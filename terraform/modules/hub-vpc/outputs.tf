# ============================================
# PayFlow Hub VPC Module Outputs
# ============================================

output "vpc_id" {
  description = "Hub VPC ID"
  value       = aws_vpc.hub.id
}

output "vpc_cidr_block" {
  description = "Hub VPC CIDR block"
  value       = aws_vpc.hub.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs (for bastion host)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (for EKS cluster)"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = aws_nat_gateway.hub[*].id
}

output "vpc_endpoint_security_group_id" {
  description = "Security group ID for VPC endpoints"
  value       = aws_security_group.vpc_endpoint.id
}

output "private_route_table_ids" {
  description = "Private route table IDs (for VPC peering)"
  value       = aws_route_table.private[*].id
}

