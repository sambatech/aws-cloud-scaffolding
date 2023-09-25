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

resource "aws_security_group" "aws_efs_sg" {
  name        = "aws-efs-sg"
  description = "Allow NFS inbound traffic"
  vpc_id      = var.efs_vpc_id

  ingress {
    description = "NFS from VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.efs_vpc_cidr]
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
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: ${aws_efs_file_system.sonarqube_efs.id}
  directoryPerms: "700"
YAML
}
