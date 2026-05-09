#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift test --filter CompletionQualityEvalTests
swift test --filter OfflineModelQualityEvalTests
swift test --filter WordCompletionQualityEvalTests

REPORT_PATH="docs/evals/word-completion-quality-2026-05-09.md"
if [[ ! -f "$REPORT_PATH" ]]; then
  echo "word completion quality report missing: $REPORT_PATH" >&2
  exit 1
fi

for required in \
  "Candidate quality" \
  "Miss rate" \
  "Typed-over rate" \
  "Repeated miss suppressed" \
  "Prefix cooldown blocked" \
  "Partial accept" \
  "Score: 9.6/10"; do
  if ! grep -F "$required" "$REPORT_PATH" >/dev/null; then
    echo "word completion quality report missing required section: $required" >&2
    exit 1
  fi
done
