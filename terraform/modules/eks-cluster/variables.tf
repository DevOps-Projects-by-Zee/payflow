# ============================================
# PayFlow EKS Cluster Module Variables
# ============================================

variable "project_name" {
  description = "Project name (used in resource naming)"
  type        = string
}

variable "environment" {
  description = "Environment name (hub, production, development)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for EKS cluster"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS cluster"
  type        = list(string)
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting EKS secrets"
  type        = string
}

variable "bastion_security_group_id" {
  description = "Bastion security group ID (for EKS API access)"
  type        = string
}

variable "node_key_pair_name" {
  description = "AWS Key Pair name for node SSH access"
  type        = string
}

variable "node_groups" {
  description = "Node group configurations"
  type = map(object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    capacity_type  = string # ON_DEMAND or SPOT
    disk_size      = number
  }))
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

