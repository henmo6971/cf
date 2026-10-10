output "alb_dns_name" {
  description = "Internal DNS name of the Application load balancer."
  value       = aws_lb.application.dns_name
}

output "bastion_instance_id" {
  description = "Instance ID of the bastion host."
  value       = aws_instance.bastion.id
}

output "application_asg_name" {
  description = "Name of the Application Auto Scaling Group."
  value       = aws_autoscaling_group.application.name
}
