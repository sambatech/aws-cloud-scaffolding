variable efs_vpc_id {
  description = "value of the EKS VPC id"
}

variable efs_vpc_cidr {
  description = "value of the EKS VPC cidr"
}

variable efs_subnet_ids {
  description = "value of the EFS mount target subnet ids"
}

variable efs_eks_cluster_endpoint {
    description = "value of the EKS cluster endpoint"
}

variable efs_eks_cluster_certificate_authority_data {
    description = "value of the EKS cluster certificate authority data"
}

variable efs_eks_cluster_auth_token {
    description = "value of the EKS cluster auth token"
}