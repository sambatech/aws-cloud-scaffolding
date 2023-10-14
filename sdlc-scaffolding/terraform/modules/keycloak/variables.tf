variable keycloak_rds_username {
    description = "value of the keycloak rds username"
}

variable keycloak_vpc_id {
    description = "The VPC reference where the keycloak must be created"
}

variable keycloak_subnet_ids {
    description = "value of the keycloak subnet ids"
    type = list
}

variable keycloak_cidr_blocks {
    description = "value of the keycloak subnet cidr blocks"
    type = list
}

variable keycloak_ipv6_cidr_blocks {
    description = "value of the keycloak subnet ipv6 cidr blocks"
    type = list
}

variable keycloak_availability_zones {
    description = "value of the keycloak availability zones"
    type = list
}

variable keycloak_eks_cluster_endpoint {
    description = "value of the EKS cluster endpoint"
}

variable keycloak_eks_cluster_certificate_authority_data {
    description = "value of the EKS cluster certificate authority data"
}

variable keycloak_eks_cluster_auth_token {    
    description = "value of the EKS cluster auth token"
}

variable keycloak_alb_name {
    description = "value of the ALB name"
}

variable keycloak_waf_arn {
    description = "value"
}