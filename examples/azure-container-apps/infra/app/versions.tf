terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Same backend story as the baseline — remote state in the storage
  # account that infra/bootstrap created. Init line passes the rest
  # via `-backend-config=...`.
  backend "azurerm" {
    key              = "app/terraform.tfstate"
    use_oidc         = true
    use_azuread_auth = true
  }
}
