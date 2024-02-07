aws_region  = "us-east-1"
aws_profile = "plataform-videos"

################################
# VPC
################################
vpc_cidr_block           = "10.1.64.0/18"
vpc_private_subnet_cidrs = ["10.1.64.0/20", "10.1.80.0/20", "10.1.96.0/20"]
vpc_public_subnet_cidrs  = ["10.1.112.0/22", "10.1.116.0/22", "10.1.120.0/22"]
vpc_availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]

################################
# EKS
################################
eks_cluster_name = "platform_cluster"

################################
# VPN
################################
# To use this AMI you need to accept the Marketplace terms in console
vpn_ami_id   = "ami-0f95ee6f985388d58"
vpn_username = "openvpn-sambatech-user"

################################
# SOANRQUBEs
################################
sonarqube_ami_id       = "ami-0eaf46e514bf33723"
sonarqube_rds_username = "sonarqube"

################################
# AURORA
################################
aurora_subnets     = ["10.1.123.0/24", "10.1.124.0/24", "10.1.125.0/24"]
engine             = "aurora-mysql"
serverless_cluster = "serverless-cluster"
engine_mode        = "provisioned"
database_version   = "8.0.mysql_aurora.3.05.1"
database_name      = "NomedoBanco"
database_user      = "usuario"
database_password  = "password123"
instance_class     = "db.serverless"

################################
# ECR
################################
ecr-name = "samba-videos-reg"

################################
# HOSTED ZONE
################################
domain-name = "dominio.com"
domain-address = "10.0.0.250"
