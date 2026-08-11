# Known technical debt

**Owner:** Engineering maintainers
**Status:** Active
**Last verified:** 2026-08-09

| Debt | Risk | Exit criteria |
| --- | --- | --- |
| PowerShell hook is statically validated when `pwsh` is unavailable | Windows drift could escape local CI | Add a Windows job that executes hook fixtures |
| Azure MCP uses a beta package | Upstream schema may change | Review and pin a stable release, then update fixtures/docs |
| Markdown anchor validation covers standard GitHub slugs only | Exotic headings may false-positive | Adopt a tested GFM slugger if real docs require it |
| Template placeholders intentionally remain before adoption | Strict doctor reports expected setup debt | Cleanup workflow replaces values and strict doctor passes |
| Historical spikes contain superseded examples | Readers may mistake evidence for truth | Keep catalog lifecycle labels and add banners when touched |

Debt must have an observable risk and exit criterion. Feature wishes belong in
issues or plans, not this register.
