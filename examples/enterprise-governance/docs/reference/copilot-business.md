# Copilot Business enterprise caveat

**Owner:** Enterprise AI administrators  
**Status:** Active  
**Last verified:** 2026-08-09

Enterprise managed settings can govern users on a Copilot Business plan, but
the server-managed deployment path requires an organization and a repository
named `.github-private`. In a dedicated Copilot Business enterprise, at least
one user needs a GitHub Enterprise license to create that organization and
repository and select it as the governance source.

If adding that license or repository is not appropriate, deploy the same
logical settings through:

- MDM-managed string values on Windows/macOS; or
- the platform file locations documented in
  [`../runbooks/mdm-fallback.md`](../runbooks/mdm-fallback.md), including Linux.

MDM/file deployment governs local clients only and does not reach Copilot cloud
agent. Users do not need repository access to receive server-managed settings,
but they do need access to any private repository hosting an automatically
enabled plugin.

Do not claim that individual keys are Enterprise-plan-only without checking the
current [managed settings reference](https://docs.github.com/en/copilot/reference/enterprise-administrators/enterprise-managed-settings).
The deployment prerequisite, client support table, and separate AI Controls
remain the controlling facts.
