# `infra/bootstrap` - Azure trust anchor

Run this root module locally with `az login`. It creates the workload and
tfstate resource groups, hardened state storage, and three purpose-specific
GitHub Actions OIDC identities.

## Identity and authorization model

| Identity | GitHub Environment | Azure authorization |
| --- | --- | --- |
| Plan | `infra-plan` | `Reader` on the exact workload resource group; `Storage Blob Data Contributor` on the exact state container |
| Apply | `infra-apply` | `Contributor` on the workload resource group; state-container data access; conditioned `Role Based Access Control Administrator` on the workload resource group |
| Deploy | `production` | No bootstrap role. `infra/app` grants `AcrPush` + `Reader` on the exact ACR and `Website Contributor` on the exact parent Web App. |

The apply identity's RBAC condition permits only the assignments created by
`infra/app`: `AcrPull` to a service principal (the Web App system identity),
and `AcrPush`, `Reader`, or `Website Contributor` to the exact deploy
principal. The condition follows Microsoft's
[constrained delegation examples](https://learn.microsoft.com/azure/role-based-access-control/delegate-role-assignments-examples)
and uses built-in role IDs rather than display names.

Separate subjects on one identity would not provide authorization isolation.
This module uses separate identities so each workflow receives a distinct
Azure permission boundary.

## GitHub OIDC subjects

New template adopters default to GitHub's immutable repository subject:

```text
repo:OWNER@OWNER-ID/REPO@REPO-ID:environment:ENVIRONMENT
```

Repositories that still emit the legacy subject must opt in explicitly:

```bash
./scripts/setup-azure-oidc.sh --legacy-subject
```

Subjects are exact and environment-bound; there is no pull-request credential
and no wildcard trust.

## State protections

The dedicated StorageV2 account has Shared Key disabled, OAuth as the portal
default, TLS 1.2 minimum, no anonymous nested items, blob versioning, 30-day
blob/container soft delete, 90-day old-version cleanup, and a `CanNotDelete`
lock by default. Active state is not immutable because Terraform must acquire
a lease and update lock metadata.

`storage_use_azuread = true` makes the AzureRM provider use OAuth for container
operations. Bootstrap grants the signed-in operator data-plane access before
creating the private container. A transient authorization error can occur
while a new role assignment propagates; rerunning `terraform apply` is safe.

The public endpoint remains enabled for standard GitHub-hosted runners. For
fixed-egress or regulated environments, use self-hosted/VNet runners and add
Storage network rules or a private endpoint.

## Run

The recommended entry point queries immutable GitHub IDs, deterministically
precomputes globally unique names, registers required Azure providers, applies
this module, creates the three GitHub Environments, and sets all repo variables:

```bash
az login
gh auth login
./scripts/setup-azure-oidc.sh --repo OWNER/REPO
```

Direct Terraform use is supported:

```bash
cp infra/bootstrap/terraform.tfvars.example infra/bootstrap/terraform.tfvars
terraform -chdir=infra/bootstrap init
terraform -chdir=infra/bootstrap apply
```

Bootstrap state is local by default because this module creates the remote
backend. Keep it protected and backed up, or configure the commented backend
in `versions.tf` to use an existing organization-owned state service.

## Rotation

After a rename, transfer, subject-mode migration, or environment recovery:

```bash
./scripts/setup-azure-oidc.sh --repo OWNER/REPO --rotate
```

Rotation reads existing Terraform outputs to preserve every Azure resource
name. Federated credential names include a subject hash and use
`create_before_destroy`, so replacements overlap instead of deleting trust
first. See `.github/skills/oidc-rotation/PLAYBOOK.md`.
