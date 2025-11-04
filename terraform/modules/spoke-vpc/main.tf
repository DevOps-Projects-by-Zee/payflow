# ============================================
# PayFlow Spoke VPC Module
# ============================================
# Purpose: Spoke VPC for production/development workloads
# Pattern: Hub-and-Spoke architecture (spoke connects to hub)
# CIDR Blocks: Production (10.1.0.0/16), Development (10.2.0.0/16)
#
# Why Spoke VPC:
# - Isolate workloads by environment
# - Connect to Hub VPC for shared services (ECR, Secrets Manager)
# - Cost: Production uses Multi-AZ, Development uses Single-AZ

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ============================================
# VPC: Spoke Network Foundation
# ============================================

resource "aws_vpc" "spoke" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true # Required for EKS
  enable_dns_support   = true # Required for EKS

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-vpc"
    Type = "spoke"
  })
}

# ============================================
# Internet Gateway: Public Internet Access
# ============================================

resource "aws_internet_gateway" "spoke" {
  vpc_id = aws_vpc.spoke.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-igw"
  })
}

# ============================================
# Public Subnets: NAT Gateway Only
# ============================================

resource "aws_subnet" "public" {
  count = var.single_nat_gateway ? 1 : length(var.availability_zones)

  vpc_id                  = aws_vpc.spoke.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false # NAT Gateway doesn't need public IPs

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-public-${count.index + 1}"
    Type = "public"
    Tier = "nat"
  })
}

# ============================================
# Private Subnets: EKS Cluster + RDS + Redis
# ============================================

resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.spoke.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name                              = "${var.project_name}-${var.environment}-private-${count.index + 1}"
    Type                              = "private"
    Tier                              = "eks"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# ============================================
# Database Subnets: RDS PostgreSQL
# ============================================
# Purpose: Isolated subnets for RDS (better security)

resource "aws_subnet" "database" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.spoke.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 20)
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-database-${count.index + 1}"
    Type = "database"
    Tier = "rds"
  })
}

# ============================================
# Elastic IPs: For NAT Gateway
# ============================================

resource "aws_eip" "nat" {
  count = var.single_nat_gateway ? 1 : length(var.availability_zones)

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-nat-eip-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.spoke]
}

# ============================================
# NAT Gateway: Outbound Internet Access
# ============================================

resource "aws_nat_gateway" "spoke" {
  count = var.single_nat_gateway ? 1 : length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.spoke]
}

# ============================================
# Route Tables: Network Traffic Routing
# ============================================

# Public Route Table: Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.spoke.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.spoke.id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-public-rt"
  })
}

# Public Subnet Association
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables: NAT Gateway + Hub VPC
resource "aws_route_table" "private" {
  count = var.single_nat_gateway ? 1 : length(var.availability_zones)

  vpc_id = aws_vpc.spoke.id

  # Route to NAT Gateway for internet access
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.spoke[count.index].id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-private-rt-${count.index + 1}"
  })
}

# Private Subnet Association
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}

# Database Route Tables: NAT Gateway + Hub VPC
resource "aws_route_table" "database" {
  count = var.single_nat_gateway ? 1 : length(var.availability_zones)

  vpc_id = aws_vpc.spoke.id

  # Route to NAT Gateway (for RDS updates, backups)
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.spoke[count.index].id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-database-rt-${count.index + 1}"
  })
}

# Database Subnet Association
resource "aws_route_table_association" "database" {
  count = length(aws_subnet.database)

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.database[0].id : aws_route_table.database[count.index].id
}

# ============================================
# Gateway Endpoint: S3 (FREE)
# ============================================

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.spoke.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [aws_route_table.private[0].id],
    var.single_nat_gateway ? [] : slice(aws_route_table.private[*].id, 1, length(aws_route_table.private))
  )

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-s3-endpoint"
    Type = "gateway-endpoint"
  })
}

# ============================================
# Gateway Endpoint: DynamoDB (FREE)
# ============================================

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.spoke.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [aws_route_table.private[0].id],
    var.single_nat_gateway ? [] : slice(aws_route_table.private[*].id, 1, length(aws_route_table.private))
  )

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-dynamodb-endpoint"
    Type = "gateway-endpoint"
  })
}

