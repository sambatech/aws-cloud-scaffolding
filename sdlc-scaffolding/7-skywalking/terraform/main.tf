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
    key     = "sdlc/skywalking.tfstate"
    region  = "us-east-1"
  }
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

provider "helm" {
  kubernetes {
    host                   = element(concat(data.aws_eks_cluster.default[*].endpoint, tolist([""])), 0)
    cluster_ca_certificate = base64decode(element(concat(data.aws_eks_cluster.default[*].certificate_authority.0.data, tolist([""])), 0))
    exec {
      api_version = "client.authentication.k8s.io/v1alpha1"
      command     = "aws"
      args        = ["--region", var.aws_region, "--profile", var.aws_profile, "eks", "get-token", "--cluster-name", data.aws_eks_cluster.cluster.name]
    }
  }
}

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

resource "helm_release" "nginx" {
  name       = "nginx"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx"

  values = [
    file("${path.module}/nginx-values.yaml")
  ]
}