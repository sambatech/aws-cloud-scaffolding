resource "aws_iam_role" "platform_cluster_role" {
  name               = "EKSClusterRole"
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = [
              "eks.amazonaws.com"
            ]
          }
        }
      ]
    }
  )
}

resource "aws_iam_role" "platform_nodegroup_role" {
  name               = "EKSNodeGroupRole"
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
  name = "EKSClusterCloudwatchPolicy"
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

resource "aws_iam_role_policy_attachment" "platform_cluster_policies_attachment" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  ])

  role       = aws_iam_role.platform_cluster_role.id
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "platform_nodegroup_policies_attachment" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSServicePolicy",
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
  ])

  role       = aws_iam_role.platform_nodegroup_role.id
  policy_arn = each.value
}

resource "aws_eks_cluster" "eks_cluster" {
  name                      = var.eks_cluster_name
  version                   = "1.27"
  role_arn                  = aws_iam_role.platform_cluster_role.arn
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_config {
    subnet_ids              = var.eks_subnets.*.id
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.platform_cluster_policies_attachment
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
  name               = "EKSClusterAssumeRoleWithWebIdentity"
}

resource "aws_eks_identity_provider_config" "eks_oidc_config" {
  cluster_name = var.eks_cluster_name
  oidc {
    identity_provider_config_name = "EKSClusterOIDCProvider"
    client_id  = substr(data.tls_certificate.eks_cluster_certificate.url, -32, -1)
    issuer_url = data.tls_certificate.eks_cluster_certificate.url
  }
}

resource "aws_launch_template" "sonarqube_launch_template" {
  name                   = "sonarqube-launch-template"
  # See https://cloud-images.ubuntu.com/aws-eks/
  image_id               = "ami-034ff84bbdab3860d"
  # See sonarqube requirements prerequisites and overview
  instance_type          = "t3.xlarge"
  ebs_optimized          = true
  update_default_version = true

  network_interfaces {
    associate_public_ip_address = false
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                               = "sonarqube"
      "kubernetes.io/cluster/${aws_eks_cluster.eks_cluster.name}" = "owned"
    }
  }
}

resource "aws_eks_node_group" "sonarqube_node_group" {
  node_group_name = "sonarqube"
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_role_arn   = aws_iam_role.platform_nodegroup_role.arn
  subnet_ids      = var.eks_subnets.*.id

  launch_template {
    id      = aws_launch_template.sonarqube_launch_template.id
    version = aws_launch_template.sonarqube_launch_template.latest_version
  }

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.platform_nodegroup_policies_attachment
  ]
}

module "addons" {
  source = "./addons"

  eks_cluster_name = aws_eks_cluster.eks_cluster.name
}
