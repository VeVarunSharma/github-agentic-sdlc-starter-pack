# Repo settings checklist

One-time GitHub repo settings that **cannot** be expressed as files in
the repo — they live in the GitHub UI / API. Walk through this list
once after creating a new repo from the template.

## 1 — Actions permissions

`Settings → Actions → General`

- **Workflow permissions:** "Read repository contents and packages
  permissions" (not "Read and write"). Workflows that need write
  permissions request them explicitly via `permissions:` blocks.
- **Allow GitHub Actions to create and approve pull requests:** OFF.
  (We don't want bots merging their own PRs.)
- **Fork pull request workflows from outside collaborators:** "Require
  approval for first-time contributors". This is the default; verify it
  hasn't been relaxed.

## 2 — GHAS features

`Settings → Code security`

| Feature | Plan availability | Default |
|---------|-------------------|---------|
| Dependency graph | All plans | ON |
| Dependabot alerts | All plans | ON |
| Dependabot security updates | All plans | ON |
| Dependabot version updates | All plans | Configured via `.github/dependabot.yml` |
| Code scanning (CodeQL) | Free for public repos; GHAS required for private | Configured via `.github/workflows/codeql.yml` |
| Secret scanning | Free for public repos; GHAS required for private | ON |
| Push protection | Free for public repos; GHAS required for private | ON |
| Private vulnerability reporting | All plans | ON (referenced by `SECURITY.md`) |

For private repos without GHAS, drop the `codeql.yml` required-check
from `.github/rulesets/main-branch-enforce.json` before importing the
ruleset, or you'll lock yourself out of merging.

## 3 — Environments

`Settings → Environments` — create two environments. Both reference
the same Azure subscription but use **different federated credential
subjects** so an app deploy can never mutate infra and vice versa.

| Environment | Subject | Approvers | Purpose |
|-------------|---------|-----------|---------|
| `production` | `repo:<owner>/<repo>:environment:production` | Auto (push to main) | App image deploy via `azure-deploy.yml` |
| `infra-apply` | `repo:<owner>/<repo>:environment:infra-apply` | **Required reviewers** | Terraform apply via `infra-apply.yml` |

The federated credentials themselves are created by
`./scripts/setup-azure-oidc.sh`. See
[`azure-oidc-setup.md`](./azure-oidc-setup.md).

## 4 — Branch protection rulesets

Two JSON rulesets ship in [`.github/rulesets/`](../.github/rulesets/):

- `main-branch-evaluate.json` — evaluate-only (visible warnings, no
  blocking). **Import this first** so you can shake out the workflows.
- `main-branch-enforce.json` — required-for-merge. Import only after
  every required check has appeared green on at least one PR.

Import:

```bash
gh api -X POST /repos/<owner>/<repo>/rulesets \
  --input .github/rulesets/main-branch-evaluate.json
```

Required-check names (must match exactly, case-sensitive):

| Required check name | Source workflow → job → name |
|---------------------|------------------------------|
| `app — lint + tests + audit` | `ci.yml` → `app-lint-test` |
| `terraform — fmt + validate (infra/bootstrap)` | `ci.yml` → `terraform-fmt-validate` (matrix) |
| `terraform — fmt + validate (infra/app)` | `ci.yml` → `terraform-fmt-validate` (matrix) |
| `terraform — fmt + validate (examples/azure-container-apps/infra/app)` | `ci.yml` → `terraform-fmt-validate` (matrix) |
| `docker — build + health smoke` | `ci.yml` → `docker-build` |
| `repository — workflows + shell + JSON + lockfiles` | `ci.yml` → `repository-validation` |
| `Analyze (javascript-typescript)` | `codeql.yml` → `analyze` (matrix) |
| `apm install + audit` | `apm-audit.yml` → `audit` |
| `Review dependency changes` | `dependency-review.yml` → `dependency-review` |

> **Graduation pitfall.** A required check that has never run is an
> "indefinite pending" — PRs are unmergeable. Open one PR that exercises
> every workflow path **before** importing `main-branch-enforce.json`.

## 5 — CODEOWNERS

[`.github/CODEOWNERS`](../.github/CODEOWNERS) ships with `<owner>/<team>`
placeholders. Either:

- Replace via the template-cleanup workflow on first push, **or**
- Edit by hand to use `@username` references if you don't have a team.

A CODEOWNERS file with non-existent team names silently no-ops review
requests — the worst kind of failure mode. Verify by opening a test PR
and confirming the right reviewers are auto-requested.

## 6 — Repo variables (set by `setup-azure-oidc.sh`)

`Settings → Secrets and variables → Actions → Variables`

| Variable | Set by | Notes |
|----------|--------|-------|
| `AZURE_CLIENT_ID` | setup script | UAMI client ID |
| `AZURE_TENANT_ID` | setup script | |
| `AZURE_SUBSCRIPTION_ID` | setup script | |
| `AZURE_RESOURCE_GROUP` | setup script | App resource group name |
| `AZURE_TFSTATE_RG` | setup script | tfstate Storage RG |
| `AZURE_TFSTATE_STORAGE_ACCOUNT` | setup script | tfstate Storage Account |
| `AZURE_TFSTATE_CONTAINER` | setup script | tfstate blob container |
| `AZURE_ACR_NAME` | **manual after first `infra-apply` run** | Set after `infra-apply.yml` outputs the ACR name |
| `AZURE_WEBAPP_NAME` | **manual after first `infra-apply` run** | Same |

Variables (not secrets) is intentional — these IDs aren't credentials.
The federated credential is the security boundary. See
[`azure-oidc-setup.md`](./azure-oidc-setup.md).

## 7 — Optional: Copilot auto-assign

If you want Copilot to pick up issues automatically (versus manual
`@copilot` assignment), set repo variable `COPILOT_AUTO_ASSIGN=true`.
The workflow at `.github/workflows/copilot-auto-assign.yml` is opt-in
via that variable. Default is OFF — see
[`spike-b-copilot-assignment.md`](./spike-b-copilot-assignment.md) for
the rationale.

## 8 — Discussions, labels, funding (optional)

Not in v1.0. Tracked as future enhancements in
[`maintenance-matrix.md`](./maintenance-matrix.md).
