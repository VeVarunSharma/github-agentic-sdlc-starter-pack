# Upstream sources

**Owner:** Supply chain owners
**Status:** Active
**Last verified:** 2026-08-09

- **APM CLI:** `0.28.0`, installed by checksum-verified
  [`../scripts/install-apm.sh`](../scripts/install-apm.sh)
- **Awesome Copilot pin:** `ab7544d03d4c49fdd07f5958e1888ad39c4118e2`
- **Azure MCP editor pin:** `@azure/mcp@3.0.0-beta.33`

## APM dependencies (5)

All APM dependencies are pinned to the same `github/awesome-copilot` commit.

| Source | Type | Deployed path |
| --- | --- | --- |
| `instructions/azure-naming.instructions.md` | Narrow instruction | `.github/instructions/azure-naming.instructions.md` |
| `instructions/containerization-docker-best-practices.instructions.md` | Narrow instruction | `.github/instructions/containerization-docker-best-practices.instructions.md` |
| `instructions/github-actions-ci-cd-best-practices.instructions.md` | Narrow instruction | `.github/instructions/github-actions-ci-cd-best-practices.instructions.md` |
| `instructions/terraform.instructions.md` | Narrow instruction | `.github/instructions/terraform.instructions.md` |
| `skills/review-and-refactor` | Skill | `.agents/skills/review-and-refactor/` |

The upstream license is MIT. Deployed files and hashes are recorded in
`apm.lock.yaml`.

## MCP provenance

MCP is not APM-managed:

- Microsoft Learn remote MCP uses the verified
  `https://learn.microsoft.com/api/mcp` endpoint with an explicit read-only
  cloud allowlist.
- GitHub's read-only repository MCP and localhost-only Playwright MCP are built
  into GitHub cloud agent and are intentionally absent from the reference.
- Editor Azure MCP uses the exact reviewed npm pin above and interactive
  `az login`; Azure is absent from cloud settings until a dedicated
  authenticated read-only identity is configured.

## Refresh

Use [`../scripts/refresh-apm.sh`](../scripts/refresh-apm.sh) or update the commit
pin manually, then run the supported sequence in
[`apm-ownership-model.md`](apm-ownership-model.md). Review the complete deployed
diff and update this document's pin/date in the same PR.
