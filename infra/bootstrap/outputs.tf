output "app_resource_group_name" {
  value       = azurerm_resource_group.app.name
  description = "Workload resource group. Set as AZURE_RESOURCE_GROUP."
}

output "apply_client_id" {
  value       = azurerm_user_assigned_identity.github["apply"].client_id
  description = "Client ID for the infra-apply identity. Set as AZURE_APPLY_CLIENT_ID."
}

output "deploy_client_id" {
  value       = azurerm_user_assigned_identity.github["deploy"].client_id
  description = "Client ID for the production deploy identity. Set as AZURE_DEPLOY_CLIENT_ID."
}

output "deploy_principal_id" {
  value       = azurerm_user_assigned_identity.github["deploy"].principal_id
  description = "Object ID for app-scoped deploy role assignments. Set as AZURE_DEPLOY_PRINCIPAL_ID."
}

output "federation_subjects" {
  value = {
    for name, credential in local.oidc_credentials :
    name => credential.subject
  }
  description = "Exact GitHub environment subjects registered across the three purpose-specific identities."
}

output "identity_names" {
  value       = local.identity_names
  description = "Purpose-specific managed identity names used for OIDC."
}

output "naming_inputs" {
  value = {
    environment   = var.environment
    location      = var.location
    region_short  = var.region_short
    workload_name = var.workload_name
  }
  description = "Stable naming inputs reused by safe OIDC rotations."
}

output "plan_client_id" {
  value       = azurerm_user_assigned_identity.github["plan"].client_id
  description = "Client ID for the infra-plan identity. Set as AZURE_PLAN_CLIENT_ID."
}

output "precomputed_acr_name" {
  value       = var.acr_name
  description = "Precomputed ACR name. Set as AZURE_ACR_NAME before the first infra apply."
}

output "precomputed_web_app_name" {
  value       = var.web_app_name
  description = "Precomputed Web App name. Set as AZURE_WEBAPP_NAME before the first infra apply."
}

output "subscription_id" {
  value       = var.subscription_id
  description = "Azure subscription ID. Set as AZURE_SUBSCRIPTION_ID."
}

output "tenant_id" {
  value       = data.azurerm_client_config.current.tenant_id
  description = "Azure tenant ID. Set as AZURE_TENANT_ID."
}

output "tfstate_container_name" {
  value       = var.create_state_backend ? azurerm_storage_container.tfstate[0].name : null
  description = "Exact state container name. Set as AZURE_TFSTATE_CONTAINER."
}

output "tfstate_resource_group_name" {
  value       = var.create_state_backend ? azurerm_resource_group.state[0].name : null
  description = "State resource group. Set as AZURE_TFSTATE_RG."
}

output "tfstate_storage_account_name" {
  value       = var.create_state_backend ? azurerm_storage_account.tfstate[0].name : null
  description = "State storage account. Set as AZURE_TFSTATE_STORAGE_ACCOUNT."
}
