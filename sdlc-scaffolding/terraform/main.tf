terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.34.0"
    }
  }
  backend "s3" {
    profile = "plataform-videos"
    bucket = "sambavideos-terraform"
    key    = "sdlc/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  profile = var.aws_profile
  region = var.aws_region
}

module "vpc" {
  source = "./modules/vpc"

  vpc_aws_region           = var.aws_region
  vpc_cidr_block           = var.vpc_cidr_block
  vpc_private_subnet_cidrs = var.vpc_private_subnet_cidrs
  vpc_public_subnet_cidrs  = var.vpc_public_subnet_cidrs
  vpc_availability_zones   = var.vpc_availability_zones
  vpc_eks_cluster_name     = var.eks_cluster_name
}

# module "openvpn" {
#   source = "./modules/openvpn"

#   vpn_aws_profile   = var.aws_profile
#   vpn_ami_id        = var.vpn_ami_id
#   vpn_subnet        = module.vpc.out_public_subnets[0]
#   vpn_username      = var.vpn_username
# }

module "eks" {
  source = "./modules/eks"

  eks_vpc_cidr_block = var.vpc_cidr_block
  eks_subnets        = module.vpc.out_private_subnets
  eks_cluster_name   = var.eks_cluster_name
}

# module "sonarqube" {
#   source = "./modules/sonarqube"

#   sonarqube_vpc                = module.vpc.out_vpc
#   sonarqube_ami_id             = var.sonarqube_ami_id
#   sonarqube_subnets            = module.vpc.out_private_subnets
#   sonarqube_username           = var.sonarqube_rds_username
#   sonarqube_availability_zones = var.vpc_availability_zones
# }

module "aurora" {
  source = "./modules/aurora"

  serverless_cluster = var.serverless_cluster
  engine             = var.engine
  engine_mode        = var.engine_mode
  database_version   = var.database_version
  database_name      = var.database_name
  database_user      = var.database_user
  database_password  = var.database_password
  aurora_subnets     = module.vpc.out_private_subnets
  main_vpc           = module.vpc.out_vpc
  instance_class     = var.instance_class

}

module "registry" {
  source = "./modules/ecr"
  ecr-name = var.ecr-name
}

module "zone-hospedada" {
  source = "./modules/dns"
  domain-name = var.domain-name
  domain-address = var.domain-address
}