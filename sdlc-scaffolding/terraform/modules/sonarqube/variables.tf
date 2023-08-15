variable sonarqube_vpc_id {}
variable sonarqube_ami_id {}
variable sonarqube_username {}
variable sonarqube_subnet_ids {
    type = list
}
variable sonarqube_subnets_cidr_blocks {
    type = list
}
variable sonarqube_availability_zones {
    type = list
}