#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/trend.jsonl" <<'JSONL'
{"dateISO":"2026-07-15T12:00:00Z","gitSHA":"abc123","engine":"mock","model":"mock","promptFormat":"chat-instruct","variant":"baseline","corpusKind":"fixture","caseCount":2,"keystrokesSavedPerCase":4.5,"shownKeystrokesSavedPerCase":3.0,"missedMagicRate":0.25,"top1WordAccuracy":0.5,"wordPrefixAccuracy2":0.5,"wordPrefixAccuracy3":0,"wordPrefixAccuracy4":0,"suggestionRate":1,"wrongFirstWordRate":0.5,"endToEndP95LatencyMs":42,"acceptedAndKeptRate":null,"acceptRate":null}
JSONL

python3 "$ROOT/script/replay_eval_report.py" --check-privacy "$TMP/trend.jsonl" > "$TMP/report.md"
grep -q '^## mock / chat-instruct / baseline$' "$TMP/report.md"
grep -q '| 2026-07-15T12:00:00Z | mock | fixture | 2 | 4.50 | 3.00 | 25.0% | 42 | 50.0%' "$TMP/report.md"

printf '%s\n' 'not-json' > "$TMP/malformed.jsonl"
if python3 "$ROOT/script/replay_eval_report.py" --check-privacy "$TMP/malformed.jsonl" > /dev/null 2>&1; then
  echo "expected privacy check to reject malformed rows" >&2
  exit 1
fi

cp "$TMP/trend.jsonl" "$TMP/unsafe.jsonl"
printf '%s\n' '{"dateISO":"2026-07-15","gitSHA":"abc123","engine":"mock","model":"mock","variant":"baseline","corpusKind":"fixture","caseCount":1,"keystrokesSavedPerCase":0,"top1WordAccuracy":0,"wordPrefixAccuracy2":0,"wordPrefixAccuracy3":0,"wordPrefixAccuracy4":0,"suggestionRate":0,"wrongFirstWordRate":0,"prompt":"private text"}' >> "$TMP/unsafe.jsonl"
if python3 "$ROOT/script/replay_eval_report.py" --check-privacy "$TMP/unsafe.jsonl" > /dev/null 2>&1; then
  echo "expected privacy check to reject a text-bearing key" >&2
  exit 1
fi

echo "replay_eval_report_self_test: PASS"
