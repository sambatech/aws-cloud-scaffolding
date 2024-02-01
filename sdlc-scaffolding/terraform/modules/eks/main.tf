resource "aws_iam_role" "platform_cluster_role" {
  name = "EKSClusterRole"
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
  name = "EKSNodeGroupRole"
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

  role       = aws_iam_role.platform_cluster_role.name
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

  role       = aws_iam_role.platform_nodegroup_role.name
  policy_arn = each.value
}

resource "aws_eks_cluster" "eks_cluster" {
  name                      = var.eks_cluster_name
  version                   = "1.29"
  role_arn                  = aws_iam_role.platform_cluster_role.arn
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_config {
    subnet_ids              = var.eks_subnets.*.id
    endpoint_private_access = true
    # endpoint_public_access = false
    # public_access_cidrs    = ["0.0.0.0/0"]

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
    client_id                     = substr(data.tls_certificate.eks_cluster_certificate.url, -32, -1)
    issuer_url                    = data.tls_certificate.eks_cluster_certificate.url
  }
}


module "addons" {
  source = "./addons"

  eks_cluster_name = aws_eks_cluster.eks_cluster.name
}

# resource "aws_security_group_rule" "eks_sg_ingress_rule" {
#   cidr_blocks = ["0.0.0.0/0"]
#   from_port   = 22
#   to_port     = 22
#   protocol    = "tcp"

#   security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
#   type              = "ingress"
# }

resource "aws_eks_node_group" "reservada" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "reservada"
  node_role_arn   = aws_iam_role.platform_nodegroup_role.arn
  subnet_ids      = var.eks_subnets.*.id

  ami_type       = "AL2_x86_64"
  capacity_type  = "ON_DEMAND"
  disk_size      = 20
  instance_types = ["t2.small"]


  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.platform_nodegroup_policies_attachment
  ]

}

resource "aws_eks_node_group" "spot" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "spot"
  node_role_arn   = aws_iam_role.platform_nodegroup_role.arn
  subnet_ids      = var.eks_subnets.*.id

  ami_type       = "AL2_x86_64"
  capacity_type  = "SPOT"
  disk_size      = 20
  instance_types = ["t2.small"]


  scaling_config {
    desired_size = 4
    max_size     = 4
    min_size     = 4
  }

  update_config {
    max_unavailable = 2
  }

  depends_on = [
    aws_iam_role_policy_attachment.platform_nodegroup_policies_attachment
  ]

}

