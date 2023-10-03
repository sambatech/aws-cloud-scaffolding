resource "random_string" "password" {
  length   = 32
  upper    = true
  numeric  = true
  special  = false
}

resource "aws_security_group" "instance" {
  name        = "sgr-sonarqube-cluster"
  vpc_id      = var.rds_vpc_id
  description = "Allow all local inbound for Postgres"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.rds_subnets_cidr_blocks
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_subnet_group" "default" {
  name       = "sonarqube-subnet-group"
  subnet_ids = var.rds_subnet_ids

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

resource "aws_secretsmanager_secret" "sonarqube_rds_credentials" {
   name                    = "/platform/sonarqube/rds/credentials/a"
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

data "aws_iam_policy_document" "rds_proxy_assume_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "rds_proxy_role" {
  name               = "SonarQubeSecretsReaderRole"
  assume_role_policy = data.aws_iam_policy_document.rds_proxy_assume_policy.json

  inline_policy {
    name = "sonarqube_secrets_reader_policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action: [
            "secretsmanager:GetResourcePolicy",
            "secretsmanager:GetSecretValue",
            "secretsmanager:DescribeSecret",
            "secretsmanager:ListSecrets",
            "secretsmanager:ListSecretVersionIds"
          ]
          Effect   = "Allow"
          Resource = aws_secretsmanager_secret.sonarqube_rds_credentials.arn
        },
      ]
    })
  }
}

resource "aws_db_proxy" "cluster_proxy" {
  name                   = "sonarqubeproxy"
  debug_logging          = false
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.rds_proxy_role.arn
  vpc_subnet_ids         = var.rds_subnet_ids
  vpc_security_group_ids = [aws_security_group.instance.id]

  auth {
    auth_scheme = "SECRETS"
    description = "Auth for SonarQube"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.sonarqube_rds_credentials.arn
  }
}

resource "aws_db_proxy_default_target_group" "cluster_proxy_target_group" {
  db_proxy_name = aws_db_proxy.cluster_proxy.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    init_query                   = "SET x=1, y=2"
    max_connections_percent      = 100
    max_idle_connections_percent = 50
    session_pinning_filters      = ["EXCLUDE_VARIABLE_SETS"]
  }
}

resource "aws_db_proxy_target" "cluster_proxy_target" {
  db_proxy_name         = aws_db_proxy.cluster_proxy.name
  db_cluster_identifier = aws_rds_cluster.database.id
  target_group_name     = aws_db_proxy_default_target_group.cluster_proxy_target_group.name
}