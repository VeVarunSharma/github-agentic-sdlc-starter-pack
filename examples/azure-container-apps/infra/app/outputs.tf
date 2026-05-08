output "container_app_name" {
  description = "Container App name. Set as the AZURE_CONTAINERAPP_NAME repo variable."
  value       = azurerm_container_app.this.name
}

output "container_app_fqdn" {
  description = "Public ingress FQDN for the Container App."
  value       = azurerm_container_app.this.latest_revision_fqdn
}

output "acr_name" {
  description = "ACR name. Set as the AZURE_ACR_NAME repo variable."
  value       = azurerm_container_registry.this.name
}

output "acr_login_server" {
  description = "ACR login server (e.g. <acr>.azurecr.io)."
  value       = azurerm_container_registry.this.login_server
}

output "log_analytics_workspace_name" {
  description = "Log Analytics workspace name."
  value       = azurerm_log_analytics_workspace.this.name
}

output "application_insights_connection_string" {
  description = "App Insights connection string. Wired into the Container App as APPLICATIONINSIGHTS_CONNECTION_STRING."
  value       = azurerm_application_insights.this.connection_string
  sensitive   = true
}
