output "client_id" {
  value       = azurerm_user_assigned_identity.deploy.client_id
  description = "Client ID of the deploy managed identity. Set as repo variable AZURE_CLIENT_ID."
}

output "tenant_id" {
  value       = azurerm_user_assigned_identity.deploy.tenant_id
  description = "Tenant ID. Set as repo variable AZURE_TENANT_ID."
}

output "subscription_id" {
  value       = var.subscription_id
  description = "Subscription ID. Set as repo variable AZURE_SUBSCRIPTION_ID."
}

output "deploy_principal_id" {
  value       = azurerm_user_assigned_identity.deploy.principal_id
  description = "Object ID (principal ID) of the deploy MI. Use when granting cross-RG role assignments outside this template."
}

output "app_resource_group_name" {
  value       = azurerm_resource_group.app.name
  description = "App resource group name. Set as repo variable AZURE_RESOURCE_GROUP."
}

output "app_location" {
  value       = azurerm_resource_group.app.location
  description = "Azure region for the app workload."
}

output "tfstate_storage_account_name" {
  value       = var.create_state_backend ? azurerm_storage_account.tfstate[0].name : null
  description = "Storage account holding infra/app's remote tfstate. Set as repo variable AZURE_TFSTATE_STORAGE_ACCOUNT."
}

output "tfstate_resource_group_name" {
  value       = var.create_state_backend ? azurerm_resource_group.state[0].name : null
  description = "Resource group of the tfstate storage account. Set as repo variable AZURE_TFSTATE_RG."
}

output "tfstate_container_name" {
  value       = var.create_state_backend ? azurerm_storage_container.tfstate[0].name : null
  description = "Storage container holding infra/app/terraform.tfstate."
}

output "federation_subjects" {
  value       = local.federation_subjects
  description = "Federated subject claims registered on the deploy MI. Use to verify GitHub Actions OIDC subjects match."
}
