data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "random_string" "password" {
  length   = 32
  upper    = true
  numeric  = true
  special  = false
}

resource "aws_security_group" "instance" {
  name        = "sgr-sonarqube-cluster"
  description = "Allow all local inbound for Postgres"
  vpc_id      = var.rds_vpc_id

  ingress {
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    cidr_blocks      = var.rds_subnets_cidr_blocks
    ipv6_cidr_blocks = var.rds_ipv6_cidr_blocks
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_subnet_group" "default" {
  name_prefix = "sonarqube-"
  description = "SonarQube RDS Subnet Group"
  subnet_ids  = var.rds_subnet_ids

  tags = {
    Name = "sonarqube-subnet-group"
  }
}

resource "aws_rds_cluster" "database" {
  cluster_identifier     = "sonarqube-cluster"
  database_name          = "sonarqube"
  engine                 = "aurora-postgresql"
  engine_mode            = "provisioned"
  engine_version         = "15"
  network_type           = "DUAL"

  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.instance.id]
  availability_zones     = var.rds_availability_zones

  master_username        = var.rds_username
  master_password        = random_string.password.result

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 3.0
  }

  depends_on = [ 
    aws_security_group.instance
  ]
}

resource "aws_rds_cluster_instance" "instance" {
  count                        = 2
  identifier                   = "sonarqube-db-${count.index}"
  instance_class               = "db.serverless"
  cluster_identifier           = aws_rds_cluster.database.id
  engine                       = aws_rds_cluster.database.engine
  engine_version               = aws_rds_cluster.database.engine_version
  performance_insights_enabled = true

  depends_on = [
    aws_rds_cluster.database
  ]
}

resource "time_static" "tag" {
  triggers = {
    run = "14/10/2023 14:13:00"
  }
}

resource "aws_secretsmanager_secret" "sonarqube_rds_credentials" {
   name                    = "/platform/sonarqube/rds/credentials/${time_static.tag.unix}"
   recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "sonarqube_rds_credentials_version" {
  secret_id = aws_secretsmanager_secret.sonarqube_rds_credentials.id
  secret_string = <<EOF
   {
    "username": "${aws_rds_cluster.database.master_username}",
    "password": "${aws_rds_cluster.database.master_password}"
   }
EOF
}