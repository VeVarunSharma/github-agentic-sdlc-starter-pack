###############################################################################
# Azure Static Web Apps — application module
#
# This file REPLACES the baseline `infra/app/main.tf`. Do not include both.
#
# Inherits from the root baseline:
#   - terraform { required_providers { azurerm = "~> 4.0" } } block
#   - the `azurerm` provider configuration
#   - the resource group, naming, and tagging conventions
#   - the `infra/bootstrap/` module (deploy managed identity + federated cred)
#
# What this module owns:
#   - azurerm_static_web_app           (the SPA hosting + managed Functions API)
#   - azurerm_log_analytics_workspace  (parity with baseline observability)
#   - azurerm_application_insights     (parity with baseline observability)
#
# Application *deployment* is handled by GitHub Actions
# (`Azure/static-web-apps-deploy@v1`), authenticated with the SWA API token
# exposed by the `api_key` attribute below. See the workflow at
# `.github/workflows/azure-deploy.yml` and the README for token vs OIDC.
###############################################################################

variable "name_prefix" {
  description = "Resource name prefix (e.g. 'agentic-sdlc-prod')."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that owns the Static Web App and observability resources."
  type        = string
}

variable "location" {
  description = <<-EOT
    Azure region for the Static Web App. Note: SWA is region-pinned for the
    control plane, but assets are served from the global edge regardless.
    Supported regions for Standard SKU include: westus2, centralus, eastus2,
    westeurope, eastasia. Check the docs for the current list.
  EOT
  type        = string
  default     = "westus2"
}

variable "tags" {
  description = "Tags applied to every resource in this module."
  type        = map(string)
  default     = {}
}

# Free SKU is fine for hobby / prototype use, but PR preview environments
# and bring-your-own Functions require Standard. We default to Standard so
# the example works end-to-end with the deploy workflow as-shipped.
variable "sku_tier" {
  description = "SWA SKU tier — 'Free' or 'Standard'. PR previews require Standard."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Free", "Standard"], var.sku_tier)
    error_message = "sku_tier must be 'Free' or 'Standard'."
  }
}

###############################################################################
# Observability — kept at parity with the baseline so dashboards and queries
# port over without change.
###############################################################################

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.name_prefix}-logs"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "this" {
  name                = "${var.name_prefix}-appi"
  resource_group_name = var.resource_group_name
  location            = var.location
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.this.id
  tags                = var.tags
}

###############################################################################
# Static Web App
#
# We intentionally do NOT set `repository_url`, `branch`, or
# `repository_token` here. Those fields wire up SWA's *built-in* GitHub
# integration, which conflicts with managing the deploy workflow ourselves
# in `.github/workflows/azure-deploy.yml`. Leaving them unset gives us a
# resource whose API token (`api_key`) we feed to
# `Azure/static-web-apps-deploy@v1` from CI.
###############################################################################

resource "azurerm_static_web_app" "this" {
  name                = "${var.name_prefix}-swa"
  resource_group_name = var.resource_group_name
  location            = var.location

  # Standard tier is required for: bring-your-own Functions (managed),
  # PR preview environments, custom auth providers, and private endpoints.
  sku_tier = var.sku_tier
  sku_size = var.sku_tier

  app_settings = {
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.this.connection_string
  }

  tags = var.tags

  # repository_url   = "https://github.com/<org>/<repo>"
  # repository_branch = "main"
  # repository_token  = var.github_pat
  # ^ Leave commented. We deploy via Azure/static-web-apps-deploy@v1 using
  #   the api_key output below; binding the repo here would create a second
  #   deploy pipeline managed by the SWA service.
}

###############################################################################
# Outputs
###############################################################################

output "static_web_app_id" {
  description = "Resource ID of the Static Web App."
  value       = azurerm_static_web_app.this.id
}

output "static_web_app_default_hostname" {
  description = "Default *.azurestaticapps.net hostname for the SPA."
  value       = azurerm_static_web_app.this.default_host_name
}

output "static_web_app_api_key" {
  description = <<-EOT
    Deployment token for the Static Web App. Wire this into the GitHub repo
    secret AZURE_STATIC_WEB_APPS_API_TOKEN — that's what the
    Azure/static-web-apps-deploy@v1 action authenticates with. Treat as a
    long-lived secret; rotate via `az staticwebapp secrets reset-api-key`.
  EOT
  value       = azurerm_static_web_app.this.api_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection string for client-side telemetry (safe to embed in the SPA)."
  value       = azurerm_application_insights.this.connection_string
  sensitive   = true
}
