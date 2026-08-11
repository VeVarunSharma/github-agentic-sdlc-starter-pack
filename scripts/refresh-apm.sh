#!/usr/bin/env bash
# scripts/refresh-apm.sh — update awesome-copilot SHA pins in apm.yml,
# re-run `apm install`, verify via `apm audit`, update upstream-sources.md.
#
# Usage:
#   ./scripts/refresh-apm.sh [--sha <commit>] [--dry-run]
#
#   --sha <commit>   Use this awesome-copilot commit instead of fetching HEAD.
#   --dry-run        Print what would change but do not modify files or run install.
#
# Testability overrides (env vars):
#   AWESOME_COPILOT_REPO   GitHub "owner/repo" of the pin target (default: github/awesome-copilot)
#   GITHUB_API_BASE        GitHub API base URL (default: https://api.github.com)
#   APM_CMD                Path to the `apm` binary (default: apm resolved from PATH)
#   APM_POLICY             Path to the policy file (default: ./apm-policy.yml)
#   UPSTREAM_SOURCES_DOC   Path to update (default: ./docs/upstream-sources.md)
#
# This script MUST NOT run `apm compile`. It only runs `apm install` +
# `apm audit`.  See docs/apm-ownership-model.md.
#
# Designed to be safe on Bash 3.2 (macOS system bash) and Bash 5+.
# Uses only POSIX + curl + sed; no associative arrays (bash 4+).

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
AWESOME_COPILOT_REPO="${AWESOME_COPILOT_REPO:-github/awesome-copilot}"
GITHUB_API_BASE="${GITHUB_API_BASE:-https://api.github.com}"
APM_CMD="${APM_CMD:-apm}"
APM_POLICY="${APM_POLICY:-./apm-policy.yml}"
UPSTREAM_SOURCES_DOC="${UPSTREAM_SOURCES_DOC:-./docs/upstream-sources.md}"

DRY_RUN=0
EXPLICIT_SHA=""

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sha)    EXPLICIT_SHA="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '2,/^$/p' "$0"
      exit 0
      ;;
    *) echo "[error] Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Safety note ───────────────────────────────────────────────────────────────
# This script must NEVER call `apm compile -t copilot` as that would
# overwrite the hand-authored .github/copilot-instructions.md.
# See docs/apm-ownership-model.md.

# ── Resolve new SHA ───────────────────────────────────────────────────────────
if [[ -n "$EXPLICIT_SHA" ]]; then
  NEW_SHA="$EXPLICIT_SHA"
  echo "[refresh-apm] Using provided SHA: ${NEW_SHA}"
else
  echo "[refresh-apm] Fetching latest main commit from ${AWESOME_COPILOT_REPO} ..."
  COMMIT_JSON=$(curl -fsSL \
    "${GITHUB_API_BASE}/repos/${AWESOME_COPILOT_REPO}/commits/main" \
    -H "Accept: application/vnd.github.v3+json")

  # Extract sha — compatible with Python 2 / 3 and available tools
  if command -v python3 >/dev/null 2>&1; then
    NEW_SHA=$(echo "$COMMIT_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['sha'])")
  elif command -v python >/dev/null 2>&1; then
    NEW_SHA=$(echo "$COMMIT_JSON" | python -c "import json,sys; d=json.load(sys.stdin); print(d['sha'])")
  else
    # Fallback: grep for the sha field (first occurrence is the commit SHA)
    NEW_SHA=$(echo "$COMMIT_JSON" | grep '"sha"' | head -1 | sed 's/.*"sha": *"\([0-9a-f]*\)".*/\1/')
  fi

  if [[ -z "$NEW_SHA" ]] || [[ ${#NEW_SHA} -lt 40 ]]; then
    echo "[error] Could not extract SHA from GitHub API response." >&2
    echo "[error] Response snippet: $(echo "$COMMIT_JSON" | head -5)" >&2
    exit 1
  fi
  echo "[refresh-apm] Resolved HEAD: ${NEW_SHA}"
fi

# ── Validate the SHA exists and extract commit metadata ───────────────────────
echo "[refresh-apm] Verifying commit ${NEW_SHA} ..."
COMMIT_DETAIL=$(curl -fsSL \
  "${GITHUB_API_BASE}/repos/${AWESOME_COPILOT_REPO}/commits/${NEW_SHA}" \
  -H "Accept: application/vnd.github.v3+json")

if command -v python3 >/dev/null 2>&1; then
  COMMIT_DATE=$(echo "$COMMIT_DETAIL" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['commit']['author']['date'][:10])")
  COMMIT_MSG=$(echo  "$COMMIT_DETAIL" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['commit']['message'].splitlines()[0][:80])")
elif command -v python >/dev/null 2>&1; then
  COMMIT_DATE=$(echo "$COMMIT_DETAIL" | python -c "import json,sys; d=json.load(sys.stdin); print(d['commit']['author']['date'][:10])")
  COMMIT_MSG=$(echo  "$COMMIT_DETAIL" | python -c "import json,sys; d=json.load(sys.stdin); print(d['commit']['message'].splitlines()[0][:80])")
else
  COMMIT_DATE=$(date -u +%Y-%m-%d)
  COMMIT_MSG="(python unavailable — date and message not extracted)"
fi

echo "[refresh-apm] Commit date: ${COMMIT_DATE}"
echo "[refresh-apm] Commit message: ${COMMIT_MSG}"

# ── Find old SHA in apm.yml ───────────────────────────────────────────────────
# Grep for the first SHA pin under github/awesome-copilot
OLD_SHA=$(grep -oE 'github/awesome-copilot/[^#]+#([0-9a-f]{40})' apm.yml \
  | head -1 \
  | grep -oE '[0-9a-f]{40}$')

if [[ -z "$OLD_SHA" ]]; then
  echo "[error] Could not detect current SHA in apm.yml" >&2
  exit 1
fi

echo "[refresh-apm] Old SHA: ${OLD_SHA}"
echo "[refresh-apm] New SHA: ${NEW_SHA}"

if [[ "$OLD_SHA" == "$NEW_SHA" ]]; then
  echo "[refresh-apm] Already up to date. Nothing to do."
  exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[refresh-apm] DRY RUN — would replace '${OLD_SHA}' with '${NEW_SHA}' in apm.yml"
  echo "[refresh-apm] DRY RUN — would update verified comment and run apm install + audit"
  echo "[refresh-apm] DRY RUN — would update docs/upstream-sources.md"
  exit 0
fi

# ── Rewrite apm.yml ───────────────────────────────────────────────────────────
# Replace all occurrences of the old SHA pin (for this repo's awesome-copilot deps).
# Also update the verified comment block that documents the SHA.
echo "[refresh-apm] Rewriting apm.yml ..."

# Step 1: Replace all #<old-sha> pins with #<new-sha>
sed -i.bak "s/#${OLD_SHA}/#${NEW_SHA}/g" apm.yml

# Step 2: Update the verified comment line
# Matches: "  # Verified at github/awesome-copilot @ <old-sha>"
sed -i.bak \
  "s|# Verified at ${AWESOME_COPILOT_REPO} @ ${OLD_SHA}.*|# Verified at ${AWESOME_COPILOT_REPO} @ ${NEW_SHA}|" \
  apm.yml

# Step 3: Update the date parenthetical in the comment that follows the SHA
# Format:  # (<old-date> — "<old-msg>"):
# We replace just the SHA in that pattern, since the date is separate.
sed -i.bak \
  "s|(${COMMIT_DATE}[^)]*):|(${COMMIT_DATE} — \"${COMMIT_MSG}\"):|" \
  apm.yml || true   # tolerate no-match (first run or already updated)

# Clean up backup files (sed -i on macOS requires .bak suffix)
rm -f apm.yml.bak

echo "[refresh-apm] apm.yml updated"

# ── Run apm install ───────────────────────────────────────────────────────────
echo "[refresh-apm] Running: ${APM_CMD} install --target copilot ..."
"$APM_CMD" install --target copilot

# ── Run apm audit ─────────────────────────────────────────────────────────────
echo "[refresh-apm] Running: ${APM_CMD} audit --ci --policy ${APM_POLICY} ..."
"$APM_CMD" audit --ci --policy "$APM_POLICY"

# ── Update docs/upstream-sources.md ──────────────────────────────────────────
echo "[refresh-apm] Updating ${UPSTREAM_SOURCES_DOC} ..."

# Get today's date (format: YYYY-MM-DD)
TODAY=$(date -u +%Y-%m-%d)

# APM version from the binary
APM_VERSION=$("$APM_CMD" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

# Update the "Last verified" block
sed -i.bak \
  "s/^- \*\*Date:\*\* .*/- **Date:** ${TODAY} (matches \`apm.lock.yaml\` \`generated_at\`)/" \
  "$UPSTREAM_SOURCES_DOC"

sed -i.bak \
  "s/^- \*\*APM CLI version:\*\* .*/- **APM CLI version:** \`${APM_VERSION}\` (installed via \`scripts\/install-apm.sh\`)/" \
  "$UPSTREAM_SOURCES_DOC"

sed -i.bak \
  "s/^- \*\*Awesome-copilot HEAD:\*\* .*/- **Awesome-copilot HEAD:** \`${NEW_SHA}\`/" \
  "$UPSTREAM_SOURCES_DOC"

rm -f "${UPSTREAM_SOURCES_DOC}.bak"

echo "[refresh-apm] Done. Refreshed to ${NEW_SHA} (${COMMIT_DATE})"
echo "[refresh-apm] Modified: apm.yml, apm.lock.yaml, docs/upstream-sources.md"
echo "[refresh-apm] Review changes, then commit with:"
echo "  git add apm.yml apm.lock.yaml .github/instructions .github/skills docs/upstream-sources.md"
echo "  git commit -s -m \"chore(deps): refresh awesome-copilot to ${NEW_SHA:0:8}\""
