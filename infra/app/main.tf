data "azurerm_resource_group" "app" {
  name = var.resource_group_name
}

locals {
  rg = data.azurerm_resource_group.app

  webapp_name = "${var.name_prefix}-app"
  plan_name   = "${var.name_prefix}-plan"
  law_name    = "${var.name_prefix}-law"
  ai_name     = "${var.name_prefix}-ai"
}

# ---------------------------------------------------------------------------
# Container registry
# Admin user disabled — the Web App pulls images via its system-assigned
# managed identity, which gets AcrPull (see role assignment below).
# ---------------------------------------------------------------------------

resource "azurerm_container_registry" "this" {
  name                = var.acr_name
  resource_group_name = local.rg.name
  location            = local.rg.location
  sku                 = var.acr_sku
  admin_enabled       = false
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Observability — Log Analytics workspace + workspace-based App Insights
# ---------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "this" {
  name                = local.law_name
  resource_group_name = local.rg.name
  location            = local.rg.location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

resource "azurerm_application_insights" "this" {
  name                = local.ai_name
  resource_group_name = local.rg.name
  location            = local.rg.location
  workspace_id        = azurerm_log_analytics_workspace.this.id
  application_type    = "Node.JS"
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# App Service Plan + Linux Web App (container)
# ---------------------------------------------------------------------------

resource "azurerm_service_plan" "this" {
  name                = local.plan_name
  resource_group_name = local.rg.name
  location            = local.rg.location
  os_type             = "Linux"
  sku_name            = var.app_service_plan_sku
  tags                = var.tags
}

resource "azurerm_linux_web_app" "this" {
  name                = local.webapp_name
  resource_group_name = local.rg.name
  location            = local.rg.location
  service_plan_id     = azurerm_service_plan.this.id
  https_only          = true
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on           = var.app_service_plan_sku != "F1" && var.app_service_plan_sku != "B1"
    health_check_path   = "/health"
    ftps_state          = "Disabled"
    http2_enabled       = true
    minimum_tls_version = "1.2"

    # Pull container images from ACR using the Web App's system-assigned MI.
    container_registry_use_managed_identity = true

    application_stack {
      docker_image_name   = var.container_image
      docker_registry_url = "https://${azurerm_container_registry.this.login_server}"
    }
  }

  app_settings = {
    WEBSITES_PORT                              = "3000"
    APPLICATIONINSIGHTS_CONNECTION_STRING      = azurerm_application_insights.this.connection_string
    ApplicationInsightsAgent_EXTENSION_VERSION = "~3"
    XDT_MicrosoftApplicationInsights_NodeJS    = "1"
    DOCKER_ENABLE_CI                           = "true"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE        = "false"
  }

  logs {
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
    application_logs {
      file_system_level = "Information"
    }
  }

  lifecycle {
    # The deploy workflow rolls images forward via
    # `az webapp config container set --container-image-name ...`.
    # Ignoring the docker_image_name field prevents Terraform from
    # reverting to the variable's default on the next apply.
    ignore_changes = [
      site_config[0].application_stack[0].docker_image_name,
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }
}

# ---------------------------------------------------------------------------
# RBAC — Web App's MI gets AcrPull on the registry
# This is the role assignment that REQUIRED `User Access Administrator`
# on the deploy MI at RG scope (granted in infra/bootstrap).
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "webapp_acr_pull" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.this.identity[0].principal_id
}

# ---------------------------------------------------------------------------
# Diagnostic settings — ship Web App + ACR logs to Log Analytics
# ---------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "webapp" {
  name                       = "to-log-analytics"
  target_resource_id         = azurerm_linux_web_app.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "AppServiceHTTPLogs"
  }
  enabled_log {
    category = "AppServiceConsoleLogs"
  }
  enabled_log {
    category = "AppServiceAppLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
