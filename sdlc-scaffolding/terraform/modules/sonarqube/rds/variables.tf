variable rds_vpc_id {
    description = "The VPC reference where the RDS must be created"
}

variable rds_subnet_ids {
    description = "value of the SonarQube subnet ids"
    type = list
}

variable rds_subnets_cidr_blocks {
    description = "value of the SonarQube subnet cidr blocks"
    type = list
}

variable rds_ipv6_cidr_blocks {
    description = "value of the SonarQube subnet ipv6 cidr blocks"
    type = list
}

variable rds_username {
    description = "The username to use for the RDS instance"
}

variable rds_availability_zones {
    description = "value of the RDS availability zones"
    type = list
}