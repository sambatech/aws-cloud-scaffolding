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
  host                   = var.deploy_eks_cluster_endpoint
  cluster_ca_certificate = var.deploy_eks_cluster_certificate_authority_data
  token                  = var.deploy_eks_cluster_auth_token
  load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = var.deploy_eks_cluster_endpoint
    cluster_ca_certificate = var.deploy_eks_cluster_certificate_authority_data
    token                  = var.deploy_eks_cluster_auth_token
  }
}

locals {
  admin_username = "KeycloakAdmin"
}

resource "random_string" "password" {
  length   = 32
  upper    = true
  numeric  = true
  special  = false
}

resource "time_static" "tag" {
  triggers = {
    run = "14/10/2023 14:13:00"
  }
}

resource "aws_secretsmanager_secret" "keycloak_credentials" {
   name                    = "/platform/keycloak/app/credentials/${time_static.tag.unix}"
   recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "keycloak_credentials_version" {
  secret_id = aws_secretsmanager_secret.keycloak_credentials.id
  secret_string = <<EOF
   {
    "username": "${local.admin_username}",
    "password": "${random_string.password.result}"
   }
EOF
}

########################################################################################
# Install the AWS Load Balancer Controller using Helm V3
########################################################################################

resource "kubectl_manifest" "keycloak_namespace" {
    yaml_body = <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: keycloak
YAML
}

resource "helm_release" "keycloak_helm_release" {
  name       = "keycloak"
  chart      = "keycloak"
  namespace  = "keycloak"
  repository = "oci://registry-1.docker.io/bitnamicharts"

  set {
    name  = "global.storageClass"
    value = "gp2"
  }

  set {
    name  = "namespaceOverride"
    value = "keycloak"
  }

  set {
    name  = "production"
    value = "true"
  }

  set {
    name  = "proxy"
    value = "edge"
  }

  set {
    name  = "auth.adminUser"
    value = "${local.admin_username}"
  }

  set {
    name  = "auth.adminPassword"
    value = "${random_string.password.result}"
  }

  set {
    name  = "replicaCount"
    value = "2"
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "ingress.enabled"
    value = "false"
  }

  set {
    name  = "postgresql.enabled"
    value = "false"
  }

  set {
    name  = "externalDatabase.host"
    value = "${var.deploy_jdbc_hostname}"
  }

  set {
    name  = "externalDatabase.port"
    value = "${var.deploy_jdbc_port}"
  }

  set {
    name  = "externalDatabase.user"
    value = "${var.deploy_jdbc_username}"
  }

  set {
    name  = "externalDatabase.password"
    value = "${var.deploy_jdbc_password}"
  }

  set {
    name  = "externalDatabase.database"
    value = "keycloak"
  }

  depends_on = [ 
    kubectl_manifest.keycloak_namespace 
  ]
}

data "aws_acm_certificate" "eks_certificate" {
  domain      = "sambatech.net"
  key_types   = ["RSA_2048"]
  most_recent = true
}

resource "kubectl_manifest" "keycloak_ingress" {
    yaml_body = <<YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak-ingress
  namespace: keycloak
  annotations:
    alb.ingress.kubernetes.io/load-balancer-name: ${var.deploy_alb_name}
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/group.name: 'platform-engineering'
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/ip-address-type: dualstack
    alb.ingress.kubernetes.io/backend-protocol: HTTP
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
    alb.ingress.kubernetes.io/healthcheck-port: traffic-port
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '15'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/success-codes: '200'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
    alb.ingress.kubernetes.io/shield-advanced-protection: 'true'
    alb.ingress.kubernetes.io/wafv2-acl-arn: '${var.deploy_waf_arn}'
    alb.ingress.kubernetes.io/certificate-arn: '${data.aws_acm_certificate.eks_certificate.arn}'
spec:
  ingressClassName: alb
  rules:
  - host: sso.sambatech.net
    http:
      paths:
      - path: /*
        pathType: ImplementationSpecific
        backend:
          service:
            name: keycloak
            port: 
              number: 80
YAML

  depends_on = [
    helm_release.keycloak_helm_release
  ]
}