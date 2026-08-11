# Private agents — testing guide

Agents in this directory (`.github/agents/`) are under evaluation before
being promoted to the enterprise-wide `agents/` directory.

## Why test here first

Agents in `agents/` are enterprise-wide — they appear in the agent picker
for all teams. A buggy or poorly scoped agent can cause confusion or
security issues across the organization. Testing candidates here first:

1. Limits exposure to the governance team during review.
2. Allows iteration without affecting production agent listings.
3. Ensures schema validation and safety review complete before promotion.

## Promotion criteria

A test candidate may be promoted to `agents/` when:

- [ ] Agent schema is valid (name, tools, description all present)
- [ ] Agent follows read-only or explicit-confirm patterns for mutations
- [ ] Agent does not expose sensitive enterprise information in prompts
- [ ] Security review completed (no prompt injection vectors, no excessive tool grants)
- [ ] CODEOWNER approval from `@{{ENTERPRISE_GOVERNANCE_TEAM}}`
- [ ] Entry added to `docs/reference/plugin-agent-lifecycle.md`

## Testing procedure

1. Add the agent file here as `<name>.agent.md`.
2. Open in VS Code / Copilot CLI and invoke manually.
3. Test with representative inputs including edge cases and adversarial prompts.
4. Document test results in a PR comment or issue.
5. When promotion criteria are met, open a PR to move the file to `agents/`.
6. The overlay validation workflow will verify the schema automatically.

## Current test candidates

- [`test-candidate.agent.md`](test-candidate.agent.md) — example under evaluation
