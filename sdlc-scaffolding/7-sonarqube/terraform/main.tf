terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.36"
    }
  }
  backend "s3" {
    profile = "platform"
    bucket = "plat-engineering-terraform-st"
    key    = "sdlc/sonarqube.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

data "aws_vpc" "instance" {
  cidr_block = var.cidr_block
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_subnets" "query" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.instance.id]
  }
  filter {
    name   = "tag:subnet/kind"
    values = ["private"]
  }
}

data "aws_subnet" "instance" {
  for_each = toset(data.aws_subnets.query.ids)
  id       = each.value
}

data "aws_eks_cluster" "default" {
  name  = var.cluster_name
}

data "aws_eks_cluster_auth" "default" {
  name  = var.cluster_name
}

module "rds" {
  source = "./rds"

  rds_vpc_id               = data.aws_vpc.instance.id
  rds_subnet_ids           = data.aws_subnets.query.ids
  rds_subnets_cidr_blocks  = [for s in data.aws_subnet.instance : s.cidr_block]
  rds_ipv6_cidr_blocks     = [for s in data.aws_subnet.instance : s.ipv6_cidr_block]
  rds_username             = var.sonarqube_username
  rds_availability_zones   = var.availability_zones
  rds_create_from_snapshot = false
}

module "deploy" {
  source = "./deploy"

  aws_region                                    = var.aws_region
  deploy_vpc_id                                 = data.aws_vpc.instance.id
  deploy_subnet_ids                             = data.aws_subnets.query.ids
  deploy_cidr_blocks                            = [for s in data.aws_subnet.instance : s.cidr_block]
  deploy_ipv6_cidr_blocks                       = [for s in data.aws_subnet.instance : s.ipv6_cidr_block]

  deploy_eks_cluster_endpoint                   = element(concat(data.aws_eks_cluster.default[*].endpoint, tolist([""])), 0)
  deploy_eks_cluster_certificate_authority_data = base64decode(element(concat(data.aws_eks_cluster.default[*].certificate_authority.0.data, tolist([""])), 0))
  deploy_eks_cluster_auth_token                 = element(concat(data.aws_eks_cluster_auth.default[*].token, tolist([""])), 0)
  deploy_cluster_primary_security_group_id      = data.aws_eks_cluster.default.vpc_config.0.cluster_security_group_id
  deploy_cluster_security_group_ids             = flatten([
    for c in data.aws_eks_cluster.default.vpc_config : [
      for id in c.security_group_ids : tostring(id)
    ]
  ])
      
  deploy_alb_name                               = var.load_balancer_name
  deploy_waf_arn                                = var.waf_arn

  deploy_cluster_name                           = var.cluster_name
  deploy_cluster_version                        = data.aws_eks_cluster.default.version

  deploy_jdbc_username                          = module.rds.out_database_username
  deploy_jdbc_password                          = module.rds.out_database_password
  deploy_jdbc_hostname                          = module.rds.out_database_hostname
  deploy_jdbc_port                              = module.rds.out_database_port
  
  keycloak_realm_name                           = var.keycloak_realm_name
  keycloak_client_id                            = var.keycloak_client_id
  keycloak_client_secret                        = var.keycloak_client_secret
  keycloak_host                                 = var.keycloak_host
  sonarqube_host                                = var.sonarqube_host
}
