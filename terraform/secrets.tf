# Store secrets in Key Vault
resource "azurerm_key_vault_secret" "openai_api_key" {
  name         = "openai-api-key"
  value        = var.openai_api_key
  key_vault_id = azurerm_key_vault.main.id

  tags = local.common_tags
}

resource "azurerm_key_vault_secret" "azure_openai_endpoint" {
  count = var.azure_openai_endpoint != "" ? 1 : 0

  name         = "azure-openai-endpoint"
  value        = var.azure_openai_endpoint
  key_vault_id = azurerm_key_vault.main.id

  tags = local.common_tags
}

resource "azurerm_key_vault_secret" "azure_openai_api_key" {
  count = var.azure_openai_api_key != "" ? 1 : 0

  name         = "azure-openai-api-key"
  value        = var.azure_openai_api_key
  key_vault_id = azurerm_key_vault.main.id

  tags = local.common_tags
}

resource "azurerm_key_vault_secret" "anthropic_api_key" {
  count = var.anthropic_api_key != "" ? 1 : 0

  name         = "anthropic-api-key"
  value        = var.anthropic_api_key
  key_vault_id = azurerm_key_vault.main.id

  tags = local.common_tags
}

resource "azurerm_key_vault_secret" "vnc_password" {
  name         = "vnc-password"
  value        = var.vnc_password
  key_vault_id = azurerm_key_vault.main.id

  tags = local.common_tags
}

resource "azurerm_key_vault_secret" "storage_connection_string" {
  name         = "storage-connection-string"
  value        = azurerm_storage_account.main.primary_connection_string
  key_vault_id = azurerm_key_vault.main.id

  tags = local.common_tags
}
