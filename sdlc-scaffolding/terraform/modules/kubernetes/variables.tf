variable create_eks {
  description = "Create EKS cluster"
  default     = true
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