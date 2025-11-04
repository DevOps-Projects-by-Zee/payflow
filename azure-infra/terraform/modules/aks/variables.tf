# 📝 Kubernetes Cluster Settings
# These are the inputs you can customize for your cluster

variable "cluster_name" {
  description = "Name for your Kubernetes cluster (e.g., 'payflow-cluster')"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
}

variable "location" {
  description = "Azure region where to create the cluster"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet where cluster nodes will live"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace for monitoring"
  type        = string
}

variable "tags" {
  description = "Labels to organize your resources"
  type        = map(string)
  default     = {}
}