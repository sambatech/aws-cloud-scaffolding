variable aws_region {
    description = "The AWS region to deploy the SonarQube"
}

variable sonarqube_vpc_id {
    description = "The VPC reference where the SonarQube must be created"
}

variable sonarqube_ami_id {
    description = "The AMI ID to use for the SonarQube instance"
}

variable sonarqube_username {
    description = "The username to use for the SonarQube instance"
}

variable sonarqube_subnet_ids {
    description = "value of the SonarQube subnet ids"
    type = list
}

variable sonarqube_cidr_blocks {
    description = "value of the SonarQube subnet cidr blocks"
    type = list
}

variable sonarqube_ipv6_cidr_blocks {
    description = "value of the SonarQube subnet ipv6 cidr blocks"
    type = list
}

variable sonarqube_availability_zones {
    description = "value of the SonarQube availability zones"
    type = list
}

variable sonarqube_eks_cluster_endpoint {
    description = "value of the EKS cluster endpoint"
}

variable sonarqube_eks_cluster_certificate_authority_data {
    description = "value of the EKS cluster certificate authority data"
}

variable sonarqube_eks_cluster_auth_token {    
    description = "value of the EKS cluster auth token"
}

variable sonarqube_alb_name {
    description = "value of the ALB name"
}

variable sonarqube_waf_arn {
    description = "value of the WAF ARN"
}