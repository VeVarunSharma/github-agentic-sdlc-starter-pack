# Client support matrix

**Owner:** Enterprise Platform / Governance Team  
**Status:** Active  
**Last verified:** 2026-08-09 against official reference docs (see Sources below)

This matrix documents which managed-settings keys are supported by each
Copilot client. Update this file when official documentation changes.

**Sources:**
- Reference: <https://docs.github.com/en/copilot/reference/enterprise-administrators/enterprise-managed-settings>
- Deployment/team mappings: <https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-enterprise/manage-agents/configure-enterprise-managed-settings>

**Rollout history (labeled separately from reference docs — see [GitHub Changelog](https://github.blog/changelog/)):**

| Date | Event | Link |
|---|---|---|
| 2026-07-27 | Plugin, marketplace, and model controls extended to Copilot app and cloud agent | [Changelog](https://github.blog/changelog/2026-07-27-enterprise-managed-settings-now-apply-to-the-github-copilot-app) |
| 2026-08-03 | Team specialization (team overrides) released | [Changelog](https://github.blog/changelog/2026-08-03-enterprise-team-specialization-for-managed-settings) |
| 2026-08-06 | MCP allowlists in enterprise managed settings GA | [Changelog](https://github.blog/changelog/2026-08-06-mcp-allowlists-in-enterprise-managed-settings) |
| 2026-08-07 | Code quality automation no longer auto-adds Copilot as PR reviewer (reversal) | [Changelog](https://github.blog/changelog/2026-08-07-github-code-quality-no-longer-adds-copilot-as-a-reviewer) |
| 2026-08-07 | Copilot code review effort levels GA | [Changelog](https://github.blog/changelog/2026-08-07-copilot-code-review-effort-levels-are-generally-available) |

The reference docs above are the authoritative per-key source; changelog entries
document rollout dates and are labeled separately.

---

## Enforcement mode

| Feature | CLI | VS Code | Copilot app (web) | Cloud agent |
|---|---|---|---|---|
| Managed settings applied | ✓ | ✓ | ✓ | ✓ (subset — per-key table below) |
| MDM override | ✓ | ✓ | ✗ | ✗ |
| Platform managed-settings file | ✓ | ✓ | ✗ | ✗ |

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
| `remoteControl.mode` | ✓ | ✓ | ✓ | ✗ | **No** |
| `remoteControl.githubDotComOrganizations` | ✓ | ✓ | ✓ | ✗ | **No** |

---

## allowedMcpServers / deniedMcpServers

Applies to **CLI, VS Code, and Copilot app**. Does **not** apply to cloud agent.

| Key | CLI | VS Code | App | Cloud agent | Team overridable |
|---|---|---|---|---|---|
| `allowedMcpServers` | ✓ | ✓ | ✓ | ✗ | **Yes** when wrapped; team value replaces the default and multi-team values combine least-restrictively |
| `deniedMcpServers` | ✓ | ✓ | ✓ | ✗ | **Yes** only when wrapped; this baseline keeps it non-overridable |

**Note:** Bypass prompts (interactive bypass requests) surface **only** in the Copilot app,
CLI, and VS Code — clients where the user is present. The cloud agent does not
receive bypass prompts; any change to managed settings applies at the start of
the cloud agent's **next task** (not in-flight).

**MCP allowlist notes (changelog 2026-08-06):** MCP allowlists are fail-closed — if
an allowlist is configured, a server must match it to be allowed. The policy is
evaluated at every layer (enterprise + all active team layers). `serverName` is
documented as a convenience matcher for well-known servers, **not a security
boundary** — prefer `serverUrl` or `serverCommand` for security baselines.

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

See the dedicated [`copilot-business.md`](copilot-business.md) caveat. The key
issue is the Enterprise license needed to create/select an organization
`.github-private` source in a dedicated Business enterprise, not a blanket claim
that sandbox or telemetry keys are unsupported.

## Centralized controls not in managed-settings

See [`centralized-controls.md`](centralized-controls.md) for the maintained
UI/REST/GA/preview inventory.

---

## MCP entry shape reference

Each entry in `allowedMcpServers`/`deniedMcpServers` must contain exactly **one**
matcher field:

| Field | Scope | Security recommendation |
|---|---|---|
| `serverUrl` | Matches remote HTTP/SSE servers by URL prefix | **Preferred for remote servers** — use exact HTTPS URL |
| `serverCommand` | Matches the exact local stdio executable and argument array | **Preferred for local servers** — pin every package/version in the array |
| `serverName` | Name-only match for well-known servers | Convenience, **not a security boundary** — avoid in security baselines (Aug 6 changelog) |

**Cloud agent MCP (separate):**
- Third-party MCP → Enterprise → AI Controls (UI)
- Custom/repository MCP → repository Copilot settings
- First-party GitHub MCP → always available; exempt from allow/deny lists

---

## Copilot automatic review

Copilot can be configured as an automatic PR reviewer. This is **separate** from
managed-settings and is controlled per-repository or per-organization.

**Reference:** <https://docs.github.com/en/copilot/how-tos/copilot-on-github/set-up-copilot/configure-automatic-review>

**Three controls:**
1. **Automatic review** — Copilot adds itself as a reviewer when a PR is opened.
2. **Review new pushes** — Copilot re-reviews when new commits are pushed.
3. **Review drafts** — Copilot reviews draft PRs (disabled by default).

**Cost and tradeoffs:**
- Each Copilot review consumes AI credits and may trigger an Actions workflow run.
- Enabling "review new pushes" on active branches can generate many repeated reviews.
- Enabling "review drafts" reviews work-in-progress that may be superseded quickly.
- **Recommendation:** Enable automatic review and optionally review-new-pushes on
  branches with protection rules; disable review-drafts unless the team explicitly
  opts in. Monitor AI credit consumption weekly during rollout.

**Aug 7, 2026 reversal:** The GitHub Code Quality automation that previously added
Copilot as a reviewer automatically was **reverted**. Copilot is no longer
auto-added as a reviewer by code quality features. Configure auto-review
explicitly per the docs above if desired.
([Changelog](https://github.blog/changelog/2026-08-07-github-code-quality-no-longer-adds-copilot-as-a-reviewer))

**Code review effort levels (GA 2026-08-07):** Copilot code review now supports
configurable effort levels, letting reviewers request lighter or deeper analysis.
([Changelog](https://github.blog/changelog/2026-08-07-copilot-code-review-effort-levels-are-generally-available))
