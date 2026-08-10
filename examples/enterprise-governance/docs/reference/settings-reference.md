# Settings reference

**Owner:** Enterprise AI Governance
**Status:** Active
**Last verified:** 2026-08-09

The canonical reference is the adjacent documentation in
[`copilot/managed-settings.source.jsonc`](../../copilot/managed-settings.source.jsonc).
GitHub consumes only the generated strict JSON.

| Key | Shape | Supported clients | Baseline |
| --- | --- | --- | --- |
| `permissions.disableBypassPermissionsMode` | string | CLI, VS Code, Copilot app | `"disable"` and non-overridable |
| `permissions.model` | `{ "overridable": "auto" }` | All four clients | Auto for new conversations |
| `enabledPlugins` | `PLUGIN@MARKETPLACE` boolean map | All four clients | standards plugin required |
| `extraKnownMarketplaces` | named source map | All four clients | governance + two official pinned marketplaces |
| `strictKnownMarketplaces` | source array | All four clients | only the three exact pinned sources |
| `telemetry` | object | CLI, VS Code | disabled; content capture false/locked; headers empty |
| `remoteControl` | `{ mode, githubDotComOrganizations }` | CLI, VS Code, Copilot app | `requireSSO` for configured org |
| `allowedMcpServers` | `{ "overridable": matcher[] }` | CLI, VS Code, Copilot app | exact Learn/internal/Azure MCP entries |
| `deniedMcpServers` | matcher array | CLI, VS Code, Copilot app | exact mutable Azure MCP command denied |
| `sandbox` | full restriction object | CLI only | required/no bypass; MCP+LSP sandboxed |

## Telemetry subkeys

The complete supported inventory is `enabled`, `endpoint`, `protocol`,
`captureContent`, `lockCaptureContent`, `serviceName`, `resourceAttributes`,
and `headers`. Protocol is `http/protobuf` or `http/json`. The committed
baseline has no token or authorization header.

## Remote-control subkeys

`mode` is `requireSSO`; `githubDotComOrganizations` contains the exact rendered
organization. This restricts control of sessions hosted on the device and does
not affect the user's ability to control their sessions hosted elsewhere.

## MCP matcher fields

Each entry contains exactly one matcher:

| Matcher | Meaning | Baseline rule |
| --- | --- | --- |
| `serverUrl` | Remote HTTP/SSE server URL | Exact HTTPS only; no wildcard |
| `serverCommand` | Exact local executable and argument array | Every package/version pinned |
| `serverName` | User-assigned label | Forbidden because users can rename it |

Deny overrides allow. All active source allowlists intersect; denylists union.
Built-in first-party GitHub cloud MCP cannot be denied.

## Sandbox subkeys

The source documents every supported key: `enabled`, `allowBypass`,
`addCurrentWorkingDirectory`, `sandboxMcpServers`, `sandboxLspServers`,
`gitAuth`, `ghAuth`, `allowDevToolAccess`,
`userPolicy.filesystem.{readwritePaths,readonlyPaths,deniedPaths}`,
`userPolicy.network.{allowOutbound,allowLocalNetwork}`, and
`userPolicy.seatbelt.keychainAccess`.

Force-on settings use `true` to require a restriction. Capability settings use
`false` to prohibit a capability; `true` leaves user behavior available.
Portable path arrays are empty because managed grants require exact absolute
path strings. Device policy can add platform-specific absolute paths.

See the official
[enterprise managed settings reference](https://docs.github.com/en/copilot/reference/enterprise-administrators/enterprise-managed-settings).
