terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Bootstrap state is intentionally LOCAL — bootstrap creates the
  # storage account that infra/app uses for its own remote state, so
  # bootstrap can't depend on its own output. Two acceptable patterns:
  #   1. Local state, committed to .gitignore (default; suitable for
  #      one-time bootstrap runs by a single operator).
  #   2. A pre-existing org-owned tfstate storage account; uncomment
  #      the backend block below and run `terraform init -backend-config=...`.
  #
  # backend "azurerm" {
  #   resource_group_name  = "<org-tfstate-rg>"
  #   storage_account_name = "<org-tfstate-sa>"
  #   container_name       = "tfstate"
  #   key                  = "agentic-sdlc/bootstrap.tfstate"
  # }
}
