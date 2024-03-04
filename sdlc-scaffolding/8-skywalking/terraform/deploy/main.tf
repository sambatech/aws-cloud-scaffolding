terraform {
  required_version = ">= 0.13"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}

provider "kubectl" {
  host                   = var.eks_cluster_endpoint
  cluster_ca_certificate = var.eks_cluster_certificate_authority_data
  token                  = var.eks_cluster_auth_token
  load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = var.eks_cluster_endpoint
    cluster_ca_certificate = var.eks_cluster_certificate_authority_data
    token                  = var.eks_cluster_auth_token
  }

  registry {
    url = "oci://registry-1.docker.io"
    username = "sambatech20"
    password = "HPqWPbxx2XPcSEA"
  }
}

module "eks_managed_node_group" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "~> 20.0"

  name            = "skywalking"
  cluster_name    = var.eks_cluster_name
  cluster_version = var.eks_cluster_version

  subnet_ids                        = var.eks_subnet_ids
  cluster_primary_security_group_id = var.eks_cluster_primary_security_group_id
  vpc_security_group_ids            = var.eks_cluster_security_group_ids

  capacity_type  = "SPOT"
  ami_type       = "AL2_x86_64"
  # @see https://aws.amazon.com/pt/ec2/spot/instance-advisor/
  # @see https://docs.aws.amazon.com/ec2/latest/instancetypes/ec2-nitro-instances.html
  instance_types = ["t3.medium", "t3a.medium"]

  min_size     = 1
  desired_size = 5
  max_size     = 10

  taints = {
    dedicated = {
      key    = "dedicated"
      value  = "skywalking"
      effect = "NO_SCHEDULE"
    }
  }
}

data "aws_acm_certificate" "eks_certificate" {
  domain      = "sambatech.net"
  key_types   = ["RSA_2048"]
  most_recent = true
}

data "template_file" "helm_values_template" {
  template = file("${path.module}/templates/values.yaml")
  vars = {
    UI_LOADBALANCER_NAME = var.alb_name
    UI_WAFV2_ACL_ARN     = var.waf_arn
    UI_CERTIFICATE_ARN   = data.aws_acm_certificate.eks_certificate.arn
    POSTGRESQL_HOST      = var.postgresql_host
    POSTGRESQL_USERNAME  = var.postgresql_username
    POSTGRESQL_PASSWORD  = var.postgresql_password
  }
}

resource "helm_release" "skywalking" {
  name             = "skywalking"
  namespace        = "skywalking"
  create_namespace = true
  repository       = "oci://registry-1.docker.io/apache/skywalking-helm"
  chart            = "skywalking"
  version          = "4.5.0"
  values           = [data.template_file.helm_values_template.rendered]
}