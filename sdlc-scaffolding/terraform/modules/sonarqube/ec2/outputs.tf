output out_server_pem {
  value     = tls_private_key.ssh.private_key_pem
  sensitive = true
}