variable rds_vpc_id {
    description = "The VPC reference where the RDS must be created"
}
variable rds_subnet_ids {
    type = list
}
variable rds_subnets_cidr_blocks {
    type = list
}
variable rds_username {}
variable rds_availability_zones {
    type = list
}