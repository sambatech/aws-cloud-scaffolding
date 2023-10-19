module "rds" {
  source = "./rds"

  rds_vpc_id              = var.sonarqube_vpc_id
  rds_subnet_ids          = var.sonarqube_subnet_ids
  rds_subnets_cidr_blocks = var.sonarqube_cidr_blocks
  rds_ipv6_cidr_blocks    = var.sonarqube_ipv6_cidr_blocks
  rds_username            = var.sonarqube_username
  rds_availability_zones  = var.sonarqube_availability_zones
}

module "deploy" {
  source = "./deploy"

  aws_region                                    = var.aws_region
  deploy_vpc_id                                 = var.sonarqube_vpc_id
  deploy_subnet_ids                             = var.sonarqube_subnet_ids
  deploy_cidr_blocks                            = var.sonarqube_cidr_blocks
  deploy_ipv6_cidr_blocks                       = var.sonarqube_ipv6_cidr_blocks
  deploy_eks_cluster_endpoint                   = var.sonarqube_eks_cluster_endpoint
  deploy_eks_cluster_certificate_authority_data = var.sonarqube_eks_cluster_certificate_authority_data
  deploy_eks_cluster_auth_token                 = var.sonarqube_eks_cluster_auth_token
  deploy_alb_name                               = var.sonarqube_alb_name
  deploy_waf_arn                                = var.sonarqube_waf_arn
  deploy_jdbc_username                          = module.rds.out_database_username
  deploy_jdbc_password                          = module.rds.out_database_password
  deploy_jdbc_hostname                          = module.rds.out_database_hostname
  deploy_jdbc_port                              = module.rds.out_database_port
}
