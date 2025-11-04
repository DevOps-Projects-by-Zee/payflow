# 🔧 Terraform Configuration
# This tells Terraform which providers (cloud services) to use

terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.42.0"
    }
  }
}

# Configure Azure provider
provider "azurerm" {
  # Use environment variables for authentication (ARM_CLIENT_ID, ARM_CLIENT_SECRET, etc.)
  # This allows the provider to work with service principal authentication in CI/CD
  subscription_id = var.subscription_id

  features {
    # Enable automatic cleanup when deleting resources
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    # Key Vault features
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}
