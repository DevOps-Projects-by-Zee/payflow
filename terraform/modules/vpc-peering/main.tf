# ============================================
# PayFlow VPC Peering Module
# ============================================
# Purpose: Connect Hub VPC with Spoke VPCs (Hub-and-Spoke architecture)
# Cost: FREE (no data transfer charges within same region)
# Why: Allows spoke VPCs to access hub services (ECR, Secrets Manager)
#
# How VPC Peering Works:
# - Creates peering connection between two VPCs
# - Updates route tables to route traffic between VPCs
# - Enables spoke VPCs to access hub services privately

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ============================================
# VPC Peering Connection
# ============================================
# Purpose: Connect Hub VPC with Spoke VPC
# Cost: FREE (no charges for peering connection itself)

resource "aws_vpc_peering_connection" "hub_spoke" {
  vpc_id      = var.hub_vpc_id
  peer_vpc_id = var.spoke_vpc_id
  auto_accept = true # Auto-accept peering (both VPCs in same account)

  tags = merge(var.tags, {
    Name = "${var.project_name}-hub-${var.spoke_environment}-peering"
  })
}

# ============================================
# Route Table Updates: Hub VPC
# ============================================
# Purpose: Allow Hub VPC to route traffic to Spoke VPC
# Why: Hub needs to access resources in Spoke (if needed)

resource "aws_route" "hub_to_spoke" {
  count = length(var.hub_route_table_ids)

  route_table_id            = var.hub_route_table_ids[count.index]
  destination_cidr_block    = var.spoke_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.hub_spoke.id
}

# ============================================
# Route Table Updates: Spoke VPC
# ============================================
# Purpose: Allow Spoke VPC to route traffic to Hub VPC
# Why: Spoke needs to access Hub services (ECR, Secrets Manager, etc.)

resource "aws_route" "spoke_to_hub" {
  count = length(var.spoke_route_table_ids)

  route_table_id            = var.spoke_route_table_ids[count.index]
  destination_cidr_block    = var.hub_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.hub_spoke.id
}

# ============================================
# Outputs
# ============================================

output "peering_connection_id" {
  description = "VPC peering connection ID"
  value       = aws_vpc_peering_connection.hub_spoke.id
}

output "peering_connection_status" {
  description = "VPC peering connection status"
  value       = aws_vpc_peering_connection.hub_spoke.accept_status
}

