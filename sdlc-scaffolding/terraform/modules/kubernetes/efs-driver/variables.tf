variable eks_vpc_id {
  description = "The VPC reference where the EKS must be created"
}

variable eks_vpc_cidr {
  description = "value of the EKS VPC CIDR"
}

variable "eks_cluster_endpoint" {
  description = "value of the EKS cluster endpoint"
}

variable "eks_cluster_certificate_authority_data" {
  description = "value of the EKS cluster certificate authority data"
}

variable "eks_cluster_name" {
  description = "value of the EKS cluster name"
}

variable "eks_cluster_auth_token" {
  description = "value of the EKS cluster auth token"
}

variable "eks_oidc_provider_arn" {
  description = "value of the EKS OIDC provider ARN"
}