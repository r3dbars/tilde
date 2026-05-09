#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TRACE_PATH="${AUTOCOMPLETE_LAB_PROMPT_PROOF_TRACE_PATH:-${AUTOCOMPLETE_LAB_TRACE_PATH:-$HOME/Library/Logs/AutocompleteLab/traces.jsonl}}"
START_LINE="${AUTOCOMPLETE_LAB_PROMPT_PROOF_START_LINE:-1}"
END_LINE="${AUTOCOMPLETE_LAB_PROMPT_PROOF_END_LINE:-}"
REQUIRE_PROMPT_EVENTS="${AUTOCOMPLETE_LAB_PROMPT_PROOF_REQUIRE_EVENTS:-1}"
EXTRA_BUNDLES="${AUTOCOMPLETE_LAB_PROMPT_PROOF_EXTRA_BUNDLES:-}"
PROOF_SURFACE="${AUTOCOMPLETE_LAB_PROMPT_PROOF_SURFACE:-}"
REQUIRE_BROWSER_CHAT_SURFACE="${AUTOCOMPLETE_LAB_PROMPT_PROOF_REQUIRE_BROWSER_CHAT_SURFACE:-0}"

usage() {
  cat <<'EOF'
Usage: script/check_prompt_app_proof.sh [--trace PATH] [--start-line N] [--end-line N] [--bundle BUNDLE] [--surface SURFACE] [--require-browser-chat-surface] [--allow-empty]

Reads a JSONL trace slice and fails if prompt/chat no-submit proof metrics are
nonzero. Line numbers are inclusive.
EOF
}

EXTRA_ARGS=()
while (($# > 0)); do
  case "$1" in
    --trace)
      if (($# < 2)); then
        echo "--trace requires a path" >&2
        exit 2
      fi
      TRACE_PATH="$2"
      shift 2
      ;;
    --start-line)
      if (($# < 2)); then
        echo "--start-line requires a value" >&2
        exit 2
      fi
      START_LINE="$2"
      shift 2
      ;;
    --end-line)
      if (($# < 2)); then
        echo "--end-line requires a value" >&2
        exit 2
      fi
      END_LINE="$2"
      shift 2
      ;;
    --bundle)
      if (($# < 2)); then
        echo "--bundle requires a bundle identifier" >&2
        exit 2
      fi
      EXTRA_ARGS+=("$2")
      shift 2
      ;;
    --surface)
      if (($# < 2)); then
        echo "--surface requires a proof surface label" >&2
        exit 2
      fi
      PROOF_SURFACE="$2"
      shift 2
      ;;
    --require-browser-chat-surface)
      REQUIRE_BROWSER_CHAT_SURFACE=1
      shift
      ;;
    --allow-empty)
      REQUIRE_PROMPT_EVENTS=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! [[ "$START_LINE" =~ ^[0-9]+$ ]] || ((START_LINE < 1)); then
  echo "--start-line must be a positive integer" >&2
  exit 2
fi

if [[ -n "$END_LINE" ]]; then
  if ! [[ "$END_LINE" =~ ^[0-9]+$ ]] || ((END_LINE < START_LINE)); then
    echo "--end-line must be a positive integer greater than or equal to --start-line" >&2
    exit 2
  fi
fi

PYTHON_ARGS=("$TRACE_PATH" "$START_LINE" "$END_LINE" "$REQUIRE_PROMPT_EVENTS" "$EXTRA_BUNDLES" "$PROOF_SURFACE" "$REQUIRE_BROWSER_CHAT_SURFACE")
if ((${#EXTRA_ARGS[@]} > 0)); then
  PYTHON_ARGS+=("${EXTRA_ARGS[@]}")
fi

python3 - "${PYTHON_ARGS[@]}" <<'PY'
from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path


path = Path(sys.argv[1]).expanduser()
start_line = int(sys.argv[2])
end_line = int(sys.argv[3]) if sys.argv[3] else None
require_prompt_events = sys.argv[4].lower() not in {"0", "false", "no", "off"}
extra_bundles = {
    item.strip()
    for raw in sys.argv[5].split(",")
    for item in [raw]
    if item.strip()
}
proof_surface = sys.argv[6].strip().lower()
require_browser_chat_surface = sys.argv[7].lower() not in {"0", "false", "no", "off"}
extra_bundles.update(value.strip() for value in sys.argv[8:] if value.strip())

prompt_bundles = {
    "com.openai.codex",
    "com.anthropic.claude-code",
    "com.anthropic.claudefordesktop",
    "com.openai.chat",
    "com.openai.ChatGPT",
    "com.openai.atlas",
    "com.tinyspeck.slackmacgap",
    "com.hnc.Discord",
    "com.hnc.DiscordPTB",
    "com.hnc.DiscordCanary",
    "ru.keepcoder.Telegram",
}
prompt_bundles.update(extra_bundles)

browser_chat_surfaces = {
    "chatgpt",
    "slack",
    "discord",
    "discord-ptb",
    "discord-canary",
    "browser-chat-harness",
    "real-browser-chat-harness",
}

submit_like_signals = {
    "fieldsend",
    "field-send",
    "field-send-finalized",
    "submit",
    "submitted",
    "prompt-submit",
    "prompt-submitted",
    "send",
    "sent",
}
submit_signal_metadata_keys = {
    "action",
    "checkpoint",
    "finishReason",
    "key",
    "keyboardAction",
    "outcome",
    "reason",
    "result",
}
unsafe_suggestion_phrases = {
    "press enter",
    "press return",
    "hit enter",
    "hit return",
    "click send",
    "send it",
    "submit it",
    "run it",
    "approve it",
}


def fail(message: str) -> None:
    print(f"Prompt app proof gate failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def normalized(value: object) -> str:
    return re.sub(r"[^a-z0-9-]+", "", str(value).strip().lower())


def lower_text(value: object) -> str:
    return str(value or "").strip().lower()


def contains_signal(value: object, signals: set[str]) -> bool:
    text = lower_text(value)
    compact = normalized(value)
    if not text and not compact:
        return False
    if compact in signals:
        return True
    return any(signal in compact for signal in signals if "-" in signal or signal in {"fieldsend"})


def is_prompt_event(event: dict) -> bool:
    metadata = event.get("metadata") if isinstance(event.get("metadata"), dict) else {}
    return (
        str(event.get("appBundleIdentifier", "")) in prompt_bundles
        or "promptSafetyMode" in metadata
        or metadata.get("behaviorProfile") == "ai_chat"
        or is_browser_chat_event(event)
    )


def is_browser_chat_event(event: dict) -> bool:
    metadata = event.get("metadata") if isinstance(event.get("metadata"), dict) else {}
    surface = lower_text(metadata.get("browserSurface"))
    tagged_surface = lower_text(metadata.get("browserChatSurface") or metadata.get("browserChatProofSurface"))
    if (
        metadata.get("browserSurfaceSafetyClass") == "browser-chat"
        or metadata.get("promptSafetyMetricSurface") == "browser-chat"
        or surface in browser_chat_surfaces
        or tagged_surface in browser_chat_surfaces
    ):
        return True

    if proof_surface in browser_chat_surfaces:
        app = str(event.get("appBundleIdentifier", ""))
        return app in prompt_bundles or app == "com.google.Chrome"

    return False


def is_true(value: object) -> bool:
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


def event_label(line_number: int, event: dict) -> str:
    event_type = event.get("type") or "unknown"
    app = event.get("appBundleIdentifier") or "unknown-app"
    reason = event.get("reason") or event.get("outcome") or ""
    if reason:
        return f"line {line_number} {event_type} {app} ({reason})"
    return f"line {line_number} {event_type} {app}"


def accidental_submit(event: dict) -> bool:
    metadata = event.get("metadata") if isinstance(event.get("metadata"), dict) else {}
    if is_true(metadata.get("accidentalSubmit")) or metadata.get("checkpoint") == "fieldSend":
        return True
    for key in ["type", "outcome", "reason", "triggerReason"]:
        if contains_signal(event.get(key), submit_like_signals):
            return True
    return any(contains_signal(metadata.get(key), submit_like_signals) for key in submit_signal_metadata_keys)


def send_key_collision(event: dict) -> bool:
    metadata = event.get("metadata") if isinstance(event.get("metadata"), dict) else {}
    if is_true(metadata.get("sendKeyCollision")) or is_true(metadata.get("keyCollision")):
        return True
    return any(
        token in lower_text(event.get(field))
        for field in ["reason", "outcome", "triggerReason"]
        for token in ["send-key-collision", "tab-conflict"]
    )


def prompt_mutation(event: dict) -> bool:
    metadata = event.get("metadata") if isinstance(event.get("metadata"), dict) else {}
    if is_true(metadata.get("promptMutationWithoutUserIntent")):
        return True
    return any(
        token in lower_text(event.get("reason"))
        for token in ["prompt-mutation", "mutation-outside-accepted-span"]
    )


def wrong_context(event: dict) -> bool:
    metadata = event.get("metadata") if isinstance(event.get("metadata"), dict) else {}
    return (
        event.get("reason") == "wrong-app-or-field-before-accept"
        or "wrong-context" in lower_text(event.get("reason"))
        or bool(metadata.get("acceptanceGuardReason"))
        or is_true(metadata.get("focusMismatch"))
    )


def suggestion_content_violation(event: dict) -> bool:
    metadata = event.get("metadata") if isinstance(event.get("metadata"), dict) else {}
    if is_true(metadata.get("contentPolicyViolation")):
        return True
    reason = lower_text(event.get("reason"))
    if "suggestion-content-violation" in reason or "accepted-text-prompt-" in reason:
        return True
    suggestion_text = " ".join(
        lower_text(event.get(field))
        for field in ["cleanedVisibleText", "displayedText", "acceptedText", "rawOutput"]
    )
    return any(phrase in suggestion_text for phrase in unsafe_suggestion_phrases)


metric_checks = [
    ("accidentalSubmitCount", accidental_submit),
    ("sendKeyCollisionCount", send_key_collision),
    ("promptMutationWithoutUserIntentCount", prompt_mutation),
    ("wrongContextInsertionCount", wrong_context),
    ("suggestionContentViolationCount", suggestion_content_violation),
]

if not path.exists():
    fail(f"missing trace file: {path}")

events: list[tuple[int, dict]] = []
with path.open("r", encoding="utf-8") as handle:
    for line_number, raw_line in enumerate(handle, start=1):
        if line_number < start_line:
            continue
        if end_line is not None and line_number > end_line:
            break
        line = raw_line.strip()
        if not line:
            continue
        try:
            decoded = json.loads(line)
        except json.JSONDecodeError as error:
            fail(f"invalid JSONL at line {line_number}: {error}")
        if not isinstance(decoded, dict):
            fail(f"trace event at line {line_number} must be an object")
        events.append((line_number, decoded))

if not events:
    fail("trace slice is empty")

prompt_events = [(line, event) for line, event in events if is_prompt_event(event)]
if require_prompt_events and not prompt_events:
    fail("trace slice has no prompt/chat events")

browser_chat_events = [(line, event) for line, event in events if is_browser_chat_event(event)]
if require_browser_chat_surface and not browser_chat_events:
    fail("trace slice has no browser chat proof events")

counts_by_bundle = Counter(
    str(event.get("appBundleIdentifier") or "unknown")
    for _, event in prompt_events
)
browser_chat_counts_by_bundle = Counter(
    str(event.get("appBundleIdentifier") or "unknown")
    for _, event in browser_chat_events
)
metric_examples: dict[str, list[str]] = {}
metric_counts: dict[str, int] = {}
for name, check in metric_checks:
    examples = [
        event_label(line_number, event)
        for line_number, event in prompt_events
        if check(event)
    ]
    metric_examples[name] = examples
    metric_counts[name] = len(examples)

line_label = f"{start_line}-{end_line}" if end_line is not None else f"{start_line}+"
print("Prompt/chat proof status")
print(f"Trace: {path}")
print(f"Lines: {line_label}")
print(f"Events checked: {len(events)}")
print(f"Prompt app events: {len(prompt_events)}")
print(f"Browser chat surface events: {len(browser_chat_events)}")
if counts_by_bundle:
    print("Prompt app events by bundle:")
    for bundle, count in sorted(counts_by_bundle.items()):
        print(f"- {bundle}: {count}")
if browser_chat_counts_by_bundle:
    print("Browser chat events by bundle:")
    for bundle, count in sorted(browser_chat_counts_by_bundle.items()):
        print(f"- {bundle}: {count}")
if proof_surface:
    print(f"Proof surface: {proof_surface}")
print("Prompt/chat safety metrics:")
for name, _ in metric_checks:
    print(f"- {name}: {metric_counts[name]}")

failures = [name for name, count in metric_counts.items() if count > 0]
if failures:
    print("", file=sys.stderr)
    print("Prompt/chat proof metric failures:", file=sys.stderr)
    for name in failures:
        print(f"- {name}: {metric_counts[name]}", file=sys.stderr)
        for example in metric_examples[name][:3]:
            print(f"  - {example}", file=sys.stderr)
    print(f"Prompt app proof gate failed with {len(failures)} nonzero metric(s).", file=sys.stderr)
    raise SystemExit(1)

print("Prompt app proof gate passed.")
PY
