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
    key    = "sdlc/skywalking.tfstate"
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

  rds_vpc_id              = data.aws_vpc.instance.id
  rds_subnet_ids          = data.aws_subnets.query.ids
  rds_subnets_cidr_blocks = [for s in data.aws_subnet.instance : s.cidr_block]
  rds_ipv6_cidr_blocks    = [for s in data.aws_subnet.instance : s.ipv6_cidr_block]
  rds_username            = var.skywalking_username
  rds_availability_zones  = var.availability_zones
}

module "deploy" {
  source = "./deploy"

  aws_profile = var.aws_profile
  aws_region  = var.aws_region

  eks_cluster_name                       = var.cluster_name
  eks_cluster_version                    = data.aws_eks_cluster.default.version
  eks_cluster_endpoint                   = element(concat(data.aws_eks_cluster.default[*].endpoint, tolist([""])), 0)
  eks_cluster_certificate_authority_data = base64decode(element(concat(data.aws_eks_cluster.default[*].certificate_authority.0.data, tolist([""])), 0))
  eks_cluster_auth_token                 = element(concat(data.aws_eks_cluster_auth.default[*].token, tolist([""])), 0)
  eks_subnet_ids                         = data.aws_subnets.query.ids
  eks_cluster_primary_security_group_id  = data.aws_eks_cluster.default.vpc_config.0.cluster_security_group_id
  eks_cluster_security_group_ids         = flatten([
    for c in data.aws_eks_cluster.default.vpc_config : [
      for id in c.security_group_ids : tostring(id)
    ]
  ])

  alb_name            = var.load_balancer_name
  waf_arn             = var.waf_arn
  postgresql_host     = module.rds.out_database_hostname
  postgresql_username = module.rds.out_database_username
  postgresql_password = module.rds.out_database_password
}