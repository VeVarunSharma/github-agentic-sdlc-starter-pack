<!-- HAND-AUTHORED - GitHub Copilot compatibility bridge. -->

# Repository instructions

Start with [`../AGENTS.md`](../AGENTS.md). It is the canonical, concise map for
this repository and takes precedence over this compatibility bridge.

Use progressive disclosure:

1. Read `AGENTS.md` for invariants, task routing, validation, and escalation.
2. Load only the task-specific source linked from its routing table.
3. Apply matching `.github/instructions/*.instructions.md` files to the paths
   they cover.
4. Use [`../docs/README.md`](../docs/README.md) to find maintained deeper
   knowledge; historical spike documents are evidence, not active truth.

Key entry points:

- Product and architecture:
  [`../docs/product.md`](../docs/product.md),
  [`../docs/architecture.md`](../docs/architecture.md)
- Engineering and quality:
  [`../docs/engineering-principles.md`](../docs/engineering-principles.md),
  [`../docs/quality-grades.md`](../docs/quality-grades.md)
- Security and review:
  [`../docs/standards/security.md`](../docs/standards/security.md),
  [`../docs/standards/review.md`](../docs/standards/review.md)
- Agent surfaces and client support:
  [`../docs/dotgithub-tour.md`](../docs/dotgithub-tour.md),
  [`../docs/agent-support-matrix.md`](../docs/agent-support-matrix.md)
- Plans and decisions:
  [`../docs/plans/README.md`](../docs/plans/README.md),
  [`../docs/decisions/README.md`](../docs/decisions/README.md)

Do not duplicate the map or deep documentation here. GitHub supports root
`AGENTS.md`; this file remains as an explicit repository-wide entry surface for
clients and users that still inspect Copilot-specific instructions first.
