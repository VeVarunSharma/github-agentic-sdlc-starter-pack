<!-- HAND-AUTHORED — multi-step skill for rotating the Azure OIDC federated credential. -->
---
name: oidc-rotation
description: "Rotate the Azure federated credential after a repo or environment rename"
applyTo: "infra/bootstrap/**"
---

# Skill: OIDC rotation

Rotate the Azure federated credentials when the repo is renamed,
transferred to a new owner, or when an environment name changes. This
is the single most common operational fragility in the OIDC-to-Azure
flow (Spike D §9, rubber-duck #9) — this skill turns the recovery from
"figure it out on the fly" into a deterministic procedure.

## When to invoke this skill

- The GitHub repo was renamed (`old-name` → `new-name`).
- The repo was transferred to a different owner / org.
- A workflow environment was renamed (e.g. `staging` → `pre-prod`).
- The CI deploy job started failing with `AADSTS70021: No matching
  federated identity record found` after one of the above.

## Inputs

Ask the user for these before doing anything:

1. **Old subject claim** — e.g. `repo:acme/old-repo:environment:production`.
2. **New subject claim** — e.g. `repo:acme/new-repo:environment:production`.
3. **UAMI name + resource group** — from `infra/bootstrap` outputs
   (`deploy_uami_name`, `bootstrap_rg_name`).
4. Confirmation that the user has `az login` with rights to update
   federated credentials on the UAMI (Contributor on the bootstrap RG
   is sufficient).

## Steps

See [`PLAYBOOK.md`](./PLAYBOOK.md) for the full step-by-step procedure
with copy-paste-able commands, expected outputs, and rollback notes.

The high-level steps:

1. Discover existing federated credentials on the UAMI.
2. Add the new federated credential **alongside** the old one (do not
   delete the old one yet — overlap window prevents downtime).
3. Run a deploy on the new credential to confirm it works (use
   `workflow_dispatch` on `azure-deploy.yml`).
4. Once confirmed, remove the old federated credential.
5. Update the repo variables (`AZURE_*`) **only if** the UAMI itself
   changed — variables hold the client/tenant/subscription IDs, which
   don't change during a rename.
6. Update `docs/azure-oidc-setup.md` if the rename is permanent.

## What this skill must NOT do

- Do not delete the old federated credential before the new one is
  confirmed working.
- Do not regenerate the UAMI — that requires re-running
  `infra/bootstrap` and re-issuing every role assignment.
- Do not commit any subject-claim values to the repo — they are derived
  from the repo name + environment name dynamically.
- Do not skip the `workflow_dispatch` validation step; "looks right" is
  not the same as "works".

## Done when

- A `workflow_dispatch` run of `azure-deploy.yml` completes successfully
  on the new federated credential.
- The old federated credential has been removed from the UAMI.
- `docs/azure-oidc-setup.md` references the new subject claim if the
  rename is permanent.
