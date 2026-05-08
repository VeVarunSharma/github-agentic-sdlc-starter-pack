<!-- HAND-AUTHORED — slash prompt for scaffolding a new Terraform child module. -->
---
mode: agent
description: "Scaffold a new Terraform child module under infra/app/modules/"
---

# /scaffold-tf-module

Scaffold a new Terraform child module under `infra/app/modules/<name>/`
that follows this repo's conventions
(`.github/instructions/infra-terraform.instructions.md`).

## Inputs

Ask the user for these if not already provided in the chat:

1. **Module name** (kebab-case, e.g. `app-service`, `key-vault`,
   `service-bus`). This becomes the directory name and the prefix for
   resource names inside the module.
2. **Purpose** — one-sentence description used in the module's README.
3. **Primary Azure resource type(s)** — e.g.
   `azurerm_linux_web_app + azurerm_service_plan`. Use this to scaffold
   the right resource blocks.
4. **Inputs the module needs** — list of `variable` names with types
   and descriptions.
5. **Outputs the module exposes** — list of `output` names.

## What to generate

Create the following files under `infra/app/modules/<name>/`. Every file
gets a one-line top-of-file comment naming the module.

- `versions.tf`

  ```hcl
  terraform {
    required_version = ">= 1.6.0"
    required_providers {
      azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    }
  }
  ```

- `variables.tf` — one typed `variable {}` per input, with `description`,
  `validation` blocks for constrained values, and `default` only when
  optional.
- `main.tf` — resource composition. If the module has more than ~5
  resources, split into per-concern files (`network.tf`, `compute.tf`).
- `outputs.tf` — one `output {}` per documented output, each with
  `description`.
- `README.md` — table of inputs, table of outputs, one usage example
  block. Use the same Markdown table layout as
  `infra/app/modules/_template/README.md` if present.

## Wire-in

After scaffolding the module, propose (but do not commit until the user
confirms) an example `module "<name>"` block to add to
`infra/app/main.tf` showing how to consume the new module.

## Style rules to follow

- Variables typed explicitly — no `any`.
- Resources named `<azurerm_type>.this` when there is one of them per
  module, otherwise `<azurerm_type>.<role>`.
- Tags merged from a `var.tags` map (with module-specific tags layered
  on top via `merge(var.tags, { module = "<name>" })`).
- No `provider {}` blocks inside the module — providers are configured
  by the root module.
- `terraform fmt` clean before responding.

## Acceptance check

Before returning, confirm:

- [ ] Every `variable` has `type`, `description`, and (where applicable)
      `validation`.
- [ ] Every `output` has `description`.
- [ ] `terraform fmt -check` would pass on every file you created.
- [ ] No hard-coded subscription IDs, secrets, or environment-specific
      values.
- [ ] README has both inputs and outputs tables.
