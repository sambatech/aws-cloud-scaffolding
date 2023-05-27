resource "random_string" "password" {
  length   = 32
  upper    = true
  numeric  = true
  special  = false
}

resource "aws_security_group" "instance" {
  vpc_id      = var.rds_vpc.id
  name        = "sgr-sonarqube-db"
  description = "Allow all local inbound for Postgres"

  ingress {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = var.rds_subnets.*.cidr_block
    }
}

resource "aws_db_subnet_group" "default" {
  name       = "sonarqube-subnet-group"
  subnet_ids = var.rds_subnets.*.id

  tags = {
    Name = "sonarqube-subnet-group"
  }
}

resource "aws_db_instance" "database" {
  identifier             = "sonarqube-db"
  db_name                = "sonarqube"
  instance_class         = "db.t3.medium"
  allocated_storage      = 5
  max_allocated_storage  = 100
  engine                 = "postgres"
  engine_version         = "15"
  skip_final_snapshot    = true
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.instance.id]
  username               = var.rds_username
  password               = random_string.password.result
}