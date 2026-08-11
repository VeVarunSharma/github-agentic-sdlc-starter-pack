# MCP threat model

**Owner:** Enterprise Platform / Governance Team
**Status:** Active
**Last verified:** 2026-08-09

---

## Scope

This document covers the security threat model for Model Context Protocol
(MCP) server usage by Copilot clients in the enterprise environment.
It addresses threats to the `allowedMcpServers` / `deniedMcpServers` controls
in managed settings and to the sandbox configuration that isolates MCP servers.

---

## Trust boundaries

```
┌──────────────────────────────────────────────────────────────────┐
│  User workstation                                                │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Copilot CLI sandbox (enabled=true, allowBypass=false)  │   │
│  │  ┌─────────────────┐    ┌─────────────────────────────┐ │   │
│  │  │  Copilot agent  │───▶│  MCP server (sandboxed)    │ │   │
│  │  └─────────────────┘    │  • Filesystem: per policy  │ │   │
│  │                         │  • Network: allowOutbound  │ │   │
│  │                         │  • No localhost (default)  │ │   │
│  │                         └─────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                │ HTTPS only                      │
│                                ▼                                 │
│       allowedMcpServers list (managed-settings.json)             │
└──────────────────────────────────────────────────────────────────┘
```

---

## Threat catalog

### T1: Rogue MCP server via marketplace

**Threat:** A malicious actor publishes an MCP server to a public marketplace
and tricks users into enabling it.

**Mitigation:**
- `strictKnownMarketplaces` lists only exact pinned sources, restricting plugin resolution.
- `allowedMcpServers` is an explicit allowlist — unknown URLs are blocked.
- Internal marketplace only (via `extraKnownMarketplaces`).

**Residual risk:** Low — mitigated by both controls.

---

### T2: Server-side request forgery (SSRF) via MCP tool

**Threat:** An MCP server calls internal services using the agent's network
context, proxying requests to RFC-1918 or loopback addresses.

**Mitigation:**
- `sandbox.userPolicy.network.allowLocalNetwork: false` blocks loopback and
  RFC-1918 egress from MCP servers.
- MCP servers are sandboxed (`sandboxMcpServers: true`).

**Residual risk:** Medium — outbound HTTPS is still permitted (required for
legitimate MCP functionality). Monitor egress with network observability.

---

### T3: Filesystem exfiltration via MCP tool

**Threat:** An MCP server reads sensitive files (SSH keys, credentials) and
exfiltrates them via outbound connections.

**Mitigation:**
- `sandbox.userPolicy.filesystem.deniedPaths` blocks `~/.ssh`,
  `~/.git-credentials`, `~/.gnupg`.
- `sandbox.userPolicy.seatbelt.keychainAccess: false` (macOS) blocks Keychain.
- `addCurrentWorkingDirectory: true` limits write scope to repo root.

**Residual risk:** Low — denied paths cover primary credential locations.
Custom credential locations (e.g. custom SSH agent sockets) are not covered;
teams with non-standard configs should add paths to `deniedPaths`.

---

### T4: Supply-chain attack via pinned MCP server package

**Threat:** A pinned npm package for a local stdio MCP server is compromised
in a later minor/patch version.

**Mitigation:**
- Pin to exact package version (e.g. `@github/mcp-docs-server@0.1.4`), not
  `@latest`.
- The validator rejects `@latest` in allowlists and requires the exact mutable
  Azure MCP `@latest` variant to remain in the denylist.
- Review package updates via Dependabot or manual audit before pin updates.

**Residual risk:** Medium — pinning reduces risk but does not eliminate it;
the pinned version itself may be compromised if the publisher's npm account
is compromised.

---

### T5: Prompt injection via MCP tool output

**Threat:** An MCP server returns malicious content that injects instructions
into the agent's context, causing it to exfiltrate data or take unauthorized
actions.

**Mitigation:**
- Only allowlisted MCP servers may connect.
- Internal marketplace vets all approved servers.
- Agents in this overlay use read-only or explicit-confirm patterns.
- Sandbox limits blast radius of any successful injection.

**Residual risk:** Medium — prompt injection cannot be fully mitigated by
infrastructure controls alone. Agents must be designed defensively.

---

### T6: Cloud agent MCP bypass (separate surface)

**Threat:** `allowedMcpServers`/`deniedMcpServers` are bypassed by using the
cloud agent, which has a separate MCP control surface.

**Mitigation (documented, not file-enforced):**
- Cloud agent third-party MCP is controlled in Enterprise → AI Controls (UI).
- Repository custom-agent MCP allowlists are set in repository Copilot settings.
- First-party GitHub MCP is always available; this is expected and reviewed.

**Residual risk:** Medium — cloud agent MCP controls are UI-only and not
enforced by this overlay. Organizations must configure AI Controls separately.
See [`docs/architecture/overview.md`](overview.md) for details.

---

## Security controls summary

| Control | Setting | Threat addressed |
|---|---|---|
| MCP allowlist | `allowedMcpServers` | T1, T5 |
| MCP denylist | `deniedMcpServers` | T1, T5 |
| Strict marketplaces | Exact pinned `strictKnownMarketplaces` source array | T1 |
| Sandbox isolation | `sandbox.enabled: true` | T2, T3, T5 |
| No local network | `allowLocalNetwork: false` | T2 |
| Filesystem deny | `deniedPaths` | T3 |
| No Keychain | `keychainAccess: false` | T3 |
| Pinned package versions | Renderer validation | T4 |
| No sandbox bypass | `allowBypass: false` | T2, T3, T5 |

---

## Monitoring

Enable telemetry (`telemetry.enabled: true`) for pilot teams to monitor:
- MCP tool call frequency and latency
- Model selection distribution
- Error rates by tool

See `docs/runbooks/incident-rollback.md` for response procedures if anomalous
MCP activity is detected.
