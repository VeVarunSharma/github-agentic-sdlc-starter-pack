# `.github/` tour

A guided tour of every primitive shipped under `.github/`. The repo is
**`.github/`-first**: hand-authored worked examples sit directly in the
folder, with APM-installed deps living alongside them.

For the rules on which files are hand-authored vs APM-managed see
[`apm-ownership-model.md`](./apm-ownership-model.md).

## Map

```
.github/
├── copilot-instructions.md     # Primary agent context (hand-authored, primary)
├── instructions/               # Path-scoped guidance, one file per applyTo glob
├── prompts/                    # Slash-prompt definitions
├── chatmodes/                  # Custom Copilot Chat modes
├── agents/                     # Sub-agent definitions
├── skills/                     # Multi-step playbooks
├── hooks/                      # Behavioural lifecycle hooks
├── mcp/                        # MCP server reference for the cloud agent
├── workflows/                  # CI/CD, security, Copilot setup
├── ISSUE_TEMPLATE/             # Spec / bug / feature issue forms
└── rulesets/                   # Branch protection as code
```

## Which primitive when?

| You want… | Use this primitive | Lives in |
|-----------|--------------------|----------|
| Always-applied guidance | **copilot-instructions.md** | `.github/copilot-instructions.md` |
| Guidance scoped to a file glob | **instruction file** with front-matter `applyTo:` | `.github/instructions/*.instructions.md` |
| A reusable command users invoke explicitly | **prompt** | `.github/prompts/*.prompt.md` |
| A persona / mode for Copilot Chat | **chatmode** | `.github/chatmodes/*.chatmode.md` |
| A reusable sub-agent invoked from another agent | **agent** | `.github/agents/*.agent.md` |
| A multi-step playbook with deterministic steps | **skill** | `.github/skills/<name>/SKILL.md` |
| A behavioural hook on a lifecycle event | **hook** | `.github/hooks/*.json` |
| A tool the cloud agent should have access to | **MCP server** | `.github/mcp/mcp.json` |

Rule of thumb: **hand-author into `.github/` first**; if a primitive
graduates to "every repo should have this", extract it to a published
package and pull it back in via [`apm.yml`](../apm.yml).

## What ships out of the box

### `copilot-instructions.md` (hand-authored, primary)

The single source of truth for project context. GitHub Copilot loads it
automatically on every chat turn and on every coding-agent run.
[`AGENTS.md`](../AGENTS.md) at the root is a slim pointer to this file
so AGENTS.md-aware clients (Claude Code, Cursor, OpenCode, Codex,
Gemini, Windsurf) see the same context.

### `instructions/` (hand-authored + APM)

| File | Owner | What it does |
|------|-------|--------------|
| `app-nodejs.instructions.md` | Hand-authored | `applyTo: "app/**/*.{js,mjs}"` — Node 22 + Express conventions |
| `infra-terraform.instructions.md` | Hand-authored | `applyTo: "infra/**/*.tf"` — Terraform module structure + naming |
| `code-review-generic.instructions.md` | APM | From `github/awesome-copilot` |
| `security-and-owasp.instructions.md` | APM | From `github/awesome-copilot` |
| `containerization-docker-best-practices.instructions.md` | APM | From `github/awesome-copilot` |
| `github-actions-ci-cd-best-practices.instructions.md` | APM | From `github/awesome-copilot` |
| `azure-naming.instructions.md` | APM | From `github/awesome-copilot` |
| `terraform.instructions.md` | APM | From `github/awesome-copilot` |

### `prompts/` (hand-authored)

- `scaffold-tf-module.prompt.md` — interactive scaffold for a new
  Terraform module under `infra/app/modules/`
- `security-review.prompt.md` — guided security review of a PR diff,
  cross-referencing GHAS / OWASP findings

### `chatmodes/` (hand-authored)

- `sdlc-planner.chatmode.md` — Copilot Chat mode that walks the SDLC
  loop (issue → plan → PR → gates → merge → deploy)

### `agents/` (hand-authored)

- `pr-reviewer.agent.md` — sub-agent that reads the path-scoped
  instructions and reviews a diff

### `skills/` (hand-authored + APM)

- `oidc-rotation/` (hand-authored) — guided playbook for rotating
  Azure federated credentials when the repo or environment is renamed
- `review-and-refactor/` (APM) — from `github/awesome-copilot`

### `hooks/` (hand-authored)

- `pre-commit-eslint.json` — runs ESLint on staged JS files. (Hooks are
  Copilot/APM-specific, **not** vanilla git hooks.)

### `mcp/` (hand-authored)

- `mcp.json` — the same three servers as
  [`.vscode/mcp.json`](../.vscode/mcp.json) (GitHub remote MCP, Microsoft
  Learn MCP, Azure MCP), but in a location any client can discover.

### `workflows/`, `ISSUE_TEMPLATE/`, `rulesets/`

Covered separately in
[`agentic-sdlc.md`](./agentic-sdlc.md) and
[`repo-settings-checklist.md`](./repo-settings-checklist.md).

## Where Copilot reads from

- **VS Code Copilot Chat & coding agent** read from
  `.github/copilot-instructions.md`, `.github/instructions/*`,
  `.github/prompts/*`, `.github/chatmodes/*`.
- **GitHub Copilot cloud coding agent** uses the MCP config under
  Settings → Copilot → Cloud agent (paste contents of
  `.github/mcp/mcp.json` there) and the `.github/copilot-instructions.md`
  in the repo it's working in.
- **AGENTS.md-aware clients** read `AGENTS.md` (which points at
  `.github/copilot-instructions.md`).

## Extending — three patterns

1. **Add a hand-authored primitive.** Drop a new file into the right
   `.github/<type>/` subdir with the right front matter. Done — Copilot
   picks it up immediately.
2. **Pull in an awesome-copilot dep via APM.** Add it to `apm.yml` with a
   pinned version, run `apm install`, commit `apm.lock.yaml` and the
   newly downloaded files.
3. **Promote a hand-authored primitive to a package.** Once it stabilises,
   publish it (e.g. as part of an org-internal awesome-copilot fork) and
   pull it back via APM. Consumers across all your repos pick up the
   same version.
