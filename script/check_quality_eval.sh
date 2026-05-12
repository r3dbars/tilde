#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift test --filter CompletionQualityEvalTests
swift test --filter OfflineModelQualityEvalTests
swift test --filter WordCompletionQualityEvalTests
swift test --filter CompletionPredictionQualityEvalTests

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

PREDICTION_REPORT_PATH="docs/evals/completion-prediction-quality-500-2026-05-11.md"
if [[ ! -f "$PREDICTION_REPORT_PATH" ]]; then
  echo "completion prediction quality report missing: $PREDICTION_REPORT_PATH" >&2
  exit 1
fi

for required in \
  "Completion Prediction Quality Eval - 500 Cases" \
  "Score: 100.0/100" \
  "Squared score: 10000.0/10000" \
  "Next word exact" \
  "4-word exact" \
  "Unsafe displays" \
  "not a claim that the live model is 100/100"; do
  if ! grep -F "$required" "$PREDICTION_REPORT_PATH" >/dev/null; then
    echo "completion prediction quality report missing required section: $required" >&2
    exit 1
  fi
done
