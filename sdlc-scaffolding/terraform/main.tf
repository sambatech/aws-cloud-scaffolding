terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.57.0"
    }
  }
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr_block           = var.vpc_cidr_block
  vpc_private_subnet_cidrs = var.vpc_private_subnet_cidrs
  vpc_public_subnet_cidrs  = var.vpc_public_subnet_cidrs
  vpc_availability_zones   = var.vpc_availability_zones
}

module "vpn" {
  source = "./modules/vpn"

  vpn_aws_profile   = var.aws_profile
  vpn_ami_id        = var.vpn_ami_id
  vpn_subnet        = module.vpc.out_public_subnets[0]
  vpn_username      = var.vpn_username
}

module "sonarqube" {
  source = "./modules/sonarqube"

  sonarqube_vpc      = module.vpc.out_vpc
  sonarqube_ami_id   = var.sonarqube_ami_id
  sonarqube_subnets  = module.vpc.out_private_subnets
  sonarqube_username = var.sonarqube_rds_username
}

module "secrets" {
  source = "./modules/secrets"

  secret_aws_profile           = var.aws_profile
  secret_vpn_username          = var.vpn_username
  secret_vpn_password          = module.vpn.out_server_password
  secret_vpn_pem               = module.vpn.out_server_pem

  secret_sonarqube_pem          = module.sonarqube.out_server_pem
  secret_sonarqube_rds_username = var.sonarqube_rds_username
  secret_sonarqube_rds_password = module.sonarqube.out_database_password
}