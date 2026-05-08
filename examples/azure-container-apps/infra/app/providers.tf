provider "azurerm" {
  features {}

  # OIDC: when running under GitHub Actions with `azure/login@v2`, the
  # provider auto-detects ARM_USE_OIDC + ACTIONS_ID_TOKEN_REQUEST_TOKEN
  # and exchanges the GitHub OIDC token for an Azure access token. No
  # client secret is ever stored in GitHub.
  use_oidc        = true
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
}
