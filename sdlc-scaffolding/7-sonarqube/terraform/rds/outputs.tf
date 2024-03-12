output out_database_username {
  value     = aws_rds_cluster.database.master_username
}

output out_database_password {
  value     = aws_rds_cluster.database.master_password
}

output out_database_hostname {
  value     = one([for instance in aws_rds_cluster_instance.instance: instance.endpoint if instance.writer])
}

output out_database_port {
  value     = aws_rds_cluster_instance.instance.0.port
}