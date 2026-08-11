<!-- HAND-AUTHORED - concise review invariants for maintained code paths. -->
---
description: "High-signal review invariants; detailed severity rules live in docs/standards/review.md"
applyTo: "app/**,infra/**,.github/**,scripts/**,tools/**"
---

# Review invariants

- Review only changed behavior and directly coupled consequences.
- Prioritize exploitable security issues, correctness failures, data loss,
  permission expansion, broken rollback, and missing tests for changed paths.
- Cite the exact file and line, explain impact, and propose the smallest safe
  fix. Do not report style-only preferences or speculative concerns.
- Verify documentation and validation routing when a contract or path changes.
- A review agent returns a structured report by default. Posting requires
  explicit user authorization and an available write-capable tool; agents in
  this repository never approve or merge.
- Follow [`../../docs/standards/review.md`](../../docs/standards/review.md).
