provider "kubectl" {
  host                   = element(concat(data.aws_eks_cluster.default[*].endpoint, tolist([""])), 0)
  cluster_ca_certificate = base64decode(element(concat(data.aws_eks_cluster.default[*].certificate_authority.0.data, tolist([""])), 0))
  token                  = element(concat(data.aws_eks_cluster_auth.default[*].token, tolist([""])), 0)
  load_config_file       = false
}

data "aws_region" "current" {}

resource "aws_iam_policy" "eks_fargate_logging_policy" {
  name = "${module.eks.cluster_name}-log-policy"

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
  for_each   = module.eks.fargate_profiles

  role       = each.value.iam_role_name
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
          log_group_name      ${module.eks.cluster_name}-logs
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
    kubectl_manifest.aws_observability_namespace,
    aws_iam_role_policy_attachment.logging_policy_attach
  ]
}