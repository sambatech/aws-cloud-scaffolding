resource "aws_rds_cluster" "serverless_cluster" {
  cluster_identifier     = var.serverless_cluster
  engine                 = var.engine
  engine_mode            = var.engine_mode
  engine_version         = var.database_version
  database_name          = var.database_name
  master_username        = var.database_user
  master_password        = var.database_password
  vpc_security_group_ids = [aws_security_group.sg_rds.id]
  db_subnet_group_name   = aws_db_subnet_group.subnet_group.name
  skip_final_snapshot    = true
  deletion_protection    = false

  serverlessv2_scaling_configuration {
    max_capacity = 1.0
    min_capacity = 0.5
  }
}

resource "aws_rds_cluster_instance" "serverless-instance" {
  cluster_identifier = aws_rds_cluster.serverless_cluster.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.serverless_cluster.engine
  engine_version     = aws_rds_cluster.serverless_cluster.engine_version
}


resource "aws_security_group" "sg_rds" {
  name        = "sg_rds"
  description = "RDS Serveless"
  vpc_id      = var.main_vpc.id


}

resource "aws_db_subnet_group" "subnet_group" {
  name       = "subnet_rds"
  subnet_ids = [var.aurora_subnets[0].id, var.aurora_subnets[1].id, var.aurora_subnets[2].id]

  tags = {
    Name = "subnet-group-rds"
  }
}
