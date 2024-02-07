variable "aws_region" {
  description = "The AWS region for creating the infrastructure"
}

variable "aws_profile" {
  description = "The AWS region for creating the infrastructure"
}

################################
# VPC
################################
variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC to use"
}

variable "vpc_private_subnet_cidrs" {
  type        = list(string)
  description = "Private Subnet CIDR values"
}

variable "vpc_public_subnet_cidrs" {
  type        = list(string)
  description = "Public Subnet CIDR values"
}

variable "vpc_availability_zones" {
  type        = list(string)
  description = "Availability Zones"
}

################################
# EKS
################################
variable "eks_cluster_name" {
  description = "The name of the EKS cluster"
}

################################
# VPN
################################
variable "vpn_ami_id" {
  description = "AWS AMI IDs for OpenVPN images"
}

variable "vpn_username" {
  description = "Username used to enter the VPN Console configuration"
}

################################
# SONARQUBE
################################
variable "sonarqube_ami_id" {}
variable "sonarqube_rds_username" {}

################################
# AURORA
################################

variable "aurora_subnets" {
  description = "Subnet para Aurora Serverless"
}

# variable "main_vpc" {
#   description = "VPC Principal"
# }

variable "engine" {
  description = "Aurora Engine"
}

variable "serverless_cluster" {
  description = "Identificador do cluster"
}

variable "database_version" {
  description = "Versão do Banco de Dados"
}

variable "database_name" {
  description = "Nome do Banco de Dados"
}

variable "database_user" {
  description = "Usuário do Banco de Dados"
}

variable "database_password" {
  description = "Senha do Banco de Dados"
}

variable "engine_mode" {
  description = "Engine do Banco de Dados"
}

variable "instance_class" {
  description = "Classe da Instancia"
}

#########################################
#       ECR
#########################################

variable "ecr-name" {
  type = string
  description = "Registry de imagens para o EKS"
}

#########################################
# HOSTED ZONE
#########################################

variable "domain-name" {
  description = "Endereço para a zona hospedada"
}

variable "domain-address" {
  description = "Endereço de IP da zona hospedada"
}