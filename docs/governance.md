# Governance

How `apm-policy.yml` is enforced, what the audit gate checks, and what
"break-glass" looks like.

## Policy file

[`apm-policy.yml`](../apm-policy.yml) is the single source of truth for
APM-related governance. The audit gate
([`.github/workflows/apm-audit.yml`](../.github/workflows/apm-audit.yml))
loads it on every PR.

Key sections:

```yaml
enforcement: block          # audit failure blocks the PR
fetch_failure: block        # treat registry download failures as policy violations

dependencies:
  allow:
    - "github/**"
    - "microsoft/**"
  # deny: implicit — anything not in allow is denied

mcp:
  transport:
    allow: [http, stdio]    # no websocket
  trust_transitive: false   # don't auto-trust deps' deps

unmanaged_files:
  action: warn              # tolerate hand-authored .github/ files
```

> **Note:** `apm_cli_version` is **not** a valid policy schema field in
> APM v0.28.0. The CLI version is pinned by `scripts/install-apm.sh` and
> the workflow that calls it — not by the policy YAML.

## What the audit gate does

On every PR, [`apm-audit.yml`](../.github/workflows/apm-audit.yml) runs:

1. `apm install --target copilot` — restores the dependency cache in a clean
   runner. The workflow fails if this changes any committed files.
2. `apm install --frozen --target copilot` — replays the cached resolution.
   The `--frozen` flag exits non-zero if the lockfile is out of sync with the
   manifest. APM-managed files must match the locked resolution.
3. `apm audit --ci --policy ./apm-policy.yml --format sarif --output apm-audit.sarif`
   — applies the policy and emits a SARIF file at the specified path.
4. `github/codeql-action/upload-sarif` pinned to v4.37.6's immutable commit
   (`5595ccaf912efad79be6eef63a5619ff05969be3`) — uploads the SARIF so
   findings appear in the **Security** tab.

It does **not** run `apm compile -t copilot` because that would clobber
the hand-authored `.github/copilot-instructions.md`. See
[`apm-ownership-model.md`](./apm-ownership-model.md) for why.

## What's NOT enforced

- **Awesome-copilot freshness.** The audit gate only verifies you're in
  sync with the **locked** resolution. Upstream may have moved on. The
  `.github/workflows/apm-update.yml` workflow opens a weekly PR with
  refreshed deps; merging it is a human decision.
- **Hand-authored content quality.** `<!-- HAND-AUTHORED -->` files are
  warnings, not errors. The reviewer is responsible for content review.
- **Copilot agent output.** The agent's PR goes through the same gates
  any human PR does — there's no separate "agent quality" check beyond
  the standard CI/CodeQL/dep-review pipeline plus required human review.

## Branch protection layer

Branch protection rulesets in
[`.github/rulesets/`](../.github/rulesets/) sit on top of the
APM policy:

- **Evaluate mode** (`main-branch-evaluate.json`) — visible warnings
  only. Default for new repos so the gates can be shaken out without
  blocking work.
- **Enforce mode** (`main-branch-enforce.json`) — required PR + required
  status checks + linear history + conversation resolution. Required
  checks include `apm install + audit` so an APM violation blocks
  merge.

Graduation: import enforce-mode **only after** every required check has
appeared on at least one PR. See
[`repo-settings-checklist.md`](./repo-settings-checklist.md).

## Break-glass

When the audit gate fires falsely (e.g. an upstream awesome-copilot
file got temporarily 404'd), three options:

1. **Fix forward** — re-pin the dep to a known-good SHA in `apm.yml`
   and re-run the audit. Preferred.
2. **Bypass via admin merge** — repo admin can override required
   checks. GitHub records the bypass in the audit log and the merge
   commit shows an "admin merge" annotation. Document why in the PR.
3. **Disable the workflow** — last resort. Comment out the trigger in
   `apm-audit.yml`, merge, then immediately follow up with a PR that
   restores the trigger and adopts a real fix.

For option 2, prefer **temporarily downgrading** `enforcement: block`
to `enforcement: warn` in `apm-policy.yml` and committing that change
through the normal flow, rather than admin-bypassing one PR. The
downgrade is itself reviewable.

## Org-level enforcement

For platform teams rolling this out org-wide:

- **Org-level rulesets** (Settings → Code security → Repository rules)
  layer on top of repo rulesets. Use them to enforce `apm-audit` as a
  required check across all repos that adopt the template.
- **Required workflows** (Enterprise/Org) can pin the audit workflow's
  source, so consumers can't disable it locally without org-admin
  approval.
- **OpenSSF Scorecard** + **Allstar** are good complements for tracking
  baseline hygiene across many repos. See
  [`enterprise-hardening.md`](./enterprise-hardening.md) and the
  `examples/public-oss-hardening/` overlay.
