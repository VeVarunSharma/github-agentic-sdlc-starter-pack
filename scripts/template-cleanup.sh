#!/usr/bin/env bash
# scripts/template-cleanup.sh
# Replaces starter-pack placeholders in the repository's maintained text files.
#
# Usage:
#   ./scripts/template-cleanup.sh \
#     --owner acme-corp \
#     --repo platform-api \
#     [--team @acme-corp/platform-team] \
#     [--email security@acme-corp.example] \
#     [--dry-run]
set -euo pipefail

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
  BLUE=$'\033[34m'; RESET=$'\033[0m'
else
  BOLD=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi

info() { printf "%s▶%s %s\n" "${BLUE}" "${RESET}" "$*"; }
ok()   { printf "%s✓%s %s\n" "${GREEN}" "${RESET}" "$*"; }
warn() { printf "%s⚠%s %s\n" "${YELLOW}" "${RESET}" "$*" >&2; }
fail() { printf "%s✗%s %s\n" "${RED}" "${RESET}" "$*" >&2; exit 1; }

OWNER=""
REPO=""
TEAM=""
EMAIL=""
DRY_RUN=false

usage() {
  sed -n '2,11p' "$0" | sed 's|^# \{0,1\}||'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner)   [[ $# -ge 2 ]] || fail "--owner requires a value"; OWNER="$2"; shift 2 ;;
    --repo)    [[ $# -ge 2 ]] || fail "--repo requires a value"; REPO="$2"; shift 2 ;;
    --team)    [[ $# -ge 2 ]] || fail "--team requires a value"; TEAM="$2"; shift 2 ;;
    --email)   [[ $# -ge 2 ]] || fail "--email requires a value"; EMAIL="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *)         fail "Unknown argument: $1 (try --help)" ;;
  esac
done

[[ -n "${OWNER}" ]] || fail "--owner required"
[[ -n "${REPO}" ]] || fail "--repo required"

contains_forbidden_delimiter() {
  case "$1" in
    *'|'*) return 0 ;;
    *) return 1 ;;
  esac
}

valid_owner() {
  [[ ${#1} -le 39 ]] &&
    printf '%s\n' "$1" | LC_ALL=C grep -Eq '^[A-Za-z0-9]([A-Za-z0-9]|-[A-Za-z0-9])*$'
}

valid_repo() {
  [[ ${#1} -le 100 ]] &&
    [[ "$1" != "." && "$1" != ".." ]] &&
    printf '%s\n' "$1" | LC_ALL=C grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$'
}

valid_team_slug() {
  [[ ${#1} -le 100 ]] &&
    printf '%s\n' "$1" | LC_ALL=C grep -Eq '^[a-z0-9]([a-z0-9]|-[a-z0-9])*$'
}

valid_email() {
  printf '%s\n' "$1" | LC_ALL=C grep -Eq \
    "^[A-Za-z0-9.!#\$%&'*+/=?^_\`{}~-]+@[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$"
}

valid_owner "${OWNER}" || fail "--owner must be at most 39 characters and contain only alphanumerics or single hyphens"
valid_repo "${REPO}" || fail "--repo must be a safe GitHub repository name (1-100 alphanumerics, '.', '_', or '-')"

if [[ -z "${TEAM}" ]]; then
  default_slug="$(printf '%s-maintainers' "${REPO}" | tr '[:upper:]_.' '[:lower:]--')"
  TEAM="@${OWNER}/${default_slug}"
fi

case "${TEAM}" in
  @"${OWNER}"/*) TEAM_NO_AT="${TEAM#@}"; TEAM_SLUG="${TEAM#@"${OWNER}"/}" ;;
  *) fail "--team must use the form @${OWNER}/lowercase-team and match --owner" ;;
esac
valid_team_slug "${TEAM_SLUG}" || fail "--team slug must contain only lowercase alphanumerics or single hyphens"

if [[ -n "${EMAIL}" ]]; then
  valid_email "${EMAIL}" || fail "--email must be a valid email address"
fi

for value in "${OWNER}" "${REPO}" "${TEAM}" "${EMAIL}"; do
  contains_forbidden_delimiter "${value}" && fail "Input values must not contain the sed delimiter '|'"
done

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${TEMPLATE_ROOT:-$(cd -- "${SCRIPT_DIR}/.." && pwd)}"
cd "${REPO_ROOT}"

MARKER_FILE=".github/.template-cleanup-applied"
if [[ -f "${MARKER_FILE}" ]]; then
  warn "Marker file '${MARKER_FILE}' already exists; cleanup has already been applied."
  warn "Delete the marker file and re-run only if you intend to re-apply cleanup."
  exit 0
fi

info "Replacements:"
printf '  <owner>/<repo>            -> %s/%s\n' "${OWNER}" "${REPO}"
printf '  <owner>/<team>            -> %s\n' "${TEAM_NO_AT}"
printf '  @<owner>/<team>           -> %s\n' "${TEAM}"
printf '  <owner>                   -> %s\n' "${OWNER}"
printf '  <repo>                    -> %s\n' "${REPO}"
if [[ -n "${EMAIL}" ]]; then
  printf '  <security-contact-email>  -> %s\n' "${EMAIL}"
  printf '  <contact-email>           -> %s\n' "${EMAIL}"
else
  warn "No --email provided; contact email placeholders will remain unchanged"
fi

render_file() {
  local source="$1"
  if [[ -n "${EMAIL}" ]]; then
    sed \
      -e "s|<owner>/<repo>|${OWNER}/${REPO}|g" \
      -e "s|@<owner>/<team>|${TEAM}|g" \
      -e "s|<owner>/<team>|${TEAM_NO_AT}|g" \
      -e "s|<security-contact-email>|${EMAIL}|g" \
      -e "s|<contact-email>|${EMAIL}|g" \
      -e "s|<owner>|${OWNER}|g" \
      -e "s|<repo>|${REPO}|g" \
      "${source}"
  else
    sed \
      -e "s|<owner>/<repo>|${OWNER}/${REPO}|g" \
      -e "s|@<owner>/<team>|${TEAM}|g" \
      -e "s|<owner>/<team>|${TEAM_NO_AT}|g" \
      -e "s|<owner>|${OWNER}|g" \
      -e "s|<repo>|${REPO}|g" \
      "${source}"
  fi
}

file_list="$(mktemp "${TMPDIR:-/tmp}/template-cleanup-files.XXXXXX")"
trap 'rm -f "${file_list}"' EXIT

find . \
  \( -path './.git' \
     -o -path './node_modules' \
     -o -path '*/.terraform' \
     -o -path './apm_modules' \
     -o -path './.agents' \
     -o -path './.github/instructions' \
     -o -path './.github/skills' \
     -o -path "./${MARKER_FILE}" \) -prune \
  -o -type f \( \
       -name '*.md' \
    -o -name '*.json' \
    -o -name '*.yml' \
    -o -name '*.yaml' \
    -o -name '*.tf' \
    -o -name '*.tfvars.example' \
    -o -name 'CODEOWNERS' \
    -o -name 'LICENSE' \
  \) -print > "${file_list}"

changed=0
while IFS= read -r file; do
  grep -Eq '<owner>|<repo>|<owner>/<team>|<security-contact-email>|<contact-email>' "${file}" || continue
  rendered="$(mktemp "${TMPDIR:-/tmp}/template-cleanup-rendered.XXXXXX")"
  render_file "${file}" > "${rendered}"
  if cmp -s "${file}" "${rendered}"; then
    rm -f "${rendered}"
    continue
  fi

  changed=$((changed + 1))
  if [[ "${DRY_RUN}" == "true" ]]; then
    diff -u "${file}" "${rendered}" || true
    rm -f "${rendered}"
  else
    mv "${rendered}" "${file}"
  fi
done < "${file_list}"

if [[ "${DRY_RUN}" == "true" ]]; then
  ok "Dry-run preview complete: ${changed} file(s) would change; no files were modified"
  exit 0
fi

mkdir -p "$(dirname "${MARKER_FILE}")"
{
  echo "# Template cleanup applied"
  echo "# Run ID: ${TEMPLATE_CLEANUP_RUN_ID:-local}"
  echo "# Actor: ${TEMPLATE_CLEANUP_ACTOR:-$(id -un)}"
  echo "# Date: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
} > "${MARKER_FILE}"

ok "Updated ${changed} file(s); marker written to ${MARKER_FILE}"
printf '\n%sNext steps%s\n' "${BOLD}" "${RESET}"
echo "  1. Review the diff: git diff"
echo "  2. Commit: git add -A && git commit -s -m 'chore: apply template cleanup'"
echo "  3. Run scripts/setup-azure-oidc.sh to wire up the Azure deploy identity"
