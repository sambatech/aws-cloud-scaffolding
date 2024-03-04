aws_region               = "us-east-1"
aws_profile              = "platform"

################################
# IAM
################################
# AWS EKS aws-auth config-map don't recognize the full arn role name, so we need to use the short name
#              fullname  =  arn:aws:iam::021847444320:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_d856cb421c5265d1
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
cluster_name        = "platform-cluster"
repository_name     = "platform-engineering"

################################
# ALB
################################
load_balancer_name  = "platform"
waf_arn             = "arn:aws:wafv2:us-east-1:021847444320:regional/webacl/platform-cluster-web-acl/5c3bf15a-78e1-4621-b95f-ac6ad00dd641"

################################
# SOANRQUBEs
################################
sonarqube_host     = "sonar.sambatech.net"
sonarqube_ami_id   = "ami-0eaf46e514bf33723"
sonarqube_username = "sonarqube"

################################
# KEYCLOAK
################################
keycloak_realm_name    = "samba"
keycloak_client_id     = "kubernetes"
keycloak_client_secret = "i6UJ40JCb71JvHk15f3pmABfNFsd570X"
keycloak_host          = "sso.sambatech.net"
keycloak_rds_username  = "keycloak"

################################
# SKYWALKING
################################
skywalking_username = "skywalking"