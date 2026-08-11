# `.github/rulesets/` — Branch protection as code

Two rulesets ship with the starter pack. Import the one that matches
where you are in your adoption curve:

| File | Mode | When to use |
| --- | --- | --- |
| `main-branch-evaluate.json` | `evaluate` | **Default for new repos.** Logs rule outcomes to *Insights → Rule insights* without blocking merges. Use this for the first 1–2 weeks so you can verify each required check binds to the right Actions job before turning on the gate. |
| `main-branch-enforce.json` | `active` | **Graduation.** Blocks merges that violate any rule. Only flip after every required check has run on at least one PR. |

## Why two files

GitHub rulesets address an old footgun: required checks are matched
**by name**, and a name that never appears on a PR is silently
ignored. If you flip straight to `enforce` mode and one of the
required check names doesn't match a real workflow job, **every PR
becomes unmergeable** until you fix the names.

Evaluate mode lets you watch the names bind correctly without
blocking anyone.

## Required check names (must match workflow job display names)

| Check name | Workflow file | Job |
| --- | --- | --- |
| `app — lint + tests + audit` | `ci.yml` | `app-lint-test` |
| `terraform — fmt + validate (infra/bootstrap)` | `ci.yml` | `terraform-fmt-validate` (matrix) |
| `terraform — fmt + validate (infra/app)` | `ci.yml` | `terraform-fmt-validate` (matrix) |
| `terraform — fmt + validate (examples/azure-container-apps/infra/app)` | `ci.yml` | `terraform-fmt-validate` (matrix) |
| `docker — lint + scan + health smoke` | `ci.yml` | `docker-build` |
| `repository — harness + workflows + shell + JSON` | `ci.yml` | `repository-validation` |
| `Analyze (javascript-typescript)` | `codeql.yml` | `analyze` |
| `apm install + audit` | `apm-audit.yml` | `audit` |
| `Review dependency changes` | `dependency-review.yml` | `dependency-review` |

If you rename any of these workflow jobs, **update both ruleset
JSONs and `docs/repo-settings-checklist.md`** in the same PR.

## Importing a ruleset

```bash
gh api -X POST /repos/<owner>/<repo>/rulesets \
  --input .github/rulesets/main-branch-evaluate.json
```

To list existing rulesets and pick an ID to update:

```bash
gh api /repos/<owner>/<repo>/rulesets
gh api -X PUT /repos/<owner>/<repo>/rulesets/<id> \
  --input .github/rulesets/main-branch-enforce.json
```

## What the baseline does NOT include

- **`required_signatures`** — would break the Copilot coding agent
  (its commits are not signed today). The signed-commit overlay
  lives in `examples/public-oss-hardening/.github/rulesets/`.
- **`commit_message_pattern`** — Conventional Commits is encouraged
  in `CONTRIBUTING.md` but not enforced as a rule.
- **`bypass_actors`** — empty by default. Add specific app or team
  IDs only when you have a documented exception (e.g. release-bot).

See `docs/repo-settings-checklist.md` for the full repo-settings
checklist (GHAS toggles, environments, secrets vs variables, etc.)
that pairs with these rulesets.
