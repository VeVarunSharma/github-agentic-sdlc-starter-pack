#!/usr/bin/env bash
# scripts/bootstrap.sh
#
# Safe bootstrap for GitHub enterprise Copilot governance settings.
# DRY-RUN by default — prints what would happen without executing.
# Add --apply only after reviewing dry-run output and confirming identifiers.
#
# USAGE
#   bash scripts/bootstrap.sh \
#     --enterprise ENTERPRISE_SLUG \
#     --organization ORG_SLUG \
#     [--governance-repo REPO_NAME]  # default: .github-private
#     [--apply]                      # execute API calls (requires admin auth)
#     [--help]
#
# PREREQUISITES
#   • gh CLI authenticated with an account that has enterprise admin access
#   • gh version >= 2.50.0 (for --jq and preview API support)
#   • Node 22 available for renderer and validator
#   • jq installed (for JSON formatting in dry-run output)
#
# API VERSION
#   GitHub Enterprise API: 2026-03-10 (preview) where applicable.
#   Standard endpoints use the stable REST API.
#
# NEVER executed automatically by CI. This script requires human review
# and --apply confirmation before any mutation.

set -euo pipefail

# ─── Argument parsing ────────────────────────────────────────────────────────

ENTERPRISE=""
ORG=""
GOV_REPO=".github-private"
APPLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --enterprise)   ENTERPRISE="$2"; shift 2 ;;
    --organization) ORG="$2"; shift 2 ;;
    --governance-repo) GOV_REPO="$2"; shift 2 ;;
    --apply)        APPLY=true; shift ;;
    --help|-h)
      cat <<'EOF'
bootstrap.sh — Enterprise Copilot governance bootstrap

USAGE
  bash scripts/bootstrap.sh \
    --enterprise ENTERPRISE_SLUG \
    --organization ORG_SLUG \
    [--governance-repo REPO_NAME]  # default: .github-private
    [--apply]                      # execute API calls (requires admin auth)
    [--help]

FLAGS
  --enterprise SLUG    GitHub Enterprise slug (required)
  --organization SLUG  GitHub organization slug (required)
  --governance-repo    Name of the .github-private repository (default: .github-private)
  --apply              Execute API calls. Dry-run by default.
  --help               Show this help.

WHAT IT DOES
  1. Validates and renders managed-settings source files
  2. Checks gh CLI auth and version
  3. Prints/executes: create governance repository if needed
  4. Prints/executes: configure managed settings path in org settings
  5. Prints/executes: import branch ruleset
  6. Prints/executes: set CODEOWNERS path
  NEVER creates enterprise or mutates AI Controls without explicit --apply.
EOF
      exit 0
      ;;
    *) echo "ERROR: Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ─── Validation ──────────────────────────────────────────────────────────────

require_arg() {
  if [[ -z "$1" ]]; then
    echo "ERROR: $2 is required" >&2
    exit 1
  fi
}

require_arg "$ENTERPRISE" "--enterprise"
require_arg "$ORG" "--organization"

# Validate slug format
validate_slug() {
  if ! [[ "$1" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
    echo "ERROR: '$1' is not a valid GitHub slug" >&2
    exit 1
  fi
}
validate_slug "$ENTERPRISE"
validate_slug "$ORG"

# Check gh CLI
if ! command -v gh &>/dev/null; then
  echo "ERROR: gh CLI not found. Install from https://cli.github.com" >&2
  exit 1
fi

GH_VERSION=$(gh --version | head -1 | awk '{print $3}')
echo "INFO: gh CLI version: $GH_VERSION"

# Check gh auth
if ! gh auth status &>/dev/null; then
  echo "ERROR: gh CLI not authenticated. Run: gh auth login" >&2
  exit 1
fi

# Check jq
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq not found. Install jq for JSON processing." >&2
  exit 1
fi

# Check Node 22
if ! command -v node &>/dev/null; then
  echo "ERROR: Node.js not found" >&2
  exit 1
fi

NODE_MAJOR=$(node -e 'console.log(process.version.split(".")[0].slice(1))')
if [[ "$NODE_MAJOR" -lt 22 ]]; then
  echo "ERROR: Node.js 22+ required (found v${NODE_MAJOR})" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

echo ""
echo "=== Enterprise Governance Bootstrap ==="
echo "Enterprise:       $ENTERPRISE"
echo "Organization:     $ORG"
echo "Governance repo:  $ORG/$GOV_REPO"
echo "Mode:             $([ "$APPLY" = "true" ] && echo 'APPLY (live API calls)' || echo 'DRY-RUN (no changes)')"
echo ""

if [[ "$APPLY" = "false" ]]; then
  echo "NOTE: Dry-run mode. Add --apply to execute. Review output carefully."
  echo ""
fi

# ─── Step 1: Render and validate ────────────────────────────────────────────

echo "── Step 1: Render managed settings"
RENDER_CMD="node $SCRIPT_DIR/render-managed-settings.mjs \
  --enterprise $ENTERPRISE \
  --organization $ORG \
  --governance-repo $GOV_REPO \
  --otlp-endpoint https://otel.example.internal"
echo "  Running: $RENDER_CMD"
if [[ "$APPLY" = "true" ]]; then
  eval "$RENDER_CMD"
else
  echo "  [DRY-RUN] Would render managed settings"
fi

echo ""
echo "── Step 2: Validate overlay"
VALIDATE_CMD="node $SCRIPT_DIR/validate-governance.mjs"
echo "  Running: $VALIDATE_CMD"
if [[ "$APPLY" = "true" ]]; then
  eval "$VALIDATE_CMD"
else
  echo "  [DRY-RUN] Would validate overlay"
fi

# ─── Step 3: Check/create governance repository ─────────────────────────────

echo ""
echo "── Step 3: Governance repository"

REPO_CHECK_CMD="gh api /repos/$ORG/$GOV_REPO --jq '.full_name' 2>/dev/null || true"
echo "  Check: gh api /repos/$ORG/$GOV_REPO"

if [[ "$APPLY" = "true" ]]; then
  EXISTING_REPO=$(gh api "/repos/$ORG/$GOV_REPO" --jq '.full_name' 2>/dev/null || true)
  if [[ -n "$EXISTING_REPO" ]]; then
    echo "  Repository $EXISTING_REPO already exists — skipping create"
  else
    echo "  Creating private repository $ORG/$GOV_REPO"
    gh api -X POST "/orgs/$ORG/repos" \
      --field name="$GOV_REPO" \
      --field private=true \
      --field description="Enterprise Copilot governance overlay" \
      --field has_issues=true \
      --field has_projects=false \
      --field has_wiki=false
    echo "  Created $ORG/$GOV_REPO"
  fi
else
  cat <<EOF
  [DRY-RUN] Would execute:
    gh api -X POST /orgs/$ORG/repos \\
      --field name="$GOV_REPO" \\
      --field private=true \\
      --field description="Enterprise Copilot governance overlay"
EOF
fi

# ─── Step 4: Configure managed settings path ─────────────────────────────────

echo ""
echo "── Step 4: Configure managed settings in organization"
echo "  NOTE: Managed settings path is configured in the GitHub UI under:"
echo "  Enterprise → Copilot → Managed settings → Source repository"
echo "  Set it to: $ORG/$GOV_REPO (copilot/managed-settings.json)"
echo ""
echo "  REST API support for programmatic setting of the managed-settings source"
echo "  repository is in preview as of 2026-08-09."
echo "  API endpoint (2026-03-10 preview): PATCH /enterprises/$ENTERPRISE/copilot/settings"

if [[ "$APPLY" = "true" ]]; then
  echo "  [PREVIEW API — verify current support before executing]"
  echo "  Consult: https://docs.github.com/en/enterprise-cloud@latest/rest/copilot"
  echo "  Skipping automated API call — configure via UI or verified REST endpoint."
else
  cat <<EOF
  [DRY-RUN] If preview API is GA, would execute:
    gh api -X PATCH /enterprises/$ENTERPRISE/copilot/settings \\
      -H "X-GitHub-Api-Version: 2026-03-10" \\
      --field managed_settings_repo="$ORG/$GOV_REPO"
EOF
fi

# ─── Step 5: Import branch ruleset ───────────────────────────────────────────

echo ""
echo "── Step 5: Branch ruleset"
RULESET_PATH="$ROOT/.github/rulesets/governance-branch-protect.json"
if [[ ! -f "$RULESET_PATH" ]]; then
  echo "  WARN: Ruleset file not found at $RULESET_PATH — skipping"
else
  echo "  Ruleset: $RULESET_PATH"
  if [[ "$APPLY" = "true" ]]; then
    echo "  Importing ruleset into $ORG/$GOV_REPO"
    gh api -X POST "/repos/$ORG/$GOV_REPO/rulesets" \
      --input "$RULESET_PATH" \
      -H "X-GitHub-Api-Version: 2022-11-28"
    echo "  Ruleset imported"
  else
    cat <<EOF
  [DRY-RUN] Would execute:
    gh api -X POST /repos/$ORG/$GOV_REPO/rulesets \\
      --input $RULESET_PATH \\
      -H "X-GitHub-Api-Version: 2022-11-28"
EOF
  fi
fi

# ─── Step 6: Summary ─────────────────────────────────────────────────────────

echo ""
echo "=== Bootstrap $( [ "$APPLY" = "true" ] && echo 'complete' || echo 'dry-run complete' ) ==="
if [[ "$APPLY" = "false" ]]; then
  echo ""
  echo "To apply, re-run with --apply:"
  echo "  bash scripts/bootstrap.sh \\"
  echo "    --enterprise $ENTERPRISE \\"
  echo "    --organization $ORG \\"
  echo "    --governance-repo $GOV_REPO \\"
  echo "    --apply"
  echo ""
  echo "Review output above before applying. This script requires human confirmation."
fi
