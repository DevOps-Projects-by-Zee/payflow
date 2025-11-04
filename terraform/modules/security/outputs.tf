# ============================================
# PayFlow Security Module Outputs
# ============================================

output "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state"
  value       = data.aws_s3_bucket.terraform_state.id
}

output "terraform_state_kms_key_arn" {
  description = "KMS key ARN for encrypting Terraform state"
  value       = data.aws_kms_key.terraform_state.arn
}

output "terraform_state_dynamodb_table" {
  description = "DynamoDB table name for state locking"
  value       = data.aws_dynamodb_table.terraform_locks.name
}

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = { for k, v in aws_ecr_repository.payflow : k => v.repository_url }
}

output "bastion_security_group_id" {
  description = "Bastion security group ID"
  value       = var.bastion_enabled ? aws_security_group.bastion[0].id : null
}

output "bastion_public_ip" {
  description = "Bastion host public IP"
  value       = var.bastion_enabled ? aws_instance.bastion[0].public_ip : null
}

output "private_zone_id" {
  description = "Route53 private zone ID"
  value       = var.create_private_zone ? aws_route53_zone.private[0].zone_id : null
}

