# Configure the Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.1"
    }
  }
  required_version = ">= 1.0"
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

# Get current client configuration
data "azurerm_client_config" "current" {}

# Random suffix for unique naming (only if resourceToken is not provided by azd)
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  # Use azd resourceToken if provided, otherwise use random suffix
  resource_suffix = var.resourceToken != "" ? var.resourceToken : random_string.suffix.result

  common_tags = {
    Environment    = var.environment
    Project        = "magentic-ui"
    ManagedBy      = "terraform"
    "azd-env-name" = var.environmentName
  }
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.environmentName}"
  location = var.location

  tags = local.common_tags
}

# Storage Account for persistent data
resource "azurerm_storage_account" "main" {
  name                     = "st${local.resource_suffix}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = local.common_tags
}

# Storage Container for application data
resource "azurerm_storage_container" "data" {
  name                  = "magentic-data"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# Key Vault for secrets
resource "azurerm_key_vault" "main" {
  name                = "kv-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Purge",
      "Recover"
    ]
  }

  tags = local.common_tags
}

# Container Registry
resource "azurerm_container_registry" "main" {
  name                = "cr${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = local.common_tags
}


