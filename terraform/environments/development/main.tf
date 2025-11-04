# ============================================
# PayFlow Development Environment
# ============================================
# Purpose: Development workloads with cost optimization
# Pattern: Hub-and-Spoke architecture (development spoke)
# Cost: ~$50/month (single AZ + Spot instances)
# CIDR: 10.2.0.0/16 (no conflicts with Hub 10.0.0.0/16 or Production 10.1.0.0/16)
#
# Cost Optimizations:
# - Single NAT Gateway (vs Multi-AZ)
# - Spot instances for EKS nodes
# - Single-AZ RDS
# - Smaller instance types

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Values provided via -backend-config=backend-config.hcl
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "development"
      ManagedBy   = "terraform"
      Purpose     = "development-workloads"
      CostCenter  = "development"
    }
  }
}

data "terraform_remote_state" "hub" {
  backend = "s3"

  config = {
    bucket = var.terraform_state_bucket
    key    = "hub/terraform.tfstate"
    region = var.aws_region
  }
}

locals {
  development_vpc_cidr = "10.2.0.0/16" # No conflict with Hub (10.0.0.0/16) or Production (10.1.0.0/16)

  common_tags = {
    Project     = var.project_name
    Environment = "development"
    ManagedBy   = "terraform"
    Purpose     = "development-workloads"
    CostCenter  = "development"
  }

  # EKS node group configuration
  # Development: Single AZ, Spot instances for cost savings
  eks_node_groups = {
    dev-spot = {
      instance_types = ["t3.small", "t3.medium"]
      min_size       = 0 # Can scale to zero for cost savings
      max_size       = 3
      desired_size   = 1
      capacity_type  = "SPOT" # Cost savings: ~50% cheaper
      disk_size      = 20
    }
  }
}

resource "aws_kms_key" "development" {
  description             = "${var.project_name} Development Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true # Security: Rotate key annually

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-development-key"
  })
}

resource "aws_kms_alias" "development" {
  name          = "alias/${var.project_name}-development"
  target_key_id = aws_kms_key.development.key_id
}

module "development_vpc" {
  source = "../../modules/spoke-vpc"

  project_name       = var.project_name
  environment        = "development"
  vpc_cidr           = local.development_vpc_cidr
  aws_region         = var.aws_region
  availability_zones = var.availability_zones
  single_nat_gateway = true # Cost optimization: Single NAT Gateway

  tags = local.common_tags
}

module "vpc_peering" {
  source = "../../modules/vpc-peering"

  project_name          = var.project_name
  spoke_environment     = "development"
  hub_vpc_id            = data.terraform_remote_state.hub.outputs.vpc_id
  hub_vpc_cidr          = data.terraform_remote_state.hub.outputs.vpc_cidr
  hub_route_table_ids   = data.terraform_remote_state.hub.outputs.private_route_table_ids
  spoke_vpc_id          = module.development_vpc.vpc_id
  spoke_vpc_cidr        = module.development_vpc.vpc_cidr_block
  spoke_route_table_ids = module.development_vpc.private_route_table_ids

  tags = local.common_tags

  depends_on = [module.development_vpc]
}

module "development_eks" {
  source = "../../modules/eks-cluster"

  project_name              = var.project_name
  environment               = "development"
  vpc_id                    = module.development_vpc.vpc_id
  private_subnet_ids        = module.development_vpc.private_subnet_ids
  kubernetes_version        = var.kubernetes_version
  kms_key_arn               = aws_kms_key.development.arn
  bastion_security_group_id = data.terraform_remote_state.hub.outputs.bastion_security_group_id
  node_key_pair_name        = var.node_key_pair_name
  node_groups               = local.eks_node_groups

  tags = local.common_tags

  depends_on = [module.development_vpc]
}

module "secrets_manager" {
  source = "../../modules/secrets-manager"

  project_name = var.project_name
  environment  = "development"
  kms_key_id   = aws_kms_key.development.key_id
  kms_key_arn  = aws_kms_key.development.arn
  db_host      = ""
  db_port      = "5432"
  db_name      = "payflow"
  redis_host   = ""
  redis_port   = "6379"

  tags = local.common_tags
}

# RDS: Single-AZ for cost optimization
resource "aws_db_subnet_group" "development" {
  name       = "${var.project_name}-development-db-subnet"
  subnet_ids = module.development_vpc.database_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-development-db-subnet"
  })
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-development-rds-"
  vpc_id      = module.development_vpc.vpc_id
  description = "Security group for RDS PostgreSQL"

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.development_eks.cluster_security_group_id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-development-rds-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "development" {
  identifier = "${var.project_name}-development-postgres"

  engine            = "postgres"
  engine_version    = "15.4"
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = "payflow"
  username = "payflow"
  password = module.secrets_manager.db_password

  db_subnet_group_name   = aws_db_subnet_group.development.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Single-AZ for cost optimization
  multi_az            = false
  publicly_accessible = false

  backup_retention_period = 3 # Fewer backups for dev
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  storage_encrypted = true
  kms_key_id        = aws_kms_key.development.arn

  enabled_cloudwatch_logs_exports = ["postgresql"]
  monitoring_interval             = 0 # Disable monitoring for cost savings

  skip_final_snapshot = true # No final snapshot for dev

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-development-postgres"
  })

  depends_on = [
    aws_db_subnet_group.development,
    aws_security_group.rds,
    module.secrets_manager
  ]
}

# Redis: Single node for cost optimization
resource "aws_elasticache_subnet_group" "development" {
  name       = "${var.project_name}-development-redis-subnet"
  subnet_ids = module.development_vpc.private_subnet_ids[*]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-development-redis-subnet"
  })
}

resource "aws_security_group" "redis" {
  name_prefix = "${var.project_name}-development-redis-"
  vpc_id      = module.development_vpc.vpc_id
  description = "Security group for ElastiCache Redis"

  ingress {
    description     = "Redis from EKS nodes"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [module.development_eks.cluster_security_group_id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-development-redis-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elasticache_replication_group" "development" {
  replication_group_id = "${var.project_name}-development-redis"
  description          = "Redis cluster for development"

  engine               = "redis"
  engine_version       = "7.0"
  node_type            = var.redis_node_type
  port                 = 6379
  parameter_group_name = "default.redis7"

  # Single node for cost optimization
  num_cache_clusters         = 1
  automatic_failover_enabled = false
  multi_az_enabled           = false

  auth_token = module.secrets_manager.redis_auth_token

  subnet_group_name  = aws_elasticache_subnet_group.development.name
  security_group_ids = [aws_security_group.redis.id]

  snapshot_retention_limit = 1 # Fewer snapshots for dev
  snapshot_window          = "03:00-05:00"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-development-redis"
  })

  depends_on = [
    aws_elasticache_subnet_group.development,
    aws_security_group.redis,
    module.secrets_manager
  ]
}

