variable aws_region {
  description = "The AWS region for creating the infrastructure"
}

variable aws_profile {
  description = "The AWS region for creating the infrastructure"
}

variable vpc_name {
  description = "The VPC name"
}

variable cidr_block {
  description = "The CIDR block for the VPC to use"
}

variable private_subnet_cidrs {
 type        = list(string)
 description = "Private Subnet CIDR values"
}

variable public_subnet_cidrs {
 type        = list(string)
 description = "Public Subnet CIDR values"
}

variable availability_zones {
 type        = list(string)
 description = "Availability Zones"
}

variable cluster_name {
  description = "The name of the EKS cluster"
}