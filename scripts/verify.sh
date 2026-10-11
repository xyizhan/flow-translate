#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
swift build
swift run FlowCoreChecks
TASK_BIN="$(swift build --show-bin-path)/FlowTranslate"
"$TASK_BIN" --feature-smoke-test
"$TASK_BIN" --ocr-expanded-test
python3 scripts/verify-api.py
print 'All offline functional checks passed. No real API key or screen contents were used.'
