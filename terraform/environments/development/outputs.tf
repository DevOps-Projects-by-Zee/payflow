# ============================================
# PayFlow Development Environment Outputs
# ============================================

output "vpc_id" {
  description = "Development VPC ID"
  value       = module.development_vpc.vpc_id
}

output "vpc_cidr" {
  description = "Development VPC CIDR block"
  value       = module.development_vpc.vpc_cidr_block
}

output "eks_cluster_id" {
  description = "Development EKS cluster ID"
  value       = module.development_eks.cluster_id
}

output "eks_cluster_endpoint" {
  description = "Development EKS cluster endpoint"
  value       = module.development_eks.cluster_endpoint
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.development.address
}

output "redis_endpoint" {
  description = "Redis endpoint"
  value       = aws_elasticache_replication_group.development.primary_endpoint_address
}

output "postgres_secret_arn" {
  description = "PostgreSQL secret ARN"
  value       = module.secrets_manager.postgres_secret_arn
}

output "redis_secret_arn" {
  description = "Redis secret ARN"
  value       = module.secrets_manager.redis_secret_arn
}

output "jwt_secret_arn" {
  description = "JWT secret ARN"
  value       = module.secrets_manager.jwt_secret_arn
}

output "rabbitmq_secret_arn" {
  description = "RabbitMQ secret ARN"
  value       = module.secrets_manager.rabbitmq_secret_arn
}

output "secrets_access_policy_arn" {
  description = "IAM policy ARN for secrets access"
  value       = module.secrets_manager.secrets_access_policy_arn
}

