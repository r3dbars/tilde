#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS_TRACE="$TMP_DIR/prompt-pass.jsonl"
FAIL_TRACE="$TMP_DIR/prompt-fail.jsonl"
NO_PROMPT_TRACE="$TMP_DIR/no-prompt.jsonl"
BROWSER_CHAT_TRACE="$TMP_DIR/browser-chat-pass.jsonl"

cat >"$PASS_TRACE" <<'JSONL'
{"type":"suggestionPresented","suggestionID":"safe-one","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","displayedText":"safe","metadata":{"promptSafetyMode":"wordOnly"}}
{"type":"suggestionAccepted","suggestionID":"safe-one","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","acceptedText":"safe","metadata":{"acceptMode":"acceptNextWord","promptSafetyMode":"wordOnly"}}
{"type":"insertionVerified","suggestionID":"safe-one","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","acceptedText":"safe","outcome":"verified","metadata":{"acceptMode":"acceptNextWord","promptSafetyMode":"wordOnly"}}
{"type":"acceptedTextEdited","suggestionID":"safe-one","appBundleIdentifier":"com.openai.codex","requestMode":"wordCompletion","acceptedText":"safe","outcome":"exactKept","metadata":{"checkpoint":"10s","promptSafetyMode":"wordOnly"}}
{"type":"acceptedTextEdited","suggestionID":"non-prompt-submit","appBundleIdentifier":"com.apple.TextEdit","reason":"field-send-finalized","metadata":{"checkpoint":"fieldSend"}}
JSONL

./script/check_prompt_app_proof.sh --trace "$PASS_TRACE" >"$TMP_DIR/pass.txt"

for expected in \
  "Prompt app events: 4" \
  "accidentalSubmitCount: 0" \
  "sendKeyCollisionCount: 0" \
  "promptMutationWithoutUserIntentCount: 0" \
  "wrongContextInsertionCount: 0" \
  "suggestionContentViolationCount: 0" \
  "Prompt app proof gate passed."; do
  if ! grep -F "$expected" "$TMP_DIR/pass.txt" >/dev/null; then
    echo "prompt proof self-test missing passing output: $expected" >&2
    cat "$TMP_DIR/pass.txt" >&2
    exit 1
  fi
done

cat >"$FAIL_TRACE" <<'JSONL'
{"type":"acceptedTextEdited","suggestionID":"accidental-submit","appBundleIdentifier":"com.openai.codex","reason":"field-send-finalized","metadata":{"checkpoint":"fieldSend"}}
{"type":"suggestionSuppressed","suggestionID":"send-key","appBundleIdentifier":"com.anthropic.claude-code","reason":"tab-conflict","metadata":{"sendKeyCollision":"true"}}
{"type":"insertionFailed","suggestionID":"mutation","appBundleIdentifier":"com.anthropic.claudefordesktop","reason":"prompt-mutation-outside-accepted-span","metadata":{"promptMutationWithoutUserIntent":"true"}}
{"type":"suggestionSuppressed","suggestionID":"wrong-context","appBundleIdentifier":"com.openai.chat","reason":"wrong-app-or-field-before-accept","metadata":{"acceptanceGuardReason":"app-changed-before-accept"}}
{"type":"suggestionSuppressed","suggestionID":"content-policy","appBundleIdentifier":"ru.keepcoder.Telegram","reason":"accepted-text-prompt-action-word","displayedText":"send it","metadata":{"contentPolicyViolation":"true"}}
{"type":"suggestionSuppressed","suggestionID":"metadata-prompt","appBundleIdentifier":"com.example.UnknownPrompt","reason":"wrong-context","metadata":{"behaviorProfile":"ai_chat"}}
JSONL

if ./script/check_prompt_app_proof.sh --trace "$FAIL_TRACE" >"$TMP_DIR/fail.txt" 2>&1; then
  echo "prompt proof self-test expected unsafe prompt trace to fail" >&2
  cat "$TMP_DIR/fail.txt" >&2
  exit 1
fi

for expected in \
  "accidentalSubmitCount: 1" \
  "sendKeyCollisionCount: 1" \
  "promptMutationWithoutUserIntentCount: 1" \
  "wrongContextInsertionCount: 2" \
  "suggestionContentViolationCount: 1" \
  "Prompt app proof gate failed with 5 nonzero metric(s)."; do
  if ! grep -F "$expected" "$TMP_DIR/fail.txt" >/dev/null; then
    echo "prompt proof self-test missing failure output: $expected" >&2
    cat "$TMP_DIR/fail.txt" >&2
    exit 1
  fi
done

cat >"$NO_PROMPT_TRACE" <<'JSONL'
{"type":"acceptedTextEdited","suggestionID":"textedit-submit","appBundleIdentifier":"com.apple.TextEdit","reason":"field-send-finalized","metadata":{"checkpoint":"fieldSend"}}
JSONL

if ./script/check_prompt_app_proof.sh --trace "$NO_PROMPT_TRACE" >"$TMP_DIR/no-prompt.txt" 2>&1; then
  echo "prompt proof self-test expected missing prompt-app evidence to fail closed" >&2
  cat "$TMP_DIR/no-prompt.txt" >&2
  exit 1
fi

if ! grep -F "trace slice has no prompt/chat events" "$TMP_DIR/no-prompt.txt" >/dev/null; then
  echo "prompt proof self-test did not fail closed on missing prompt events" >&2
  cat "$TMP_DIR/no-prompt.txt" >&2
  exit 1
fi

cat >"$BROWSER_CHAT_TRACE" <<'JSONL'
{"type":"suggestionPresented","suggestionID":"safe-chat","appBundleIdentifier":"com.google.Chrome","requestMode":"wordCompletion","displayedText":"safe","metadata":{"browserChatProofSurface":"browser-chat-harness"}}
{"type":"suggestionAccepted","suggestionID":"safe-chat","appBundleIdentifier":"com.google.Chrome","requestMode":"wordCompletion","acceptedText":"safe","metadata":{"acceptMode":"acceptNextWord","browserChatProofSurface":"browser-chat-harness"}}
{"type":"insertionVerified","suggestionID":"safe-chat","appBundleIdentifier":"com.google.Chrome","requestMode":"wordCompletion","acceptedText":"safe","outcome":"verified","metadata":{"acceptMode":"acceptNextWord","browserChatProofSurface":"browser-chat-harness"}}
JSONL

./script/check_prompt_app_proof.sh \
  --trace "$BROWSER_CHAT_TRACE" \
  --bundle com.google.Chrome \
  --surface browser-chat-harness \
  --require-browser-chat-surface >"$TMP_DIR/browser-chat-pass.txt"

for expected in \
  "Browser chat surface events: 3" \
  "Proof surface: browser-chat-harness" \
  "accidentalSubmitCount: 0" \
  "sendKeyCollisionCount: 0" \
  "promptMutationWithoutUserIntentCount: 0" \
  "wrongContextInsertionCount: 0" \
  "Prompt app proof gate passed."; do
  if ! grep -F "$expected" "$TMP_DIR/browser-chat-pass.txt" >/dev/null; then
    echo "prompt proof self-test missing browser-chat output: $expected" >&2
    cat "$TMP_DIR/browser-chat-pass.txt" >&2
    exit 1
  fi
done

echo "Prompt app proof self-test passed."
