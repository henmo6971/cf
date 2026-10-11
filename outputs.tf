output "vpc_id" {
  description = "ID of the VPC."
  value       = module.network.vpc_id
}

output "subnet_ids" {
  description = "IDs of the Management, Application, and Backend subnets."
  value       = module.network.subnet_ids
}

output "nat_gateway_public_ip" {
  description = "Public IPv4 address of the NAT Gateway."
  value       = module.network.nat_gateway_public_ip
}

output "alb_dns_name" {
  description = "Internal DNS name of the Application load balancer."
  value       = module.workloads.alb_dns_name
  }

output "bastion_instance_id" {
  description = "Instance ID of the bastion host."
  value       = module.workloads.bastion_instance_id
  }

output "application_asg_name" {
  description = "Name of the Application Auto Scaling Group."
  value       = module.workloads.application_asg_name
  }
