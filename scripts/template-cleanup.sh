#!/usr/bin/env bash
# scripts/template-cleanup.sh
# ─────────────────────────────────────────────────────────────────────────────
# Local fallback for the .github/workflows/template-cleanup.yml workflow.
# Replaces the four template placeholders across the repo, then drops a
# marker file so the workflow won't re-run on the next push.
#
# Placeholders replaced:
#   <owner>/<repo>            → OWNER/REPO  (the new repo's owner & name)
#   <owner>/<team>            → CODEOWNER_TEAM (sans leading @)
#   @<owner>/<team>           → @CODEOWNER_TEAM
#   <owner>                   → OWNER  (catch-alls left over after the above)
#   <repo>                    → REPO
#   <security-contact-email>  → CONTACT_EMAIL (if --email provided)
#   <contact-email>           → CONTACT_EMAIL (if --email provided)
#
# Usage:
#   ./scripts/template-cleanup.sh \
#     --owner acme-corp \
#     --repo platform-api \
#     [--team @acme-corp/platform-team] \
#     [--email security@acme-corp.example] \
#     [--dry-run]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
  BLUE=$'\033[34m'; RESET=$'\033[0m'
else
  BOLD=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi

info() { printf "%s▶%s %s\n" "${BLUE}"   "${RESET}" "$*"; }
ok()   { printf "%s✓%s %s\n" "${GREEN}"  "${RESET}" "$*"; }
warn() { printf "%s⚠%s %s\n" "${YELLOW}" "${RESET}" "$*" >&2; }
fail() { printf "%s✗%s %s\n" "${RED}"    "${RESET}" "$*" >&2; exit 1; }

OWNER=""
REPO=""
TEAM=""
EMAIL=""
DRY_RUN=false

usage() {
  sed -n '2,24p' "$0" | sed 's|^# \{0,1\}||'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner)   OWNER="${2:-}"; shift 2 ;;
    --repo)    REPO="${2:-}";  shift 2 ;;
    --team)    TEAM="${2:-}";  shift 2 ;;
    --email)   EMAIL="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=true;   shift ;;
    -h|--help) usage; exit 0 ;;
    *)         fail "Unknown argument: $1 (try --help)" ;;
  esac
done

[[ -n "${OWNER}" ]] || fail "--owner required"
[[ -n "${REPO}"  ]] || fail "--repo required"

# Strip leading @ from team if present
TEAM_NO_AT="${TEAM#@}"
TEAM_DEFAULT="${OWNER}/${REPO%-*}-maintainers"   # sane default if --team omitted
[[ -n "${TEAM_NO_AT}" ]] || TEAM_NO_AT="${TEAM_DEFAULT}"

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

MARKER_FILE=".github/.template-cleanup-applied"
if [[ -f "${MARKER_FILE}" ]]; then
  warn "Marker file '${MARKER_FILE}' already exists — cleanup has already been applied."
  warn "Delete the marker file and re-run if you really want to re-apply."
  exit 0
fi

info "Replacements:"
echo "  <owner>/<repo>            → ${OWNER}/${REPO}"
echo "  <owner>/<team>            → ${TEAM_NO_AT}"
echo "  @<owner>/<team>           → @${TEAM_NO_AT}"
echo "  <owner>                   → ${OWNER}"
echo "  <repo>                    → ${REPO}"
if [[ -n "${EMAIL}" ]]; then
  echo "  <security-contact-email>  → ${EMAIL}"
  echo "  <contact-email>           → ${EMAIL}"
else
  warn "No --email provided; <security-contact-email> and <contact-email> left as-is"
fi

if [[ "${DRY_RUN}" == "true" ]]; then
  warn "Dry run — no files modified."
  exit 0
fi

# Cross-platform sed in-place: write to .bak then delete (works on BSD + GNU)
sed_inplace() {
  local file="$1"; shift
  sed "$@" "${file}" > "${file}.tmp" && mv "${file}.tmp" "${file}"
}

# Collect candidate files (text-ish, not in vendored dirs)
mapfile -t FILES < <(
  find . -type f \
    \( -path './.git' -o -path './node_modules' -o -path '*/.terraform' -o -path './apm_modules' -o -path './.agents' \) -prune -o \
    -type f \
    \( -name '*.md' -o -name '*.yml' -o -name '*.yaml' -o -name '*.json' \
       -o -name '*.tf' -o -name '*.tfvars*' -o -name '*.js' -o -name '*.mjs' \
       -o -name '*.sh' -o -name 'Dockerfile*' -o -name 'CODEOWNERS' \
       -o -name '.gitattributes' -o -name '.editorconfig' \) \
    -print
)

CHANGED=0
for f in "${FILES[@]}"; do
  if grep -qE '<owner>|<repo>|<owner>/<team>|<security-contact-email>|<contact-email>' "${f}"; then
    sed_inplace "${f}" \
      -e "s|<owner>/<repo>|${OWNER}/${REPO}|g" \
      -e "s|<owner>/<team>|${TEAM_NO_AT}|g" \
      -e "s|@<owner>/<team>|@${TEAM_NO_AT}|g" \
      -e "s|<owner>|${OWNER}|g" \
      -e "s|<repo>|${REPO}|g"
    if [[ -n "${EMAIL}" ]]; then
      sed_inplace "${f}" \
        -e "s|<security-contact-email>|${EMAIL}|g" \
        -e "s|<contact-email>|${EMAIL}|g"
    fi
    CHANGED=$((CHANGED + 1))
  fi
done

# Drop marker so the workflow's idempotency guard fires
mkdir -p "$(dirname "${MARKER_FILE}")"
{
  echo "# Created by scripts/template-cleanup.sh on $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo "# This file's presence prevents the template-cleanup workflow from re-running."
} > "${MARKER_FILE}"

ok "Updated ${CHANGED} file(s); marker written to ${MARKER_FILE}"
echo ""
echo "${BOLD}Next steps${RESET}"
echo "  1. Review the diff: git diff"
echo "  2. Commit: git add -A && git commit -s -m 'chore: apply template cleanup'"
echo "  3. Run scripts/setup-azure-oidc.sh to wire up the Azure deploy identity"
