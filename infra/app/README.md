# `infra/app` — Application infrastructure (CI-applied via OIDC)

This Terraform module provisions everything the sample Node/Express app
needs to run on Azure App Service Linux Containers. It is **applied
from CI** (`infra-apply.yml`) using the OIDC-federated identity
created by `infra/bootstrap`. No long-lived Azure credentials live in
GitHub.

## What this module owns

| Resource | Purpose |
| --- | --- |
| `azurerm_container_registry.this` | Stores app images. Admin disabled — the Web App pulls via its system-assigned MI. |
| `azurerm_log_analytics_workspace.this` | Central log sink. |
| `azurerm_application_insights.this` | Workspace-based App Insights, wired into the Web App via app settings. |
| `azurerm_service_plan.this` | Linux App Service Plan (B1 default). |
| `azurerm_linux_web_app.this` | The Web App itself, container-hosted, system-assigned MI, /health probe, HTTPS-only. |
| `azurerm_role_assignment.webapp_acr_pull` | Web App MI → `AcrPull` on the registry. Requires `User Access Administrator` on the deploy MI at RG scope (granted by `infra/bootstrap`). |
| `azurerm_monitor_diagnostic_setting.webapp` | Ships HTTP logs, console logs, app logs, and metrics to Log Analytics. |

## What this module does **not** own

`infra/bootstrap` owns the resource group, the deploy managed
identity, the federated credentials, and the tfstate backend. None of
those resources are referenced here as `resource` blocks — only as
`data` (the RG) or via the OIDC-federated provider configuration.

That separation means CI never needs subscription-scope or
`User Access Administrator` permissions.

## Required inputs (from infra/bootstrap)

| Variable | Source | Notes |
| --- | --- | --- |
| `subscription_id` | repo var `AZURE_SUBSCRIPTION_ID` | |
| `tenant_id` | repo var `AZURE_TENANT_ID` | |
| `client_id` | repo var `AZURE_CLIENT_ID` | UAMI client ID |
| `resource_group_name` | repo var `AZURE_RESOURCE_GROUP` | |
| `acr_name` | choose at adoption | Globally unique, 5–50 lowercase alphanumeric. |

## Typical CI usage

```bash
cd infra/app

terraform init \
  -backend-config="resource_group_name=$AZURE_TFSTATE_RG" \
  -backend-config="storage_account_name=$AZURE_TFSTATE_STORAGE_ACCOUNT" \
  -backend-config="container_name=$AZURE_TFSTATE_CONTAINER"

terraform plan \
  -var="subscription_id=$AZURE_SUBSCRIPTION_ID" \
  -var="tenant_id=$AZURE_TENANT_ID" \
  -var="client_id=$AZURE_CLIENT_ID" \
  -var="resource_group_name=$AZURE_RESOURCE_GROUP" \
  -var="acr_name=$ACR_NAME"

terraform apply -auto-approve ...same vars...
```

`infra-apply.yml` does this exact flow, gated by the `infra-apply`
GitHub environment for human approval.

## What the deploy workflow consumes

`azure-deploy.yml` reads two outputs from the most recent
`terraform apply`:

- `acr_login_server` — for `az acr login` and `docker tag`.
- `web_app_name` — for `az webapp config container set`.

The deploy workflow **never re-runs `terraform apply`**. It only
rolls the container image forward. Infra changes flow through
`infra-apply.yml` so a code-only deploy can never silently mutate
infra.

## Local development (optional)

You can run this against your own subscription with `az login`:

```bash
cp terraform.tfvars.example terraform.tfvars
# Fill in subscription_id / tenant_id / client_id (your user, NOT
# the CI MI) and acr_name.

terraform init -backend=false   # local-only, no remote state
terraform plan
```

When running locally, drop `use_oidc = true` from
`providers.tf` (or override with `-var-file` containing
`use_oidc = false`). The CI uses OIDC.

## Drift / fork-safety

PR runs from forks **must not** execute `terraform plan` against the
real subscription — that would either leak the OIDC token to a fork's
`pull_request` event (mitigated but not eliminated) or fail with
permission errors. PR CI (`ci.yml`) runs `terraform fmt -check` and
`terraform validate` only. Cloud-backed plans are reserved for the
`infra-apply.yml` workflow which is gated by environment approval.
