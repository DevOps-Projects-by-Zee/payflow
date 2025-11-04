# ============================================
# PayFlow Hub Environment Outputs
# ============================================

output "vpc_id" {
  description = "Hub VPC ID"
  value       = module.hub_vpc.vpc_id
}

output "vpc_cidr" {
  description = "Hub VPC CIDR block"
  value       = module.hub_vpc.vpc_cidr_block
}

output "eks_cluster_id" {
  description = "Hub EKS cluster ID"
  value       = module.hub_eks.cluster_id
}

output "eks_cluster_endpoint" {
  description = "Hub EKS cluster endpoint (private)"
  value       = module.hub_eks.cluster_endpoint
}

output "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state (used by other environments)"
  value       = module.security.terraform_state_bucket
}

output "terraform_state_kms_key_arn" {
  description = "KMS key ARN for Terraform state encryption"
  value       = module.security.terraform_state_kms_key_arn
}

output "terraform_state_dynamodb_table" {
  description = "DynamoDB table name for state locking"
  value       = module.security.terraform_state_dynamodb_table
}

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = module.security.ecr_repository_urls
}

output "bastion_public_ip" {
  description = "Bastion host public IP (for SSH access)"
  value       = module.security.bastion_public_ip
}

output "bastion_allowed_ip" {
  description = "IP address used for bastion SSH access (auto-detected or provided)"
  value       = length(var.bastion_allowed_cidrs) > 0 ? "Using provided: ${join(", ", var.bastion_allowed_cidrs)}" : try("Auto-detected: ${chomp(data.http.user_ip.response_body)}/32", "Could not auto-detect")
}

output "bastion_security_group_id" {
  description = "Bastion security group ID (for spoke environments)"
  value       = module.security.bastion_security_group_id
}

output "private_route_table_ids" {
  description = "Hub private route table IDs (for VPC peering)"
  value       = module.hub_vpc.private_route_table_ids
}

output "deployment_info" {
  description = "Instructions for accessing the cluster"
  value = {
    message = "Hub environment deployed successfully!"
    next_steps = [
      "1. SSH to bastion: ssh -i your-key.pem ec2-user@${module.security.bastion_public_ip}",
      "2. Configure kubectl: aws eks update-kubeconfig --region ${var.aws_region} --name ${module.hub_eks.cluster_id}",
      "3. Verify cluster: kubectl get nodes",
      "4. Deploy production: cd ../production && terraform init -backend-config=backend-config.hcl && terraform apply"
    ]
  }
}

