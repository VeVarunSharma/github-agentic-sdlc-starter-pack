# Azure OIDC setup

The starter pack uses three GitHub Actions OIDC identities with no client
secrets or certificates. Run:

```bash
az login
gh auth login
./scripts/setup-azure-oidc.sh --repo OWNER/REPO
```

The script queries the immutable owner and repository database IDs with `gh`,
derives stable globally unique resource names from those IDs plus the Azure
subscription ID, registers required Azure providers, applies
`infra/bootstrap`, creates GitHub Environments, and sets every repository
variable required before the first app apply.

## Trust and authorization boundaries

| GitHub Environment | Identity variable | Azure roles |
| --- | --- | --- |
| `infra-plan` | `AZURE_PLAN_CLIENT_ID` | Reader at the workload RG; Storage Blob Data Contributor at the state container |
| `infra-apply` | `AZURE_APPLY_CLIENT_ID` | Contributor at the workload RG; state-container data access; conditioned RBAC Administrator at the workload RG |
| `production` | `AZURE_DEPLOY_CLIENT_ID` | AcrPush + Reader at the exact ACR; Website Contributor at the exact Web App |

The production roles are created by `infra/app`; the deploy identity has no
broad bootstrap assignment. Website Contributor is intentionally scoped to the
parent Web App. It includes `Microsoft.Web/sites/*`, covering configuration,
restart, child slots, and swaps. `az acr login` requires registry control-plane
Reader in addition to `AcrPush`.

The apply identity uses `Role Based Access Control Administrator`, not
`User Access Administrator`, with a version 2.0 condition. It may create or
delete only:

- `AcrPull` assignments to service principals (for the Web App system MI);
- `AcrPush`, `Reader`, and `Website Contributor` assignments to the exact
  deploy principal.

The implementation follows Microsoft's
[role-assignment delegation condition examples](https://learn.microsoft.com/azure/role-based-access-control/delegate-role-assignments-examples)
and [built-in role IDs](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles).

Different subjects on one identity do not create authorization isolation.
Separate identities and separate Azure role assignments are the permission
boundary; GitHub Environments govern who can request each exact subject.

## Immutable and legacy subject formats

GitHub's immutable subject for repositories created, renamed, or transferred
after **2026-07-15** is:

```text
repo:OWNER@OWNER-ID/REPO@REPO-ID:environment:ENV
```

The setup script defaults to that format and creates exactly these subjects:

```text
repo:OWNER@OWNER-ID/REPO@REPO-ID:environment:infra-plan
repo:OWNER@OWNER-ID/REPO@REPO-ID:environment:infra-apply
repo:OWNER@OWNER-ID/REPO@REPO-ID:environment:production
```

There is no wildcard and no `pull_request` federation. Older repositories
whose tokens still use `repo:OWNER/REPO:environment:ENV` must opt in:

```bash
./scripts/setup-azure-oidc.sh --legacy-subject
```

The script never infers legacy mode from a date or repository name.

## Saved-plan workflow

`infra-apply.yml` has two jobs:

1. `infra-plan` checks out the exact workflow SHA, initializes with the provider
   lock file, validates, and creates `tfplan` with a five-minute lock timeout.
   Its summary contains only escaped resource addresses and allowlisted action
   names. The short-lived artifact is the binary plan only.
2. `infra-apply` waits for required reviewers, checks out the same SHA,
   initializes identically, downloads the same-run artifact, independently
   verifies its SHA-256, and applies that exact plan.

Saved plans can contain cleartext sensitive data. The workflow never prints or
uploads a JSON plan and retains the binary for only five days. Terraform's
normal stale-plan/state-serial rejection remains enabled.

## State hardening

The tfstate account disables Shared Key, defaults to OAuth, requires TLS 1.2,
blocks anonymous nested items, and uses a private container. Blob versioning,
30-day blob/container soft delete, and 90-day old-version cleanup protect
recovery without placing immutability on the active state blob. A
`CanNotDelete` account lock is enabled by default.

`Storage Blob Data Contributor` is required for both plan and apply because
Terraform state locking acquires a lease and writes lock metadata; a read-only
blob role is insufficient.

The public endpoint remains available for standard GitHub-hosted runners.
Higher-assurance deployments should use fixed-egress or VNet-connected
self-hosted runners, Storage network rules, and a private endpoint.

## Digest deployment and rollback

`azure-deploy.yml` keeps a human-readable commit-SHA tag for ACR inventory,
but deploys the digest returned by `docker/build-push-action`. Before any
production mutation it captures and validates the current
`siteConfig.linuxFxVersion`.

The default low-cost flow:

1. set production to `<acr>/<image>@sha256:<digest>`;
2. restart and verify the resulting `linuxFxVersion`;
3. probe `/health`;
4. on failure, restore the exact captured image, restart, and verify rollback
   health; the workflow remains failed and never emits a deployed summary.

For manual recovery, copy the exact known-good image from App Service
configuration and run:

```bash
az webapp config container set \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$AZURE_WEBAPP_NAME" \
  --container-image-name "<registry>/<image>@sha256:<digest>"
az webapp restart \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$AZURE_WEBAPP_NAME"
./scripts/smoke-health.sh "https://<web-app-hostname>/health"
```

Do not replace a known-good digest with a floating tag during incident
recovery.

## Optional S1+ staging slot

Slots are disabled by default because F1 and B1-B3 do not support them. To opt
in:

1. choose Standard S1 or higher in `infra/app`;
2. set Terraform `staging_slot_enabled=true` and optionally
   `staging_slot_name`;
3. run the approval-gated `Infra Apply` workflow;
4. set repository variables `AZURE_STAGING_SLOT_ENABLED=true` and
   `AZURE_STAGING_SLOT_NAME=staging`.

Terraform gives the slot its own system-assigned identity and exact-ACR
`AcrPull` assignment because managed identities are slot-specific and are not
swapped. The deploy workflow verifies both identities, role assignments,
secure config, and selected app settings before warming staging. After swap,
production `/health` must pass; otherwise the workflow swaps again and verifies
the previous production image and health.

## Deterministic names and repo variables

The script hashes the stable subscription/owner/repository IDs and uses the
suffix in globally unique names. It sets:

- `AZURE_PLAN_CLIENT_ID`, `AZURE_APPLY_CLIENT_ID`,
  `AZURE_DEPLOY_CLIENT_ID`, `AZURE_DEPLOY_PRINCIPAL_ID`;
- `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`;
- `AZURE_TFSTATE_RG`, `AZURE_TFSTATE_STORAGE_ACCOUNT`,
  `AZURE_TFSTATE_CONTAINER`;
- `AZURE_ACR_NAME`, `AZURE_WEBAPP_NAME`;
- `AZURE_LOCATION`, `AZURE_REGION_SHORT`, `AZURE_ENVIRONMENT`,
  `AZURE_WORKLOAD_NAME`, `AZURE_OIDC_SUBJECT_MODE`.

These are identifiers, not credentials. Access still requires a token with an
exact trusted subject and the corresponding Azure role assignments.

## Rotation

Use `--rotate` after a rename, transfer, subject-mode migration, or environment
repair:

```bash
./scripts/setup-azure-oidc.sh --repo OWNER/REPO --rotate
# Add --legacy-subject only when intentionally retaining legacy claims.
```

Rotation reads existing bootstrap outputs so it does not derive replacement
Azure resource names, and preserves the explicit
`AZURE_OIDC_SUBJECT_MODE` repository variable unless `--legacy-subject` is
passed. Subject hashes make credential names change, and Terraform
`create_before_destroy` overlaps each new credential with its old credential.
All three identities are rotated in one apply.

## Troubleshooting

| Error | Check |
| --- | --- |
| `AADSTS70021` | Subject mode, exact owner/repo IDs, and environment name |
| State `403` | Correct plan/apply client ID and exact container data role; allow role propagation after first bootstrap |
| Provider registration authorization failure | Run setup as a subscription operator able to register the listed providers |
| `az acr login` authorization failure | Deploy identity has both AcrPush and Reader on the exact ACR |
| Web App config/restart authorization failure | Website Contributor is assigned on the exact parent Web App |
