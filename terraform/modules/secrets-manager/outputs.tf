# ============================================
# PayFlow Secrets Manager Module Outputs
# ============================================

output "postgres_secret_arn" {
  description = "ARN of PostgreSQL credentials secret"
  value       = aws_secretsmanager_secret.postgres.arn
}

output "redis_secret_arn" {
  description = "ARN of Redis auth token secret"
  value       = aws_secretsmanager_secret.redis.arn
}

output "jwt_secret_arn" {
  description = "ARN of JWT secret"
  value       = aws_secretsmanager_secret.jwt.arn
}

output "rabbitmq_secret_arn" {
  description = "ARN of RabbitMQ credentials secret"
  value       = aws_secretsmanager_secret.rabbitmq.arn
}

output "secrets_access_policy_arn" {
  description = "ARN of IAM policy for secrets access"
  value       = aws_iam_policy.secrets_access.arn
}

output "db_password" {
  description = "Generated database password (for RDS master password)"
  value       = random_password.db_password.result
  sensitive   = true
}

output "redis_auth_token" {
  description = "Generated Redis auth token"
  value       = random_password.redis_auth_token.result
  sensitive   = true
}

