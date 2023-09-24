aws_region               = "us-east-1"
aws_profile              = "platform"

################################
# IAM
################################
# AWS EKS aws-auth config-map don't recognize the full arn role name, so we need to use the short name
# arn:aws:iam::021847444320:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_d856cb421c5265d1
iam_federated_role_name  = "arn:aws:iam::021847444320:role/AWSReservedSSO_AdministratorAccess_d856cb421c5265d1"

################################
# VPC
################################
vpc_creation_enabled     = false
vpc_cidr_block           = "10.0.128.0/18"
vpc_private_subnet_cidrs = ["10.0.144.0/20", "10.0.160.0/20", "10.0.176.0/20"]
vpc_public_subnet_cidrs  = ["10.0.128.0/22", "10.0.132.0/22", "10.0.136.0/22"]
vpc_availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]

################################
# EKS
################################
eks_cluster_name = "platform-eks"

################################
# VPN
################################
# To use this AMI you need to accept the Marketplace terms in console
vpn_ami_id         = "ami-0f95ee6f985388d58"
vpn_username       = "openvpn-sambatech-user"

################################
# SOANRQUBEs
################################
sonarqube_ami_id       = "ami-0eaf46e514bf33723"
sonarqube_rds_username = "sonarqube"