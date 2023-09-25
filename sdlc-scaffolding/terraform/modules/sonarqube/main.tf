module "rds" {
  source = "./rds"

  rds_vpc_id              = var.sonarqube_vpc_id
  rds_subnet_ids          = var.sonarqube_subnet_ids
  rds_subnets_cidr_blocks = var.sonarqube_subnets_cidr_blocks
  rds_username            = var.sonarqube_username
  rds_availability_zones  = var.sonarqube_availability_zones
}

module "deploy" {
  source = "./deploy"

  deploy_efs_filesystem_id                      = var.sonarqube_efs_filesystem_id
  deploy_eks_cluster_endpoint                   = var.sonarqube_eks_cluster_endpoint
  deploy_eks_cluster_certificate_authority_data = var.sonarqube_eks_cluster_certificate_authority_data
  deploy_eks_cluster_auth_token                 = var.sonarqube_eks_cluster_auth_token
  deploy_jdbc_username                          = module.rds.out_database_username
  deploy_jdbc_password                          = module.rds.out_database_password
  deploy_jdbc_hostname                          = module.rds.out_database_hostname
  deploy_jdbc_port                              = module.rds.out_database_port
}
