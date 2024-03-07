variable aws_region {
  description = "The AWS region for creating the infrastructure"
}

variable aws_profile {
  description = "The AWS region for creating the infrastructure"
}

variable repository_name {
  description = "The name of ECR repository"
}

variable cluster_name {
  description = "The name of the EKS cluster"
}

variable cluster_logging_policy_name {

}

variable iam_federated_role_name {
  description = "The ARN of the IAM role to assume"
}

variable vpc_name {
  description = "The VPC name"
}

variable cidr_block {
  description = "value of the EKS cluster CIDR blocks"
}