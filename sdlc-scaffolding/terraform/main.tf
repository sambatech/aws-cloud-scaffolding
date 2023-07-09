terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.57.0"
    }
  }
  backend "s3" {
    profile = "platform"
    bucket = "opensamba-terraform-st"
    key    = "sdlc/terraform.tfstate"
    region = "us-east-1"
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

module "openvpn" {
  source = "./modules/openvpn"

  vpn_aws_profile   = var.aws_profile
  vpn_ami_id        = var.vpn_ami_id
  vpn_subnet        = module.vpc.out_public_subnets[0]
  vpn_username      = var.vpn_username
}

module "eks" {
  source = "./modules/eks"

  eks_subnets = module.vpc.out_private_subnets  
}

module "sonarqube" {
  source = "./modules/sonarqube"

  sonarqube_vpc                = module.vpc.out_vpc
  sonarqube_ami_id             = var.sonarqube_ami_id
  sonarqube_subnets            = module.vpc.out_private_subnets
  sonarqube_username           = var.sonarqube_rds_username
  sonarqube_availability_zones = var.vpc_availability_zones
}