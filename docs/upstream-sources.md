# Upstream sources

Provenance for every external dependency declared in `apm.yml`. Refresh
this table whenever `apm-update.yml` opens a refresh PR.

## Last verified

- **Date:** 2026-05-08 (matches `apm.lock.yaml` `generated_at`)
- **APM CLI version:** `0.12.4` (pinned in `apm-policy.yml`)
- **Awesome-copilot HEAD:** `6d676fa6fe7df117e6ec11f96330ae277a1bbd71`

## Awesome-copilot deps (7)

All 7 deps come from a single upstream repo at the same pinned commit.
**License:** MIT (see
[`github/awesome-copilot/LICENSE`](https://github.com/github/awesome-copilot/blob/main/LICENSE)).

| Path in `apm.yml` | Type | Lands at |
|-------------------|------|----------|
| `github/awesome-copilot/instructions/code-review-generic.instructions.md` | Instructions | `.github/instructions/code-review-generic.instructions.md` |
| `github/awesome-copilot/instructions/security-and-owasp.instructions.md` | Instructions | `.github/instructions/security-and-owasp.instructions.md` |
| `github/awesome-copilot/instructions/containerization-docker-best-practices.instructions.md` | Instructions | `.github/instructions/containerization-docker-best-practices.instructions.md` |
| `github/awesome-copilot/instructions/github-actions-ci-cd-best-practices.instructions.md` | Instructions | `.github/instructions/github-actions-ci-cd-best-practices.instructions.md` |
| `github/awesome-copilot/instructions/azure-naming.instructions.md` | Instructions | `.github/instructions/azure-naming.instructions.md` |
| `github/awesome-copilot/instructions/terraform.instructions.md` | Instructions | `.github/instructions/terraform.instructions.md` |
| `github/awesome-copilot/skills/review-and-refactor` | Skill | `.github/skills/review-and-refactor/` |

Why these 7? Because they're the smallest set that demonstrates the APM
flow end-to-end while covering the stack the baseline ships:

- `code-review-generic` + `security-and-owasp` — language-agnostic
  baseline guidance any reviewer (human or agent) should apply
- `containerization-docker-best-practices` — Dockerfile hardening for
  `app/Dockerfile`
- `github-actions-ci-cd-best-practices` — keeps the ~10 workflows in
  `.github/workflows/` honest
- `azure-naming` + `terraform` — pair perfectly with the
  hand-authored `infra-terraform.instructions.md`
- `review-and-refactor` — a multi-step skill demo, paired with our
  hand-authored `oidc-rotation` skill

## MCP servers (3)

| Registry name | Transport | Source | Lands at |
|---------------|-----------|--------|----------|
| `io.github.github/github-mcp-server` | http | [`github/github-mcp-server`](https://github.com/github/github-mcp-server) (Apache-2.0) | `.vscode/mcp.json` + `.github/mcp/mcp.json` |
| `microsoftdocs/mcp` | http | [`microsoftdocs/mcp`](https://github.com/microsoftdocs/mcp) (MIT) | Same |
| `com.microsoft/azure` | stdio | [`Azure/azure-mcp`](https://github.com/Azure/azure-mcp) (MIT) | Same |

`Microsoft Learn MCP` was flagged UNVERIFIED in Spike A §9.1 — verify
the registry name is still resolvable before relying on it in prod.

## License compatibility

| Their license | Our use | Notes |
|---------------|---------|-------|
| MIT (awesome-copilot) | Bundled into `.github/instructions/` and `.github/skills/` | Attribution lives in this file and in each file's APM header. |
| MIT (Microsoft Learn MCP) | Referenced as MCP server, no source bundling | |
| Apache-2.0 (GitHub MCP) | Referenced as MCP server, no source bundling | |
| MIT (Azure MCP) | Referenced as MCP server, stdio launches official binary | |

This repo is licensed MIT (see [`LICENSE`](../LICENSE)). All declared
upstreams are MIT or Apache-2.0 — no copyleft conflicts.

## Refreshing the lockfile

Two paths:

### Automatic (preferred)

`.github/workflows/apm-update.yml` runs weekly and on
`workflow_dispatch`. It runs `apm update`, regenerates `apm.lock.yaml`
and any drifted managed files, and opens a PR titled
`chore(deps): refresh apm.lock`. Reviewer reads the upstream changelog
excerpt in the PR body, decides, merges.

### Manual

```bash
apm update                                    # bumps to latest matching apm.yml constraints
apm install                                   # regenerates managed files + lockfile
apm audit --policy ./apm-policy.yml           # verify no policy violations
git add apm.lock.yaml .github/instructions .github/skills
git commit -s -m "chore(deps): refresh apm.lock to upstream <sha>"
```

After either path, **update the "Last verified" date and HEAD SHA at
the top of this file**. The audit gate doesn't enforce that, but PR
reviewers should call it out when missing.
