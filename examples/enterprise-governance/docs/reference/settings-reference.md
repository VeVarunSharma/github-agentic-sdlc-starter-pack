# Settings reference

**Owner:** Enterprise Platform / Governance Team
**Status:** Active
**Last verified:** 2026-08-09

Cross-reference from settings keys to annotations in
[`copilot/managed-settings.source.jsonc`](../../copilot/managed-settings.source.jsonc).

---

## How to use this reference

Each key below links to the section in the annotated source. The source file
contains inline comments explaining every key's behavior, clients, security
impact, and precedence. This reference is a quick lookup index.

For the authoritative description, read the comment adjacent to the key in
`managed-settings.source.jsonc`.

---

## Top-level keys

| Key | Type | Clients | Floor | Description |
|---|---|---|---|---|
| `permissions` | object | All | — | Permission enforcement settings |
| `permissions.disableBypassPermissionsMode` | `"disable"` \| `"enable"` | All | `"disable"` | Prevent admin bypass of content controls |
| `permissions.model` | string \| `"Auto"` | CLI, VS Code, App | — | Model selection policy |
| `enabledPlugins` | string[] | CLI, VS Code, App | — | `PLUGIN@MARKETPLACE` identifiers |
| `extraKnownMarketplaces` | object[] | CLI, VS Code, App | — | Additional approved marketplaces |
| `strictKnownMarketplaces` | boolean | CLI, VS Code, App | `true` | Block unknown marketplaces |
| `telemetry` | object | CLI, VS Code | — | OTLP telemetry export settings |
| `telemetry.enabled` | boolean | CLI, VS Code | — | Enable/disable telemetry export |
| `telemetry.endpoint` | string (URL) | CLI, VS Code | — | OTLP receiver URL |
| `telemetry.endpointToken` | string | CLI, VS Code | — | Bearer auth token for OTLP |
| `telemetry.protocol` | string | CLI, VS Code | — | `http/protobuf` or `grpc` |
| `telemetry.captureContent` | boolean | CLI, VS Code | `false` | Include prompts/completions in telemetry |
| `telemetry.lockCaptureContent` | boolean | CLI, VS Code | `true` | Prevent users from changing captureContent |
| `telemetry.serviceName` | string | CLI, VS Code | — | OTel service.name resource attribute |
| `telemetry.resourceAttributes` | object | CLI, VS Code | — | Additional OTel resource attributes |
| `telemetry.headers` | object | CLI, VS Code | — | Additional HTTP headers for OTLP requests |
| `remoteControl` | object | CLI, VS Code | — | Remote control settings |
| `remoteControl.requireSSO` | object | CLI, VS Code | — | Require SSO auth for remote control |
| `remoteControl.requireSSO.organization` | string | CLI, VS Code | — | Org slug for SSO validation |
| `allowedMcpServers` | object[] | CLI, VS Code, App | — | Allowlisted MCP servers |
| `deniedMcpServers` | object[] | CLI, VS Code, App | — | Denylisted MCP servers (overrides allow) |
| `sandbox` | object | CLI (macOS/Linux) | — | Sandbox isolation settings |
| `sandbox.enabled` | boolean | CLI | `true` | Enable sandbox isolation |
| `sandbox.allowBypass` | boolean | CLI | `false` | Allow users to disable sandbox |
| `sandbox.addCurrentWorkingDirectory` | boolean | CLI | — | Auto-add cwd to readwrite paths |
| `sandbox.sandboxMcpServers` | boolean | CLI | `true` | Sandbox MCP servers |
| `sandbox.sandboxLspServers` | boolean | CLI | `true` | Sandbox LSP servers |
| `sandbox.gitAuth` | boolean | CLI | — | Pass through Git auth to sandbox |
| `sandbox.ghAuth` | boolean | CLI | — | Pass through gh CLI auth to sandbox |
| `sandbox.allowDevToolAccess` | boolean | CLI | — | Allow DevTools access in sandbox |
| `sandbox.userPolicy` | object | CLI | — | Filesystem and network policy |
| `sandbox.userPolicy.filesystem.readwritePaths` | string[] | CLI | — | Additive read-write paths |
| `sandbox.userPolicy.filesystem.readonlyPaths` | string[] | CLI | — | Read-only paths |
| `sandbox.userPolicy.filesystem.deniedPaths` | string[] | CLI | — | Denied paths (floor: includes ~/.ssh) |
| `sandbox.userPolicy.network.allowOutbound` | boolean | CLI | — | Allow outbound network connections |
| `sandbox.userPolicy.network.allowLocalNetwork` | boolean | CLI | `false` | Allow loopback/RFC-1918 connections |
| `sandbox.userPolicy.seatbelt.keychainAccess` | boolean | CLI (macOS) | `false` | Allow macOS Keychain access |

---

## MCP server entry fields

| Field | Required | Description |
|---|---|---|
| `url` | url or command required | HTTPS URL prefix for remote servers |
| `command` | url or command required | Executable for local stdio servers |
| `args` | when command present | Arguments for the command |
| `name` | optional | Display name |

---

## Links

- Full annotated source: [`copilot/managed-settings.source.jsonc`](../../copilot/managed-settings.source.jsonc)
- Team overrides: [`copilot/team-mappings.source.jsonc`](../../copilot/team-mappings.source.jsonc)
- Architecture: [`docs/architecture/overview.md`](../architecture/overview.md)
- Official docs: https://docs.github.com/en/enterprise-cloud@latest/copilot/managing-copilot
