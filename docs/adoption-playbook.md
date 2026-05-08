# Adoption playbook

How to adopt this template in your own org. Three modes, depending on
how much you want to lift-and-shift vs cherry-pick.

## Mode 1 — Use as a template repo (recommended for new repos)

1. **On GitHub**: click "Use this template" or run
   `gh repo create <my-org>/<my-app> --template <this-org>/github-agentic-sdlc-starter-pack`
2. **First push** triggers
   [`template-cleanup.yml`](../.github/workflows/template-cleanup.yml) which
   replaces `<owner>/<repo>`, `<owner>/<team>`, `<contact-email>`, and
   `<security-contact-email>` placeholders across the repo. (Or run
   `./scripts/template-cleanup.sh` locally to do the same.)
3. **One-time Azure setup**:
   ```bash
   az login
   ./scripts/setup-azure-oidc.sh --repo <my-org>/<my-app>
   ```
   This runs `terraform -chdir=infra/bootstrap apply` with `az login`
   creds and sets the seven `AZURE_*` GitHub repo variables (not
   secrets) that the CI/CD workflows read.
4. **Verify locally**:
   ```bash
   ./scripts/bootstrap.sh    # apm install (optional) + npm ci + verify.sh
   ```
5. **Open a PR** with any change. All gates should run and pass.
6. **Graduate to enforce-mode rulesets** once every required check has
   appeared on at least one PR (see
   [`repo-settings-checklist.md`](./repo-settings-checklist.md)).

## Mode 2 — Adopt into an existing repo

For repos that already have code and infra, lift the agent + governance
layers without disturbing your existing app:

| What to copy | From | Why |
|--------------|------|-----|
| `.github/copilot-instructions.md` | This repo | Primary agent context. **Edit** to match your stack. |
| `.github/instructions/` | This repo | Path-scoped guidance. **Edit** the `applyTo:` globs. |
| `.github/prompts/`, `.github/chatmodes/`, `.github/agents/`, `.github/skills/`, `.github/hooks/`, `.github/mcp/` | This repo | Worked examples to fork from |
| `apm.yml`, `apm-policy.yml` | This repo | Trim the dep list to what you need |
| `.github/workflows/apm-audit.yml`, `codeql.yml`, `dependency-review.yml`, `template-cleanup.yml` | This repo | Reusable verbatim |
| `.github/rulesets/` | This repo | Adapt the required-check names to your job names |
| `.github/dependabot.yml` | This repo | |
| `.github/ISSUE_TEMPLATE/`, `.github/pull_request_template.md` | This repo | |
| `CONTRIBUTING.md`, `SECURITY.md`, `SUPPORT.md`, `CODE_OF_CONDUCT.md` | This repo | |
| `infra/`, `azure-deploy.yml`, `infra-apply.yml`, `setup-azure-oidc.sh` | **Maybe** | Only if your existing repo doesn't already have its own deploy story |

Do **not** copy `app/` (your existing app stays).

## Mode 3 — Cherry-pick individual primitives

If you only want one piece — say, the `oidc-rotation` skill or the
`pr-reviewer` agent — copy that file alone. Each primitive is
self-contained and has an `<!-- HAND-AUTHORED -->` marker plus inline
comments explaining what it does and where Copilot reads it.

## Org-wide rollout playbook

For platform / DevEx teams rolling this out across many repos:

1. **Fork this repo** into your org and pin SHAs in `apm.yml` to
   versions you've vetted.
2. **Publish your fork** as your org's standard template (mark the
   "Template repository" checkbox in repo settings).
3. **Curate `apm.yml`** for your org's stack — strip awesome-copilot
   deps you don't use; add your own internal-package deps.
4. **Document overrides** in your fork's `docs/adoption-playbook.md`
   so consumer repos know which files are safe to edit and which
   should stay unmodified.
5. **Use repo rulesets at the org level** to enforce branch protection
   centrally. (Org-level rulesets layer on top of repo-level rulesets.)
6. **Refresh upstream** quarterly: `apm update` against the latest
   awesome-copilot HEAD; review changes; tag a new version of your
   fork.

## Pre-flight checklist

Before you make the first commit on a brand-new derived repo:

- [ ] `<owner>/<repo>` placeholders replaced (workflow or script)
- [ ] Azure subscription + tenant chosen
- [ ] CODEOWNERS team exists (or replace `<owner>/<team>` with users)
- [ ] Branch protection: evaluate-mode imported (rulesets)
- [ ] GHAS settings reviewed (free tier covers everything in baseline
      for public repos; private repos need GHAS for CodeQL)
- [ ] One sample PR opened to confirm every required check runs

For the GitHub repo settings list see
[`repo-settings-checklist.md`](./repo-settings-checklist.md).
