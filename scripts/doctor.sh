#!/usr/bin/env bash
# Read-only environment diagnostics for the starter pack.
#
# Usage: ./scripts/doctor.sh [--strict] [--cloud] [--help]
#   --strict  Exit non-zero for missing required tools or unresolved placeholders.
#   --cloud   Also inspect gh/az authentication and required repository settings.
set -u

STRICT=false
CLOUD=false
for arg in "$@"; do
  case "${arg}" in
    --strict) STRICT=true ;;
    --cloud) CLOUD=true ;;
    -h|--help)
      sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) printf 'ERROR: unknown argument: %s\n' "${arg}" >&2; exit 2 ;;
  esac
done

ROOT="${DOCTOR_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
REQUIRED_TOOLS="${DOCTOR_REQUIRED_TOOLS-git node npm terraform apm docker}"
CLOUD_VARIABLES="${DOCTOR_CLOUD_VARIABLES-AZURE_PLAN_CLIENT_ID AZURE_APPLY_CLIENT_ID AZURE_DEPLOY_CLIENT_ID AZURE_DEPLOY_PRINCIPAL_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID AZURE_RESOURCE_GROUP AZURE_TFSTATE_RG AZURE_TFSTATE_STORAGE_ACCOUNT AZURE_TFSTATE_CONTAINER AZURE_ACR_NAME AZURE_WEBAPP_NAME AZURE_LOCATION AZURE_REGION_SHORT AZURE_ENVIRONMENT AZURE_WORKLOAD_NAME AZURE_OIDC_SUBJECT_MODE}"
failures=0
warnings=0

pass() { printf 'PASS: %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; warnings=$((warnings + 1)); }
fail() { printf 'FAIL: %s\n' "$*" >&2; failures=$((failures + 1)); }
report_problem() {
  if [[ "${STRICT}" == "true" ]]; then fail "$*"; else warn "$*"; fi
}

printf 'Agentic SDLC doctor\nRoot: %s\nMode: %s%s\n\n' \
  "${ROOT}" \
  "$([[ "${STRICT}" == "true" ]] && printf strict || printf normal)" \
  "$([[ "${CLOUD}" == "true" ]] && printf '+cloud' || true)"

for tool in ${REQUIRED_TOOLS}; do
  if command -v "${tool}" >/dev/null 2>&1; then
    version="$("${tool}" --version 2>&1 | head -1)"
    pass "${tool}: ${version}"
  else
    report_problem "required tool '${tool}' is not on PATH"
  fi
done

if git -C "${ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch="$(git -C "${ROOT}" branch --show-current)"
  dirty="$(git -C "${ROOT}" status --porcelain)"
  pass "git repository on branch ${branch:-detached}"
  if [[ -n "${dirty}" ]]; then warn "git worktree has uncommitted changes"; fi
  if git -C "${ROOT}" diff --quiet -- apm.lock.yaml .github/instructions .agents/skills; then
    pass "no tracked APM generated-file drift"
  else
    report_problem "tracked APM-managed files differ from the index"
  fi
else
  report_problem "${ROOT} is not a git worktree"
fi

placeholder_output=""
if git -C "${ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  placeholder_output="$(git -C "${ROOT}" grep -n -E '<(owner|repo|team|contact-email|security-contact-email)>' -- . ':!docs/spike-*' 2>/dev/null || true)"
else
  placeholder_output="$(grep -R -n -E '<(owner|repo|team|contact-email|security-contact-email)>' "${ROOT}" 2>/dev/null || true)"
fi
if [[ -n "${placeholder_output}" ]]; then
  report_problem "unresolved template placeholders found"
  printf '%s\n' "${placeholder_output}" | head -20
else
  pass "no unresolved template placeholders"
fi

if command -v npm >/dev/null 2>&1 && [[ -f "${ROOT}/app/package.json" ]]; then
  if npm --prefix "${ROOT}/app" test --silent >/dev/null; then
    pass "app quick tests"
  else
    fail "app quick tests failed"
  fi
fi

if command -v npm >/dev/null 2>&1 && [[ -f "${ROOT}/tools/harness/package.json" ]]; then
  if npm --prefix "${ROOT}/tools/harness" run validate --silent >/dev/null; then
    pass "agent harness validation"
  else
    fail "agent harness validation failed"
  fi
fi

if [[ "${CLOUD}" == "true" ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    report_problem "gh is required for --cloud"
  elif ! gh auth status >/dev/null 2>&1; then
    report_problem "gh authentication is unavailable"
  else
    pass "gh authentication"
    repo="$(cd "${ROOT}" && gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
    if [[ -z "${repo}" ]]; then
      report_problem "cannot resolve GitHub repository"
    else
      variables="$(gh variable list -R "${repo}" --json name --jq '.[].name' 2>/dev/null || true)"
      for required in ${CLOUD_VARIABLES}; do
        if printf '%s\n' "${variables}" | grep -qx "${required}"; then
          pass "repository variable ${required}"
        else
          report_problem "repository variable ${required} is missing"
        fi
      done
      gh api "repos/${repo}/environments" >/dev/null 2>&1 ||
        report_problem "cannot read repository environments"
      gh api "repos/${repo}/actions/permissions/workflow" >/dev/null 2>&1 ||
        report_problem "cannot read Actions workflow permissions"
    fi
  fi

  if ! command -v az >/dev/null 2>&1; then
    report_problem "az is required for --cloud"
  elif az account show >/dev/null 2>&1; then
    pass "Azure CLI authentication"
  else
    report_problem "Azure CLI authentication is unavailable"
  fi
fi

printf '\nDoctor complete: %s failure(s), %s warning(s).\n' "${failures}" "${warnings}"
[[ "${failures}" -eq 0 ]]
