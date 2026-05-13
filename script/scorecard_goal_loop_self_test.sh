#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCRIPT_TEXT="$(sed -n '1,220p' script/scorecard_goal_loop.sh)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

require_contains() {
  local expected="$1"
  if ! grep -F "$expected" <<<"$SCRIPT_TEXT" >/dev/null; then
    echo "missing expected score loop text: $expected" >&2
    exit 1
  fi
}

require_contains 'BETA_READINESS_GATE_SCRIPT="${AUTOCOMPLETE_LAB_BETA_READINESS_GATE_SCRIPT:-./script/beta_readiness.sh}"'
require_contains 'PROMPT_APP_PROOF_GATE_SCRIPT="${AUTOCOMPLETE_LAB_SCORE_TARGET_PROMPT_APP_PROOF_GATE_SCRIPT:-./script/check_prompt_app_manifest_proof.sh}"'
require_contains 'AUTOCOMPLETE_LAB_SCORE_TARGET_STRICT_PROOF_GATES=never'
require_contains '"$BETA_READINESS_GATE_SCRIPT" --check-only'
require_contains 'Final prompt app manifest proof output:'
require_contains 'Final beta readiness output:'
require_contains 'prompt-app manifest proof gate, and private-beta readiness gate repeatedly'

make_gate() {
  local name="$1"
  local path="$TMP_DIR/$name"
  cat >"$path" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s|%s|strict=%s\n' \
  "$(basename "$0")" \
  "$*" \
  "${AUTOCOMPLETE_LAB_SCORE_TARGET_STRICT_PROOF_GATES:-unset}" \
  >>"$AUTOCOMPLETE_LAB_SCORE_LOOP_STUB_LOG"
STUB
  chmod +x "$path"
  printf '%s' "$path"
}

STUB_LOG="$TMP_DIR/gates.log"
touch "$STUB_LOG"

OUTPUT="$(
  AUTOCOMPLETE_LAB_SCORE_LOOP_STUB_LOG="$STUB_LOG" \
  AUTOCOMPLETE_LAB_STEADYTYPE_SCORECARD_GATE_SCRIPT="$(make_gate steadytype-scorecard)" \
  AUTOCOMPLETE_LAB_SCORE_TARGET_GATE_SCRIPT="$(make_gate score-targets)" \
  AUTOCOMPLETE_LAB_SCORE_TARGET_MANUAL_SMOKE_GATE_SCRIPT="$(make_gate manual-smoke)" \
  AUTOCOMPLETE_LAB_SCORE_TARGET_VISUAL_EVIDENCE_GATE_SCRIPT="$(make_gate visual-evidence)" \
  AUTOCOMPLETE_LAB_SCORE_TARGET_PROOF_MANIFEST_GATE_SCRIPT="$(make_gate proof-manifest)" \
  AUTOCOMPLETE_LAB_SCORE_TARGET_PROMPT_APP_PROOF_GATE_SCRIPT="$(make_gate prompt-app-proof)" \
  AUTOCOMPLETE_LAB_BETA_READINESS_GATE_SCRIPT="$(make_gate beta-readiness)" \
    script/scorecard_goal_loop.sh --iterations 1
)"

if ! grep -F "All scorecard goals complete on iteration 1." <<<"$OUTPUT" >/dev/null; then
  echo "score loop self-test did not complete with stub gates" >&2
  echo "$OUTPUT" >&2
  exit 1
fi

for expected in \
  "score-targets||strict=never" \
  "manual-smoke|--strict|strict=unset" \
  "visual-evidence|--require-all|strict=unset" \
  "proof-manifest|--require-all|strict=unset" \
  "prompt-app-proof||strict=unset" \
  "beta-readiness|--check-only|strict=unset"; do
  if ! grep -F "$expected" "$STUB_LOG" >/dev/null; then
    echo "score loop self-test missing expected gate invocation: $expected" >&2
    cat "$STUB_LOG" >&2
    exit 1
  fi
done

echo "Scorecard goal loop self-test passed."
