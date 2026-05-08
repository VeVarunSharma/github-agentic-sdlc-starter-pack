# Azure subscription / location
variable "subscription_id" {
  type        = string
  description = "Azure subscription ID where the resources will be created."
}

variable "location" {
  type        = string
  description = "Azure region for the app and tfstate resource groups."
  default     = "eastus"
}

# GitHub repository the federated credentials will trust
variable "github_owner" {
  type        = string
  description = "GitHub organization or user that owns the repository (e.g. 'contoso')."
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name only, no owner prefix (e.g. 'sample-app')."
}

# Naming knobs — overridable to fit org naming conventions. Defaults
# follow the awesome-copilot azure-naming.instructions.md pattern of
# `<workload>-<env>-<resource>`.
variable "name_prefix" {
  type        = string
  description = "Short prefix prepended to every resource name. Use kebab-case."
  default     = "agentic-sdlc"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,16}$", var.name_prefix))
    error_message = "name_prefix must be 3-17 chars, start with a letter, and contain only lowercase letters, digits, and hyphens."
  }
}

variable "app_rg_name" {
  type        = string
  description = "Resource group that will hold the app workload (Web App, ACR, etc.)."
  default     = null
}

variable "deploy_identity_name" {
  type        = string
  description = "Name of the user-assigned managed identity that GitHub Actions assumes via OIDC."
  default     = null
}

# tfstate backend (consumed by infra/app)
variable "create_state_backend" {
  type        = bool
  description = "If true, creates an Azure Storage account + container for infra/app's remote tfstate."
  default     = true
}

variable "state_rg_name" {
  type        = string
  description = "Resource group for the tfstate storage account."
  default     = null
}

variable "state_storage_account_name" {
  type        = string
  description = "Globally-unique storage account name for tfstate (3-24 lowercase alphanumeric)."

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.state_storage_account_name))
    error_message = "state_storage_account_name must be 3-24 chars, lowercase letters and digits only."
  }
}

# Federated-credential toggles. The 3 default subjects are:
#   1. environment:production  — push to main → deploy
#   2. environment:infra-apply — manual `terraform apply` against infra/app
#   3. pull_request            — PR `terraform fmt`+`validate` only (no plan)
variable "enable_pr_federation" {
  type        = bool
  description = "If true, creates a federated credential for pull_request runs (used for PR fmt+validate, NOT for cloud-backed plans)."
  default     = true
}

# Common tags — applied to every resource so cost/ownership reports are
# searchable. Override per-environment as needed.
variable "tags" {
  type        = map(string)
  description = "Tags applied to every bootstrap resource."
  default = {
    project   = "agentic-sdlc-starter-pack"
    component = "bootstrap"
    managedBy = "terraform"
  }
}
