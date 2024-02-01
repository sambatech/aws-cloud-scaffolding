output "out_database_password" {
  value     = module.rds.out_database_password
  sensitive = true
}