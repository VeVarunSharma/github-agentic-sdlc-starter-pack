#!/usr/bin/env bash
# scripts/bootstrap.sh
# ─────────────────────────────────────────────────────────────────────────────
# One-shot orchestrator: installs project dependencies, runs the verify smoke
# test, and surfaces the next manual step (Azure OIDC bootstrap).
#
# Idempotent — safe to re-run. Does NOT touch Azure or GitHub. Use
# scripts/setup-azure-oidc.sh for that.
#
# Usage:
#   ./scripts/bootstrap.sh [--skip-apm] [--skip-app] [--help]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Colors (degrade if not a TTY) ────────────────────────────────────────────
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

# ── Args ─────────────────────────────────────────────────────────────────────
SKIP_APM=false
SKIP_APP=false

usage() {
  cat <<EOF
${BOLD}bootstrap.sh${RESET} — set up local working copy

Installs the optional APM dependency layer plus app and harness npm
dependencies, then runs the smoke test.

Usage: $0 [OPTIONS]

Options:
  --skip-apm    Skip 'apm install' (the APM layer is optional)
  --skip-app    Skip 'npm ci' in app/
  -h, --help    Show this help

Next steps after this script succeeds:
  1. Run scripts/setup-azure-oidc.sh once (requires az login + gh auth login)
  2. Open a PR and watch the CI gates run
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-apm) SKIP_APM=true; shift ;;
    --skip-app) SKIP_APP=true; shift ;;
    -h|--help)  usage; exit 0 ;;
    *)          fail "Unknown argument: $1 (try --help)" ;;
  esac
done

# ── Locate repo root ─────────────────────────────────────────────────────────
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

info "Repo root: ${REPO_ROOT}"

# ── APM (optional) ───────────────────────────────────────────────────────────
if [[ "${SKIP_APM}" == "true" ]]; then
  warn "Skipping 'apm install' (--skip-apm)"
elif ! command -v apm >/dev/null 2>&1; then
  warn "APM CLI not found — skipping (install: https://github.com/microsoft/apm)"
else
  info "Running 'apm install' (refreshes apm.lock.yaml + .github/{instructions,skills}/)"
  apm install
  ok "APM dependencies installed"
fi

# ── App dependencies ─────────────────────────────────────────────────────────
if [[ "${SKIP_APP}" == "true" ]]; then
  warn "Skipping 'npm ci' (--skip-app)"
elif ! command -v npm >/dev/null 2>&1; then
  warn "npm not found — skipping (install Node.js 22 from https://nodejs.org)"
elif [[ ! -f app/package.json ]]; then
  warn "app/package.json not found — nothing to install"
else
  info "Running 'npm ci' in app/"
  npm --prefix app ci
  ok "App dependencies installed"
fi

# ── Harness dependencies ──────────────────────────────────────────────────────
if ! command -v npm >/dev/null 2>&1; then
  warn "npm not found — skipping harness install"
elif [[ ! -f tools/harness/package.json ]]; then
  fail "tools/harness/package.json not found"
else
  info "Running 'npm ci' in tools/harness/"
  npm --prefix tools/harness ci
  ok "Harness dependencies installed"
fi

# ── Smoke test ───────────────────────────────────────────────────────────────
info "Running scripts/verify.sh"
"${REPO_ROOT}/scripts/verify.sh" || fail "verify.sh failed — see above for details"

ok "Bootstrap complete"
echo ""
echo "${BOLD}Next steps${RESET}"
echo "  1. Provision Azure OIDC identity (one-time, requires 'az login'):"
echo "       ./scripts/setup-azure-oidc.sh"
echo "  2. Import the evaluate-mode branch ruleset:"
echo "       gh api -X POST /repos/<owner>/<repo>/rulesets \\"
echo "         --input .github/rulesets/main-branch-evaluate.json"
echo "  3. Open a PR and watch the CI gates run."
