terraform {
  required_version = ">= 0.15"
  
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

resource "aws_iam_policy" "additional" {
  name = "${var.cluster_name}-additional"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.2"

  cluster_name                             = var.cluster_name
  vpc_id                                   = data.aws_vpc.instance.id
  subnet_ids                               = data.aws_subnets.query.ids
  cluster_version                          = "1.29"
  cluster_ip_family                        = lower(var.cluster_ip_family) == "ipv4" ? "ipv4" : "ipv6"
  enable_irsa                              = true
  cluster_endpoint_public_access           = true
  cluster_endpoint_private_access          = true
  create_cni_ipv6_iam_policy               = true
  enable_cluster_creator_admin_permissions = true
  # Fargate profiles use the cluster primary security group so these are not utilized
  create_cluster_security_group            = false
  create_node_security_group               = false

  # https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html
  cluster_addons = {
    coredns = {
      preserve    = true
      most_recent = true
      timeouts = {
        create = "25m"
        delete = "10m"
      }
      configuration_values = jsonencode({
        computeType = "Fargate"
        resources = {
          limits = {
            cpu = "0.25"
            memory = "256M"
          }
          requests = {
            cpu = "0.25"
            memory = "256M"
          }
        }
      })
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

  fargate_profile_defaults = {
    iam_role_additional_policies = {
      additional = aws_iam_policy.additional.arn
    }
  }

  eks_managed_node_groups = {
    # Node group used only by addons, because some of them doesn't support fargate profiles
    cluster_addons = {
      capacity_type     = "SPOT"
      
      # @see https://aws.amazon.com/pt/ec2/spot/instance-advisor/
      # @see https://docs.aws.amazon.com/ec2/latest/instancetypes/ec2-nitro-instances.html
      #
      # You need to use this command to discover the instance types
      #
      # aws --profile platform --region us-east-1 ec2 describe-instance-types \
      #    --filters "Name=supported-usage-class,Values=spot" "Name=hypervisor,Values=nitro" "Name=bare-metal,Values=false" "Name=processor-info.supported-architecture,Values=x86_64" \
      #    --query "InstanceTypes" \
      #    --output json | jq ".[] | [.VCpuInfo.DefaultVCpus, .VCpuInfo.DefaultCores, .MemoryInfo.SizeInMiB, .InstanceType] | @csv" | sort
      #

      instance_types    = ["t3.small", "t3a.small", "t3.medium", "t3a.medium"]
      disk_size         = 20
      min_size          = 3
      max_size          = 10
      desired_size      = 3
    }
  }

  # See https://docs.aws.amazon.com/eks/latest/userguide/fargate-pod-configuration.html
  fargate_profiles = {
    default-fargate = {
      selectors = [
        { namespace = "default" }
      ]
    }
  }
}

data "aws_eks_cluster" "default" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "default" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = element(concat(data.aws_eks_cluster.default[*].endpoint, tolist([""])), 0)
  cluster_ca_certificate = base64decode(element(concat(data.aws_eks_cluster.default[*].certificate_authority.0.data, tolist([""])), 0))
  token                  = element(concat(data.aws_eks_cluster_auth.default[*].token, tolist([""])), 0)
}

# @see https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1_data
resource "kubernetes_config_map_v1_data" "aws_auth" {
  force = true

  data = {
    "mapRoles" = <<-EOT
      - groups:
        - system:masters
        rolearn: ${var.iam_federated_role_name}
        username: AWSReservedSSO-AdministratorAccess-Role
      - groups:
        - system:bootstrappers
        - system:nodes
        - system:node-proxier
        rolearn: arn:aws:iam::021847444320:role/default-fargate-20240306114145114700000006
        username: system:node:{{SessionName}}
    EOT
  }

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
}

module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name_prefix               = "AmazonEKSVPCCNIRole-"
  attach_vpc_cni_policy          = true
  vpc_cni_enable_ipv4            = true
  vpc_cni_enable_ipv6            = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}

data "template_file" "kube_config_template" {
  template = "${file("${path.module}/templates/kube_config.yml")}"
  vars = {
    aws_region                         = var.aws_region
    aws_profile                        = var.aws_profile
    cluster_name                       = module.eks.cluster_name
    cluster_endpoint                   = module.eks.cluster_endpoint
    cluster_certificate_authority_data = module.eks.cluster_certificate_authority_data
  }
}

resource "local_file" "kube_config" {
  filename = pathexpand("~/.kube/${module.eks.cluster_name}")
  content  = data.template_file.kube_config_template.rendered
}