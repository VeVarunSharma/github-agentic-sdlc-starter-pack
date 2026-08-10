---
name: governance-validation
description: Validate managed settings, team policy, plugin, agent, and governance drift before release.
---

# Governance validation

1. Read the active governance repository `AGENTS.md`.
2. Run `npm test`.
3. Run `npm run check`.
4. Run `npm run validate`.
5. Report the exact failing contract without weakening a floor or editing
   generated JSON directly.
