# Contributing

Thank you for considering a contribution to the **GitHub Agentic SDLC
Starter Pack**! This repo is intentionally small and opinionated, but
we welcome:

- 🐛 Bug fixes and security patches
- 📚 Documentation improvements (especially worked examples)
- 🧱 New `.github/` primitive examples (instructions, prompts,
  chatmodes, agents, skills, hooks)
- 🧪 New variants under `examples/`
- 🤖 Improvements to the agentic SDLC loop itself

If you're proposing a larger change, **open an issue first** so we
can align on direction before you invest time.

## Quick start

```bash
gh repo clone <owner>/<repo>
cd <repo>

# 1. Install the supplementary APM layer (optional but recommended).
apm install

# 2. Install app deps and run the smoke tests.
npm --prefix app ci
npm --prefix app test

# 3. Validate Terraform.
( cd infra/bootstrap && terraform init -backend=false && terraform validate )
( cd infra/app       && terraform init -backend=false && terraform validate )

# 4. (One-shot) verify everything together.
./scripts/verify.sh
```

## Branch + commit conventions

| Prefix | Use for |
| --- | --- |
| `feature/<desc>` | New functionality |
| `fix/<desc>` | Bug fixes |
| `chore/<desc>` | Tooling, deps, no-behaviour-change refactors |
| `docs/<desc>` | Documentation only |
| `agent/<issue>-<desc>` | Branches authored by the Copilot coding agent — `<issue>` is the spec issue number |

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(app): add /version endpoint
fix(infra): correct AcrPull scope on web app MI
docs(adoption): clarify OIDC rotation procedure
chore(deps): bump azurerm provider to 4.71.0
```

The PR title becomes the squash-commit subject — write it in
Conventional Commits form.

## DCO sign-off (encouraged in baseline)

We use the [Developer Certificate of Origin](https://developercertificate.org/).
Sign your commits with `-s`:

```bash
git commit -s -m "feat(app): add /version endpoint"
```

The sign-off is **encouraged but not enforced** in the baseline so
agent-authored PRs aren't blocked. The
`examples/public-oss-hardening/` overlay adds a DCO-check workflow
for repos that need to enforce it (regulated industries, OSS projects
that require legal provenance).

## Agent-authored PRs

If your PR is fully or partially produced by an AI agent (Copilot
coding agent, Copilot chat, Cursor, etc.):

1. Tick the **Agent-authored** box in the PR template.
2. Add a `Co-authored-by:` trailer for the agent:
   ```
   Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
   ```
3. Add a `Signed-off-by:` trailer for the human reviewer who
   approved the change.

The agent did not write `Signed-off-by:` for itself — that line is
the human's accountability stamp.

## Pull request gates

Every PR must pass:

| Check | Source | What it does |
| --- | --- | --- |
| `app — lint + tests` | `ci.yml` | ESLint + `node:test` |
| `terraform — fmt + validate` | `ci.yml` | Two matrix entries (bootstrap + app) |
| `docker — build sample app image (smoke)` | `ci.yml` | Multi-stage Docker build, no push |
| `Analyze (javascript-typescript)` | `codeql.yml` | CodeQL static analysis |
| `apm install + audit` | `apm-audit.yml` | APM lockfile drift + policy |
| `Review dependency changes` | `dependency-review.yml` | GHAS Dependency Review |

PR runs do **NOT** execute `terraform plan` against the real
subscription — that is reserved for `infra-apply.yml` (manual,
gated by the `infra-apply` GitHub Environment).

## Code style

- **JavaScript:** ESLint flat config in `app/eslint.config.js`,
  Prettier-compatible defaults, ES modules.
- **Terraform:** `terraform fmt -recursive`. Variable typing required.
  Naming follows `azure-naming.instructions.md`
  (`<workload>-<env>-<resource>`).
- **Shell:** `set -euo pipefail`, ShellCheck-clean.
- **YAML / JSON:** 2-space indent, LF line endings, final newline.
  Enforced by `.editorconfig`.

## Filing a security issue

**Do not open a public issue for security vulnerabilities.** Use
[GitHub Private Vulnerability Reporting](../../security/advisories/new).
See [`SECURITY.md`](./SECURITY.md) for the full disclosure policy.

## Code of conduct

This project is governed by the [Contributor Covenant 2.1](./CODE_OF_CONDUCT.md).
By participating, you agree to its terms.
