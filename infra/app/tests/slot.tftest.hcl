mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
    }
  }

  mock_data "azurerm_resource_group" {
    defaults = {
      location = "eastus"
      name     = "rg-sdlcstarter-prod-eus"
    }
  }
}

variables {
  acr_name            = "crsdlcstarterprod1234"
  deploy_principal_id = "11111111-1111-1111-1111-111111111111"
  resource_group_name = "rg-sdlcstarter-prod-eus"
  web_app_name        = "app-sdlcstarter-prod-eus-1234"
}

run "baseline_uses_direct_deployment" {
  command = plan

  assert {
    condition     = length(azurerm_linux_web_app_slot.staging) == 0
    error_message = "The B1 baseline must not create a deployment slot."
  }

  assert {
    condition = (
      !contains(keys(azurerm_linux_web_app.this.app_settings), "ApplicationInsightsAgent_EXTENSION_VERSION") &&
      !contains(keys(azurerm_linux_web_app.this.app_settings), "XDT_MicrosoftApplicationInsights_NodeJS")
    )
    error_message = "App Service auto-instrumentation must stay disabled when the OpenTelemetry SDK is used."
  }
}

run "standard_plan_creates_isolated_slot_identity" {
  command = plan

  variables {
    app_service_plan_sku = "S1"
    staging_slot_enabled = true
    staging_slot_name    = "staging"
  }

  assert {
    condition     = length(azurerm_linux_web_app_slot.staging) == 1
    error_message = "An enabled S1 staging slot must be created."
  }

  assert {
    condition     = azurerm_linux_web_app_slot.staging[0].identity[0].type == "SystemAssigned"
    error_message = "The staging slot must have its own system-assigned identity."
  }

  assert {
    condition = (
      toset(keys(azurerm_linux_web_app_slot.staging[0].app_settings)) ==
      toset(keys(azurerm_linux_web_app.this.app_settings)) &&
      azurerm_linux_web_app_slot.staging[0].app_settings["WEBSITES_PORT"] == "3000" &&
      azurerm_linux_web_app_slot.staging[0].app_settings["WEBSITES_ENABLE_APP_SERVICE_STORAGE"] == "false"
    )
    error_message = "Production and staging must receive equivalent app-setting keys and secure runtime values."
  }

  assert {
    condition     = length(azurerm_role_assignment.staging_slot_acr_pull) == 1
    error_message = "The slot identity must receive its own AcrPull assignment."
  }
}

run "basic_plan_rejects_staging_slot" {
  command = plan

  variables {
    app_service_plan_sku = "B1"
    staging_slot_enabled = true
  }

  expect_failures = [
    azurerm_service_plan.this,
  ]
}
