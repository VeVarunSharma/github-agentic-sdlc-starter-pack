output "web_app_name" {
  value       = azurerm_linux_web_app.this.name
  description = "Linux Web App name. Used by az webapp config container set."
}

output "web_app_url" {
  value       = "https://${azurerm_linux_web_app.this.default_hostname}"
  description = "Public HTTPS URL of the deployed Web App."
}

output "web_app_principal_id" {
  value       = azurerm_linux_web_app.this.identity[0].principal_id
  description = "Object ID of the Web App's system-assigned MI (already granted AcrPull)."
}

output "acr_name" {
  value       = azurerm_container_registry.this.name
  description = "ACR name. Used by az acr login."
}

output "acr_login_server" {
  value       = azurerm_container_registry.this.login_server
  description = "ACR login server (e.g. <name>.azurecr.io)."
}

output "log_analytics_workspace_id" {
  value       = azurerm_log_analytics_workspace.this.id
  description = "Log Analytics workspace resource ID."
}

output "application_insights_connection_string" {
  value       = azurerm_application_insights.this.connection_string
  description = "App Insights connection string. Already wired into the Web App's app settings."
  sensitive   = true
}

output "resource_group_name" {
  value       = local.rg.name
  description = "App resource group name (echoed from input)."
}

output "staging_slot_name" {
  value       = var.staging_slot_enabled ? azurerm_linux_web_app_slot.staging[0].name : ""
  description = "Optional staging slot name, or an empty string when the low-cost direct deployment path is used."
}

output "staging_slot_hostname" {
  value       = var.staging_slot_enabled ? azurerm_linux_web_app_slot.staging[0].default_hostname : ""
  description = "Optional staging slot hostname, or an empty string when no slot is provisioned."
}
