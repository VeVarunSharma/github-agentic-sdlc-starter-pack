# Architecture and data flow

**Owner:** Enterprise Platform / Governance Team
**Status:** Active
**Last verified:** 2026-08-09

---

## Overview

The enterprise governance overlay centralizes Copilot policy management for all
teams in the organization. Settings flow from this repository through GitHub's
managed-settings infrastructure to every supported Copilot client.

```
┌─────────────────────────────────────────────────────────────┐
│  Governance Repository (.github-private)                    │
│                                                             │
│  copilot/managed-settings.source.jsonc  (edit here)        │
│           │ render-managed-settings.mjs                     │
│           ▼                                                 │
│  copilot/managed-settings.json          (generated, GA)     │
│  copilot/team-mappings.json             (generated, GA)     │
└────────────────────────┬────────────────────────────────────┘
                         │ GitHub reads via managed-settings
                         │ infrastructure (org admin sets source)
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  GitHub Enterprise managed settings infrastructure          │
│  • Merges enterprise settings + team mappings               │
│  • Least-restrictive merge for most keys                    │
│  • Floor keys enforce minimum security (non-overridable)    │
└────────────────────────┬────────────────────────────────────┘
                         │
          ┌──────────────┼──────────────┬──────────────┐
          ▼              ▼              ▼              ▼
    Copilot CLI    VS Code ext     Copilot app   Cloud agent
    (full support) (full support) (full support) (subset — see below)
```

---

## Key concepts

### Managed settings source repository

- GitHub Enterprise reads `copilot/managed-settings.json` from the repository
  configured as the **managed settings source** under Enterprise → Copilot →
  Managed settings.
- Only one repository per organization can be the managed settings source.
- The file must be at exactly `copilot/managed-settings.json` (strict JSON,
  no comments).
- Changes take effect when GitHub's periodic sync picks them up (typically
  within minutes of a push to main).

### Precedence (highest → lowest)

```
1. MDM / device-management profile    (platform-enforced; overrides all)
2. Server managed settings            (this file)
3. File-based user config             (~/.config/github-copilot/settings.json)
4. User in-app preferences
```

MDM is out of scope for this overlay. If your organization uses MDM for device
policy, see [`docs/runbooks/mdm-fallback.md`](../runbooks/mdm-fallback.md).

### Team policy merge

Team policies in `copilot/team-mappings.json` are merged with the enterprise
baseline using a **least-restrictive** rule: if enterprise allows X and team
allows Y, the user gets X ∪ Y (the union). This means:

- Teams can **add** allowed MCP servers or plugins beyond the enterprise list.
- Teams can **enable** telemetry that is disabled at the enterprise level.
- Teams CANNOT **remove** enterprise-level denials or floor settings.

**Floor keys** are absolute minimums enforced by this overlay's renderer and
validator. No team mapping may set them to a weaker value:

| Key | Floor value | Why |
|---|---|---|
| `permissions.disableBypassPermissionsMode` | `"disable"` | Prevents admin bypass of content controls |
| `sandbox.enabled` | `true` | All CLI agent sessions must run sandboxed |
| `sandbox.allowBypass` | `false` | Users cannot escape sandbox |
| `sandbox.sandboxMcpServers` | `true` | MCP servers stay inside sandbox |
| `sandbox.sandboxLspServers` | `true` | LSP servers stay inside sandbox |
| `telemetry.captureContent` | `false` | Protects code/prompt confidentiality |
| `telemetry.lockCaptureContent` | `true` | Users cannot enable content capture |
| `strictKnownMarketplaces` | `true` | Prevents supply-chain via rogue marketplaces |

---

## Client scope

Not all settings apply to all clients. The table below documents effective
scope as of 2026-08-09. See
[`docs/reference/client-support-matrix.md`](../reference/client-support-matrix.md)
for the full dated matrix.

| Setting | CLI | VS Code | Copilot app | Cloud agent |
|---|---|---|---|---|
| permissions | ✓ | ✓ | ✓ | ✓ |
| sandbox | ✓ | Partial | ✗ | ✗ (managed by GitHub infra) |
| telemetry | ✓ | ✓ | ✗ (separate) | ✗ (separate) |
| remoteControl | ✓ | ✓ | ✗ | ✗ |
| allowedMcpServers | ✓ | ✓ | ✓ | ✗ (separate — see below) |
| deniedMcpServers | ✓ | ✓ | ✓ | ✗ |
| enabledPlugins | ✓ | ✓ | ✓ | ✗ |
| strictKnownMarketplaces | ✓ | ✓ | ✓ | ✗ |

### Cloud agent MCP note

Cloud agent MCP is governed separately:
- **Third-party MCP** (non-GitHub): configured in Enterprise → AI Controls.
- **Custom/repository MCP**: allowlisted in repository Copilot settings.
- **First-party GitHub MCP**: always available; exempt from deny lists.
- `allowedMcpServers` and `deniedMcpServers` in managed-settings.json do
  **NOT** apply to the cloud agent.

### Copilot Business enterprise caveat

Copilot Business accounts may not support all managed-settings keys. Some
keys (e.g. sandbox, telemetry) are available only on Copilot Enterprise.
Verify with your GitHub account team before relying on sandbox enforcement
in a Business plan.

---

## Centralized controls NOT in managed-settings

Some enterprise controls are UI-only and cannot be configured via this file:

| Control | Location |
|---|---|
| Cloud agent third-party MCP allow/deny | Enterprise → AI Controls |
| Copilot seat assignments | Org → Settings → Copilot → Access |
| GitHub.com content exclusions | Org → Settings → Copilot → Content exclusion |
| Enterprise audit log | Enterprise → Settings → Audit log |
| SSO/SAML enforcement | Organization → Settings → Authentication security |

These controls must be documented in your organization's policy documentation
and verified separately from this overlay.

---

## Official documentation links

- Managed settings: https://docs.github.com/en/enterprise-cloud@latest/copilot/managing-copilot/managing-github-copilot-in-your-organization/managing-github-copilot-features-in-your-organization/configuring-managed-settings-with-your-github-copilot-plan
- MCP in Copilot: https://docs.github.com/en/copilot/customizing-copilot/using-model-context-protocol-with-github-copilot
- Copilot for Enterprise: https://docs.github.com/en/enterprise-cloud@latest/copilot
