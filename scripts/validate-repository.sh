#!/usr/bin/env bash
# Validates repository-owned agent, workflow, shell, JSON, and Terraform files.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

failures=0
fail() {
  printf 'ERROR: %s\n' "$*" >&2
  failures=$((failures + 1))
}

for tool in actionlint shellcheck jq node npm; do
  command -v "${tool}" >/dev/null 2>&1 || fail "Required tool '${tool}' is not on PATH"
done
[[ "${failures}" -eq 0 ]] || exit 1

workflow_list="$(mktemp "${TMPDIR:-/tmp}/workflow-list.XXXXXX")"
json_list="$(mktemp "${TMPDIR:-/tmp}/json-list.XXXXXX")"
shell_list="$(mktemp "${TMPDIR:-/tmp}/shell-list.XXXXXX")"
trap 'rm -f "${workflow_list}" "${json_list}" "${shell_list}"' EXIT

{
  find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \) -print
  find examples -type f \( -name '*.yml' -o -name '*.yaml' \) \
    -path '*/.github/workflows/*' -print
} > "${workflow_list}"
if ! xargs actionlint < "${workflow_list}"; then
  fail "actionlint reported invalid workflows"
fi

find scripts -type f -name '*.sh' -print > "${shell_list}"
find .github/hooks/scripts -type f -name '*.sh' -print >> "${shell_list}"
find examples -type f -name '*.sh' -print >> "${shell_list}"
if ! xargs shellcheck < "${shell_list}"; then
  fail "ShellCheck reported shell script issues"
fi

if ! ./scripts/tests/azure-oidc.test.sh; then
  fail "Azure OIDC offline tests failed"
fi

if ! ./scripts/tests/doctor.test.sh; then
  fail "Doctor fixture tests failed"
fi

if ! ./scripts/tests/hook.test.sh; then
  fail "Lifecycle hook fixture tests failed"
fi

if ! npm --prefix tools/harness test; then
  fail "Agent harness unit and fixture tests failed"
fi

if ! npm --prefix tools/harness run validate; then
  fail "Agent harness repository validation failed"
fi

if [[ -f examples/enterprise-governance/package.json ]] &&
   ! npm --prefix examples/enterprise-governance test; then
  fail "Enterprise governance overlay tests failed"
fi

find . \
  \( -path './.git' -o -path '*/node_modules' -o -path '*/.terraform' \) -prune \
  -o \( -path './.devcontainer/devcontainer.json' -o -path './.vscode/settings.json' \) -prune \
  -o -type f -name '*.json' -print > "${json_list}"
while IFS= read -r file; do
  jq empty "${file}" || fail "Invalid JSON: ${file}"
done < "${json_list}"

while IFS= read -r workflow; do
  while IFS= read -r uses_line; do
    printf '%s\n' "${uses_line}" |
      grep -Eq 'uses:[[:space:]]*[^[:space:]#]+@[0-9a-fA-F]{40}[[:space:]]+#[[:space:]]+v?[0-9]+(\.[0-9]+){0,2}([^[:space:]]*)?[[:space:]]*$' ||
      fail "${workflow}: action reference must use a full SHA and human version comment: ${uses_line}"
  done < <(grep -E '^[[:space:]]*#?[[:space:]]*-?[[:space:]]*uses:' "${workflow}" || true)
done < "${workflow_list}"

lockfiles_found=0
while IFS= read -r lockfile; do
  lockfiles_found=$((lockfiles_found + 1))
  if grep -q 'registry\.opentofu\.org' "${lockfile}"; then
    fail "${lockfile}: OpenTofu registry entries are forbidden in Terraform-owned lockfiles"
  fi
  grep -q 'registry\.terraform\.io' "${lockfile}" ||
    fail "${lockfile}: expected registry.terraform.io provider entries"
done < <(find infra examples -type f -name '.terraform.lock.hcl' -print)
[[ "${lockfiles_found}" -gt 0 ]] || fail "No Terraform lockfiles found"

if [[ "${failures}" -ne 0 ]]; then
  printf '%s repository validation failure(s)\n' "${failures}" >&2
  exit 1
fi

echo "Repository agent surfaces, workflows, shell scripts, JSON, action pins, and Terraform lockfiles are valid."
