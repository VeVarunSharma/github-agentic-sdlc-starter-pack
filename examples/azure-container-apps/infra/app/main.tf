# Variant: Container Apps replacement for `infra/app/main.tf`.
# Drop this file in over the baseline (or copy this whole directory).
# Inputs and outputs intentionally mirror the baseline so the deploy
# workflow only changes the deploy step itself.

data "azurerm_resource_group" "app" {
  name = var.resource_group_name
}

locals {
  rg = data.azurerm_resource_group.app

  ca_env_name = "${var.name_prefix}-cae"
  ca_app_name = "${var.name_prefix}-app"
  law_name    = "${var.name_prefix}-law"
  ai_name     = "${var.name_prefix}-ai"
}

# ---------------------------------------------------------------------------
# Container registry — identical to the baseline
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
# Observability — identical to the baseline
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
# Container Apps environment — the regional boundary that hosts apps.
# Connected to the Log Analytics workspace for stdout/stderr capture.
# ---------------------------------------------------------------------------

resource "azurerm_container_app_environment" "this" {
  name                       = local.ca_env_name
  resource_group_name        = local.rg.name
  location                   = local.rg.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  tags                       = var.tags
}

# ---------------------------------------------------------------------------
# Container App — the workload itself, with system-assigned MI for ACR pull.
#
# `min_replicas = 0` enables scale-to-zero. Bump to >= 1 if you need a warm
# worker for low-latency cold-start avoidance.
# ---------------------------------------------------------------------------

resource "azurerm_container_app" "this" {
  name                         = local.ca_app_name
  resource_group_name          = local.rg.name
  container_app_environment_id = azurerm_container_app_environment.this.id
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type = "SystemAssigned"
  }

  # Pull images from ACR using the Container App's MI.
  registry {
    server   = azurerm_container_registry.this.login_server
    identity = "System"
  }

  ingress {
    external_enabled = true
    target_port      = 3000
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "app"
      image  = var.container_image
      cpu    = var.cpu
      memory = var.memory

      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = azurerm_application_insights.this.connection_string
      }
      env {
        name  = "PORT"
        value = "3000"
      }

      liveness_probe {
        transport = "HTTP"
        port      = 3000
        path      = "/health"
        # Container Apps probes don't accept the same exhaustive tunables as
        # AKS — the defaults are sensible for HTTP /health.
      }

      readiness_probe {
        transport = "HTTP"
        port      = 3000
        path      = "/health"
      }
    }

    http_scale_rule {
      name                = "http-scaler"
      concurrent_requests = "20"
    }
  }

  lifecycle {
    # The deploy workflow rolls images forward via
    # `az containerapp update --image ...`. Ignoring the image attr
    # prevents Terraform from reverting to the variable's default on
    # the next apply.
    ignore_changes = [
      template[0].container[0].image,
    ]
  }
}

# ---------------------------------------------------------------------------
# RBAC — Container App's MI gets AcrPull on the registry.
# Same as the baseline; just a different principal_id source.
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "containerapp_acr_pull" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.this.identity[0].principal_id
}
