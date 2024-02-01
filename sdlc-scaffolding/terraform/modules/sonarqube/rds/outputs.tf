output "out_database_password" {
  value = random_string.password.result
}

output "out_database_endpoint" {
  value = aws_rds_cluster.database.endpoint
}