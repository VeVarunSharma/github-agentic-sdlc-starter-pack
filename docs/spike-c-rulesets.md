# Spike C — GitHub Branch Rulesets via `gh api`

> **Historical evidence (last cataloged 2026-08-09).** Active settings guidance
> lives in [`repo-settings-checklist.md`](./repo-settings-checklist.md).

**Date:** 2025-07-08  
**Status:** Research complete — ready for Phase 4 implementation  
**Author:** Spike C research agent  
**Sources:** GitHub REST API docs (accessed 2025-07-08), `github/ruleset-recipes` repo (SHA `82adf895`), `gh` CLI manual

---

## Table of Contents

1. [Endpoint + Auth + Import Command](#1-endpoint--auth--import-command)
2. [Ruleset JSON Schema (Annotated)](#2-ruleset-json-schema-annotated)
3. [`main-branch-evaluate.json` (Full File Content)](#3-main-branch-evaluatejson-full-file-content)
4. [`main-branch-enforce.json` (Full File Content)](#4-main-branch-enforcejson-full-file-content)
5. [Required Check Name Binding (Catalog)](#5-required-check-name-binding-catalog)
6. [Failure Modes](#6-failure-modes)
7. [Recommended Graduation Path](#7-recommended-graduation-path)
8. [Open Questions](#8-open-questions)

---

## 1. Endpoint + Auth + Import Command

### Endpoint

```
POST /repos/{owner}/{repo}/rulesets
```

- **Full URL:** `https://api.github.com/repos/OWNER/REPO/rulesets`
- **HTTP Method:** `POST`
- **Content-Type:** `application/vnd.github+json`
- **API Version header:** `X-GitHub-Api-Version: 2022-11-28` (recommended)

Source: [GitHub REST API — Create a repository ruleset](https://docs.github.com/en/rest/repos/rules#create-a-repository-ruleset)

### Required Token Scopes / Permissions

| Auth type | Required permission |
|-----------|-------------------|
| Fine-grained PAT | **Administration** — repository write |
| Classic PAT | `repo` scope (full) |
| GitHub App installation token | `administration: write` |
| GitHub App user token | `administration: write` |

> **Classic PATs:** the `repo` scope grants administration write implicitly. A `public_repo` scope is **not** sufficient.

### Exact `gh api` Import Command

```bash
# Import evaluate-mode ruleset
gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/OWNER/REPO/rulesets \
  --input .github/rulesets/main-branch-evaluate.json

# Import enforce-mode ruleset
gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/OWNER/REPO/rulesets \
  --input .github/rulesets/main-branch-enforce.json
```

> The `--input` flag reads the file as the raw HTTP request body (JSON). Any additional `-f`/`-F` field flags are appended as query-string parameters, not body params — so **do not combine `--input` with `-f` flags**.

Source: [gh api manual](https://cli.github.com/manual/gh_api) — confirmed `--input` example: `gh api repos/{owner}/{repo}/rulesets --input file.json`

### Update (Replace) an Existing Ruleset

If you need to replace (not delete-and-recreate) a ruleset, use `PUT` with the ruleset ID:

```bash
# First, get the ruleset ID
gh api /repos/OWNER/REPO/rulesets | jq '.[].id'

# Then PUT the updated JSON
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  /repos/OWNER/REPO/rulesets/RULESET_ID \
  --input .github/rulesets/main-branch-enforce.json
```

### `gh ruleset` Subcommand — READ-ONLY Only

The `gh ruleset` command exists (`gh ruleset check`, `gh ruleset list`, `gh ruleset view`) but is **read-only**. There is **no `gh ruleset create`, `gh ruleset import`, or `gh ruleset apply`** command in the stable CLI as of 2025-07-08.

Source: [gh ruleset manual](https://cli.github.com/manual/gh_ruleset)

```
Available commands:
  gh ruleset check       — Show rules that apply to a branch
  gh ruleset list        — List rulesets for a repo/org
  gh ruleset view        — View details of a specific ruleset
```

**Conclusion:** All create/update/delete operations **must** use `gh api` (REST) or the GitHub web UI. The starter pack correctly documents `gh api --method POST … --input file.json` as the import mechanism.

### Org-Level Rulesets (Alternative)

For org-level rulesets (GitHub Team or GHEC only):

```bash
gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  /orgs/ORG/rulesets \
  --input org-branch-ruleset.json
```

> **Caveat:** Org-level rulesets target repositories by name pattern, custom property, or topic filter — not individual repos. The starter pack ships **repo-level** rulesets by default. Org-level is documented here for completeness; adopters running a GitHub Team/GHEC org may prefer it for fleet-wide enforcement.

---

## 2. Ruleset JSON Schema (Annotated)

Source: [GitHub REST API docs — Create a repository ruleset parameters](https://docs.github.com/en/rest/repos/rules#create-a-repository-ruleset--parameters)

### Top-Level Fields

```jsonc
{
  // Required. Human-readable display name. Shown in Settings → Rules → Rulesets.
  "name": "string",

  // Optional. Default: "branch". One of: "branch", "tag", "push"
  "target": "branch",

  // Required. One of: "disabled", "active", "evaluate"
  // "evaluate" → warn-mode/insights only; does NOT block merges.
  //   ⚠️  "evaluate" requires GitHub Enterprise Cloud or GHES.
  //   On GitHub Free/Pro/Team: accepted by API but insights UI is not available.
  // "active"   → fully enforced; blocks merges that violate rules.
  // "disabled" → ruleset exists but is inert.
  "enforcement": "evaluate",

  // Optional. Array of actors who may bypass ALL rules in this ruleset.
  // Omit or use [] for zero-bypass (recommended for strict repos).
  "bypass_actors": [],

  // Optional. Narrows which branches/tags the ruleset applies to.
  "conditions": {
    "ref_name": {
      // ~DEFAULT_BRANCH = the repo's current default branch (dynamically resolved).
      // ~ALL = every branch. Plain strings use fnmatch glob syntax.
      "include": ["~DEFAULT_BRANCH"],
      "exclude": []
    }
  },

  // Required. Array of rule objects (see below).
  "rules": []
}
```

### Rule Types

Each entry in `rules` must have a `"type"` field and, for most rule types, a `"parameters"` object.

#### Simple rules (no parameters)

```jsonc
{ "type": "deletion" }          // Blocks branch deletion by non-bypass users
{ "type": "non_fast_forward" }  // Blocks force-push
{ "type": "creation" }          // Blocks branch creation by non-bypass users
{ "type": "required_signatures" } // Requires GPG/SSH signed commits
{ "type": "required_linear_history" } // Blocks merge commits; only squash/rebase
```

#### `pull_request` rule

```jsonc
{
  "type": "pull_request",
  "parameters": {
    // Number of approving reviews required before merge. Integer 0–10.
    "required_approving_review_count": 1,

    // Dismiss existing approvals when new commits are pushed to the PR branch.
    "dismiss_stale_reviews_on_push": true,

    // Require approval from a CODEOWNER for files they own.
    "require_code_owner_review": true,

    // The most recent push to the PR must be approved by someone other
    // than the pusher. Prevents self-approval of last-minute changes.
    "require_last_push_approval": false,

    // All review comment threads must be resolved before merge.
    "required_review_thread_resolution": true

    // NOTE: "automatic_copilot_code_review_enabled" does NOT exist in the
    // rulesets API schema. Copilot code review is configured separately
    // via repository settings → Code review → Copilot. Do not include
    // this field; the API will reject it with a 422 error.
  }
}
```

#### `required_status_checks` rule

```jsonc
{
  "type": "required_status_checks",
  "parameters": {
    // If true, PR branch must be up-to-date with the base branch before merging.
    "strict_required_status_checks_policy": true,

    // Array of checks that must pass. Each entry:
    //   context      (string, required) — exact check run name (see Section 5)
    //   integration_id (integer, optional) — GitHub App ID that must report the check.
    //     GitHub Actions app ID = 15368. Omitting allows any app to satisfy the check.
    "required_status_checks": [
      {
        "context": "CI / ci",
        "integration_id": 15368
      }
    ]
  }
}
```

#### `update` rule (optional, with parameter)

```jsonc
{
  "type": "update",
  "parameters": {
    // If true, branch can still pull changes from upstream (fetch+merge allowed).
    "update_allows_fetch_and_merge": true
  }
}
```

### `bypass_actors` Schema

```jsonc
{
  // Actor ID. Required for Integration, RepositoryRole, Team.
  // Ignored for OrganizationAdmin. Null for DeployKey.
  "actor_id": 1,

  // One of: "Integration", "OrganizationAdmin", "RepositoryRole", "Team", "DeployKey"
  "actor_type": "OrganizationAdmin",

  // When bypass applies:
  //   "always"       — bypass rules entirely (no audit entry created)
  //   "pull_request" — can bypass via PR only (branch rulesets only)
  //   "exempt"       — rules not run; bypass audit entry IS created
  // Default: "always"
  "bypass_mode": "always"
}
```

---

## 3. `main-branch-evaluate.json` (Full File Content)

> **Copy this JSON byte-for-byte into `.github/rulesets/main-branch-evaluate.json`**

```json
{
  "name": "Main branch protection (evaluate mode)",
  "target": "branch",
  "enforcement": "evaluate",
  "bypass_actors": [],
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH"],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "deletion"
    },
    {
      "type": "non_fast_forward"
    },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": true,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          {
            "context": "CI / ci",
            "integration_id": 15368
          },
          {
            "context": "CodeQL / Analyze (javascript)",
            "integration_id": 15368
          },
          {
            "context": "Dependency review / dependency-review",
            "integration_id": 15368
          },
          {
            "context": "APM Audit / apm-audit",
            "integration_id": 15368
          }
        ]
      }
    },
    {
      "type": "required_linear_history"
    }
  ]
}
```

> **Notes on context strings (see also Section 5):**
> - The workflow files in `.github/workflows/` do not yet exist. Context strings above are *planned* values based on expected workflow `name:` fields and job `name:` fields.
> - If the actual workflow `name:` differs, update the context strings **before** posting this ruleset, or merges will be permanently blocked (see Section 6).
> - `required_linear_history` is included. Teams preferring merge commits should remove this rule.
> - `automatic_copilot_code_review_enabled` is intentionally absent — this field does not exist in the rulesets API schema.
> - `evaluate` enforcement requires GitHub Enterprise Cloud or GHES. On Free/Pro/Team plans, use `"disabled"` for testing and graduate directly to `"active"`.

---

## 4. `main-branch-enforce.json` (Full File Content)

> **Copy this JSON byte-for-byte into `.github/rulesets/main-branch-enforce.json`**

```json
{
  "name": "Main branch protection (enforce mode)",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH"],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "deletion"
    },
    {
      "type": "non_fast_forward"
    },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": true,
        "require_last_push_approval": true,
        "required_review_thread_resolution": true
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          {
            "context": "CI / ci",
            "integration_id": 15368
          },
          {
            "context": "CodeQL / Analyze (javascript)",
            "integration_id": 15368
          },
          {
            "context": "Dependency review / dependency-review",
            "integration_id": 15368
          },
          {
            "context": "APM Audit / apm-audit",
            "integration_id": 15368
          }
        ]
      }
    },
    {
      "type": "required_linear_history"
    }
  ]
}
```

> **Differences from evaluate variant:**
> - `enforcement`: `"evaluate"` → `"active"` — **this is the only change needed for graduation**
> - `require_last_push_approval`: `false` → `true` — tightened for active enforcement
> - `required_approving_review_count`: kept at `1` (conservative default; bump to `2` for higher-risk repos)
>
> **Scorecard note:** The `/examples/public-oss-hardening/` optional add-on workflow
> (`scorecard.yml`) would add a `"Scorecard analysis / scorecard"` check. This is intentionally
> excluded from the default enforce ruleset. Adopters using the public OSS hardening example
> should add the following entry to `required_status_checks` manually:
> ```json
> {
>   "context": "Scorecard analysis / scorecard",
>   "integration_id": 15368
> }
> ```

---

## 5. Required Check Name Binding (Catalog)

### How GitHub Actions Check Names Are Derived

When a GitHub Actions workflow runs, each job creates a **check run** whose display name follows this pattern:

```
{workflow `name:` field} / {job `name:` field  (or job_id if no name:)}
```

For matrix strategies, the check name becomes:
```
{workflow name} / {job name} ({matrix-key-value})
```

**This full `"Workflow / Job"` string is the `context` value required in `required_status_checks`.**

Example: A workflow file with `name: CI` containing a job with `name: ci` → context = `"CI / ci"`.

> **Verification step (run after workflow files are created):**
> ```bash
> # List checks on the most recent commit of a PR
> gh api /repos/OWNER/REPO/commits/COMMIT_SHA/check-runs \
>   --jq '.check_runs[] | {name, app: .app.slug}'
> ```
> The `name` field in the output is the exact context string to use.

### Planned Check Name Catalog

The workflow files in `.github/workflows/` have not yet been created. The table below documents the **planned** check names, derived from expected workflow file names and job naming conventions. **These must be verified after workflow files are authored in Phase 2/3.**

| Workflow file | Workflow `name:` | Job `id` | Job `name:` | Expected check context | Notes |
|---|---|---|---|---|---|
| `ci.yml` | `CI` | `ci` | `ci` | `CI / ci` | CI job name TBD — this is a placeholder; verify against actual file |
| `codeql.yml` | `CodeQL` | `analyze` | `Analyze` | `CodeQL / Analyze (javascript)` | CodeQL default matrix uses `${{ matrix.language }}`; one check per language |
| `dependency-review.yml` | `Dependency review` | `dependency-review` | *(none — uses job_id)* | `Dependency review / dependency-review` | Uses `actions/dependency-review-action` standard pattern |
| `apm-audit.yml` | `APM Audit` | `apm-audit` | *(none — uses job_id)* | `APM Audit / apm-audit` | Custom workflow; name TBD |

#### CodeQL Matrix Note

The CodeQL workflow typically scans multiple languages. If the repository contains only JavaScript/TypeScript:

```yaml
# In .github/workflows/codeql.yml
strategy:
  matrix:
    language: [ javascript ]
```

→ Check name: `CodeQL / Analyze (javascript)`

If multiple languages are scanned, add one entry per language to `required_status_checks`.

#### `integration_id` 15368

The integer `15368` is the GitHub-internal App ID for the **GitHub Actions** app. Specifying it ensures the check must come from GitHub Actions, not from any other status source (e.g., a third-party CI system with an identical context string). To verify:

```bash
gh api /repos/OWNER/REPO/check-runs/RUN_ID --jq '.app'
# Look for "slug": "github-actions", note the "id" value
```

If you omit `integration_id`, any app (or manual status post) can satisfy the check.

---

## 6. Failure Modes

### 6.1 Required Check That Doesn't Exist

**Symptom:** PRs are permanently blocked with a red ❌ "Waiting for status" that never resolves.

**Cause:** The `context` string in `required_status_checks` doesn't match any check run being reported on the commit. This happens when:
- The workflow file hasn't been created yet
- The workflow `name:` or job `name:` was changed after the ruleset was created
- The workflow only runs on certain branches (e.g., `push` trigger on `main`), not on PRs

**Fix:** Either update the ruleset's context string to match, or temporarily set `enforcement: "disabled"` while fixing the workflow. In `evaluate` mode this is only a warning; in `active` mode it blocks all merges.

### 6.2 Wrong `integration_id`

**Symptom:** Check passes from the expected workflow, but ruleset still shows as failing.

**Cause:** The `integration_id` was set to a value that doesn't match the app actually reporting the check. For example, using `15368` (GitHub Actions) when the check is reported by a different app (e.g., a third-party CI provider).

**Fix:** Remove `integration_id` from the rule entry to accept checks from any app, or verify the actual app ID using the check-runs API.

### 6.3 `enforcement: "evaluate"` Doesn't Block

**By design**, `evaluate` mode **does not block merges**. It only surfaces policy violations in the repository's [Insights → Rulesets page](https://github.com/OWNER/REPO/insights/rulesets).

- Developers will **not** see a blocking PR check in `evaluate` mode
- Admins must proactively review the Rulesets Insights page for violations
- **Graduation path:** after monitoring the evaluate period, delete the evaluate ruleset (or PUT with `"enforcement": "active"`) to enforce

**⚠️ Enterprise-only:** `evaluate` enforcement is only available on **GitHub Enterprise Cloud (GHEC)** and **GHES**. The API accepts the `evaluate` value on Free/Pro/Team plans but the Insights UI will not appear. Teams on Free/Pro/Team should use `"disabled"` for testing and graduate directly to `"active"`.

Source: GitHub REST API docs — `enforcement` field description: *"`evaluate` is only available with GitHub Enterprise"*

### 6.4 Rulesets vs. Classic Branch Protection Conflict

**Rulesets and classic branch protection coexist** — they do not replace each other automatically. Both apply simultaneously, and the most restrictive rule wins (rule layering).

**Problem:** A classic branch protection rule requiring 1 reviewer + a ruleset requiring 0 reviewers → 1 reviewer is still required (most restrictive). Running both creates unpredictable behaviour and confusing UI.

**Recommendation:** Do **not** have both classic branch protection and rulesets for the same branch. Before importing these rulesets:
1. Audit existing branch protection: `Settings → Branches → Branch protection rules`
2. Delete or disable any classic rules covering `main` before activating rulesets
3. Classic rules can be exported via: `gh api /repos/OWNER/REPO/branches/main/protection`

### 6.5 Token Permission Issues

**Symptom:** `gh api` returns HTTP 403 or 404.

**Common causes and fixes:**

| Error | Cause | Fix |
|---|---|---|
| `403 Must have admin rights` | Token lacks `administration: write` | Create a fine-grained PAT with Administration (read/write) on the repo |
| `404 Not Found` | Repo path typo, or token can't see the repo | Verify `OWNER/REPO`, ensure token has `contents: read` or `metadata: read` |
| `422 Unprocessable Entity` | Invalid JSON field (e.g., `automatic_copilot_code_review_enabled`) | Validate JSON against schema; remove unsupported fields |
| `403 Resource protected by organization SAML` | Org requires SAML SSO and PAT isn't authorized | Authorize the PAT for the org SSO at `github.com/settings/tokens` |

---

## 7. Recommended Graduation Path

### Day 0 — Import Evaluate Ruleset

```bash
gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/OWNER/REPO/rulesets \
  --input .github/rulesets/main-branch-evaluate.json
```

> **On Free/Pro/Team:** Skip to `main-branch-enforce.json` directly, or import evaluate as `"disabled"` just for documentation purposes.

### Days 1–7 — Monitor Evaluate Insights

1. Navigate to **Insights → Rulesets** in your repository
2. Review which PRs are triggering rule violations (without being blocked)
3. Common issues to watch for:
   - PRs failing `required_status_checks` due to mismatched context names
   - Bot PRs (Dependabot, Renovate) unexpectedly blocked by `require_code_owner_review`
   - Matrix job names including unexpected values
4. Adjust context strings in the JSON files as needed
5. Re-import with `PUT` if adjustments are required:
   ```bash
   RULESET_ID=$(gh api /repos/OWNER/REPO/rulesets --jq '.[] | select(.name=="Main branch protection (evaluate mode)") | .id')
   gh api --method PUT /repos/OWNER/REPO/rulesets/$RULESET_ID \
     --input .github/rulesets/main-branch-evaluate.json
   ```

### Day 7+ — Graduate to Enforce

**Option A — Delete evaluate, POST enforce (cleanest):**

```bash
# Get the evaluate ruleset ID
EVAL_ID=$(gh api /repos/OWNER/REPO/rulesets \
  --jq '.[] | select(.name=="Main branch protection (evaluate mode)") | .id')

# Delete evaluate ruleset
gh api --method DELETE /repos/OWNER/REPO/rulesets/$EVAL_ID

# Import enforce ruleset
gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  /repos/OWNER/REPO/rulesets \
  --input .github/rulesets/main-branch-enforce.json
```

**Option B — PUT to update enforcement in-place:**

```bash
EVAL_ID=$(gh api /repos/OWNER/REPO/rulesets \
  --jq '.[] | select(.name=="Main branch protection (evaluate mode)") | .id')

gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  /repos/OWNER/REPO/rulesets/$EVAL_ID \
  --input .github/rulesets/main-branch-enforce.json
```

> Option B changes the ruleset name too (to "Main branch protection (enforce mode)"), which is fine and provides audit clarity.

### Ongoing — Add Bypass Actors (If Needed)

If Dependabot, Renovate, or a release bot needs to bypass PR requirements:

```bash
# Get your GitHub Actions app or bot's integration ID, then add:
gh api --method PUT /repos/OWNER/REPO/rulesets/$RULESET_ID \
  -f 'bypass_actors[][actor_id]=ACTOR_ID' \
  -f 'bypass_actors[][actor_type]=Integration' \
  -f 'bypass_actors[][bypass_mode]=pull_request'
```

---

## 8. Open Questions

| # | Question | Impact | Suggested resolution |
|---|---|---|---|
| OQ-1 | **`ci.yml` workflow name and job name are unknown** — the file hasn't been created yet. The context `"CI / ci"` is a placeholder. | High — wrong context permanently blocks merges in enforce mode | Author `ci.yml` first, run a PR, inspect check run names via `gh api /repos/OWNER/REPO/commits/SHA/check-runs`, then update ruleset JSON |
| OQ-2 | **`evaluate` enforcement on Free/Pro/Team** — the API accepts `"evaluate"` but the Rulesets Insights page is GHEC/GHES only. Should the starter pack's default enforce `"disabled"` for non-GHEC repos? | Medium — confusion for Free/Pro/Team adopters | Add a conditional note in README: use `"disabled"` instead of `"evaluate"` on Free/Pro/Team; graduate directly to `"active"` |
| OQ-3 | **CodeQL language matrix** — the starter pack template uses `javascript` only. If a consumer adds Python/Go/etc., additional check contexts need to be added to the ruleset. | Medium — additional languages added without updating ruleset will block their CodeQL checks | Document as a "post-template customization" step; perhaps drive required checks from a list in a config file |
| OQ-4 | **`require_last_push_approval: true` in enforce mode vs. single-person repos** — solo developers can never merge their own PRs if this is enabled with 1 reviewer required. | Low-Medium — affects solo/low-team-size adopters | Set to `false` in enforce mode too, or document that `required_approving_review_count: 0` disables the review requirement entirely |
| OQ-5 | **`required_linear_history` vs. merge commits** — some teams use merge commits intentionally. This rule blocks them. | Low — stylistic preference | Leave in default JSON with a comment; document removal as a customization step |
| OQ-6 | **`apm-audit.yml` workflow** — this workflow is referenced in the plan but not yet implemented. Its check name is unknown. | High — same as OQ-1 | Same resolution as OQ-1: verify check name after implementation |
| OQ-7 | **Org-level ruleset adoption path** — the starter pack ships repo-level rulesets, but org-level may be preferred for fleet management. The JSON schema differs (adds `conditions.repository_name`). | Low — optional enhancement | Document org-level variant in a follow-on spike or Phase 5 |

---

## Appendix A — Sources

| Source | URL | Accessed |
|---|---|---|
| GitHub REST API — Create a repository ruleset | https://docs.github.com/en/rest/repos/rules#create-a-repository-ruleset | 2025-07-08 |
| GitHub Docs — About rulesets | https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets | 2025-07-08 |
| GitHub Docs — Creating rulesets for a repository | https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository | 2025-07-08 |
| GitHub Docs — Available rules for rulesets | https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets | 2025-07-08 |
| `github/ruleset-recipes` repo | https://github.com/github/ruleset-recipes (SHA: 82adf895) | 2025-07-08 |
| `gh` CLI manual — `gh api` | https://cli.github.com/manual/gh_api | 2025-07-08 |
| `gh` CLI manual — `gh ruleset` | https://cli.github.com/manual/gh_ruleset | 2025-07-08 |
| GitHub Docs — Org-level rulesets | https://docs.github.com/en/organizations/managing-organization-settings/creating-rulesets-for-repositories-in-your-organization | 2025-07-08 |
