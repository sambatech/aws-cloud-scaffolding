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
            test     = "StringEquals"
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

resource "helm_release" "aws_efs_csi_driver_release" {
  name       = "aws-efs-csi-driver"
  chart      = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  namespace  = "kube-system"

  set {
    name  = "image.repository"
    value = "602401143452.dkr.ecr.us-east-1.amazonaws.com/eks/aws-efs-csi-driver"
  }

  set {
    name  = "controller.serviceAccount.create"
    value = false
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "efs-csi-controller-sa"
  }

  set {
    name  = "node.serviceAccount.create"
    value = false
  }

  set {
    name  = "node.serviceAccount.name"
    value = "efs-csi-node-sa"
  }
}

resource "aws_security_group" "aws_efs_sg" {
  name        = "aws-efs-sg"
  description = "Allow NFS inbound traffic"
  vpc_id      = var.efs_vpc_id

  ingress {
    description      = "NFS from VPC"
    from_port        = 2049
    to_port          = 2049
    protocol         = "tcp"
    cidr_blocks      = var.efs_cidr_blocks
    ipv6_cidr_blocks = var.efs_ipv6_cidr_blocks
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

}

resource "aws_efs_file_system" "sonarqube_efs" {
  creation_token   = "sonarqube-efs"
  throughput_mode  = "bursting"
  performance_mode = "generalPurpose"

#  lifecycle {
#    prevent_destroy = true
#  }

  tags = {
    Name = "sonarqube-efs"
  }
}

resource "aws_efs_mount_target" "sonarqube_efs_mount_target" {
  count           = length(var.efs_subnet_ids)
  security_groups = [aws_security_group.aws_efs_sg.id]
  subnet_id       = var.efs_subnet_ids[count.index]
  file_system_id  = aws_efs_file_system.sonarqube_efs.id
}

resource "kubectl_manifest" "sonarqube_storage_class" {
    yaml_body = <<YAML
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: sonarqube-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: ${aws_efs_file_system.sonarqube_efs.id}
  directoryPerms: "700"
YAML
}
