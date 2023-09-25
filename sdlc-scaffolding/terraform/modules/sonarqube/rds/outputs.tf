output out_database_username {
  value     = aws_rds_cluster.database.master_username
}

output out_database_password {
  value     = aws_rds_cluster.database.master_password
}

output out_database_hostname {
  value     = aws_db_proxy.cluster_proxy.endpoint
}

output out_database_port {
  value     = aws_db_proxy_target.cluster_proxy_target.port
}