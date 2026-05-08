#!/usr/bin/env bash
# scripts/verify.sh
# ─────────────────────────────────────────────────────────────────────────────
# Local smoke test. Runs every read-only check that CI runs:
#   - app:    npm ci, lint, test
#   - infra:  terraform fmt -check + validate (bootstrap + app)
#   - apm:    apm audit (if APM is installed)
#
# Skips any check whose tool is missing (warns instead of failing) so the
# script Just Works on a fresh clone with whatever tooling is present.
# Returns non-zero only if a tool that IS present reports an error.
#
# Usage: ./scripts/verify.sh [--strict] [--help]
#   --strict   Fail (instead of warn) when a required tool is missing
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
  BLUE=$'\033[34m'; RESET=$'\033[0m'
else
  BOLD=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi

info()  { printf "%s▶%s %s\n"  "${BLUE}"   "${RESET}" "$*"; }
ok()    { printf "%s✓%s %s\n"  "${GREEN}"  "${RESET}" "$*"; }
warn()  { printf "%s⚠%s %s\n"  "${YELLOW}" "${RESET}" "$*" >&2; }
fail()  { printf "%s✗%s %s\n"  "${RED}"    "${RESET}" "$*" >&2; exit 1; }

STRICT=false
for arg in "$@"; do
  case "${arg}" in
    --strict) STRICT=true ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's|^# \{0,1\}||'
      exit 0
      ;;
    *) fail "Unknown argument: ${arg} (try --help)" ;;
  esac
done

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

ERRORS=0
SKIPS=0

# Tool presence helper — returns 0 if present, 1 if missing (and warns/fails)
need() {
  local tool="$1"
  if command -v "${tool}" >/dev/null 2>&1; then return 0; fi
  if [[ "${STRICT}" == "true" ]]; then
    fail "Required tool '${tool}' not found"
  fi
  warn "Skipping checks that need '${tool}' (not on PATH)"
  SKIPS=$((SKIPS + 1))
  return 1
}

# ── App: npm lint + test ─────────────────────────────────────────────────────
echo ""
info "${BOLD}App${RESET} (Node.js, ${REPO_ROOT}/app)"

if [[ ! -f app/package.json ]]; then
  warn "Skipping app checks — app/package.json not found"
  SKIPS=$((SKIPS + 1))
elif need npm; then
  if [[ ! -d app/node_modules ]]; then
    info "Installing dependencies (npm ci)"
    npm --prefix app ci || { ERRORS=$((ERRORS + 1)); warn "npm ci failed"; }
  fi
  if [[ "${ERRORS}" -eq 0 ]]; then
    if npm --prefix app run lint --silent 2>/dev/null; then
      ok "Lint clean"
    else
      ERRORS=$((ERRORS + 1)); warn "Lint failed"
    fi
    if npm --prefix app test --silent; then
      ok "Tests pass"
    else
      ERRORS=$((ERRORS + 1)); warn "Tests failed"
    fi
  fi
fi

# ── Infra: terraform fmt + validate ──────────────────────────────────────────
TF_BIN=""
if   command -v terraform >/dev/null 2>&1; then TF_BIN="terraform"
elif command -v tofu      >/dev/null 2>&1; then TF_BIN="tofu"
fi

for tf_dir in infra/bootstrap infra/app; do
  echo ""
  info "${BOLD}Infra${RESET} (${tf_dir})"
  if [[ ! -d "${tf_dir}" ]]; then
    warn "Skipping ${tf_dir} — directory missing"
    SKIPS=$((SKIPS + 1))
    continue
  fi
  if [[ -z "${TF_BIN}" ]]; then
    if [[ "${STRICT}" == "true" ]]; then
      fail "Required tool 'terraform' (or 'tofu') not found"
    fi
    warn "Skipping ${tf_dir} — neither terraform nor tofu on PATH"
    SKIPS=$((SKIPS + 1))
    continue
  fi
  if "${TF_BIN}" -chdir="${tf_dir}" fmt -check -recursive >/dev/null; then
    ok "${tf_dir}: fmt clean"
  else
    ERRORS=$((ERRORS + 1)); warn "${tf_dir}: fmt drift (run '${TF_BIN} -chdir=${tf_dir} fmt -recursive')"
  fi
  # validate requires init; init without backend is sufficient for syntax check
  if ! "${TF_BIN}" -chdir="${tf_dir}" init -backend=false -input=false >/dev/null 2>&1; then
    ERRORS=$((ERRORS + 1)); warn "${tf_dir}: terraform init failed"
    continue
  fi
  if "${TF_BIN}" -chdir="${tf_dir}" validate >/dev/null; then
    ok "${tf_dir}: validate clean"
  else
    ERRORS=$((ERRORS + 1)); warn "${tf_dir}: validate failed"
  fi
done

# ── APM audit (optional, only if APM is installed) ───────────────────────────
echo ""
info "${BOLD}APM${RESET} (supplementary)"
if [[ ! -f apm.yml ]]; then
  warn "Skipping APM audit — no apm.yml in repo root"
  SKIPS=$((SKIPS + 1))
elif ! command -v apm >/dev/null 2>&1; then
  warn "Skipping APM audit — 'apm' CLI not on PATH (install: https://github.com/microsoft/apm)"
  SKIPS=$((SKIPS + 1))
else
  if apm audit --policy ./apm-policy.yml; then
    ok "APM audit clean"
  else
    ERRORS=$((ERRORS + 1)); warn "APM audit reported issues"
  fi
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
if [[ "${ERRORS}" -eq 0 ]]; then
  ok "${BOLD}All checks passed${RESET} (${SKIPS} skipped)"
  exit 0
else
  fail "${BOLD}${ERRORS} check(s) failed${RESET} (${SKIPS} skipped)"
fi
