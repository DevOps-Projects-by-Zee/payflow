# ============================================
# PayFlow Hub VPC Module
# ============================================
# Purpose: Hub VPC with VPC endpoints for cost optimization
# Pattern: Hub-and-Spoke architecture (shared services)
# Cost Optimization: VPC endpoints reduce NAT Gateway traffic by ~$32/month
#
# VPC Endpoints Explained:
# - Gateway Endpoints (S3, DynamoDB): FREE, no data transfer costs
# - Interface Endpoints (ECR, Secrets Manager): ~$7/month per endpoint per AZ
# - Benefit: Private traffic to AWS services doesn't go through NAT Gateway
#
# Why This Matters:
# - NAT Gateway: $32/month + $0.045/GB data transfer
# - VPC Endpoints: Reduce NAT Gateway usage by routing AWS service traffic privately
# - Cost Savings: ~$32/month for high-traffic scenarios

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ============================================
# VPC: Hub Network Foundation
# ============================================
# Hub VPC hosts shared services accessible by all spoke VPCs
# CIDR: 10.0.0.0/16 (allows 65,536 IP addresses)

resource "aws_vpc" "hub" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true # Required for EKS
  enable_dns_support   = true # Required for EKS

  tags = merge(var.tags, {
    Name = "${var.project_name}-hub-vpc"
    Type = "hub"
  })
}

# ============================================
# Internet Gateway: Public Internet Access
# ============================================
# Only needed for bastion host and NAT Gateway
# Private subnets don't need direct internet access

resource "aws_internet_gateway" "hub" {
  vpc_id = aws_vpc.hub.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-hub-igw"
  })
}

# ============================================
# Public Subnets: Bastion Host + NAT Gateway
# ============================================
# Purpose: Host bastion host for secure EKS access
# Multi-AZ: For high availability (bastion can failover)

resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.hub.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true # Required for bastion host

  tags = merge(var.tags, {
    Name = "${var.project_name}-hub-public-${count.index + 1}"
    Type = "public"
    Tier = "bastion"
  })
}

# ============================================
# Private Subnets: EKS Cluster + Services
# ============================================
# Purpose: Host EKS cluster nodes (no public IPs)
# Multi-AZ: Required for high availability
# EKS Requirement: Minimum 2 AZs for control plane

resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.hub.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.project_name}-hub-private-${count.index + 1}"
    Type = "private"
    Tier = "eks"
    # EKS Requirement: Kubernetes needs to identify subnets
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# ============================================
# Elastic IPs: For NAT Gateway
# ============================================
# Purpose: Static IP for NAT Gateway
# Cost: Free (when attached to running NAT Gateway)

resource "aws_eip" "nat" {
  count = var.single_nat_gateway ? 1 : length(var.availability_zones)

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.project_name}-hub-nat-eip-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.hub]
}

# ============================================
# NAT Gateway: Outbound Internet Access
# ============================================
# Purpose: Allow private subnets to access internet (for container image pulls)
# Cost Optimization: Single NAT Gateway for dev, Multi-AZ for prod
# Cost: $32/month + $0.045/GB data transfer
#
# Why We Need It:
# - EKS nodes need to pull container images from ECR (if not using VPC endpoint)
# - CloudWatch logs need internet access
# - Package managers (npm, pip) need internet access
#
# Cost Reduction Strategy:
# - Use VPC endpoints for ECR (container images) → saves NAT Gateway traffic
# - Use VPC endpoints for CloudWatch Logs → saves NAT Gateway traffic
# - Result: NAT Gateway only used for actual internet traffic, not AWS service traffic

resource "aws_nat_gateway" "hub" {
  count = var.single_nat_gateway ? 1 : length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id # NAT Gateway in public subnet

  tags = merge(var.tags, {
    Name = "${var.project_name}-hub-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.hub]
}

# ============================================
# Route Tables: Network Traffic Routing
# ============================================

# Public Route Table: Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.hub.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hub.id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-hub-public-rt"
  })
}

# Public Subnet Association
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables: NAT Gateway (if not using VPC endpoints)
resource "aws_route_table" "private" {
  count = var.single_nat_gateway ? 1 : length(var.availability_zones)

  vpc_id = aws_vpc.hub.id

  # Route to NAT Gateway for internet access
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.hub[count.index].id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-hub-private-rt-${count.index + 1}"
  })
}

# Private Subnet Association
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}

# ============================================
# VPC Endpoints: Cost Optimization
# ============================================
# Purpose: Private connectivity to AWS services (no NAT Gateway traffic)
# Cost Savings: ~$32/month by reducing NAT Gateway data transfer
#
# How VPC Endpoints Work:
# - Gateway Endpoints: Route traffic privately to S3/DynamoDB (FREE)
# - Interface Endpoints: ENI in your VPC that routes to AWS services (~$7/month per AZ)
# - Result: AWS service traffic stays within AWS network, doesn't go through NAT Gateway

# ============================================
# Gateway Endpoint: S3 (FREE)
# ============================================
# Purpose: Private access to S3 (Terraform state, container images)
# Cost: FREE (no data transfer charges)
# Why: S3 traffic doesn't go through NAT Gateway, saves $0.045/GB

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.hub.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  # Route table association: Private subnets can access S3 directly
  route_table_ids = concat(
    [aws_route_table.private[0].id],
    var.single_nat_gateway ? [] : slice(aws_route_table.private[*].id, 1, length(aws_route_table.private))
  )

  tags = merge(var.tags, {
    Name = "${var.project_name}-hub-s3-endpoint"
    Type = "gateway-endpoint"
  })
}

# ============================================
# Gateway Endpoint: DynamoDB (FREE)
# ============================================
# Purpose: Private access to DynamoDB (state locking)
# Cost: FREE (no data transfer charges)

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.hub.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [aws_route_table.private[0].id],
    var.single_nat_gateway ? [] : slice(aws_route_table.private[*].id, 1, length(aws_route_table.private))
  )

  tags = merge(var.tags, {
    Name = "${var.project_name}-hub-dynamodb-endpoint"
    Type = "gateway-endpoint"
  })
}

# ============================================
# Interface Endpoint: ECR API (Cost: ~$7/month per AZ)
# ============================================
# Purpose: Private access to ECR API (authentication, image metadata)
# Cost: ~$7/month per AZ + $0.01/GB data transfer (vs $0.045/GB via NAT Gateway)
# Why: Container image pulls don't go through NAT Gateway
# Savings: Significant for high-traffic scenarios

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.hub.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true # Automatically resolves ECR URLs to private IPs

  tags = merge(var.tags, {
    Name = "${var.project_name}-hub-ecr-api-endpoint"
    Type = "interface-endpoint"
  })
}

# ============================================
# Interface Endpoint: ECR DKR (Docker Registry)
# ============================================
# Purpose: Private access to ECR Docker registry (actual image pulls)
# Cost: ~$7/month per AZ + $0.01/GB data transfer

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.hub.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-hub-ecr-dkr-endpoint"
    Type = "interface-endpoint"
  })
}

# ============================================
# Interface Endpoint: Secrets Manager
# ============================================
# Purpose: Private access to Secrets Manager (API keys, passwords)
# Cost: ~$7/month per AZ
# Why: Secrets retrieval doesn't go through NAT Gateway

resource "aws_vpc_endpoint" "secrets_manager" {
  vpc_id              = aws_vpc.hub.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-hub-secretsmanager-endpoint"
    Type = "interface-endpoint"
  })
}

# ============================================
# Interface Endpoint: CloudWatch Logs
# ============================================
# Purpose: Private access to CloudWatch Logs (application logs)
# Cost: ~$7/month per AZ
# Why: Log streaming doesn't go through NAT Gateway

resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = aws_vpc.hub.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-hub-cloudwatch-logs-endpoint"
    Type = "interface-endpoint"
  })
}

# ============================================
# Security Group: VPC Endpoints
# ============================================
# Purpose: Allow HTTPS traffic from private subnets to VPC endpoints
# Why: Interface endpoints require security group rules

resource "aws_security_group" "vpc_endpoint" {
  name_prefix = "${var.project_name}-hub-vpc-endpoint-"
  vpc_id      = aws_vpc.hub.id
  description = "Security group for VPC endpoints (allows HTTPS from private subnets)"

  # Allow HTTPS from private subnets
  ingress {
    description = "HTTPS from private subnets"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-hub-vpc-endpoint-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}


