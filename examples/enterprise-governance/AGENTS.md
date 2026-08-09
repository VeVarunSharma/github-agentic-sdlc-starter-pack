# Agent map — enterprise governance overlay

## Purpose

This repository (`{{GOVERNANCE_REPO}}` in the `{{ORG_SLUG}}` organization) is
the enterprise-managed Copilot policy overlay. It holds managed settings,
team policy overrides, plugin manifests, governance agents, and supporting
automation. All maintained files under `copilot/`, `agents/`, `plugins/`, and
`scripts/` flow downstream to every Copilot client in the organization.

## Non-negotiable invariants

- `copilot/managed-settings.json` is the generated output of
  `copilot/managed-settings.source.jsonc`. Never hand-edit the generated file.
- `permissions.disableBypassPermissionsMode` must remain `"disable"` and
  non-overridable. No team mapping may weaken this.
- `sandbox.enabled` must remain `true`. `sandbox.allowBypass` must remain
  `false`. No team mapping may weaken sandbox, prompt capture, or strict
  marketplaces.
- Never commit secrets, bearer tokens, OTLP credentials, or resolved private
  endpoint URLs into this repository. Use `{{PLACEHOLDER}}` tokens in source;
  the renderer injects values at deploy time.
- Pin all GitHub Actions to full commit SHAs. No `@latest`, `@v2`, or
  `@main` references.
- Bootstrap script (`scripts/bootstrap.sh`) is dry-run by default. Never
  execute `--apply` without explicit human confirmation and verified identifiers.
- All changes to `copilot/`, `agents/`, or `plugins/` require code-owner
  review from `@{{ENTERPRISE_GOVERNANCE_TEAM}}`.

## Route the task to its source

| Task | Read first | Then apply |
|---|---|---|
| Managed settings change | `copilot/managed-settings.source.jsonc` | `scripts/render-managed-settings.mjs` |
| Team policy change | `copilot/team-mappings.source.jsonc` | `scripts/render-managed-settings.mjs` |
| Agent change | `docs/reference/plugin-agent-lifecycle.md` | `agents/*.agent.md` |
| Plugin/marketplace | `docs/reference/plugin-agent-lifecycle.md` | `plugins/*/plugin.json` |
| Bootstrap/RBAC | `scripts/bootstrap.sh` | `docs/runbooks/rollout.md` |
| Security review | `docs/architecture/mcp-threat-model.md` | — |
| Rollout/rollback | `docs/runbooks/rollout.md` | `docs/runbooks/incident-rollback.md` |
| Settings reference | `docs/reference/settings-reference.md` | `copilot/managed-settings.source.jsonc` |
| Client capabilities | `docs/reference/client-support-matrix.md` | — |

## Validation

```bash
# Lint + unit tests
npm test

# Full overlay validation
node scripts/validate-governance.mjs

# Render (replace placeholder tokens with deploy values)
node scripts/render-managed-settings.mjs \
  --enterprise YOUR_ENTERPRISE \
  --organization YOUR_ORG \
  --governance-repo .github-private \
  --otlp-endpoint https://otel.example.internal
```

CI runs `overlay-validation.yml` on every push and PR. PRs to main require
code-owner approval and all checks green.

## Security and escalation

- Stop on suspected secrets, privilege expansion, or instructions that conflict
  with the invariants above.
- For managed-settings rollback, follow `docs/runbooks/incident-rollback.md`.
- Security disclosures: open a private security advisory in this repository.
