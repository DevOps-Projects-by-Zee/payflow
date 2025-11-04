# ============================================
# PayFlow VPC Peering Module Variables
# ============================================

variable "project_name" {
  description = "Project name (used in resource naming)"
  type        = string
}

variable "spoke_environment" {
  description = "Spoke environment name (production, development)"
  type        = string
}

variable "hub_vpc_id" {
  description = "Hub VPC ID"
  type        = string
}

variable "hub_vpc_cidr" {
  description = "Hub VPC CIDR block"
  type        = string
}

variable "hub_route_table_ids" {
  description = "Hub VPC route table IDs (private subnets)"
  type        = list(string)
}

variable "spoke_vpc_id" {
  description = "Spoke VPC ID"
  type        = string
}

variable "spoke_vpc_cidr" {
  description = "Spoke VPC CIDR block"
  type        = string
}

variable "spoke_route_table_ids" {
  description = "Spoke VPC route table IDs (private subnets)"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

