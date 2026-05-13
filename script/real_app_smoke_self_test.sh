#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

script/real_app_smoke.sh textedit --help >"$TMP_DIR/help.txt"
if ! grep -F "fails closed unless" "$TMP_DIR/help.txt" >/dev/null ||
   ! grep -F "this checkout's dist/SteadyType.app binary" "$TMP_DIR/help.txt" >/dev/null; then
  echo "real app smoke help must explain --skip-build checkout verification" >&2
  exit 1
fi

script/real_app_smoke.sh textedit --dry-run >"$TMP_DIR/textedit.txt"
if ! grep -F "Real app smoke: textedit" "$TMP_DIR/textedit.txt" >/dev/null; then
  echo "real app smoke self-test did not print the TextEdit dry-run plan" >&2
  exit 1
fi
if ! grep -F "Proof mode bundle(s): com.apple.TextEdit" "$TMP_DIR/textedit.txt" >/dev/null; then
  echo "real app smoke self-test did not print the TextEdit proof mode bundle" >&2
  exit 1
fi
if ! grep -F "proof fragments are typed through System Events key events" "$TMP_DIR/textedit.txt" >/dev/null; then
  echo "real app smoke self-test did not explain TextEdit proof typing uses live key events" >&2
  exit 1
fi

script/real_app_smoke.sh textedit-model-latency --dry-run >"$TMP_DIR/textedit-model-latency.txt"
if ! grep -F "TextEdit variant: model-latency" "$TMP_DIR/textedit-model-latency.txt" >/dev/null ||
   ! grep -F "allow a cold local model warmup" "$TMP_DIR/textedit-model-latency.txt" >/dev/null ||
   ! grep -F "require real model-backed suggestions in one launch" "$TMP_DIR/textedit-model-latency.txt" >/dev/null ||
   ! grep -F "stable context into the disposable TextEdit AX target" "$TMP_DIR/textedit-model-latency.txt" >/dev/null ||
   ! grep -F "final partial word through live key events" "$TMP_DIR/textedit-model-latency.txt" >/dev/null ||
   ! grep -F "disables fast word completions for that launch" "$TMP_DIR/textedit-model-latency.txt" >/dev/null ||
   ! grep -F "scenario textedit-model-latency" "$TMP_DIR/textedit-model-latency.txt" >/dev/null ||
   ! grep -F "proof scenario: textedit-model-latency" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test did not print the TextEdit model latency dry-run plan" >&2
  exit 1
fi

if script/real_app_smoke.sh textedit-model-latency --skip-build --dry-run >"$TMP_DIR/textedit-model-latency-skip-build.txt" 2>&1; then
  echo "real app smoke self-test expected TextEdit model latency --skip-build to fail closed" >&2
  exit 1
fi
if ! grep -F "must relaunch with fast word completions disabled" "$TMP_DIR/textedit-model-latency-skip-build.txt" >/dev/null; then
  echo "real app smoke self-test expected TextEdit model latency --skip-build failure to explain the proof env requirement" >&2
  exit 1
fi

if ! grep -F 'AUTOCOMPLETE_LAB_TEXTEDIT_SMOKE_AX_INSERTION=0' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'TextEdit model latency stable context' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION=1' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_PROOF_SCENARIO="textedit-model-latency"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'TextEdit model latency seed settled' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected model latency proof to seed context before live key-trigger typing" >&2
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
start = source.index('run_textedit_model_latency()')
end = source.index('run_chrome_fixture()', start)
block = source[start:end]
if "wait_for_log_fields_optional \"$seed_start\"" not in block:
    raise SystemExit("model-latency proof must wait briefly for seed timing before the measured sample")
if "dismiss_textedit_smoke_suggestion" in block or "key code 53" in block:
    raise SystemExit("model-latency proof must not press Escape after seeding context")
PY

if ! grep -F 'PROOF_SCENARIO_LAUNCHCTL_PREVIOUS' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'launchctl unsetenv "$PROOF_SCENARIO_ENV_KEY"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected model latency proof scenario cleanup" >&2
  exit 1
fi

if ! grep -F 'textedit_document_name_exists' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'Open TextEdit documents:' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected TextEdit document-open diagnostics" >&2
  exit 1
fi

if ! awk '
  /textedit_model_latency_fragments\(\)/ { in_fragments = 1; next }
  in_fragments && /^EOF$/ { exit }
  in_fragments && $0 !~ /^  cat <<'\''EOF'\''$/ {
    word_count = split($0, words, /[[:space:]]+/)
    if (length(words[word_count]) > 5) {
      exit 1
    }
  }
' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected TextEdit model latency triggers to stay within word-completion length" >&2
  exit 1
fi

if ! grep -F 'AUTOCOMPLETE_LAB_TEXTEDIT_MODEL_LATENCY_RUNTIME_READY_TIMEOUT_SECONDS' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'textedit_model_latency_runtime_ready_timeout_seconds' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected TextEdit model latency to have its own cold-warm runtime timeout" >&2
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
start = source.index('wait_for_log_fields "$sample_start" "TextEdit model latency timing $sample_index"')
end = source.index('wait_for_log_fields "$sample_start" "TextEdit model latency visible $sample_index"', start)
block = source[start:end]
if '"mlx-completion-timing"' not in block or '"app=com.apple.TextEdit"' not in block:
    raise SystemExit("model-latency timing proof must still require TextEdit MLX timing")
if '"mode=wordCompletion"' in block:
    raise SystemExit("model-latency timing proof must not depend on a fragile request mode label")
start = source.index('wait_for_log_fields "$sample_start" "TextEdit model latency visible $sample_index"')
end = source.index('sleep 0.4', start)
block = source[start:end]
if '"candidateSelectionSource=app-model-result"' not in block:
    raise SystemExit("model-latency visible proof must require model-backed display")
if '"requestMode=wordCompletion"' in block:
    raise SystemExit("model-latency visible proof must not depend on a fragile request mode label")
PY

script/real_app_smoke.sh chrome --dry-run >"$TMP_DIR/chrome.txt"
if ! grep -F "disposable Chrome textarea fixture" "$TMP_DIR/chrome.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome dry-run plan" >&2
  exit 1
fi
if ! grep -F "Proof mode bundle(s): com.google.Chrome" "$TMP_DIR/chrome.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome proof mode bundle" >&2
  exit 1
fi

if ! grep -F "temporarily enables Chrome only for this proof pass" "$TMP_DIR/chrome.txt" >/dev/null; then
  echo "real app smoke self-test did not explain temporary Chrome enablement" >&2
  exit 1
fi
if ! grep -F "requires Chrome to expose a focused editable web text target" "$TMP_DIR/chrome.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Chrome focused editable guard" >&2
  exit 1
fi
if ! grep -F "Chrome setup text is seeded before SteadyType launches whenever the smoke builds the app itself" "$TMP_DIR/chrome.txt" >/dev/null ||
   ! grep -F "later Chrome setup pauses SteadyType while disposable text is seeded" "$TMP_DIR/chrome.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Chrome setup/relaunch guards" >&2
  exit 1
fi
if ! grep -F "Chrome setup text first tries DevTools/DOM or AX value replacement, then guarded key/paste fallbacks" "$TMP_DIR/chrome.txt" >/dev/null; then
  echo "real app smoke self-test did not explain targeted Chrome setup insertion" >&2
  exit 1
fi

if ! grep -F 'AUTOCOMPLETE_LAB_DIRECT_LAUNCH=1' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected proof runs to direct-launch the current app bundle" >&2
  exit 1
fi
if grep -F '|| screenshot_trace_requested' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected direct launch to be unconditional for proof runs" >&2
  exit 1
fi
if ! grep -F 'stop_current_steadytype_app_bundle' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected TextEdit proof to stop the old app before opening its disposable target" >&2
  exit 1
fi
if ! grep -F 'textedit_smoke_allows_ax_proof_typing' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_TEXTEDIT_SMOKE_TEXT="$fragment" osascript' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected TextEdit proof fragments to default to System Events key typing" >&2
  exit 1
fi
if ! grep -F 'move_textedit_caret_to_document_end "$window_title"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'set_textedit_selected_range "$window_title" "$utf16_length" 0' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected TextEdit proof typing to keep the caret at document end" >&2
  exit 1
fi
if ! grep -F 'wait_for_textedit_document_exact "$textedit_window_title" "" "TextEdit initial reset" 5' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'wait_for_textedit_document_exact "$textedit_window_title" "$first_fragment" "TextEdit first typed exact" 5' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected TextEdit proof setup to verify reset and first typed text before waiting for suggestions" >&2
  exit 1
fi
if ! grep -F 'cleanup_stale_textedit_smoke_windows' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'docName starts with "textedit-smoke-"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected stale TextEdit proof windows to be cleaned before opening a new disposable document" >&2
  exit 1
fi
if ! grep -F 'wait_for_background_process "$osascript_pid" 4 "stale TextEdit smoke cleanup"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'wait_for_background_process "$osascript_pid" 4 "TextEdit smoke cleanup"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected TextEdit cleanup AppleScript to be bounded so proof setup cannot hang" >&2
  exit 1
fi
if ! grep -F 'launch_steadytype_after_chrome_setup' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'pause_steadytype_for_chrome_setup' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Chrome proof to pause during setup and relaunch before proof" >&2
  exit 1
fi
if ! grep -F 'build_bundle_if_needed' script/real_app_smoke.sh >/dev/null ||
   ! grep -F './script/build_and_run.sh bundle-only' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Chrome proof to build before seeding and launch only for proof" >&2
  exit 1
fi
python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()

def function_body(name: str) -> str:
    marker = f"{name}() {{"
    start = source.index(marker)
    next_start = source.find("\n}\n\n", start)
    return source[start:next_start]

build_if_needed = function_body("build_if_needed")
build_bundle_if_needed = function_body("build_bundle_if_needed")
if "wait_for_current_autocomplete_lab_process\n  refresh_build_archive_proof" not in build_if_needed:
    raise SystemExit("build_if_needed must verify the current checkout process before proof")
if 'else\n    wait_for_current_autocomplete_lab_process' not in build_bundle_if_needed:
    raise SystemExit("build_bundle_if_needed must verify the current checkout process when --skip-build is used")
if "SteadyType smoke launch did not settle on this checkout" not in source:
    raise SystemExit("stale process failure message is missing")
PY
if ! grep -F 'local backup_path="${2:-}"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F "focused AX verification is deferred to the click/refocus step" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Codex seeding to allow refocus-step verification" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture contenteditable --dry-run >"$TMP_DIR/chrome-contenteditable.txt"
if ! grep -F "disposable Chrome contenteditable fixture" "$TMP_DIR/chrome-contenteditable.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome contenteditable dry-run plan" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture textarea-public --dry-run >"$TMP_DIR/chrome-textarea-public.txt"
if ! grep -F "public top-level textarea-public demo page" "$TMP_DIR/chrome-textarea-public.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome public textarea dry-run plan" >&2
  exit 1
fi
if ! grep -F "JavaScript-from-Apple-Events is not required" "$TMP_DIR/chrome-textarea-public.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Chrome public textarea AX proof path" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture contenteditable-public --dry-run >"$TMP_DIR/chrome-contenteditable-public.txt"
if ! grep -F "public top-level contenteditable-public demo page" "$TMP_DIR/chrome-contenteditable-public.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome public contenteditable dry-run plan" >&2
  exit 1
fi
if ! grep -F "JavaScript-from-Apple-Events is not required" "$TMP_DIR/chrome-contenteditable-public.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Chrome public contenteditable AX proof path" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture production-text-fields --dry-run >"$TMP_DIR/chrome-production-text-fields.txt"
if ! grep -F "bounded public Chrome textarea and contenteditable proof" "$TMP_DIR/chrome-production-text-fields.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome production text fields dry-run plan" >&2
  exit 1
fi
if ! grep -F "JavaScript-from-Apple-Events is not required" "$TMP_DIR/chrome-production-text-fields.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Chrome production text fields AX proof path" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture editor-like --dry-run >"$TMP_DIR/chrome-editor-like.txt"
if ! grep -F "disposable Chrome editor-like fixture" "$TMP_DIR/chrome-editor-like.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome editor-like dry-run plan" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture monaco-like --dry-run >"$TMP_DIR/chrome-monaco-like.txt"
if ! grep -F "disposable Chrome monaco-like fixture" "$TMP_DIR/chrome-monaco-like.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome Monaco-like dry-run plan" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture prosemirror-like --dry-run >"$TMP_DIR/chrome-prosemirror-like.txt"
if ! grep -F "disposable Chrome prosemirror-like fixture" "$TMP_DIR/chrome-prosemirror-like.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome ProseMirror-like dry-run plan" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture monaco-real --dry-run >"$TMP_DIR/chrome-monaco-real.txt"
if ! grep -F "disposable Chrome monaco-real fixture" "$TMP_DIR/chrome-monaco-real.txt" >/dev/null; then
  echo "real app smoke self-test did not print the real Chrome Monaco dry-run plan" >&2
  exit 1
fi
if ! grep -F "Chrome accessibility: isolated Chrome with forced renderer accessibility for local fixtures" "$TMP_DIR/chrome-monaco-real.txt" >/dev/null; then
  echo "real app smoke self-test did not print the forced Chrome accessibility mode" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture monaco-real --chrome-accessibility default --dry-run >"$TMP_DIR/chrome-monaco-real-default.txt"
if ! grep -F "Chrome accessibility: default Chrome accessibility exposure; experimental proof lane, weaker than isolated forced renderer mode" "$TMP_DIR/chrome-monaco-real-default.txt" >/dev/null; then
  echo "real app smoke self-test did not print the default Chrome accessibility proof lane" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture=prosemirror-real --chrome-accessibility=default --dry-run >"$TMP_DIR/chrome-prosemirror-real-default.txt"
if ! grep -F "Chrome fixture: prosemirror-real" "$TMP_DIR/chrome-prosemirror-real-default.txt" >/dev/null; then
  echo "real app smoke self-test did not parse --chrome-accessibility=default with --fixture=prosemirror-real" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture prosemirror-real --dry-run >"$TMP_DIR/chrome-prosemirror-real.txt"
if ! grep -F "disposable Chrome prosemirror-real fixture" "$TMP_DIR/chrome-prosemirror-real.txt" >/dev/null; then
  echo "real app smoke self-test did not print the real Chrome ProseMirror dry-run plan" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture chat-like --dry-run >"$TMP_DIR/chrome-chat-like.txt"
if ! grep -F "disposable Chrome chat-like fixture" "$TMP_DIR/chrome-chat-like.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome chat-like dry-run plan" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture browser-chat-harness --dry-run >"$TMP_DIR/chrome-browser-chat-harness.txt"
if ! grep -F "bounded HTTP browser-chat no-submit proof harness" "$TMP_DIR/chrome-browser-chat-harness.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome browser-chat harness dry-run plan" >&2
  exit 1
fi
if ! grep -F "does not enable Slack, Discord, ChatGPT, or broad browser chat support" "$TMP_DIR/chrome-browser-chat-harness.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome browser-chat harness scope warning" >&2
  exit 1
fi

for blocked_fixture in google-docs notion browser-chatgpt browser-slack browser-discord; do
  script/real_app_smoke.sh chrome --fixture "$blocked_fixture" --dry-run >"$TMP_DIR/chrome-$blocked_fixture.txt"
  if ! grep -F "blocked preflight only" "$TMP_DIR/chrome-$blocked_fixture.txt" >/dev/null; then
    echo "real app smoke self-test did not print the Chrome $blocked_fixture blocked plan" >&2
    exit 1
  fi
  if ! grep -F "refuses to type into the live service" "$TMP_DIR/chrome-$blocked_fixture.txt" >/dev/null; then
    echo "real app smoke self-test did not explain the Chrome $blocked_fixture no-typing guard" >&2
    exit 1
  fi
  if script/real_app_smoke.sh chrome --fixture "$blocked_fixture" >"$TMP_DIR/chrome-$blocked_fixture-run.txt" 2>&1; then
    echo "real app smoke self-test expected Chrome $blocked_fixture to fail closed before typing" >&2
    exit 1
  fi
  if ! grep -F "No Chrome typing was attempted." "$TMP_DIR/chrome-$blocked_fixture-run.txt" >/dev/null; then
    echo "real app smoke self-test did not confirm Chrome $blocked_fixture failed closed before typing" >&2
    exit 1
  fi
done

script/real_browser_chat_proof.sh --dry-run >"$TMP_DIR/real-browser-chat-proof.txt"
if ! grep -F "Chrome fixture: browser-chat-harness" "$TMP_DIR/real-browser-chat-proof.txt" >/dev/null; then
  echo "real browser chat proof wrapper did not select the browser-chat harness fixture" >&2
  exit 1
fi

for official_fixture in codemirror-official monaco-official prosemirror-official; do
  script/real_app_smoke.sh chrome --fixture "$official_fixture" --dry-run >"$TMP_DIR/chrome-$official_fixture.txt"
  if ! grep -F "public official $official_fixture demo page" "$TMP_DIR/chrome-$official_fixture.txt" >/dev/null; then
    echo "real app smoke self-test did not print the Chrome $official_fixture dry-run plan" >&2
    exit 1
  fi
  if ! grep -F "isolated temporary Chrome profile plus localhost DevTools focus/setup" "$TMP_DIR/chrome-$official_fixture.txt" >/dev/null; then
    echo "real app smoke self-test did not print the Chrome $official_fixture isolated DevTools proof path" >&2
    exit 1
  fi
  if ! grep -F "macOS Accessibility" "$TMP_DIR/chrome-$official_fixture.txt" >/dev/null; then
    echo "real app smoke self-test did not print the Chrome $official_fixture Accessibility preflight requirement" >&2
    exit 1
  fi
  if ! grep -F "allow up to 180s" "$TMP_DIR/chrome-$official_fixture.txt" >/dev/null; then
    echo "real app smoke self-test did not print the Chrome $official_fixture cold runtime timeout" >&2
    exit 1
  fi
done

script/real_app_smoke.sh chrome --fixture monaco-official --chrome-accessibility default --dry-run >"$TMP_DIR/chrome-monaco-official-default.txt"
if ! grep -F "Monaco official must expose setup text through the focused macOS AX editor" "$TMP_DIR/chrome-monaco-official-default.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Monaco official AX-readable setup gate" >&2
  exit 1
fi
if ! grep -F "monaco-official default AX uses normal Chrome AX focus only" "$TMP_DIR/chrome-monaco-official-default.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Monaco official default-AX no-fallback path" >&2
  exit 1
fi
if ! grep -F 'wait_for_chrome_setup_text_visible_to_ax "$fixture" "$chrome_pid" "$expected_fragment" "$label"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Monaco official setup to require AX-readable text after DevTools setup" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture all --dry-run >"$TMP_DIR/chrome-all.txt"
if ! grep -F "textarea, contenteditable, editor-like, Monaco-like, ProseMirror-like, real Monaco, real ProseMirror, and chat-like no-submit local fixtures" "$TMP_DIR/chrome-all.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome all-fixtures dry-run plan" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture all --include-default-real-editor-proof --dry-run >"$TMP_DIR/chrome-all-default-addon.txt"
if ! grep -F "rerun real Monaco and real ProseMirror in default Chrome AX mode after the forced renderer lane" "$TMP_DIR/chrome-all-default-addon.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome default AX add-on plan" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture=contenteditable --dry-run >"$TMP_DIR/chrome-contenteditable-equals.txt"
if ! grep -F "Chrome fixture: contenteditable" "$TMP_DIR/chrome-contenteditable-equals.txt" >/dev/null; then
  echo "real app smoke self-test did not parse --fixture=contenteditable" >&2
  exit 1
fi

script/real_app_smoke.sh notes --dry-run >"$TMP_DIR/notes.txt"
if ! grep -F "choose a manual-gated Apple Notes surface" "$TMP_DIR/notes.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Notes surface picker" >&2
  exit 1
fi

for notes_surface in notes-title notes-title-short notes-title-long notes-body notes-body-short notes-body-long notes-checklist notes-checklist-checked notes-checklist-long notes-title-undo notes-body-undo notes-checklist-undo; do
  script/real_app_smoke.sh "$notes_surface" --dry-run >"$TMP_DIR/$notes_surface.txt"
  case "$notes_surface" in
    notes-title-short)
      expected_plan="guarded Apple Notes short title proof"
      ;;
    notes-title-long)
      expected_plan="guarded Apple Notes long title proof"
      ;;
    notes-title-undo)
      expected_plan="guarded Apple Notes title undo proof"
      ;;
    notes-body-short)
      expected_plan="guarded Apple Notes short body proof"
      ;;
    notes-body-long)
      expected_plan="guarded Apple Notes long body proof"
      ;;
    notes-body-undo)
      expected_plan="guarded Apple Notes body undo proof"
      ;;
    notes-checklist-checked)
      expected_plan="guarded Apple Notes checked checklist proof"
      ;;
    notes-checklist-long)
      expected_plan="guarded Apple Notes long checklist proof"
      ;;
    notes-checklist-undo)
      expected_plan="guarded Apple Notes checklist undo proof"
      ;;
    *)
      expected_plan="guarded Apple Notes ${notes_surface#notes-} proof"
      ;;
  esac
  if ! grep -F "$expected_plan" "$TMP_DIR/$notes_surface.txt" >/dev/null; then
    echo "real app smoke self-test did not print the $notes_surface proof plan" >&2
    exit 1
  fi
done

if ! grep -F "Command-Z" "$TMP_DIR/notes-title-undo.txt" >/dev/null ||
   ! grep -F "same-slice undo" "$TMP_DIR/notes-body-undo.txt" >/dev/null ||
   ! grep -F "same-slice undo" "$TMP_DIR/notes-checklist-undo.txt" >/dev/null; then
  echo "real app smoke self-test expected Notes undo lanes to be automated guarded proofs" >&2
  exit 1
fi

if ! grep -F "bodyText.utf16.count" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "kAXSelectedTextRangeAttribute" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Notes body proof to move the caret to the end of the disposable note" >&2
  exit 1
fi
if ! grep -F "kAXFocusedUIElementAttribute" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "Focused Notes element is not the body text view" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Notes body proof to validate the focused text view without walking the Notes AX tree" >&2
  exit 1
fi
if ! grep -F "Refusing Notes title proof because the fresh title line is not blank" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "ensure_notes_title_smoke_note" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Notes title proof to guard a fresh blank title line before typing" >&2
  exit 1
fi
if ! grep -F "Refusing Notes checklist proof because the focused note does not start with the expected disposable checklist prefix" script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'click menu item "Checklist"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Notes checklist proof to guard a disposable checklist note before typing" >&2
  exit 1
fi
if ! grep -F 'system attribute "AUTOCOMPLETE_LAB_NOTES_RAW_TEXT"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F "keystroke rawText" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Notes body setup to type through System Events" >&2
  exit 1
fi

script/real_app_smoke.sh obsidian --dry-run >"$TMP_DIR/obsidian.txt"
if ! grep -F "manual-gated disposable Obsidian default-note smoke" "$TMP_DIR/obsidian.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Obsidian manual gate" >&2
  exit 1
fi

if ! grep -F "script/real_app_smoke.sh obsidian-theme --manual-gate" "$TMP_DIR/obsidian.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Obsidian theme command" >&2
  exit 1
fi

if ! grep -F "markerText.utf16.count" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER_TEXT" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Obsidian reset to move the AX selected range to the end of the disposable note" >&2
  exit 1
fi

for obsidian_variant in obsidian-theme obsidian-pane obsidian-long-note; do
  script/real_app_smoke.sh "$obsidian_variant" --dry-run >"$TMP_DIR/$obsidian_variant.txt"
  case "$obsidian_variant" in
    obsidian-theme)
      expected_plan="guarded Obsidian non-default theme proof"
      ;;
    *)
      expected_plan="manual-gated Obsidian"
      ;;
  esac
  if ! grep -F "$expected_plan" "$TMP_DIR/$obsidian_variant.txt" >/dev/null; then
    echo "real app smoke self-test did not print the $obsidian_variant proof plan" >&2
    exit 1
  fi
done

if script/real_app_smoke.sh chrome --fixture unknown --dry-run >/dev/null 2>&1; then
  echo "real app smoke self-test expected unknown Chrome fixtures to fail" >&2
  exit 1
fi

LOCK_DIR="$TMP_DIR/smoke.lock"
mkdir -p "$LOCK_DIR"
echo "$$" >"$LOCK_DIR/pid"
if AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST="" \
  AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR="$LOCK_DIR" \
  AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_WAIT_SECONDS=0 \
  script/real_app_smoke.sh codex >/dev/null 2>"$TMP_DIR/lock-fail.txt"; then
  echo "real app smoke self-test expected concurrent smoke lock to fail" >&2
  exit 1
fi
if ! grep -F "Another real app smoke run is already active" "$TMP_DIR/lock-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the concurrent smoke lock" >&2
  exit 1
fi
rm -rf "$LOCK_DIR"

if AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_WAIT_SECONDS=0 AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST=$'123 1 999 bash ./script/real_app_smoke.sh chrome --fixture textarea\n' script/real_app_smoke.sh codex >/dev/null 2>"$TMP_DIR/process-fail.txt"; then
  echo "real app smoke self-test expected concurrent process scan to fail" >&2
  exit 1
fi
if ! grep -F "Another real app smoke process is already active" "$TMP_DIR/process-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the concurrent process scan" >&2
  exit 1
fi

if script/real_app_smoke.sh chrome --fixture >/dev/null 2>&1; then
  echo "real app smoke self-test expected missing Chrome fixture values to fail" >&2
  exit 1
fi

if script/real_app_smoke.sh chrome --chrome-accessibility unknown --dry-run >/dev/null 2>&1; then
  echo "real app smoke self-test expected unknown Chrome accessibility modes to fail" >&2
  exit 1
fi

if script/real_app_smoke.sh chrome --chrome-accessibility >/dev/null 2>&1; then
  echo "real app smoke self-test expected missing Chrome accessibility values to fail" >&2
  exit 1
fi

if script/real_app_smoke.sh chrome --fixture monaco-real --include-default-real-editor-proof --dry-run >/dev/null 2>&1; then
  echo "real app smoke self-test expected default real-editor add-on without all fixtures to fail" >&2
  exit 1
fi

if script/real_app_smoke.sh chrome --fixture all --chrome-accessibility default --include-default-real-editor-proof --dry-run >/dev/null 2>&1; then
  echo "real app smoke self-test expected default real-editor add-on from default accessibility mode to fail" >&2
  exit 1
fi

if script/real_app_smoke.sh textedit --include-default-real-editor-proof --dry-run >/dev/null 2>&1; then
  echo "real app smoke self-test expected Chrome default real-editor add-on outside Chrome to fail" >&2
  exit 1
fi

if script/real_app_smoke.sh textedit --fixture contenteditable --dry-run >/dev/null 2>&1; then
  echo "real app smoke self-test expected non-Chrome fixtures to fail" >&2
  exit 1
fi

if script/real_app_smoke.sh textedit --chrome-accessibility default --dry-run >/dev/null 2>&1; then
  echo "real app smoke self-test expected non-Chrome accessibility modes to fail" >&2
  exit 1
fi

if script/real_app_smoke.sh textedit --host terminal --dry-run >/dev/null 2>&1; then
  echo "real app smoke self-test expected Claude Code host variants outside Claude Code to fail" >&2
  exit 1
fi

if script/real_app_smoke.sh claude-code --host unknown --dry-run >/dev/null 2>&1; then
  echo "real app smoke self-test expected unknown Claude Code host variants to fail" >&2
  exit 1
fi

script/real_app_smoke.sh codex --dry-run >"$TMP_DIR/codex.txt"
if ! grep -F "one-word Tab accept without submit" "$TMP_DIR/codex.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Codex one-word no-submit proof" >&2
  exit 1
fi
if ! grep -F "seeds disposable AUTOCOMPLETE_LAB_CODEX_PROOF text" "$TMP_DIR/codex.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Codex targeted proof seed" >&2
  exit 1
fi
if ! grep -F "backs it up privately and restores it after the no-submit proof" "$TMP_DIR/codex.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Codex draft restore guard" >&2
  exit 1
fi
if ! grep -F "Proof mode bundle(s): com.openai.codex" "$TMP_DIR/codex.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Codex proof mode bundle" >&2
  exit 1
fi
if [[ "$(grep -F "seed_codex_proof_prompt" script/real_app_smoke.sh | wc -l | tr -d ' ')" -lt 2 ]]; then
  echo "real app smoke self-test expected Codex proof to refocus the seeded composer before Tab" >&2
  exit 1
fi
if ! grep -F "codex-proof-snapshot-fast-path" Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null; then
  echo "real app smoke self-test expected proof-only Codex snapshot fast path diagnostics" >&2
  exit 1
fi
if ! grep -F "codex-proof-insert-verification-fast-path" Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null; then
  echo "real app smoke self-test expected proof-only Codex insertion verification fast path diagnostics" >&2
  exit 1
fi

script/real_app_smoke.sh claude-code --dry-run >"$TMP_DIR/claude-code.txt"
if ! grep -F "one-word Tab accept without submit" "$TMP_DIR/claude-code.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Claude Code one-word no-submit proof" >&2
  exit 1
fi
if ! grep -F "Proof mode bundle(s): com.anthropic.claude-code" "$TMP_DIR/claude-code.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Claude Code proof mode bundle" >&2
  exit 1
fi
if ! grep -F "terminal-host Claude Code proof" "$TMP_DIR/claude-code.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Claude Code terminal-host proof lane" >&2
  exit 1
fi
if ! grep -F "Claude Code proof label: default" "$TMP_DIR/claude-code.txt" >/dev/null; then
  echo "real app smoke self-test did not print the default Claude Code proof label" >&2
  exit 1
fi

script/real_app_smoke.sh claude-code --host terminal --dry-run >"$TMP_DIR/claude-code-terminal.txt"
if ! grep -F "Claude Code host: Terminal (com.apple.Terminal)" "$TMP_DIR/claude-code-terminal.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Claude Code Terminal host variant" >&2
  exit 1
fi
if ! grep -F "Claude Code proof label: claude-code-terminal" "$TMP_DIR/claude-code-terminal.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Claude Code Terminal proof label" >&2
  exit 1
fi

script/real_app_smoke.sh claude-code-iterm2 --dry-run >"$TMP_DIR/claude-code-iterm2.txt"
if ! grep -F "Claude Code host: iTerm2 (com.googlecode.iterm2)" "$TMP_DIR/claude-code-iterm2.txt" >/dev/null; then
  echo "real app smoke self-test did not parse the Claude Code iTerm2 alias" >&2
  exit 1
fi

script/real_app_smoke.sh claude-code-warp --dry-run >"$TMP_DIR/claude-code-warp.txt"
if ! grep -F "honest proof gap" "$TMP_DIR/claude-code-warp.txt" >/dev/null; then
  echo "real app smoke self-test did not document missing Claude Code host variants as proof gaps" >&2
  exit 1
fi

script/real_app_smoke.sh claude --dry-run >"$TMP_DIR/claude.txt"
if ! grep -F "full accept waits for separate full-accept no-submit proof" "$TMP_DIR/claude.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Claude full-accept gate" >&2
  exit 1
fi

for claude_variant in claude-empty claude-long claude-wrapped claude-narrow claude-context claude-light claude-dark; do
  script/real_app_smoke.sh "$claude_variant" --dry-run >"$TMP_DIR/$claude_variant.txt"
  if ! grep -F "Claude layout proof: $claude_variant" "$TMP_DIR/$claude_variant.txt" >/dev/null; then
    echo "real app smoke self-test did not label the $claude_variant layout proof" >&2
    exit 1
  fi
  if ! grep -F "full accept waits for separate full-accept no-submit proof" "$TMP_DIR/$claude_variant.txt" >/dev/null; then
    echo "real app smoke self-test did not keep full accept blocked for $claude_variant" >&2
    exit 1
  fi
done

if script/real_app_smoke.sh unknown --dry-run >/dev/null 2>&1; then
  echo "real app smoke self-test expected unknown apps to fail" >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST=$'1 1 1 launchd\n' \
  AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR="$TMP_DIR/codex-safety.lock" \
  script/real_app_smoke.sh codex >/dev/null 2>"$TMP_DIR/codex-fail.txt"; then
  echo "real app smoke self-test expected Codex to require --manual-gate" >&2
  exit 1
fi

if ! grep -F "requires --manual-gate" "$TMP_DIR/codex-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Codex safety gate" >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST=$'1 1 1 launchd\n' \
  AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR="$TMP_DIR/claude-code-safety.lock" \
  script/real_app_smoke.sh claude-code >/dev/null 2>"$TMP_DIR/claude-code-fail.txt"; then
  echo "real app smoke self-test expected Claude Code to require --manual-gate" >&2
  exit 1
fi

if ! grep -F "requires --manual-gate" "$TMP_DIR/claude-code-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Claude Code safety gate" >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST=$'1 1 1 launchd\n' \
  AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR="$TMP_DIR/notes-safety.lock" \
  script/real_app_smoke.sh notes >/dev/null 2>"$TMP_DIR/notes-fail.txt"; then
  echo "real app smoke self-test expected Notes to require --manual-gate" >&2
  exit 1
fi

if ! grep -F "private Apple Notes content" "$TMP_DIR/notes-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Notes safety gate" >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST=$'1 1 1 launchd\n' \
  AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR="$TMP_DIR/notes-generic.lock" \
  script/real_app_smoke.sh notes --manual-gate >/dev/null 2>"$TMP_DIR/notes-generic-fail.txt"; then
  echo "real app smoke self-test expected generic Notes proof to require a surface" >&2
  exit 1
fi

if ! grep -F "Notes real smoke cannot record a generic Notes proof" "$TMP_DIR/notes-generic-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the generic Notes proof failure" >&2
  exit 1
fi

if ! grep -F "script/real_app_smoke.sh notes-title --manual-gate" "$TMP_DIR/notes-generic-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Notes title command after generic proof failure" >&2
  exit 1
fi

if ! grep -F "script/real_app_smoke.sh notes-title-undo --manual-gate" "$TMP_DIR/notes-generic-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Notes title undo command after generic proof failure" >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST=$'1 1 1 launchd\n' \
  AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR="$TMP_DIR/obsidian-safety.lock" \
  script/real_app_smoke.sh obsidian >/dev/null 2>"$TMP_DIR/obsidian-fail.txt"; then
  echo "real app smoke self-test expected Obsidian to require --manual-gate" >&2
  exit 1
fi

if ! grep -F "private Obsidian vault" "$TMP_DIR/obsidian-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Obsidian safety gate" >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST=$'1 1 1 launchd\n' \
  AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR="$TMP_DIR/obsidian-theme-safety.lock" \
  script/real_app_smoke.sh obsidian-theme >/dev/null 2>"$TMP_DIR/obsidian-theme-fail.txt"; then
  echo "real app smoke self-test expected Obsidian variants to require --manual-gate" >&2
  exit 1
fi

if ! grep -F "private Obsidian vault" "$TMP_DIR/obsidian-theme-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Obsidian variant safety gate" >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST=$'1 1 1 launchd\n' \
  AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR="$TMP_DIR/claude-safety.lock" \
  script/real_app_smoke.sh claude >/dev/null 2>"$TMP_DIR/claude-fail.txt"; then
  echo "real app smoke self-test expected Claude to require --manual-gate" >&2
  exit 1
fi

if ! grep -F "requires --manual-gate" "$TMP_DIR/claude-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Claude safety gate" >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST=$'1 1 1 launchd\n' \
  AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR="$TMP_DIR/claude-empty-safety.lock" \
  script/real_app_smoke.sh claude-empty >/dev/null 2>"$TMP_DIR/claude-empty-fail.txt"; then
  echo "real app smoke self-test expected Claude layout variants to require --manual-gate" >&2
  exit 1
fi

if ! grep -F "requires --manual-gate" "$TMP_DIR/claude-empty-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Claude layout safety gate" >&2
  exit 1
fi

echo "Real app smoke self-test passed."
