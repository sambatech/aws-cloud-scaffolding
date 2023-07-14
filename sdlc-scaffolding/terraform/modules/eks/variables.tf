variable eks_cluster_name {
  description = "The name of the EKS cluster"
}

variable eks_vpc_cidr_block {
  description = "The VPC CIDR block"
  type        = string
}

variable eks_subnets {
  description = "The VPC subnet list"
  type        = list
}