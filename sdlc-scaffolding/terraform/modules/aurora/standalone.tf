# resource "aws_db_instance" "default" {
#   allocated_storage    = 10
#   db_name              = var.database_name
#   engine               = var.engine
#   engine_version       = var.database_version
#   instance_class       = var.instance_class
#   username             = var.database_user
#   password             = var.database_password
#   parameter_group_name = "default.${var.database_version}"
#   skip_final_snapshot  = true
#   deletion_protection = false
# }