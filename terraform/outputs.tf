# ============================================
# PayFlow Global Outputs
# ============================================
# Purpose: Root-level outputs (mostly informational)
# Note: Actual infrastructure outputs are in each environment's outputs.tf

output "project_info" {
  description = "Project information"
  value = {
    project_name     = var.project_name
    default_region   = var.default_region
    architecture     = "hub-and-spoke"
    state_management = "separate-state-files-per-environment"
  }
}

