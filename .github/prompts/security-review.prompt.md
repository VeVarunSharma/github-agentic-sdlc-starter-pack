<!-- HAND-AUTHORED — slash prompt for a guided security review of a PR diff. -->
---
mode: agent
description: "Guided security review of the current PR diff, cross-referenced with GHAS findings"
---

# /security-review

Perform a focused security review of the current pull request, combining
**static review of the diff** with **the live GHAS findings on this PR**.
Output is a structured report the human reviewer can paste as a PR
comment.

## Inputs

- `pr_number` — taken from the active context if available; otherwise
  ask the user.
- The current diff for the PR (use the `github` MCP server's
  `get_pull_request_files` tool, or `gh pr diff <pr_number>`).

## Steps

1. **Pull the PR metadata + diff.**
   - PR title, body, branch, head SHA, base SHA, list of changed files.
   - Highlight any file whose path matches the high-risk globs:
     `infra/**`, `.github/workflows/**`, `app/src/middleware/**`,
     `app/src/lib/auth*.js`, `Dockerfile`, `*.tfvars*`,
     anything under `infra/bootstrap/`.

2. **Pull GHAS findings on this PR.**
   - **CodeQL alerts** for the head SHA (use the `github` MCP
     `list_code_scanning_alerts` tool, filtered by `pr` parameter).
   - **Dependency Review** results for the PR (vulnerable / GPL /
     denylisted packages introduced).
   - **Secret Scanning** alerts for the head SHA.
   - **Push Protection** bypass events (rare — flag prominently if any).

3. **Walk the diff against this checklist.** Flag every hit.

   **Application code (`app/**`):**
   - User input flowing into `eval`, `new Function`, `child_process.exec`
     with shell metacharacters, dynamic `import()` paths, or file-system
     paths without normalisation.
   - Hard-coded secrets, API keys, connection strings, JWT signing
     keys, or tokens (even in tests — they should use `TEST_*` fixtures).
   - Crypto: weak algorithms (`md5`, `sha1`), insecure RNG (`Math.random`
     used for tokens / IDs), missing salts on password hashes,
     `crypto.createCipher` (deprecated, use `createCipheriv`).
   - HTTP handlers without input validation; absence of `helmet()`;
     `express.json()` without a `limit`.
   - SSRF: `fetch(userUrl)` without an allow-list of hosts.
   - Logging: any `logger.info`/`logger.error` that could leak
     secrets, tokens, PII, or full request bodies.
   - Authentication / authorisation gaps: routes that should be
     protected but are not; `req.user` referenced without an upstream
     auth middleware.

   **Infra (`infra/**`):**
   - New role assignments at subscription scope (must be RG scope or
     tighter; flag any subscription-scope grant).
   - `azurerm_storage_account` without `min_tls_version = "TLS1_2"`,
     without HTTPS-only, or with public network access enabled.
   - `azurerm_key_vault` with `purge_protection_enabled = false`,
     `soft_delete_retention_days < 7`, or public network access.
   - `azurerm_container_registry` with `admin_enabled = true` (must
     be `false` in this repo — Web App MI + AcrPull only).
   - New federated credentials whose subject claim doesn't follow
     `repo:<owner>/<repo>:environment:<env>` or
     `repo:<owner>/<repo>:pull_request`.

   **Workflows (`.github/workflows/**`):**
   - `pull_request_target` with `actions/checkout` of `${{ github.event.pull_request.head.sha }}` (classic supply-chain hole).
   - `permissions:` missing or set to `write-all` (must be least-privilege per job).
   - Use of `github.event.*` values in shell expressions without
     quoting (script injection).
   - New third-party Actions referenced by `@<branch>` or `@<tag>`
     instead of `@<full-sha>`.
   - Inline `env:` blocks containing secrets that don't need them
     (secrets should be scoped to the step that uses them).
   - Missing `concurrency:` blocks on long-running deploy workflows.

   **Container (`Dockerfile`, `app/Dockerfile`):**
   - Running as root (must `USER nonroot` or numeric UID).
   - `:latest` base image tags (must be pinned by digest or version).
   - `COPY . .` without a `.dockerignore` excluding `.git`,
     `node_modules`, `.env*`.

4. **Cross-reference.** For every CodeQL / Dependency-Review finding
   from step 2, check whether the diff in step 3 introduces or worsens
   it. Distinguish:
   - **Pre-existing** — present on `main`, not this PR's fault. Note,
     do not block.
   - **Newly introduced by this PR** — flag as a blocker.
   - **Made worse by this PR** — flag as a blocker.

5. **Output the report.** Use this exact structure so the reviewer can
   paste it as a PR comment:

   ```markdown
   ## Security review — PR #<n>

   **Head:** `<sha>` &nbsp;|&nbsp; **Files changed:** <count>
   &nbsp;|&nbsp; **High-risk paths:** <count>

   ### Blockers
   - [ ] `<file>:<line>` — <issue> (introduced by this PR)
   - [ ] ... or "_None._"

   ### GHAS findings on this PR
   - CodeQL: <n> open (<n> new, <n> pre-existing)
   - Dependency Review: <n> vulnerable deps introduced
   - Secret Scanning: <n> alerts on head SHA
   - Push Protection bypasses: <n>

   ### Recommendations (non-blocking)
   - <observation> at `<file>:<line>` — <suggestion>

   ### Reviewer sign-off
   - [ ] No blockers, or all blockers explicitly accepted with rationale.
   - [ ] Cross-referenced GHAS findings — no new high/critical alerts.
   - [ ] OWASP Top 10 considered (auth, injection, crypto, logging).
   ```

## What you must NOT do

- Do not approve or merge the PR.
- Do not edit code to "fix" findings during the review — file an
  issue or suggest a follow-up commit; the human reviewer decides
  what to do.
- Do not include excerpts of any **secret** value in the report — even
  ones that look like fixtures. Reference by file and line only.
