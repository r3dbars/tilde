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
  "Useful suffix" \
  "Over-eager/chatty ok" \
  "Repetition ok" \
  "Wrong-topic ok" \
  "Unsafe/sensitive ok" \
  "User-feel ok" \
  "| Code field negative | 0/20 | n/a | n/a | n/a | n/a | 100% | 0 |" \
  "Unsafe displays" \
  "Predictive phrase fallback exact: 200/200" \
  "Predictor-only positives omit the expected answer" \
  "not a claim that the live model is 100/100"; do
  if ! grep -F "$required" "$PREDICTION_REPORT_PATH" >/dev/null; then
    echo "completion prediction quality report missing required section: $required" >&2
    exit 1
  fi
done

PHRASE_REPORT_PATH="docs/evals/daily-driver-phrase-quality-2026-06-12.md"
if [[ ! -f "$PHRASE_REPORT_PATH" ]]; then
  echo "daily-driver phrase quality report missing: $PHRASE_REPORT_PATH" >&2
  exit 1
fi

for required in \
  "Daily Driver Phrase Quality Eval - 30 Real Writing Cases" \
  "Score: 100/100" \
  "Rows scored: 30" \
  "Display-eligible rows: 24" \
  "Suppressed/no-suggestion rows: 6" \
  "Accept-worthy rows: 30/30" \
  "3-8 word phrase rate: 100%" \
  "Suffix-noise failures: 0" \
  "| Total | 24/24 | 100% | 100% | 0 | 6/6 | 100% |" \
  "would this visible suggestion be worth accepting" \
  "not private dogfood"; do
  if ! grep -F "$required" "$PHRASE_REPORT_PATH" >/dev/null; then
    echo "daily-driver phrase quality report missing required section: $required" >&2
    exit 1
  fi
done
