locals {
  eks_cluster_name = "platform_cluster"
}

resource "aws_iam_role" "platform_cluster_role" {
  name               = "platform_cluster_role"
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = [
              "eks-fargate-pods.amazonaws.com",
              "eks.amazonaws.com",
            ]
          }
        }
      ]
    }
  )
}

resource "aws_iam_role" "platform_nodegroup_role" {
  name               = "platform_nodegroup_role"
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "ec2.amazonaws.com"
          }
        }
      ]
    }
  )
}

resource "aws_iam_role_policy" "platform_cluster_cloudwatch_policy" {
  name = "platform_cluster_cloudwatch_policy"
  role = aws_iam_role.platform_cluster_role.id
  policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Action = [
            "cloudwatch:PutMetricData"
          ],
          Effect   = "Allow",
          Resource = "*"
        }
      ]
    }
  )
}

resource "aws_iam_role_policy" "platform_nodegroup_autoscaling_policy" {
  name = "platform_nodegroup_autoscaling_policy"
  role = aws_iam_role.platform_nodegroup_role.id
  policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Action = [
            "autoscaling:DescribeAutoScalingGroups",
            "autoscaling:DescribeAutoScalingInstances",
            "autoscaling:DescribeLaunchConfigurations",
            "autoscaling:DescribeTags",
            "autoscaling:SetDesiredCapacity",
            "autoscaling:TerminateInstanceInAutoScalingGroup",
            "ec2:DescribeLaunchTemplateVersions"
          ],
          Effect   = "Allow",
          Resource = "*"
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "platform_cluster_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.platform_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "platform_nodegroup_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.platform_nodegroup_role.id
}

resource "aws_eks_cluster" "eks_cluster" {
  name                      = local.eks_cluster_name
  role_arn                  = aws_iam_role.platform_cluster_role.arn
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = false
    subnet_ids = var.eks_subnets.*.id
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.platform_cluster_policy_attachment,
    aws_iam_role_policy_attachment.platform_nodegroup_policy_attachment,
  ]
}

data "tls_certificate" "eks_cluster_certificate" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = data.tls_certificate.eks_cluster_certificate.certificates[*].sha1_fingerprint
  url             = data.tls_certificate.eks_cluster_certificate.url
}

data "aws_iam_policy_document" "eks_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.oidc_provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.oidc_provider.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "platform_cluster_assume_role" {
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role_policy.json
  name               = "platform_cluster_assume_role"
}

resource "aws_eks_identity_provider_config" "eks_oidc_config" {
  cluster_name = local.eks_cluster_name
  oidc {
    identity_provider_config_name = "platform_oidc_provider"
    client_id  = substr(data.tls_certificate.eks_cluster_certificate.url, -32, -1)
    issuer_url = data.tls_certificate.eks_cluster_certificate.url
  }
}

resource "aws_eks_fargate_profile" "eks_fargate_profile" {
  cluster_name           = aws_eks_cluster.eks_cluster.name
  fargate_profile_name   = "platform_fargate_profile"
  pod_execution_role_arn = aws_iam_role.platform_cluster_role.arn
  subnet_ids             = var.eks_subnets.*.id

  selector {
    namespace = "platform"
  }
}