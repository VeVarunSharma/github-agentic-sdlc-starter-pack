# Incident response and rollback

**Owner:** Enterprise Platform / Governance Team
**Status:** Active
**Last verified:** 2026-08-09

---

## Trigger conditions

Escalate to this runbook when:
- Users report Copilot is broken or behaving unexpectedly after a settings change
- Telemetry shows anomalous error rates or blocked tool calls
- A security concern is reported about an MCP server or agent

---

## Immediate triage

1. **Identify the last merged PR** to `copilot/managed-settings.source.jsonc`
   or `copilot/team-mappings.source.jsonc`.
2. **Determine scope**: is the issue affecting all users or a specific team?
   - All users → enterprise baseline change
   - Specific team → team-mapping change
3. **Check telemetry** (if enabled) for error patterns.

---

## Rollback procedure

### Option A: Revert the PR (recommended)

This is the fastest path and leaves a clean audit trail.

```bash
# Find the commit to revert
git log --oneline copilot/ | head -5

# Create a revert commit
git revert <commit-sha>
git push origin main

# Or use the GitHub UI: PR → Revert
```

After merge, GitHub syncs the reverted settings within ~5 minutes.

### Option B: Targeted fix (for small issues)

If the rollback would remove too much, apply a targeted fix instead:

1. Edit `copilot/managed-settings.source.jsonc` with the minimal fix.
2. Run `node scripts/render-managed-settings.mjs` to regenerate.
3. Run `node scripts/validate-governance.mjs` — must pass.
4. Open a PR with `[HOTFIX]` prefix and request emergency CODEOWNER review.
5. Merge and verify within the change window.

---

## Monitoring

When telemetry is enabled (`telemetry.enabled: true` for a team), use your
OTLP-compatible observability platform to monitor:

- `github.copilot.tool.call` events — rate and error rate
- `github.copilot.model.selection` — model distribution
- Sandbox block events — `github.copilot.sandbox.blocked`

Set alerts for:
- Error rate > 5% over 5 minutes
- Sandbox block rate > 10% over 5 minutes (may indicate misconfigured deniedPaths)

---

## Communication

1. Notify affected teams immediately via Slack/Teams.
2. Post a status update to the governance issue tracker.
3. After resolution, open a post-mortem issue using the governance-change template.

---

## Post-incident

- Document root cause in the post-mortem issue.
- Update the [verification checklist](../reference/verification-checklist.md)
  with any new check to prevent recurrence.
- Update this runbook if a new pattern was identified.
