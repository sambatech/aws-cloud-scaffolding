resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-data-pipe"
  }
}

resource "aws_subnet" "public_subnets" {
  count             = length(var.vpc_public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.vpc_public_subnet_cidrs, count.index)
  availability_zone = element(var.vpc_availability_zones, count.index)


  tags = {
    Name = "subnet-data-pipe-pub-${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.vpc_private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.vpc_private_subnet_cidrs, count.index)
  availability_zone = element(var.vpc_availability_zones, count.index)

  tags = {
    Name = "subnet-data-pipe-priv-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw-data-pipe"
  }
}

resource "aws_route_table" "secondary_rtb" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "rtb-data-pipe-secondary"
  }
}

resource "aws_route_table_association" "public_subnet_asso" {
  count          = length(var.vpc_public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.secondary_rtb.id
}
