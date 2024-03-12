terraform {
  required_version = ">= 0.13"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}

provider "kubectl" {
  host                   = var.log_eks_cluster_endpoint
  cluster_ca_certificate = var.log_eks_cluster_certificate_authority_data
  token                  = var.log_eks_cluster_auth_token
  load_config_file       = false
}

data "aws_region" "current" {}

module "eks_fargate-profile" {
  source  = "terraform-aws-modules/eks/aws//modules/fargate-profile"
  version = "~> 20.0"

  name         = "aws-observability"
  cluster_name = var.log_cluster_name
  subnet_ids   = var.log_subnet_ids

  selectors = [{
    namespace = "aws-observability"
  }]
}

resource "aws_iam_policy" "eks_fargate_logging_policy" {
  name = var.log_logging_policy_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:PutRetentionPolicy"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "logging_policy_attach" {
  role       = module.eks_fargate-profile.iam_role_name
  policy_arn = aws_iam_policy.eks_fargate_logging_policy.arn
}

resource "kubectl_manifest" "aws_observability_namespace" {
  yaml_body = <<-YAML
  apiVersion: v1
  kind: Namespace
  metadata:
    name: aws-observability
  YAML
}

resource "kubectl_manifest" "log_deployment" {
  yaml_body = <<-YAML
  kind: ConfigMap
  apiVersion: v1
  metadata:
    name: aws-logging
    namespace: aws-observability
  data:
    flb_log_cw: "false"  # Set to true to ship Fluent Bit process logs to CloudWatch.
    filters.conf: |
      [FILTER]
          Name                parser
          Match               *
          Key_name            log
          Parser              crio
      [FILTER]
          Name                kubernetes
          Match               kube.*
          Merge_Log           On
          Keep_Log            Off
          Buffer_Size         0
          Kube_Meta_Cache_TTL 300s
    output.conf: |
      [OUTPUT]
          Name                cloudwatch_logs
          Match               kube.*
          region              ${data.aws_region.current.name}
          log_group_name      my-logs
          log_stream_prefix   from-fluent-bit-
          log_retention_days  60
          auto_create_group   true
    parsers.conf: |
      [PARSER]
          Name                crio
          Format              Regex
          Regex               ^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<logtag>P|F) (?<log>.*)$
          Time_Key            time
          Time_Format         %Y-%m-%dT%H:%M:%S.%L%z
  YAML

  depends_on = [ 
    kubectl_manifest.aws_observability_namespace
  ]
}