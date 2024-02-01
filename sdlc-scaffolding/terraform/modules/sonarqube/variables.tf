variable "sonarqube_vpc" {}
variable "sonarqube_ami_id" {}
variable "sonarqube_username" {}
variable "sonarqube_subnets" {
  type = list(any)
}
variable "sonarqube_availability_zones" {
  type = list(any)
}