variable secret_aws_profile {
  description = "The AWS region for creating the infrastructure"
}

variable secret_vpn_username {
  description = "Username used to enter the VPN Console configuration"
}

variable secret_vpn_password {
  description = "Password used to enter the VPN Console configuration"
}

variable secret_vpn_pem {
  description = "Pem used to enter the VM instance"
}

variable secret_sonarqube_pem {}
variable secret_sonarqube_rds_username {}
variable secret_sonarqube_rds_password {}
