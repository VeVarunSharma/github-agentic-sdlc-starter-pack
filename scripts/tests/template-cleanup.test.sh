#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/../template-cleanup.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/template-cleanup-test.XXXXXX")"
trap 'rm -rf "${TEST_ROOT}"' EXIT

new_fixture() {
  local root="$1"
  mkdir -p "${root}/.github"
  cat > "${root}/README.md" <<'EOF'
Repository: <owner>/<repo>
Team: @<owner>/<team>
Security: <security-contact-email>
EOF
  cat > "${root}/package.json" <<'EOF'
{"repository":"<owner>/<repo>"}
EOF
}

fixture="${TEST_ROOT}/valid"
new_fixture "${fixture}"
TEMPLATE_ROOT="${fixture}" "${SCRIPT}" \
  --owner acme-corp \
  --repo platform-api \
  --team @acme-corp/platform-team \
  --email security@acme.example >/dev/null
grep -q 'Repository: acme-corp/platform-api' "${fixture}/README.md"
grep -q 'Team: @acme-corp/platform-team' "${fixture}/README.md"
grep -q 'Security: security@acme.example' "${fixture}/README.md"
test -f "${fixture}/.github/.template-cleanup-applied"

fixture="${TEST_ROOT}/dry-run"
new_fixture "${fixture}"
before="$(shasum -a 256 "${fixture}/README.md" | awk '{print $1}')"
preview="$(
  TEMPLATE_ROOT="${fixture}" "${SCRIPT}" \
    --owner acme-corp \
    --repo platform-api \
    --team @acme-corp/platform-team \
    --dry-run
)"
after="$(shasum -a 256 "${fixture}/README.md" | awk '{print $1}')"
[[ "${before}" == "${after}" ]]
[[ ! -e "${fixture}/.github/.template-cleanup-applied" ]]
printf '%s\n' "${preview}" | grep -q 'acme-corp/platform-api'

expect_rejected() {
  local name="$1"
  shift
  local root="${TEST_ROOT}/${name}"
  new_fixture "${root}"
  if TEMPLATE_ROOT="${root}" "${SCRIPT}" "$@" >/dev/null 2>&1; then
    echo "Expected invalid input to be rejected: ${name}" >&2
    exit 1
  fi
  grep -q '<owner>/<repo>' "${root}/README.md"
  [[ ! -e "${root}/.github/.template-cleanup-applied" ]]
}

expect_rejected owner-injection --owner 'acme|s/x/y/' --repo platform-api
expect_rejected owner-shape --owner 'acme--corp' --repo platform-api
expect_rejected repo-injection --owner acme-corp --repo '../platform'
expect_rejected team-mismatch --owner acme-corp --repo platform-api --team @other/platform-team
expect_rejected team-shape --owner acme-corp --repo platform-api --team @acme-corp/Platform_Team
expect_rejected email-injection --owner acme-corp --repo platform-api --email 'security@example.com|x'

echo "template-cleanup tests passed"
