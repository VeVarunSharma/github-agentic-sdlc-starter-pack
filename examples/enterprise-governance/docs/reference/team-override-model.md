# Team override model

**Owner:** Enterprise Platform / Governance Team
**Status:** Active
**Last verified:** 2026-08-09

---

## How team overrides work

Team policy overrides in `copilot/team-mappings.json` allow specific GitHub
teams to receive settings that differ from the enterprise baseline.

### Overridable and additive keys

The enterprise marks `permissions.model`, `allowedMcpServers`, and optionally
other supported keys with `{ "overridable": <default> }`. A mapped team file
supplies the value for that key; omission falls back to the enterprise default.
`enabledPlugins` and `extraKnownMarketplaces` are the additive exceptions.

When a user belongs to multiple mapped teams, GitHub combines the team values
least-restrictively and applies them beneath enterprise/platform decisions. The
pioneer MCP policy therefore repeats the three default allow entries before
adding its fourth endpoint.

### Enterprise precedence (floor keys)

Floor keys are the exception. They represent absolute minimums that no team
override can weaken:

| Key | Floor value | Rationale |
|---|---|---|
| `permissions.disableBypassPermissionsMode` | `"disable"` | Admin bypass prevention |
| `sandbox.enabled` | `true` | Mandatory isolation |
| `sandbox.allowBypass` | `false` | No user escape from sandbox |
| `sandbox.sandboxMcpServers` | `true` | MCP stays sandboxed |
| `sandbox.sandboxLspServers` | `true` | LSP stays sandboxed |
| `telemetry.captureContent` | `false` | Prompt confidentiality |
| `telemetry.lockCaptureContent` | `true` | User cannot override captureContent |
| `strictKnownMarketplaces` | exact pinned source array | No rogue marketplace injection |

The renderer and validator both reject team mappings that attempt to set any
floor key to a weaker value.

---

## Adding a team override

1. Open a governance-change issue with the team override as the proposed change.
2. Document the justification for the deviation from the enterprise baseline.
3. Edit `copilot/team-mappings.source.jsonc` with the team entry and inline
   comment explaining the justification.
4. Render (`node scripts/render-managed-settings.mjs`) and validate.
5. PR with CODEOWNER approval. Merge.
6. Verify the team receives the override (check with a team member).

---

## Current team policies

See `copilot/team-mappings.source.jsonc` for annotated policies.

| Team | Model | Extra plugins | Telemetry | Sandbox deviations |
|---|---|---|---|---|
| developers | Auto | None | Disabled | None |
| ai-platform-pioneers | unmanaged | sdlc-pilot-tools | Inherits disabled | None |

---

## Multi-team users

If a user belongs to multiple teams with different override policies:
- GitHub applies all team overrides using least-restrictive merge.
- Example: membership in a less restrictive pioneer policy can make that
  reviewed specialization effective.
- Floor keys still apply to all teams regardless.

---

## Time-bounding overrides

Policy exceptions (especially for pilots) should be time-bounded:
- Document an expiry date in adjacent JSONC comments and the change issue.
- Schedule a governance review issue for the expiry date.
- Remove the override when the justification no longer applies.

The governance gardener agent can flag overrides that have passed their
documented expiry date.
