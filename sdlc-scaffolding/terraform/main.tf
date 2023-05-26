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

  vpn_aws_profile          = var.aws_profile
  vpn_ami_id               = var.vpn_ami_id
  vpn_subnet               = module.vpc.out_public_subnet
  vpn_server_username      = var.vpn_server_username
}

module "secrets" {
  source = "./modules/secrets"

  secret_aws_profile       = var.aws_profile
  secret_server_username   = var.vpn_server_username
  secret_server_password   = module.vpn.out_server_password
  secret_server_pem        = module.vpn.out_server_pem
}