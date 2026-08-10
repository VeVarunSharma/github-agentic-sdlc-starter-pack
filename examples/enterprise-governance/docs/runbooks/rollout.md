# Rollout runbook

**Owner:** Enterprise Platform / Governance Team
**Status:** Active
**Last verified:** 2026-08-09

---

## Purpose

This runbook covers how to safely roll out changes to enterprise Copilot managed
settings. Follow this procedure for any change to `copilot/managed-settings.source.jsonc`
or `copilot/team-mappings.source.jsonc`.

---

## Pre-rollout checklist

Before merging any managed-settings change:

- [ ] Replace `{{ENTERPRISE_GOVERNANCE_TEAM}}` in `CODEOWNERS` with the real
      `@organization/team-slug` in the copied governance repository
- [ ] Open an issue using the [governance-change template](../../.github/ISSUE_TEMPLATE/governance-change.yml)
- [ ] Run `node scripts/validate-governance.mjs` locally — zero errors
- [ ] Run `node scripts/render-managed-settings.mjs --check` — passes
- [ ] PR has CODEOWNER approval from `@{{ENTERPRISE_GOVERNANCE_TEAM}}`
- [ ] All CI checks pass (overlay-validation.yml)
- [ ] Rollback plan documented in the PR description
- [ ] Change window communicated to affected teams (if user-visible behavior changes)

---

## Staged rollout (recommended for high-impact changes)

For changes affecting sandbox configuration, MCP allowlists, or plugin
permissions, use a staged rollout:

1. **Apply to a test team first** via `copilot/team-mappings.source.jsonc`.
   Configure the test team with the new setting and verify behavior.

2. **Monitor for 48 hours** using telemetry (if enabled for the test team)
   and manual spot-checks.

3. **Promote to enterprise baseline** by updating `managed-settings.source.jsonc`.
   Render, validate, and merge.

4. **Remove the team-level override** in team-mappings if it was used for staged
   testing only.

---

## Applying the change

1. Ensure the PR is merged to main in the governance repository.
2. GitHub's managed-settings sync picks up the new `copilot/managed-settings.json`
   within ~5 minutes.
3. Verify by asking affected users to reload Copilot and confirm the new setting
   is active (e.g. run `gh copilot config show` in CLI).

---

## Post-rollout verification

- [ ] Affected Copilot clients reflect the new setting
- [ ] No error reports from users in the first 30 minutes
- [ ] Telemetry (if enabled) shows normal patterns
- [ ] No regression in blocked functionality (e.g. agents can still build/test)

---

## Rollback

If the rollout causes issues, see [`incident-rollback.md`](incident-rollback.md).

The fastest rollback is to revert the PR to main:
```bash
gh pr create --title "Revert: <original PR title>" --body "Emergency rollback"
# Or use GitHub UI → PR → Revert
```

Once the revert is merged, GitHub's sync picks it up within ~5 minutes.
