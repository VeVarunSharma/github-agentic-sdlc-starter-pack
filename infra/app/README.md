# `infra/app` - CI-applied application infrastructure

This module creates ACR, Log Analytics, Application Insights, an App Service
Plan, the Linux Web App, and an optional S1+ staging slot. The manual
`infra-apply.yml` workflow plans with
the `infra-plan` identity and applies the exact saved binary plan with the
`infra-apply` identity.

## Required inputs

| Terraform variable | Repository variable |
| --- | --- |
| `resource_group_name` | `AZURE_RESOURCE_GROUP` |
| `acr_name` | `AZURE_ACR_NAME` |
| `web_app_name` | `AZURE_WEBAPP_NAME` |
| `deploy_principal_id` | `AZURE_DEPLOY_PRINCIPAL_ID` |
| `environment` | `AZURE_ENVIRONMENT` |
| `region_short` | `AZURE_REGION_SHORT` |
| `workload_name` | `AZURE_WORKLOAD_NAME` |
| `staging_slot_enabled` | `AZURE_STAGING_SLOT_ENABLED` (optional, defaults `false`) |
| `staging_slot_name` | `AZURE_STAGING_SLOT_NAME` (optional, defaults `staging`) |

All values are created by `scripts/setup-azure-oidc.sh` before the first app
apply, eliminating the former ACR/Web App variable deadlock.

Provider authentication is not represented by Terraform variables. CI supplies
`ARM_USE_OIDC`, `ARM_USE_AZUREAD`, `ARM_CLIENT_ID`, `ARM_TENANT_ID`, and
`ARM_SUBSCRIPTION_ID` per job, so the saved plan can move from the plan
identity to the apply identity without embedding identity configuration.

## Resource-scoped deploy roles

This module grants the deploy UAMI:

- `AcrPush` and control-plane `Reader` on the exact registry (`az acr login`
  needs both);
- `Website Contributor` on the exact parent Web App, which covers
  configuration, restart, child slots, and swap operations;
- no resource-group or bootstrap role.

The Web App system identity receives `AcrPull` on the exact registry.
When enabled, the staging slot receives a distinct system identity and its own
exact-registry `AcrPull` assignment. This is required because slot identities
are not swapped.
Built-in IDs come from Microsoft's
[Azure built-in roles](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles).

## CI and local use

The workflow initializes the AzureAD backend, validates, saves `tfplan`, uploads
the binary for five days, verifies its SHA-256 in the approval-gated apply job,
and runs only:

```bash
terraform apply -input=false -auto-approve -lock-timeout=5m tfplan
```

Terraform rejects a stale plan if state changed while approval was pending.

For local Azure CLI use:

```bash
az login
export ARM_SUBSCRIPTION_ID="<subscription-id>"
cp infra/app/terraform.tfvars.example infra/app/terraform.tfvars
terraform -chdir=infra/app init -backend=false
terraform -chdir=infra/app plan
```

The provider deliberately disables automatic resource-provider registration.
The setup script registers `Microsoft.Authorization`,
`Microsoft.ContainerRegistry`, `Microsoft.Insights`,
`Microsoft.ManagedIdentity`, `Microsoft.OperationalInsights`,
`Microsoft.Resources`, `Microsoft.Storage`, and `Microsoft.Web` before
bootstrap.

## Optional staging slot

The default B1 plan uses the direct, health-verified rollback path and creates
no slot. Slots require Standard, Premium, or Isolated:

```hcl
app_service_plan_sku = "S1"
staging_slot_enabled = true
staging_slot_name    = "staging"
```

Terraform rejects slot enablement on F1/B1-B3. The slot mirrors the production
TLS, FTPS, HTTP/2, health, storage, telemetry, and managed-ACR settings. Its
name and hostname are the only slot outputs, and both are non-sensitive.
When disabled, those outputs are empty strings.
`terraform test` exercises the default no-slot plan, an enabled S1 slot with a
distinct identity/AcrPull assignment, and rejection of a B1 slot request.
