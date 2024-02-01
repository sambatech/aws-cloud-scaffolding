aws_region  = "us-east-1"
aws_profile = "platform"

################################
# VPC
################################
vpc_cidr_block           = "10.0.0.0/16"
vpc_private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
vpc_public_subnet_cidrs  = ["10.0.121.0/24", "10.0.122.0/24", "10.0.123.0/24"]
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
aurora_subnets     = ["10.0.131.0/24", "10.0.132.0/24", "10.0.133.0/24"]
engine             = "aurora-mysql"
serverless_cluster = "serverless-cluster"
engine_mode        = "provisioned"
database_version   = "8.0.mysql_aurora.3.05.1"
database_name      = "NomedoBanco"
database_user      = "usuario"
database_password  = "password123"
instance_class     = "db.serverless"