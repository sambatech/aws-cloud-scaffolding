output "out_url_access" {
  value = "https://${aws_instance.openvpn.public_ip}:943/admin"
}
