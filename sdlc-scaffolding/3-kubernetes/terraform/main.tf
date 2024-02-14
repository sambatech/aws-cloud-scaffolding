terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.36"
    }
  }
  backend "s3" {
    profile = "platform"
    bucket = "plat-engineering-terraform-st"
    key    = "sdlc/kubernetes.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

data "aws_vpc" "instance" {
  cidr_block = var.cidr_block
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_subnets" "query" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.instance.id]
  }
  filter {
    name   = "tag:subnet/kind"
    values = ["private"]
  }
}

data "aws_subnet" "instance" {
  for_each = toset(data.aws_subnets.query.ids)
  id       = each.value
}

resource "aws_security_group" "remote_access" {
  name_prefix = "nodes-remote-access"
  description = "Allow remote SSH access"
  vpc_id      = data.aws_vpc.instance.id

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

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.2"

  cluster_name                     = var.cluster_name
  vpc_id                           = data.aws_vpc.instance.id
  subnet_ids                       = data.aws_subnets.query.ids
  cluster_version                  = "1.29"
  cluster_ip_family                = "ipv6"
  enable_irsa                      = true
  cluster_endpoint_public_access   = true
  cluster_endpoint_private_access  = true
  create_cni_ipv6_iam_policy       = true

  enable_cluster_creator_admin_permissions = true

  # https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html
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
          AWS_VPC_K8S_CNI_EXTERNALSNAT = "true"
          ENABLE_PREFIX_DELEGATION     = "true"
          WARM_PREFIX_TARGET           = "1"
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
    aws-efs-csi-driver = {
      most_recent = true
    }
  }

  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
  }

  ##############################################
  # EKS Managed Node Group(s)
  ##############################################
  eks_managed_node_group_defaults = {
    ami_type                   = "AL2_x86_64"
    # @see https://aws.amazon.com/pt/ec2/spot/instance-advisor/
    # @see https://docs.aws.amazon.com/ec2/latest/instancetypes/ec2-nitro-instances.html
    instance_types             = ["t3a.small","t3.small","c7i.large","c6i.large","c5a.large","c6in.large","c5ad.large"]


    # We are using the IRSA created below for permissions
    # However, we have to deploy with the policy attached FIRST (when creating a fresh cluster)
    # and then turn this off after the cluster/node group is created. Without this initial policy,
    # the VPC CNI fails to assign IPs and nodes cannot join the cluster
    # See https://github.com/aws/containers-roadmap/issues/1666 for more context
    iam_role_attach_cni_policy            = true
    iam_role_use_name_prefix              = false
    attach_cluster_primary_security_group = true

    iam_role_additional_policies = {
      AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      AmazonEFSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
    }
  }

  eks_managed_node_groups = {
    # Default node group - as provided by AWS EKS
    default = {
      capacity_type     = "SPOT"
      # @see https://aws.amazon.com/pt/ec2/spot/instance-advisor/
      # @see https://docs.aws.amazon.com/ec2/latest/instancetypes/ec2-nitro-instances.html
      instance_types    = ["t3a.small","t3.small","c7i.large","c6i.large","c5a.large","c6in.large","c5ad.large"]
      disk_size         = 20
      min_size          = 1
      max_size          = 3
      desired_size      = 1
    }
  }
}

module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name_prefix               = "VPC-CNI-IRSA"
  attach_vpc_cni_policy          = true
  vpc_cni_enable_ipv6            = true
  vpc_cni_enable_ipv4            = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}