#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUTPUT="$(script/local_quality_audit.py --self-test)"

python3 - <<'PY'
import importlib.util
from pathlib import Path

module_path = Path("script/local_quality_audit.py").resolve()
spec = importlib.util.spec_from_file_location("local_quality_audit", module_path)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)

assert module.prompt_template_for_model("qwen3-1.7b-base") == "raw_completion"
assert module.prompt_template_for_model("small-draft-1b") == "raw_completion"
assert module.prompt_template_for_model("qwen3-0.6b") == "raw_completion"
assert module.prompt_template_for_model("qwen35-4b") == "chat_instruct"
assert module.raw_completion_prompt("system", "user") == "system\n\nuser"
PY

grep -q "Local quality audit: PASS" <<<"$OUTPUT"
grep -q "Source: self-test fixtures" <<<"$OUTPUT"
grep -q "Expected suppressions passed: 1" <<<"$OUTPUT"
grep -q "Overall score: 92/100" <<<"$OUTPUT"
grep -q "Relevance score: 75/100" <<<"$OUTPUT"
grep -q "Raw output persisted: no" <<<"$OUTPUT"
grep -q "PASS fixture-good-markdown" <<<"$OUTPUT"
grep -q "FAIL fixture-assistant-voice" <<<"$OUTPUT"
grep -q "FAIL fixture-sensitive-structure" <<<"$OUTPUT"
grep -q "SUPPRESS fixture-no-suggestion" <<<"$OUTPUT"

for label in \
  "relevance" \
  "literal continuation" \
  "assistant voice" \
  "wrong topic" \
  "too long" \
  "structural breakage" \
  "unsafe or sensitive content" \
  "repetition"; do
  grep -q -- "- $label:" <<<"$OUTPUT"
done

echo "$OUTPUT"
