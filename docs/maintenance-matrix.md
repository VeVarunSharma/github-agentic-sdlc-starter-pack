# Maintenance matrix

What to update when, who owns it, and how to know when something has
gone stale.

## Recurring tasks

| Cadence | Task | Owner | Triggered by |
|---------|------|-------|--------------|
| Continuous | Dependabot security updates merged | Reviewer (human) | Dependabot alert → auto-PR |
| Weekly | `apm update` PR review | DevEx / platform team | `.github/workflows/apm-update.yml` |
| Weekly | npm version-update PRs | Reviewer (human) | `.github/dependabot.yml` |
| Weekly | GitHub Actions version-update PRs | Reviewer (human) | `.github/dependabot.yml` |
| Weekly | CodeQL scheduled scan | (automated) | `.github/workflows/codeql.yml` cron |
| Quarterly | Refresh `docs/upstream-sources.md` "last verified" SHAs | DevEx / platform team | Manual |
| Quarterly | Review `apm-policy.yml` allowlist for new orgs | DevEx / platform team | Manual |
| Quarterly | Review hand-authored `.github/` primitives — still relevant? | Repo owner | Manual |
| Annually | Refresh `infra/bootstrap/` — Terraform, provider, AzureRM versions | DevEx / platform team | Manual |
| Annually | Re-bootstrap OIDC federated credentials if rotated subjects (e.g. repo rename) | Repo owner | Manual or via `oidc-rotation` skill |
| Annually | Review the `enterprise-hardening.md` overlay against current GHAS feature set | DevEx / platform team | Manual |

## Drift detection

How each kind of drift surfaces:

| Kind of drift | Detected by | What you see |
|---------------|-------------|--------------|
| APM-managed file edited by hand | `apm-audit.yml` PR check | Audit job fails with "drift in managed file" |
| `apm.lock.yaml` out of sync with `apm.yml` | `apm-audit.yml` PR check | Audit job fails with "lockfile out of date" |
| Hand-authored file added under `.github/` | `apm-audit.yml` PR check | Warning only ("unmanaged file"), tolerated by `unmanaged_files.action: warn` |
| Vulnerable npm dep introduced | `dependency-review.yml` PR check | Block on high/critical CVEs |
| Vulnerable Action introduced | `dependency-review.yml` PR check | Same |
| Terraform syntax broken | `ci.yml` `terraform-fmt-validate` matrix job | PR check fails |
| Required check renamed without ruleset update | Branch protection rule evaluation | "Indefinite pending" — PR can't merge |
| OIDC federated subject mismatch (e.g. repo rename) | `azure-deploy.yml` runtime | `AADSTS70021: No matching federated identity record found` — see [`azure-oidc-setup.md`](./azure-oidc-setup.md) |
| awesome-copilot upstream moved on | `apm-update.yml` weekly PR | Auto-PR opens; reviewer decides |

## Ownership map

| Area | Owner |
|------|-------|
| `app/` | App team |
| `infra/app/` | App team (via PR) + DevEx team (via `infra-apply.yml` approval) |
| `infra/bootstrap/` | DevEx / platform team (one-time + rotations) |
| `.github/copilot-instructions.md` and other hand-authored `.github/` files | Repo owner + reviewers |
| `apm.yml`, `apm-policy.yml`, `apm.lock.yaml` | DevEx / platform team |
| `.github/workflows/` | DevEx / platform team |
| `.github/rulesets/` | DevEx / platform team + repo owner (graduation) |
| `.github/CODEOWNERS` | Repo owner |
| `docs/` | Author of the linked feature; DevEx team for cross-cutting docs |
| `scripts/` | DevEx / platform team |

## Health signals

Repos following the baseline should expect:

- **Green CI rate ≥ 95%.** Investigate red-CI streaks > 2 days.
- **Time-to-merge for agent PRs < 24h** (after first review). Slower
  → probably a context gap; revisit the spec issue template or the
  agent's instructions.
- **Dependabot PRs merged within 7 days.** Older = security risk.
- **Zero outstanding CodeQL critical alerts.** Triage within 7 days.
- **Zero outstanding Dependabot critical alerts.** Triage within 7 days.

## When to bump major versions

| Component | Bump signal |
|-----------|-------------|
| Node.js (sample app) | Each LTS cut (~April every 2 years). Update `app/package.json` `engines.node`, `Dockerfile` base image, devcontainer image. |
| Terraform CLI | Each minor release; pin in `infra/*/versions.tf` |
| AzureRM provider | Quarterly; coordinate with bootstrap apply |
| APM CLI | When a breaking change is announced; update `scripts/install-apm.sh` `APM_VERSION` and `.github/workflows/apm-audit.yml`. The `apm_cli_version` field does NOT exist in `apm-policy.yml`; pin the CLI via `install-apm.sh`. |
| GHAS features | When GitHub announces new free-tier features applicable to the baseline — update [`repo-settings-checklist.md`](./repo-settings-checklist.md) |
