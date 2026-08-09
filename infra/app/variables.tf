variable "acr_name" {
  type        = string
  description = "Exact precomputed globally unique ACR name."

  validation {
    condition     = can(regex("^[a-z0-9]{5,50}$", var.acr_name))
    error_message = "acr_name must be 5-50 lowercase alphanumeric characters."
  }
}

variable "acr_sku" {
  type        = string
  description = "Azure Container Registry SKU."
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "acr_sku must be one of: Basic, Standard, Premium."
  }
}

variable "app_service_plan_sku" {
  type        = string
  description = "App Service Plan SKU."
  default     = "B1"
}

variable "container_image" {
  type        = string
  description = "Initial container image. The deploy workflow updates this after provisioning."
  default     = "mcr.microsoft.com/azuredocs/aci-helloworld:latest"
}

variable "deploy_principal_id" {
  type        = string
  description = "Object ID of the production deploy UAMI that receives app-scoped roles."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.deploy_principal_id))
    error_message = "deploy_principal_id must be a UUID."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment segment used in resource names."
  default     = "prod"

  validation {
    condition     = contains(["dev", "test", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, staging, prod."
  }
}

variable "log_retention_days" {
  type        = number
  description = "Log Analytics retention in days."
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "log_retention_days must be between 30 and 730."
  }
}

variable "region_short" {
  type        = string
  description = "Lowercase short Azure region segment used in resource names."
  default     = "eus"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,7}$", var.region_short))
    error_message = "region_short must be 2-8 lowercase alphanumeric characters and start with a letter."
  }
}

variable "resource_group_name" {
  type        = string
  description = "Exact workload resource group created by infra/bootstrap."

  validation {
    condition     = can(regex("^rg-[a-z0-9-]{3,80}$", var.resource_group_name))
    error_message = "resource_group_name must follow the rg-<workload>-<environment>-<region-short> convention."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to app resources."
  default = {
    component = "app"
    managedBy = "terraform"
    project   = "agentic-sdlc-starter-pack"
  }
}

variable "web_app_name" {
  type        = string
  description = "Exact precomputed globally unique Web App name."

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
