# Docs catalog — enterprise governance overlay

**Owner:** Enterprise Platform / Governance Team
**Status:** Active
**Last verified:** 2026-08-09

This is the maintained catalog of documentation in this overlay. For the
top-level map, see [AGENTS.md](../AGENTS.md).

## Architecture and data flow

| Document | What it covers |
|---|---|
| [architecture/overview.md](architecture/overview.md) | Architecture, data flow, precedence diagram, client scope |
| [architecture/mcp-threat-model.md](architecture/mcp-threat-model.md) | MCP security threat model |

## Runbooks

| Document | When to use |
|---|---|
| [runbooks/rollout.md](runbooks/rollout.md) | Rolling out managed settings changes |
| [runbooks/incident-rollback.md](runbooks/incident-rollback.md) | Incident response and settings rollback |
| [runbooks/mdm-fallback.md](runbooks/mdm-fallback.md) | MDM policy and file-based fallback procedures |

## Reference

| Document | What it covers |
|---|---|
| [reference/settings-reference.md](reference/settings-reference.md) | All settings keys cross-linked to JSONC annotations |
| [reference/plugin-agent-lifecycle.md](reference/plugin-agent-lifecycle.md) | Plugin and agent lifecycle: add, update, remove |
| [reference/team-override-model.md](reference/team-override-model.md) | Team policy override merge model |
| [reference/verification-checklist.md](reference/verification-checklist.md) | Verification evidence checklist |
| [reference/client-support-matrix.md](reference/client-support-matrix.md) | Dated client capability matrix |

## Maintenance

- Update this catalog when adding or removing maintained docs.
- Mark deprecated docs with `**Status:** Deprecated` and link to the replacement.
- Historical spike documents are evidence, not active truth — do not link them here.
