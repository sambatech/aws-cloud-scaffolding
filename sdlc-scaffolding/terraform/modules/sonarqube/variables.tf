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

variable sonarqube_subnets_cidr_blocks {
    description = "value of the SonarQube subnet cidr blocks"
    type = list
}

variable sonarqube_availability_zones {
    description = "value of the SonarQube availability zones"
    type = list
}

variable sonarqube_efs_sg_id {
    description = "value of the SonarQube EFS security group id"
}