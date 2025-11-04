# ============================================
# PayFlow Secrets Manager Module
# ============================================
# Purpose: Create and manage application secrets in AWS Secrets Manager
# Security: All secrets encrypted with KMS, automatic rotation support
# Cost: $0.40/month per secret + $0.05 per 10,000 API calls
#
# Why AWS Secrets Manager:
# - Centralized secret management
# - Automatic rotation support
# - Audit logging
# - Integration with Kubernetes via External Secrets Operator
#
# Secrets Created:
# - Database credentials (RDS PostgreSQL)
# - Redis auth token
# - JWT signing key
# - RabbitMQ credentials

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
# Random Passwords: Generate Secure Secrets
# ============================================
# Purpose: Generate cryptographically secure passwords
# Security: 32 characters, includes uppercase, lowercase, numbers, special chars

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "redis_auth_token" {
  length  = 32
  special = false # Redis auth tokens don't support special characters
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = false # JWT secrets are typically base64-like strings
}

resource "random_password" "rabbitmq_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ============================================
# AWS Secrets Manager: Database Credentials
# ============================================
# Purpose: Store RDS PostgreSQL credentials
# Format: JSON with username and password
# Access: Kubernetes External Secrets Operator syncs to K8s secrets

resource "aws_secretsmanager_secret" "postgres" {
  name                    = "${var.project_name}-${var.environment}-postgres"
  description             = "PostgreSQL database credentials for ${var.environment} environment"
  kms_key_id              = var.kms_key_id
  recovery_window_in_days = 7 # Allow recovery for 7 days after deletion

  # Cross-region replication for disaster recovery
  dynamic "replica" {
    for_each = var.dr_region != "" ? [1] : []
    content {
      region = var.dr_region
    }
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-postgres"
    Purpose     = "database-credentials"
    Type        = "postgres"
    Environment = var.environment
  })
}

resource "aws_secretsmanager_secret_version" "postgres" {
  secret_id = aws_secretsmanager_secret.postgres.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    engine   = "postgres"
    host     = var.db_host
    port     = var.db_port
    dbname   = var.db_name
  })
}

# ============================================
# AWS Secrets Manager: Redis Auth Token
# ============================================

resource "aws_secretsmanager_secret" "redis" {
  name        = "${var.project_name}-${var.environment}-redis"
  description = "Redis authentication token for ${var.environment} environment"
  kms_key_id  = var.kms_key_id

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment}-redis"
    Purpose = "cache-credentials"
    Type    = "redis"
  })
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id = aws_secretsmanager_secret.redis.id
  secret_string = jsonencode({
    auth_token = random_password.redis_auth_token.result
    host       = var.redis_host
    port       = var.redis_port
  })
}

# ============================================
# AWS Secrets Manager: JWT Secret
# ============================================

resource "aws_secretsmanager_secret" "jwt" {
  name        = "${var.project_name}-${var.environment}-jwt"
  description = "JWT signing key for ${var.environment} environment"
  kms_key_id  = var.kms_key_id

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment}-jwt"
    Purpose = "authentication"
    Type    = "jwt"
  })
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id = aws_secretsmanager_secret.jwt.id
  secret_string = jsonencode({
    jwt_secret = random_password.jwt_secret.result
  })
}

# ============================================
# AWS Secrets Manager: RabbitMQ Credentials
# ============================================

resource "aws_secretsmanager_secret" "rabbitmq" {
  name        = "${var.project_name}-${var.environment}-rabbitmq"
  description = "RabbitMQ credentials for ${var.environment} environment"
  kms_key_id  = var.kms_key_id

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment}-rabbitmq"
    Purpose = "message-queue-credentials"
    Type    = "rabbitmq"
  })
}

resource "aws_secretsmanager_secret_version" "rabbitmq" {
  secret_id = aws_secretsmanager_secret.rabbitmq.id
  secret_string = jsonencode({
    username = var.rabbitmq_username
    password = random_password.rabbitmq_password.result
  })
}

# ============================================
# IAM Policy: Allow EKS to Access Secrets
# ============================================
# Purpose: Grant External Secrets Operator permission to read secrets
# Method: IRSA (IAM Roles for Service Accounts)

resource "aws_iam_policy" "secrets_access" {
  name        = "${var.project_name}-${var.environment}-secrets-access"
  description = "Policy for External Secrets Operator to read secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.postgres.arn,
          aws_secretsmanager_secret.redis.arn,
          aws_secretsmanager_secret.jwt.arn,
          aws_secretsmanager_secret.rabbitmq.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = [
          var.kms_key_arn
        ]
      }
    ]
  })

  tags = var.tags
}

