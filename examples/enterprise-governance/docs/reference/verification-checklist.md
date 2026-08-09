# Verification checklist and evidence

**Owner:** Enterprise Platform / Governance Team
**Status:** Active
**Last verified:** 2026-08-09

---

## Purpose

This checklist is used after any settings change to verify the change
took effect correctly and no regressions occurred. Capture evidence
(screenshots, CLI output, telemetry links) in the associated PR or issue.

---

## Checklist

### Overlay integrity

- [ ] `node scripts/validate-governance.mjs` exits 0 with 0 errors
- [ ] `node scripts/render-managed-settings.mjs --check` exits 0
- [ ] `node --test scripts/test/*.test.mjs` exits 0
- [ ] No unresolved `{{PLACEHOLDER}}` tokens in `managed-settings.json` or `team-mappings.json`
- [ ] All required files exist (see validator check 9)

### GitHub settings sync

- [ ] `copilot/managed-settings.json` committed to main
- [ ] GitHub managed-settings source is set to this repository (verify in org settings)
- [ ] Settings sync confirmed (verify by checking at least one affected client)

### Client verification

For each affected setting, verify on at least one representative client:

| Setting changed | Verification method |
|---|---|
| `permissions.model` | Copilot CLI: `gh copilot config show` |
| `sandbox.*` | CLI: attempt a sandboxed agent task and confirm scope |
| `allowedMcpServers` | CLI: attempt connection to allowed/denied server |
| `telemetry.enabled` | Observability platform: verify traces arriving |
| `enabledPlugins` | Copilot agent picker: verify plugin appears |
| `strictKnownMarketplaces` | Attempt to add unlisted marketplace (should fail) |

### Security verification

- [ ] No secret values in `managed-settings.json` (no real tokens, bearer headers)
- [ ] Floor keys are intact: `sandbox.enabled=true`, `allowBypass=false`,
  `captureContent=false`, `lockCaptureContent=true`, `strictKnownMarketplaces=true`
- [ ] MCP allowlist: no `http://` entries, no `@latest` pinning
- [ ] CODEOWNERS file intact and governance team is listed

### Post-change monitoring (first 24 hours)

- [ ] No elevated error rates in telemetry (if enabled)
- [ ] No user reports of broken functionality
- [ ] No unexpected sandbox block events

---

## Evidence capture

Record evidence for each verification step:
- CLI output: paste into PR comment or issue
- Telemetry: link to dashboard or export relevant trace IDs
- Screenshots: attach to PR/issue
- Spot-check: record who verified and on which OS/client version

Example evidence format:
```
## Verification evidence (PR #42)

### Overlay integrity
- validate-governance.mjs: 0 errors, 0 warnings (run at 2026-08-09T14:00Z)
- render-managed-settings.mjs --check: PASS (run at 2026-08-09T14:01Z)
- Tests: all 12 pass (run at 2026-08-09T14:02Z)

### Client verification
- sandbox.allowDevToolAccess for ai-platform-pioneers: verified by @jsmith
  on macOS 14.6 with Copilot CLI v1.5.2 at 2026-08-09T15:00Z
  Output: [CLI output here]
```
