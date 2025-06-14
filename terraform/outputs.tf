# Azure Developer CLI expected outputs
output "AZURE_LOCATION" {
  description = "Azure region where resources are deployed"
  value       = azurerm_resource_group.main.location
}

output "AZURE_TENANT_ID" {
  description = "Azure tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}

output "AZURE_RESOURCE_GROUP" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "AZURE_CONTAINER_REGISTRY_ENDPOINT" {
  description = "Login server for the container registry"
  value       = azurerm_container_registry.main.login_server
}

output "AZURE_CONTAINER_REGISTRY_NAME" {
  description = "Name of the container registry"
  value       = azurerm_container_registry.main.name
}

output "AZURE_KEY_VAULT_NAME" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "AZURE_KEY_VAULT_ENDPOINT" {
  description = "Key Vault endpoint URL"
  value       = azurerm_key_vault.main.vault_uri
}

output "AZURE_STORAGE_ACCOUNT_NAME" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "AZURE_STORAGE_ACCOUNT_ENDPOINT" {
  description = "Storage account blob endpoint"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "SERVICE_WEB_NAME" {
  description = "Name of the main web service"
  value       = azurerm_container_app.web.name
}

output "SERVICE_WEB_URI" {
  description = "URL to access Magentic-UI"
  value       = "https://${azurerm_container_app.web.ingress[0].fqdn}"
}

output "SERVICE_WEB_IMAGE_NAME" {
  description = "Container image name for the web service"
  value       = "magentic-ui:latest"
}

output "SERVICE_VNC_BROWSER_NAME" {
  description = "Name of the VNC browser service"
  value       = "" # VNC browser not implemented in serverless architecture
}

output "SERVICE_VNC_BROWSER_URI" {
  description = "URL to access VNC browser (if enabled)"
  value       = "" # VNC browser not implemented in serverless architecture
}

output "SERVICE_VNC_BROWSER_IMAGE_NAME" {
  description = "Container image name for the VNC browser service"
  value       = "" # VNC browser not implemented in serverless architecture
}

# Legacy outputs for backward compatibility
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "container_registry_login_server" {
  description = "Login server for the container registry"
  value       = azurerm_container_registry.main.login_server
}

output "magentic_ui_url" {
  description = "URL to access Magentic-UI"
  value       = "https://${azurerm_container_app.web.ingress[0].fqdn}"
}

output "vnc_browser_url" {
  description = "URL to access VNC browser (if enabled)"
  value       = null # VNC browser not implemented in serverless architecture
}

# Docker commands for building and pushing images
output "docker_build_commands" {
  description = "Commands to build and push Docker images to ACR"
  value = {
    login      = "az acr login --name ${azurerm_container_registry.main.name}"
    build_main = "docker build -t ${azurerm_container_registry.main.login_server}/magentic-ui:latest -f Dockerfile ."
    build_vnc  = "docker build -t ${azurerm_container_registry.main.login_server}/magentic-ui-vnc:latest -f Dockerfile.vnc ."
    push_main  = "docker push ${azurerm_container_registry.main.login_server}/magentic-ui:latest"
    push_vnc   = "docker push ${azurerm_container_registry.main.login_server}/magentic-ui-vnc:latest"
  }
}
