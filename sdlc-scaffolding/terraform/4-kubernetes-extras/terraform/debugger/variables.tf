variable aws_profile {
    description = "The AWS profile to use"
}

variable registry_url {
    description = "The URL of the ECR registry"
}

variable debugger_eks_cluster_endpoint {
    description = "value of the EKS cluster endpoint"
}

variable debugger_eks_cluster_certificate_authority_data {
    description = "value of the EKS cluster certificate authority data"
}

variable debugger_eks_cluster_auth_token {
    description = "value of the EKS cluster auth token"
}