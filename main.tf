resource  "aws_route53_zone" "private" {
  name = var.dns_zone_name
  vpc {
     vpc_id = module.network.vpc_id
  } 
 
} 


module "network" {
  source = "./modules/network"

  name_prefix             = var.name_prefix
  vpc_cidr                = var.vpc_cidr
  management_subnet_cidr  = var.management_subnet_cidr
  application_subnet_cidr = var.application_subnet_cidr
  backend_subnet_cidr     = var.backend_subnet_cidr
}

module "workloads" {
  source = "./modules/workloads"

  name_prefix              = var.name_prefix
  vpc_id                   = module.network.vpc_id
  vpc_cidr                 = module.network.vpc_cidr_block
  management_subnet_id     = module.network.subnet_ids["management"]
  application_subnet_id    = module.network.subnet_ids["application"]
  backend_subnet_id        = module.network.subnet_ids["backend"]
  bastion_allowed_ssh_cidr = var.bastion_allowed_ssh_cidr
  bastion_ssh_public_key   = var.bastion_ssh_public_key
  dns_zone_name            = aws_route53_zone.private.name
  dns_zone_id              = aws_route53_zone.private.zone_id
  alb_record_name          = var.alb_record_name
}

output "route53_zone_id" {
  value = aws_route53_zone.private.zone_id
}

output "route53_zone_name" {
  value = aws_route53_zone.private.name
}
#output "route53_zone_id" {
#  value = aws_route53_zone.private.zone_id
#  }

#output "route53_zone_name" {
#  value = aws_route53_zone.private.name
#}
