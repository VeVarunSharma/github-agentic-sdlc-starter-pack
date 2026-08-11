# Centralized controls outside `managed-settings.json`

**Owner:** Enterprise AI administrators  
**Status:** Active  
**Last verified:** 2026-08-09

`managed-settings.json` governs supported client behavior. It does not replace
GitHub Enterprise AI Controls, organization repository permissions, rulesets,
custom roles, audit, or usage administration.

| Control | Enforcement surface | Automation/status | Operator action |
| --- | --- | --- | --- |
| Create and select `.github-private` governance source | Enterprise **AI controls → Agents → Configuration source** | UI-only selection; GA | [Create/select the source](https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-enterprise/manage-agents/create-github-private-repo), protect agent/policy files, then verify the configuration summary. |
| Cloud agent availability | Enterprise AI Controls | REST GA: `PUT /enterprises/{enterprise}/copilot/policies/coding_agent`, API `2026-03-10` | Choose all orgs, selected orgs, disabled, or configured by org admins. See [enable cloud agent](https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-enterprise/manage-agents/enable-copilot-cloud-agent) and [REST](https://docs.github.com/en/rest/copilot/copilot-coding-agent-management). |
| Selected cloud-agent organizations/custom properties | Enterprise AI Controls | REST GA; custom-property selection is a point-in-time evaluation | Add/remove selected organizations with the coding-agent management endpoints; periodically reconcile property changes. |
| Organization repository access and repository IDs | Organization Copilot settings | REST public preview: `/orgs/{org}/copilot/coding-agent/permissions` and `/repositories` | Set all/selected/none and verify immutable repository IDs before enabling selected repositories. |
| Third-party MCP for cloud agent | Enterprise **AI controls → MCP** | UI policy; GA support policy, registry restriction preview | Govern separately from this overlay. Managed `allowedMcpServers`/`deniedMcpServers` do not enforce on cloud agent. See [MCP management](https://docs.github.com/en/copilot/concepts/mcp-management). |
| Repository/custom-agent MCP tools | Repository Copilot settings and agent `mcp-servers`/`tools` | Repository file/UI; GA, custom agents key-dependent preview | Use explicit read-only tool allowlists. The built-in first-party GitHub cloud MCP is exempt from managed deny rules. See [cloud-agent MCP](https://docs.github.com/en/copilot/concepts/agents/cloud-agent/mcp-and-cloud-agent). |
| Third-party coding agents and agent apps | Enterprise/organization AI Controls | Third-party agents GA for paid plans; agent apps public preview | Enable only reviewed providers/apps, restrict repository access, and monitor AI-credit billing. See [agent apps](https://docs.github.com/en/copilot/concepts/agents/agent-apps). |
| Model availability and custom models | Enterprise **AI controls → Copilot → Models** | UI; default model policy GA, enterprise-team targeting preview | Configure allowed/default models, custom models, data-residency constraints, and review the [default availability policy](https://docs.github.com/en/copilot/concepts/models/default-availability). |
| Automatic Copilot code review | Repository/organization branch rulesets | Rulesets GA | Explicitly select automatic review; decide whether to review new pushes and drafts. New-push/draft review increases AI credits and Actions minutes. See [automatic review](https://docs.github.com/en/copilot/how-tos/copilot-on-github/set-up-copilot/configure-automatic-review). |
| Suggestions matching public code | Enterprise/organization AI Controls | UI; GA | Keep blocked unless legal and security approve the matching/licensing posture. |
| Copilot in GitHub.com and feedback collection | Enterprise/organization AI Controls | UI; GA | Select enabled/disabled/delegated policy and document who reviews submitted feedback. See [enterprise policies](https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-enterprise/manage-enterprise-policies). |
| Content exclusion | Enterprise/organization/repository settings | UI; GA, supported surfaces vary | Define exclusions and verify them on every required surface using the [policy support matrix](https://docs.github.com/en/copilot/reference/supported-surfaces-for-policies). |
| Enterprise AI-manager custom role/team | Enterprise roles and teams | UI; GA where custom roles are licensed | Grant only AI policy/governance administration, not broad enterprise ownership; review membership periodically. |
| Governance ruleset bypass | Governance repository ruleset | UI after team/role creation | Add the reviewed AI-manager team through the UI. Never copy numeric actor IDs into this template. Audit every bypass. |
| Agent-session and policy monitoring | Agent sessions, enterprise audit log/streaming | UI/streaming; GA | Search `action:copilot` and `actor:Copilot`, stream to the SIEM, and follow the [audit guide](https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-enterprise/review-audit-logs). |
| Usage metrics and access review | Copilot dashboards and metrics REST | REST GA, API `2026-03-10` | Review usage/AI credits monthly and licenses, team membership, apps, models, MCP, and exceptions quarterly. See [usage metrics REST](https://docs.github.com/en/rest/copilot/copilot-usage-metrics). |

The bootstrap script intentionally does not select the governance source or
mutate AI Controls because those changes need separate policy decisions and
human authorization.
