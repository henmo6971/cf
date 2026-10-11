data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# --- Bastion (Management subnet) ---

resource "aws_key_pair" "bastion" {
  key_name   = "${var.name_prefix}-bastion"
  public_key = file("~/.ssh/id_ed25519.pub")
}

resource "aws_security_group" "bastion" {
  name_prefix = "${var.name_prefix}-bastion-"
  description = "Bastion host in the Management subnet"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.bastion_allowed_ssh_cidr]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-bastion-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type               = "t3.micro"
  subnet_id                   = var.management_subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.bastion.key_name
  associate_public_ip_address = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 8
  }

  tags = {
    Name = "${var.name_prefix}-bastion"
  }
}

# --- Application tier (ASG, private Application subnet) ---

resource "aws_security_group" "application" {
  name_prefix = "${var.name_prefix}-application-"
  description = "No external traffic as requested"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-application-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "application_http_from_alb" {
  type                     = "ingress"
  description              = "HTTP from the ALB"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.application.id
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "application_ssh_from_bastion" {
  type                     = "ingress"
  description              = "SSH from the bastion"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.application.id
  source_security_group_id = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "application_egress" {
  type              = "egress"
  description       = "Allow outbound traffic for package installation and updates"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.application.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_launch_template" "application" {
  name_prefix   = "${var.name_prefix}-application-"
  image_id      = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type = "t3.micro"
  key_name      = aws_key_pair.bastion.key_name

  vpc_security_group_ids = [aws_security_group.application.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      encrypted             = true
      volume_size           = 8
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euxo pipefail

    dnf install -y httpd
    PRIVATE_IP=$(hostname -I | awk '{print $1}')

    cat > /var/www/html/index.html <<HTML
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <title>Application Server</title>
      </head>
      <body>
        <h1>Amazon Linux 2023</h1>
        <p>Instance private IP: $${PRIVATE_IP}</p>
      </body>
    </html>
    HTML

    systemctl enable --now httpd
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.name_prefix}-application"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = "${var.name_prefix}-application"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "application" {
  name_prefix         = "${var.name_prefix}-application-"
  min_size            = 2
  max_size            = 6
  desired_capacity    = 2
  vpc_zone_identifier = [var.application_subnet_id]
  health_check_type   = "EC2"
  target_group_arns   = [aws_lb_target_group.application.arn]

  launch_template {
    id      = aws_launch_template.application.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-application"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --- Internal ALB (Backend + Application subnets) ---

resource "aws_security_group" "alb" {
  name_prefix = "${var.name_prefix}-alb-"
  description = "Internal ALB for the Application tier"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-alb-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "alb_http_from_vpc" {
  type              = "ingress"
  description       = "HTTP from within the VPC"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = [var.vpc_cidr]
}

resource "aws_security_group_rule" "alb_http_to_application" {
  type                     = "egress"
  description              = "HTTP to the Application tier"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.application.id
}

resource "aws_lb" "application" {
  name_prefix        = substr(replace(var.name_prefix, "-", ""), 0, 6)
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [var.backend_subnet_id, var.application_subnet_id]

  tags = {
    Name = "${var.name_prefix}-alb"
  }
}

resource "aws_lb_target_group" "application" {
  name_prefix = "app-"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.name_prefix}-application-tg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "application" {
  load_balancer_arn = aws_lb.application.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.application.arn
  }
}

# --- DNS ---

data "aws_route53_zone" "this" {
  name         = var.dns_zone_name
  private_zone = true
}

resource "aws_route53_record" "alb" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.alb_record_name
  type    = "CNAME"
  ttl     = 300
  records = [aws_lb.application.dns_name]
}
