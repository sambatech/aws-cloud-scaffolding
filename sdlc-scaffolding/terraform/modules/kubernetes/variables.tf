variable aws_profile {
  description = "The AWS profile to use"
}

variable eks_cluster_name {
  description = "The name of the EKS cluster"
}

variable eks_federated_role_name {
  description = "The ARN of the IAM role to assume"
}

variable eks_vpc_id {
  description = "The VPC reference where the EKS must be created"
}

variable eks_subnet_ids {
  description = "The VPC subnet list"
  type        = list
}

variable eks_cidr_blocks {
  description = "value of the EKS cluster CIDR blocks"
  type        = list
}

variable eks_ipv6_cidr_blocks {
  description = "value of the EKS cluster ipv6 CIDR blocks"
  type        = list
}

variable eks_registry_url {
  description = "The URL of the ECR registry"
}