# Plugin and agent lifecycle

**Owner:** Enterprise Platform / Governance Team
**Status:** Active
**Last verified:** 2026-08-09

---

## Overview

This document covers the full lifecycle for enterprise plugins and agents:
onboarding, updating, and removing. All changes require CODEOWNER review.

---

## Plugin lifecycle

### Adding a plugin

1. **Develop and review the plugin** — the plugin must have a `plugin.json`
   manifest with id, name, description, version, and declared agents/skills/hooks.
2. **Add to internal marketplace** — add an entry to `.github/plugin/marketplace.json`.
3. **Open a governance-change issue** using the template.
4. **PR with**: updated `marketplace.json`, `plugins/<id>/plugin.json`,
   and (if enterprise-wide) add `<id>@enterprise-standards` to `enabledPlugins`
   in `managed-settings.source.jsonc`.
5. **Render and validate** — run renderer and validator; all checks must pass.
6. **CODEOWNER approval** and CI green.
7. **Staged rollout** per [rollout runbook](../runbooks/rollout.md).

### Updating a plugin

1. Update `plugin.json` version and contents.
2. Update `marketplace.json` if the version is listed there.
3. Render, validate, PR, review, merge.

### Removing a plugin

1. Remove from `enabledPlugins` in `managed-settings.source.jsonc` first.
2. Render, validate, merge — this disables the plugin for all users.
3. After 48 hours (allow sync and client cache expiry), remove from
   `marketplace.json` and `plugins/`.
4. Render, validate, merge.

---

## Agent lifecycle

### Adding an agent

1. **Create the agent file** as `agents/<name>.agent.md` with required frontmatter:
   - `name`: display name
   - `description`: one-line purpose
   - `tools`: array of tool identifiers
   - `user-invocable`: true/false
   - `disable-model-invocation`: true/false
2. **Test the candidate** — place in `.github/agents/` first and test manually.
   Follow the `.github/agents/README.md` promotion criteria.
3. **Open a governance-change issue** once testing is satisfactory.
4. **PR** moving the file to `agents/` and documenting test results.
5. **CODEOWNER approval** and CI green (schema validation in validator).
6. Promote to `agents/` via merge.

### Updating an agent

- Edit the `agents/<name>.agent.md` file.
- PR with description of behavioral change.
- Security review if tool grants change.
- CODEOWNER approval and CI green.

### Removing an agent

- Remove the file from `agents/`.
- Update `plugin.json` if the agent is listed there.
- PR with rationale.
- CODEOWNER approval and CI green.

---

## Schema requirements

Agents MUST have the following frontmatter:

```yaml
---
name: <string>
description: <string>
tools: [<tool-ids>]
user-invocable: <true|false>
disable-model-invocation: <true|false>
---
```

The validator (`validate-governance.mjs`) checks for `name:` and YAML
frontmatter delimiters (`---`).

---

## Security review checklist for new agents

- [ ] Does the agent request only the tools it needs?
- [ ] Is the agent read-only by default? (mutations require explicit confirmation)
- [ ] No prompt injection vectors in the system prompt?
- [ ] No hardcoded secrets or endpoints?
- [ ] No `execute` tool unless strictly necessary (document justification)?
