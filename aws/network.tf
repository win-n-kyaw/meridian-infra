resource "aws_vpc" "meridian" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "meridian-vpc"
    role = "network"
  })
}

resource "aws_internet_gateway" "meridian" {
  vpc_id = aws_vpc.meridian.id

  tags = merge(local.common_tags, {
    Name = "meridian-igw"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.meridian.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.meridian.id
  }

  tags = merge(local.common_tags, {
    Name = "meridian-public-rt"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.meridian.id

  # Mirrors the current OCI stage behavior (internet-routed private subnet).
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.meridian.id
  }

  tags = merge(local.common_tags, {
    Name = "meridian-private-rt"
  })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.meridian.id
  availability_zone       = local.selected_az
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "meridian-public"
  })
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.meridian.id
  availability_zone       = local.selected_az
  cidr_block              = var.private_subnet_cidr
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "meridian-private"
  })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
