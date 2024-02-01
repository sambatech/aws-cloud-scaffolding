variable "aurora_subnets" {
  description = "Lista de VPC"
}

variable "main_vpc" {
  description = "VPC Principal"
}

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