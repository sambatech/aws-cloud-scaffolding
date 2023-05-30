aws_region               = "us-east-1"
aws_profile              = "develop"

################################
# VPC
################################
vpc_cidr_block           = "123.45.0.0/16"
vpc_private_subnet_cidrs = ["123.45.101.0/24", "123.45.103.0/24", "123.45.105.0/24"]
vpc_public_subnet_cidrs  = ["123.45.102.0/24", "123.45.104.0/24", "123.45.106.0/24"]
vpc_availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]

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