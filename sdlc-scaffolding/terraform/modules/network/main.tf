data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0"

  name = "platform"
  cidr = var.vpc_cidr_block

  azs             = var.vpc_availability_zones
  public_subnets  = var.vpc_public_subnet_cidrs
  private_subnets = var.vpc_private_subnet_cidrs

  enable_ipv6            = true
  enable_nat_gateway     = true
  create_egress_only_igw = true
  one_nat_gateway_per_az = true
  single_nat_gateway     = false

  public_subnet_ipv6_prefixes                    = [0, 1, 2]
  public_subnet_assign_ipv6_address_on_creation  = true
  private_subnet_ipv6_prefixes                   = [3, 4, 5]
  private_subnet_assign_ipv6_address_on_creation = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
    "kubernetes.io/cluster/${var.vpc_eks_cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "kubernetes.io/cluster/${var.vpc_eks_cluster_name}" = "shared"
  }
}