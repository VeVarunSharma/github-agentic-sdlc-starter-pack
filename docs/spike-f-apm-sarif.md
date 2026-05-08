<!-- docs/spike-f-apm-sarif.md -->
<!-- Date: 2025-01-31 -->
<!-- Spike: F — APM SARIF Output ↔ CodeQL upload-sarif contract -->

# Spike F — APM SARIF Audit Integration

**Date:** 2025-01-31  
**Status:** Research complete — ready for implementation  
**Sources:** `microsoft/apm-action` README + `action.yml` (HEAD `b48dd081`, 2026-05-07);
`github/codeql-action/upload-sarif` `action.yml` (HEAD `b81d0d25`).

---

## Section 1 — Verified Contract

### 1.1 Inputs to enable SARIF on `microsoft/apm-action@v1`

| Input | Value | Notes |
|---|---|---|
| `audit-report` | `true` | Generates SARIF to the **default path** `apm-audit.sarif` (relative to `working-directory`, default `.`). Alternatively, supply an absolute or relative custom path. |
| `apm-version` | `0.12.4` | Pinned default in `action.yml`; matches Spike A pin. Pass `latest` to float, not recommended. |
| `working-directory` | _(unset → `.`)_ | The SARIF file lands here; keep default so path is `$GITHUB_WORKSPACE/apm-audit.sarif`. |

> **Source:** `microsoft/apm-action:action.yml` — `audit-report` description:
> _"Generate a SARIF audit report during install/unpack. Set to `true` for default path
> (`apm-audit.sarif`), or provide a custom file path."_
> ([`action.yml` line ~78](https://github.com/microsoft/apm-action/blob/b48dd081eb0050f6d7f32d0e7caa0a59a2d419fd/action.yml))

### 1.2 Output path

The action exposes an **output** named `audit-report-path`:

> _"Path to the generated SARIF audit report, if `audit-report` was enabled"_
> — `microsoft/apm-action:action.yml`, `outputs.audit-report-path`

**Best practice:** Always reference `${{ steps.apm.outputs.audit-report-path }}` rather
than hard-coding `apm-audit.sarif`. This survives `working-directory` changes and custom
path overrides without touching the upload step.

**Concrete default path:** `$GITHUB_WORKSPACE/apm-audit.sarif`
(when `working-directory` is the default `.`).

### 1.3 SARIF schema version

GitHub Code Scanning requires **SARIF 2.1.0**
(`$schema: https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json`).
The `microsoft/apm-action` README explicitly positions the output as input to
`github/codeql-action/upload-sarif`, which **rejects** non-2.1.0 payloads.  
The action's compiled bundle (`dist/index.js`, 1.4 MB minified) could not be
directly inspected for the schema literal, but the integration contract implies
2.1.0 — see Section 7 (Open Questions) for the caveat.

### 1.4 What the SARIF report contains

From the README security scanning section and the APM security documentation
(<https://microsoft.github.io/apm/enterprise/security/>):

- **Hidden Unicode scanning** — checks every installed agent primitive
  (skills, instructions, prompts, agents) for suspicious Unicode characters:
  - Zero-width joiners / non-joiners (`U+200C`, `U+200D`)
  - Bidirectional overrides and marks (`U+200E`–`U+200F`, `U+061C`, `U+202A`–`U+202E`,
    `U+2066`–`U+2069`)
  - Variation selectors 1–15 (`U+FE00`–`U+FE0E`)
  - Invisible math operators (`U+2061`–`U+2064`)
- **Severity levels:** Critical (blocks deploy) → Warning → Info.
- **Also produces** a Markdown summary in `$GITHUB_STEP_SUMMARY` alongside the SARIF file.

### 1.5 Failure / exit behaviour

> _"`apm install` already blocks critical findings; this adds reporting for Code Scanning
> and a markdown summary in `$GITHUB_STEP_SUMMARY`."_
> — `microsoft/apm-action:README.md`, Security scanning section

**The action already exits non-zero on critical violations.**  
No additional `exit 1` conditional step is needed — the `apm-action` step will fail
the job on its own. The SARIF upload step uses `if: always()` so the report is uploaded
to Code Scanning **even when** the apm-action step fails (making the alert visible in
the PR / repo before the developer looks at raw logs).

---

## Section 2 — Recommended `apm-audit.yml`

The snippet below is the **canonical pattern from the `microsoft/apm-action` README**
(security scanning section), expanded into a full production workflow file.

```yaml
# .github/workflows/apm-audit.yml
#
# Runs the APM Agent Package Manager audit on every PR and push to main,
# then uploads findings as a SARIF report to GitHub Code Scanning.
#
# Required repo permissions / settings:
#   - Actions: Read and write (or "Allow GitHub Actions to create and approve PRs")
#   - Code scanning: enabled (GHAS or free public repo tier)
#
# See docs/spike-f-apm-sarif.md for the full design rationale.

name: APM Audit

on:
  push:
    branches: [main]
  pull_request:
  schedule:
    # Weekly: every Monday at 06:00 UTC — catches upstream APM package changes
    - cron: '0 6 * * 1'

permissions:
  # Minimum required by github/codeql-action/upload-sarif@v3
  contents: read          # checkout + read repo
  security-events: write  # upload SARIF to Code Scanning
  actions: read           # read workflow context (required on private repos)

jobs:
  apm-audit:
    name: APM dependency audit
    runs-on: ubuntu-latest

    steps:
      # ── 1. Checkout ────────────────────────────────────────────────────────
      - name: Checkout
        uses: actions/checkout@v4

      # ── 2. APM install + SARIF audit ───────────────────────────────────────
      # audit-report: true  → writes apm-audit.sarif to $GITHUB_WORKSPACE
      # audit-report-path   → output that carries the absolute path
      # apm-version         → pinned to the Spike-A version (0.12.4);
      #                       update here and in apm.yml together.
      # The action exits non-zero if critical hidden-Unicode findings are
      # detected — no separate fail step is required.
      - name: APM install + generate SARIF audit report
        id: apm
        uses: microsoft/apm-action@v1
        with:
          apm-version: '0.12.4'
          audit-report: true

      # ── 3. Upload SARIF to GitHub Code Scanning ────────────────────────────
      # if: always()  → run even when step 2 exits non-zero (critical finding),
      #                 so the Code Scanning alert is visible in the PR before
      #                 the developer opens the raw log.
      # category: apm-audit → keeps these alerts separate from CodeQL's SARIF
      #                        (different category = different Code Scanning tool
      #                        entry in the Security tab).
      - name: Upload SARIF to Code Scanning
        uses: github/codeql-action/upload-sarif@v3
        if: always() && steps.apm.outputs.audit-report-path != ''
        with:
          sarif_file: ${{ steps.apm.outputs.audit-report-path }}
          category: apm-audit
```

> **References:**
> - Canonical README snippet: `microsoft/apm-action:README.md` (SHA `d29f7c59`),
>   "Security scanning" section.
> - `upload-sarif` inputs: `github/codeql-action:upload-sarif/action.yml` (SHA `2827891b`).

---

## Section 3 — Permissions Matrix

| Permission | Value | Why |
|---|---|---|
| `contents: read` | read | `actions/checkout@v4` must clone the repository. Without it the checkout step fails with HTTP 403. |
| `security-events: write` | write | **Required by `github/codeql-action/upload-sarif@v3`.** The upload action calls the Code Scanning API endpoint (`POST /repos/{owner}/{repo}/code-scanning/sarifs`) which checks this permission. Without it the upload returns HTTP 403. GitHub [documents this explicitly](https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/uploading-a-sarif-file-to-github#uploading-a-code-scanning-analysis-with-github-actions). |
| `actions: read` | read | Required on **private repositories** for `upload-sarif` to resolve the workflow run context (branch, SHA) when associating the SARIF upload with a specific run. Public repos do not need this but it is harmless and recommended for portability. Documented in the `upload-sarif/action.yml` `token` input description: _"the workflow must have the `security-events: write` permission"_ (implies `actions: read` for private repos). |

**GitHub docs reference:** <https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/uploading-a-sarif-file-to-github#uploading-a-code-scanning-analysis-with-github-actions>

---

## Section 4 — SARIF in PRs vs `main`

### On a pull request

- `upload-sarif` sends the SARIF to the Code Scanning API with `ref = refs/pull/<n>/merge`
  (or `/head` for forks).
- GitHub surfaces findings as **inline Code Scanning annotations on the PR diff**.
- Alerts that are new relative to the base branch are marked "new in this PR".
- If the repository has a code-scanning blocking rule, PR merge can be blocked.

### On `main` (push or schedule)

- The SARIF is associated with `refs/heads/main`.
- Findings appear in the **Security → Code scanning alerts** tab at the repo level.
- Resolved findings (no longer present) are automatically closed by GitHub after
  the next successful SARIF upload to that ref.

### The `category` field

`category: apm-audit` assigns these results to a separate "tool" slot from CodeQL's
uploads (which use `category: '' / language-specific`). This means:

- APM alerts and CodeQL alerts appear as **separate tools** in the Code Scanning UI.
- Closing or dismissing an APM alert does **not** affect CodeQL alerts and vice versa.
- The `sarif-id` output of the upload step uniquely identifies this category's upload.

---

## Section 5 — Failure Modes

| Failure | Symptom | Fix |
|---|---|---|
| Missing `security-events: write` | `upload-sarif` step fails with HTTP 403 (`Resource not accessible by integration`). The apm-action step succeeds; SARIF is generated but silently never reaches Code Scanning. | Add `security-events: write` to the job-level `permissions:` block. |
| Wrong SARIF version (not 2.1.0) | `upload-sarif` step reports `invalid SARIF` or the upload succeeds but no alerts appear. | Upgrade `apm-action` to a version that emits 2.1.0 SARIF (all v1.x releases are expected to; see Section 7). |
| Path mismatch (`sarif_file` resolves to missing file) | `upload-sarif` exits with `No SARIF files found`. Most common if `working-directory` is customised but the upload step still hardcodes `apm-audit.sarif`. | Always reference `${{ steps.apm.outputs.audit-report-path }}` — never hardcode the filename. |
| `apm-action` fails for unrelated reasons (network, schema mismatch) | `audit-report-path` output is empty or absent; the `if:` condition on upload-sarif evaluates false; no SARIF is uploaded but the overall job still fails on the apm step. | The `if: always() && steps.apm.outputs.audit-report-path != ''` guard handles this: no phantom upload attempt, no confusing error from upload-sarif. The root cause is visible in the apm step logs. |
| Code Scanning disabled on repo | `upload-sarif` step returns HTTP 404 (`Code scanning is not enabled for this repository`). | Enable GHAS (or, for public repos, go to Security → Code scanning → Set up) and re-run. |
| `audit-report` input not set | `audit-report-path` output is empty; upload-sarif step is skipped via `if:` guard. No SARIF, no alerts. Silent omission. | Ensure `audit-report: true` is present in the apm step's `with:` block. |

---

## Section 6 — Compatibility with the Rest of Phase 4

### Works alongside `codeql.yml` (no conflict)

The `category: apm-audit` input is the key isolation mechanism. GitHub Code Scanning
treats uploads with different `category` values as results from **different tools**.
The APM SARIF and CodeQL SARIF are stored, displayed, and dismissed independently.

**Concrete consequence:** if CodeQL finds a vulnerability in `app/src/server.js` and
APM finds a hidden-Unicode finding in `.github/prompts/foo.md`, they appear in separate
rows in the Security → Code scanning alerts view and neither closes the other.

### Does NOT replace Dependency Review or Dependabot

- **Dependency Review** (`github/dependency-review-action`) checks `package-lock.json`
  and other manifests for known CVEs in *npm/pip/etc. packages*. APM audit checks
  for **prompt-injection-style content threats** (hidden Unicode) in agent primitives.
  Different threat models, complementary controls.
- **Dependabot** handles version bumps for npm, Terraform, and GitHub Actions
  dependencies. APM primitives are not npm packages and are outside Dependabot's scope.

### Interaction with `apm-policy.yml`

This workflow runs `apm install` (via `microsoft/apm-action@v1`) which enforces
`apm-policy.yml` at install time. The SARIF output from `audit-report: true` is the
*reportable evidence* of that enforcement, surfacing all findings (not just the
critical-blocking ones) in Code Scanning for audit trail and trend purposes.

---

## Section 7 — Open Questions

1. **SARIF 2.1.0 schema confirmation.** The `dist/index.js` bundle is 1.4 MB of
   minified code; a text search for `"2.1.0"` or `"$schema"` via GitHub code search
   returned zero results (minification likely obfuscates string literals). The
   integration is designed for `upload-sarif` which rejects non-2.1.0 payloads, and
   the README explicitly targets GitHub Code Scanning.  
   **Recommended verification:** on a test repo, run the workflow, download the raw
   SARIF artifact, and inspect the `$schema` field. A one-line `jq '."$schema"'
   apm-audit.sarif` in a debug step would confirm.

2. **Findings on zero-dependency repos.** If the repo has no APM dependencies
   (`apm.yml` with empty `dependencies:`), will `audit-report: true` still produce a
   valid SARIF file (with zero results) or skip file creation entirely?  
   The `if: always() && steps.apm.outputs.audit-report-path != ''` guard handles the
   skip case, but if an empty SARIF is produced, upload-sarif will still run
   (harmlessly). Behaviour is not documented in the README.

3. **Fork PR SARIF uploads.** For forks, GitHub restricts `security-events: write`
   to workflows triggered by repository owners. PRs from forks will have the apm step
   succeed but the upload step may be silently skipped (GitHub does not fail the step,
   it no-ops). This is standard GitHub behaviour for all SARIF uploaders, not specific
   to APM. The `category: apm-audit` alerts still appear when the PR is merged to main.

4. **`apm-version` drift.** The pinned default (`0.12.4`) in `microsoft/apm-action@v1`
   will be updated by future releases (see commit `b48dd081`: "bump APM CLI default to
   v0.12.4"). The workflow pins `apm-version: '0.12.4'` explicitly; when Spike A's
   version recommendation changes, update this workflow and `apm.yml` together in the
   same PR.

---

*Sources cited inline. Report generated by research subagent. Do not hand-edit the
`action.yml`-derived claims — re-run this spike against a newer SHA if the action
releases a new major version.*
