# APM ownership model

**Owner:** Developer experience
**Status:** Active
**Last verified:** 2026-08-09

APM is a narrow supplementary layer. The repository's canonical map and
hand-authored primitives remain directly reviewable without APM.

## Ownership

| Path | Owner | Update path |
| --- | --- | --- |
| `AGENTS.md`, `.github/copilot-instructions.md` | Repository | Edit directly; never run `apm compile` here |
| `.github/instructions/{app-nodejs,infra-terraform,showcase-ui,security,review}.instructions.md` | Repository | Edit directly |
| `.github/instructions/{azure-naming,containerization-docker-best-practices,github-actions-ci-cd-best-practices,terraform}.instructions.md` | APM | Change `apm.yml`, run install, commit output |
| `.github/agents/`, `.github/prompts/`, `.github/hooks/`, `.github/mcp/` | Repository | Edit directly |
| `.github/skills/oidc-rotation/` | Repository | Edit directly |
| `.agents/skills/review-and-refactor/` | APM | Change `apm.yml`, run install, commit output |
| `apm.yml`, `apm-policy.yml` | Repository | Edit directly with review |
| `apm.lock.yaml` | APM | Regenerate; never hand-edit |

The oversized always-on generic review and OWASP packages were removed. Their
repository-specific invariants now live in concise path-scoped files with deep
standards under `docs/standards/`.

## Supported update sequence

```bash
apm install --target copilot
apm install --frozen --target copilot
apm audit --ci --policy ./apm-policy.yml
npm --prefix tools/harness run validate
```

The first command may update lock/deployed files and must be reviewed. Frozen
install and audit must produce no drift. `apm compile -t copilot` is not part of
this repository's workflow because it would replace the hand-authored bridge.

## Unmanaged files

`apm-policy.yml` intentionally sets `unmanaged_files.action: warn`. Hand-authored
files coexist in governed directories, and warnings keep that boundary visible.
`tools/harness` separately verifies that every APM `deployed_file` exists and
that removed oversized packages do not reappear.

## MCP boundary

APM no longer declares MCP servers. Cloud and editor MCP settings have different
schemas and trust models, so their reviewed references remain hand-authored at
`.github/mcp/mcp.json` and `.vscode/mcp.json`.
