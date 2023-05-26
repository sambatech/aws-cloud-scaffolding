output out_url_access {
  value = "https://${aws_instance.openvpn.public_ip}:943/admin"
}

output out_server_password {
  value = random_password.password.result
}

output out_server_pem {
  value     = tls_private_key.ssh.private_key_pem
  sensitive = true
}