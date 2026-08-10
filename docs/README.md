# Documentation catalog

This catalog is the system of record for maintained repository knowledge.
`AGENTS.md` routes agents here; entries marked **Historical** are evidence and
must not override active documentation or code.

**Catalog owner:** repository maintainers
**Last catalog verification:** 2026-08-09

| Document | Purpose | Owner | Lifecycle | Last verified |
| --- | --- | --- | --- | --- |
| [`product.md`](product.md) | Product intent and non-goals | Product maintainers | Active | 2026-08-09 |
| [`architecture.md`](architecture.md) | Components, boundaries, and data flow | Platform maintainers | Active | 2026-08-09 |
| [`engineering-principles.md`](engineering-principles.md) | Golden engineering principles | Engineering maintainers | Active | 2026-08-09 |
| [`quality-grades.md`](quality-grades.md) | Domain quality grades and evidence | Engineering maintainers | Active | 2026-08-09 |
| [`technical-debt.md`](technical-debt.md) | Known debt and exit criteria | Engineering maintainers | Active | 2026-08-09 |
| [`agent-support-matrix.md`](agent-support-matrix.md) | Client discovery and portability | Developer experience | Active | 2026-08-09 |
| [`agentic-sdlc.md`](agentic-sdlc.md) | Issue-to-deploy lifecycle | Developer experience | Active | 2026-08-09 |
| [`dotgithub-tour.md`](dotgithub-tour.md) | Agent customization surfaces | Developer experience | Active | 2026-08-09 |
| [`adoption-playbook.md`](adoption-playbook.md) | Template adoption paths | Developer experience | Active | 2026-08-09 |
| [`apm-ownership-model.md`](apm-ownership-model.md) | Generated/hand-authored boundaries | Developer experience | Active | 2026-08-09 |
| [`upstream-sources.md`](upstream-sources.md) | APM provenance and pins | Supply chain owners | Active | 2026-08-09 |
| [`maintenance-matrix.md`](maintenance-matrix.md) | Recurring ownership and checks | Repository maintainers | Active | 2026-08-09 |
| [`governance.md`](governance.md) | Policy and ruleset governance | Repository maintainers | Active | 2026-08-09 |
| [`repo-settings-checklist.md`](repo-settings-checklist.md) | One-time GitHub settings | Repository administrators | Active | 2026-08-09 |
| [`azure-oidc-setup.md`](azure-oidc-setup.md) | Azure federation setup/rotation | Cloud platform owners | Active | 2026-08-09 |
| [`enterprise-hardening.md`](enterprise-hardening.md) | Optional regulated controls | Security owners | Active | 2026-08-09 |
| [`resources.md`](resources.md) | Curated external references | Developer experience | Active | 2026-08-09 |
| [`standards/security.md`](standards/security.md) | Security engineering standard | Security owners | Active | 2026-08-09 |
| [`standards/review.md`](standards/review.md) | High-signal review standard | Engineering maintainers | Active | 2026-08-09 |
| [`plans/README.md`](plans/README.md) | Plan policy and lifecycle | Engineering maintainers | Active | 2026-08-09 |
| [`plans/template.md`](plans/template.md) | Execution-plan template | Engineering maintainers | Template | 2026-08-09 |
| [`plans/active/README.md`](plans/active/README.md) | Active-plan directory contract | Engineering maintainers | Active | 2026-08-09 |
| [`plans/completed/2026-08-09-enterprise-copilot-governance.md`](plans/completed/2026-08-09-enterprise-copilot-governance.md) | Layer 5 centralized enterprise Copilot governance implementation | Developer experience | Active | 2026-08-09 |
| [`plans/completed/README.md`](plans/completed/README.md) | Completed-plan archive contract | Engineering maintainers | Active | 2026-08-09 |
| [`decisions/README.md`](decisions/README.md) | ADR policy and index | Architecture owners | Active | 2026-08-09 |
| [`decisions/template.md`](decisions/template.md) | ADR template | Architecture owners | Template | 2026-08-09 |
| [`decisions/0001-canonical-agent-context.md`](decisions/0001-canonical-agent-context.md) | Canonical context hierarchy | Architecture owners | Active | 2026-08-09 |
| [`decisions/0002-annotated-enterprise-governance.md`](decisions/0002-annotated-enterprise-governance.md) | Annotated source and deterministic strict JSON for centralized Copilot policy | Enterprise AI administrators | Active | 2026-08-09 |
| [`spike-a-apm-roundtrip.md`](spike-a-apm-roundtrip.md) | Original APM investigation | Developer experience | Historical | 2026-08-09 |
| [`spike-b-copilot-assignment.md`](spike-b-copilot-assignment.md) | Original assignment API research | Developer experience | Historical | 2026-08-09 |
| [`spike-c-rulesets.md`](spike-c-rulesets.md) | Original ruleset research | Repository administrators | Historical | 2026-08-09 |
| [`spike-d-azure-oidc.md`](spike-d-azure-oidc.md) | Original OIDC design research | Cloud platform owners | Historical | 2026-08-09 |
| [`spike-e-copilot-setup-steps.md`](spike-e-copilot-setup-steps.md) | Original setup-steps research | Developer experience | Historical | 2026-08-09 |
| [`spike-f-apm-sarif.md`](spike-f-apm-sarif.md) | Original SARIF research | Security owners | Historical | 2026-08-09 |

## Catalog rules

- Add every maintained Markdown document under `docs/` to this table.
- Update purpose, owner, lifecycle, and verified date in the same PR as a
  material contract change.
- Move superseded research to **Historical**; do not delete evidence solely
  because active truth changed.
- Use active docs, ADRs, code, and tests in that order to resolve disagreement.
