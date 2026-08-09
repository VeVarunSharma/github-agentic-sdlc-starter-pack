# GitHub Agentic SDLC Starter Pack

> A reusable, opinionated GitHub template for orgs and enterprises adopting
> an **agentic software development lifecycle**. Clone it, run two
> commands, and you have a working agent context layer + CI/CD gates +
> secure Azure deploy reference, all on GitHub.

This repo is **`.github/`-first**: hand-authored
[`.github/copilot-instructions.md`](./.github/copilot-instructions.md) is
the primary entry point, and `.github/{instructions, prompts, chatmodes,
agents, skills, hooks, mcp}/` ship worked examples of every Copilot agent
primitive you'll want to extend. APM is layered on top as the optional
"and here's how you scale this" pattern.

---

## What you get

- 🤖 **Hand-authored Copilot primitives** under `.github/` — at least one
  worked example per type (instructions, prompts, chatmodes, agents,
  skills, hooks, MCP), readable without installing anything.
- 📦 **Optional APM layer** ([microsoft/apm](https://github.com/microsoft/apm))
  pulling 7 curated dependencies from
  [github/awesome-copilot](https://github.com/github/awesome-copilot)
  alongside the hand-authored examples.
- ☁️ **Terraform infra for Azure App Service** with separate plan, apply,
  and deploy **OIDC federated identities** — no long-lived cloud credentials.
- 🔐 **GHAS baseline** — CodeQL, Dependabot, Dependency Review, Secret
  Scanning + Push Protection.
- 🚦 **Branch rulesets-as-code** with an evaluate → enforce graduation
  path, and **gates** that block merges on lint, tests, CodeQL,
  Dependency Review, APM audit, and Terraform validate.
- 🔁 **Closed-loop SDLC** — spec issue → Copilot agent → draft PR →
  gates → human review → squash-merge → OIDC deploy.
- 🖥️ **Live control-plane showcase** — a responsive, accessible UI backed by
  real `/health` and `/api/info` state, governed by root `DESIGN.md`.
- 📦 **Immutable container delivery** — pinned base image, Hadolint + Trivy,
  BuildKit SBOM/provenance, digest deployment, and health-verified rollback.

---

## Quick start

```bash
# 1. Create a new repo from this template
gh repo create <owner>/<repo> --template <this-owner>/<this-repo> --private --clone
cd <repo>

# 2. One-time: provision scoped Azure plan/apply/deploy trust (no secrets)
./scripts/setup-azure-oidc.sh

# 3. Smoke-test everything (lint + tests + terraform validate + apm audit)
./scripts/verify.sh
```

> `apm install` is **optional**. The hand-authored `.github/` primitives
> and the sample app work without it; APM augments them with curated
> awesome-copilot deps. See
> [`docs/apm-ownership-model.md`](./docs/apm-ownership-model.md).

---

## What's inside

| Path | What it is |
| --- | --- |
| [`.github/copilot-instructions.md`](./.github/copilot-instructions.md) | Primary agent context — read first |
| [`.github/instructions/`](./.github/instructions/) | Path-scoped guidance (hand-authored + APM coexist) |
| [`.github/prompts/`](./.github/prompts/) | Slash-prompt definitions |
| [`.github/chatmodes/`](./.github/chatmodes/) | Custom Copilot Chat modes |
| [`.github/agents/`](./.github/agents/) | Sub-agent definitions |
| [`.github/skills/`](./.github/skills/) | Multi-step skill playbooks |
| [`.github/hooks/`](./.github/hooks/) | Lifecycle hooks |
| [`.github/mcp/`](./.github/mcp/) | MCP server reference for the cloud agent |
| [`.github/workflows/`](./.github/workflows/) | CI/CD, GHAS, APM audit, OIDC deploy |
| [`.github/rulesets/`](./.github/rulesets/) | Branch protection as code |
| [`app/`](./app/) | Node.js 22 + Express 5 showcase app and live APIs |
| [`DESIGN.md`](./DESIGN.md) | Enforceable visual system for `app/public/**` |
| [`infra/bootstrap/`](./infra/bootstrap/) | One-time Terraform — scoped OIDC identities + hardened tfstate |
| [`infra/app/`](./infra/app/) | CI-applied Terraform — ACR, App Service, Log Analytics |
| [`examples/`](./examples/) | Variants — Container Apps, Static Web Apps, OSS-hardening |
| [`docs/`](./docs/) | Architecture, adoption, ownership, security, OIDC, governance |
| [`scripts/`](./scripts/) | `bootstrap.sh`, `setup-azure-oidc.sh`, `verify.sh`, `template-cleanup.sh` |

A guided walkthrough of every `.github/` primitive lives in
[`docs/dotgithub-tour.md`](./docs/dotgithub-tour.md).

---

## The agentic SDLC loop

1. **Spec issue** opened from
   [`.github/ISSUE_TEMPLATE/spec.yml`](./.github/ISSUE_TEMPLATE/spec.yml)
   (intent, acceptance criteria, non-goals, context).
2. **Copilot coding agent** assigned. Reads `.github/copilot-instructions.md`,
   matching `.github/instructions/*`, any referenced skills; opens a draft
   PR on `agent/<issue>-<desc>`.
3. **Gates run** on the PR — `ci`, `codeql`, `dependency-review`,
   `apm-audit`, Terraform `fmt` + `validate`.
4. **Human review** — branch protection requires at least one approving
   review. Squash-merge to `main`.
5. **OIDC deploy** — the `production` identity exchanges a short-lived
   exact-subject token for an Azure access token, builds + pushes an attested
   image to ACR, and updates only the scoped App Service by OCI digest. Failed
   health checks restore the exact prior image.

Full diagram + gate-by-gate breakdown:
[`docs/agentic-sdlc.md`](./docs/agentic-sdlc.md).

---

## Adopting this template

1. Click **Use this template** (or `gh repo create --template`).
2. Run the **Template cleanup** workflow (or `scripts/template-cleanup.sh`)
   to replace `<owner>/<repo>`, `<owner>/<team>`, `<security-contact-email>`,
   and `<contact-email>` placeholders.
3. Configure Azure OIDC: `./scripts/setup-azure-oidc.sh`.
4. Import the evaluate-mode ruleset:
   ```bash
   gh api -X POST /repos/<owner>/<repo>/rulesets \
     --input .github/rulesets/main-branch-evaluate.json
   ```
5. Enable GHAS in **Settings → Code security**. CodeQL is free for public
   repos; private repos require a GHAS license.
6. Once every required check has appeared on at least one PR, graduate to
   the enforce-mode ruleset.

Step-by-step walkthrough:
[`docs/adoption-playbook.md`](./docs/adoption-playbook.md).
One-time GitHub repo settings:
[`docs/repo-settings-checklist.md`](./docs/repo-settings-checklist.md).

---

## Where to read more

- **[`docs/architecture.md`](./docs/architecture.md)** — components, data flow
- **[`docs/azure-oidc-setup.md`](./docs/azure-oidc-setup.md)** — federated credential setup + rotation
- **[`docs/governance.md`](./docs/governance.md)** — `apm-policy.yml` enforcement
- **[`docs/enterprise-hardening.md`](./docs/enterprise-hardening.md)** — additional controls for regulated deployments
- **[`docs/resources.md`](./docs/resources.md)** — curated link catalogue
- **[`AGENTS.md`](./AGENTS.md)** · **[`CONTRIBUTING.md`](./CONTRIBUTING.md)** · **[`SECURITY.md`](./SECURITY.md)** · **[`SUPPORT.md`](./SUPPORT.md)**

---

## Built on the shoulders of

- [github/awesome-copilot](https://github.com/github/awesome-copilot) — curated Copilot primitives library
- [microsoft/apm](https://github.com/microsoft/apm) — Agent Package Manager
- [microsoft/github-copilot-canada](https://github.com/microsoft/github-copilot-canada) — adoption guidance
- [sdras/awesome-actions](https://github.com/sdras/awesome-actions) — Actions catalog

## License

[MIT](./LICENSE) — fork it, adapt it, ship it.
