module "rds" {
  source = "./rds"

  rds_vpc_id              = var.keycloak_vpc_id
  rds_subnet_ids          = var.keycloak_subnet_ids
  rds_subnets_cidr_blocks = var.keycloak_cidr_blocks
  rds_ipv6_cidr_blocks    = var.keycloak_ipv6_cidr_blocks
  rds_username            = var.keycloak_rds_username
  rds_availability_zones  = var.keycloak_availability_zones
}

module "deploy" {
  source = "./deploy"

  aws_profile                                   = var.aws_profile
  registry_url                                  = var.registry_url
  deploy_alb_name                               = var.keycloak_alb_name
  deploy_waf_arn                                = var.keycloak_waf_arn

  deploy_vpc_id                                 = var.keycloak_vpc_id
  deploy_subnet_ids                             = var.keycloak_subnet_ids
  deploy_cidr_blocks                            = var.keycloak_cidr_blocks
  deploy_ipv6_cidr_blocks                       = var.keycloak_ipv6_cidr_blocks
  
  deploy_eks_cluster_endpoint                   = var.keycloak_eks_cluster_endpoint
  deploy_eks_cluster_certificate_authority_data = var.keycloak_eks_cluster_certificate_authority_data
  deploy_eks_cluster_auth_token                 = var.keycloak_eks_cluster_auth_token

  deploy_jdbc_username                          = module.rds.out_database_username
  deploy_jdbc_password                          = module.rds.out_database_password
  deploy_jdbc_hostname                          = module.rds.out_database_hostname
  deploy_jdbc_port                              = module.rds.out_database_port
}
