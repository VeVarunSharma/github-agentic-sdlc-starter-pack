# Resources

A curated link catalog. We deliberately do **not** re-host or fork
content from these — we link out to the canonical sources and pin SHAs
in [`upstream-sources.md`](./upstream-sources.md) when we depend on
specific versions.

## GitHub Copilot — agent context

- [GitHub Copilot docs — Customizing Copilot](https://docs.github.com/copilot/customizing-copilot)
  — official guidance on `.github/copilot-instructions.md`,
  `.github/instructions/`, `.github/prompts/`, `.github/chatmodes/`,
  and the AGENTS.md convention.
- [GitHub Copilot docs — Coding agent](https://docs.github.com/copilot/using-github-copilot/using-copilot-coding-agent-to-work-on-tasks)
  — how the cloud agent picks up issues, reads context, and opens
  PRs.
- [VS Code — Custom instructions for chat](https://code.visualstudio.com/docs/copilot/copilot-customization)
  — VS Code's view of the same primitives.
- [VS Code — MCP configuration reference](https://code.visualstudio.com/docs/copilot/reference/mcp-configuration)
  — the syntax `.vscode/mcp.json` (and our `.github/mcp/mcp.json`)
  uses.
- [agents.md — the AGENTS.md convention](https://agents.md) —
  cross-tool agent context manifest. We ship a slim `AGENTS.md`
  pointing at `.github/copilot-instructions.md`.

## Awesome lists (curated upstream content)

- [github/awesome-copilot](https://github.com/github/awesome-copilot)
  — Copilot prompts, instructions, chatmodes, agents, skills. Source
  for the 7 APM-installed deps in [`apm.yml`](../apm.yml).
- [sdras/awesome-actions](https://github.com/sdras/awesome-actions) —
  GitHub Actions catalog. Use to find Actions we haven't already pinned
  in our workflows.
- [microsoft/github-copilot-canada](https://github.com/microsoft/github-copilot-canada)
  — Microsoft's curated learning content for Copilot. Inspiration for
  this docs/ catalog.

## APM (Agent Package Manager)

- [microsoft/apm](https://github.com/microsoft/apm) — APM CLI source +
  registry. We install `v0.28.0` via
  [`scripts/install-apm.sh`](../scripts/install-apm.sh).
- [APM action — `microsoft/apm-action@v1`](https://github.com/microsoft/apm-action)
  — used in [`apm-audit.yml`](../.github/workflows/apm-audit.yml) and
  [`apm-update.yml`](../.github/workflows/apm-update.yml).
- [Spike A — APM Round-Trip](./spike-a-apm-roundtrip.md) — our verified
  research notes.

## MCP (Model Context Protocol)

- [Anthropic MCP spec](https://modelcontextprotocol.io/) —
  protocol-level documentation.
- [`github/github-mcp-server`](https://github.com/github/github-mcp-server)
  — GitHub remote MCP server (read-write Issues, PRs, code, Actions).
  Apache-2.0.
- [`microsoftdocs/mcp`](https://github.com/microsoftdocs/mcp) —
  Microsoft Learn MCP server. MIT.
- [`Azure/azure-mcp`](https://github.com/Azure/azure-mcp) — Azure MCP
  server (stdio). MIT.
- [MCP servers registry](https://github.com/modelcontextprotocol/servers)
  — broader catalog.

## Azure infra + OIDC

- [Azure / GitHub OIDC docs](https://learn.microsoft.com/azure/developer/github/connect-from-azure-openid-connect)
  — official end-to-end guide. The basis for
  [Spike D](./spike-d-azure-oidc.md).
- [Azure Verified Modules (AVM)](https://aka.ms/avm) — opinionated
  Bicep + Terraform module catalog. Useful when you want to swap our
  hand-authored `infra/app/` for a module-based composition.
- [Terraform AzureRM provider docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
  — the resources we use in `infra/`.
- [`azure/login@v2`](https://github.com/Azure/login) — the Action that
  exchanges the OIDC token for an Azure access token.

## GHAS (GitHub Advanced Security)

- [GHAS overview](https://docs.github.com/code-security)
- [CodeQL docs](https://codeql.github.com/docs/) — our `codeql.yml`
  workflow uses the standard `github/codeql-action`.
- [Dependabot docs](https://docs.github.com/code-security/dependabot)
  — version + security updates configured via
  [`.github/dependabot.yml`](../.github/dependabot.yml).
- [Dependency Review](https://docs.github.com/code-security/supply-chain-security/understanding-your-software-supply-chain/about-dependency-review)
  — gates PRs on new vulnerable deps.
- [Secret Scanning + Push Protection](https://docs.github.com/code-security/secret-scanning)
  — free for public repos, GHAS for private.

## Branch protection and rulesets

- [Repository rulesets docs](https://docs.github.com/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets)
- [Importing rulesets via API](https://docs.github.com/rest/repos/rules)
  — used by [`repo-settings-checklist.md`](./repo-settings-checklist.md).
- [Spike C — Rulesets](./spike-c-rulesets.md) — verified research
  notes for our `main-branch-evaluate.json` and `main-branch-enforce.json`.

## CI/CD references

- [GitHub Actions docs](https://docs.github.com/actions)
- [Reusable workflows](https://docs.github.com/actions/using-workflows/reusing-workflows)
  — pattern for org-wide rollout (factor `ci.yml` into a reusable
  workflow consumers extend).
- [Required workflows (org/enterprise)](https://docs.github.com/actions/using-workflows/required-workflows)
  — enforce `apm-audit` across all org repos.
- [Spike B — Copilot agent assignment](./spike-b-copilot-assignment.md)
  — GraphQL flow for `copilot-auto-assign.yml`.
- [Spike E — `copilot-setup-steps.yml`](./spike-e-copilot-setup-steps.md)
  — the cloud-agent runtime workflow.
- [Spike F — APM SARIF](./spike-f-apm-sarif.md) — wiring the audit
  output into the Security tab.

## Supply chain hardening

- [OpenSSF Scorecard](https://github.com/ossf/scorecard) — measure
  baseline hygiene. Used in `examples/public-oss-hardening/`.
- [OpenSSF Allstar](https://github.com/ossf/allstar) — enforce
  baseline policies across an org. Org-level opt-in.
- [Sigstore + Cosign](https://www.sigstore.dev/) — sign container
  images. Recommended for regulated overlays.
- [Syft (SBOM)](https://github.com/anchore/syft) +
  [`actions/attest-sbom`](https://github.com/actions/attest-sbom) —
  SBOM generation and attestation.
- [SLSA](https://slsa.dev/) — supply chain levels framework.

## Reading order for new adopters

If you're new to this and want a guided path:

1. Start with the project's [`README.md`](../README.md) for the elevator
   pitch.
2. Read [`agentic-sdlc.md`](./agentic-sdlc.md) for the loop.
3. Tour [`dotgithub-tour.md`](./dotgithub-tour.md) for the primitives.
4. Walk [`adoption-playbook.md`](./adoption-playbook.md) for the
   "how do I use this in my own org" steps.
5. Pre-flight with [`repo-settings-checklist.md`](./repo-settings-checklist.md).
6. For credentials specifically: [`azure-oidc-setup.md`](./azure-oidc-setup.md).
7. Going deep on rationale and trade-offs:
   [`apm-ownership-model.md`](./apm-ownership-model.md),
   [`governance.md`](./governance.md),
   [`upstream-sources.md`](./upstream-sources.md).
