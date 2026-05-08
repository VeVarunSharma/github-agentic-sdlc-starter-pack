# Inputs sourced from infra/bootstrap outputs (set via repo variables
# AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID,
# AZURE_RESOURCE_GROUP). The CI workflow passes them as -var=... so
# Terraform never reads them from the OIDC token implicitly.

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID. From AZURE_SUBSCRIPTION_ID repo variable."
}

variable "tenant_id" {
  type        = string
  description = "Azure tenant ID. From AZURE_TENANT_ID repo variable."
}

variable "client_id" {
  type        = string
  description = "Client ID of the deploy MI. From AZURE_CLIENT_ID repo variable."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group created by infra/bootstrap. From AZURE_RESOURCE_GROUP repo variable."
}

variable "location" {
  type        = string
  description = "Azure region. Should match the bootstrap RG's region."
  default     = "eastus"
}

variable "name_prefix" {
  type        = string
  description = "Short prefix prepended to every resource name. Use kebab-case."
  default     = "agentic-sdlc"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,16}$", var.name_prefix))
    error_message = "name_prefix must be 3-17 chars, start with a letter, and contain only lowercase letters, digits, and hyphens."
  }
}

variable "acr_name" {
  type        = string
  description = "Globally-unique ACR name (5-50 lowercase alphanumeric)."

  validation {
    condition     = can(regex("^[a-z0-9]{5,50}$", var.acr_name))
    error_message = "acr_name must be 5-50 chars, lowercase letters and digits only."
  }
}

variable "acr_sku" {
  type        = string
  description = "ACR SKU. Basic for dev/test, Standard for production with geo-replication."
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "acr_sku must be one of: Basic, Standard, Premium."
  }
}

variable "app_service_plan_sku" {
  type        = string
  description = "App Service Plan SKU. B1 is the cheapest Linux container option; P1v3 for production."
  default     = "B1"
}

variable "container_image" {
  type        = string
  description = "Initial container image to deploy (e.g. <acr>.azurecr.io/sample-app:<sha>). Updated on each deploy by the workflow."
  default     = "mcr.microsoft.com/azuredocs/aci-helloworld:latest"
}

variable "log_retention_days" {
  type        = number
  description = "Log Analytics workspace retention in days. 30 is the free-tier minimum useful value."
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "log_retention_days must be between 30 and 730."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default = {
    project   = "agentic-sdlc-starter-pack"
    component = "app"
    managedBy = "terraform"
  }
}
