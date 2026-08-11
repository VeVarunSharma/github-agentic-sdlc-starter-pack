# Enterprise Governance Overlay

**Layer 5 — copy-ready `.github-private` root for one GitHub organization.**

This directory is the exact layout an adopter copies into a **new private
repository** (typically named `.github-private`) in their GitHub Enterprise
organization. The contents land at the repository root — there is no nested
`.github-private/` folder inside.

Before the first pull request, replace the declared
`{{ENTERPRISE_GOVERNANCE_TEAM}}` token in `CODEOWNERS` with the real
`@organization/team-slug`. Render real organization/endpoints only in the
copied private governance repository, never in this public starter example.

> **Scope:** This overlay adds enterprise-wide Copilot managed settings, team
> policy customizations, a plugin marketplace, governance agents, branch
> rulesets, bootstrap automation, and operations documentation on top of any
> team repositories. It does **not** replace per-repository `.github/`
> customization.

---

## Quick start

```bash
# 1. Clone or fork this overlay into your .github-private repository
git clone <this-repo> && cd enterprise-governance

# 2. Install dependencies deterministically (Node 22 required)
npm ci

# 3. Render managed settings with your deployment values
node scripts/render-managed-settings.mjs \
  --enterprise YOUR_ENTERPRISE_SLUG \
  --organization YOUR_ORG_SLUG \
  --governance-repo .github-private \
  --governance-ref FULL_REVIEWED_COMMIT_SHA \
  --otlp-endpoint https://otel.example.internal \
  --internal-mcp-url https://mcp.example.internal/standards \
  --pioneer-mcp-url https://mcp.example.internal/pioneers \
  --standard-team developers \
  --pioneer-team ai-platform-pioneers

# 4. Validate the overlay (also run in CI)
node scripts/validate-governance.mjs

# 5. Bootstrap GitHub settings (dry-run by default; add --apply to execute)
bash scripts/bootstrap-enterprise-governance.sh --help
```

---

## Layout

```
examples/enterprise-governance/          ← copy THIS directory to .github-private root
├── README.md                            ← this file
├── AGENTS.md                            ← agent map for the governance repo
├── CODEOWNERS                           ← code ownership declarations
├── package.json                         ← Node 22 project for scripts and tests
├── package-lock.json
├── config/render-inputs.json            ← committed non-secret render inputs
│
├── copilot/
│   ├── managed-settings.source.jsonc    ← annotated source of truth (EDIT THIS)
│   ├── managed-settings.json            ← generated strict JSON (DO NOT EDIT)
│   ├── team-mappings.source.jsonc       ← annotated team policy overrides
│   ├── team-mappings.json               ← generated strict JSON
│   └── teams/                           ← annotated/generated team policies
│
├── agents/                              ← enterprise-wide custom agents
│   ├── sdlc-planner.agent.md
│   ├── pr-reviewer.agent.md
│   └── governance-gardener.agent.md
│
├── .github/
│   ├── agents/
│   │   ├── README.md                    ← testing guide for private agents
│   │   └── test-candidate.agent.md      ← example agent under evaluation
│   ├── plugin/
│   │   └── marketplace.json             ← enterprise plugin marketplace
│   ├── workflows/
│   │   └── overlay-validation.yml       ← CI validation workflow
│   └── ISSUE_TEMPLATE/
│       ├── governance-change.yml
│       └── policy-exception.yml
│
├── plugins/
│   └── agentic-sdlc-standards/
│       ├── plugin.json                  ← current plugin manifest
│       ├── agents/                      ← contained portable agents
│       └── skills/                      ← contained validation skill
│
├── scripts/
│   ├── render-managed-settings.mjs      ← renderer + deployment token substitution
│   ├── validate-governance.mjs          ← comprehensive overlay validator
│   ├── bootstrap-enterprise-governance.sh ← safe dry-run GitHub bootstrap
│   └── test/
│       ├── render.test.mjs
│       ├── validate.test.mjs
│       └── bootstrap.test.mjs
│
└── docs/
    ├── README.md                        ← docs catalog
    ├── architecture/
    │   ├── overview.md                  ← architecture + data flow + precedence
    │   └── mcp-threat-model.md          ← MCP security threat model
    ├── runbooks/
    │   ├── rollout.md                   ← rollout runbook
    │   ├── incident-rollback.md         ← monitoring + incident response
    │   └── mdm-fallback.md              ← MDM/file fallback procedures
    └── reference/
        ├── settings-reference.md        ← settings cross-referenced to JSONC
        ├── plugin-agent-lifecycle.md    ← plugin + agent lifecycle
        ├── team-override-model.md       ← team policy override model
        ├── verification-checklist.md    ← verification evidence checklist
        ├── client-support-matrix.md    ← dated client capability matrix
        ├── centralized-controls.md     ← UI/REST controls outside managed JSON
        └── copilot-business.md         ← dedicated Business caveat
```

---

## Key concepts

| Concept | Where configured | Enforced by |
|---|---|---|
| Enterprise managed settings | `copilot/managed-settings.json` | Server (`.github-private` repo) |
| Team policy overrides | `copilot/team-mappings.json` | Server (least-restrictive merge) |
| Plugin marketplace | `.github/plugin/marketplace.json` | Server/client resolution |
| Branch protection | `.github/rulesets/*.json` | GitHub ruleset import |
| Bootstrap governance | `scripts/bootstrap-enterprise-governance.sh` | Human-run, dry-run default |
| Overlay CI validation | `.github/workflows/overlay-validation.yml` | GitHub Actions |

See [`docs/architecture/overview.md`](docs/architecture/overview.md) for data
flow, precedence, and client-support scope.

---

## Maintenance

- **Edit** `copilot/managed-settings.source.jsonc` and team sources, then run
  the renderer to regenerate strict JSON. Never hand-edit generated files.
- **Validate** with `node scripts/validate-governance.mjs` before any commit.
- **Pin** Actions to full commit SHAs. Update pins via Dependabot or manual
  audit.
- **CODEOWNERS** requires PR review by `@{{ENTERPRISE_GOVERNANCE_TEAM}}` for
  all governance-critical paths.
- Consult [`docs/runbooks/rollout.md`](docs/runbooks/rollout.md) before
  changing managed settings in production.
