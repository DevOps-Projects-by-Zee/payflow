# ============================================
# PayFlow Spoke VPC Module Outputs
# ============================================

output "vpc_id" {
  description = "Spoke VPC ID"
  value       = aws_vpc.spoke.id
}

output "vpc_cidr_block" {
  description = "Spoke VPC CIDR block"
  value       = aws_vpc.spoke.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs (for NAT Gateway)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (for EKS cluster)"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "Database subnet IDs (for RDS)"
  value       = aws_subnet.database[*].id
}

output "private_route_table_ids" {
  description = "Private route table IDs (for VPC peering)"
  value       = aws_route_table.private[*].id
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = aws_nat_gateway.spoke[*].id
}

