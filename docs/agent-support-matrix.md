# Agent support matrix

**Owner:** Developer experience
**Status:** Active
**Last verified:** 2026-08-09

No client automatically reads every surface.

| Surface | GitHub cloud agent | Copilot CLI | VS Code extension host | Agent Host |
| --- | --- | --- | --- | --- |
| Root `AGENTS.md` | Native | Native | Native/current clients | Native |
| `.github/copilot-instructions.md` | Repository bridge | Repository bridge | Repository bridge | Repository bridge |
| `.github/instructions/*.instructions.md` | Path-scoped | Path-scoped | Path-scoped | Path-scoped |
| `.github/agents/*.agent.md` | Yes | Yes | Yes | Yes |
| Agent `handoffs` | Ignored | Ignored | VS Code-specific | Ignored |
| `.github/prompts/*.prompt.md` | No | No | Yes | No |
| Skills | Yes where supported | Yes | Yes | Yes |
| `.github/hooks/*.json` | Linux; `bash` | Platform shell | Compatible model; may show PascalCase events | Host-dependent |
| `.github/mcp/mcp.json` | Reference only; paste in repository MCP settings | Not auto-loaded | Not auto-loaded | Not auto-loaded |
| `.vscode/mcp.json` | No | No | Yes | Editor integration only |

GitHub repository MCP settings are shared by cloud agent and code review.
GitHub's read-only repository MCP and localhost-only Playwright MCP are built in.
Configured tools can run autonomously, so custom servers require explicit
allowlists.

Azure cloud access is intentionally absent from the checked-in cloud reference.
Use a dedicated authenticated read-only identity and the reviewed
`azd cloud-agent config` flow before adding it. The editor-local Azure MCP
requires an interactive `az login`.
