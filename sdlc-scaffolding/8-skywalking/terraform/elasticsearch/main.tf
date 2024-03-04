locals {
  common_prefix = "skywalking"
  elk_domain = "${local.common_prefix}-elk-domain"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "random_string" "password" {
  length      = 32

  lower       = true
  min_lower   = 1
  upper       = true
  min_upper   = 1
  numeric     = true
  min_numeric = 1
  special     = true
  min_special = 1
}

resource "aws_security_group" "instance" {
  name        = "skywalking-es-sg"
  description = "Allow inbound traffic to ElasticSearch from VPC CIDR"
  vpc_id      = var.vpc_id

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = var.subnets_cidr_blocks
    ipv6_cidr_blocks = var.ipv6_cidr_blocks
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

resource "aws_iam_service_linked_role" "role" {
  aws_service_name = "es.amazonaws.com"
}

resource "aws_opensearch_domain" "domain" {
  domain_name    = local.elk_domain
  engine_version = "OpenSearch_2.11"

  domain_endpoint_options {
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  node_to_node_encryption {
    enabled = true
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = var.skywalking_username
      master_user_password = random_string.password.result
    }
  }

  encrypt_at_rest {
    enabled = true
  }

  cluster_config {
      instance_count                = length(var.availability_zones)
      instance_type                 = "r5.large.search"
      zone_awareness_enabled        = true
#     multi_az_with_standby_enabled = true

      zone_awareness_config {
        availability_zone_count = length(var.availability_zones)
      }
  }
  
  vpc_options {
      subnet_ids         = var.subnets_ids
      security_group_ids = [aws_security_group.instance.id]
  }
  
  ebs_options {
      ebs_enabled = true
      volume_type = "gp3"
      volume_size = 100
  }
  
  access_policies = <<-CONFIG
    {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Action": "es:*",
              "Principal": "*",
              "Effect": "Allow",
              "Resource": "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${local.elk_domain}/*"
          }
      ]
    }
  CONFIG

  snapshot_options {
      automated_snapshot_start_hour = 23
  }

  tags = {
      Domain = local.elk_domain
  }

  depends_on = [
    aws_iam_service_linked_role.role
  ]
}

resource "time_static" "tag" {
  triggers = {
    run = sha1(join("-", [var.skywalking_username, random_string.password.result]))
  }
}

resource "aws_secretsmanager_secret" "skywalking_elastic_credentials" {
   name                    = "/platform/skywalking/elastic/credentials/${time_static.tag.unix}"
   recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "skywalking_credentials_version" {
  secret_id = aws_secretsmanager_secret.skywalking_elastic_credentials.id
  secret_string = <<-EOF
  {
    "username": "${var.skywalking_username}",
    "password": "${random_string.password.result}"
  }
  EOF
}