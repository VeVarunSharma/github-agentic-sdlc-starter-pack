# Spike E — `copilot-setup-steps.yml`: Discovery, Constraints, and Working Example

**Spike:** E  
**Status:** Complete  
**Date:** 2025-07-14  
**Sources:** GitHub Copilot cloud agent official documentation (fetched live)  
**Primary doc:** https://docs.github.com/en/copilot/customizing-copilot/customizing-the-development-environment-for-copilot-coding-agent  
**Also:** https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/customize-the-agent-environment  

---

## Section 1 — Verified File Path and Discovery

### Confirmed location

```
.github/workflows/copilot-setup-steps.yml
```

Source: *"You can customize Copilot's environment by creating a special GitHub Actions workflow file,
located at `.github/workflows/copilot-setup-steps.yml` within your repository."*
— [GitHub docs, customizing the development environment](https://docs.github.com/en/copilot/customizing-copilot/customizing-the-development-environment-for-copilot-coding-agent)

### Confirmed required job name

**`copilot-setup-steps`**

The docs are explicit:

> *"The job MUST be called `copilot-setup-steps` or it will not be picked up by Copilot."*

Any other job name in the same file is ignored by the agent.

### Default-branch requirement

> *"The `copilot-setup-steps.yml` workflow won't trigger unless it's present on your default branch."*

The file must be **merged into the default branch** (typically `main`) before it is used. A version sitting only on a feature branch has no effect on the agent's runtime.

### When and how it runs

1. When a Copilot cloud agent session starts (user assigns an issue, mentions `@copilot`, or opens a session from the Agents panel), GitHub Actions spins up an ephemeral runner.
2. **Before the agent begins coding**, it executes the `copilot-setup-steps` job from `.github/workflows/copilot-setup-steps.yml` on that runner.
3. After all setup steps complete (or after the first failure), the agent proceeds to checkout (if not already done in setup steps) and starts working.
4. Progress is visible in the Copilot session logs. See [Tracking GitHub Copilot's sessions](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/track-copilot-sessions).

### Runner OS / image

- **Default:** `ubuntu-latest` (GitHub-hosted, standard image — same as a normal Actions runner)
- **Customizable via `runs-on`:** Can be set to larger GitHub-hosted runners or self-hosted runners
- **OS restriction:** Only **Ubuntu x64** and **Windows 64-bit** are supported. macOS runners are not compatible with Copilot cloud agent.

---

## Section 2 — Trigger Requirements

### Official template triggers (from GitHub docs)

```yaml
on:
  workflow_dispatch:
  push:
    paths:
      - .github/workflows/copilot-setup-steps.yml
  pull_request:
    paths:
      - .github/workflows/copilot-setup-steps.yml
```

**Three triggers are used in the official example — here is what each does:**

| Trigger | Purpose |
|---|---|
| `workflow_dispatch` | Manual test run from the Actions tab at any time |
| `push` (path filter) | Auto-validates the file when it is changed on any branch and pushed |
| `pull_request` (path filter) | Shows the workflow check inline on the PR that modifies the file |

**The Copilot agent itself does NOT use these triggers.** The agent runtime directly invokes the `copilot-setup-steps` job, bypassing the `on:` triggers entirely. The triggers exist purely so the file can be tested as a regular workflow:

> *"Your `copilot-setup-steps.yml` file will automatically be run as a normal GitHub Actions workflow when changes are made, so you can see if it runs successfully."*

> *"Once you have merged the yml file into your default branch, you can manually run the workflow from the repository's Actions tab at any time to check that everything works as expected."*

### Minimum viable trigger

If you only want manual testing capability, `workflow_dispatch` alone is sufficient:

```yaml
on:
  workflow_dispatch:
```

The `push` + `pull_request` path-filter triggers are optional quality-of-life additions (they let you catch regressions whenever the file is edited).

---

## Section 3 — Recommended `copilot-setup-steps.yml` (Full File)

The following is the drop-in file for `.github/workflows/copilot-setup-steps.yml` in this starter pack.

```yaml
# .github/workflows/copilot-setup-steps.yml
#
# Purpose:
#   Pre-provisions the Copilot cloud agent's ephemeral GitHub Actions runner
#   before the agent starts coding. This deterministically installs the
#   toolchain and dependencies so the agent can build, lint, test, and
#   validate its own changes without trial-and-error installs.
#
# Discovery rules (GitHub docs):
#   - File MUST live at exactly `.github/workflows/copilot-setup-steps.yml`.
#   - File MUST be present on the repository's default branch.
#   - Job MUST be named `copilot-setup-steps` (exact match, case-sensitive).
#   - Only `steps`, `permissions`, `runs-on`, `services`, `snapshot`, and
#     `timeout-minutes` (max: 59) are honoured in the job definition.
#     All other job-level settings are ignored by the agent runtime.
#
# Triggers:
#   - `workflow_dispatch` lets maintainers manually test from the Actions tab.
#   - `push` / `pull_request` path filters auto-validate this file when it
#     is edited, showing a check on the PR.  Neither trigger is used by the
#     Copilot agent itself — the agent invokes the job directly.
#
# References:
#   https://docs.github.com/en/copilot/customizing-copilot/customizing-the-development-environment-for-copilot-coding-agent

name: Copilot Setup Steps

on:
  # Allow maintainers to manually test this workflow from the Actions tab.
  workflow_dispatch:
  # Auto-validate whenever this file is modified (push or PR).
  push:
    paths:
      - .github/workflows/copilot-setup-steps.yml
  pull_request:
    paths:
      - .github/workflows/copilot-setup-steps.yml

jobs:
  # IMPORTANT: This job name is mandatory. Copilot will silently ignore
  # any job with a different name.
  copilot-setup-steps:
    runs-on: ubuntu-latest

    # Minimum permissions needed for setup steps.
    # Copilot is given its own separate token for its coding operations.
    permissions:
      contents: read   # required by actions/checkout

    # The agent enforces a hard cap; 59 minutes is the maximum allowed.
    # Keep setup lean — every minute here is a minute before the agent
    # can start coding. Target < 5 minutes for a warm cache hit.
    timeout-minutes: 15

    steps:
      # ── 1. Checkout ──────────────────────────────────────────────────────
      # Note: The agent overrides `fetch-depth` regardless of what is set
      # here, so omit it entirely (docs confirmed behaviour).
      - name: Checkout repository
        uses: actions/checkout@v4

      # ── 2. Node.js 22 ────────────────────────────────────────────────────
      # This starter pack's Express app requires Node >= 22 (package.json
      # `engines` field). Pinning the major version ensures reproducibility.
      # `cache: npm` stores ~/.npm between runs; `cache-dependency-path`
      # scopes the cache key to the app subdirectory's lockfile.
      - name: Set up Node.js 22
        uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: "npm"
          cache-dependency-path: app/package-lock.json

      # ── 3. Install Node dependencies ─────────────────────────────────────
      # `npm ci` performs a clean, deterministic install from package-lock.json.
      # Running this in setup means the agent can immediately run
      # `npm test` and `npm run lint` without re-downloading packages.
      - name: Install Node dependencies
        working-directory: app
        run: npm ci

      # ── 4. Terraform ─────────────────────────────────────────────────────
      # The infra/ directory uses Terraform. Pin to 1.9.x so the agent uses
      # the same CLI version as human contributors and CI.
      - name: Set up Terraform 1.9.x
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.9.*"

      # ── 5. APM CLI ───────────────────────────────────────────────────────
      # TODO: replace with verified APM install command from Spike A.
      # Example placeholder (do NOT commit this as-is):
      #
      # - name: Install APM CLI
      #   run: |
      #     curl -fsSL https://apm.example.com/install.sh | bash
      #     echo "$HOME/.apm/bin" >> "$GITHUB_PATH"

      # ── 6. Sanity checks ─────────────────────────────────────────────────
      # Quick version pins so failures surface in setup logs, not mid-task.
      # These are read-only, fast, and provide clear diagnostics.
      - name: Verify tool versions
        run: |
          echo "=== Node ===" && node --version
          echo "=== npm ===" && npm --version
          echo "=== Terraform ===" && terraform --version
          echo "=== gh CLI ===" && gh --version
          echo "=== az CLI ===" && az --version 2>/dev/null | head -3 || echo "(az not pre-installed on this image)"
```

### Notes on specific decisions

| Decision | Rationale |
|---|---|
| `actions/checkout@v4` | Current stable major version. Docs show `@v6` in some examples but v6 does not exist as a stable release (likely a docs draft error); v4 is the production version. |
| `timeout-minutes: 15` | Safely under the 59-minute hard cap. Warm cache path takes ~1–2 min; cold install of Node + Terraform ~5 min. Leaves headroom without wasting time on runaway steps. |
| No `npm run lint && npm test` in setup | **Not recommended in setup steps.** Lint/test failures would cause the agent to skip remaining steps and start with a partially-configured environment. The agent will run lint/test itself as part of its validation loop — don't duplicate it here and risk blocking setup on a pre-existing linting warning. |
| No `docker pull node:22-slim` | Pre-pulling the Docker image adds ~1 minute every cold run and only benefits tasks that explicitly use Docker. Omit unless the agent is expected to run Docker-based tests. |
| `working-directory: app` | The Express app lives in `app/`, not the repo root. |
| APM CLI as `# TODO` | Spike A has not yet confirmed the APM binary distribution method. Replace with verified command from Spike A before shipping. |

---

## Section 4 — What Goes Where

| File | Responsibility | Who reads it |
|---|---|---|
| `.github/workflows/copilot-setup-steps.yml` | **Runtime environment provisioning.** Installs OS-level toolchains, language runtimes, package dependencies, and CLIs. Runs _before_ the agent writes a single line of code. | GitHub Actions runner (machine) |
| `AGENTS.md` | **Coding-time guidance.** Tells the agent where the source lives, what commands to run (`npm test`, `terraform plan`), coding conventions, file structure, and what _not_ to change. Read by the agent's LLM context window as it works. | Copilot LLM at runtime |
| `.github/copilot-instructions.md` | **APM-compiled instructions.** Auto-generated by the APM (`apm compile`). Contains merged, deduplicated instructions assembled from repo knowledge. Should not be hand-edited. | Copilot LLM at runtime |

**Rule of thumb:**  
- If it installs something on the machine → `copilot-setup-steps.yml`  
- If it tells the agent _how_ to use what's installed → `AGENTS.md`  
- If APM manages it → `.github/copilot-instructions.md`

---

## Section 5 — Failure Modes

### F-1: Job named differently → silent skip

**Symptom:** Agent starts without pre-installed deps, fails to build.  
**Cause:** A job named `setup-steps`, `copilot_setup_steps`, or anything else is silently ignored.  
**Fix:** The job must be named exactly `copilot-setup-steps`.

### F-2: File not on default branch → never executed

**Symptom:** Even after merge to `main`, the file doesn't run; agent starts cold.  
**Cause:** File exists only on a feature branch or has not been merged yet.  
**Fix:** Merge the file into the default branch before delegating tasks to the agent.

### F-3: Step failure → partial environment

**Symptom:** Agent starts but cannot find `terraform` or `npm` packages.  
**Cause:** A setup step failed (non-zero exit). Remaining steps are skipped, not the whole job.  
**Fix:** Use `set -e` / `set -euo pipefail` in `run:` blocks to catch silent failures. Monitor session logs.

### F-4: Heavy/slow setup → agent timeout risk

**Symptom:** Agent session times out or costs excessive Actions minutes before coding begins.  
**Cause:** Setup exceeds the 59-minute hard cap (GitHub enforced), or simply takes too long due to uncached large downloads.  
**Fix:** Keep setup lean. Use `actions/setup-node` with `cache: npm` — subsequent runs serve from cache in seconds. Avoid `docker pull` of large images unless necessary.

### F-5: Network egress restricted by org policy → install failures

**Symptom:** `npm ci` or `terraform init` fails with network errors on org-managed runners.  
**Cause:** The org has egress filtering (firewall policy or Azure private networking) that blocks `registry.npmjs.org`, `releases.hashicorp.com`, etc.  
**Fix:** Allowlist the required hostnames at the org/network level. Required outbound hosts for the Copilot agent itself:
  - `uploads.github.com`
  - `user-images.githubusercontent.com`
  - `api.business.githubcopilot.com` (Copilot Business)
  - `api.enterprise.githubcopilot.com` (Copilot Enterprise)
  - `api.individual.githubcopilot.com` (Pro/Pro+)

### F-6: Wrong Node version → Express fails

**Symptom:** Agent cannot run `npm test` or start the Express app.  
**Cause:** `setup-node` pinned to `node-version: "18"` while `app/package.json` requires `"node": ">=22.0.0"`.  
**Fix:** Use `node-version: "22"` as in the file above. The `engines` field in `package.json` will cause `npm ci` itself to warn on mismatch.

### F-7: `fetch-depth` override (known behaviour)

**Symptom:** `actions/checkout` `fetch-depth` setting has no effect.  
**Cause:** The agent runtime overrides `fetch-depth` to enable rollback capabilities.  
**Fix:** Do not set `fetch-depth` in the checkout step; it will be ignored regardless.

### F-8: Secrets not in `copilot` environment

**Symptom:** `${{ secrets.MY_API_KEY }}` is empty in setup steps; npm install of private packages fails.  
**Cause:** Secrets must be stored in the **`copilot` GitHub Actions environment** (not the standard repo secrets) to be available in the agent's runner.  
**Fix:** Navigate to **Settings → Environments → copilot → Add secret** in the repository. Standard repo secrets are not automatically surfaced to the agent's environment.

---

## Section 6 — Open Questions

| # | Question | Status | Notes |
|---|---|---|---|
| OQ-1 | **APM CLI install command** | ⏳ Blocked on Spike A | Replace `# TODO` in Step 5 once Spike A confirms the binary distribution method and pinnable version. |
| OQ-2 | **Actions minutes billing** | Partially verified | The agent's environment is powered by GitHub Actions; minutes count against the org's standard Actions quota. However, the _Copilot premium requests_ consumed by the agent itself are billed separately (per Copilot plan). The exact per-session Actions minutes cost depends on setup time + agent task duration. Org admins should monitor via **Settings → Billing → Actions**. GitHub docs do not publish a per-session estimate. |
| OQ-3 | **Caching across agent sessions** | Unclear | GitHub Actions cache is repo-scoped and shared across workflow runs. Setup steps with `cache: npm` should benefit from cache hits across sessions, but cache eviction policy (10 GB per repo) may cause cold runs for infrequently-used keys. |
| OQ-4 | **`snapshot` job setting** | Undocumented detail | The `snapshot` field is listed as configurable in the `copilot-setup-steps` job, but GitHub docs provide no usage example. This may relate to container or VM snapshotting for faster agent warm-up. Investigate if setup time exceeds 5 minutes in practice. |
| OQ-5 | **Multiple jobs in the file** | Verified non-issue | Only the `copilot-setup-steps` job is executed by the agent. Other jobs in the same workflow file are simply ignored by the agent runtime (they run only on normal trigger conditions). This means the `push` / `pull_request` triggers can safely trigger a separate validation job in the same file if desired. |
| OQ-6 | **`actions/checkout@v6` in docs** | Likely docs draft error | GitHub's official docs examples show `uses: actions/checkout@v6` — but as of 2025-07-14, the current stable release of `actions/checkout` is v4. There is no stable v5 or v6 release. This spike uses `@v4`. Re-verify if GitHub releases a new major version before this starter pack ships. |

---

## Summary

| Item | Value |
|---|---|
| **Required file path** | `.github/workflows/copilot-setup-steps.yml` |
| **Required job name** | `copilot-setup-steps` (exact, case-sensitive) |
| **Must be on** | Default branch (e.g. `main`) |
| **Triggers needed for agent** | None — agent invokes the job directly |
| **Triggers for self-validation** | `workflow_dispatch` + `push`/`pull_request` (path filter) |
| **Runner** | `ubuntu-latest` (default); Ubuntu x64 or Windows x64 only |
| **Customisable job fields** | `steps`, `permissions`, `runs-on`, `services`, `snapshot`, `timeout-minutes` (max: 59) |
| **Permissions** | `contents: read` (minimum for checkout) |
| **Failure behaviour** | First failing step skips remaining steps; agent continues |
| **Secrets** | Must be in the `copilot` GitHub Actions environment |
| **Actions minutes** | Counts against org's standard Actions quota |
