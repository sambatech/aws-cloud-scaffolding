resource "aws_secretsmanager_secret" "vpn_credentials" {
   name                    = "/${var.secret_aws_profile}/ec2/openvpn/credentials"
   recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "vpn_credentials_version" {
  secret_id = aws_secretsmanager_secret.vpn_credentials.id
  secret_string = <<EOF
   {
    "username": "${var.secret_vpn_username}",
    "password": "${var.secret_vpn_password}"
   }
EOF
}

resource "aws_secretsmanager_secret" "vpn_pem" {
   name                    = "/${var.secret_aws_profile}/ec2/openvpn/pem"
   recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "vpn_pem_version" {
  secret_id     = aws_secretsmanager_secret.vpn_pem.id
  secret_string = var.secret_vpn_pem
}

resource "aws_secretsmanager_secret" "sonarqube_pem" {
   name                    = "/ec2/sonarqube/pem"
   recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "sonarqube_pem_version" {
  secret_id     = aws_secretsmanager_secret.sonarqube_pem.id
  secret_string = var.secret_vpn_pem
}

resource "aws_secretsmanager_secret" "sonarqube_rds_credentials" {
   name                    = "/rds/sonarqube/credentials"
   recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "sonarqube_rds_credentials_version" {
  secret_id = aws_secretsmanager_secret.sonarqube_rds_credentials.id
  secret_string = <<EOF
   {
    "username": "${var.secret_sonarqube_rds_username}",
    "password": "${var.secret_sonarqube_rds_password}"
   }
EOF
}