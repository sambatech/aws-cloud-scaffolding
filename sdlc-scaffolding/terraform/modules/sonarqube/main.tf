module "rds" {
  source = "./rds"

  rds_vpc      = var.sonarqube_vpc
  rds_subnets  = var.sonarqube_subnets
  rds_username = var.sonarqube_username
}

module "ec2" {
  source = "./ec2"

  ec2_ami_id      = var.sonarqube_ami_id
  ec2_vpc         = var.sonarqube_vpc
  ec2_subnet      = var.sonarqube_subnets[0]
  ec2_db_username = var.sonarqube_username
  ec2_db_password = module.rds.out_database_password
  ec2_db_endpoint = module.rds.out_database_endpoint
}