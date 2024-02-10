terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}

provider "kubectl" {
  host                   = var.efs_eks_cluster_endpoint
  cluster_ca_certificate = var.efs_eks_cluster_certificate_authority_data
  token                  = var.efs_eks_cluster_auth_token
  load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = var.efs_eks_cluster_endpoint
    cluster_ca_certificate = var.efs_eks_cluster_certificate_authority_data
    token                  = var.efs_eks_cluster_auth_token
  }
}

data "aws_region" "current" {}

data "aws_iam_policy" "efs_csi_driver_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

data "aws_iam_policy_document" "assume_role" {
    statement {
        actions = ["sts:AssumeRoleWithWebIdentity"]

        principals {
            type        = "Federated"
            identifiers = [var.oidc_provider_arn]
        }

        condition {
            test     = "StringLike"
            variable = "oidc.eks.${data.aws_region.current.name}.amazonaws.com/id/${substr(var.oidc_provider_arn, -32, -1)}:aud"
            values = ["sts.amazonaws.com"]
        }

        condition {
            test     = "StringLike"
            variable = "oidc.eks.${data.aws_region.current.name}.amazonaws.com/id/${substr(var.oidc_provider_arn, -32, -1)}:sub"
            values = ["system:serviceaccount:kube-system:efs-csi-*"]
        }
    }
}

resource "aws_iam_role" "eks_efs_csi_driver_role" {
  name = "AmazonEKS_EFS_CSI_DriverRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "role_policy_attachment" {
  role       = aws_iam_role.eks_efs_csi_driver_role.name
  policy_arn = data.aws_iam_policy.efs_csi_driver_policy.arn
}

resource "kubectl_manifest" "efs_csi_controller_sa" {
    yaml_body = <<YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: kube-system
  name: efs-csi-controller-sa
  labels:
    app.kubernetes.io/name: aws-efs-csi-driver
  annotations:
    eks.amazonaws.com/role-arn: ${aws_iam_role.eks_efs_csi_driver_role.arn}
YAML
}

resource "kubectl_manifest" "efs_csi_node_sa" {
    yaml_body = <<YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: kube-system
  name: efs-csi-node-sa
  labels:
    app.kubernetes.io/name: aws-efs-csi-driver
  annotations:
    eks.amazonaws.com/role-arn: ${aws_iam_role.eks_efs_csi_driver_role.arn}
YAML
}
