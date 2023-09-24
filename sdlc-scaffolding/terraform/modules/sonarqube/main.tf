module efs {
  source = "./efs"

  efs_sg_id      = var.sonarqube_efs_sg_id
  efs_subnet_ids = var.sonarqube_subnet_ids
}

module "rds" {
  source = "./rds"

  rds_vpc_id              = var.sonarqube_vpc_id
  rds_subnet_ids          = var.sonarqube_subnet_ids
  rds_subnets_cidr_blocks = var.sonarqube_subnets_cidr_blocks
  rds_username            = var.sonarqube_username
  rds_availability_zones  = var.sonarqube_availability_zones
}