terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.36"
    }
  }
  backend "s3" {
    profile = "platform"
    bucket  = "plat-engineering-terraform-st"
    key     = "sdlc/kubernetes-extra.tfstate"
    region  = "us-east-1"
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

data "aws_ecr_repository" "instance" {
  name = var.repository_name
}

data "aws_eks_cluster" "default" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "default" {
  name = var.cluster_name
}

data "aws_iam_openid_connect_provider" "instance" {
  url = data.aws_eks_cluster.default.identity.0.oidc.0.issuer
}

provider "kubernetes" {
  host                   = element(concat(data.aws_eks_cluster.default[*].endpoint, tolist([""])), 0)
  cluster_ca_certificate = base64decode(element(concat(data.aws_eks_cluster.default[*].certificate_authority.0.data, tolist([""])), 0))
  token                  = element(concat(data.aws_eks_cluster_auth.default[*].token, tolist([""])), 0)
}

module "log" {
  source = "./log"

  log_cluster_name                           = var.cluster_name
  log_logging_policy_name                    = var.cluster_logging_policy_name
  log_subnet_ids                             = data.aws_subnets.query.ids
  log_eks_cluster_endpoint                   = element(concat(data.aws_eks_cluster.default[*].endpoint, tolist([""])), 0)
  log_eks_cluster_certificate_authority_data = base64decode(element(concat(data.aws_eks_cluster.default[*].certificate_authority.0.data, tolist([""])), 0))
  log_eks_cluster_auth_token                 = element(concat(data.aws_eks_cluster_auth.default[*].token, tolist([""])), 0)
}

module "efs" {
  source = "./efs"

  oidc_provider_arn = data.aws_iam_openid_connect_provider.instance.arn
  efs_vpc_id        = data.aws_vpc.instance.id
  efs_subnet_ids    = data.aws_subnets.query.ids

  efs_cidr_blocks      = [for s in data.aws_subnet.instance : s.cidr_block]
  efs_ipv6_cidr_blocks = [for s in data.aws_subnet.instance : s.ipv6_cidr_block]

  efs_eks_cluster_endpoint                   = element(concat(data.aws_eks_cluster.default[*].endpoint, tolist([""])), 0)
  efs_eks_cluster_certificate_authority_data = base64decode(element(concat(data.aws_eks_cluster.default[*].certificate_authority.0.data, tolist([""])), 0))
  efs_eks_cluster_auth_token                 = element(concat(data.aws_eks_cluster_auth.default[*].token, tolist([""])), 0)
}

module "metrics-server" {
  source = "./metrics-server"

  deploy_eks_cluster_endpoint                   = element(concat(data.aws_eks_cluster.default[*].endpoint, tolist([""])), 0)
  deploy_eks_cluster_certificate_authority_data = base64decode(element(concat(data.aws_eks_cluster.default[*].certificate_authority.0.data, tolist([""])), 0))
  deploy_eks_cluster_auth_token                 = element(concat(data.aws_eks_cluster_auth.default[*].token, tolist([""])), 0)
}

module "ingress-controller" {
  source = "./ingress-controller"

  eks_cluster_name  = var.cluster_name
  eks_vpc_id        = data.aws_vpc.instance.id
  oidc_provider_arn = data.aws_iam_openid_connect_provider.instance.arn
  ingress_controller_service_account_name = var.ingress_controller_service_account_name

  eks_cluster_endpoint                   = element(concat(data.aws_eks_cluster.default[*].endpoint, tolist([""])), 0)
  eks_cluster_certificate_authority_data = base64decode(element(concat(data.aws_eks_cluster.default[*].certificate_authority.0.data, tolist([""])), 0))
  eks_cluster_auth_token                 = element(concat(data.aws_eks_cluster_auth.default[*].token, tolist([""])), 0)
}

module "waf" {
  source = "./waf"

  eks_cluster_name = var.cluster_name
}

module "debugger" {
  source = "./debugger"

  aws_profile                                     = var.aws_profile
  registry_url                                    = data.aws_ecr_repository.instance.repository_url
  debugger_eks_cluster_endpoint                   = element(concat(data.aws_eks_cluster.default[*].endpoint, tolist([""])), 0)
  debugger_eks_cluster_certificate_authority_data = base64decode(element(concat(data.aws_eks_cluster.default[*].certificate_authority.0.data, tolist([""])), 0))
  debugger_eks_cluster_auth_token                 = element(concat(data.aws_eks_cluster_auth.default[*].token, tolist([""])), 0)
}
