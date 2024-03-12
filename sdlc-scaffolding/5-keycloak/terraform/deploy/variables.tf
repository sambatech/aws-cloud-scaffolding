variable aws_profile {
    description = "value of the AWS profile"
}

variable deploy_vpc_id {
    description = "value of the VPC id"
}

variable deploy_subnet_ids {
    description = "value of the VPC subnet ids"
    type = list
}

variable deploy_cidr_blocks {
    description = "value of the VPC cidr blocks"
}

variable deploy_ipv6_cidr_blocks {
    description = "value of the VPC ipv6 cidr blocks"
}

variable deploy_eks_cluster_endpoint {
    description = "value of the EKS cluster endpoint"
}

variable deploy_eks_cluster_certificate_authority_data {
    description = "value of the EKS cluster certificate authority data"
}

variable deploy_eks_cluster_auth_token {
    description = "value of the EKS cluster auth token"
}

variable deploy_cluster_name {

}

variable deploy_cluster_version {

}

variable cluster_ip_family {

}

variable deploy_cluster_primary_security_group_id {

}

variable deploy_cluster_security_group_ids {

}

variable deploy_logging_policy_name {
    
}

variable deploy_jdbc_username {
    description = "The username to use for the SonarQube instance"
}

variable deploy_jdbc_password {
    description = "The password to use for the SonarQube instance"
}

variable deploy_jdbc_hostname {
    description = "The jdbc url to use for the SonarQube instance"
}

variable deploy_jdbc_port {
    description = "The jdbc port to use for the SonarQube instance"
}

variable deploy_alb_name {
    description = "value of the ALB name"
}

variable deploy_waf_arn {
    description = "value"
}

variable repository_name {
    description = "value of the registry url"
}

variable keycloak_host {
    
}