variable "vpc_aws_region" {
  description = "The AWS region to deploy to"
}

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

variable vpc_eks_cluster_name {
  description = "The name of the EKS cluster"
}