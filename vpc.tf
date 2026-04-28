# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc-${var.environment}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw-${var.environment}"
  }
}

# Public Subnets (for MediaConnect VPC interfaces)
resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${each.key}-${var.environment}"
    Type = "public"
  }
}

# Private Subnets (optional, for other resources)
resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = "${var.project_name}-private-${each.key}-${var.environment}"
    Type = "private"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt-${var.environment}"
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Security Group for MediaConnect
resource "aws_security_group" "mediaconnect" {
  name_prefix = "${var.project_name}-mediaconnect-"
  description = "Security group for MediaConnect VPC interfaces"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-mediaconnect-sg-${var.environment}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Allow RTMP inbound (port 1935)
resource "aws_vpc_security_group_ingress_rule" "rtmp" {
  security_group_id = aws_security_group.mediaconnect.id
  description       = "RTMP inbound"
  from_port         = 1935
  to_port           = 1935
  ip_protocol       = "tcp"
  cidr_ipv4         = var.allowed_inbound_cidr
}

# Allow SRT inbound (ports 5000-5999)
resource "aws_vpc_security_group_ingress_rule" "srt" {
  security_group_id = aws_security_group.mediaconnect.id
  description       = "SRT inbound"
  from_port         = 5000
  to_port           = 5999
  ip_protocol       = "udp"
  cidr_ipv4         = var.allowed_inbound_cidr
}

# Allow RTP inbound (ports 5004-5005)
resource "aws_vpc_security_group_ingress_rule" "rtp" {
  security_group_id = aws_security_group.mediaconnect.id
  description       = "RTP inbound"
  from_port         = 5004
  to_port           = 5005
  ip_protocol       = "udp"
  cidr_ipv4         = var.allowed_inbound_cidr
}

# Allow Zixi inbound (ports 2088-2089)
resource "aws_vpc_security_group_ingress_rule" "zixi" {
  security_group_id = aws_security_group.mediaconnect.id
  description       = "Zixi inbound"
  from_port         = 2088
  to_port           = 2089
  ip_protocol       = "udp"
  cidr_ipv4         = var.allowed_inbound_cidr
}

# Allow all outbound
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.mediaconnect.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
