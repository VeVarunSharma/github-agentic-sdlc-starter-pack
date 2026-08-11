<!-- HAND-AUTHORED — path-scoped instructions for Terraform infrastructure code. -->
---
description: "Terraform conventions for the Azure App Service infrastructure"
applyTo: "infra/**/*.tf"
---

# Terraform conventions (`infra/**`)

These rules apply to every `.tf` file under `infra/`. They sit alongside
the awesome-copilot `terraform.instructions.md` and `azure-naming.instructions.md`
files installed by APM — those cover language-level Terraform best practice;
this file covers **the conventions specific to this repo**.

## Two-layer structure

This repo splits infra into two Terraform root modules with **different
permission models** — keep them strictly separate:

- **`infra/bootstrap/`** — one-time, **human-run with `az login`**. Creates
  the deploy identity (UAMI), federated credentials, the app resource
  group, ground-floor RBAC, and the tfstate backend.
- **`infra/app/`** — **CI-applied under OIDC**. Creates ACR, Log
  Analytics, App Insights, the App Service Plan, the Linux Web App, and
  the resource-scoped role assignments that depend on those resources
  existing (e.g. `AcrPull` on the Web App's system MI).

Never put resources in `bootstrap/` that depend on `app/` resources. Never
put identity / RBAC scaffolding in `app/`.

## Provider, version, and state

- Pin `terraform { required_version = ">= 1.6.0" }` in
  `versions.tf`.
- Pin every provider with the `~>` major.minor constraint:

  ```hcl
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    azuread = { source = "hashicorp/azuread", version = "~> 3.0" }
  }
  ```

- Configure the `azurerm` backend in `providers.tf` for the `app/`
  module, pointing at the Storage Account created by `bootstrap/`. Do
  not commit `terraform.tfvars` (it's `.gitignore`d); commit
  `terraform.tfvars.example` instead.

## Naming

Follow the awesome-copilot `azure-naming.instructions.md` rules. In this
repo, the convention for the resource group, ACR, and Web App names is:

- `rg-<workload>-<env>-<region-short>` — e.g. `rg-sdlcstarter-prod-eus`
- ACR names: `cr<workload><env><region-short>` — lowercase, no hyphens,
  ≤ 50 chars.
- Web App names: `app-<workload>-<env>-<region-short>` — globally
  unique; if a name collision is likely, append a 4-char random suffix.

Use `random_string` only when a name **must** be globally unique. Do not
sprinkle randomness into RG / Log Analytics names.

## Module structure

Every root module (`bootstrap/`, `app/`) has the same files:

- `versions.tf` — `terraform { required_version, required_providers, backend }`
- `providers.tf` — provider configuration blocks
- `variables.tf` — every input as a typed `variable {}` with `description`
- `main.tf` — resource composition (or split into `network.tf`, `compute.tf`
  etc. once `main.tf` exceeds ~150 lines)
- `outputs.tf` — every output with `description`
- `terraform.tfvars.example` — sample values, safe to commit

Reusable composition lives in `infra/app/modules/<name>/` with the same
file layout (no `terraform.tfvars.example` for child modules).

## Variable typing

- Always type variables explicitly. No bare `variable "x" {}`.
- Use `object({ ... })` types for grouped settings; do not use `any`.
- Provide `default` only when the value is genuinely optional.
- Add `validation {}` blocks for variables with constrained values
  (Azure region names, SKUs, environment ids).

```hcl
variable "environment" {
  type        = string
  description = "Deployment environment (e.g. dev, staging, prod)."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}
```

## Identity and RBAC

- **No long-lived credentials.** All compute uses managed identity; all
  CI uses OIDC federated credentials.
- The Web App has a **system-assigned MI**. ACR pulls happen via that
  MI with the `AcrPull` role assigned **after** the Web App resource is
  created (use `depends_on` if needed).
- `bootstrap/` creates separate plan, apply, and deploy UAMIs. Plan gets
  `Reader` on the workload RG; apply gets `Contributor` plus conditioned
  `Role Based Access Control Administrator`; deploy gets no broad bootstrap
  role. State access is `Storage Blob Data Contributor` on the exact
  container for plan/apply.
- `infra/app` grants the deploy UAMI only `AcrPush` + `Reader` on the exact
  ACR and `Website Contributor` on the exact parent Web App.
- Never use `User Access Administrator` or subscription-scope workflow roles.

## Formatting and linting

- `terraform fmt` clean — CI fails the PR otherwise.
- `terraform validate` clean — CI fails the PR otherwise.
- `tflint` is recommended (run via `scripts/verify.sh`) but not
  blocking in v1.0.

## What CI does on PRs

- `terraform fmt -check`
- `terraform validate`

CI **does not** run `terraform plan` on PRs from forks (no cloud
credentials are issued to fork PRs by design — see Spike D §4 fork-safety
note). Plan + apply happen in the `infra-apply.yml` workflow against the
`infra-apply` environment, which requires manual approval.
