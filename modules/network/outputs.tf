output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "subnet_ids" {
  description = "Subnet IDs keyed by tier name."
  value       = { for name, subnet in aws_subnet.this : name => subnet.id }
}

output "subnet_cidr_blocks" {
  description = "Subnet CIDR blocks keyed by tier name."
  value       = { for name, subnet in aws_subnet.this : name => subnet.cidr_block }
}

output "subnet_availability_zones" {
  description = "Subnet availability zones keyed by tier name."
  value       = { for name, subnet in aws_subnet.this : name => subnet.availability_zone }
}

output "internet_gateway_id" {
  description = "ID of the VPC Internet Gateway."
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway."
  value       = aws_nat_gateway.this.id
}

output "nat_gateway_public_ip" {
  description = "Public IPv4 address of the NAT Gateway."
  value       = aws_eip.nat.public_ip
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the private route table."
  value       = aws_route_table.private.id
}
