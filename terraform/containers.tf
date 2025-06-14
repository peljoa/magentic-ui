# Azure Container Apps Environment for serverless scaling
resource "azurerm_container_app_environment" "main" {
  name                = "cae-${var.environmentName}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  tags = local.common_tags
}

# User Assigned Identity for Container Apps
resource "azurerm_user_assigned_identity" "container_identity" {
  name                = "id-${var.environmentName}-container"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

# Role assignment for Key Vault access
resource "azurerm_role_assignment" "keyvault_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.container_identity.principal_id
}

# Role assignment for Storage Account access
resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.container_identity.principal_id
}

# Azure Files share for persistent storage
resource "azurerm_storage_share" "container_storage" {
  name                 = "container-storage"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 50
}

# Container Apps Environment Storage for Azure Files
resource "azurerm_container_app_environment_storage" "main" {
  name                         = "azure-files-storage"
  container_app_environment_id = azurerm_container_app_environment.main.id
  account_name                 = azurerm_storage_account.main.name
  share_name                   = azurerm_storage_share.container_storage.name
  access_key                   = azurerm_storage_account.main.primary_access_key
  access_mode                  = "ReadWrite"
}

# Container App for the web application
resource "azurerm_container_app" "web" {
  name                         = "ca-${var.environmentName}-web"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_identity.id]
  }

  secret {
    name  = "openai-api-key"
    value = var.openai_api_key
  }

  secret {
    name  = "azure-openai-endpoint"
    value = var.azure_openai_endpoint
  }

  secret {
    name  = "azure-openai-api-key"
    value = var.azure_openai_api_key
  }

  secret {
    name  = "anthropic-api-key"
    value = var.anthropic_api_key
  }

  secret {
    name  = "storage-connection-string"
    value = azurerm_storage_account.main.primary_connection_string
  }

  template {
    min_replicas = 0
    max_replicas = 3

    volume {
      name         = "azure-files-volume"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.main.name
    }

    container {
      name   = "web"
      image  = "nginx:latest" # Placeholder - will be updated during deployment
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name        = "OPENAI_API_KEY"
        secret_name = "openai-api-key"
      }

      env {
        name        = "AZURE_OPENAI_ENDPOINT"
        secret_name = "azure-openai-endpoint"
      }

      env {
        name        = "AZURE_OPENAI_API_KEY"
        secret_name = "azure-openai-api-key"
      }

      env {
        name        = "ANTHROPIC_API_KEY"
        secret_name = "anthropic-api-key"
      }

      env {
        name        = "STORAGE_CONNECTION_STRING"
        secret_name = "storage-connection-string"
      }

      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.container_identity.client_id
      }

      volume_mounts {
        name = "azure-files-volume"
        path = "/mnt/storage"
      }
    }

    http_scale_rule {
      name                = "http-scale"
      concurrent_requests = 10
    }
  }

  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = local.common_tags
}