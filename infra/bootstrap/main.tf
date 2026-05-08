locals {
  app_rg_name          = coalesce(var.app_rg_name, "${var.name_prefix}-app-rg")
  state_rg_name        = coalesce(var.state_rg_name, "${var.name_prefix}-state-rg")
  deploy_identity_name = coalesce(var.deploy_identity_name, "${var.name_prefix}-deploy-mi")

  # Federated subject claims — exact match required by Entra. No
  # wildcards. See docs/spike-d-azure-oidc.md §2.
  federation_subjects = merge(
    {
      production  = "repo:${var.github_owner}/${var.github_repo}:environment:production"
      infra_apply = "repo:${var.github_owner}/${var.github_repo}:environment:infra-apply"
    },
    var.enable_pr_federation ? {
      pull_request = "repo:${var.github_owner}/${var.github_repo}:pull_request"
    } : {}
  )
}

# ---------------------------------------------------------------------------
# Resource groups
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "app" {
  name     = local.app_rg_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "state" {
  count    = var.create_state_backend ? 1 : 0
  name     = local.state_rg_name
  location = var.location
  tags     = merge(var.tags, { component = "tfstate" })
}

# ---------------------------------------------------------------------------
# Terraform state backend (consumed by infra/app)
# ---------------------------------------------------------------------------

resource "azurerm_storage_account" "tfstate" {
  count                           = var.create_state_backend ? 1 : 0
  name                            = var.state_storage_account_name
  resource_group_name             = azurerm_resource_group.state[0].name
  location                        = azurerm_resource_group.state[0].location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false # force RBAC + AAD auth (no shared keys)
  tags                            = merge(var.tags, { component = "tfstate" })
}

resource "azurerm_storage_container" "tfstate" {
  count                 = var.create_state_backend ? 1 : 0
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate[0].id
  container_access_type = "private"
}

# ---------------------------------------------------------------------------
# Deploy managed identity (GitHub Actions assumes this via OIDC)
# ---------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "deploy" {
  name                = local.deploy_identity_name
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  tags                = var.tags
}

# Federated identity credentials — one per subject claim. Entra requires
# an exact match (no wildcards), so PR / production / infra-apply each
# need their own row. See docs/spike-d-azure-oidc.md §2.4 for the
# rotation contract when the repo or environment is renamed.
resource "azurerm_federated_identity_credential" "deploy" {
  for_each = local.federation_subjects

  name                = "github-${replace(each.key, "_", "-")}"
  resource_group_name = azurerm_resource_group.app.name
  parent_id           = azurerm_user_assigned_identity.deploy.id
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = each.value
  audience            = ["api://AzureADTokenExchange"]
}

# ---------------------------------------------------------------------------
# RBAC at resource-group scope
#
# We deliberately scope to the app RG (not the subscription) so the
# deploy identity is bounded to a single workload. The Web App's own
# AcrPull role assignment lives in infra/app — the Web App resource
# doesn't exist yet at bootstrap time. Granting the deploy MI
# `User Access Administrator` at this RG scope is what lets the CI
# deploy create that AcrPull role assignment from inside infra/app.
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "deploy_rg_contributor" {
  principal_id         = azurerm_user_assigned_identity.deploy.principal_id
  role_definition_name = "Contributor"
  scope                = azurerm_resource_group.app.id
}

resource "azurerm_role_assignment" "deploy_rg_uaa" {
  principal_id         = azurerm_user_assigned_identity.deploy.principal_id
  role_definition_name = "User Access Administrator"
  scope                = azurerm_resource_group.app.id
}

# Storage Blob Data Contributor on the tfstate container so the deploy
# MI can read/write infra/app's terraform.tfstate via OIDC-backed
# `use_azuread_auth = true`.
resource "azurerm_role_assignment" "deploy_tfstate" {
  count                = var.create_state_backend ? 1 : 0
  principal_id         = azurerm_user_assigned_identity.deploy.principal_id
  role_definition_name = "Storage Blob Data Contributor"
  scope                = azurerm_storage_account.tfstate[0].id
}
