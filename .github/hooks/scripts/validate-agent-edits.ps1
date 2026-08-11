$ErrorActionPreference = "Stop"
node tools/harness/src/hook.mjs
exit $LASTEXITCODE
