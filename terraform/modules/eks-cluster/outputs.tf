# ============================================
# PayFlow EKS Cluster Module Outputs
# ============================================

output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.payflow.id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.payflow.arn
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint (private)"
  value       = aws_eks_cluster.payflow.endpoint
}

output "cluster_security_group_id" {
  description = "EKS cluster security group ID (automatically created by EKS)"
  value       = aws_eks_cluster.payflow.vpc_config[0].cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "EKS OIDC provider ARN (for IRSA)"
  value       = try(aws_eks_cluster.payflow.identity[0].oidc[0].issuer, null)
}

output "cluster_oidc_issuer_url" {
  description = "EKS OIDC issuer URL"
  value       = try(aws_eks_cluster.payflow.identity[0].oidc[0].issuer, null)
}

