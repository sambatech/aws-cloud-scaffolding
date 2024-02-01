resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-platform"
  }
}

resource "aws_vpc_dhcp_options" "dhcp_options" {
  domain_name         = "platform.com"
  domain_name_servers = ["AmazonProvidedDNS"]

  tags = {
    Name = "dhcp-platform"
  }
}

resource "aws_vpc_dhcp_options_association" "dns_resolver" {
  vpc_id          = aws_vpc.main.id
  dhcp_options_id = aws_vpc_dhcp_options.dhcp_options.id
}

resource "aws_subnet" "public_subnets" {
  count                   = length(var.vpc_public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.vpc_public_subnet_cidrs, count.index)
  availability_zone       = element(var.vpc_availability_zones, count.index)
  map_public_ip_on_launch = true
  tags = {
    Type                     = "Public_Subnet"
    Name                     = "subnet-platform-pub-${count.index + 1}"
    "kubernetes.io/role/elb" = 1
  }
}

resource "aws_subnet" "private_subnets" {
  count                   = length(var.vpc_private_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.vpc_private_subnet_cidrs, count.index)
  availability_zone       = element(var.vpc_availability_zones, count.index)
  map_public_ip_on_launch = false

  tags = {
    Type                                                = "Private_Subnet"
    Name                                                = "subnet-platform-priv-${count.index + 1}"
    "kubernetes.io/cluster/${var.vpc_eks_cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"                   = 1
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw-platform"
  }
}

resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(aws_subnet.public_subnets[*].id, 0)
  depends_on    = [aws_internet_gateway.igw]

  tags = {
    Name = "nat-platform"
  }
}

resource "aws_route_table" "primary_rtb" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "rtb-platform-primary"
  }
}

resource "aws_route_table" "secondary_rtb" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "rtb-platform-secondary"
  }
}

resource "aws_main_route_table_association" "main_route_table_association" {
  vpc_id         = aws_vpc.main.id
  route_table_id = aws_route_table.primary_rtb.id
}

resource "aws_route_table_association" "public_subnet_asso" {
  count          = length(var.vpc_public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.primary_rtb.id
}

resource "aws_route_table_association" "private_subnet_asso" {
  count          = length(var.vpc_private_subnet_cidrs)
  subnet_id      = element(aws_subnet.private_subnets[*].id, count.index)
  route_table_id = aws_route_table.secondary_rtb.id
}

resource "aws_vpc_endpoint" "vpc_gateway_endpoints" {
  for_each = toset([
    "com.amazonaws.${var.vpc_aws_region}.s3"
  ])

  service_name      = each.value
  vpc_endpoint_type = "Gateway"
  vpc_id            = aws_vpc.main.id
  route_table_ids = [
    aws_route_table.secondary_rtb.id
  ]

  tags = {
    Name = "vpce-platform-${trimprefix(each.value, "com.amazonaws.${var.vpc_aws_region}.")}"
  }
}

resource "aws_vpc_endpoint" "vpc_interface_endpoints" {
  for_each = toset([
    "com.amazonaws.${var.vpc_aws_region}.ssm",
    "com.amazonaws.${var.vpc_aws_region}.ec2",
    "com.amazonaws.${var.vpc_aws_region}.sts",
    "com.amazonaws.${var.vpc_aws_region}.logs",
    "com.amazonaws.${var.vpc_aws_region}.ecr.api",
    "com.amazonaws.${var.vpc_aws_region}.ecr.dkr",
    "com.amazonaws.${var.vpc_aws_region}.autoscaling",
    "com.amazonaws.${var.vpc_aws_region}.aps-workspaces",
    "com.amazonaws.${var.vpc_aws_region}.elasticloadbalancing",
    "com.amazonaws.${var.vpc_aws_region}.eks-auth",
    "com.amazonaws.${var.vpc_aws_region}.eks"
  ])

  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  vpc_id              = aws_vpc.main.id
  subnet_ids = setunion(
    aws_subnet.private_subnets[*].id,
  )

  tags = {
    Name = "vpce-platform-${trimprefix(each.value, "com.amazonaws.${var.vpc_aws_region}.")}"
  }
}

# resource "aws_vpc_endpoint" "eks_endpoint" {
#   service_name        = "com.amazonaws.${var.vpc_aws_region}.eks"
#   vpc_endpoint_type   = "Interface"
#   vpc_id              = aws_vpc.main.id
#   private_dns_enabled = true
#   subnet_ids          = setunion(aws_subnet.private_subnets[*].id)
#   security_group_ids = [aws_security_group.eks.id]
# }

# resource "aws_vpc_endpoint_route_table_association" "eks" {
#   count = length(aws_subnet.private_subnets)

#   vpc_endpoint_id = aws_vpc_endpoint.eks_endpoint.id
#   route_table_id  = aws_route_table.eks_route.id
# }

# resource "aws_security_group" "eks" {
#   vpc_id      = aws_vpc.main.id
#   name_prefix = "eks-"

#   tags = {
#     "Name"                                              = "eks-cluster-sg-${var.vpc_eks_cluster_name}"
#     "kubernetes.io/cluster/${var.vpc_eks_cluster_name}" = "owned",
#     "aws:eks:cluster-name"                              = var.vpc_eks_cluster_name
#   }
# }

# resource "aws_security_group_rule" "eks" {
#   type              = "ingress"
#   from_port         = 0
#   to_port           = 65535
#   protocol          = "tcp"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = aws_security_group.eks.id
# }

# resource "aws_security_group_rule" "eks_egress" {
#   type              = "egress"
#   from_port         = 0
#   to_port           = 0
#   protocol          = "-1"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = aws_security_group.eks.id
# }