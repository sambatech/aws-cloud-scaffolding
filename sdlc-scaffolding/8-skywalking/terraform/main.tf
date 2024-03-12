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

module "opensearch" {
  source = "./opensearch"

  create              = true
  aws_profile         = var.aws_profile
  vpc_id              = data.aws_vpc.instance.id
  subnets_ids         = data.aws_subnets.query.ids
  subnets_cidr_blocks = [for s in data.aws_subnet.instance : s.cidr_block]
  ipv6_cidr_blocks    = [for s in data.aws_subnet.instance : s.ipv6_cidr_block]
  availability_zones  = var.availability_zones
  skywalking_username = var.skywalking_username
}

module "deploy" {
  source = "./deploy"

  aws_profile = var.aws_profile
  aws_region  = var.aws_region

  eks_cluster_name                       = var.cluster_name
  cluster_ip_family                      = var.cluster_ip_family
  eks_cluster_version                    = data.aws_eks_cluster.default.version
  eks_logging_policy_name                = var.cluster_logging_policy_name
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

  waf_arn                                 = var.waf_arn
  alb_name                                = var.load_balancer_name
  skywalking_host                         = var.skywalking_host
  opensearch_hostname                     = module.opensearch.out_hostname
  opensearch_username                     = module.opensearch.out_username
  opensearch_password                     = module.opensearch.out_password
  keycloak_host                           = var.keycloak_host
  keycloak_realm_name                     = var.keycloak_realm_name
  keycloak_client_id                      = var.keycloak_client_id
  keycloak_client_secret                  = var.keycloak_client_secret
  ingress_controller_service_account_name = var.ingress_controller_service_account_name
}