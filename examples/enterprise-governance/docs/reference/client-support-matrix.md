# Client support matrix

**Owner:** Enterprise Platform / Governance Team
**Status:** Active
**Last verified:** 2026-08-09

This matrix documents which managed-settings keys are supported by each
Copilot client as of the verification date above. Update after each major
Copilot release or when official docs are updated.

**Source:** https://docs.github.com/en/enterprise-cloud@latest/copilot/managing-copilot

---

## Enforcement mode

| Feature | CLI | VS Code | Copilot app (web) | Cloud agent |
|---|---|---|---|---|
| Managed settings applied | ✓ GA | ✓ GA | ✓ GA | ✓ (subset) |
| MDM override | ✓ | ✓ | ✗ | ✗ |
| File fallback | ✓ | ✓ | ✗ | ✗ |

---

## permissions

| Key | CLI | VS Code | App | Cloud agent |
|---|---|---|---|---|
| `disableBypassPermissionsMode` | ✓ GA | ✓ GA | ✓ GA | ✓ GA |
| `model` | ✓ GA | ✓ GA | ✓ GA | ✗ (separate) |

---

## enabledPlugins / marketplace

| Key | CLI | VS Code | App | Cloud agent |
|---|---|---|---|---|
| `enabledPlugins` | ✓ GA | ✓ GA | ✓ GA | ✗ |
| `extraKnownMarketplaces` | ✓ GA | ✓ GA | ✓ GA | ✗ |
| `strictKnownMarketplaces` | ✓ GA | ✓ GA | ✓ GA | ✗ |

---

## telemetry

| Key | CLI | VS Code | App | Cloud agent |
|---|---|---|---|---|
| `telemetry.enabled` | ✓ GA | ✓ GA | ✗ | ✗ |
| `telemetry.endpoint` | ✓ GA | ✓ GA | ✗ | ✗ |
| `telemetry.endpointToken` | ✓ GA | ✓ GA | ✗ | ✗ |
| `telemetry.protocol` | ✓ GA | ✓ GA | ✗ | ✗ |
| `telemetry.captureContent` | ✓ GA | ✓ GA | ✗ | ✗ |
| `telemetry.lockCaptureContent` | ✓ GA | ✓ GA | ✗ | ✗ |
| `telemetry.serviceName` | ✓ GA | ✓ GA | ✗ | ✗ |
| `telemetry.resourceAttributes` | ✓ GA | ✓ GA | ✗ | ✗ |
| `telemetry.headers` | ✓ GA | ✓ GA | ✗ | ✗ |

---

## remoteControl

| Key | CLI | VS Code | App | Cloud agent |
|---|---|---|---|---|
| `remoteControl.requireSSO` | ✓ GA | ✓ GA | ✗ | ✗ |

---

## allowedMcpServers / deniedMcpServers

| Key | CLI | VS Code | App | Cloud agent |
|---|---|---|---|---|
| `allowedMcpServers` | ✓ GA | ✓ GA | ✓ GA | ✗ (separate) |
| `deniedMcpServers` | ✓ GA | ✓ GA | ✓ GA | ✗ |

Cloud agent third-party MCP: controlled via Enterprise → AI Controls (UI).
Cloud agent custom MCP: controlled via repository Copilot settings.
First-party GitHub MCP: always available on cloud agent; not affected by deny lists.

---

## sandbox

| Key | CLI | VS Code | App | Cloud agent |
|---|---|---|---|---|
| `sandbox.enabled` | ✓ GA (macOS/Linux) | Partial | ✗ | ✗ |
| `sandbox.allowBypass` | ✓ GA | Partial | ✗ | ✗ |
| `sandbox.addCurrentWorkingDirectory` | ✓ GA | ✓ GA | ✗ | ✗ |
| `sandbox.sandboxMcpServers` | ✓ GA | Partial | ✗ | ✗ |
| `sandbox.sandboxLspServers` | ✓ GA | Partial | ✗ | ✗ |
| `sandbox.gitAuth` | ✓ GA | ✓ GA | ✗ | ✗ |
| `sandbox.ghAuth` | ✓ GA | ✓ GA | ✗ | ✗ |
| `sandbox.allowDevToolAccess` | ✓ GA | ✗ | ✗ | ✗ |
| `sandbox.userPolicy.filesystem.*` | ✓ GA | Partial | ✗ | ✗ |
| `sandbox.userPolicy.network.*` | ✓ GA | ✗ | ✗ | ✗ |
| `sandbox.userPolicy.seatbelt.keychainAccess` | ✓ GA (macOS) | ✗ | ✗ | ✗ |

**Partial:** VS Code supports the key but may not apply all restrictions
equivalently to CLI. Verify on your VS Code version before relying on it.

---

## Notes

- **GA**: Generally available as of 2026-08-09.
- **Preview**: in preview — may change without notice.
- **✗**: not supported on this client.
- Cloud agent bypass controls (e.g. `allowBypass`) do not apply — the cloud
  agent runs in GitHub's isolated infrastructure.
- Verify against official docs before making compliance decisions:
  https://docs.github.com/en/enterprise-cloud@latest/copilot

## Copilot Business vs Enterprise caveat

Some features (notably `sandbox.*` and `telemetry.*`) are available only on
**Copilot Enterprise** plans. Copilot Business users may see these keys
ignored or not applied. Verify feature availability with your GitHub account
team for your specific plan tier.
