terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.57.0"
    }
  }
  backend "s3" {
    profile = "platform"
    bucket = "plat-engineering-terraform-st"
    key    = "sdlc/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

module "network" {
  source = "./modules/network"

  vpc_aws_region           = var.aws_region
  vpc_cidr_block           = var.vpc_cidr_block
  vpc_private_subnet_cidrs = var.vpc_private_subnet_cidrs
  vpc_public_subnet_cidrs  = var.vpc_public_subnet_cidrs
  vpc_availability_zones   = var.vpc_availability_zones
  vpc_eks_cluster_name     = var.eks_cluster_name
}

module "kubernetes" {
  source = "./modules/kubernetes"

  eks_vpc_id              = module.network.out_vpc_id
  eks_vpc_cidr            = module.network.out_vpc_cidr
  eks_subnet_ids          = module.network.out_private_subnet_ids
  eks_federated_role_name = var.iam_federated_role_name
  eks_cluster_name        = var.eks_cluster_name
}

module "sonarqube" {
  source = "./modules/sonarqube"

  sonarqube_vpc_id                                 = module.network.out_vpc_id
  sonarqube_subnet_ids                             = module.network.out_private_subnet_ids
  sonarqube_subnets_cidr_blocks                    = module.network.out_private_subnets_cidr_blocks
  sonarqube_efs_filesystem_id                      = module.kubernetes.out_efs_filesystem_id  
  sonarqube_eks_cluster_endpoint                   = module.kubernetes.out_eks_cluster_endpoint
  sonarqube_eks_cluster_certificate_authority_data = module.kubernetes.out_eks_cluster_certificate_authority_data
  sonarqube_eks_cluster_auth_token                 = module.kubernetes.out_eks_cluster_auth_token
  sonarqube_ami_id                                 = var.sonarqube_ami_id
  sonarqube_username                               = var.sonarqube_rds_username
  sonarqube_availability_zones                     = var.vpc_availability_zones
  sonarqube_waf_arn                                = module.kubernetes.out_waf_arn
}