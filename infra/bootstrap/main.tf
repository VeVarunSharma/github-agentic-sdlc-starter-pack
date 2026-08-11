data "azurerm_client_config" "current" {}

locals {
  app_resource_group_name = coalesce(
    var.app_resource_group_name,
    "rg-${var.workload_name}-${var.environment}-${var.region_short}"
  )
  state_resource_group_name = coalesce(
    var.state_resource_group_name,
    "rg-${var.workload_name}-tfstate-${var.region_short}"
  )

  identity_names = {
    apply  = coalesce(var.apply_identity_name, "id-${var.workload_name}-${var.environment}-apply")
    deploy = coalesce(var.deploy_identity_name, "id-${var.workload_name}-${var.environment}-deploy")
    plan   = coalesce(var.plan_identity_name, "id-${var.workload_name}-${var.environment}-plan")
  }

  github_repository_subject = var.oidc_subject_mode == "immutable" ? (
    "${var.github_owner}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}"
  ) : "${var.github_owner}/${var.github_repo}"

  oidc_credentials = {
    apply = {
      environment = "infra-apply"
      subject     = "repo:${local.github_repository_subject}:environment:infra-apply"
    }
    deploy = {
      environment = "production"
      subject     = "repo:${local.github_repository_subject}:environment:production"
    }
    plan = {
      environment = "infra-plan"
      subject     = "repo:${local.github_repository_subject}:environment:infra-plan"
    }
  }

  role_ids = {
    acr_pull                 = "7f951dda-4ed3-4680-a7ca-43fe172d538d"
    acr_push                 = "8311e382-0749-4cb8-b61a-304f252e45ec"
    contributor              = "b24988ac-6180-42a0-ab88-20f7382dd24c"
    reader                   = "acdd72a7-3385-48ef-bd42-f606fba81ae7"
    rbac_administrator       = "f58310d9-a9f6-439a-9e8d-f62e7b41a168"
    storage_blob_contributor = "ba92f5b4-2d11-453d-a403-e96b0029c9fe"
    website_contributor      = "de139f84-1756-47ae-9be6-808fbbe84772"
  }

  role_definition_ids = {
    for name, id in local.role_ids :
    name => "/subscriptions/${var.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/${id}"
  }
}

resource "azurerm_resource_group" "app" {
  location = var.location
  name     = local.app_resource_group_name
  tags     = var.tags
}

resource "azurerm_resource_group" "state" {
  count = var.create_state_backend ? 1 : 0

  location = var.location
  name     = local.state_resource_group_name
  tags     = merge(var.tags, { component = "tfstate" })
}

resource "azurerm_storage_account" "tfstate" {
  count = var.create_state_backend ? 1 : 0

  account_replication_type        = "LRS"
  account_tier                    = "Standard"
  allow_nested_items_to_be_public = false
  default_to_oauth_authentication = true
  location                        = azurerm_resource_group.state[0].location
  min_tls_version                 = "TLS1_2"
  name                            = var.state_storage_account_name
  public_network_access_enabled   = true
  resource_group_name             = azurerm_resource_group.state[0].name
  shared_access_key_enabled       = false
  tags                            = merge(var.tags, { component = "tfstate" })

  blob_properties {
    versioning_enabled = true

    container_delete_retention_policy {
      days = var.state_soft_delete_days
    }

    delete_retention_policy {
      days = var.state_soft_delete_days
    }
  }
}

# AzureRM uses the Storage data plane for container operations when Shared Key
# is disabled. Grant the bootstrap operator access before creating the
# container; storage_use_azuread in providers.tf forces OAuth.
resource "azurerm_role_assignment" "bootstrap_operator_tfstate" {
  count = var.create_state_backend ? 1 : 0

  principal_id       = data.azurerm_client_config.current.object_id
  role_definition_id = local.role_definition_ids.storage_blob_contributor
  scope              = azurerm_storage_account.tfstate[0].id
}

resource "azurerm_storage_container" "tfstate" {
  count = var.create_state_backend ? 1 : 0

  depends_on = [azurerm_role_assignment.bootstrap_operator_tfstate]

  container_access_type = "private"
  name                  = var.state_container_name
  storage_account_id    = azurerm_storage_account.tfstate[0].id
}

resource "azurerm_storage_management_policy" "tfstate" {
  count = var.create_state_backend ? 1 : 0

  storage_account_id = azurerm_storage_account.tfstate[0].id

  rule {
    enabled = true
    name    = "delete-old-state-versions"

    actions {
      version {
        delete_after_days_since_creation = var.state_version_retention_days
      }
    }

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["${var.state_container_name}/"]
    }
  }
}

resource "azurerm_management_lock" "tfstate" {
  count = var.create_state_backend && var.enable_state_delete_lock ? 1 : 0

  lock_level = "CanNotDelete"
  name       = "lock-${var.workload_name}-tfstate"
  notes      = "Prevents accidental deletion of active Terraform state. Remove explicitly before intentional teardown."
  scope      = azurerm_storage_account.tfstate[0].id
}

resource "azurerm_user_assigned_identity" "github" {
  for_each = local.identity_names

  location            = azurerm_resource_group.app.location
  name                = each.value
  resource_group_name = azurerm_resource_group.app.name
  tags                = merge(var.tags, { purpose = each.key })
}

# Exact environment subjects only. Including the subject hash in the Azure
# credential name lets create_before_destroy overlap old and new subjects
# during a rename/transfer rotation.
resource "azurerm_federated_identity_credential" "github" {
  for_each = local.oidc_credentials

  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  name                      = "github-${each.value.environment}-${substr(sha256(each.value.subject), 0, 8)}"
  subject                   = each.value.subject
  user_assigned_identity_id = azurerm_user_assigned_identity.github[each.key].id

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_role_assignment" "plan_rg_reader" {
  principal_id                     = azurerm_user_assigned_identity.github["plan"].principal_id
  principal_type                   = "ServicePrincipal"
  role_definition_id               = local.role_definition_ids.reader
  scope                            = azurerm_resource_group.app.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "apply_rg_contributor" {
  principal_id                     = azurerm_user_assigned_identity.github["apply"].principal_id
  principal_type                   = "ServicePrincipal"
  role_definition_id               = local.role_definition_ids.contributor
  scope                            = azurerm_resource_group.app.id
  skip_service_principal_aad_check = true
}

# Official constrained-delegation syntax:
# https://learn.microsoft.com/azure/role-based-access-control/delegate-role-assignments-examples
# The apply identity can grant AcrPull only to service principals (the Web App
# system MI) and the deploy roles only to the exact deploy UAMI.
resource "azurerm_role_assignment" "apply_rg_rbac_administrator" {
  principal_id                     = azurerm_user_assigned_identity.github["apply"].principal_id
  principal_type                   = "ServicePrincipal"
  role_definition_id               = local.role_definition_ids.rbac_administrator
  scope                            = azurerm_resource_group.app.id
  skip_service_principal_aad_check = true

  condition_version = "2.0"
  condition = trimspace(<<-EOT
    (
      (!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'}))
      OR
      (
        (
          @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.role_ids.acr_pull}}
          AND
          @Request[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'ServicePrincipal'}
        )
        OR
        (
          @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.role_ids.acr_push}, ${local.role_ids.reader}, ${local.role_ids.website_contributor}}
          AND
          @Request[Microsoft.Authorization/roleAssignments:PrincipalId] ForAnyOfAnyValues:GuidEquals {${azurerm_user_assigned_identity.github["deploy"].principal_id}}
          AND
          @Request[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'ServicePrincipal'}
        )
      )
    )
    AND
    (
      (!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'}))
      OR
      (
        (
          @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.role_ids.acr_pull}}
          AND
          @Resource[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'ServicePrincipal'}
        )
        OR
        (
          @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.role_ids.acr_push}, ${local.role_ids.reader}, ${local.role_ids.website_contributor}}
          AND
          @Resource[Microsoft.Authorization/roleAssignments:PrincipalId] ForAnyOfAnyValues:GuidEquals {${azurerm_user_assigned_identity.github["deploy"].principal_id}}
          AND
          @Resource[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'ServicePrincipal'}
        )
      )
    )
  EOT
  )
}

resource "azurerm_role_assignment" "workflow_tfstate" {
  for_each = var.create_state_backend ? toset(["apply", "plan"]) : toset([])

  principal_id                     = azurerm_user_assigned_identity.github[each.key].principal_id
  principal_type                   = "ServicePrincipal"
  role_definition_id               = local.role_definition_ids.storage_blob_contributor
  scope                            = azurerm_storage_container.tfstate[0].id
  skip_service_principal_aad_check = true
}
