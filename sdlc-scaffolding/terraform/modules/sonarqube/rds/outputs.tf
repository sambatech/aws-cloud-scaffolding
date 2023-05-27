output out_database_password {
  value     = random_string.password.result
}

output out_database_endpoint {
  value     = aws_db_instance.database.endpoint
}