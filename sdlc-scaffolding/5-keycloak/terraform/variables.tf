variable aws_region {
  description = "The AWS region for creating the infrastructure"
}

variable aws_profile {
  description = "The AWS region for creating the infrastructure"
}

variable cluster_name {
    description = "The EKS Cluster name"
}

variable cluster_ip_family {

}

variable cluster_logging_policy_name {

}

variable cidr_block {

}

variable vpc_name {

}

variable keycloak_rds_username {
    description = "value of the keycloak rds username"
}

variable availability_zones {
    description = "value of the keycloak availability zones"
    type = list
}

variable load_balancer_name {
    description = "value of the ALB name"
}

variable waf_arn {
    description = "value"
}

variable repository_name {
    description = "ECR repository name"
}

variable keycloak_host {
    
}