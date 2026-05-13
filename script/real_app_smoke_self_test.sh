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
   ! grep -F "disables fast word completions and phrase continuations for that launch" "$TMP_DIR/textedit-model-latency.txt" >/dev/null ||
   ! grep -F "scenario textedit-model-latency" "$TMP_DIR/textedit-model-latency.txt" >/dev/null ||
   ! grep -F "proof scenario: textedit-model-latency" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test did not print the TextEdit model latency dry-run plan" >&2
  exit 1
fi

if script/real_app_smoke.sh textedit-model-latency --skip-build --dry-run >"$TMP_DIR/textedit-model-latency-skip-build.txt" 2>&1; then
  echo "real app smoke self-test expected TextEdit model latency --skip-build to fail closed" >&2
  exit 1
fi
if ! grep -F "must relaunch with fast word completions and phrase continuations disabled" "$TMP_DIR/textedit-model-latency-skip-build.txt" >/dev/null; then
  echo "real app smoke self-test expected TextEdit model latency --skip-build failure to explain the proof env requirement" >&2
  exit 1
fi

script/real_app_smoke.sh textedit-default-model-latency --dry-run >"$TMP_DIR/textedit-default-model-latency.txt"
if ! grep -F "TextEdit variant: default-model-latency" "$TMP_DIR/textedit-default-model-latency.txt" >/dev/null ||
   ! grep -F "default phrase model suggestions" "$TMP_DIR/textedit-default-model-latency.txt" >/dev/null ||
   ! grep -F "trailing space through live key events" "$TMP_DIR/textedit-default-model-latency.txt" >/dev/null ||
   ! grep -F "disables word completions and fast phrase fallback for that launch" "$TMP_DIR/textedit-default-model-latency.txt" >/dev/null ||
   ! grep -F "scenario textedit-default-model-latency" "$TMP_DIR/textedit-default-model-latency.txt" >/dev/null ||
   ! grep -F "proof scenario: textedit-default-model-latency" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test did not print the TextEdit default model latency dry-run plan" >&2
  exit 1
fi

if script/real_app_smoke.sh textedit-default-model-latency --skip-build --dry-run >"$TMP_DIR/textedit-default-model-latency-skip-build.txt" 2>&1; then
  echo "real app smoke self-test expected TextEdit default model latency --skip-build to fail closed" >&2
  exit 1
fi
if ! grep -F "must relaunch with word completions and the fast phrase fallback disabled" "$TMP_DIR/textedit-default-model-latency-skip-build.txt" >/dev/null; then
  echo "real app smoke self-test expected TextEdit default model latency --skip-build failure to explain the proof env requirement" >&2
  exit 1
fi

if ! grep -F 'AUTOCOMPLETE_LAB_TEXTEDIT_SMOKE_AX_INSERTION=0' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'TextEdit model latency stable context' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION=1' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION=1' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'export AUTOCOMPLETE_LAB_TEXTEDIT_SINGLE_WINDOW_FALLBACK=1' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_PROOF_SCENARIO="textedit-model-latency"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'TextEdit model latency seed settled' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected model latency proof to seed context before live key-trigger typing with non-word modes disabled" >&2
  exit 1
fi

if ! grep -F 'run_textedit_default_model_latency()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_PROOF_DISABLE_WORD_COMPLETION=1' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_PHRASE_FALLBACK=1' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'TextEdit default model latency stable context' script/real_app_smoke.sh >/dev/null ||
   ! grep -F '"mode=phraseContinuation"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F '"maxTokens=11"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'visible_sample_count' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'reason=empty-suggestion' script/real_app_smoke.sh >/dev/null ||
   ! grep -F './script/model_latency_report.py --default-model-proof' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected default model latency proof to force and count visible phrase model samples" >&2
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
start = source.index('run_textedit_model_latency()')
end = source.index('run_textedit_default_model_latency()', start)
block = source[start:end]
if "wait_for_log_fields_optional \"$seed_start\"" not in block:
    raise SystemExit("model-latency proof must wait briefly for seed timing before the measured sample")
if "describe_textedit_model_latency_seed_miss" not in block:
    raise SystemExit("model-latency proof must diagnose missing seed logs before the measured sample")
if 'wait_for_log_fields "$seed_start" "TextEdit model latency disabled phrase seed' in block:
    raise SystemExit("model-latency proof must not hard-fail before typing the measured trigger")
if 'proof_runtime_guard_line="$(line_count "$LOG_PATH")"' not in block:
    raise SystemExit("model-latency proof must remember the tagged runtime launch before opening TextEdit")
if block.count('assert_no_runtime_relaunch_since "$proof_runtime_guard_line"') < 2:
    raise SystemExit("model-latency proof must fail clearly if another runtime relaunches before sampling")
if "dismiss_textedit_smoke_suggestion" in block or "key code 53" in block:
    raise SystemExit("model-latency proof must not press Escape after seeding context")
runtime_ready = block.index('"TextEdit model latency runtime readiness"')
sample_window = block.index('start_line="$(line_count "$LOG_PATH")"', runtime_ready)
post_runtime_block = block[runtime_ready:sample_window]
if "focus_textedit_smoke_editor" not in post_runtime_block or "click_textedit_smoke_editor" not in post_runtime_block:
    raise SystemExit("model-latency proof must refocus TextEdit after build/runtime warmup before sampling")
trigger = block.index('type_textedit_smoke_fragment "$textedit_window_title" "$trigger_text"')
timing = block.index('wait_for_log_fields_optional "$sample_start" 20', trigger)
if 'move_textedit_caret_to_document_end "$textedit_window_title"' in block[trigger:timing]:
    raise SystemExit("model-latency proof must not move the caret while the measured model request is in flight")
if "visible_sample_count" not in block or "model_sample_count" not in block:
    raise SystemExit("model-latency proof must count actual visible and timed model-backed samples")
if "visible_sample_count >= 5" not in block:
    raise SystemExit("model-latency proof must stop only after five visible model-backed word completions")

default_start = source.index('run_textedit_default_model_latency()')
default_end = source.index('run_chrome_fixture()', default_start)
default_block = source[default_start:default_end]
default_prepare_start = source.index('prepare_default_model_latency_runtime_options()')
default_prepare_end = source.index('accept_all_shortcut()', default_prepare_start)
default_prepare_block = source[default_prepare_start:default_prepare_end]
if "dismiss_textedit_proof_suggestion" in default_block or "key code 53" in default_block:
    raise SystemExit("default-model phrase proof must not press Escape after seeding context")
if "prepare_default_model_latency_runtime_options" not in default_block:
    raise SystemExit("default-model phrase proof must prepare its proof-only runtime flags")
if "AUTOCOMPLETE_LAB_PROOF_DISABLE_WORD_COMPLETION=1" not in default_prepare_block:
    raise SystemExit("default-model phrase proof must disable seed word completions before measuring the trailing-space trigger")

app_delegate = Path("Sources/AutocompleteLabApp/App/AppDelegate.swift").read_text()
if "pollTimer?.fireDate" in app_delegate:
    raise SystemExit("focused text polling must not defer the shared timer past a future faster cadence state")
insert_start = app_delegate.index("private func insertObsidianDirectValueText(")
insert_end = app_delegate.index("private func moveFrontmostInsertionPointToLineEnd()", insert_start)
insert_block = app_delegate[insert_start:insert_end]
if "focusedTextAreaElementIdentifier" not in insert_block:
    raise SystemExit("Obsidian direct insertion fallback must verify the currently focused AX text area")
if "elementIdentifier: focusedTextAreaElementIdentifier" not in insert_block:
    raise SystemExit("Obsidian direct insertion fallback must pass the focused AX text area identity into descendant matching")
fallback_start = app_delegate.index("nonisolated private static func axTextAreaDescendantContainingText(")
fallback_end = app_delegate.index("nonisolated private static func replacementRange(", fallback_start)
fallback_block = app_delegate[fallback_start:fallback_end]
if "Int(CFHash(element)) == elementIdentifier" not in fallback_block:
    raise SystemExit("Obsidian descendant fallback must only match the currently focused AX text area")
PY

if ! grep -F 'PROOF_SCENARIO_LAUNCHCTL_PREVIOUS' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'PROOF_DISABLE_WORD_LAUNCHCTL_PREVIOUS' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'PROOF_DISABLE_PHRASE_LAUNCHCTL_PREVIOUS' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'PROOF_DISABLE_FAST_PHRASE_LAUNCHCTL_PREVIOUS' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'launchctl unsetenv "$PROOF_DISABLE_WORD_ENV_KEY"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'launchctl unsetenv "$PROOF_DISABLE_PHRASE_ENV_KEY"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'launchctl unsetenv "$PROOF_DISABLE_FAST_PHRASE_ENV_KEY"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'launchctl unsetenv "$PROOF_SCENARIO_ENV_KEY"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected model latency proof scenario cleanup" >&2
  exit 1
fi

if ! grep -F 'textedit_document_name_exists' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'Open TextEdit documents:' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_TEXTEDIT_SINGLE_WINDOW_FALLBACK' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'textedit_single_smoke_window_ready' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'run_osascript_with_timeout 4 "TextEdit AppleScript open"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'run_osascript_with_timeout "${AUTOCOMPLETE_LAB_TEXTEDIT_DOCUMENT_NAME_PROBE_TIMEOUT_SECONDS:-2}" "TextEdit document-name probe"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'run_osascript_with_timeout "${AUTOCOMPLETE_LAB_TEXTEDIT_DOCUMENT_LIST_TIMEOUT_SECONDS:-2}" "TextEdit document-list diagnostic"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'run_osascript_with_timeout 2 "frontmost app probe"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'run_osascript_with_timeout 1 "frontmost app wait probe"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'force_quit_textedit_if_only_smoke_windows' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected TextEdit document-open diagnostics" >&2
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()

def function_body(name: str) -> str:
    marker = f"{name}() {{"
    start = source.index(marker)
    end = source.index("\n}\n\n", start) + 3
    return source[start:end]

textedit_focus_blocks = {
    "raise_textedit_smoke_window": source[
        source.index("raise_textedit_smoke_window()"):
        source.index("click_textedit_smoke_window()", source.index("raise_textedit_smoke_window()"))
    ],
    "click_textedit_smoke_window": source[
        source.index("click_textedit_smoke_window()"):
        source.index("nudge_textedit_frontmost()", source.index("click_textedit_smoke_window()"))
    ],
}
for name, block in textedit_focus_blocks.items():
    if 'textedit_document_name_exists "$window_title"' in block:
        raise SystemExit(f"{name} must not run the TextEdit document-name AppleScript probe on the focus/click hot path")
    if 'local single_window_fallback="${AUTOCOMPLETE_LAB_TEXTEDIT_SINGLE_WINDOW_FALLBACK:-0}"' not in block:
        raise SystemExit(f"{name} must make single-window fallback an explicit proof flag")
    if "activateIgnoringOtherApps" not in block:
        raise SystemExit(f"{name} must force TextEdit foreground activation for live key-event proof")
    if "print(app.processIdentifier)" not in block:
        raise SystemExit(f"{name} must return the TextEdit pid, not the currently frontmost app pid")
    if "allowSingleWindowFallback && windows.count == 1 ? windows[0]" in block:
        raise SystemExit(f"{name} must not treat any single TextEdit window as safe fallback")
    if 'title.hasPrefix("textedit-model-latency-")' not in block:
        raise SystemExit(f"{name} fallback must be limited to disposable smoke/proof windows")
    if 'title.hasPrefix("textedit-default-model-latency-")' not in block:
        raise SystemExit(f"{name} fallback must include disposable default-model-latency proof windows")

frontmost_start = source.index("textedit_frontmost_window_is()")
frontmost_end = source.index("wait_for_textedit_frontmost_window()", frontmost_start)
frontmost_block = source[frontmost_start:frontmost_end]
if 'AUTOCOMPLETE_LAB_TEXTEDIT_SINGLE_WINDOW_FALLBACK' not in frontmost_block or 'allowSingleWindowFallback && windows.count == 1' not in frontmost_block:
    raise SystemExit("TextEdit frontmost proof must honor the single-window fallback")
if 'title.hasPrefix("textedit-model-latency-")' not in frontmost_block:
    raise SystemExit("TextEdit frontmost fallback must be limited to disposable smoke/proof windows")
if 'title.hasPrefix("textedit-default-model-latency-")' not in frontmost_block:
    raise SystemExit("TextEdit frontmost fallback must include disposable default-model-latency proof windows")

for name in ("textedit_document_name_exists", "describe_open_textedit_documents", "assert_textedit_frontmost_window", "try_wait_for_frontmost_app"):
    block = function_body(name)
    if "run_osascript_with_timeout" not in block:
        raise SystemExit(f"{name} must use bounded AppleScript")

wait_for_open = function_body("wait_for_textedit_document_open")
if 'textedit_document_name_exists "$window_title"' not in wait_for_open:
    raise SystemExit("TextEdit open wait must keep document-name fallback")
if "textedit_single_smoke_window_ready" not in wait_for_open:
    raise SystemExit("TextEdit open wait must require a real disposable AX window before focus")
if "nudge_textedit_frontmost" not in wait_for_open:
    raise SystemExit("TextEdit open wait must activate TextEdit when only the document name is visible")

run_textedit = function_body("run_textedit")
fallback = run_textedit.index("export AUTOCOMPLETE_LAB_TEXTEDIT_SINGLE_WINDOW_FALLBACK=1")
open_document = run_textedit.index('open_textedit_smoke_document "$textedit_file" "$textedit_window_title"')
if fallback > open_document:
    raise SystemExit("TextEdit smoke must enable single-window fallback before opening/focusing the proof document")
if "AUTOCOMPLETE_LAB_SKIP_SYSTEM_EVENTS_PROCESS_ACTIVATION=1" in run_textedit:
    raise SystemExit("TextEdit smoke must allow bounded System Events activation for focus recovery")

model_latency = function_body("run_textedit_model_latency")
if "AUTOCOMPLETE_LAB_SKIP_SYSTEM_EVENTS_PROCESS_ACTIVATION=1" in model_latency:
    raise SystemExit("TextEdit model-latency proof must allow bounded System Events activation for focus recovery")
model_build = model_latency.index("build_if_needed")
model_open = model_latency.index('open_textedit_smoke_document "$textedit_file" "$textedit_window_title"')
if model_build > model_open:
    raise SystemExit("TextEdit model-latency proof must relaunch SteadyType before opening the disposable TextEdit window")
default_model_latency = function_body("run_textedit_default_model_latency")
if "AUTOCOMPLETE_LAB_SKIP_SYSTEM_EVENTS_PROCESS_ACTIVATION=1" in default_model_latency:
    raise SystemExit("TextEdit default-model latency proof must keep bounded System Events focus recovery available")
if "wait_for_textedit_frontmost_window" not in function_body("focus_textedit_smoke_editor"):
    raise SystemExit("TextEdit focus must still verify the expected frontmost window after activation")
activate_process_id_block = source[
    source.index("activate_process_id()"):
    source.index("activate_process_id_osascript()", source.index("activate_process_id()"))
]
if "activateIgnoringOtherApps" not in activate_process_id_block:
    raise SystemExit("activate_process_id must force foreground activation for live proof focus recovery")
if 'wait_for_appkit_activation_frontmost "$target_pid"' not in activate_process_id_block:
    raise SystemExit("activate_process_id must skip System Events activation when AppKit already made the process frontmost")
if 'activate_process_id_osascript "$target_pid" &' not in activate_process_id_block:
    raise SystemExit("activate_process_id must keep bounded System Events activation available")
if "wait_for_appkit_activation_frontmost()" not in source or "frontmost_process_id" not in function_body("wait_for_appkit_activation_frontmost"):
    raise SystemExit("real app smoke must probe the frontmost process before falling back to System Events activation")
PY

if ! grep -F 'wait_for_textedit_document_prefix "$textedit_window_title" "$fragment" "TextEdit model latency sample $sample_index"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected TextEdit model latency typing to tolerate native TextEdit completions" >&2
  exit 1
fi
if ! grep -F 'clear_textedit_document_for_proof()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'clear_textedit_document_for_proof "$textedit_window_title" "TextEdit model latency initial reset"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'clear_textedit_document_for_proof "$textedit_window_title" "TextEdit model latency reset $sample_index"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'keystroke "a" using command down' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'key code 51' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected TextEdit model latency reset to recover through a disposable-window keyboard clear" >&2
  exit 1
fi
if ! grep -F 'trim_textedit_native_completion_suffix' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_TEXTEDIT_SUFFIX_DELETE_COUNT' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'trim_textedit_native_completion_suffix "$textedit_window_title" "$fragment" "TextEdit model latency sample $sample_index"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected TextEdit model latency to trim native completion suffixes before waiting for visible proof" >&2
  exit 1
fi
if ! grep -F 'trim_textedit_native_completion_suffix()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'trim_textedit_native_completion_suffix "$textedit_window_title" "$fragment" "TextEdit model latency sample $sample_index"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'key code 117' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'fell back to AX replacement' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'set_textedit_document_text "$window_title" "$expected_text"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected TextEdit model latency proof to remove native completion suffixes before timing" >&2
  exit 1
fi

if ! grep -F 'AUTOCOMPLETE_LAB_ARCHIVE_PATH:-dist/smoke-proof/SteadyType.zip' script/real_app_smoke.sh >/dev/null ||
   grep -F 'AUTOCOMPLETE_LAB_ARCHIVE_PATH:-dist/SteadyType.zip' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'Refusing to write smoke proof archive over release artifact' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected proof archives to stay separate from release dist/SteadyType.zip" >&2
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

python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
start = source.index("textedit_model_latency_fragments()")
body_start = source.index("cat <<'EOF'\n", start) + len("cat <<'EOF'\n")
body_end = source.index("\nEOF", body_start)
fragments = [line for line in source[body_start:body_end].splitlines() if line.strip()]
if len(fragments) < 8:
    raise SystemExit("model-latency proof must keep extra fragments so it can retry non-visible word-completion samples")
bad_triggers = {"confu", "relia", "immed", "trust", "verif"}
for fragment in fragments:
    trigger = fragment.rsplit(" ", 1)[-1]
    if trigger in bad_triggers:
        raise SystemExit(f"model-latency trigger {trigger!r} is prone to native TextEdit completion")
PY

if ! grep -F 'AUTOCOMPLETE_LAB_TEXTEDIT_MODEL_LATENCY_RUNTIME_READY_TIMEOUT_SECONDS' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'textedit_model_latency_runtime_ready_timeout_seconds' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected TextEdit model latency to have its own cold-warm runtime timeout" >&2
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
function_start = source.index('run_textedit_model_latency()')
function_end = source.index('run_textedit_default_model_latency()', function_start)
function_block = source[function_start:function_end]
start = function_block.index('wait_for_log_fields_optional "$sample_start" 20')
end = function_block.index('if wait_for_log_fields_optional "$sample_start" 20', start + 1)
block = function_block[start:end]
if '"mlx-completion-timing"' not in block or '"app=com.apple.TextEdit"' not in block:
    raise SystemExit("model-latency timing proof must still require TextEdit MLX timing")
if '"mode=wordCompletion"' in block:
    raise SystemExit("model-latency timing proof must not depend on a fragile request mode label")
start = function_block.index('if wait_for_log_fields_optional "$sample_start" 20', end)
end = function_block.index('if ((visible_sample_count >= 5', start)
block = function_block[start:end]
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
if ! grep -F 'current_steadytype_app_bundle_pids' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'steadytype_app_process_rows' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'command_matches_steadytype_binary "$command" "$app_binary"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'current_process_ancestor_pids' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'relatedToSelf(pid)' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'script/check_current_build_privacy_export.sh' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected exact app-stop cleanup to avoid killing the active proof shell" >&2
  exit 1
fi
if grep -F 'index(command, app_binary)' script/real_app_smoke.sh >/dev/null ||
   grep -F 'pgrep -f "/[S]teadyType.app/Contents/MacOS/SteadyType"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected exact app process matching, not substring process matching" >&2
  exit 1
fi
if ! AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_WAIT_SECONDS=0 AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST=$'123 1 424242 zsh -lc ./script/real_app_smoke.sh textedit-model-latency\n' script/real_app_smoke.sh codex >/dev/null 2>"$TMP_DIR/zsh-wrapper-fail.txt"; then
  if ! grep -F "Another real app smoke process is already active." "$TMP_DIR/zsh-wrapper-fail.txt" >/dev/null; then
    echo "real app smoke self-test expected zsh -lc smoke wrappers to be detected" >&2
    exit 1
  fi
else
  echo "real app smoke self-test expected zsh -lc smoke wrappers to block another smoke" >&2
  exit 1
fi
if AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_WAIT_SECONDS=0 AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST=$'123 1 424242 zsh -lc echo /Users/redbars/.codex/worktrees/25ed/transcripted-autocomplete-lab/dist/SteadyType.app/Contents/MacOS/SteadyType\n' script/real_app_smoke.sh codex >/dev/null 2>"$TMP_DIR/path-wrapper-fail.txt"; then
  :
else
  if grep -F "Another real app smoke process is already active." "$TMP_DIR/path-wrapper-fail.txt" >/dev/null; then
    echo "real app smoke self-test expected wrappers that only mention the app binary path not to be treated as smoke runs" >&2
    exit 1
  fi
fi
if ! grep -F 'textedit_smoke_allows_ax_proof_typing' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_TEXTEDIT_SMOKE_TEXT="$fragment" osascript' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_TEXTEDIT_SMOKE_KEY_DELAY_SECONDS' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_TEXTEDIT_MODEL_LATENCY_KEY_DELAY_SECONDS:-0' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'wait_for_background_process "$osascript_pid" "${AUTOCOMPLETE_LAB_TEXTEDIT_KEY_TYPING_TIMEOUT_SECONDS:-4}" "TextEdit proof key typing"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected TextEdit proof fragments to default to bounded System Events key typing with optional key pacing" >&2
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
   ! grep -F 'dismiss_textedit_modal_panels' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'run_osascript_with_timeout 2 "TextEdit modal cleanup"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'docName starts with "textedit-smoke-"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'docName starts with "textedit-model-latency-"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'docName starts with "textedit-default-model-latency-"' script/real_app_smoke.sh >/dev/null; then
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
if "Archive proof failed after 3 attempts." not in source:
    raise SystemExit("archive proof must retry transient ditto failures before failing the smoke")
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

if ! grep -F "swift script/obsidian_ax_editor.swift reset" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER_TEXT" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "focusAtEnd(editor, text: resetText)" script/obsidian_ax_editor.swift >/dev/null ||
   ! grep -F "focusTextForDocumentEnd(currentText:" script/obsidian_ax_editor.swift >/dev/null; then
  echo "real app smoke self-test expected Obsidian reset to move the AX selected range to the end of the disposable note through the helper" >&2
  exit 1
fi
if ! grep -F "wait_for_obsidian_long_note_second_suggestion" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "beforeChars=\${expected_before_chars}±2" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Obsidian long-note proof to allow a tiny CodeMirror file/AX count skew while requiring afterChars=0" >&2
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
append = source.index('append_obsidian_smoke_note_file_text " and stays inst"')
watch = source.index('second_start_line="$(line_count "$LOG_PATH")"', append)
focus = source.index('move_obsidian_caret_to_document_end', append)
assertion = source.index('assert_obsidian_smoke_target "Smoke proof feels instant and stays inst"', append)
branch_end = source.index('\n  else', append)
if not (append < watch < focus < assertion < branch_end):
    raise SystemExit("Obsidian long-note proof must start watching before focus/assert can trigger the second suggestion")
PY

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

if AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_WAIT_SECONDS=0 AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST=$'123 1 999 bash ./script/smoke_test.sh\n' script/real_app_smoke.sh codex >/dev/null 2>"$TMP_DIR/full-smoke-process-fail.txt"; then
  echo "real app smoke self-test expected full smoke test process scan to fail" >&2
  exit 1
fi
if ! grep -F "Another real app smoke process is already active" "$TMP_DIR/full-smoke-process-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the full smoke test process scan" >&2
  exit 1
fi

if AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_WAIT_SECONDS=0 AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST=$'123 1 999 bash ./script/build_and_run.sh --verify\n' script/real_app_smoke.sh codex >/dev/null 2>"$TMP_DIR/build-run-process-fail.txt"; then
  echo "real app smoke self-test expected build/run process scan to fail" >&2
  exit 1
fi
if ! grep -F "Another real app smoke process is already active" "$TMP_DIR/build-run-process-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the build/run process scan" >&2
  exit 1
fi

SELF_TEST_PGID="$(ps -o pgid= -p "$$" 2>/dev/null || true)"
SELF_TEST_PGID="${SELF_TEST_PGID//[[:space:]]/}"
if [[ -n "$SELF_TEST_PGID" ]]; then
  if AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_WAIT_SECONDS=0 AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST="123 1 $SELF_TEST_PGID bash ./script/build_and_run.sh --verify"$'\n' script/real_app_smoke.sh codex >/dev/null 2>"$TMP_DIR/same-pgid-build-run-process-fail.txt"; then
    echo "real app smoke self-test expected same-PGID sibling build/run process scan to fail" >&2
    exit 1
  fi
  if ! grep -F "Another real app smoke process is already active" "$TMP_DIR/same-pgid-build-run-process-fail.txt" >/dev/null; then
    echo "real app smoke self-test did not explain the same-PGID sibling process scan" >&2
    exit 1
  fi
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
