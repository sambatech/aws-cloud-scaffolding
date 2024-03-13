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

locals {
  prefer_ipv4_stack = "-Djava.net.preferIPv4Stack=${lower(var.cluster_ip_family) == "ipv4" ? "true" : "false"}"
  prefer_ipv6_stack = "-Djava.net.preferIPv6Addresses=${lower(var.cluster_ip_family) == "ipv6" ? "true" : "false"}"
}

module "eks_fargate-profile" {
  source  = "terraform-aws-modules/eks/aws//modules/fargate-profile"
  version = "~> 20.0"

  name         = "teamcity-fargate"
  cluster_name = var.eks_cluster_name
  subnet_ids   = var.eks_subnet_ids

  selectors = [{
    namespace = "teamcity"
  }]
}

data "aws_iam_policy" "logging_policy" {
  name = var.eks_logging_policy_name
}

resource "aws_iam_role_policy_attachment" "logging_policy_attach" {
  role       = module.eks_fargate-profile.iam_role_name
  policy_arn = data.aws_iam_policy.logging_policy.arn
}

resource "aws_efs_file_system" "teamcity_efs" {
  creation_token   = "teamcity-efs"
  throughput_mode  = "bursting"
  performance_mode = "generalPurpose"

  tags = {
    Name = "teamcity-efs"
  }
}

resource "aws_efs_access_point" "teamcity_access_point" {
  file_system_id = aws_efs_file_system.teamcity_efs.id
}

resource "aws_efs_mount_target" "teamcity_efs_mount_target" {
  count           = length(var.eks_subnet_ids)
  subnet_id       = var.eks_subnet_ids[count.index]
  security_groups = [aws_security_group.teamcity_efs_sg.id]
  file_system_id  = aws_efs_file_system.teamcity_efs.id
}

resource "kubectl_manifest" "teamcity_namespace" {
  yaml_body = <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: teamcity
YAML
}

resource "kubectl_manifest" "teamcity_datadir_config" {
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: teamcity-datadir-config
  namespace: teamcity
data:
  database.properties: |
    connectionUrl=jdbc:postgresql://${var.rds_hostname}:${var.rds_port}/teamcity?allowPublicKeyRetrieval=true&useSSL=false
    connectionProperties.user=${var.rds_username}
    connectionProperties.password=${var.rds_password}
    maxConnections=50
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_services_config" {
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: teamcity-services
  namespace: teamcity
data:
  fastunzip.sh: |
    #!/bin/bash
    cd /opt/teamcity/webapps/ROOT/WEB-INF/plugins
    for zip in ./*.zip; do
      test -f $zip || continue
      unzip $zip -d $(basename $zip .zip) > /dev/null && rm -f $zip &
    done
    wait
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: teamcity-startup-wrp
  namespace: teamcity
data:
  run-services-wrp.sh: |
    #!/bin/bash
    HOSTNAME=$(cat /etc/hostname)

    exec /run-services.sh
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_persistent_volume" {
    yaml_body = <<YAML
apiVersion: v1
kind: PersistentVolume
metadata:
  name: teamcity-pv
  namespace: teamcity
spec:
  capacity:
    storage: 32Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: teamcity-sc
  csi:
    driver: efs.csi.aws.com
    volumeHandle: "${aws_efs_file_system.teamcity_efs.id}::${aws_efs_access_point.teamcity_access_point.id}"
YAML

    depends_on = [
        kubectl_manifest.teamcity_namespace
    ]
}

resource "kubectl_manifest" "teamcity_persistent_volume_claim" {
    yaml_body = <<YAML
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: teamcity-claim
  namespace: teamcity
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: teamcity-sc
  resources:
    requests:
      storage: 32Gi
YAML

    depends_on = [
        kubectl_manifest.teamcity_namespace,
        kubectl_manifest.teamcity_persistent_volume
    ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_" {
  yaml_body = <<YAML
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

