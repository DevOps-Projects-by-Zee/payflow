# ============================================
# PayFlow Production Environment
# ============================================
# Purpose: Production workloads with High Availability
# Pattern: Hub-and-Spoke architecture (production spoke)
# Cost: ~$305/month (optimized production setup)
# CIDR: 10.1.0.0/16 (no conflicts with Hub 10.0.0.0/16)
#
# Includes:
# - Production Spoke VPC
# - EKS Cluster (Multi-AZ for HA)
# - RDS PostgreSQL (Multi-AZ)
# - Redis ElastiCache
# - VPC Peering to Hub
# - AWS Secrets Manager integration

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3 Backend: Remote state storage
  backend "s3" {
    # Values provided via -backend-config=backend-config.hcl
  }
}

# ============================================
# Provider Configuration
# ============================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "production"
      ManagedBy   = "terraform"
      Purpose     = "application-workloads"
      CostCenter  = "production-workloads"
    }
  }
}

# ============================================
# Data Sources: Import Hub State
# ============================================
# Purpose: Reference Hub VPC for peering and shared services

data "terraform_remote_state" "hub" {
  backend = "s3"

  config = {
    bucket = var.terraform_state_bucket
    key    = "hub/terraform.tfstate"
    region = var.aws_region
  }
}

# ============================================
# Local Variables
# ============================================

locals {
  production_vpc_cidr = "10.1.0.0/16" # No conflict with Hub (10.0.0.0/16)

  common_tags = {
    Project     = var.project_name
    Environment = "production"
    ManagedBy   = "terraform"
    Purpose     = "application-workloads"
    CostCenter  = "production-workloads"
  }

  # EKS node group configuration
  # Production: Multi-AZ, On-Demand instances for reliability
  eks_node_groups = {
    production = {
      instance_types = ["t3.medium", "t3.large"]
      min_size       = 2
      max_size       = 10
      desired_size   = 3
      capacity_type  = "ON_DEMAND" # Stable for production
      disk_size      = 30
    }
  }
}

# ============================================
# KMS Key: Production Encryption
# ============================================

resource "aws_kms_key" "production" {
  description             = "${var.project_name} Production Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true # Security: Rotate key annually

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-production-key"
  })
}

resource "aws_kms_alias" "production" {
  name          = "alias/${var.project_name}-production"
  target_key_id = aws_kms_key.production.key_id
}

# ============================================
# Production Spoke VPC
# ============================================

module "production_vpc" {
  source = "../../modules/spoke-vpc"

  project_name       = var.project_name
  environment        = "production"
  vpc_cidr           = local.production_vpc_cidr
  aws_region         = var.aws_region
  availability_zones = var.availability_zones
  single_nat_gateway = false # Multi-AZ for HA

  tags = local.common_tags
}

# ============================================
# VPC Peering: Connect to Hub
# ============================================

module "vpc_peering" {
  source = "../../modules/vpc-peering"

  project_name          = var.project_name
  spoke_environment     = "production"
  hub_vpc_id            = data.terraform_remote_state.hub.outputs.vpc_id
  hub_vpc_cidr          = data.terraform_remote_state.hub.outputs.vpc_cidr
  hub_route_table_ids   = data.terraform_remote_state.hub.outputs.private_route_table_ids
  spoke_vpc_id          = module.production_vpc.vpc_id
  spoke_vpc_cidr        = module.production_vpc.vpc_cidr_block
  spoke_route_table_ids = module.production_vpc.private_route_table_ids

  tags = local.common_tags

  depends_on = [module.production_vpc]
}

# ============================================
# Production EKS Cluster
# ============================================

module "production_eks" {
  source = "../../modules/eks-cluster"

  project_name              = var.project_name
  environment               = "production"
  vpc_id                    = module.production_vpc.vpc_id
  private_subnet_ids        = module.production_vpc.private_subnet_ids
  kubernetes_version        = var.kubernetes_version
  kms_key_arn               = aws_kms_key.production.arn
  bastion_security_group_id = data.terraform_remote_state.hub.outputs.bastion_security_group_id
  node_key_pair_name        = var.node_key_pair_name
  node_groups               = local.eks_node_groups

  tags = local.common_tags

  depends_on = [module.production_vpc]
}

# ============================================
# AWS Secrets Manager: Application Secrets
# ============================================
# Note: Created before RDS/Redis so we can use generated passwords

module "secrets_manager" {
  source = "../../modules/secrets-manager"

  project_name = var.project_name
  environment  = "production"
  kms_key_id   = aws_kms_key.production.key_id
  kms_key_arn  = aws_kms_key.production.arn
  db_host      = "" # Will be updated after RDS creation
  db_port      = "5432"
  db_name      = "payflow"
  redis_host   = "" # Will be updated after ElastiCache creation
  redis_port   = "6379"

  tags = local.common_tags
}

# ============================================
# RDS PostgreSQL: Multi-AZ for HA
# ============================================

resource "aws_db_subnet_group" "production" {
  name       = "${var.project_name}-production-db-subnet"
  subnet_ids = module.production_vpc.database_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-production-db-subnet"
  })
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-production-rds-"
  vpc_id      = module.production_vpc.vpc_id
  description = "Security group for RDS PostgreSQL"

  # PostgreSQL access from EKS nodes only
  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.production_eks.cluster_security_group_id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-production-rds-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "production" {
  identifier = "${var.project_name}-production-postgres"

  engine            = "postgres"
  engine_version    = "15.4"
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = "payflow"
  username = "payflow"
  password = module.secrets_manager.db_password # Password from Secrets Manager

  db_subnet_group_name   = aws_db_subnet_group.production.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Multi-AZ for HA
  multi_az            = true
  publicly_accessible = false

  # Backup configuration
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  # Encryption
  storage_encrypted = true
  kms_key_id        = aws_kms_key.production.arn

  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn

  # Performance Insights
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.production.arn

  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-production-postgres-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-production-postgres"
  })

  depends_on = [
    aws_db_subnet_group.production,
    aws_security_group.rds,
    module.secrets_manager
  ]
}

# IAM Role for RDS Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-production-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ============================================
# ElastiCache Redis: High Availability
# ============================================

resource "aws_elasticache_subnet_group" "production" {
  name       = "${var.project_name}-production-redis-subnet"
  subnet_ids = module.production_vpc.private_subnet_ids[*]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-production-redis-subnet"
  })
}

resource "aws_security_group" "redis" {
  name_prefix = "${var.project_name}-production-redis-"
  vpc_id      = module.production_vpc.vpc_id
  description = "Security group for ElastiCache Redis"

  # Redis access from EKS nodes only
  ingress {
    description     = "Redis from EKS nodes"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [module.production_eks.cluster_security_group_id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-production-redis-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elasticache_replication_group" "production" {
  replication_group_id = "${var.project_name}-production-redis"
  description          = "Redis cluster for production"

  engine               = "redis"
  engine_version       = "7.0"
  node_type            = var.redis_node_type
  port                 = 6379
  parameter_group_name = "default.redis7"

  # Multi-AZ for HA
  num_cache_clusters         = 2
  automatic_failover_enabled = true
  multi_az_enabled           = true

  # Auth token from Secrets Manager
  auth_token = module.secrets_manager.redis_auth_token

  subnet_group_name  = aws_elasticache_subnet_group.production.name
  security_group_ids = [aws_security_group.redis.id]

  # Snapshot configuration
  snapshot_retention_limit = 3
  snapshot_window          = "03:00-05:00"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-production-redis"
  })

  depends_on = [
    aws_elasticache_subnet_group.production,
    aws_security_group.redis,
    module.secrets_manager
  ]
}

# ============================================
# Amazon MQ (RabbitMQ) - Managed Message Queue
# ============================================
# Purpose: Replace K8s RabbitMQ with managed service
# Cost: ~$15/month (mq.t3.micro, single AZ) - cost-effective for fintech startup
# Security: Private subnet, no public access

# Security Group for Amazon MQ
resource "aws_security_group" "mq" {
  name_prefix = "${var.project_name}-production-mq-"
  vpc_id      = module.production_vpc.vpc_id
  description = "Security group for Amazon MQ (RabbitMQ)"

  # Allow AMQP from EKS nodes
  ingress {
    description     = "AMQP from EKS nodes"
    from_port       = 5671
    to_port         = 5671
    protocol        = "tcp"
    security_groups = [module.production_eks.cluster_security_group_id]
  }

  # Allow AMQP management from EKS nodes
  ingress {
    description     = "AMQP management from EKS nodes"
    from_port       = 15671
    to_port         = 15671
    protocol        = "tcp"
    security_groups = [module.production_eks.cluster_security_group_id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-production-mq-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

module "amazon_mq" {
  source = "../../modules/amazon-mq"

  broker_name         = "${var.project_name}-production-mq"
  subnet_ids          = module.production_vpc.private_subnet_ids
  security_group_ids  = [aws_security_group.mq.id]
  username            = var.project_name
  password            = module.secrets_manager.rabbitmq_password
  host_instance_type  = "mq.t3.micro"           # Cost-effective for startup
  deployment_mode     = "SINGLE_INSTANCE"       # Cost optimization: Single AZ
  enable_general_logs = false                   # Disable to save costs
  enable_audit_logs  = false                   # Disable to save costs

  tags = local.common_tags

  depends_on = [
    aws_security_group.mq,
    module.secrets_manager
  ]
}

# ============================================
# Application Load Balancer
# ============================================
# Purpose: AWS-native load balancer for cost-effective traffic distribution
# Cost: ~$16/month (standard ALB, minimal data transfer)

module "alb" {
  source = "../../modules/alb"

  alb_name                  = "${var.project_name}-production-alb"
  vpc_id                    = module.production_vpc.vpc_id
  subnet_ids                = module.production_vpc.public_subnet_ids
  internal                  = false
  target_port               = 3000
  health_check_path         = "/health"
  enable_deletion_protection = true  # Production safety
  enable_access_logs         = false # Disable to save costs (~$5/month)
  certificate_arn            = null  # Add ACM certificate ARN for HTTPS

  tags = local.common_tags

  depends_on = [module.production_vpc]
}

# ============================================
# CloudWatch Alarms and SNS
# ============================================
# Purpose: Cost-effective monitoring and alerting
# Cost: ~$2/month (SNS + minimal CloudWatch metrics)

module "monitoring_alerts" {
  source = "../../modules/monitoring-alerts"

  topic_name              = "${var.project_name}-production-alerts"
  resource_name           = "${var.project_name}-production"
  email_endpoint          = var.alert_email # Set in terraform.tfvars
  enable_cpu_alarm        = true
  enable_memory_alarm     = true
  enable_health_alarm      = true
  enable_db_alarm          = true
  cpu_threshold           = 80
  memory_threshold        = 85
  db_connection_threshold = 50
  db_instance_id          = aws_db_instance.production.id
  target_group_arn        = module.alb.target_group_arn
  load_balancer_arn       = module.alb.alb_arn

  tags = local.common_tags

  depends_on = [
    aws_db_instance.production,
    module.alb
  ]
}

