variable aws_region {
  description = "The AWS region for creating the infrastructure"
}

variable aws_profile {
  description = "The AWS region for creating the infrastructure"
}

################################
# VPC
################################
variable vpc_cidr_block {
  description = "The CIDR block for the VPC to use"
}

variable vpc_private_subnet_cidrs {
  type        = list(string)
  description = "Private Subnet CIDR values"
}

variable vpc_public_subnet_cidrs {
  type        = list(string)
  description = "Public Subnet CIDR values"
}

variable vpc_availability_zones {
  type        = list(string)
  description = "Availability Zones"
}

################################
# VPN
################################
variable vpn_ami_id {
  description = "AWS AMI IDs for OpenVPN images"
}

variable vpn_server_username {
  description = "Username used to enter the VPN Console configuration"
}