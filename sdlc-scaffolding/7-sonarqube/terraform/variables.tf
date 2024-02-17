variable aws_region {
  description = "The AWS region for creating the infrastructure"
}

variable aws_profile {
  description = "The AWS region for creating the infrastructure"
}

variable vpc_name {
    description = "The name of the VPC"
}

variable cidr_block {
    description = "The VPC reference where the SonarQube must be created"
}

variable cluster_name {
    description = "The EKS cluster name"
}

variable sonarqube_ami_id {
    description = "The AMI ID to use for the SonarQube instance"
}

variable sonarqube_host {

}

variable sonarqube_username {
    description = "The username to use for the SonarQube instance"
}

variable availability_zones {
    description = "value of the SonarQube availability zones"
    type = list
}

variable load_balancer_name {
    description = "value of the ALB name"
}

variable waf_arn {
    description = "value of the WAF ARN"
}

variable keycloak_realm_name {

}

variable keycloak_client_id {
    description = "Keycloak client id for kubernetes access"
}

variable keycloak_client_secret {
    description = "Keycloak client secret for kubernetes access"
}

variable keycloak_host {
    description = "Keycloak hostname"
}