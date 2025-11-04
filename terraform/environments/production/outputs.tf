# ============================================
# PayFlow Production Environment Outputs
# ============================================

output "vpc_id" {
  description = "Production VPC ID"
  value       = module.production_vpc.vpc_id
}

output "vpc_cidr" {
  description = "Production VPC CIDR block"
  value       = module.production_vpc.vpc_cidr_block
}

output "eks_cluster_id" {
  description = "Production EKS cluster ID"
  value       = module.production_eks.cluster_id
}

output "eks_cluster_endpoint" {
  description = "Production EKS cluster endpoint"
  value       = module.production_eks.cluster_endpoint
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.production.address
}

output "redis_endpoint" {
  description = "Redis endpoint"
  value       = aws_elasticache_replication_group.production.primary_endpoint_address
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

output "amazon_mq_broker_id" {
  description = "Amazon MQ broker ID"
  value       = module.amazon_mq.broker_id
}

output "amazon_mq_amqp_endpoint" {
  description = "Amazon MQ AMQP endpoint (for application connection)"
  value       = module.amazon_mq.amqp_ssl_endpoint
  sensitive   = true
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "Application Load Balancer ARN"
  value       = module.alb.alb_arn
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = module.monitoring_alerts.sns_topic_arn
}

output "sns_topic_name" {
  description = "SNS topic name for alerts"
  value       = module.monitoring_alerts.sns_topic_name
}

output "secrets_access_policy_arn" {
  description = "IAM policy ARN for secrets access"
  value       = module.secrets_manager.secrets_access_policy_arn
}

