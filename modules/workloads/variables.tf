variable "name_prefix" {
  description = "Prefix applied to resource Name tags."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
}

variable "management_subnet_id" {
  description = "ID of the public Management subnet."
  type        = string
}

variable "application_subnet_id" {
  description = "ID of the private Application subnet."
  type        = string
}

variable "backend_subnet_id" {
  description = "ID of the private Backend subnet."
  type        = string
}

variable "bastion_allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the bastion (e.g. your admin IP /32)."
  type        = string
}

variable "bastion_ssh_public_key" {
  description = "Public key installed on the bastion for admin SSH access."
  type        = string
  sensitive   = true
}

variable "dns_zone_name" {
  type = string
}

variable "dns_zone_id" {
  type = string
}

variable "alb_record_name" {
  description = "Full DNS record name that should CNAME to the ALB."
  type        = string
}
