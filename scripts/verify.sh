#!/usr/bin/env bash
# scripts/verify.sh
# ─────────────────────────────────────────────────────────────────────────────
# Local smoke test. Runs every read-only check that CI runs:
#   - app:    npm ci, lint, test, production dependency audit
#   - infra:  Terraform fmt -check + validate (all three owned roots)
#   - repo:   workflows, shell, JSON, action pins, and Terraform lockfiles
#   - docker: build + running /health smoke test
#   - apm:    frozen install + CI policy audit (if APM is installed)
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

# ── App: npm lint + test + audit ─────────────────────────────────────────────
echo ""
info "${BOLD}App${RESET} (Node.js, ${REPO_ROOT}/app)"

if [[ ! -f app/package.json ]]; then
  warn "Skipping app checks — app/package.json not found"
  SKIPS=$((SKIPS + 1))
elif need npm; then
  info "Installing dependencies (npm ci)"
  npm --prefix app ci || { ERRORS=$((ERRORS + 1)); warn "npm ci failed"; }
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
    if npm --prefix app audit --omit=dev --audit-level=high; then
      ok "Production dependency audit clean"
    else
      ERRORS=$((ERRORS + 1)); warn "Production dependency audit failed"
    fi
  fi
fi

# ── Infra: terraform fmt + validate ──────────────────────────────────────────
for tf_dir in infra/bootstrap infra/app examples/azure-container-apps/infra/app; do
  echo ""
  info "${BOLD}Infra${RESET} (${tf_dir})"
  if [[ ! -d "${tf_dir}" ]]; then
    warn "Skipping ${tf_dir} — directory missing"
    SKIPS=$((SKIPS + 1))
    continue
  fi
  if ! command -v terraform >/dev/null 2>&1; then
    if [[ "${STRICT}" == "true" ]]; then fail "Required tool 'terraform' not found"; fi
    warn "Skipping ${tf_dir} — HashiCorp Terraform is not on PATH"
    SKIPS=$((SKIPS + 1))
    continue
  fi
  if terraform -chdir="${tf_dir}" fmt -check -recursive >/dev/null; then
    ok "${tf_dir}: fmt clean"
  else
    ERRORS=$((ERRORS + 1)); warn "${tf_dir}: fmt drift (run 'terraform -chdir=${tf_dir} fmt -recursive')"
  fi
  # validate requires init; init without backend is sufficient for syntax check
  if ! terraform -chdir="${tf_dir}" init -backend=false -input=false >/dev/null 2>&1; then
    ERRORS=$((ERRORS + 1)); warn "${tf_dir}: terraform init failed"
    continue
  fi
  if terraform -chdir="${tf_dir}" validate >/dev/null; then
    ok "${tf_dir}: validate clean"
  else
    ERRORS=$((ERRORS + 1)); warn "${tf_dir}: validate failed"
  fi
done

# ── Repository maintenance surfaces ──────────────────────────────────────────
echo ""
info "${BOLD}Repository${RESET} (workflows, shell, JSON, lockfiles)"
if command -v actionlint >/dev/null 2>&1 &&
   command -v shellcheck >/dev/null 2>&1 &&
   command -v jq >/dev/null 2>&1; then
  if ./scripts/validate-repository.sh; then
    ok "Repository maintenance surfaces clean"
  else
    ERRORS=$((ERRORS + 1)); warn "Repository maintenance validation failed"
  fi
else
  if [[ "${STRICT}" == "true" ]]; then
    fail "Required repository validators actionlint, shellcheck, and jq must be on PATH"
  fi
  warn "Skipping repository validation — actionlint, shellcheck, and jq are all required"
  SKIPS=$((SKIPS + 1))
fi

# ── Docker build + running health smoke ──────────────────────────────────────
echo ""
info "${BOLD}Docker${RESET} (build + /health)"
if command -v docker >/dev/null 2>&1; then
  image="agentic-sdlc-sample-app:local-verify"
  container="agentic-sdlc-verify-$$"
  if docker build --quiet --tag "${image}" app >/dev/null &&
     docker run --detach --rm --name "${container}" --publish 127.0.0.1::3000 "${image}" >/dev/null; then
    port="$(docker port "${container}" 3000/tcp | awk -F: 'NR == 1 { print $NF }')"
    healthy=false
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      if curl --fail --silent "http://127.0.0.1:${port}/health" | grep -q '"status":"ok"'; then
        healthy=true
        break
      fi
      sleep 2
    done
    docker rm --force "${container}" >/dev/null 2>&1 || true
    if [[ "${healthy}" == "true" ]]; then
      ok "Docker image builds and /health responds"
    else
      ERRORS=$((ERRORS + 1)); warn "Docker /health smoke test failed"
    fi
  else
    docker rm --force "${container}" >/dev/null 2>&1 || true
    ERRORS=$((ERRORS + 1)); warn "Docker build or startup failed"
  fi
else
  if [[ "${STRICT}" == "true" ]]; then fail "Required tool 'docker' not found"; fi
  warn "Skipping Docker build and health smoke — docker is not on PATH"
  SKIPS=$((SKIPS + 1))
fi

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
  if apm install --target copilot &&
     apm install --frozen --target copilot &&
     apm audit --ci --policy ./apm-policy.yml; then
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
