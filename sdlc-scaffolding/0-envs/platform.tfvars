aws_region               = "us-east-1"
aws_profile              = "platform"

################################
# IAM
################################
# AWS EKS aws-auth config-map don't recognize the full arn role name, so we need to use the short name
# arn:aws:iam::021847444320:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_d856cb421c5265d1
oidc_provider_arn        = "arn:aws:iam::021847444320:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/C5A14CCA66E2AF45967E0A2B49079B1C"
iam_federated_role_name  = "arn:aws:iam::021847444320:role/AWSReservedSSO_AdministratorAccess_d856cb421c5265d1"

################################
# VPC
################################
creation_enabled     = false
vpc_name             = "platform"
cidr_block           = "10.0.128.0/18"
public_subnet_cidrs  = ["10.0.128.0/22", "10.0.132.0/22", "10.0.136.0/22"]
private_subnet_cidrs = ["10.0.144.0/20", "10.0.160.0/20", "10.0.176.0/20"]
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]

################################
# EKS
################################
cluster_name       = "platform-cluster"
repository_name    = "platform-engineering"

################################
# ALB
################################
load_balancer_name     = "platform"

################################
# SOANRQUBEs
################################
sonarqube_ami_id       = "ami-0eaf46e514bf33723"
sonarqube_rds_username = "sonarqube"

################################
# KEYCLOAK
################################
keycloak_rds_username  = "keycloak"