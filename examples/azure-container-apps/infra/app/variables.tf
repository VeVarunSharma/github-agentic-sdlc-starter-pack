# Variables for the Container Apps variant.
# The first eight (subscription_id…container_image, log_retention_days, tags)
# are intentionally identical to the baseline so the OIDC bootstrap and
# infra-apply workflow don't change. The last four (min_replicas, max_replicas,
# cpu, memory) are Container-Apps-specific.

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

variable "container_image" {
  type        = string
  description = "Initial container image. Updated on each deploy by the workflow."
  default     = "mcr.microsoft.com/azuredocs/aci-helloworld:latest"
}

variable "log_retention_days" {
  type        = number
  description = "Log Analytics workspace retention in days."
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
    variant   = "container-apps"
    managedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Container-Apps-specific tunables
# ---------------------------------------------------------------------------

variable "min_replicas" {
  type        = number
  description = "Minimum replicas. Set to 0 for scale-to-zero (dev/test); >= 1 for production to avoid cold starts."
  default     = 0

  validation {
    condition     = var.min_replicas >= 0 && var.min_replicas <= 100
    error_message = "min_replicas must be between 0 and 100."
  }
}

variable "max_replicas" {
  type        = number
  description = "Maximum replicas the HTTP scaler can fan out to."
  default     = 10

  validation {
    condition     = var.max_replicas >= 1 && var.max_replicas <= 1000
    error_message = "max_replicas must be between 1 and 1000."
  }
}

variable "cpu" {
  type        = number
  description = "vCPU per replica. Allowed values for the Consumption profile: 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0."
  default     = 0.5

  validation {
    condition     = contains([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0], var.cpu)
    error_message = "cpu must be one of: 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0."
  }
}

variable "memory" {
  type        = string
  description = "Memory per replica (e.g. \"1Gi\"). Must be paired with a valid CPU value per Container Apps Consumption profile."
  default     = "1Gi"

  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)?Gi$", var.memory))
    error_message = "memory must look like '1Gi', '1.5Gi', '2Gi', etc."
  }
}
