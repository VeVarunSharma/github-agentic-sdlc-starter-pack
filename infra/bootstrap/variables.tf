variable "acr_name" {
  type        = string
  description = "Exact precomputed globally unique Azure Container Registry name consumed by infra/app."

  validation {
    condition     = can(regex("^[a-z0-9]{5,50}$", var.acr_name))
    error_message = "acr_name must be 5-50 lowercase alphanumeric characters."
  }
}

variable "app_resource_group_name" {
  type        = string
  description = "Exact workload resource group name. Defaults to the CAF rg-<workload>-<environment>-<region-short> pattern."
  default     = null

  validation {
    condition     = var.app_resource_group_name == null || can(regex("^rg-[a-z0-9-]{3,80}$", var.app_resource_group_name))
    error_message = "app_resource_group_name must start with rg- and contain only lowercase letters, digits, and hyphens."
  }
}

variable "apply_identity_name" {
  type        = string
  description = "Optional exact name for the infra-apply user-assigned managed identity."
  default     = null
}

variable "create_state_backend" {
  type        = bool
  description = "Whether to create the Azure Storage backend used by infra/app."
  default     = true
}

variable "deploy_identity_name" {
  type        = string
  description = "Optional exact name for the production deploy user-assigned managed identity."
  default     = null
}

variable "enable_state_delete_lock" {
  type        = bool
  description = "Whether to protect the tfstate storage account with a CanNotDelete management lock."
  default     = true
}

variable "environment" {
  type        = string
  description = "Deployment environment segment used in CAF resource names."
  default     = "prod"

  validation {
    condition     = contains(["dev", "test", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, staging, prod."
  }
}

variable "github_owner" {
  type        = string
  description = "GitHub organization or user login that owns the repository."

  validation {
    condition     = can(regex("^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$", var.github_owner))
    error_message = "github_owner must be a valid GitHub owner login."
  }
}

variable "github_owner_id" {
  type        = string
  description = "Immutable numeric GitHub database ID of the repository owner."

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.github_owner_id))
    error_message = "github_owner_id must be a positive numeric GitHub database ID."
  }
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name without the owner prefix."

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]{1,100}$", var.github_repo))
    error_message = "github_repo must be a valid repository name without an owner prefix."
  }
}

variable "github_repo_id" {
  type        = string
  description = "Immutable numeric GitHub repository database ID."

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.github_repo_id))
    error_message = "github_repo_id must be a positive numeric GitHub database ID."
  }
}

variable "location" {
  type        = string
  description = "Azure region for workload and tfstate resource groups."
  default     = "eastus"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,19}$", var.location))
    error_message = "location must be a lowercase Azure region name such as eastus or westus2."
  }
}

variable "oidc_subject_mode" {
  type        = string
  description = "GitHub OIDC subject format. Immutable is the default for repos created, renamed, or transferred after 2026-07-15; legacy is explicit compatibility mode."
  default     = "immutable"

  validation {
    condition     = contains(["immutable", "legacy"], var.oidc_subject_mode)
    error_message = "oidc_subject_mode must be either immutable or legacy."
  }
}

variable "plan_identity_name" {
  type        = string
  description = "Optional exact name for the infra-plan user-assigned managed identity."
  default     = null
}

variable "region_short" {
  type        = string
  description = "Lowercase short Azure region segment used in CAF resource names, such as eus or weu."
  default     = "eus"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,7}$", var.region_short))
    error_message = "region_short must be 2-8 lowercase alphanumeric characters and start with a letter."
  }
}

variable "state_container_name" {
  type        = string
  description = "Blob container name for Terraform state."
  default     = "tfstate"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{1,61}[a-z0-9])$", var.state_container_name))
    error_message = "state_container_name must be a valid 3-63 character lowercase blob container name."
  }
}

variable "state_resource_group_name" {
  type        = string
  description = "Exact tfstate resource group name. Defaults to rg-<workload>-tfstate-<region-short>."
  default     = null

  validation {
    condition     = var.state_resource_group_name == null || can(regex("^rg-[a-z0-9-]{3,80}$", var.state_resource_group_name))
    error_message = "state_resource_group_name must start with rg- and contain only lowercase letters, digits, and hyphens."
  }
}

variable "state_soft_delete_days" {
  type        = number
  description = "Retention in days for deleted state blobs and containers."
  default     = 30

  validation {
    condition     = var.state_soft_delete_days >= 1 && var.state_soft_delete_days <= 365
    error_message = "state_soft_delete_days must be between 1 and 365."
  }
}

variable "state_storage_account_name" {
  type        = string
  description = "Globally unique tfstate storage account name."

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.state_storage_account_name))
    error_message = "state_storage_account_name must be 3-24 lowercase alphanumeric characters."
  }
}

variable "state_version_retention_days" {
  type        = number
  description = "Age in days after which non-current state blob versions are deleted."
  default     = 90

  validation {
    condition     = var.state_version_retention_days >= 30 && var.state_version_retention_days <= 3650
    error_message = "state_version_retention_days must be between 30 and 3650."
  }
}

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID where bootstrap resources are created."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be a UUID."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to bootstrap resources."
  default = {
    component = "bootstrap"
    managedBy = "terraform"
    project   = "agentic-sdlc-starter-pack"
  }
}

variable "web_app_name" {
  type        = string
  description = "Exact precomputed globally unique Web App name consumed by infra/app."

  validation {
    condition     = length(var.web_app_name) >= 2 && length(var.web_app_name) <= 60 && can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.web_app_name))
    error_message = "web_app_name must be 2-60 lowercase alphanumeric or hyphen characters and cannot start or end with a hyphen."
  }
}

variable "workload_name" {
  type        = string
  description = "Short lowercase workload segment used in CAF resource names."
  default     = "sdlcstarter"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,14}$", var.workload_name))
    error_message = "workload_name must be 3-15 lowercase alphanumeric characters and start with a letter."
  }
}
