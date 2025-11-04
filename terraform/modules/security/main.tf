# ============================================
# PayFlow Security Module
# ============================================
# Purpose: Shared security infrastructure for Hub environment
# Includes: S3 backend, DynamoDB locking, ECR, Secrets Manager, Bastion host
# Cost: ~$15/month (ECR free, S3/DynamoDB pay-per-use, Bastion ~$7/month)
#
# Why This Module:
# - Creates backend infrastructure that other environments will use
# - Centralizes shared services (ECR, Secrets Manager)
# - Provides secure access to EKS via bastion host

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# ============================================
# S3 Backend Bucket: Terraform State Storage
# ============================================
# NOTE: Backend bucket is created by init-backend.sh BEFORE Terraform runs
# This module uses data sources to reference the existing bucket
# Purpose: Store Terraform state files remotely (enables collaboration)
# Security: Encrypted with KMS, versioning enabled, lifecycle policies
# Cost: ~$1/month for state files (very small storage)

# Data source: Get existing S3 bucket (created by init-backend.sh)
# Bucket name is passed via variable (from backend-config.hcl)
data "aws_s3_bucket" "terraform_state" {
  bucket = var.terraform_state_bucket
}

# Data source: Get existing KMS key (created by init-backend.sh)
data "aws_kms_key" "terraform_state" {
  key_id = "alias/${var.project_name}-terraform-state"
}

# Data source: Get existing DynamoDB table (created by init-backend.sh)
data "aws_dynamodb_table" "terraform_locks" {
  name = "${var.project_name}-terraform-locks"
}

# Note: Backend resources are managed by init-backend.sh script
# This ensures they exist BEFORE Terraform runs, preventing chicken-and-egg problems

# ============================================
# ECR: Container Registry
# ============================================
# Purpose: Store Docker images for PayFlow services
# Cost: FREE (storage and transfer costs are minimal)
# Why: Private registry, faster image pulls, secure

resource "aws_ecr_repository" "payflow" {
  for_each = toset([
    "api-gateway",
    "auth-service",
    "wallet-service",
    "transaction-service",
    "notification-service",
    "frontend"
  ])

  name                 = "${var.project_name}/${each.value}"
  image_tag_mutability = "IMMUTABLE" # Security: Prevent tag overwriting

  image_scanning_configuration {
    scan_on_push = true # Scan images for vulnerabilities automatically
  }

  encryption_configuration {
    encryption_type = "AES256" # Free encryption
  }

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${each.value}"
    Service = each.value
  })
}

# ECR Lifecycle Policy: Delete old images (cost optimization)
resource "aws_ecr_lifecycle_policy" "payflow" {
  for_each = aws_ecr_repository.payflow

  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images, delete older ones"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# ============================================
# Secrets Manager: Application Secrets
# ============================================
# Purpose: Store secrets securely (database passwords, API keys)
# Cost: $0.40/month per secret + $0.05 per 10,000 API calls
# Why: Secure secret storage, automatic rotation support

# Note: Secrets are created manually or via application code
# This just creates the KMS key for encryption

resource "aws_kms_key" "secrets_manager" {
  description             = "KMS key for Secrets Manager encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true # Security: Rotate key annually

  tags = merge(var.tags, {
    Name = "${var.project_name}-secrets-manager-key"
  })
}

resource "aws_kms_alias" "secrets_manager" {
  name          = "alias/${var.project_name}-secrets-manager"
  target_key_id = aws_kms_key.secrets_manager.key_id
}

# ============================================
# Bastion Host: Secure EKS Access
# ============================================
# Purpose: Secure SSH access to EKS cluster (private endpoint only)
# Cost: ~$7/month (t3.micro instance)
# Why: EKS has private endpoint only, bastion provides secure access
#
# How It Works:
# 1. User connects to bastion via SSH
# 2. From bastion, user runs kubectl commands
# 3. kubectl connects to EKS private endpoint
# 4. No public internet exposure

# IAM Role for Bastion: Allows EKS cluster access
resource "aws_iam_role" "bastion" {
  count = var.bastion_enabled ? 1 : 0

  name = "${var.project_name}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-bastion-role"
  })
}

# IAM Policy: Allow bastion to describe EKS clusters (needed for kubectl)
# Enhanced IAM Policy: Bastion EKS and monitoring access
resource "aws_iam_role_policy" "bastion_eks_access" {
  count = var.bastion_enabled ? 1 : 0

  name = "${var.project_name}-bastion-eks-access"
  role = aws_iam_role.bastion[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:DescribeUpdate",
          "eks:ListUpdates",
          "eks:DescribeAddon",
          "eks:ListAddons"
        ]
        Resource = var.eks_cluster_arn != "" ? [var.eks_cluster_arn] : ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "secretsmanager:ResourceTag/Project" = var.project_name
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/bastion/*"
      }
    ]
  })
}

# IAM Instance Profile: Attach role to EC2 instance
resource "aws_iam_instance_profile" "bastion" {
  count = var.bastion_enabled ? 1 : 0

  name = "${var.project_name}-bastion-profile"
  role = aws_iam_role.bastion[0].name

  tags = merge(var.tags, {
    Name = "${var.project_name}-bastion-profile"
  })
}

resource "aws_instance" "bastion" {
  count = var.bastion_enabled ? 1 : 0

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.bastion_instance_type
  key_name               = var.bastion_key_pair_name
  subnet_id              = var.public_subnet_ids[0] # Bastion in public subnet
  vpc_security_group_ids = [aws_security_group.bastion[0].id]
  iam_instance_profile   = aws_iam_instance_profile.bastion[0].name # Attach IAM role

  # Force IMDSv2 for security (prevents SSRF attacks)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Require IMDSv2
    http_put_response_hop_limit = 1
  }

  # User data: Install kubectl, AWS CLI, etc.
  user_data = file("${path.module}/bastion_user_data.sh")

  tags = merge(var.tags, {
    Name    = "${var.project_name}-bastion"
    Purpose = "eks-access"
  })
}

# Bastion Security Group: Allow SSH from allowed IPs only
resource "aws_security_group" "bastion" {
  count = var.bastion_enabled ? 1 : 0

  name_prefix = "${var.project_name}-bastion-"
  vpc_id      = var.vpc_id
  description = "Security group for bastion host (SSH access)"

  # SSH access from allowed CIDRs only
  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_allowed_cidrs
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-bastion-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Amazon Linux 2 AMI for bastion
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ============================================
# Route53 Private Zone: Internal DNS (Optional)
# ============================================
# Purpose: Internal service discovery within VPC
# Cost: $0.50/month per zone
# Why: Easy service discovery (prometheus.payflow.aws instead of IP addresses)

resource "aws_route53_zone" "private" {
  count = var.create_private_zone ? 1 : 0

  name = var.private_zone_name

  vpc {
    vpc_id = var.vpc_id
  }

  tags = merge(var.tags, {
    Name    = "${var.project_name}-private-zone"
    Purpose = "internal-dns"
  })
}


