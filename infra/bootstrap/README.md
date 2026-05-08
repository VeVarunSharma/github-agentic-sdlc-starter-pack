# `infra/bootstrap` — One-time Azure setup for OIDC

This Terraform module is run **once, by a human**, with `az login`. It
provisions the trust anchor for the rest of the SDLC: a
user-assigned managed identity that GitHub Actions will assume via
OIDC, the federated credentials for that identity, the app resource
group, and an Azure Storage container for the `infra/app` remote
tfstate.

After this runs successfully you (or `scripts/setup-azure-oidc.sh`)
write the four output values to GitHub repo *variables* (not
secrets — the IDs are not credentials). From that point forward CI
pushes, PRs, and the deploy workflow can run without any long-lived
secret in GitHub.

## What this module owns

| Resource | Why it lives in bootstrap |
| --- | --- |
| App resource group (`<name_prefix>-app-rg`) | Needs to exist before `infra/app` can place anything inside it. |
| User-assigned managed identity (`<name_prefix>-deploy-mi`) | The OIDC trust anchor; never recreated unless the repo is retired. |
| Federated identity credentials (production / infra-apply / pull_request) | Bound to specific GitHub subjects — renames invalidate them, see "Rotation". |
| `Contributor` and `User Access Administrator` on the app RG | RG-scope so the deploy MI can both create resources and grant `AcrPull` to the Web App MI later from inside `infra/app`. |
| tfstate storage account, container, blob `Storage Blob Data Contributor` role | Backend used by `infra/app` for remote state; created here to break the bootstrap chicken-and-egg. |

## What this module does **not** own

These belong to `infra/app` because they depend on the app workload:

- ACR, Log Analytics, App Insights, App Service Plan, Linux Web App
- The system-assigned managed identity on the Web App
- The `AcrPull` role assignment scoped to the ACR (Web App MI as principal)

That split keeps `infra/app` re-runnable from CI without ever
needing `User Access Administrator` at any scope wider than the app
RG it inherits.

## Run it

```bash
# 1. Authenticate as a human with permission to create RG + UAMI +
#    role assignments at the subscription scope.
az login
az account set --subscription <subscription-id>

cd infra/bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: subscription_id, github_owner, github_repo,
# state_storage_account_name (must be globally unique).

terraform init
terraform apply
```

Or use the wrapper:

```bash
./scripts/setup-azure-oidc.sh
```

The wrapper auto-detects the GitHub repo from `git remote -v`, prompts
for missing values, runs `terraform apply`, then writes the
`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
`AZURE_RESOURCE_GROUP`, `AZURE_TFSTATE_*` repo variables via `gh
variable set`.

## Outputs that become GitHub repo variables

| Terraform output | GitHub repo variable | Used by |
| --- | --- | --- |
| `client_id` | `AZURE_CLIENT_ID` | `azure/login@v2` |
| `tenant_id` | `AZURE_TENANT_ID` | `azure/login@v2` |
| `subscription_id` | `AZURE_SUBSCRIPTION_ID` | `azure/login@v2`, `terraform` provider |
| `app_resource_group_name` | `AZURE_RESOURCE_GROUP` | `infra/app`, deploy workflow |
| `tfstate_storage_account_name` | `AZURE_TFSTATE_STORAGE_ACCOUNT` | `terraform init -backend-config` |
| `tfstate_resource_group_name` | `AZURE_TFSTATE_RG` | `terraform init -backend-config` |
| `tfstate_container_name` | `AZURE_TFSTATE_CONTAINER` | `terraform init -backend-config` |

## Rotation: when the federated credentials need to be re-issued

Entra federated credentials require an exact-match subject claim
(`repo:<owner>/<repo>:environment:production` or similar). Any of
the following events invalidates them:

- The repo is renamed.
- The repo is transferred to a different owner.
- A GitHub Environment used in the subject claim is renamed.
- You decide to add a new environment (e.g. `staging`).

Rotation procedure (also packaged as the
`.github/skills/oidc-rotation/PLAYBOOK.md` skill):

```bash
# Re-run bootstrap with the corrected variables.
./scripts/setup-azure-oidc.sh --rotate
# Or manually:
cd infra/bootstrap
terraform apply -var=github_owner=<new-owner> -var=github_repo=<new-repo>
```

The federated credentials are expressed as a `for_each` map over
`local.federation_subjects`, so adding or renaming a subject is a
single-variable change that re-applies cleanly.

## State

By default this module uses **local state**. That's fine for a
one-time bootstrap operated by a single person — the alternative
(remote state) creates a chicken-and-egg with the storage account this
module is creating.

If your org already has a tfstate storage account, uncomment the
`backend "azurerm"` block in `versions.tf` and run
`terraform init -backend-config=...`.
