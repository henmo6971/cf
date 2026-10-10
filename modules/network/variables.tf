variable "name_prefix" {
  description = "Prefix applied to resource Name tags."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
}

variable "management_subnet_cidr" {
  description = "IPv4 CIDR block for the public Management subnet."
  type        = string
}

variable "application_subnet_cidr" {
  description = "IPv4 CIDR block for the private Application subnet."
  type        = string
}

variable "backend_subnet_cidr" {
  description = "IPv4 CIDR block for the private Backend subnet."
  type        = string
}
