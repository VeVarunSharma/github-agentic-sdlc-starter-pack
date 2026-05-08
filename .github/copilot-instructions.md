<!--
  HAND-AUTHORED — primary agent context for this repository.
  Edit this file directly. Do NOT run `apm compile -t copilot` against this
  repo: it would overwrite this file.

  GitHub Copilot reads this file automatically (see
  https://docs.github.com/copilot/customizing-copilot/adding-repository-custom-instructions-for-github-copilot
  ). AGENTS.md-aware clients (Claude Code, Cursor, OpenCode, Codex, Gemini,
  Windsurf) read AGENTS.md, which is a slim pointer back to this file.

  Coexistence: APM-installed instructions (from github/awesome-copilot) live
  alongside the hand-authored ones in `.github/instructions/`. APM tracks its
  files in `apm.lock.yaml`; hand-authored ones are flagged "unmanaged" by
  `apm audit` (allowed by `unmanaged_files.action: warn` in apm-policy.yml).
-->

# Copilot instructions — GitHub Agentic SDLC Starter Pack

## Project overview

This is the **GitHub Agentic SDLC Starter Pack** — a reusable, opinionated
template that any GitHub org or enterprise can clone (or use as a template
repository) and get, in one bootstrap command, a complete agentic software
development lifecycle running on GitHub. It ships:

- A small Node.js + Express sample app (deploy target).
- Terraform infrastructure for Azure App Service deployed via OIDC (no
  long-lived secrets in GitHub).
- A GitHub Actions CI/CD pipeline with built-in gates (lint, tests, CodeQL,
  Dependency Review, APM audit, Terraform fmt/validate).
- GitHub Advanced Security (GHAS) baseline (CodeQL, Dependabot, Dependency
  Review, Secret Scanning + Push Protection).
- A **`.github/`-first agent context layer**: this file plus hand-authored
  examples of every Copilot primitive type — instructions, prompts,
  chatmodes, agents, skills, hooks, MCP — under
  `.github/{instructions,prompts,chatmodes,agents,skills,hooks,mcp}/`.
- An optional [APM (Agent Package Manager)](https://github.com/microsoft/apm)
  layer that installs ~5–7 curated dependencies from
  [github/awesome-copilot](https://github.com/github/awesome-copilot)
  alongside the hand-authored examples.

The repo's identity is **`.github/`-first**. The hand-authored primitives are
the showcase; APM is the supplementary "and here's how you scale this with
awesome-copilot" pattern. Consumers can fork the repo and read every
primitive directly without ever installing APM.

The goal: clone, run `scripts/setup-azure-oidc.sh`, run `./scripts/verify.sh`,
and you have a working agentic SDLC reference you can adapt to your own
workloads.

## Tech stack

- **App** — Node.js 22 + Express (in [`app/`](../app)). Tests use Node's
  built-in `node:test` runner; no extra test framework dependency.
- **Container** — Docker, multi-stage build on `node:22-slim`. Non-root user.
- **Infra** — Terraform (`hashicorp/azurerm` provider) targeting Azure App
  Service (Linux, container), Azure Container Registry, Log Analytics
  workspace, and Application Insights. State is remote (Azure Storage)
  configured by the bootstrap module.
- **CI/CD** — GitHub Actions. OIDC-based auth to Azure (`azure/login@v2` with
  `client-id` + `tenant-id` + `subscription-id` repo *variables*, no client
  secret).
- **Agent context** — hand-authored primitives in `.github/`, augmented
  optionally by APM-installed deps from awesome-copilot. MCP servers
  (GitHub, Microsoft Learn, Azure) configured for VS Code in
  [`.vscode/mcp.json`](../.vscode/mcp.json) and mirrored as a reference
  for the GitHub Copilot cloud agent in
  [`.github/mcp/mcp.json`](./mcp/mcp.json).
- **Security** — GHAS baseline: CodeQL (JavaScript), Dependabot version +
  security updates, Dependency Review on PRs, Secret Scanning + Push
  Protection at the repo level.

## Repository layout

```
.
├── app/                              # Sample Node/Express app (deploy target)
├── infra/
│   ├── bootstrap/                    # One-time Terraform: deploy identity, tfstate backend
│   │                                 # (a human runs this with `az login`)
│   └── app/                          # CI-applied Terraform: ACR, App Service, Log Analytics
├── .github/
│   ├── copilot-instructions.md       # ← THIS FILE (hand-authored, primary entry point)
│   ├── instructions/                 # Path-scoped instructions (hand-authored + APM)
│   ├── prompts/                      # Slash-prompt definitions (hand-authored + APM)
│   ├── chatmodes/                    # Custom Copilot Chat modes (hand-authored)
│   ├── agents/                       # Sub-agent definitions (hand-authored + APM)
│   ├── skills/                       # Multi-step skills (hand-authored + APM)
│   ├── hooks/                        # Copilot/APM hook definitions (hand-authored)
│   ├── mcp/                          # MCP server reference for the cloud agent
│   ├── workflows/                    # CI/CD, APM audit, Copilot setup steps, security
│   ├── ISSUE_TEMPLATE/               # Spec / bug / feature issue forms
│   └── rulesets/                     # Branch protection rules as code
├── .vscode/
│   ├── mcp.json                      # MCP server config that VS Code reads natively
│   ├── settings.json                 # Workspace editor + Copilot settings
│   └── extensions.json               # Recommended extensions
├── .devcontainer/
│   └── devcontainer.json             # Codespaces / Dev Container definition
├── apm.yml                           # APM manifest — declares supplementary deps
├── apm-policy.yml                    # APM governance policy — allow/deny rules
├── apm.lock.yaml                     # APM lockfile — committed; rewritten by `apm install`
├── AGENTS.md                         # Slim pointer for AGENTS.md-aware clients
├── examples/                         # Alternative variants (Container Apps, OSS, SWA)
├── docs/                             # Architecture, adoption playbook, ownership model
└── scripts/                          # bootstrap.sh, setup-azure-oidc.sh, verify.sh
```

## How agents read this repo

Different clients pick up different files. The `.github/`-first layout is
designed so that whatever client an agent uses, it gets the same context.

| Client                          | Reads from                                                      |
| ------------------------------- | --------------------------------------------------------------- |
| **GitHub Copilot (Chat / coding agent)** | `.github/copilot-instructions.md`, `.github/instructions/*`, `.github/prompts/*`, `.github/chatmodes/*` |
| **AGENTS.md-aware clients** (Claude Code, Cursor, OpenCode, Codex, Gemini, Windsurf) | `AGENTS.md` → which points back to this file              |
| **VS Code (any model via Copilot Chat)** | `.vscode/mcp.json` for MCP servers; the `.github/` files above for instructions |
| **GitHub Copilot cloud agent**  | Repo Settings → Copilot → Cloud agent for MCP (paste contents of `.github/mcp/mcp.json`); `.github/copilot-instructions.md` for context |

When extending the agent context, prefer the most-specific primitive:

- **Always-applied guidance** → this file.
- **Path-scoped guidance** (e.g. only for `app/**/*.js`) →
  `.github/instructions/*.instructions.md` with an `applyTo:` glob in the
  front matter.
- **One-off slash command** → `.github/prompts/*.prompt.md`.
- **Persona / mode for Copilot Chat** → `.github/chatmodes/*.chatmode.md`.
- **Reusable sub-agent invoked from another agent** →
  `.github/agents/*.agent.md`.
- **Multi-step playbook with deterministic steps** →
  `.github/skills/<name>/SKILL.md`.
- **Behavioural lifecycle hook** → `.github/hooks/*.json`.

The rule of thumb: hand-author into `.github/` first, then once a primitive
is stable, consider extracting it to a published package and pulling it back
in via `apm.yml` so other repos can reuse it.

## Conventions

### Code style

- ESLint flat config (`eslint.config.js` in `app/`). Prettier-compatible
  defaults.
- 2-space indent. LF line endings. Final newline. No trailing whitespace.
  Enforced by `.editorconfig` and `.gitattributes`.
- Imports: ES modules (`"type": "module"` in `app/package.json`).
- Prefer small, pure functions. Keep route handlers thin; push logic into
  `app/src/services/`.

### Commit style

- [Conventional Commits](https://www.conventionalcommits.org/) encouraged:
  `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, `ci:`, `build:`.
- DCO sign-off (`git commit -s`) is **encouraged in the baseline**, not
  enforced — the public-OSS-hardening overlay enables the Probot DCO check
  for repos that need it.
- Agent-authored commits **must** declare authorship. Use the
  `Co-authored-by:` trailer for the agent and the `Signed-off-by:` trailer
  for the human reviewer who approved the change. Concrete trailer for the
  GitHub Copilot coding agent:

  ```
  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
  ```

### Branch naming

| Prefix                 | Use for                                                                   |
| ---------------------- | ------------------------------------------------------------------------- |
| `feature/<desc>`       | New functionality                                                         |
| `fix/<desc>`           | Bug fixes                                                                 |
| `chore/<desc>`         | Tooling, deps, refactors with no behaviour change                         |
| `docs/<desc>`          | Documentation-only changes                                                |
| `agent/<issue>-<desc>` | Branches authored by Copilot coding agent (issue # is the spec issue)     |

### Pull requests

- Use the PR template in `.github/PULL_REQUEST_TEMPLATE.md`.
- Declare whether the PR is agent-authored (the template has a checkbox).
- Link the source spec issue with `Closes #<n>` or `Refs #<n>`.
- All PRs must pass: `ci` (lint + unit tests), `codeql`, `dependency-review`,
  `apm-audit`, and Terraform `fmt` + `validate` (no `plan` on PR — that
  runs in `infra-apply.yml` against the `infra-apply` environment).
- **Squash-merge is the default** merge strategy; the PR title becomes the
  commit subject, so write it in Conventional Commit form.

### Tests

- Use Node's built-in `node:test` for the sample app. Run with `npm test`
  (which runs `node --test`).
- Keep tests next to source: `app/src/foo.js` ↔ `app/src/foo.test.js`.
- New features should ship with at least one test exercising the happy path.

## Build, test, run commands

```bash
# --- Sample app (Node 22) ---
cd app
npm install
npm test
npm start                       # serves http://localhost:3000
docker build -t agentic-sdlc-sample-app .
docker run --rm -p 3000:3000 agentic-sdlc-sample-app

# --- Infra: bootstrap (one-time, human-run with `az login`) ---
cd infra/bootstrap
terraform init
terraform apply                 # creates the Azure deploy identity + tfstate backend

# --- Infra: app (run from CI under OIDC; or locally with `az login`) ---
cd infra/app
terraform init
terraform plan
terraform apply                 # CI does this on `main` after PR merge

# --- APM (supplementary; OPTIONAL) ---
apm install                     # installs ~5–7 awesome-copilot deps alongside
                                # the hand-authored .github/* primitives
apm audit --policy ./apm-policy.yml

# IMPORTANT: do NOT run `apm compile -t copilot` against this repo.
# That command would overwrite the hand-authored .github/copilot-instructions.md.

# --- End-to-end verify ---
./scripts/verify.sh             # lint + test + terraform validate + apm audit
```

## Agentic SDLC overview

The repository implements a closed-loop agentic SDLC built entirely on
GitHub primitives. The loop is:

1. **Issue** — A spec issue is opened (often from the issue form in
   `.github/ISSUE_TEMPLATE/spec.yml`). It captures intent, acceptance
   criteria, non-goals, and links to relevant context.
2. **Copilot agent** — The issue is assigned to the GitHub Copilot coding
   agent (or picked up by a developer working with Copilot in their
   editor). The agent reads `.github/copilot-instructions.md`, the
   `.github/instructions/*` files that match the files it edits, any
   relevant `.github/skills/`, and any referenced docs, then opens a
   draft PR on a `agent/<issue>-<desc>` branch.
3. **PR + gates** — The PR triggers CI: `ci` (lint + tests), `codeql`,
   `dependency-review`, `apm-audit` (verifies the APM-installed files
   match `apm install` output and the policy in `apm-policy.yml`), and
   Terraform `fmt` + `validate`.
4. **Review** — A human reviews the diff, the gates' results, and the
   agent's PR description. Branch protection requires at least one
   approving review.
5. **Merge** — Squash merge to `main`.
6. **OIDC deploy** — The `azure-deploy.yml` workflow assumes the Azure
   deploy identity via OIDC, builds and pushes the container image to
   ACR, and updates the App Service to point at the new image. No
   long-lived secrets are stored in GitHub.

See [`docs/agentic-sdlc.md`](../docs/agentic-sdlc.md) for the full diagram,
the list of guardrails at each stage, and a worked walkthrough.

## File ownership

This repository uses a **layered ownership model**. Knowing who owns which
file is essential — APM will overwrite some files on `apm install`, and
the CI audit will surface drift in those files.

### Hand-authored (humans own; never generated)

- `AGENTS.md` — slim pointer to this file.
- `.github/copilot-instructions.md` — **this file**.
- `.github/instructions/app-nodejs.instructions.md`
- `.github/instructions/infra-terraform.instructions.md`
- `.github/prompts/scaffold-tf-module.prompt.md`
- `.github/prompts/security-review.prompt.md`
- `.github/chatmodes/sdlc-planner.chatmode.md`
- `.github/agents/pr-reviewer.agent.md`
- `.github/skills/oidc-rotation/`
- `.github/hooks/pre-commit-eslint.json`
- `.github/mcp/mcp.json`
- `apm.yml`, `apm-policy.yml` — APM manifest and governance policy.
- `.vscode/*`, `.devcontainer/*` — workspace tooling.
- Root community files (`README.md`, `CODE_OF_CONDUCT.md`,
  `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE`, `SUPPORT.md`).

Each hand-authored primitive starts with an `<!-- HAND-AUTHORED -->`
marker so it's easy to tell at a glance what is generated and what is not.

### APM-installed (APM owns; rewritten by `apm install`)

- A subset of `.github/instructions/*.instructions.md` (the ones declared in
  `apm.yml` — typically code-review-generic, security-and-owasp, terraform,
  azure-naming, etc.)
- A subset of `.github/skills/<name>/` (typically `review-and-refactor`)
- `apm.lock.yaml` — committed but rewritten by `apm install`. Treat it like
  `package-lock.json`: don't hand-edit, but do commit changes.

**Do not edit APM-installed files by hand.** They are deterministically
generated from `apm.yml` (the dependency manifest) and the upstream
content. To change them:

1. Adjust `apm.yml` to add / remove / re-pin a dependency, then
2. Run `apm install`, and commit the result.

The [`apm-audit.yml`](./workflows/apm-audit.yml) workflow runs
`apm install --target copilot` + `apm audit --ci --policy ./apm-policy.yml`
on every PR. It detects drift in APM-managed files only — hand-authored
files surface as "unmanaged" warnings (allowed by
`unmanaged_files.action: warn` in `apm-policy.yml`).

### Files consumers own (when adopting this template)

- Everything in `app/` — your application code.
- Everything in `infra/` — your infrastructure.
- Root community files when bootstrapping into an existing repo (the
  adoption script will not overwrite without `--force`).

The full ownership table, including conflict-resolution rules and what
`apm install --force` does, lives in
[`docs/apm-ownership-model.md`](../docs/apm-ownership-model.md).

## Security

- **GHAS baseline** — CodeQL (JavaScript) runs on PRs and `main`;
  Dependabot delivers version and security updates weekly; Dependency
  Review fails PRs that introduce high-severity vulnerable dependencies;
  Secret Scanning and Push Protection are enabled at the repo settings
  level. CodeQL is free for public repos and requires GHAS for private
  repos — see [`docs/repo-settings-checklist.md`](../docs/repo-settings-checklist.md).
- **OIDC to Azure** — No long-lived cloud credentials in GitHub. The
  `azure-deploy.yml` workflow exchanges a short-lived OIDC token for an
  Azure access token. The bootstrap Terraform creates the federated
  identity credential. Repo *variables* (not secrets) hold the public
  identity references. See
  [`docs/azure-oidc-setup.md`](../docs/azure-oidc-setup.md) for the
  rotation procedure when the repo or environment is renamed.
- **APM content scanning** — `apm install` scans every dependency for
  hidden Unicode and other tampering; `apm audit` runs the same checks
  on demand and is wired into CI.
- **Branch protection as code** — `.github/rulesets/` defines branch
  protection rules; review them rather than relying on UI configuration.
  The default is **evaluate-mode** (visible warnings, no blocking) so the
  template is friendly on day one; **enforce-mode** is the graduation step
  documented in `docs/repo-settings-checklist.md`.
- **Reporting vulnerabilities** — Use GitHub Private Vulnerability
  Reporting. See [`SECURITY.md`](../SECURITY.md) for details.

## MCP servers

This repo configures three Model Context Protocol servers in two places so
that whatever client an agent uses, it gets the same tools:

| Server            | Type  | Purpose                                                     |
| ----------------- | ----- | ----------------------------------------------------------- |
| `github`          | http  | GitHub remote MCP — read/write issues, PRs, code, Actions   |
| `microsoft-learn` | http  | Microsoft Learn docs — grounded answers from official docs  |
| `azure`           | stdio | Azure MCP server — query/operate Azure resources during dev |

- **VS Code** reads from [`.vscode/mcp.json`](../.vscode/mcp.json) natively.
  The first time you start an MCP server in VS Code you'll be prompted to
  trust it. The GitHub server uses an input-prompted PAT (stored securely
  by VS Code); the Azure server uses your `az login` credentials.
- **GitHub Copilot cloud agent** does *not* read from a file — paste the
  contents of [`.github/mcp/mcp.json`](./mcp/mcp.json) into
  Settings → Copilot → Cloud agent → MCP configuration. The repo-tracked
  `.github/mcp/mcp.json` is the source of truth so the cloud-agent config
  is reviewable in PRs.

For server config syntax and IntelliSense, VS Code reads
[the official MCP configuration reference](https://code.visualstudio.com/docs/copilot/reference/mcp-configuration).

## Where to learn more

- [`docs/dotgithub-tour.md`](../docs/dotgithub-tour.md) — guided tour of
  every `.github/` primitive, what it is, and when to use it.
- [`docs/architecture.md`](../docs/architecture.md) — components,
  boundaries, data flow.
- [`docs/agentic-sdlc.md`](../docs/agentic-sdlc.md) — the SDLC loop, gate
  by gate.
- [`docs/adoption-playbook.md`](../docs/adoption-playbook.md) — how to
  adopt this template in your own org.
- [`docs/apm-ownership-model.md`](../docs/apm-ownership-model.md) — full
  file-ownership table and conflict-resolution rules.
- [`docs/azure-oidc-setup.md`](../docs/azure-oidc-setup.md) — step-by-step
  federated credential setup.
- [`docs/governance.md`](../docs/governance.md) — policy model and how
  `apm-policy.yml` is enforced.
- [`docs/repo-settings-checklist.md`](../docs/repo-settings-checklist.md)
  — one-time GitHub repo settings (rulesets, GHAS, Actions perms).
- [`docs/upstream-sources.md`](../docs/upstream-sources.md) — provenance of
  every dependency declared in `apm.yml`.
- [`docs/maintenance-matrix.md`](../docs/maintenance-matrix.md) — what to
  update when, and who owns it.
- [`docs/enterprise-hardening.md`](../docs/enterprise-hardening.md) —
  additional controls for regulated/enterprise deployments.
- [`docs/resources.md`](../docs/resources.md) — curated link catalogue
  (awesome-copilot, awesome-actions, github-copilot-canada, MCP registry,
  Azure Verified Modules).
