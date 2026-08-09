provider "azurerm" {
  features {}

  # CI selects plan/apply identities through ARM_* environment variables.
  # Keeping identity details out of this block makes the saved plan portable
  # between those identities. Local `az login` remains supported.
  resource_provider_registrations = "none"
}
