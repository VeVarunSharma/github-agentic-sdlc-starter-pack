#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
bootstrap-enterprise-governance.sh

Validate/render a `.github-private` governance source and preview supported
GitHub REST operations. Cloud mutation is disabled unless --apply and an exact
--confirm OWNER/REPOSITORY value are both supplied.

USAGE
  bash scripts/bootstrap-enterprise-governance.sh \
    --enterprise SLUG \
    --organization SLUG \
    --governance-repo .github-private \
    --governance-ref FULL_COMMIT_SHA \
    --otlp-endpoint HTTPS_URL \
    --internal-mcp-url HTTPS_URL \
    --pioneer-mcp-url HTTPS_URL \
    --standard-team TEAM_SLUG \
    --pioneer-team TEAM_SLUG \
    [--create-repository] [--apply-ruleset] \
    [--apply --confirm ORGANIZATION/.github-private]

OPTIONS
  --create-repository  Opt in to creating the governance repository on apply.
  --apply-ruleset      Opt in to importing the included ruleset on apply.
  --apply              Execute only the explicitly opted-in REST operations.
  --confirm VALUE      Must exactly equal ORGANIZATION/REPOSITORY with --apply.
  --help               Show this help.

The script never creates an enterprise and never changes enterprise AI
Controls. Select the governance source in Enterprise > AI controls > Agents >
Configuration source after the reviewed repository is ready.
EOF
}

ENTERPRISE=""
ORGANIZATION=""
GOVERNANCE_REPO=""
GOVERNANCE_REF=""
OTLP_ENDPOINT=""
INTERNAL_MCP_URL=""
PIONEER_MCP_URL=""
STANDARD_TEAM=""
PIONEER_TEAM=""
CONFIRM=""
APPLY=false
CREATE_REPOSITORY=false
APPLY_RULESET=false

require_value() {
  [[ $# -ge 2 && -n "${2:-}" && "${2:-}" != --* ]] || {
    printf 'ERROR: %s requires a value\n' "$1" >&2
    exit 1
  }
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --enterprise) require_value "$@"; ENTERPRISE="$2"; shift 2 ;;
    --organization) require_value "$@"; ORGANIZATION="$2"; shift 2 ;;
    --governance-repo) require_value "$@"; GOVERNANCE_REPO="$2"; shift 2 ;;
    --governance-ref) require_value "$@"; GOVERNANCE_REF="$2"; shift 2 ;;
    --otlp-endpoint) require_value "$@"; OTLP_ENDPOINT="$2"; shift 2 ;;
    --internal-mcp-url) require_value "$@"; INTERNAL_MCP_URL="$2"; shift 2 ;;
    --pioneer-mcp-url) require_value "$@"; PIONEER_MCP_URL="$2"; shift 2 ;;
    --standard-team) require_value "$@"; STANDARD_TEAM="$2"; shift 2 ;;
    --pioneer-team) require_value "$@"; PIONEER_TEAM="$2"; shift 2 ;;
    --confirm) require_value "$@"; CONFIRM="$2"; shift 2 ;;
    --create-repository) CREATE_REPOSITORY=true; shift ;;
    --apply-ruleset) APPLY_RULESET=true; shift ;;
    --apply) APPLY=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

for required in \
  ENTERPRISE ORGANIZATION GOVERNANCE_REPO GOVERNANCE_REF OTLP_ENDPOINT \
  INTERNAL_MCP_URL PIONEER_MCP_URL STANDARD_TEAM PIONEER_TEAM; do
  [[ -n "${!required}" ]] || {
    printf 'ERROR: %s is required\n' "$required" >&2
    exit 1
  }
done

command -v node >/dev/null 2>&1 || {
  printf 'ERROR: Node.js 22 or newer is required\n' >&2
  exit 1
}
node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 22 ? 0 : 1)' || {
  printf 'ERROR: Node.js 22 or newer is required\n' >&2
  exit 1
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
EXPECTED_CONFIRM="${ORGANIZATION}/${GOVERNANCE_REPO}"
API_VERSION="2026-03-10"

render_args=(
  --enterprise "${ENTERPRISE}"
  --organization "${ORGANIZATION}"
  --governance-repo "${GOVERNANCE_REPO}"
  --governance-ref "${GOVERNANCE_REF}"
  --otlp-endpoint "${OTLP_ENDPOINT}"
  --internal-mcp-url "${INTERNAL_MCP_URL}"
  --pioneer-mcp-url "${PIONEER_MCP_URL}"
  --standard-team "${STANDARD_TEAM}"
  --pioneer-team "${PIONEER_TEAM}"
)

printf 'Mode: %s\n' "$([[ "${APPLY}" == true ]] && printf APPLY || printf DRY-RUN)"
printf 'Enterprise: %s\nGovernance source: %s\n' "${ENTERPRISE}" "${EXPECTED_CONFIRM}"
printf 'Requested REST operations:\n'
printf '  create repository: %s\n  import ruleset: %s\n' "${CREATE_REPOSITORY}" "${APPLY_RULESET}"
printf 'UI-only follow-up: select %s under AI controls > Agents > Configuration source.\n' "${ORGANIZATION}"

if [[ "${APPLY}" == true ]]; then
  [[ "${CONFIRM}" == "${EXPECTED_CONFIRM}" ]] || {
    printf 'ERROR: --confirm must exactly equal %s\n' "${EXPECTED_CONFIRM}" >&2
    exit 1
  }
  command -v gh >/dev/null 2>&1 || {
    printf 'ERROR: gh CLI is required for --apply\n' >&2
    exit 1
  }
  gh auth status >/dev/null
  gh api /user -H "X-GitHub-Api-Version: ${API_VERSION}" --silent
  node "${SCRIPT_DIR}/render-managed-settings.mjs" "${render_args[@]}"
else
  node "${SCRIPT_DIR}/render-managed-settings.mjs" "${render_args[@]}" --validate-only
fi

node "${SCRIPT_DIR}/validate-governance.mjs"

if [[ "${APPLY}" != true ]]; then
  printf 'DRY-RUN: no GitHub mutation executed. Re-run with --apply and exact --confirm after review.\n'
  exit 0
fi

if [[ "${CREATE_REPOSITORY}" == true ]]; then
  if gh api "/repos/${ORGANIZATION}/${GOVERNANCE_REPO}" \
      -H "X-GitHub-Api-Version: ${API_VERSION}" --silent 2>/dev/null; then
    printf 'Repository already exists; create skipped.\n'
  else
    gh api -X POST "/orgs/${ORGANIZATION}/repos" \
      -H "X-GitHub-Api-Version: ${API_VERSION}" \
      -f name="${GOVERNANCE_REPO}" \
      -F private=true \
      -f description='Enterprise Copilot governance source'
  fi
fi

if [[ "${APPLY_RULESET}" == true ]]; then
  gh api -X POST "/repos/${ORGANIZATION}/${GOVERNANCE_REPO}/rulesets" \
    -H "X-GitHub-Api-Version: ${API_VERSION}" \
    --input "${ROOT}/.github/rulesets/governance-branch-protect.json"
fi

printf 'Apply complete. Commit the rendered config/ and copilot/ outputs through the protected review flow.\n'
