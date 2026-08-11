# Engineering principles

**Owner:** Engineering maintainers
**Status:** Active
**Last verified:** 2026-08-09

1. **Map, then disclose.** `AGENTS.md` routes work; deep docs carry detail.
2. **Determinism before prompting.** Validate schemas, links, pins, ownership,
   and structure mechanically.
3. **Least privilege by default.** Read-only agents and MCP allowlists are the
   baseline; writes require an explicit use case and authorization.
4. **One source per contract.** Link to active truth instead of copying it.
5. **Behavior-safe layers.** Harness changes must not alter app or deploy
   behavior unless the layer explicitly owns that behavior.
6. **Evidence over claims.** Tests, command output, and recorded decisions are
   stronger than prose saying a surface works.
7. **Fail visibly.** Invalid input and missing required tools cannot become
   success-shaped output.
8. **Portable core, honest adapters.** Mark VS Code-only prompts/handoffs and
   GitHub settings references instead of claiming universal discovery.
