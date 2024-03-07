output "out_hostname" {
  value = aws_opensearch_domain.domain.0.endpoint
}

output "out_username" {
  value = var.skywalking_username
}

output "out_password" {
  sensitive = true
  value = random_string.password.result
}
