terraform {
  required_version = ">= 0.15"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.36"
    }
  }
  backend "s3" {
    profile = "platform"
    bucket = "plat-engineering-terraform-st"
    key    = "sdlc/network.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.5"

  name = var.vpc_name
  cidr = var.cidr_block

  azs             = var.availability_zones
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  enable_ipv6            = true
  enable_nat_gateway     = true
  enable_dns_hostnames   = true
  enable_dns_support     = true
  one_nat_gateway_per_az = true
  create_egress_only_igw = true
  single_nat_gateway     = false

  public_subnet_ipv6_prefixes                    = [0, 1, 2]
  public_subnet_assign_ipv6_address_on_creation  = true
  private_subnet_ipv6_prefixes                   = [3, 4, 5]
  private_subnet_assign_ipv6_address_on_creation = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "subnet/kind" = "public"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "subnet/kind" = "private"
  }
}