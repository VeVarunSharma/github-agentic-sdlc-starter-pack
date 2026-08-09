# Client support matrix

**Owner:** Enterprise Platform / Governance Team  
**Status:** Active  
**Last verified:** 2026-08-09 against official reference docs (see Sources below)

This matrix documents which managed-settings keys are supported by each
Copilot client. Update this file when official documentation changes.

**Sources:**
- Reference: <https://docs.github.com/en/copilot/reference/enterprise-administrators/enterprise-managed-settings>
- Deployment/team mappings: <https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-enterprise/manage-agents/configure-enterprise-managed-settings>

**Rollout dates:** Feature availability dates are NOT included in this matrix
because the official reference docs do not attach dated rollout information.
For release dates, consult the [GitHub Changelog](https://github.blog/changelog/)
and label any time-bound claims separately from this reference matrix.

---

## Enforcement mode

| Feature | CLI | VS Code | Copilot app (web) | Cloud agent |
|---|---|---|---|---|
| Managed settings applied | ✓ | ✓ | ✓ | ✓ (subset — per-key table below) |
| MDM override | ✓ | ✓ | ✗ | ✗ |
| File fallback (`~/.config/github-copilot/`) | ✓ | ✓ | ✗ | ✗ |

---

## permissions

| Key | CLI | VS Code | App | Cloud agent | Team overridable |
|---|---|---|---|---|---|
| `disableBypassPermissionsMode` | ✓ | ✓ | ✓ | **✗** | Technically yes; kept non-overridable by this baseline |
| `model` | ✓ | ✓ | ✓ | ✓ | **Yes** — teams may set named model or "unmanaged" |

**Note:** `model` applies to all four clients. `disableBypassPermissionsMode`
does **not** apply to the cloud agent.

---

## enabledPlugins / marketplace

| Key | CLI | VS Code | App | Cloud agent | Team overridable |
|---|---|---|---|---|---|
| `enabledPlugins` | ✓ | ✓ | ✓ | ✓ | **Additive only** (teams can add, not remove) |
| `extraKnownMarketplaces` | ✓ | ✓ | ✓ | ✓ | **Additive only** |
| `strictKnownMarketplaces` | ✓ | ✓ | ✓ | ✓ | **No** — non-overridable floor |

---

## telemetry

Applies to **CLI and VS Code only**. Copilot app and cloud agent telemetry
is controlled separately in Enterprise AI settings — these keys have no effect
on those clients.

| Key | CLI | VS Code | App | Cloud agent | Team overridable |
|---|---|---|---|---|---|
| `telemetry.enabled` | ✓ | ✓ | ✗ | ✗ | **No** |
| `telemetry.endpoint` | ✓ | ✓ | ✗ | ✗ | **No** |
| `telemetry.endpointToken` | ✓ | ✓ | ✗ | ✗ | **No** |
| `telemetry.protocol` | ✓ | ✓ | ✗ | ✗ | **No** |
| `telemetry.captureContent` | ✓ | ✓ | ✗ | ✗ | **No** — security floor |
| `telemetry.lockCaptureContent` | ✓ | ✓ | ✗ | ✗ | **No** — security floor |
| `telemetry.serviceName` | ✓ | ✓ | ✗ | ✗ | **No** |
| `telemetry.resourceAttributes` | ✓ | ✓ | ✗ | ✗ | **No** |
| `telemetry.headers` | ✓ | ✓ | ✗ | ✗ | **No** |

---

## remoteControl

Applies to **CLI, VS Code, and Copilot app**. Not applicable to cloud agent.

| Key | CLI | VS Code | App | Cloud agent | Team overridable |
|---|---|---|---|---|---|
| `remoteControl.requireSSO` | ✓ | ✓ | ✓ | ✗ | **No** |

---

## allowedMcpServers / deniedMcpServers

Applies to **CLI, VS Code, and Copilot app**. Does **not** apply to cloud agent.

| Key | CLI | VS Code | App | Cloud agent | Team overridable |
|---|---|---|---|---|---|
| `allowedMcpServers` | ✓ | ✓ | ✓ | ✗ | **Yes** — additive (teams add; least-restrictive) |
| `deniedMcpServers` | ✓ | ✓ | ✓ | ✗ | **Yes** — additive (more deny = more restrictive) |

**Cloud agent MCP is separate:**
- Third-party MCP → Enterprise AI Controls (UI)
- Custom-agent MCP → repository Copilot settings
- First-party GitHub MCP → always available; exempt from allow/deny lists

**MCP evaluation order:** built-ins always allowed → deny wins (any source)
→ allowlist fail-closed → malformed policy fails safe.

**Entry shape:** each entry must contain exactly **one** of:
- `serverUrl` — remote HTTP/SSE server (prefer; use exact URL prefix)
- `serverCommand` — local stdio server (include `args` to pin version)
- `serverName` — name-only match (**avoid** — too broad for security baseline)

---

## sandbox

Applies to **Copilot CLI ONLY** (macOS Seatbelt + Linux seccomp/namespaces).
VS Code, Copilot app, and cloud agent: sandbox keys have **no effect**.
Cloud agent runs in GitHub's own isolated infrastructure.

| Key | CLI | VS Code | App | Cloud agent | Team overridable |
|---|---|---|---|---|---|
| `sandbox.enabled` | ✓ | ✗ | ✗ | ✗ | **No** — security floor (must be true) |
| `sandbox.allowBypass` | ✓ | ✗ | ✗ | ✗ | **No** — security floor (must be false) |
| `sandbox.addCurrentWorkingDirectory` | ✓ | ✗ | ✗ | ✗ | **No** |
| `sandbox.sandboxMcpServers` | ✓ | ✗ | ✗ | ✗ | **No** |
| `sandbox.sandboxLspServers` | ✓ | ✗ | ✗ | ✗ | **No** |
| `sandbox.gitAuth` | ✓ | ✗ | ✗ | ✗ | **No** — baseline requires true |
| `sandbox.ghAuth` | ✓ | ✗ | ✗ | ✗ | **No** — baseline requires true |
| `sandbox.allowDevToolAccess` | ✓ | ✗ | ✗ | ✗ | **No** |
| `sandbox.userPolicy.filesystem.*` | ✓ | ✗ | ✗ | ✗ | **No** |
| `sandbox.userPolicy.network.*` | ✓ | ✗ | ✗ | ✗ | **No** |
| `sandbox.userPolicy.seatbelt.keychainAccess` | ✓ (macOS) | ✗ | ✗ | ✗ | **No** |

**Note:** The cloud agent and bypass controls are independent. Cloud agent
bypass controls do not apply; it runs under GitHub's infrastructure controls.

---

## Notes

- **✓**: Key is read and applied on this client.
- **✗**: Key has no effect on this client.
- **Non-overridable**: team settings files must not contain this key.
- **Additive**: teams may add entries but not remove enterprise-level entries.

## Copilot Business vs Enterprise caveat

`sandbox.*` and `telemetry.*` require **Copilot Enterprise**. On Copilot Business
these keys may be ignored. Verify feature availability with your GitHub account
team before relying on these controls for compliance purposes.

## Centralized controls not in managed-settings

The following are **not** controlled by `copilot/managed-settings.json`:
- Cloud agent third-party MCP → Enterprise AI Controls (UI, REST, preview API)
- Cloud agent custom MCP → repository Copilot settings
- Copilot seat assignment → Organization settings → Copilot
- Policy for public code suggestions → Organization settings → Copilot
- Cloud agent repository access → Organization settings → Copilot
