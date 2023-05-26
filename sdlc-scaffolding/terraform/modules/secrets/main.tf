resource "aws_secretsmanager_secret" "vpn_credentials" {
   name                    = "/${var.secret_aws_profile}/ec2/openvpn/credentials"
   recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "vpn_credentials_version" {
  secret_id = aws_secretsmanager_secret.vpn_credentials.id
  secret_string = <<EOF
   {
    "username": "${var.secret_server_username}",
    "password": "${var.secret_server_password}"
   }
EOF
}

resource "aws_secretsmanager_secret" "vpn_server_pem" {
   name                    = "/${var.secret_aws_profile}/ec2/openvpn/pem"
   recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "vpn_server_pem_version" {
  secret_id = aws_secretsmanager_secret.vpn_server_pem.id
  secret_string = var.secret_server_pem
}