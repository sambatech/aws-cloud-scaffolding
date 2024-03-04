output "elk_endpoint" {
  value = aws_opensearch_domain.domain.endpoint
}

output "elk_password" {
  sensitive = true
  value = random_string.password.result
}

output "elk_clustername" {
  value = local.elk_domain
}