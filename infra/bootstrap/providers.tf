provider "azurerm" {
  features {}

  # Bootstrap is run by a HUMAN operator under `az login`. Do NOT set
  # `use_oidc = true` here — that's only valid in CI. The provider
  # picks up the operator's Azure CLI session by default.
  subscription_id = var.subscription_id
}
