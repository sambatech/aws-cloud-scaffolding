module "rds" {
  source = "./rds"

  rds_vpc                = var.sonarqube_vpc
  rds_subnets            = var.sonarqube_subnets
  rds_username           = var.sonarqube_username
  rds_availability_zones = var.sonarqube_availability_zones
}