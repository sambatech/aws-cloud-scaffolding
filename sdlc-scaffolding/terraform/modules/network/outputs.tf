output "out_vpc_id" {
  value = module.vpc.vpc_id
}

output "out_public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "out_private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "out_private_subnets_cidr_blocks" {
  value = module.vpc.private_subnets_cidr_blocks
}

output "out_availability_zones" {
  value = var.vpc_availability_zones
}