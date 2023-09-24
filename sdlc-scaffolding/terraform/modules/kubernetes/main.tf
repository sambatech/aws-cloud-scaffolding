data "aws_caller_identity" "current" {}

resource "aws_security_group" "remote_access" {
  name_prefix = "nodes-remote-access"
  description = "Allow remote SSH access"
  vpc_id      = var.eks_vpc_id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
}

resource "aws_key_pair" "this" {
  key_name_prefix = "eks-nodes-key-pair"
  public_key      = tls_private_key.this.public_key_openssh
}

data "aws_eks_cluster" "default" {
  name  = coalesce(module.eks.cluster_id, var.eks_cluster_name)
}

data "aws_eks_cluster_auth" "default" {
  name  = coalesce(module.eks.cluster_id, var.eks_cluster_name)
}

provider "kubernetes" {
  host                   = element(concat(data.aws_eks_cluster.default[*].endpoint, tolist([""])), 0)
  cluster_ca_certificate = base64decode(element(concat(data.aws_eks_cluster.default[*].certificate_authority.0.data, tolist([""])), 0))
  token                  = element(concat(data.aws_eks_cluster_auth.default[*].token, tolist([""])), 0)
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.16"

  cluster_name                    = var.eks_cluster_name
  vpc_id                          = var.eks_vpc_id
  subnet_ids                      = var.eks_subnet_ids
  cluster_version                 = "1.27"
  cluster_ip_family               = "ipv6"
  enable_irsa                     = true
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  create_cni_ipv6_iam_policy      = true

  cluster_addons = {
    coredns = {
      preserve    = true
      most_recent = true
      timeouts = {
        create = "25m"
        delete = "10m"
      }
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent              = true
      before_compute           = true
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
      configuration_values     = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  ##############################################
  # EKS Managed Node Group(s)
  ##############################################
  eks_managed_node_group_defaults = {
    ami_type                   = "AL2_x86_64"
    instance_types             = ["t3a.micro"]

    # We are using the IRSA created below for permissions
    # However, we have to deploy with the policy attached FIRST (when creating a fresh cluster)
    # and then turn this off after the cluster/node group is created. Without this initial policy,
    # the VPC CNI fails to assign IPs and nodes cannot join the cluster
    # See https://github.com/aws/containers-roadmap/issues/1666 for more context
    iam_role_attach_cni_policy = true
  }

  eks_managed_node_groups = {
    sonarqube = {
      iam_role_attach_cni_policy = true

      instance_types = ["t3a.large"]
      disk_size      = 20

      min_size     = 1
      max_size     = 1
      desired_size = 1


      update_config = {
        max_unavailable = 1
      }
    }

    harbor = {
      iam_role_attach_cni_policy = true

      instance_types = ["t3a.large"]
      disk_size      = 20

      min_size     = 1
      max_size     = 1
      desired_size = 1

      update_config = {
        max_unavailable = 1
      }
    }
  }

  # aws-auth configmap
  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      rolearn  = var.eks_federated_role_name
      username = "sso_admin_role"
      groups   = ["system:masters"]
    },
  ]

  aws_auth_users = [
    {
      userarn  = data.aws_caller_identity.current.arn
      username = data.aws_caller_identity.current.user_id
      groups   = ["system:masters"]
    }
  ]

  aws_auth_accounts = [
    data.aws_caller_identity.current.account_id
  ]
}

module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix      = "VPC-CNI-IRSA"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv6   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}

module "efs" {
  source = "./efs-driver"

  eks_vpc_id                             = var.eks_vpc_id
  eks_vpc_cidr                           = var.eks_vpc_cidr
  eks_cluster_name                       = var.eks_cluster_name
  eks_oidc_provider_arn                  = module.eks.oidc_provider_arn
  eks_cluster_endpoint                   = element(concat(data.aws_eks_cluster.default[*].endpoint, tolist([""])), 0)
  eks_cluster_auth_token                 = element(concat(data.aws_eks_cluster_auth.default[*].token, tolist([""])), 0)
  eks_cluster_certificate_authority_data = base64decode(element(concat(data.aws_eks_cluster.default[*].certificate_authority.0.data, tolist([""])), 0))
}