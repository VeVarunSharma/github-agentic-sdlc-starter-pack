#!/usr/bin/env bash
# Copilot lifecycle hook entry point; this is not a Git pre-commit hook.
set -euo pipefail
exec node tools/harness/src/hook.mjs
