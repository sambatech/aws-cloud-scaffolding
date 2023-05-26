variable vpn_aws_profile {
  description = "The AWS region for creating the infrastructure"
}

variable vpn_subnet {
  description = "The Subnet reference where the VPN must be created"
}

variable vpn_ami_id {
  description = "AWS AMI IDs for OpenVPN images"
}

variable vpn_server_username {
  description = "Username used to enter the VPN Console configuration"
}