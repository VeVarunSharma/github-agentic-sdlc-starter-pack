# AGENTS.md

> **This repository's primary agent context lives in
> [`.github/copilot-instructions.md`](./.github/copilot-instructions.md).**
> Tools that follow the [AGENTS.md convention](https://agents.md) — Claude
> Code, Cursor, OpenCode, Codex, Gemini, Windsurf — should read this file
> first; it points to the same hand-authored source of truth that GitHub
> Copilot loads automatically.

## What's in this repo

A reusable, opinionated **GitHub Agentic SDLC Starter Pack** — a Node.js +
Express sample app deployed to Azure App Service via Terraform + OIDC, with
GitHub Advanced Security wired in and a `.github/`-first agent context layer
that ships hand-authored worked examples of every Copilot primitive type.

## Read these files first

For project overview, conventions, build/test commands, the agentic SDLC
loop, and file-ownership rules, see:

- [`.github/copilot-instructions.md`](./.github/copilot-instructions.md) —
  primary, hand-authored entry point. Read this in full before doing any
  work in the repo.

For path-scoped guidance, slash prompts, sub-agents, skills, hooks, and
MCP server configuration, browse:

- [`.github/instructions/`](./.github/instructions/) — path-scoped
  instructions (e.g. only for `app/**/*.js` or `infra/**/*.tf`).
- [`.github/prompts/`](./.github/prompts/) — slash-prompt definitions.
- [`.github/chatmodes/`](./.github/chatmodes/) — Copilot Chat modes.
- [`.github/agents/`](./.github/agents/) — sub-agent definitions.
- [`.github/skills/`](./.github/skills/) — multi-step skill playbooks.
- [`.github/hooks/`](./.github/hooks/) — Copilot/APM lifecycle hooks.
- [`.github/mcp/`](./.github/mcp/) — MCP server reference for the
  GitHub Copilot cloud agent.

For the SDLC loop, gate by gate, see
[`docs/agentic-sdlc.md`](./docs/agentic-sdlc.md).

## Why a slim AGENTS.md?

This repo is **`.github/`-first**: `.github/copilot-instructions.md` is
hand-authored and primary. Keeping AGENTS.md as a pointer instead of a
duplicate copy means there is **one source of truth**, no risk of drift
between the two files, and the GitHub Copilot coding agent and
AGENTS.md-aware clients see identical guidance.

The rationale and full file-ownership table live in
[`docs/apm-ownership-model.md`](./docs/apm-ownership-model.md).
