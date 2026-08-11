terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }

  # Remote state in the storage account that infra/bootstrap created.
  # The storage_account_name, resource_group_name, and container_name
  # are passed via `terraform init -backend-config=...` so they remain
  # template-friendly. See azure-deploy.yml for the exact init line.
  backend "azurerm" {
    key              = "app/terraform.tfstate"
    use_azuread_auth = true
  }
}
