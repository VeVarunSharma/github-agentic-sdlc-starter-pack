# Agent customization tour

**Owner:** Developer experience
**Status:** Active
**Last verified:** 2026-08-09

Root [`AGENTS.md`](../AGENTS.md) is the canonical map. `.github/` contains
adapters and task-specific primitives; it is not a duplicate project manual.
Centralized enterprise policy is a separate repository tier represented by the
copy-ready [`examples/enterprise-governance/`](../examples/enterprise-governance/)
overlay.

## Map

```text
.github/
├── copilot-instructions.md   # short bridge to ../AGENTS.md
├── instructions/             # narrow applyTo invariants
├── agents/                   # current portable *.agent.md profiles
├── prompts/                  # VS Code extension-host slash commands
├── skills/                   # repository playbooks
├── hooks/                    # Copilot CLI/cloud lifecycle hooks
├── mcp/mcp.json              # reviewed cloud settings reference
├── workflows/                # CI, security, docs, and deployment gates
├── ISSUE_TEMPLATE/           # spec/bug/feature forms
└── rulesets/                 # branch protection as code
```

## Primitive selection

| Need | Surface | Portability |
| --- | --- | --- |
| Repository map/invariants | `AGENTS.md` | Native across supported agent clients |
| Path-specific rule | `*.instructions.md` | GitHub/CLI/VS Code where supported |
| Reusable persona | `*.agent.md` | GitHub, CLI, VS Code, Agent Host |
| One-off slash command | `*.prompt.md` | VS Code extension host only |
| Deterministic playbook | skill directory | Preferred portable workflow |
| Lifecycle enforcement | hook v1 JSON + scripts | CLI/cloud; VS Code compatibility differs |
| External tools | MCP config | Configuration/discovery is client-specific |

`.chatmode.md` is obsolete for this showcase. The SDLC planner now lives at
[`../.github/agents/sdlc-planner.agent.md`](../.github/agents/sdlc-planner.agent.md).

## What ships

- **Instructions:** concise app, UI, infra, security, and review invariants plus
  four narrow APM-managed references for Docker, Actions, Azure naming, and
  Terraform.
- **Agents:** manually selected read-only SDLC planner and PR reviewer, plus a
  docs gardener that runs deterministic checks and proposes fixes.
- **Prompts:** Terraform scaffolding and security review examples. Both state
  that Agent Host/cloud do not load prompt files and point to portable sources.
- **Skills:** hand-authored OIDC rotation and the pinned APM
  `review-and-refactor` skill.
- **Hooks:** [`harness-validation.json`](../.github/hooks/harness-validation.json)
  uses the GitHub v1 lifecycle schema and safe Bash/PowerShell adapters. It is
  not a Git pre-commit hook.
- **MCP:** the cloud reference contains only Microsoft Learn with a read-only
  allowlist. GitHub and localhost Playwright are built in. The VS Code config
  adds an exact-version Azure MCP and requires `az login`.

## Discovery is not universal

See [`agent-support-matrix.md`](agent-support-matrix.md). In particular:

- repository cloud MCP JSON must be entered under repository **Copilot -> MCP
  servers** settings and is shared with code review;
- custom MCP tools can run autonomously, so allowlists are mandatory;
- VS Code handoffs are ignored by GitHub;
- VS Code prompt files are not loaded by Agent Host;
- editor `.vscode/mcp.json` and cloud MCP settings are separate contracts.

## Extending safely

1. Add or change the smallest appropriate primitive.
2. Link to active docs rather than duplicating a contract.
3. Update [`README.md`](README.md) when adding a maintained doc.
4. Run `npm --prefix ../tools/harness run validate`.
5. If APM owns the file, change [`../apm.yml`](../apm.yml) and regenerate it;
   never hand-edit the deployed copy.

## Centralized enterprise tier

Repository-local primitives remain reviewable examples and per-repository
context. Enterprise administrators can copy
[`examples/enterprise-governance/`](../examples/enterprise-governance/) to a
selected organization `.github-private` repository for server-managed settings,
team mappings, enterprise plugins, and enterprise agents. The overlay keeps
annotated JSONC canonical and commits generated strict JSON because GitHub does
not consume comments. Selection and AI Controls remain administrator actions;
files in this starter do not enforce enterprise policy by themselves.
