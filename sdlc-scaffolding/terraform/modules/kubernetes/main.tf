locals {
  iam_role_policy_prefix = "Platform"
}

data "aws_caller_identity" "current" {}

data "aws_iam_role" "federated_role" {
  name = var.eks_federated_role_name
}

data "aws_eks_cluster" "default" {
  count = var.create_eks ? 1 : 0
  name  = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "default" {
  count = var.create_eks ? 1 : 0
  name = module.eks.cluster_id
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
  cluster_ip_family               = "ipv4"
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

  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                    = "Nodes on ephemeral ports"
      protocol                       = "tcp"
      from_port                      = 1025
      to_port                        = 65535
      type                           = "ingress"
      source_node_security_group     = true
    }
    egress_nodes_ephemeral_ports_tcp = {
      description                    = "To node 1025-65535"
      protocol                       = "tcp"
      from_port                      = 1025
      to_port                        = 65535
      type                           = "egress"
      source_node_security_group     = true
    }
  }

  # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all   = {
      description      = "Node to node all ports/protocols"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "ingress"
      self             = true
    }
    egress_all         = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  ##############################################
  # EKS Managed Node Group(s)
  ##############################################
  eks_managed_node_group_defaults = {
    instance_types = ["t3a.micro"]
  }

  eks_managed_node_groups = {
    sonarqube = {
      instance_types = ["t3a.large"]
      disk_size      = 50

      min_size     = 1
      max_size     = 1
      desired_size = 1

      update_config = {
        max_unavailable = 1
      }
    }

    harbor = {
      instance_types = ["t3a.large"]
      disk_size      = 50

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
      rolearn  = data.aws_iam_role.federated_role.arn
      username = data.aws_iam_role.federated_role.name
      groups   = [
        "system:masters", 
        "system:bootstrappers", 
        "system:nodes"
      ]
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