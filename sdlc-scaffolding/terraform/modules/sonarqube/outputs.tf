output out_server_pem {
  value     = module.ec2.out_server_pem
  sensitive = true
}

output out_database_password {
  value     = module.rds.out_database_password
  sensitive = true
}