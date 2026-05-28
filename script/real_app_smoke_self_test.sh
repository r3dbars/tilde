#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

script/real_app_smoke.sh textedit --help >"$TMP_DIR/help.txt"
if ! grep -F "fails closed unless" "$TMP_DIR/help.txt" >/dev/null ||
   ! grep -F "this checkout's dist/SteadyType.app binary" "$TMP_DIR/help.txt" >/dev/null ||
   ! grep -F "AUTOCOMPLETE_LAB_ALLOW_MODEL_LATENCY_SKIP_BUILD=1" "$TMP_DIR/help.txt" >/dev/null; then
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

script/real_app_smoke.sh chrome-textarea-model-latency --dry-run >"$TMP_DIR/chrome-textarea-model-latency.txt"
if ! grep -F "Real app smoke: chrome" "$TMP_DIR/chrome-textarea-model-latency.txt" >/dev/null ||
   ! grep -F "Chrome fixture: textarea" "$TMP_DIR/chrome-textarea-model-latency.txt" >/dev/null ||
   ! grep -F "Chrome model latency proof disables fast word completions and phrase continuations" "$TMP_DIR/chrome-textarea-model-latency.txt" >/dev/null ||
   ! grep -F "scenario chrome-textarea-model-latency" "$TMP_DIR/chrome-textarea-model-latency.txt" >/dev/null ||
   ! grep -F 'Chrome $CHROME_FIXTURE model latency proof scenario: $scenario' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test did not print the Chrome textarea model latency dry-run plan" >&2
  exit 1
fi

if script/real_app_smoke.sh chrome-textarea-model-latency --skip-build --dry-run >"$TMP_DIR/chrome-textarea-model-latency-skip-build.txt" 2>&1; then
  echo "real app smoke self-test expected Chrome textarea model latency --skip-build to fail closed" >&2
  exit 1
fi
if ! grep -F "must relaunch with fast word completions and phrase continuations disabled" "$TMP_DIR/chrome-textarea-model-latency-skip-build.txt" >/dev/null; then
  echo "real app smoke self-test expected Chrome textarea model latency --skip-build failure to explain the proof env requirement" >&2
  exit 1
fi

script/real_app_smoke.sh chrome-contenteditable-model-latency --dry-run >"$TMP_DIR/chrome-contenteditable-model-latency.txt"
if ! grep -F "Real app smoke: chrome" "$TMP_DIR/chrome-contenteditable-model-latency.txt" >/dev/null ||
   ! grep -F "Chrome fixture: contenteditable" "$TMP_DIR/chrome-contenteditable-model-latency.txt" >/dev/null ||
   ! grep -F "Chrome model latency proof disables fast word completions and phrase continuations" "$TMP_DIR/chrome-contenteditable-model-latency.txt" >/dev/null ||
   ! grep -F "scenario chrome-contenteditable-model-latency" "$TMP_DIR/chrome-contenteditable-model-latency.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome contenteditable model latency dry-run plan" >&2
  exit 1
fi

if script/real_app_smoke.sh chrome-contenteditable-model-latency --skip-build --dry-run >"$TMP_DIR/chrome-contenteditable-model-latency-skip-build.txt" 2>&1; then
  echo "real app smoke self-test expected Chrome contenteditable model latency --skip-build to fail closed" >&2
  exit 1
fi
if ! grep -F "must relaunch with fast word completions and phrase continuations disabled" "$TMP_DIR/chrome-contenteditable-model-latency-skip-build.txt" >/dev/null; then
  echo "real app smoke self-test expected Chrome contenteditable model latency --skip-build failure to explain the proof env requirement" >&2
  exit 1
fi

script/real_app_smoke.sh codex-model-latency --dry-run >"$TMP_DIR/codex-model-latency.txt"
if ! grep -F "Real app smoke: codex" "$TMP_DIR/codex-model-latency.txt" >/dev/null ||
   ! grep -F "Codex prompt model latency proof" "$TMP_DIR/codex-model-latency.txt" >/dev/null ||
   ! grep -F "model-backed visible word completions in one launch" "$TMP_DIR/codex-model-latency.txt" >/dev/null ||
   ! grep -F "disables fast word completions and phrase continuations" "$TMP_DIR/codex-model-latency.txt" >/dev/null ||
   ! grep -F "scenario codex-model-latency" "$TMP_DIR/codex-model-latency.txt" >/dev/null ||
   ! grep -F "never presses Enter or full accept" "$TMP_DIR/codex-model-latency.txt" >/dev/null ||
   ! grep -F "prompt no-submit gate on the same trace slice" "$TMP_DIR/codex-model-latency.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Codex model latency dry-run plan" >&2
  exit 1
fi

if script/real_app_smoke.sh codex-model-latency --skip-build --dry-run >"$TMP_DIR/codex-model-latency-skip-build.txt" 2>&1; then
  echo "real app smoke self-test expected Codex model latency --skip-build to fail closed" >&2
  exit 1
fi
if ! grep -F "must relaunch with fast word completions and phrase continuations disabled" "$TMP_DIR/codex-model-latency-skip-build.txt" >/dev/null; then
  echo "real app smoke self-test expected Codex model latency --skip-build failure to explain the proof env requirement" >&2
  exit 1
fi

script/real_app_smoke.sh claude-model-latency --dry-run >"$TMP_DIR/claude-model-latency.txt"
if ! grep -F "Real app smoke: claude" "$TMP_DIR/claude-model-latency.txt" >/dev/null ||
   ! grep -F "Claude desktop prompt model latency proof" "$TMP_DIR/claude-model-latency.txt" >/dev/null ||
   ! grep -F "model-backed visible word completions in one launch" "$TMP_DIR/claude-model-latency.txt" >/dev/null ||
   ! grep -F "disables fast word completions and phrase continuations" "$TMP_DIR/claude-model-latency.txt" >/dev/null ||
   ! grep -F "scenario claude-model-latency" "$TMP_DIR/claude-model-latency.txt" >/dev/null ||
   ! grep -F "never presses Enter or full accept" "$TMP_DIR/claude-model-latency.txt" >/dev/null ||
   ! grep -F "prompt no-submit gate on the same trace slice" "$TMP_DIR/claude-model-latency.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Claude model latency dry-run plan" >&2
  exit 1
fi

if script/real_app_smoke.sh claude-model-latency --skip-build --dry-run >"$TMP_DIR/claude-model-latency-skip-build.txt" 2>&1; then
  echo "real app smoke self-test expected Claude model latency --skip-build to fail closed" >&2
  exit 1
fi
if ! grep -F "must relaunch with fast word completions and phrase continuations disabled" "$TMP_DIR/claude-model-latency-skip-build.txt" >/dev/null; then
  echo "real app smoke self-test expected Claude model latency --skip-build failure to explain the proof env requirement" >&2
  exit 1
fi

AUTOCOMPLETE_LAB_ALLOW_MODEL_LATENCY_SKIP_BUILD=1 \
  script/real_app_smoke.sh claude-model-latency --skip-build --dry-run >"$TMP_DIR/claude-model-latency-skip-build-allowed.txt" 2>&1
if ! grep -F "Packaged model latency proof: reusing the already-running app because AUTOCOMPLETE_LAB_ALLOW_MODEL_LATENCY_SKIP_BUILD=1 is set." "$TMP_DIR/claude-model-latency-skip-build-allowed.txt" >/dev/null ||
   ! grep -F "Safety: strict latency selector must still prove the tagged runtime launch for this app binary." "$TMP_DIR/claude-model-latency-skip-build-allowed.txt" >/dev/null; then
  echo "real app smoke self-test expected guarded packaged Claude model latency --skip-build proof to be allowed with an explicit env opt-in" >&2
  exit 1
fi

if ! grep -F 'AUTOCOMPLETE_LAB_TEXTEDIT_SMOKE_AX_INSERTION=0' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'insert_textedit_smoke_fragment()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'TextEdit model latency stable context' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION=1' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION=1' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_PROOF_SUPPRESS_ANNOYANCE_LEARNING=1' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'export AUTOCOMPLETE_LAB_TEXTEDIT_SINGLE_WINDOW_FALLBACK=1' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_PROOF_SCENARIO="textedit-model-latency"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_PROOF_SCENARIO="$scenario"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'prepare_codex_model_latency_runtime_options' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'prepare_claude_model_latency_runtime_options' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_PROMPT_PROOF_SURFACE="codex-model-latency"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_PROMPT_PROOF_SURFACE="claude-model-latency"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'TextEdit model latency seed settled' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'press_textedit_event_tap_probe_key' script/real_app_smoke.sh >/dev/null ||
   ! grep -F -- '--require-event-tap-samples "$event_tap_sample_count"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected model latency proof to seed context before sampling with non-word modes disabled" >&2
  exit 1
fi

if ! grep -F 'run_textedit_default_model_latency()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_PROOF_DISABLE_WORD_COMPLETION=1' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_PHRASE_FALLBACK=1' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'TextEdit default model latency stable context' script/real_app_smoke.sh >/dev/null ||
   ! grep -F '"mode=phraseContinuation"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F '"maxTokens=14"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'visible_sample_count' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'reason=empty-suggestion' script/real_app_smoke.sh >/dev/null ||
   ! grep -F './script/model_latency_report.py --default-model-proof' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected default model latency proof to force and count visible phrase model samples" >&2
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
if "focus_claude_code_ghostty_proof_window_by_title()" not in source:
    raise SystemExit("Ghostty proof harness must have a title-marked focus helper")
if source.count("focus_claude_code_ghostty_proof_window_by_title") < 3:
    raise SystemExit("Ghostty proof harness must use title-marked focus before activation and fallback Tab")
if "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_TITLE" not in source:
    raise SystemExit("Ghostty proof focus must scope activation to the title-marked disposable window")
if "system_events_frontmost_process_id_matches()" not in source or "System Events frontmost pid probe" not in source:
    raise SystemExit("Ghostty proof harness must be able to verify exact frontmost ownership through System Events")
if "Claude Code $host_name fallback could not focus the title-marked proof window" not in source:
    raise SystemExit("Ghostty fallback Tab must fail clearly when the title-marked proof window cannot be focused")
if "claude_code_ghostty_frontmost_proof_process_id_by_title()" not in source or "AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_TITLE_FRONTMOST_SECONDS" not in source:
    raise SystemExit("Ghostty proof launch must resolve the frontmost root app pid after focusing the title-marked window")
if "focus_claude_code_ghostty_host_app_after_title_proof()" not in source or "CLAUDE_CODE_GHOSTTY_TITLE_FOCUS_CONFIRMED=0" not in source:
    raise SystemExit("Ghostty proof launch must remember title-focus proof before using host-app refocus fallback")
if "claude_code_terminal_proof_title_for_dir()" not in source or 'CLAUDE_CODE_TERMINAL_PROOF_TITLE="$(claude_code_terminal_proof_title_for_dir "$proof_dir")"' not in source:
    raise SystemExit("Claude Code terminal proof titles must include the unique temp proof id")
if 'CLAUDE_CODE_TERMINAL_PROOF_TITLE="Claude Code $marker"' in source:
    raise SystemExit("Claude Code terminal proof titles must not reuse the same marker-only title")
launch_focus_start = source.index("mark_claude_code_ghostty_proof_window_title")
launch_focus_end = source.index('CLAUDE_CODE_TERMINAL_PROOF_PIDS="$ghostty_pid"', launch_focus_start)
launch_focus_block = source[launch_focus_start:launch_focus_end]
if "claude_code_ghostty_frontmost_proof_process_id_by_title" not in launch_focus_block:
    raise SystemExit("Ghostty proof launch must prefer title-focused root app pid discovery over generic frontmost pid discovery")
if "if windowName contains proofTitle then" not in launch_focus_block:
    raise SystemExit("Ghostty proof title-focused pid resolution must require the unique proof title")
if "if windowName contains proofMarker or windowName contains compactProofMarker then" in launch_focus_block:
    raise SystemExit("Ghostty proof title-focused pid resolution must not fall back to stale marker-only windows")
if "focus_claude_code_ghostty_proof_window_by_title || true" not in launch_focus_block:
    raise SystemExit("Ghostty proof launch must still explicitly refocus the title-marked proof window before generic fallback")
if "frontmost_process_id" not in launch_focus_block or "frontmost_bundle_identifier" not in launch_focus_block:
    raise SystemExit("Ghostty proof launch must use the frontmost Ghostty root app pid after title focus")
if "CLAUDE_CODE_GHOSTTY_TITLE_FOCUS_CONFIRMED=1" not in launch_focus_block:
    raise SystemExit("Ghostty proof launch must record successful title-focus before later host-app refocus")
if "did not keep the focused title-marked app process frontmost" in source:
    raise SystemExit("Ghostty proof launch must not immediately redo the volatile title-frontmost check after title-focused pid discovery")
if source.count("set proofTitle to item 3 of argv") < 2 or source.count('perform action ("set_surface_title:" & proofTitle) on targetTerminal') < 3:
    raise SystemExit("Ghostty proof launch must title-mark the new disposable window before running claude")
wait_focus_start = source.index("try_wait_for_frontmost_claude_code_terminal_proof_process()")
wait_focus_end = source.index("\nwait_for_frontmost_claude_code_terminal_proof_process()", wait_focus_start)
wait_focus_block = source[wait_focus_start:wait_focus_end]
if 'focus_claude_code_ghostty_proof_window_by_title "$root_pid"' not in wait_focus_block:
    raise SystemExit("Ghostty proof frontmost wait must actively refocus the exact title-marked window")
if 'if focus_claude_code_ghostty_proof_window_by_title "$root_pid" >/dev/null 2>&1; then' not in wait_focus_block or "return 0" not in wait_focus_block:
    raise SystemExit("Ghostty proof frontmost wait must trust the atomic title-window focus proof before laggy frontmost polling")
if 'focus_claude_code_ghostty_host_app_after_title_proof "$root_pid"' not in wait_focus_block:
    raise SystemExit("Ghostty proof frontmost wait must allow host-app refocus after a proven title focus")
focus_start = source.index("focus_claude_code_ghostty_proof_window_by_title()")
focus_end = source.index("frontmost_claude_code_terminal_proof_process_is_active()", focus_start)
focus_block = source[focus_start:focus_end]
if "if windowName contains proofTitle then" not in focus_block:
    raise SystemExit("Ghostty proof focus must require the exact unique proof title")
if "if windowName contains proofTitle or windowName contains proofMarker" in focus_block:
    raise SystemExit("Ghostty proof focus must not fall back to stale marker-only windows")
if "set windowName to name of front window of frontApp" in focus_block:
    raise SystemExit("Ghostty proof focus must not reject title-scoped activation on lagging System Events front-window metadata")
if "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_TARGET_PID" not in focus_block:
    raise SystemExit("Ghostty proof focus must carry the disposable host pid into the title-scoped focus helper")
if "set frontmost of procRef to true" not in focus_block or 'return "exact"' not in focus_block:
    raise SystemExit("Ghostty proof focus must reassert exact-pid frontmost ownership through System Events")
if 'focus_claude_code_ghostty_proof_window_by_title "$target_pid"' not in source:
    raise SystemExit("Ghostty proof activation must pass the exact disposable pid into title-scoped focus")
host_focus_start = source.index("focus_claude_code_ghostty_host_app_after_title_proof()")
host_focus_end = source.index("frontmost_claude_code_terminal_proof_process_is_active()", host_focus_start)
host_focus_block = source[host_focus_start:host_focus_end]
if "CLAUDE_CODE_GHOSTTY_TITLE_FOCUS_CONFIRMED" not in host_focus_block:
    raise SystemExit("Ghostty host-app refocus fallback must only run after title-focus proof")
if "host_focus_result" not in host_focus_block or '[[ "$host_focus_result" == "true" ]]' not in host_focus_block:
    raise SystemExit("Ghostty host-app refocus fallback must inspect the AppleScript frontmost result")
if 'tell application id "com.mitchellh.ghostty"' not in host_focus_block or "activate" not in host_focus_block:
    raise SystemExit("Ghostty host-app refocus fallback must reactivate Ghostty directly")
if 'bundle identifier of frontApp is "com.mitchellh.ghostty"' not in host_focus_block:
    raise SystemExit("Ghostty host-app refocus fallback must verify Ghostty became frontmost")
frontmost_match_start = source.index("frontmost_claude_code_terminal_proof_pid_matches()")
frontmost_match_end = source.index("frontmost_claude_code_terminal_proof_root_pid_matches()", frontmost_match_start)
frontmost_match_block = source[frontmost_match_start:frontmost_match_end]
if "system_events_frontmost_process_id_matches" not in frontmost_match_block:
    raise SystemExit("Ghostty proof frontmost matching must accept exact System Events pid proof when NSWorkspace reports a root pid")
host_active_start = source.index("frontmost_claude_code_terminal_host_app_is_active()")
host_active_end = source.index("guard_ghostty_frontmost_bundle_fallback()", host_active_start)
host_active_block = source[host_active_start:host_active_end]
if 'try_wait_for_frontmost_app "$host_app" 1' not in host_active_block:
    raise SystemExit("Ghostty proof frontmost matching must accept System Events host-app frontmost proof when NSWorkspace lags")
if "cleanup_stale_claude_code_ghostty_proofs()" not in source:
    raise SystemExit("Ghostty proof cleanup must have a Ghostty-native stale window cleanup path")
ghostty_cleanup_start = source.index("cleanup_stale_claude_code_ghostty_proofs()")
ghostty_cleanup_end = source.index("cleanup_stale_claude_code_terminal_proofs()", ghostty_cleanup_start)
ghostty_cleanup_block = source[ghostty_cleanup_start:ghostty_cleanup_end]
if 'tell application id "com.mitchellh.ghostty"' not in ghostty_cleanup_block:
    raise SystemExit("Ghostty stale cleanup must use Ghostty's own window API")
if "application processes" in ghostty_cleanup_block:
    raise SystemExit("Ghostty stale cleanup must not enumerate System Events application windows")
if "reset_zero_window_claude_code_ghostty_proof_host()" not in source:
    raise SystemExit("Ghostty proof cleanup must reset poisoned zero-window Ghostty hosts")
zero_window_reset_start = source.index("reset_zero_window_claude_code_ghostty_proof_host()")
zero_window_reset_end = source.index("close_claude_code_ghostty_proof_window_by_title()", zero_window_reset_start)
zero_window_reset_block = source[zero_window_reset_start:zero_window_reset_end]
if 'return (count windows) as text' not in zero_window_reset_block:
    raise SystemExit("Ghostty zero-window reset must prove no user windows through Ghostty's own API")
if '[[ "$window_count" == "0" ]]' not in zero_window_reset_block:
    raise SystemExit("Ghostty zero-window reset must only kill the host when window count is exactly zero")
if 'kill -KILL "$proof_pid"' not in zero_window_reset_block:
    raise SystemExit("Ghostty zero-window reset must hard-reset a stuck zero-window process")
open_proof_start = source.index("open_claude_code_terminal_proof()")
open_proof_end = source.index("cleanup_claude_code_terminal_proof()", open_proof_start)
open_proof_block = source[open_proof_start:open_proof_end]
if "reset_zero_window_claude_code_ghostty_proof_host" not in open_proof_block:
    raise SystemExit("Ghostty proof launch must reset zero-window hosts before creating a new proof window")
if "reset_zero_window_claude_code_ghostty_proof_host" not in ghostty_cleanup_block:
    raise SystemExit("Ghostty stale cleanup must reset zero-window hosts after closing stale proof windows")
generic_cleanup_start = source.index("cleanup_stale_claude_code_terminal_proofs()")
generic_cleanup_end = source.index("open_fresh_claude_code_terminal_proof_context()", generic_cleanup_start)
generic_cleanup_block = source[generic_cleanup_start:generic_cleanup_end]
if 'if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]' not in generic_cleanup_block or "cleanup_stale_claude_code_ghostty_proofs" not in generic_cleanup_block:
    raise SystemExit("Ghostty stale cleanup must bypass generic System Events terminal process cleanup")
fresh_context_start = source.index("open_fresh_claude_code_terminal_proof_context()")
fresh_context_end = source.index("wait_for_claude_code_terminal_prompt()", fresh_context_start)
fresh_context_block = source[fresh_context_start:fresh_context_end]
if 'settle_claude_code_terminal_proof_focus "fresh proof context"' not in fresh_context_block:
    raise SystemExit("Ghostty fresh-context setup must repair exact proof focus before failing")
if "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CONTEXT_LAUNCH_ATTEMPTS" not in fresh_context_block or "try_wait_for_claude_code_terminal_prompt" not in fresh_context_block:
    raise SystemExit("Ghostty fresh-context setup must retry transient disposable launch failures")
if 'assert_frontmost_app "$host_name" "Claude Code $host_name proof"' in fresh_context_block:
    raise SystemExit("Ghostty fresh-context setup must not use a plain host-app assertion after exact proof focus repair")
if "try_wait_for_claude_code_terminal_process_name()" not in source or "wait_for_claude_code_terminal_process_name() {\n  try_wait_for_claude_code_terminal_process_name" not in source:
    raise SystemExit("Claude Code terminal process discovery must offer a retryable helper plus the fatal wrapper")
if "try_wait_for_claude_code_terminal_prompt()" not in source or "wait_for_claude_code_terminal_prompt() {\n  try_wait_for_claude_code_terminal_prompt || exit 1" not in source:
    raise SystemExit("Claude Code terminal prompt readiness must offer a retryable helper plus the fatal wrapper")
start = source.index('run_textedit_model_latency()')
end = source.index('run_textedit_default_model_latency()', start)
block = source[start:end]
if "wait_for_log_fields_optional \"$seed_start\"" not in block:
    raise SystemExit("model-latency proof must wait briefly for seed timing before the measured sample")
if "describe_textedit_model_latency_seed_miss" not in block:
    raise SystemExit("model-latency proof must diagnose missing seed logs before the measured sample")
if 'trigger_prefix="${trigger_text%?}"' in block or 'trigger_final="${trigger_text: -1}"' in block:
    raise SystemExit("model-latency proof must not seed a partial trigger that can create a seed suggestion")
if 'stable_context="${stable_context}${trigger_prefix}"' in block:
    raise SystemExit("model-latency proof must seed only stable context before live-typing the trigger word")
if 'AUTOCOMPLETE_LAB_TEXTEDIT_MODEL_LATENCY_SEED_SETTLE_SECONDS' not in block:
    raise SystemExit("model-latency proof must allow the stable context seed to settle before the measured trigger word")
if 'AUTOCOMPLETE_LAB_TEXTEDIT_MODEL_LATENCY_ATTEMPTS_PER_FRAGMENT' not in block:
    raise SystemExit("model-latency proof must expose a bounded retry count per stable context")
if 'for ((attempt = 1; attempt <= max_attempts; attempt++))' not in block:
    raise SystemExit("model-latency proof must retry a stable context before moving to the next fragment")
if 'wait_for_log_fields "$seed_start" "TextEdit model latency disabled phrase seed' in block:
    raise SystemExit("model-latency proof must not hard-fail before typing the measured trigger")
if 'dismiss_textedit_seed_suggestion_if_possible' in block:
    raise SystemExit("model-latency proof must not dismiss seed suggestions with Escape because that suppresses the field")
if 'proof_runtime_guard_line="$(latest_runtime_bootstrap_line_number)"' not in block:
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
sample_start = block.index('sample_start="$(line_count "$LOG_PATH")')
if sample_start > trigger:
    raise SystemExit("model-latency proof must start sample timing before live-typing the trigger word")
timing = block.index('wait_for_log_fields_optional "$sample_start" 20', trigger)
if 'move_textedit_caret_to_document_end "$textedit_window_title"' in block[trigger:timing]:
    raise SystemExit("model-latency proof must not move the caret while the measured model request is in flight")
if "visible_sample_count" not in block or "model_sample_count" not in block:
    raise SystemExit("model-latency proof must count actual visible and timed model-backed samples")
if "event_tap_sample_count" not in block:
    raise SystemExit("model-latency proof must count raw event-tap latency samples")
if "event_tap_started=0" not in block:
    raise SystemExit("model-latency proof must treat event-tap startup as a one-time launch condition")
visible_increment = block.index('visible_sample_count=$((visible_sample_count + 1))')
model_increment = block.rfind('model_sample_count=$((model_sample_count + 1))', 0, visible_increment)
visible_wait = block.rfind('candidateSelectionSource=app-model-result', 0, visible_increment)
if model_increment < visible_wait:
    raise SystemExit("model-latency proof must count model samples only on an attempt with visible model-backed proof")
if 'wait_for_log_fields "$sample_start" "TextEdit model latency event tap started' in block:
    raise SystemExit("model-latency proof must not expect a fresh event-tap-started marker for every visible sample")
if 'wait_for_log_fields "$runtime_start_line" "TextEdit model latency event tap startup"' not in block:
    raise SystemExit("model-latency proof must require event-tap startup once for the runtime launch")
event_tap_wait = block.rfind('keyboard-event-tap-latency', 0, visible_increment)
if event_tap_wait < visible_wait:
    raise SystemExit("model-latency proof must require event-tap latency after visible model-backed proof")
if 'press_textedit_event_tap_probe_key' not in block:
    raise SystemExit("model-latency proof must press a disposable acceptance key after the tap starts")
if '"key=tab"' not in block or '"decision=consume"' not in block:
    raise SystemExit("model-latency proof must require the tab acceptance event-tap diagnostic category")
if '--require-event-tap-samples "$event_tap_sample_count"' not in block:
    raise SystemExit("model-latency proof must require raw event-tap samples in its beta gate")
if "visible_sample_count >= 5" not in block:
    raise SystemExit("model-latency proof must stop only after five visible model-backed word completions")

keyboard_tap = Path("Sources/AutocompleteLabApp/Mac/KeyboardEventTap.swift").read_text()
if 'if key != .other' in keyboard_tap:
    raise SystemExit("keyboard event tap latency must include normal typed-key categories")
if '"keyboard-event-tap-latency"' not in keyboard_tap or '"key": key.diagnosticName' not in keyboard_tap:
    raise SystemExit("keyboard event tap latency must log key category and duration")

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

codex_start = source.index('run_codex_model_latency()')
codex_end = source.index('run_claude_model_latency()', codex_start)
codex_block = source[codex_start:codex_end]
codex_prepare_start = source.index('prepare_codex_model_latency_runtime_options()')
codex_prepare_end = source.index('prepare_claude_model_latency_runtime_options()', codex_prepare_start)
codex_prepare_block = source[codex_prepare_start:codex_prepare_end]
if 'prepare_codex_model_latency_runtime_options' not in codex_block:
    raise SystemExit("Codex model latency proof must prepare proof-only runtime flags")
if 'AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION=1' not in codex_prepare_block:
    raise SystemExit("Codex model latency proof must disable fast word completions")
if 'AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION=1' not in codex_prepare_block:
    raise SystemExit("Codex model latency proof must disable phrase continuations")
if 'AUTOCOMPLETE_LAB_PROOF_SCENARIO="$scenario"' not in codex_prepare_block or 'local scenario="codex-model-latency"' not in codex_prepare_block:
    raise SystemExit("Codex model latency proof must tag its runtime scenario")
if 'press_key_code' in codex_block or 'press_accept_all_shortcut' in codex_block or 'key code 36' in codex_block:
    raise SystemExit("Codex model latency proof must not press Tab, Enter, or full accept")
if 'type_codex_raw_smoke_text "$trigger_text"' not in codex_block:
    raise SystemExit("Codex model latency proof must type only the trigger character through live key events")
if 'AUTOCOMPLETE_LAB_CODEX_MODEL_LATENCY_SEED_SETTLE_SECONDS' not in codex_block:
    raise SystemExit("Codex model latency proof must let the stable AX seed settle before live key-trigger typing")
if 'AUTOCOMPLETE_LAB_PROMPT_PROOF_SURFACE="codex-model-latency"' not in codex_block:
    raise SystemExit("Codex model latency proof must run prompt no-submit proof on the same trace slice")
if 'visible_sample_count >= 5' not in codex_block:
    raise SystemExit("Codex model latency proof must stop only after five visible model-backed samples")
if '"requestMode=wordCompletion"' not in codex_block or '"candidateSelectionSource=app-model-result"' not in codex_block:
    raise SystemExit("Codex model latency proof must require model-backed word-completion visibility")
if 'reason=empty-suggestion' not in codex_block:
    raise SystemExit("Codex model latency proof must skip empty model candidates and try another disposable context")
if 'assert_codex_prompt_retains_marker' not in codex_block:
    raise SystemExit("Codex model latency proof must verify the prompt marker still exists after each sample")

claude_start = source.index('run_claude_model_latency()')
claude_end = source.index('run_manual_gated()', claude_start)
claude_block = source[claude_start:claude_end]
claude_prepare_start = source.index('prepare_claude_model_latency_runtime_options()')
claude_prepare_end = source.index('prepare_default_model_latency_runtime_options()', claude_prepare_start)
claude_prepare_block = source[claude_prepare_start:claude_prepare_end]
if 'prepare_claude_model_latency_runtime_options' not in claude_block:
    raise SystemExit("Claude model latency proof must prepare proof-only runtime flags")
if 'AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION=1' not in claude_prepare_block:
    raise SystemExit("Claude model latency proof must disable fast word completions")
if 'AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION=1' not in claude_prepare_block:
    raise SystemExit("Claude model latency proof must disable phrase continuations")
if 'AUTOCOMPLETE_LAB_PROOF_SCENARIO="$scenario"' not in claude_prepare_block or 'local scenario="claude-model-latency"' not in claude_prepare_block:
    raise SystemExit("Claude model latency proof must tag its runtime scenario")
if 'press_key_code' in claude_block or 'press_accept_all_shortcut' in claude_block or 'key code 36' in claude_block:
    raise SystemExit("Claude model latency proof must not press Tab, Enter, or full accept")
if 'type_claude_raw_smoke_text "$trigger_text"' not in claude_block:
    raise SystemExit("Claude model latency proof must type only the trigger character through live key events")
if 'AUTOCOMPLETE_LAB_CLAUDE_MODEL_LATENCY_SEED_SETTLE_SECONDS' not in claude_block:
    raise SystemExit("Claude model latency proof must let the stable AX seed settle before live key-trigger typing")
if 'open -a Claude' not in claude_block or 'wait_for_frontmost_app "Claude"' not in claude_block:
    raise SystemExit("Claude model latency proof must launch and focus Claude before AX seeding")
if 'AUTOCOMPLETE_LAB_CLAUDE_COMPOSER_DISCOVERY_TIMEOUT_SECONDS' not in source:
    raise SystemExit("Claude model latency proof must give the launched composer a bounded discovery window")
if 'AUTOCOMPLETE_LAB_PROMPT_PROOF_SURFACE="claude-model-latency"' not in claude_block:
    raise SystemExit("Claude model latency proof must run prompt no-submit proof on the same trace slice")
if 'visible_sample_count >= 5' not in claude_block:
    raise SystemExit("Claude model latency proof must stop only after five visible model-backed samples")
if '"requestMode=wordCompletion"' not in claude_block or '"candidateSelectionSource=app-model-result"' not in claude_block:
    raise SystemExit("Claude model latency proof must require model-backed word-completion visibility")
if 'reason=empty-suggestion' not in claude_block:
    raise SystemExit("Claude model latency proof must skip empty model candidates and try another disposable context")
if 'assert_claude_prompt_retains_marker' not in claude_block:
    raise SystemExit("Claude model latency proof must verify the prompt marker still exists after each sample")
if 'restore_claude_draft_if_needed' not in source or 'prompt_app_ax_proof_helper.swift' not in source:
    raise SystemExit("Claude model latency proof must restore focused drafts through the AX helper")
prompt_helper = Path("script/prompt_app_ax_proof_helper.swift").read_text()
if "seedWithSelectedTextFallback" not in prompt_helper or "seedWithPasteFallback" not in prompt_helper:
    raise SystemExit("Prompt app AX helper must fall back when direct AX value seeding does not stick")
if "waitForStableTreeExactValue" not in prompt_helper or "exactValueInput" not in prompt_helper:
    raise SystemExit("Prompt app AX helper must verify seeded text stays in the live app tree")
if "prefersEventBackedSeeding" not in prompt_helper or 'options.bundleIdentifier == "com.openai.codex"' not in prompt_helper:
    raise SystemExit("Codex prompt helper must use event-backed seeding so React state keeps the proof text")
if "clonePasteboardItems" not in prompt_helper or "$0.copy() as? NSPasteboardItem" in prompt_helper:
    raise SystemExit("Prompt app AX helper must clone pasteboard data without crashing on NSPasteboardItem.copy()")
if 'let acceptedLabels = ["new chat"]' not in prompt_helper:
    raise SystemExit("Claude prompt helper must not press task/start buttons that can submit proof text")

terminal_prompt_helper = Path("script/terminal_prompt_ax_proof_helper.swift").read_text()
if '"--pid"' not in terminal_prompt_helper or "processIdentifier" not in terminal_prompt_helper:
    raise SystemExit("Terminal prompt AX helper must accept the disposable terminal process pid")
if "activateIfNeeded" not in terminal_prompt_helper or ".activateAllWindows" not in terminal_prompt_helper:
    raise SystemExit("Terminal prompt AX helper must reactivate the exact disposable terminal process while waiting")
if "activateWithSystemEvents" not in terminal_prompt_helper or '"/usr/bin/osascript"' not in terminal_prompt_helper or "set frontmost of procRef to true" not in terminal_prompt_helper:
    raise SystemExit("Terminal prompt AX helper must fall back to System Events pid activation when AppKit activation loses focus")
if "frontmostPid=" not in terminal_prompt_helper or "targetPid=" not in terminal_prompt_helper:
    raise SystemExit("Terminal prompt AX helper failures must include focus ownership pids")
if "func focusedWindow(in appElement" not in terminal_prompt_helper or "kAXFocusedWindowAttribute" not in terminal_prompt_helper:
    raise SystemExit("Terminal prompt AX helper must include focused-window text when Ghostty omits AXWindows")
if "if texts.isEmpty" not in terminal_prompt_helper or "collectText(from: appElement" not in terminal_prompt_helper:
    raise SystemExit("Terminal prompt AX helper must fall back to the exact target app AX subtree when Ghostty reports no window text nodes")
if "--allow-missing-marker-for-empty-text" not in terminal_prompt_helper or "allowsMissingMarkerForEmptyText" not in terminal_prompt_helper:
    raise SystemExit("Terminal prompt AX helper must support Ghostty empty-prompt readiness when title markers are not exposed")

text_event_helper = Path("Sources/SteadyTypeTextEventHelper/main.swift").read_text()
if "waitForExpectedFrontmostApplication" not in text_event_helper or ".activate(options: [.activateAllWindows])" not in text_event_helper:
    raise SystemExit("Bundled text-event helper must activate and poll the expected pid before failing frontmost checks")
if "systemEventsReportsExpectedProcessFrontmost" not in text_event_helper or "first application process whose unix id is targetProcessId" not in text_event_helper:
    raise SystemExit("Bundled text-event helper must accept System Events exact-pid frontmost proof when NSWorkspace reports Ghostty's root pid")
if "frontmost pid mismatch actual=" not in text_event_helper or "expected=" not in text_event_helper:
    raise SystemExit("Bundled text-event helper frontmost failures must include actual and expected pids")
if "readDataToEndOfFile" not in text_event_helper or "multiline text refused" not in text_event_helper:
    raise SystemExit("Bundled text-event helper must keep stdin-only single-line text input")

app_delegate = Path("Sources/AutocompleteLabApp/App/AppDelegate.swift").read_text()
if "clonePasteboardItems" not in app_delegate or "$0.copy() as? NSPasteboardItem" in app_delegate:
    raise SystemExit("App pasteboard fallbacks must clone pasteboard data without NSPasteboardItem.copy() exceptions")
if "static var currentSuggestionTuningDefaultsVersion: Int {\n        6\n    }" not in app_delegate:
    raise SystemExit("Daily-driver tuning defaults version must bump when visible phrase length changes")
if "if maxVisibleWords == 3 || maxVisibleWords == 5" not in app_delegate or "maxVisibleWords = SuggestionTuning.defaultMaxVisibleWords" not in app_delegate:
    raise SystemExit("Daily-driver tuning migration must lift old 3/5-word defaults to the current short-phrase length")
if "canTrustPromptProofFieldIdentityRefresh" not in app_delegate or "prompt-proof-field-identity-refresh-relaxed" not in app_delegate:
    raise SystemExit("Prompt proof refresh must safely relax stale field identity only after live text verification")
if "pollTimer?.fireDate" in app_delegate:
    raise SystemExit("focused text polling must not defer the shared timer past a future faster cadence state")
placement_gate_start = app_delegate.index("let syntheticCaretBundleIdentifier = syntheticTextAreaCaretBundleIdentifier(")
placement_gate_end = app_delegate.index("guard supportsSyntheticTextAreaCaret", placement_gate_start)
placement_gate_block = app_delegate[placement_gate_start:placement_gate_end]
if "requiresTerminalScreenPromptCaret" not in placement_gate_block or "missing-terminal-screen-prompt" not in placement_gate_block:
    raise SystemExit("Ghostty Claude Code proof must reject generic top-row synthetic carets without terminal-screen-prompt placement")
synthetic_record_start = app_delegate.index("private func recordSyntheticCaretIfNeeded(")
synthetic_record_end = app_delegate.index("private func recordTextContextRepairIfNeeded(", synthetic_record_start)
synthetic_record_block = app_delegate[synthetic_record_start:synthetic_record_end]
if 'source != "terminal-screen-prompt"' not in synthetic_record_block:
    raise SystemExit("Ghostty Claude Code proof must keep recording terminal-screen-prompt caret evidence for the live harness")
terminal_insert_start = app_delegate.index("private func insertClaudeCodeTerminalHostProofPasteboardText(")
terminal_insert_end = app_delegate.index("private func verifyClaudeCodeTerminalHostProofInsertion(", terminal_insert_start)
terminal_insert_block = app_delegate[terminal_insert_start:terminal_insert_end]
terminal_verification_start = app_delegate.index("private func claudeCodeTerminalHostProofVerificationInputText(")
terminal_verification_end = app_delegate.index("private func verifyClaudeCodeTerminalHostProofInsertion(", terminal_verification_start)
terminal_verification_block = app_delegate[terminal_verification_start:terminal_verification_end]
if "proofInputTextPreferringTerminalScreen" not in terminal_verification_block or "focusedWindowText(for: app)" not in terminal_verification_block:
    raise SystemExit("Claude Code Ghostty proof verification must prefer current terminal screen text over stale focused text")
if "claude-code-terminal-host-proof-verification" not in app_delegate or '"terminalScreen"' not in terminal_verification_block:
    raise SystemExit("Claude Code Ghostty proof verification must diagnose terminal-screen verification wins")
hardware_helper_start = app_delegate.index("private func insertClaudeCodeTerminalHostProofHardwareKeyEvents(")
hardware_helper_end = app_delegate.index("\n    private func insertClaudeCodeTerminalHostProofBundledTextEventHelper(", hardware_helper_start)
hardware_helper_block = app_delegate[hardware_helper_start:hardware_helper_end]
bundled_helper_start = app_delegate.index("private func insertClaudeCodeTerminalHostProofBundledTextEventHelper(")
bundled_helper_end = app_delegate.index("private func prepareGhosttyTerminalHostProofInsertionTarget(", bundled_helper_start)
bundled_helper_block = app_delegate[bundled_helper_start:bundled_helper_end]
native_prefix_final_key_start = app_delegate.index("private func insertGhosttyTerminalHostProofNativePrefixFinalKeyText(")
native_prefix_final_key_end = app_delegate.index("private func insertGhosttyTerminalHostProofInProcessInputText(", native_prefix_final_key_start)
native_prefix_final_key_block = app_delegate[native_prefix_final_key_start:native_prefix_final_key_end]
fast_ghostty_start = app_delegate.index("if prefersFastGhosttyPasteboardInsertion {")
fast_ghostty_end = app_delegate.index('\n        if frontmostApp.bundleIdentifier == "com.mitchellh.ghostty",', fast_ghostty_start)
fast_ghostty_block = app_delegate[fast_ghostty_start:fast_ghostty_end]
if "prepareGhosttyTerminalHostProofInsertionTarget" not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must reassert and verify the target before inserting")
if "focusGhosttyTerminalHostProofPromptByClickIfAvailable" not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must click the proven prompt-row caret before app-owned insertion")
if "insertGhosttyTerminalHostProofSystemEventsKeystroke" not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must keep guarded System Events fallback rungs")
if "insertGhosttyTerminalHostProofInProcessInputText" not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must try app-owned in-process native input text before subprocess input fallbacks")
if "insertGhosttyTerminalHostProofFrontWindowInputText" not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must try the smoke-equivalent front-window input text rung")
if "launchThroughShell: true" not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must try the shell-launched front-window input text rung")
if "insertGhosttyTerminalHostProofActionText" not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must try Ghostty's native text action before slower key fallbacks")
if "insertGhosttyTerminalHostProofAppleScriptText" not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must keep timeout-bounded native input text as a verified fallback")
if "ghosttyAppleScriptLoginShellInputText" not in app_delegate or "ghosttyLoginShellInputTextOutcome" not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must include shell-launched marker-scanned native input text")
if "insertGhosttyTerminalHostProofPasteAction" not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must keep Ghostty's native paste action as a verified fallback")
if "insertGhosttyTerminalHostProofSendKey" not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must try terminal-scoped send key before System Events")
if "insertClaudeCodeTerminalHostProofHardwareKeyEvents" not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must try hardware key events before bundled Unicode helpers")
if "insertClaudeCodeTerminalHostProofBundledTextEventHelper" not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must try the bundled app-owned CGEvent text helper")
if "bulkKeystroke: true" not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must try System Events bulk keystroke before per-character fallback")
if "launchThroughShell: true" not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must try a shell-launched System Events bulk keystroke")
if '"cgHardwareKeyEventsToPid"' not in fast_ghostty_block or '"cgHardwareKeyEventsGlobal"' not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must try targeted and global hardware key-event insertion")
if fast_ghostty_block.index("insertGhosttyTerminalHostProofActionText") > fast_ghostty_block.index("insertGhosttyTerminalHostProofAppleScriptText"):
    raise SystemExit("Claude Code Ghostty fast proof must try native text action before native input text")
if fast_ghostty_block.index("focusGhosttyTerminalHostProofPromptByClickIfAvailable") > fast_ghostty_block.index("insertGhosttyTerminalHostProofActionText"):
    raise SystemExit("Claude Code Ghostty fast proof must focus-click the prompt before native text insertion")
if fast_ghostty_block.index("insertGhosttyTerminalHostProofInProcessInputText") > fast_ghostty_block.index("insertGhosttyTerminalHostProofFrontWindowInputText"):
    raise SystemExit("Claude Code Ghostty fast proof must try in-process native input before subprocess front-window input")
if fast_ghostty_block.index("insertGhosttyTerminalHostProofFrontWindowInputText") > fast_ghostty_block.index("insertGhosttyTerminalHostProofActionText"):
    raise SystemExit("Claude Code Ghostty fast proof must try front-window input text before marker-scanned native text action")
if fast_ghostty_block.index("launchThroughShell: true") > fast_ghostty_block.index("insertGhosttyTerminalHostProofActionText"):
    raise SystemExit("Claude Code Ghostty fast proof must try shell-launched front-window input text before marker-scanned native text action")
if fast_ghostty_block.index("insertGhosttyTerminalHostProofAppleScriptText") > fast_ghostty_block.index("insertGhosttyTerminalHostProofPasteAction"):
    raise SystemExit("Claude Code Ghostty fast proof must try native input text before native paste action")
if fast_ghostty_block.index("ghosttyLoginShellInputTextOutcome") > fast_ghostty_block.index("insertGhosttyTerminalHostProofPasteAction"):
    raise SystemExit("Claude Code Ghostty fast proof must try shell-launched marker-scanned native input before native paste action")
if fast_ghostty_block.index("insertGhosttyTerminalHostProofSendKey") > fast_ghostty_block.index("insertGhosttyTerminalHostProofInProcessInputText"):
    raise SystemExit("Claude Code Ghostty fast proof must try terminal-scoped send key before slow native text fallbacks")
if fast_ghostty_block.index("insertGhosttyTerminalHostProofSendKey") > fast_ghostty_block.index("insertGhosttyTerminalHostProofSystemEventsKeystroke"):
    raise SystemExit("Claude Code Ghostty fast proof must try terminal-scoped send key before System Events")
if fast_ghostty_block.index("insertGhosttyTerminalHostProofSendKey") > fast_ghostty_block.index("insertClaudeCodeTerminalHostProofPasteboardText"):
    raise SystemExit("Claude Code Ghostty fast proof must try terminal-scoped send key before pasteboard probes")
bulk_system_events_source = fast_ghostty_block.index("bulkKeystroke: true")
per_character_system_events_source = fast_ghostty_block.index("delayMilliseconds: 0", bulk_system_events_source + 1)
if bulk_system_events_source > per_character_system_events_source:
    raise SystemExit("Claude Code Ghostty fast proof must try bulk System Events before per-character System Events")
if fast_ghostty_block.index("insertGhosttyTerminalHostProofSystemEventsKeystroke") > fast_ghostty_block.index("insertClaudeCodeTerminalHostProofHardwareKeyEvents"):
    raise SystemExit("Claude Code Ghostty fast proof must try System Events before hardware key events")
if fast_ghostty_block.index("insertGhosttyTerminalHostProofSystemEventsKeystroke") > fast_ghostty_block.index("insertClaudeCodeTerminalHostProofPasteboardText"):
    raise SystemExit("Claude Code Ghostty fast proof must try proven System Events bulk insertion before pasteboard probes")
if fast_ghostty_block.index("insertClaudeCodeTerminalHostProofHardwareKeyEvents") > fast_ghostty_block.index("insertClaudeCodeTerminalHostProofBundledTextEventHelper"):
    raise SystemExit("Claude Code Ghostty fast proof must try hardware key events before the bundled text helper")
if fast_ghostty_block.index("insertClaudeCodeTerminalHostProofBundledTextEventHelper") > fast_ghostty_block.index("postUnicodeTextKeyEventsPerCharacter"):
    raise SystemExit("Claude Code Ghostty fast proof must try the bundled text helper before in-process Unicode events")
if fast_ghostty_block.index("ghosttyShellBulkSystemEventsOutcome") < fast_ghostty_block.index("insertClaudeCodeTerminalHostProofBundledTextEventHelper"):
    raise SystemExit("Claude Code Ghostty fast proof must try bundled helpers before the shell-launched System Events bulk fallback")
if fast_ghostty_block.index("insertClaudeCodeTerminalHostProofPasteboardText") > fast_ghostty_block.index("insertGhosttyTerminalHostProofInProcessInputText"):
    raise SystemExit("Claude Code Ghostty fast proof must try pasteboard insertion before slower native input fallbacks")
if fast_ghostty_block.index("insertGhosttyTerminalHostProofNativePrefixFinalKeyText") > fast_ghostty_block.index("insertGhosttyTerminalHostProofInProcessInputText"):
    raise SystemExit("Claude Code Ghostty fast proof must try the opt-in native-prefix/final-key transport before plain native input")
if "ghosttyFastFailClosed" not in fast_ghostty_block or "ghostty-fast-verified-insertion-failed" not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must fail closed before generic insertion fallbacks")
if "AUTOCOMPLETE_LAB_GHOSTTY_EXTENDED_INSERTION_PROBES" not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must keep the long insertion ladder behind an explicit opt-in flag")
if "AUTOCOMPLETE_LAB_GHOSTTY_FAST_INSERTION_BUDGET_SECONDS" not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must allow an explicit bounded insertion budget override")
if "ghosttyFastInsertionBudget" not in fast_ghostty_block or "ghostty-fast-insertion-budget-exceeded" not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must log a bounded fail-closed insertion miss")
if "AUTOCOMPLETE_LAB_GHOSTTY_NATIVE_PREFIX_FINAL_KEY_PROBE" not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty native-prefix/final-key probe must stay opt-in until live proof verifies it")
if "ghosttyNativePrefixFinalKeyText" not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must keep the native-prefix/final-key transport in the insertion ladder")
if 'shouldContinueGhosttyFastInsertion(before: "ghosttyPerformActionText")' not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must budget-gate slower native action text probes")
if 'shouldContinueGhosttyFastInsertion(before: "cgUnicodeKeyEventsPerCharacterGlobal")' not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must budget-gate the final global Unicode key-event probe")
native_prefix_helper_start = app_delegate.index("private func insertGhosttyTerminalHostProofNativePrefixFinalKeyText(")
native_prefix_helper_end = app_delegate.index("private func insertGhosttyTerminalHostProofInProcessInputText(", native_prefix_helper_start)
native_prefix_helper_block = app_delegate[native_prefix_helper_start:native_prefix_helper_end]
if "ghosttyNativePrefixFinalKeyTextBaseline" not in native_prefix_helper_block:
    raise SystemExit("Claude Code Ghostty native-prefix/final-key probe must verify the original prompt before continuing")
if "ghostty-native-prefix-final-key-final-event-not-posted" not in native_prefix_helper_block:
    raise SystemExit("Claude Code Ghostty native-prefix/final-key probe must log final key-event post misses")
if "ghostty-native-prefix-final-key-frontmost-reassertion-mutated-input" not in native_prefix_helper_block:
    raise SystemExit("Claude Code Ghostty native-prefix/final-key probe must fail closed when focus reassertion cannot prove the prompt unchanged")
if "postHardwareTextKeyEvents" not in hardware_helper_block or "mutatedInputReason" not in hardware_helper_block:
    raise SystemExit("Claude Code Ghostty hardware key proof must be verified and fail closed on unexpected mutation")
if "FrontmostPidReassertion" not in hardware_helper_block:
    raise SystemExit("Claude Code Ghostty hardware key proof must reassert the exact Ghostty proof pid before posting events")
prompt_focus_start = app_delegate.index("private func focusGhosttyTerminalHostProofPromptByClickIfAvailable(")
prompt_focus_end = app_delegate.index("private func prepareGhosttyTerminalHostProofInsertionTarget(", prompt_focus_start)
prompt_focus_block = app_delegate[prompt_focus_start:prompt_focus_end]
if "targetFingerprint.caretBounds" not in prompt_focus_block or "CGEvent(" not in prompt_focus_block:
    raise SystemExit("Claude Code Ghostty prompt focus must click the shown caret, not a generic window point")
if "ghostty-prompt-focus-click-missing-caret" not in prompt_focus_block:
    raise SystemExit("Claude Code Ghostty prompt focus click must fail closed when the shown caret is missing")
front_window_input_start = app_delegate.index("private func insertGhosttyTerminalHostProofFrontWindowInputText(")
front_window_input_end = app_delegate.index("private func focusGhosttyTerminalHostProofPromptByClickIfAvailable(", front_window_input_start)
front_window_input_block = app_delegate[front_window_input_start:front_window_input_end]
if "set targetWindow to front window" not in front_window_input_block or "input text acceptedText to targetTerminal" not in front_window_input_block:
    raise SystemExit("Claude Code Ghostty front-window input rung must mirror the live smoke native typing path")
if "ghosttyFrontWindowInputTextBaseline" not in front_window_input_block or "ghostty-front-window-input-unverified-mutated-input" not in front_window_input_block:
    raise SystemExit("Claude Code Ghostty front-window input rung must verify unchanged baseline and fail closed on mutation")
if "ghosttyLoginShellFrontWindowInputText" not in front_window_input_block or 'process.arguments = ["-lc", "exec /usr/bin/osascript"]' not in front_window_input_block:
    raise SystemExit("Claude Code Ghostty front-window input rung must support the login-shell native input proof path")
if "standardInput.fileHandleForWriting.write(Data(scriptSource.utf8))" not in front_window_input_block:
    raise SystemExit("Claude Code Ghostty shell-launched front-window input must pass AppleScript through stdin")
if "AUTOCOMPLETE_LAB_GHOSTTY_KEY_DELAY_SECONDS" not in terminal_insert_block or "repeat with characterIndex" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty System Events proof must type accepted text as paced characters")
if "bundledCGEventTextHelper" not in bundled_helper_block or "bundled-helper-unverified-mutated-input" not in bundled_helper_block:
    raise SystemExit("Claude Code Ghostty bundled helper proof must be verified and fail closed on unexpected mutation")
if "bundledCGEventTextHelperHID" not in bundled_helper_block or "bundledCGEventTextHelperSession" not in bundled_helper_block:
    raise SystemExit("Claude Code Ghostty bundled helper proof must try both HID and session text taps")
if "FrontmostPidReassertion" not in bundled_helper_block or "FrontmostPidReassertionBaseline" not in bundled_helper_block:
    raise SystemExit("Claude Code Ghostty bundled helper proof must reassert and baseline-check the exact Ghostty proof pid before posting events")
if 'tapName: "hid"' not in fast_ghostty_block or 'tapName: "session"' not in fast_ghostty_block:
    raise SystemExit("Claude Code Ghostty fast proof must run bundled helper HID and session tap attempts")
if "process.arguments" not in bundled_helper_block or "acceptedText" in bundled_helper_block.split("process.arguments", 1)[1].split("]", 1)[0]:
    raise SystemExit("Claude Code Ghostty bundled helper must not put accepted text in process arguments")
if "inputPipe.fileHandleForWriting.write(Data(acceptedText.utf8))" not in bundled_helper_block:
    raise SystemExit("Claude Code Ghostty bundled helper must pass accepted text over stdin")
if "ghosttyFocusPidReassertion" not in app_delegate or "reassertGhosttyTerminalHostProofFrontmostProcess" not in app_delegate:
    raise SystemExit("Claude Code Ghostty proof must keep a reusable exact-pid frontmost reassertion before fragile event-posting rungs")
targeted_source = terminal_insert_block.index('source: "pasteboardCommandVToPid"')
global_source = terminal_insert_block.index('source: "pasteboardCommandV"', targeted_source)
if targeted_source > global_source:
    raise SystemExit("Claude Code terminal-host paste proof must try pid-targeted Command-V before global Command-V")
if "processIdentifier: frontmostApp.processIdentifier" not in terminal_insert_block:
    raise SystemExit("Claude Code terminal-host paste proof must post Command-V to the verified frontmost terminal pid")
if "reassertGhosttyTerminalHostProofFrontmostProcess" not in terminal_insert_block or "FrontmostPidReassertion" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty pid paste proof must reassert the exact proof pid before Command-V")
if "pasteboardCommandVToPidBaseline" not in terminal_insert_block:
    raise SystemExit("Claude Code terminal-host paste proof must verify the prompt stayed unchanged after an unverified pid paste")
if "AUTOCOMPLETE_LAB_GHOSTTY_SESSION_TAP_PASTE_PROBE" not in terminal_insert_block:
    raise SystemExit("Claude Code terminal-host session-tap paste probe must stay opt-in after timeout evidence")
if "pasteboardCommandVSession" not in terminal_insert_block or ".cgSessionEventTap" not in terminal_insert_block:
    raise SystemExit("Claude Code terminal-host paste proof must keep the paced session-tap Command-V probe available for isolated repros")
if "session-tap-probe-disabled" not in terminal_insert_block:
    raise SystemExit("Claude Code terminal-host paste proof must skip the session-tap probe by default instead of risking a proof timeout")
if "RestoreDeferredToNextAttempt" not in terminal_insert_block or "deferPasteboardRestoreOnMiss: false" not in terminal_insert_block:
    raise SystemExit("Claude Code terminal-host session paste miss must hand off to the final global paste without a blocking restore when the opt-in probe runs")
if "pasteboard-to-pid-unverified-mutated-input" not in terminal_insert_block:
    raise SystemExit("Claude Code terminal-host paste proof must fail closed if pid paste mutates the prompt unexpectedly")
if "guard targetedPasteOutcome.safeToContinue else" not in terminal_insert_block:
    raise SystemExit("Claude Code terminal-host paste proof must not continue to global paste after unsafe pid insertion")
if "restoreSynchronouslyOnMiss: true" not in terminal_insert_block or "restoreSynchronouslyOnMiss: false" not in terminal_insert_block:
    raise SystemExit("Claude Code terminal-host paste proof must keep synchronous pid cleanup but async final global cleanup")
if "tapLocation: CGEventTapLocation" not in app_delegate or "Thread.sleep(forTimeInterval: 0.018)" not in app_delegate:
    raise SystemExit("Claude Code terminal-host paste proof must pace Command-V key-down/key-up events")
paste_verified_record = terminal_insert_block.index('"verified": String(verified)')
paste_miss_baseline = terminal_insert_block.index("let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion", paste_verified_record)
paste_miss_restore = terminal_insert_block.index("if restoreSynchronouslyOnMiss", paste_miss_baseline)
if paste_miss_baseline > paste_miss_restore:
    raise SystemExit("Claude Code terminal-host paste proof must record unchanged-prompt baseline before pasteboard cleanup")
if '"source": "\\(source)RestoreScheduled"' not in terminal_insert_block:
    raise SystemExit("Claude Code terminal-host paste proof must log async cleanup on final global paste miss")
global_paste_call = terminal_insert_block[terminal_insert_block.index("let globalPasteOutcome = tryPasteboardCommandV("):]
if "restoreSynchronouslyOnMiss: false" not in global_paste_call:
    raise SystemExit("Claude Code terminal-host global paste miss must not block the keyboard callback on synchronous pasteboard restore")
if '"ghosttySystemEventsKeystrokeShell"' not in terminal_insert_block or "/usr/bin/osascript" not in terminal_insert_block or "keystroke" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty proof must keep a verified System Events keystroke fallback")
if "ghosttySystemEventsKeystrokeShellBaseline" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty System Events proof must verify the prompt stayed unchanged after unverified keystrokes")
if "ghostty-system-events-unverified-mutated-input" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty System Events proof must fail closed if keystrokes mutate the prompt unexpectedly")
if "scriptTimeoutSeconds" not in terminal_insert_block or "ghostty-system-events-osascript-timeout" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty System Events proof must be timeout bounded")
if "ghostty-system-events-timeout-mutated-input" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty System Events timeout must fail closed if keystrokes mutate the prompt")
if "ghosttySystemEventsKeystrokeShellAsync" in terminal_insert_block or "ghosttyPerformActionTextAsync" in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty proof must not report success from unverified async insertion")
if "DispatchQueue.main.asyncAfter" in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty proof must not schedule post-accept async insertion")
if '"ghosttySystemEventsBulkKeystrokeShell"' not in terminal_insert_block or 'keystrokeMode is "bulk"' not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty proof must keep a verified System Events bulk keystroke fallback")
if "set frontmost of ghosttyProcess to true" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty System Events proof must foreground Ghostty through System Events before typing")
if "AUTOCOMPLETE_LAB_GHOSTTY_TARGET_PID" not in terminal_insert_block or "whose unix id is targetProcessId" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty insertion fallbacks must foreground the exact title-scoped Ghostty proof process")
if "Target Ghostty process is not frontmost" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty insertion fallbacks must fail clearly when the exact proof process is not frontmost")
if "AUTOCOMPLETE_LAB_GHOSTTY_NATIVE_PREFIX_FINAL_KEY_DRAIN_SECONDS" not in native_prefix_final_key_block:
    raise SystemExit("Claude Code Ghostty native-prefix/final-key probe must have a bounded drain override")
if "postUnicodeTextKeyEventsPerCharacter(finalText)" not in native_prefix_final_key_block:
    raise SystemExit("Claude Code Ghostty native-prefix/final-key probe must use a real final key event after native input")
if "ghostty-native-prefix-final-key-unverified-mutated-input" not in native_prefix_final_key_block:
    raise SystemExit("Claude Code Ghostty native-prefix/final-key probe must fail closed if only part of the transport mutates the prompt")
if "prefixExpectedProofInputText" not in native_prefix_final_key_block or '"stage": "prefix-verified"' not in native_prefix_final_key_block:
    raise SystemExit("Claude Code Ghostty native-prefix/final-key probe must verify the native prefix before sending the final key")
if "?? 8.0" not in native_prefix_final_key_block or "10.0" not in native_prefix_final_key_block:
    raise SystemExit("Claude Code Ghostty native-prefix/final-key probe must use the harness-like bounded native-text drain")
if "ghostty-native-prefix-final-key-prefix-unverified-noop" not in native_prefix_final_key_block:
    raise SystemExit("Claude Code Ghostty native-prefix/final-key probe must distinguish a no-op prefix from a final-key miss")
prefix_verify_source = native_prefix_final_key_block.index("expectedProofInputText: prefixExpectedProofInputText")
final_key_source = native_prefix_final_key_block.index("postUnicodeTextKeyEventsPerCharacter(finalText)")
if prefix_verify_source > final_key_source:
    raise SystemExit("Claude Code Ghostty native-prefix/final-key probe must verify the prefix before posting the final key event")
drain_source = native_prefix_final_key_block.index("Thread.sleep(forTimeInterval: drainSeconds)")
if drain_source > prefix_verify_source:
    raise SystemExit("Claude Code Ghostty native-prefix/final-key probe must drain native text before prefix verification")
for env_key in [
    "AUTOCOMPLETE_LAB_GHOSTTY_EXTENDED_INSERTION_PROBES",
    "AUTOCOMPLETE_LAB_GHOSTTY_FAST_INSERTION_BUDGET_SECONDS",
    "AUTOCOMPLETE_LAB_GHOSTTY_NATIVE_PREFIX_FINAL_KEY_DRAIN_SECONDS",
    "AUTOCOMPLETE_LAB_GHOSTTY_NATIVE_PREFIX_FINAL_KEY_PROBE",
    "AUTOCOMPLETE_LAB_GHOSTTY_SESSION_TAP_PASTE_PROBE",
]:
    if env_key not in source:
        raise SystemExit(f"real app smoke launch must forward {env_key} into the SteadyType app process")
if '"ghosttySystemEventsLoginShellBulkKeystroke"' not in terminal_insert_block or 'exec /usr/bin/osascript' not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty proof must keep a shell-launched System Events bulk fallback")
if "ghosttySystemEventsBulkKeystrokeShellBaseline" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty System Events bulk proof must verify the prompt stayed unchanged after unverified keystrokes")
if "ghostty-system-events-bulk-unverified-mutated-input" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty System Events bulk proof must fail closed if keystrokes mutate the prompt unexpectedly")
if "compactProofMarker" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty insertion fallbacks must remain title-marker scoped")
if terminal_insert_block.count("repeat with candidateWindow in windows") < 5 or terminal_insert_block.count("set targetWindow to candidateWindow") < 5:
    raise SystemExit("Claude Code Ghostty insertion fallbacks must find the title-marked proof window instead of trusting the front Ghostty window")
ghostty_window_target_helpers = [
    ("in-process input text", "private func insertGhosttyTerminalHostProofInProcessInputText(", "private func insertGhosttyTerminalHostProofFrontWindowInputText("),
    ("paste action", "private func insertGhosttyTerminalHostProofPasteAction(", "private func insertGhosttyTerminalHostProofSystemEventsKeystroke("),
    ("system events", "private func insertGhosttyTerminalHostProofSystemEventsKeystroke(", "private func insertGhosttyTerminalHostProofActionText("),
    ("action text", "private func insertGhosttyTerminalHostProofActionText(", "private func insertGhosttyTerminalHostProofAppleScriptText("),
    ("input text", "private func insertGhosttyTerminalHostProofAppleScriptText(", "nonisolated private static func waitForProcessExit("),
    ("send key", "private func insertGhosttyTerminalHostProofSendKey(", "nonisolated private static func ghosttySendKeySteps("),
]
for name, start_marker, end_marker in ghostty_window_target_helpers:
    helper_block = app_delegate[app_delegate.index(start_marker):app_delegate.index(end_marker, app_delegate.index(start_marker))]
    if 'set targetWindowName to ""' not in helper_block or "name of front window of ghosttyProcess as text" not in helper_block:
        raise SystemExit(f"Claude Code Ghostty {name} proof must capture the exact pid front-window title before native insertion")
    if "set targetWindowNameIsProof to false" not in helper_block:
        raise SystemExit(f"Claude Code Ghostty {name} proof must treat unmarked front-window titles as stale")
    if name == "input text" and ("ghosttyAppleScriptLoginShellInputText" not in helper_block or 'process.arguments = ["-lc", "exec /usr/bin/osascript"]' not in helper_block):
        raise SystemExit("Claude Code Ghostty native input text must support a shell-launched marker-scanned proof path")
    if name == "input text" and "standardInput.fileHandleForWriting.write(Data(scriptSource.utf8))" not in helper_block:
        raise SystemExit("Claude Code Ghostty shell-launched native input text must pass AppleScript through stdin")
    if "targetWindowName contains" not in helper_block:
        raise SystemExit(f"Claude Code Ghostty {name} proof must only trust exact front-window titles that carry the proof marker")
    exact_title_source = helper_block.index('targetWindowNameIsProof and targetWindowName is not "" and windowName is targetWindowName')
    marker_fallback_source = helper_block.index("windowName contains", exact_title_source)
    if exact_title_source > marker_fallback_source:
        raise SystemExit(f"Claude Code Ghostty {name} proof must prefer the exact pid front-window title before marker fallback")
if "ghostty-system-events-proof-window-missing" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty System Events proof must fail closed when no title-marked proof window is found")
if terminal_insert_block.count("focus targetTerminal") < 5 or terminal_insert_block.count("activate window targetWindow") < 5:
    raise SystemExit("Claude Code Ghostty native insertion fallbacks must re-focus the title-scoped terminal before posting input")
if terminal_insert_block.count("\n            activate\n") < 5:
    raise SystemExit("Claude Code Ghostty native insertion fallbacks must mirror the harness by activating Ghostty after terminal focus")
if '"ghosttyPerformActionText"' not in terminal_insert_block or "perform action" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty proof must use Ghostty's native text action command")
if "ghosttyPerformActionTextBaseline" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty proof must verify the prompt stayed unchanged after unverified action text")
if "ghostty-action-unverified-mutated-input" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty proof must fail closed if action text mutates the prompt unexpectedly")
if "ghostty-action-script-timeout" not in terminal_insert_block or "ghosttyPerformActionTextTimeoutBaseline" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty native action text must be timeout bounded with unchanged-prompt baseline proof")
if "ghostty-action-script-timeout-mutated-input" not in terminal_insert_block or "ghostty-action-script-timeout-still-running" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty native action text timeout must fail closed on mutation or a still-running script")
if "AUTOCOMPLETE_LAB_GHOSTTY_ACTION_TEXT" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty native action text must pass the escaped action through osascript environment")
if "ghosttyTextAction" not in terminal_insert_block or "\\\\x%02x" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty proof must hex-escape non-alphanumeric text action bytes")
if '"ghosttyAppleScriptInputText"' not in terminal_insert_block or "input text" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty proof must use Ghostty's native scripting input text command")
if "ghostty-apple-script-timeout" not in terminal_insert_block or "waitForProcessExit" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty native input text must be timeout bounded")
if "ghosttyAppleScriptInputTextTimeoutBaseline" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty native input text timeout must verify the prompt stayed unchanged")
if "ghostty-apple-script-timeout-mutated-input" not in terminal_insert_block or "ghostty-apple-script-timeout-still-running" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty native input text timeout must fail closed on mutation or a still-running script")
if "AUTOCOMPLETE_LAB_GHOSTTY_ACCEPTED_TEXT" not in terminal_insert_block or "system attribute" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty native input text must avoid putting accepted text in osascript argv")
if "ghosttyAppleScriptInputTextBaseline" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty proof must verify the prompt stayed unchanged after unverified scripting input")
if "ghostty-apple-script-unverified-mutated-input" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty proof must fail closed if scripting input mutates the prompt unexpectedly")
if '"ghosttyInProcessInputText"' not in app_delegate or "ghosttyInProcessInputTextBaseline" not in app_delegate:
    raise SystemExit("Claude Code Ghostty proof must include in-process native input text with unchanged-prompt baseline proof")
if "ghostty-in-process-input-unverified-mutated-input" not in app_delegate:
    raise SystemExit("Claude Code Ghostty in-process native input must fail closed if it mutates the prompt unexpectedly")
if '"ghosttyPerformActionPasteFromClipboard"' not in terminal_insert_block or 'perform action "paste_from_clipboard"' not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty proof must try Ghostty's native paste_from_clipboard action")
if "ghosttyPerformActionPasteFromClipboardBaseline" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty native paste action must verify the prompt stayed unchanged after unverified paste")
if "ghostty-paste-action-unverified-mutated-input" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty native paste action must fail closed if paste mutates the prompt unexpectedly")
if "ghostty-paste-action-script-timeout" not in terminal_insert_block or "ghosttyPerformActionPasteFromClipboardTimeoutBaseline" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty native paste action must be timeout bounded with unchanged-prompt baseline proof")
if "ghostty-paste-action-timeout-mutated-input" not in terminal_insert_block or "ghostty-paste-action-script-timeout-still-running" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty native paste action timeout must fail closed on mutation or a still-running script")
if '"ghosttySendKey"' not in terminal_insert_block or "send key" not in terminal_insert_block or "action release" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty proof must use Ghostty's terminal-scoped send key command before global key events")
if "ghosttySendKeyBaseline" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty send key proof must verify the prompt stayed unchanged after unverified terminal-scoped key events")
if "ghostty-send-key-unverified-mutated-input" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty send key proof must fail closed if terminal-scoped key events mutate the prompt unexpectedly")
if "ghosttySendKeySteps" not in terminal_insert_block or "ghostty-send-key-text-unsupported" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty send key proof must gate unsupported accepted text before falling back")
if '"apostrophe"' not in terminal_insert_block or "unsupportedScalar" not in terminal_insert_block:
    raise SystemExit("Claude Code Ghostty send key proof must support safe apostrophes and log unsupported scalars")
terminal_main_insert_start = app_delegate.index("private func insertClaudeCodeTerminalHostProofText(")
terminal_main_insert_end = app_delegate.index("private func insertClaudeCodeTerminalHostProofPasteboardText(", terminal_main_insert_start)
terminal_main_insert_block = app_delegate[terminal_main_insert_start:terminal_main_insert_end]
ghostty_slow_start = terminal_main_insert_block.index('if frontmostApp.bundleIdentifier == "com.mitchellh.ghostty",')
ghostty_slow_end = terminal_main_insert_block.index("\n        if Self.postHardwareTextKeyEvents", ghostty_slow_start)
ghostty_slow_block = terminal_main_insert_block[ghostty_slow_start:ghostty_slow_end]
ghostty_action_source = ghostty_slow_block.index("insertGhosttyTerminalHostProofActionText")
ghostty_script_source = ghostty_slow_block.index("insertGhosttyTerminalHostProofAppleScriptText")
ghostty_send_key_source = ghostty_slow_block.index("insertGhosttyTerminalHostProofSendKey")
ghostty_system_events_source = ghostty_slow_block.index("insertGhosttyTerminalHostProofSystemEventsKeystroke")
hardware_source = terminal_main_insert_block.index("Self.postHardwareTextKeyEvents")
if ghostty_action_source > ghostty_script_source:
    raise SystemExit("Claude Code Ghostty proof must try raw Ghostty text actions before paste-like scripting input")
if ghostty_script_source > ghostty_send_key_source:
    raise SystemExit("Claude Code Ghostty proof must try native scripting input before terminal-scoped send key events")
if ghostty_send_key_source > ghostty_system_events_source:
    raise SystemExit("Claude Code Ghostty proof must try terminal-scoped send key events before System Events keystrokes")
if ghostty_system_events_source > hardware_source:
    raise SystemExit("Claude Code Ghostty proof must try verified System Events keystrokes before slow CG key-event fallbacks")
if "cgHardwareKeyEventsGlobal" not in terminal_main_insert_block or "cgUnicodeKeyEventsGlobal" not in terminal_main_insert_block:
    raise SystemExit("Claude Code terminal-host insertion must try verified global text key events before paste fallback")
if terminal_main_insert_block.count("keyboardEventTap?.suppressPassthroughObservation(for: 0.5)") < 2:
    raise SystemExit("Claude Code terminal-host global key insertion must suppress synthetic typing passthrough observation")
insert_start = app_delegate.index("private func insertObsidianDirectValueText(")
insert_end = app_delegate.index("private func insertObsidianSystemEventsPasteText(", insert_start)
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
   ! grep -F 'PROOF_SUPPRESS_ANNOYANCE_LAUNCHCTL_PREVIOUS' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'launchctl unsetenv "$PROOF_DISABLE_WORD_ENV_KEY"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'launchctl unsetenv "$PROOF_DISABLE_PHRASE_ENV_KEY"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'launchctl unsetenv "$PROOF_DISABLE_FAST_PHRASE_ENV_KEY"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'launchctl unsetenv "$PROOF_SCENARIO_ENV_KEY"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'launchctl unsetenv "$PROOF_SUPPRESS_ANNOYANCE_ENV_KEY"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected model latency proof scenario cleanup" >&2
  exit 1
fi

if ! grep -F 'AUTOCOMPLETE_LAB_GHOSTTY_NATIVE_PREFIX_FINAL_KEY_PROBE \' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_GHOSTTY_FAST_INSERTION_BUDGET_SECONDS \' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_GHOSTTY_SESSION_TAP_PASTE_PROBE \' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Ghostty proof env overrides to reach relaunched SteadyType" >&2
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
if ! grep -F "osascript_stdin_path" script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'osascript "$@" <"$osascript_stdin_path"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected timed osascript helper to preserve heredoc stdin for background AppleScripts" >&2
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
    if "app.activate(options: [.activateAllWindows])" not in block:
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
if "app.activate(options: [.activateAllWindows])" not in activate_process_id_block:
    raise SystemExit("activate_process_id must force foreground activation for live proof focus recovery")
if 'wait_for_appkit_activation_frontmost "$target_pid"' not in activate_process_id_block:
    raise SystemExit("activate_process_id must skip System Events activation when AppKit already made the process frontmost")
if 'activate_process_id_osascript "$target_pid" &' not in activate_process_id_block:
    raise SystemExit("activate_process_id must keep bounded System Events activation available")
if "wait_for_appkit_activation_frontmost()" not in source or "frontmost_process_id" not in function_body("wait_for_appkit_activation_frontmost"):
    raise SystemExit("real app smoke must probe the frontmost process before falling back to System Events activation")
PY

if ! grep -F 'wait_for_textedit_document_prefix "$textedit_window_title" "$expected_text" "TextEdit model latency sample $sample_index attempt $attempt"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected TextEdit model latency typing to tolerate native TextEdit completions" >&2
  exit 1
fi

if ! grep -F 'AUTOCOMPLETE_LAB_LOG_START_LINE="$runtime_start_line"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected latency reports to include the tagged runtime launch" >&2
  exit 1
fi
if ! grep -F 'latest_runtime_bootstrap_line_number' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'proof_runtime_guard_line="$(latest_runtime_bootstrap_line_number)"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected latency relaunch guard to anchor to the tagged runtime bootstrap line" >&2
  exit 1
fi
if ! grep -F 'clear_textedit_document_for_proof()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'clear_textedit_document_for_proof "$textedit_window_title" "TextEdit model latency initial reset"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'clear_textedit_document_for_proof "$textedit_window_title" "TextEdit model latency reset $sample_index attempt $attempt"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'keystroke "a" using command down' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'key code 51' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected TextEdit model latency reset to recover through a disposable-window keyboard clear" >&2
  exit 1
fi
if ! grep -F 'AUTOCOMPLETE_LAB_TEXTEDIT_AX_WRITE_TIMEOUT_SECONDS' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'TextEdit AX value replacement' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected TextEdit AX document writes to be timeout-bounded" >&2
  exit 1
fi
if ! grep -F 'trim_textedit_native_completion_suffix' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_TEXTEDIT_SUFFIX_DELETE_COUNT' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'trim_textedit_native_completion_suffix "$textedit_window_title" "$expected_text" "TextEdit model latency sample $sample_index attempt $attempt"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected TextEdit model latency to trim native completion suffixes before waiting for visible proof" >&2
  exit 1
fi
if ! grep -F 'trim_textedit_native_completion_suffix()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'trim_textedit_native_completion_suffix "$textedit_window_title" "$expected_text" "TextEdit model latency sample $sample_index attempt $attempt"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'key code 117' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'fell back to AX replacement' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'unexpectedly long ($suffix_length chars); falling back to AX replacement' script/real_app_smoke.sh >/dev/null ||
   ! grep -F '"$label native completion fallback"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'set_textedit_document_text "$window_title" "$expected_text"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected TextEdit model latency proof to remove native completion suffixes before timing" >&2
  exit 1
fi

if ! grep -F 'AUTOCOMPLETE_LAB_ARCHIVE_PATH:-$dist_dir/smoke-proof/SteadyType.zip' script/real_app_smoke.sh >/dev/null ||
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
if ! grep -F 'AUTOCOMPLETE_LAB_BUILD_RUN_OWNED_BY_SMOKE=1' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected build/run relaunches to be marked as smoke-owned" >&2
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
   ! grep -F 'selfPgid' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'processGroup[pid]' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'terminate_foreign_proof_processes_for_exclusive_run' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'foreign_proof_process_lines' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_RUN' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'script/beta_readiness.sh' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'script/check_score_targets.sh' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'script/check_controls_diagnostics_readiness.sh' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'script/check_current_build_privacy_export.sh' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected exact app-stop cleanup to avoid killing the active proof shell" >&2
  exit 1
fi
python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
foreign_start = source.index("foreign_proof_process_lines()")
foreign_end = source.index("\nterminate_foreign_proof_processes_for_exclusive_run()", foreign_start)
foreign_block = source[foreign_start:foreign_end]
if '"$command" == "$ROOT_DIR"/dist/SteadyType.app/Contents/MacOS/SteadyType*' not in foreign_block:
    raise SystemExit(
        "real app smoke self-test expected exclusive proof cleanup not to terminate the current SteadyType app bundle"
    )

current_start = source.index("current_steadytype_app_bundle_pids()")
current_end = source.index("\nstop_current_steadytype_app_bundle()", current_start)
current_block = source[current_start:current_end]
if "current_pgid" in current_block:
    raise SystemExit(
        "real app smoke self-test expected current app stop to include smoke-launched apps in the same process group"
    )

stop_start = source.index("stop_current_steadytype_app_bundle()")
stop_end = source.index("\nstale_steadytype_app_bundle_pids()", stop_start)
stop_block = source[stop_start:stop_end]
if 'kill -9 "$pid"' not in stop_block or "Timed out stopping current SteadyType app bundle before smoke setup." not in stop_block:
    raise SystemExit(
        "real app smoke self-test expected current app stop to fail closed if the old app survives TERM"
    )
PY
if ! grep -F 'steadytype_dist_dir()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_DIST_DIR:-$ROOT_DIR/dist' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'steadytype_app_binary' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'cd "$dist_dir" && ditto -c -k --keepParent "SteadyType.app"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected smoke proof checks to honor AUTOCOMPLETE_LAB_DIST_DIR" >&2
  exit 1
fi
if ! grep -F 'AUTOCOMPLETE_LAB_QUARANTINE_OTHER_WORKTREES' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'start_foreign_worktree_quarantine_guard' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'terminate_foreign_proof_processes_for_exclusive_run quiet' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'quarantine_foreign_smoke_processes "$(other_smoke_process_lines || true)"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'quarantine_foreign_steadytype_apps' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_QUARANTINE_GUARD_INTERVAL_SECONDS' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'terminate_pid_tree "$pid"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'descendant_pids "$pid"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'cwd_is_foreign_worktree "$cwd"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'command_path_is_foreign_worktree "$command"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected quarantine mode to stop foreign worktree proof processes and app bundles" >&2
  exit 1
fi
if grep -F 'kill -TERM -"$pgid"' script/real_app_smoke.sh >/dev/null ||
   grep -F 'kill -TERM "-$pgid"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected proof quarantine to avoid process-group kills" >&2
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

chrome_window_start = source.index("focus_chrome_process_window()")
chrome_window_end = source.index("\nchrome_fixture_click_offsets()", chrome_window_start)
chrome_window_focus = source[chrome_window_start:chrome_window_end]
if (
    "let focusedWindow: AXUIElement?" not in chrome_window_focus
    or "let firstWindow = windows.first" not in chrome_window_focus
    or "smokeWindow ?? focusedWindow ?? firstWindow" not in chrome_window_focus
    or "Chrome smoke focus failed: no accessible Chrome window" not in chrome_window_focus
):
    raise SystemExit("Chrome process focus must tolerate a temporarily missing AXFocusedWindow and report real window failures")
if "guard let windowValue = copyAttribute(appElement, kAXFocusedWindowAttribute)" in chrome_window_focus:
    raise SystemExit("Chrome process focus must not require AXFocusedWindow before using the smoke window fallback")

chrome_ready = function_body("assert_chrome_ready_for_input")
focus = chrome_ready.index('focus_chrome_smoke_editor "$fixture" "$chrome_pid" "$expected_url"')
wait = chrome_ready.index('wait_for_frontmost_process_id "$chrome_pid" 5 "Chrome $fixture $label"', focus)
assert_front = chrome_ready.index('assert_frontmost_process_id "$chrome_pid" "Chrome $fixture $label"', wait)
assert_tab = chrome_ready.index('assert_chrome_expected_tab "$fixture" "$expected_url" "$label" "$chrome_pid"', assert_front)
assert_ax = chrome_ready.index('assert_chrome_focused_editable_ax "$fixture" "$chrome_pid" "$label"', assert_tab)
if not focus < wait < assert_front < assert_tab < assert_ax:
    raise SystemExit("Chrome input guard must refocus the isolated fixture before asserting frontmost/editable state")

chrome_fixture = function_body("run_chrome_fixture")
before_tab = chrome_fixture.index('before_one_word_accept_text="$(chrome_focused_editor_text "$fixture" "$chrome_pid")"')
focus_tab = chrome_fixture.index('focus_chrome_smoke_editor "$fixture" "$chrome_pid" "$chrome_url"', before_tab)
wait_tab_pid = chrome_fixture.index('wait_for_frontmost_process_id "$chrome_pid" 5 "Chrome $fixture before Tab accept"', focus_tab)
wait_tab_app = chrome_fixture.index('wait_for_frontmost_app "Google Chrome" 5', wait_tab_pid)
press_tab = chrome_fixture.index('press_key_code 48', wait_tab_app)
if not before_tab < focus_tab < wait_tab_pid < wait_tab_app < press_tab:
    raise SystemExit("Chrome proof must refocus the editor immediately before Tab acceptance")

before_full = chrome_fixture.index('before_full_accept_text="$(chrome_focused_editor_text "$fixture" "$chrome_pid")"')
focus_full = chrome_fixture.index('focus_chrome_smoke_editor "$fixture" "$chrome_pid" "$chrome_url"', before_full)
wait_full_pid = chrome_fixture.index('wait_for_frontmost_process_id "$chrome_pid" 5 "Chrome $fixture before full accept"', focus_full)
wait_full_app = chrome_fixture.index('wait_for_frontmost_app "Google Chrome" 5', wait_full_pid)
full_start = chrome_fixture.index('full_start_line="$(line_count "$LOG_PATH")"', wait_full_app)
press_full = chrome_fixture.index('press_accept_all_shortcut', full_start)
if not before_full < focus_full < wait_full_pid < wait_full_app < full_start < press_full:
    raise SystemExit("Chrome proof must refocus the editor immediately before full acceptance")
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
if ! grep -F '" while the textarea keeps inst"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F '" while the editor keeps inst"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'Chrome $fixture second suggestion attempt $second_attempt returned empty; retrying with another disposable fragment.' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'Chrome $fixture second suggestion attempt $second_attempt was too slow to display; retrying with another disposable fragment.' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Chrome textarea/contenteditable proof to retry fragile second suggestions" >&2
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
if ! grep -F "SteadyType Chrome Local Editor-Like Fixture Smoke [ready=1]" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected the Chrome editor-like fixture title to carry the local ready proof marker" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture monaco-like --dry-run >"$TMP_DIR/chrome-monaco-like.txt"
if ! grep -F "disposable Chrome monaco-like fixture" "$TMP_DIR/chrome-monaco-like.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome Monaco-like dry-run plan" >&2
  exit 1
fi
if ! grep -F "SteadyType Chrome Local Monaco-Like Fixture Smoke [ready=1]" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected the Chrome Monaco-like fixture title to carry the local ready proof marker" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture prosemirror-like --dry-run >"$TMP_DIR/chrome-prosemirror-like.txt"
if ! grep -F "disposable Chrome prosemirror-like fixture" "$TMP_DIR/chrome-prosemirror-like.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome ProseMirror-like dry-run plan" >&2
  exit 1
fi
if ! grep -F "SteadyType Chrome Local ProseMirror-Like Fixture Smoke [ready=1]" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected the Chrome ProseMirror-like fixture title to carry the local ready proof marker" >&2
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
if ! grep -F "SteadyType Chrome Local Chat-Like Fixture No-Submit Smoke [ready=1 submits=0]" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected the Chrome chat-like fixture title to carry the local ready proof marker" >&2
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

for blocked_fixture in google-docs notion browser-webmail browser-gmail browser-outlook browser-chatgpt browser-slack browser-discord; do
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
if ! grep -F "moveCaret(textInput, to: replacementText.utf16.count)" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "kAXValueAttribute as CFString" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected TextEdit proof setup to leave the caret after exact setup text" >&2
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
if ! grep -F "script/real_app_smoke.sh obsidian-font-zoom --manual-gate" "$TMP_DIR/obsidian.txt" >/dev/null ||
   ! grep -F "obsidian-font-zoom|" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test did not expose the Obsidian font/zoom proof lane" >&2
  exit 1
fi

if ! grep -F "swift script/obsidian_ax_editor.swift reset" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER_TEXT" script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'local reset_text="${AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_RESET_TEXT:-$marker}"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F "printf '%s' \"\$reset_text\"" script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'obsidian|obsidian-theme|obsidian-pane|obsidian-font-zoom|obsidian-multiline)' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'obsidian-markdown-bold)' script/real_app_smoke.sh >/dev/null ||
   ! grep -F '"**Smoke proof feels "*)' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'obsidian-markdown-list)' script/real_app_smoke.sh >/dev/null ||
   ! grep -F '"- Smoke proof feels "*)' script/real_app_smoke.sh >/dev/null ||
   ! grep -F "focusAtEnd(editor, text: resetText)" script/obsidian_ax_editor.swift >/dev/null ||
   ! grep -F "focusTextForDocumentEnd(currentText:" script/obsidian_ax_editor.swift >/dev/null ||
   ! grep -F "let replacementText = baseText + insertionText" script/obsidian_ax_editor.swift >/dev/null; then
  echo "real app smoke self-test expected Obsidian seeding, reset, and append helpers to use the same guarded disposable text" >&2
  exit 1
fi
if ! grep -F "wait_for_obsidian_long_note_second_suggestion" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "visible viewport beforeChars>=\${min_visible_before_chars}" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Obsidian long-note proof to allow viewport-only CodeMirror AX counts while requiring afterChars=0" >&2
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
long_seed = source.index('obsidian_long_note_text_before_trigger()')
long_seed_tail = source.index("printf 'Smoke proof feel'", long_seed)
long_reset = source.index('reset_obsidian_smoke_note_file "$(obsidian_long_note_text_before_trigger)"', long_seed_tail)
long_caret = source.index('set_obsidian_caret_to_value_end', long_reset)
long_trigger = source.index('type_obsidian_raw_smoke_text "s"', long_caret)
first_long_suffix = source.index('wait_for_obsidian_smoke_note_file_suffix "Smoke proof feels"', long_trigger)
first_suggestion = source.index('wait_for_log_pattern "$start_line" "suggestion-presented .*app=md.obsidian" "Obsidian suggestion"', first_long_suffix)
if not (long_seed < long_seed_tail < long_reset < long_caret < long_trigger < first_long_suffix < first_suggestion):
    raise SystemExit("Obsidian long-note proof must seed the note before the trigger, type only the final live character, verify the disposable file suffix, then wait for the first suggestion")
first_preservation = source.index('assert_obsidian_long_note_file_preserved "Smoke proof feels instant"')
fragment_default = source.index('long_note_second_fragment=" and stays"', first_preservation)
fragment_spacing = source.index('long_note_second_fragment="and stays"', fragment_default)
append = source.index('append_obsidian_smoke_note_file_text "$long_note_second_fragment"', fragment_spacing)
watch = source.index('second_start_line="$(line_count "$LOG_PATH")"', append)
open_note = source.index('open_obsidian_smoke_note_if_configured', watch)
assertion = source.index('wait_for_obsidian_smoke_target_current_value_end "Smoke proof feels instant and stays"', open_note)
expected_chars = source.index('long_note_expected_before_chars="$(obsidian_smoke_note_file_char_count)"', assertion)
branch_end = source.index('\n  else', append)
if not (first_preservation < fragment_default < fragment_spacing < append < watch < open_note < assertion < expected_chars < branch_end):
    raise SystemExit("Obsidian long-note proof must append the second fragment through the disposable note file, start log watching before reopening Obsidian, then AX-assert the visible caret end")
non_long_else = source.index('\n  else', branch_end)
non_long_settle = source.index('settle_obsidian_focus_for_smoke "Obsidian post-accept setup"', non_long_else)
non_long_assert = source.index('assert_obsidian_smoke_target "$first_expected_suffix"', non_long_settle)
non_long_watch = source.index('second_start_line="$(line_count "$LOG_PATH")"', non_long_assert)
non_long_append = source.index('type_obsidian_raw_smoke_text "$second_fragment"', non_long_watch)
non_long_wait = source.index('wait_for_log_pattern "$second_start_line" "suggestion-presented .*app=md.obsidian" "Obsidian second suggestion"', non_long_append)
non_long_full_branch = source.index('\n  else', non_long_wait)
non_long_full_start = source.index('full_start_line="$(line_count "$LOG_PATH")"', non_long_full_branch)
if not (non_long_settle < non_long_assert < non_long_watch < non_long_append < non_long_wait < non_long_full_branch < non_long_full_start):
    raise SystemExit("Obsidian default/theme/pane proof must settle focus, append the second fragment, wait for the second suggestion, and keep the caret at the appended suffix before full accept")
PY

if ! grep -F 'insertionMode: .keyEvents' Sources/AutocompleteLabCore/Configuration/CompatibilityProfile.swift >/dev/null ||
   ! grep -F 'AX values can represent only the visible viewport' Sources/AutocompleteLabCore/Configuration/CompatibilityProfile.swift >/dev/null; then
  echo "real app smoke self-test expected Obsidian to avoid destructive AX value replacement in long notes" >&2
  exit 1
fi

if ! grep -F "insertObsidianSystemEventsPasteText" Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null ||
   ! grep -F 'keystroke "v" using command down' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null; then
  echo "real app smoke self-test expected Obsidian insertion to use the proven paste path instead of raw CGEvents" >&2
  exit 1
fi
if ! grep -F 'usedDocumentEndFallback' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null ||
   ! grep -F '"documentEndFallback": String(usedDocumentEndFallback)' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null ||
   ! grep -F 'Self.postCommandDownKey()' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null; then
  echo "real app smoke self-test expected Obsidian full accept repair to try a document-end fallback before key insertion" >&2
  exit 1
fi
if ! grep -F 'let action: KeyboardAction?' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null ||
   ! grep -F 'action: baseline.action' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null; then
  echo "real app smoke self-test expected insertion verification retries to preserve the original acceptance action" >&2
  exit 1
fi
if ! grep -F 'elif [[ "$manual_app" == "obsidian-markdown-list" ]]; then' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'export AUTOCOMPLETE_LAB_OBSIDIAN_DIRECT_VALUE_INSERT=1' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Obsidian Markdown list proof to use proof-gated direct value insertion" >&2
  exit 1
fi
if ! grep -F 'AUTOCOMPLETE_LAB_OBSIDIAN_DIRECT_VALUE_INSERT=1' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'activeAppProofBundleIdentifiers.contains("md.obsidian")' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null; then
  echo "real app smoke self-test expected Obsidian long-note proof to opt into direct value insertion only under proof mode" >&2
  exit 1
fi

if ! grep -F "assert_obsidian_long_note_file_preserved" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "lost off-screen note content" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Obsidian long-note proof to guard off-screen note preservation" >&2
  exit 1
fi

if ! grep -F 'obsidian_long_note_text_before_trigger()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F "printf 'Smoke proof feel'" script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'first_fragment=""' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'type_obsidian_raw_smoke_text "s"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Obsidian long-note proof to seed the trigger prefix, then type the final trigger character after caret-end repair" >&2
  exit 1
fi

if ! grep -F 'wait_for_frontmost_app "Obsidian" "${AUTOCOMPLETE_LAB_OBSIDIAN_ACTIVATION_WAIT_SECONDS:-5}"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'settle_obsidian_focus_for_smoke()' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Obsidian activation to wait for frontmost focus before proof actions" >&2
  exit 1
fi
if ! grep -F 'application processes whose frontmost is true' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'while IFS= read -r frontmost_identity' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected frontmost checks to handle multiple frontmost System Events processes" >&2
  exit 1
fi
python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
start = source.index("open_obsidian_smoke_note_if_configured()")
end = source.index("\nrun_obsidian()", start)
block = source[start:end]
custom_open = block.index('open "$smoke_uri"')
custom_activate = block.index("activate_obsidian_for_smoke", custom_open)
custom_return = block.index("return 0", custom_activate)
vault_open = block.index("obsidian://open?vault=ObsidianProofVault", custom_return)
vault_activate = block.index("activate_obsidian_for_smoke", vault_open)
vault_return = block.index("return 0", vault_activate)
if not custom_open < custom_activate < custom_return < vault_open < vault_activate < vault_return:
    raise SystemExit(
        "real app smoke self-test expected both Obsidian URI open paths to reactivate Obsidian before returning"
    )
PY

if ! grep -F 'AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT="${AUTOCOMPLETE_LAB_SMOKE_ACCEPT_ALL_SHORTCUT:-optionTab}"' script/obsidian_deep_sweep.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_OBSIDIAN_FOCUS_SETTLE_SECONDS="${AUTOCOMPLETE_LAB_OBSIDIAN_FOCUS_SETTLE_SECONDS:-0.4}"' script/obsidian_deep_sweep.sh >/dev/null; then
  echo "real app smoke self-test expected Obsidian deep sweep to inherit the proven shortcut and focus settle defaults" >&2
  exit 1
fi

if grep -F 'AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR="$lock_dir"' script/obsidian_deep_sweep.sh >/dev/null; then
  echo "real app smoke self-test expected Obsidian deep sweep to use the shared real-app smoke lock" >&2
  exit 1
fi

if ! grep -F "terminate_stale_steadytype_app_bundles" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "stale_steadytype_app_bundle_pids" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected exclusive proof runs to terminate stale SteadyType apps from other worktrees" >&2
  exit 1
fi

python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
append_index = source.index('append_obsidian_smoke_note_file_text "$long_note_second_fragment"')
start_index = source.index('second_start_line="$(line_count "$LOG_PATH")"', append_index)
open_index = source.index('open_obsidian_smoke_note_if_configured', append_index)
wait_index = source.index('wait_for_obsidian_long_note_second_suggestion "$second_start_line"', open_index)
assert_index = source.index('wait_for_obsidian_smoke_target_current_value_end "Smoke proof feels instant and stays"', start_index)
if not append_index < start_index < open_index < assert_index < wait_index:
    raise SystemExit(
        "real app smoke self-test expected Obsidian long-note log watching to start before reopening Obsidian and repair the visible AX caret without stale keyboard events"
    )
if '"beforeChars=$long_note_expected_before_chars"' in source:
    raise SystemExit(
        "real app smoke self-test expected Obsidian long-note proof not to require full-file AX beforeChars"
    )

full_branch = source[source.index('if [[ "$manual_app" == "obsidian-long-note" ]]; then', source.index('wait_for_obsidian_long_note_second_suggestion "$second_start_line"')):]
full_branch = full_branch[:full_branch.index('else')]
try:
    full_start_position = full_branch.index('full_start_line="$(line_count "$LOG_PATH")"')
    press_position = full_branch.index('press_accept_all_shortcut', full_start_position)
    screenshot_position = full_branch.index('wait_for_screenshot_capture_if_enabled "$second_start_line" "md.obsidian" "Obsidian long-note second"', press_position)
except ValueError as error:
    raise SystemExit(
        "real app smoke self-test expected Obsidian long-note proof to press full accept immediately after the second suggestion, then wait for visual proof"
    ) from error
if not (full_start_position < press_position < screenshot_position):
    raise SystemExit(
        "real app smoke self-test expected Obsidian long-note proof to press full accept immediately after the second suggestion, then wait for visual proof"
    )

normal_branch = source[source.index('else', source.index('wait_for_log_pattern "$start_line" "insert-verification .*app=md.obsidian .*result=verified"')):]
normal_branch = normal_branch[:normal_branch.index('fi', normal_branch.index('type_obsidian_raw_smoke_text "$second_fragment"'))]
normal_required = [
    'settle_obsidian_focus_for_smoke "Obsidian post-accept setup"',
    'assert_obsidian_smoke_target "$first_expected_suffix"',
    'elif [[ "$manual_app" == "obsidian-markdown-bold" || "$manual_app" == "obsidian-markdown-list" || "$manual_app" == "obsidian-run-on" ]]; then\n      move_obsidian_caret_to_document_end',
    'second_start_line="$(line_count "$LOG_PATH")"',
    'type_obsidian_raw_smoke_text "$second_fragment"',
    'elif [[ "$manual_app" == "obsidian-markdown-bold" || "$manual_app" == "obsidian-markdown-list" ]]; then\n      set_obsidian_caret_to_value_end\n      move_obsidian_caret_to_document_end',
]
normal_positions = [normal_branch.find(text) for text in normal_required]
if any(position < 0 for position in normal_positions) or normal_positions != sorted(normal_positions):
    raise SystemExit(
        "real app smoke self-test expected Obsidian normal proof to settle focus before second typing"
    )
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

if AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_WAIT_SECONDS=0 \
  AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST=$'123 1 424242 bash ./script/real_app_smoke.sh chrome --fixture textarea\n' \
  AUTOCOMPLETE_LAB_EXCLUSIVE_PROOF_PROTECTED_PGIDS=424242 \
  script/real_app_smoke.sh codex >/dev/null 2>"$TMP_DIR/protected-process.txt"; then
  echo "real app smoke self-test expected Codex to still require --manual-gate" >&2
  exit 1
fi
if grep -F "Another real app smoke process is already active" "$TMP_DIR/protected-process.txt" >/dev/null; then
  echo "real app smoke self-test expected protected proof parent groups not to block child lanes" >&2
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

if AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_WAIT_SECONDS=0 AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST=$'123 1 999 bash ./script/beta_readiness.sh --check-only\n' script/real_app_smoke.sh codex >/dev/null 2>"$TMP_DIR/beta-check-only-process-fail.txt"; then
  :
else
  if grep -F "Another real app smoke process is already active" "$TMP_DIR/beta-check-only-process-fail.txt" >/dev/null; then
    echo "real app smoke self-test expected beta_readiness --check-only not to block a proof refresh" >&2
    exit 1
  fi
fi

if AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_WAIT_SECONDS=0 AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST=$'123 1 999 bash ./script/beta_readiness.sh\n' script/real_app_smoke.sh codex >/dev/null 2>"$TMP_DIR/beta-readiness-process-fail.txt"; then
  echo "real app smoke self-test expected full beta readiness process scan to fail" >&2
  exit 1
fi
if ! grep -F "Another real app smoke process is already active" "$TMP_DIR/beta-readiness-process-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the full beta readiness process scan" >&2
  exit 1
fi

SELF_TEST_PGID="$(ps -o pgid= -p "$$" 2>/dev/null || true)"
SELF_TEST_PGID="${SELF_TEST_PGID//[[:space:]]/}"
if [[ -n "$SELF_TEST_PGID" ]]; then
  if AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_WAIT_SECONDS=0 AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST="123 1 $SELF_TEST_PGID bash ./script/build_and_run.sh --verify"$'\n' script/real_app_smoke.sh codex >/dev/null 2>"$TMP_DIR/same-pgid-build-run-process-fail.txt"; then
    :
  elif grep -F "Another real app smoke process is already active" "$TMP_DIR/same-pgid-build-run-process-fail.txt" >/dev/null; then
    echo "real app smoke self-test expected same-PGID child/sibling process scan to be treated as the active proof, not a competing proof" >&2
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
if ! grep -F "backs it up privately and restores it after the no-submit proof; empty proof composers are cleared" "$TMP_DIR/codex.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Codex draft restore guard" >&2
  exit 1
fi
if ! grep -F '[[ -z "$CODEX_DRAFT_BACKUP_PATH" || ! -f "$CODEX_DRAFT_BACKUP_PATH" ]]' script/real_app_smoke.sh >/dev/null ||
   ! grep -F "Cleared Codex proof composer after proof." script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected empty Codex proof composers to be cleared during cleanup" >&2
  exit 1
fi
if ! grep -F "Proof mode bundle(s): com.openai.codex" "$TMP_DIR/codex.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Codex proof mode bundle" >&2
  exit 1
fi
if ! grep -F "assert_codex_proof_prompt_ready" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Codex proof to read-verify the focused marker composer before Tab" >&2
  exit 1
fi
if ! grep -F "codex_ax_helper seed" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "prompt_app_ax_proof_helper.swift" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "AUTOCOMPLETE_LAB_CODEX_COMPOSER_DISCOVERY_TIMEOUT_SECONDS" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Codex proof to use the shared hardened prompt AX helper" >&2
  exit 1
fi
if ! grep -F "maxDepth: 12" Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null; then
  echo "real app smoke self-test expected Codex proof acceptance to search the focused text-area subtree" >&2
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
if ! awk '/run_codex\(\)/ { in_smoke = 1 } /^}/ && in_smoke { in_smoke = 0 } in_smoke && /press_key_code_cgevent 48/ { found = 1 } END { exit found ? 0 : 1 }' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Codex proof to press Tab through CGEvent session events" >&2
  exit 1
fi
if ! grep -F 'ensure_cgevent_keypress_helper()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'cgevent_keypress_helper_path()' script/real_app_smoke.sh >/dev/null ||
   ! awk '/run_codex\(\)/ { in_smoke = 1 } /^}/ && in_smoke { in_smoke = 0 } in_smoke && /ensure_cgevent_keypress_helper/ { found = 1 } END { exit found ? 0 : 1 }' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Codex proof to warm the CGEvent keypress helper before showing a suggestion" >&2
  exit 1
fi

script/real_app_smoke.sh codex-full-accept --dry-run >"$TMP_DIR/codex-full-accept.txt"
if ! grep -F "Codex prompt full-accept no-submit proof" "$TMP_DIR/codex-full-accept.txt" >/dev/null ||
   ! grep -F "runtime scenario codex-full-accept-no-submit" "$TMP_DIR/codex-full-accept.txt" >/dev/null ||
   ! grep -F "never presses Enter" "$TMP_DIR/codex-full-accept.txt" >/dev/null ||
   ! grep -F "prompt full-accept no-submit gate on the same trace slice" "$TMP_DIR/codex-full-accept.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Codex full-accept no-submit proof lane" >&2
  exit 1
fi
if script/real_app_smoke.sh codex-full-accept --skip-build --dry-run >"$TMP_DIR/codex-full-accept-skip-build.txt" 2>&1; then
  echo "real app smoke self-test expected Codex full accept proof to reject --skip-build" >&2
  exit 1
fi
if ! grep -F "must relaunch with the codex-full-accept-no-submit proof scenario" "$TMP_DIR/codex-full-accept-skip-build.txt" >/dev/null; then
  echo "real app smoke self-test did not explain Codex full accept --skip-build rejection" >&2
  exit 1
fi
if ! awk '/run_codex_full_accept\(\)/ { in_smoke = 1 } /^}/ && in_smoke { in_smoke = 0 } in_smoke && /prepare_codex_full_accept_runtime_options/ { found = 1 } END { exit found ? 0 : 1 }' script/real_app_smoke.sh ||
   ! awk '/run_codex_full_accept\(\)/ { in_smoke = 1 } /^}/ && in_smoke { in_smoke = 0 } in_smoke && /press_accept_all_shortcut/ { found = 1 } END { exit found ? 0 : 1 }' script/real_app_smoke.sh ||
   ! awk '/run_codex_full_accept\(\)/ { in_smoke = 1 } /^}/ && in_smoke { in_smoke = 0 } in_smoke && /manual_smoke_session.sh codex-full-accept/ { found = 1 } END { exit found ? 0 : 1 }' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Codex full accept proof to set the proof scenario, press accept-all, and run the full-accept validator" >&2
  exit 1
fi
python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
start = source.index("run_codex()")
end = source.index("run_claude_code_terminal_host_smoke()", start)
block = source[start:end]
if block.index("focus_codex_proof_prompt") > block.index('wait_for_log_pattern "$start_line" "suggestion-presented .*app=com.openai.codex"'):
    raise SystemExit("Codex proof must focus the marker composer before waiting for the visible suggestion")
after_visible = block.split('wait_for_log_pattern "$start_line" "suggestion-presented .*app=com.openai.codex"', 1)[1]
before_tab = after_visible.split("press_key_code_cgevent 48", 1)[0]
if "focus_codex_proof_prompt" in before_tab or "assert_codex_proof_prompt_ready" in before_tab:
    raise SystemExit("Codex proof must not refocus the composer after the suggestion is visible")
PY

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
if ! grep -F 'proof_text="${AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_TEXT:-Make this setting $marker the feature con}"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Claude Code default proof text to keep the marker near the caret" >&2
  exit 1
fi
if ! grep -F 'claude_code_terminal_smoke_input_text()' script/real_app_smoke.sh >/dev/null ||
   ! awk '/claude_code_terminal_smoke_input_text\(\)/ { in_fn = 1 } /^}/ && in_fn { in_fn = 0 } in_fn && /claude_code_smoke_proof_text/ { found = 1 } END { exit found ? 0 : 1 }' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Terminal-host Claude Code proof to keep the inline marker in the typed prompt" >&2
  exit 1
fi
if ! grep -F 'claude_code_terminal_smoke_input_texts()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_PROOF_TEXTS' script/real_app_smoke.sh >/dev/null ||
   ! grep -F '$marker Make this setting the feature' script/real_app_smoke.sh >/dev/null ||
   ! grep -F '$marker Please make this' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_MAX_ATTEMPTS' script/real_app_smoke.sh >/dev/null ||
   ! grep -F '${CLAUDE_CODE_TERMINAL_PROOF_TITLE:-}' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'wait_for_claude_code_terminal_suggestion_line_optional' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'fieldKindReason=claude-code-terminal-host-proof' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'source=terminal-screen-prompt' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'find_claude_code_terminal_suggestion_line_optional' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'find_recent_claude_code_terminal_suggestion_line_optional' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'awk \' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'NR <= start' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'is_terminal_proof_suggestion == 0' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'saw_terminal_screen_prompt == 0' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'print NR' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_RECENT_SUGGESTION_SCAN_LINES' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'suggestion_start_line="$(line_count "$LOG_PATH")"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'pre_trigger_suggestion_start_line="$suggestion_start_line"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'find_claude_code_terminal_suggestion_line_optional "$pre_trigger_suggestion_start_line"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'find_recent_claude_code_terminal_suggestion_line_optional "$start_line"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'accept_start_line="$pre_trigger_suggestion_start_line"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'accept_start_line="$start_line"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'guard_ghostty_frontmost_bundle_fallback' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'frontmost_bundle_identifier()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F '"$frontmost_bundle" == "$host_bundle"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'frontmost_claude_code_terminal_host_app_is_active "$frontmost_pid"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'frontmost_claude_code_terminal_proof_pid_matches "$frontmost_pid"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'wait_for_log_line_number_optional \' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'suggestion-presented .*app=com.anthropic.claude-code .*fieldKindReason=claude-code-terminal-host-proof .*fieldKindSuppressed=false .*placementAnchorSource=synthetic-caret' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'placementAnchorSource=synthetic-caret' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'produced no visible suggestion; launching a fresh disposable context' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Terminal-host Claude Code proof to retry disposable title-scoped contexts with Ghostty frontmost fallback and field-scoped prompt-row suggestion detection after typed prompt readiness, including still-visible Ghostty prefix suggestions" >&2
  exit 1
fi
if grep -F 'AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_MIN_PROMPT_ANCHOR_Y' script/real_app_smoke.sh >/dev/null ||
   grep -F 'ghostty_suggestion_line_has_prompt_row_anchor' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Ghostty proof to require app-proven terminal-screen-prompt evidence instead of low-y prompt-row heuristics" >&2
  exit 1
fi
if ! python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
start = source.index("frontmost_claude_code_terminal_host_app_is_active()")
end = source.index("\nguard_ghostty_frontmost_bundle_fallback()", start)
block = source[start:end]
expected_order = [
    'host_bundle="$(claude_code_host_bundle_id)"',
    'frontmost_bundle="$(frontmost_bundle_identifier 2>/dev/null || true)"',
    'frontmost_bundle" == "$host_bundle"',
    'host_process="$(claude_code_host_process_name)"',
]
position = -1
for expected in expected_order:
    next_position = block.find(expected, position + 1)
    if next_position == -1:
        raise SystemExit(1)
    position = next_position
PY
then
  echo "real app smoke self-test expected Ghostty frontmost fallback to trust bundle id before process-name matching" >&2
  exit 1
fi
if ! awk '
  /wait_for_claude_code_terminal_suggestion_line_optional\(\)/ { in_helper = 1 }
  /^}/ && in_helper { in_helper = 0 }
  in_helper && /find_claude_code_terminal_suggestion_line_optional "\$start_line"/ { found = 1 }
  END { exit found ? 0 : 1 }
' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Claude Code terminal-host suggestion wait to use indexed historical log scanning" >&2
  exit 1
fi
if ! python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
start = source.index("find_recent_claude_code_terminal_suggestion_line_optional()")
end = source.index("\nwait_for_claude_code_terminal_suggestion_line_optional()", start)
block = source[start:end]
for expected in (
    '[[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]',
    'recent_start_line="$preferred_start_line"',
    'absolute_line = NR + start',
    'candidate = absolute_line',
    'suggestion-hidden',
    'keyboard-action',
    'insert ',
    'screen-geometry-changed',
    'workspace-focus-changed app=com.apple.Terminal',
    'MATCHED_LOG_LINE="$matched_line"',
):
    if expected not in block:
        raise SystemExit(1)
if block.index('[[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]') > block.index('recent_start_line >= preferred_start_line'):
    raise SystemExit(1)
if "\n      ' \"$LOG_PATH\"" in block:
    raise SystemExit(1)
PY
then
  echo "real app smoke self-test expected Ghostty suggestion proof to bridge only still-visible prompt-row suggestions" >&2
  exit 1
fi
if ! python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
start = source.index("find_claude_code_terminal_suggestion_line_optional()")
end = source.index("\nfind_recent_claude_code_terminal_suggestion_line_optional()", start)
block = source[start:end]
for expected in (
    'candidate = absolute_line',
    'suggestion-hidden',
    'keyboard-action',
    'insert ',
    'screen-geometry-changed',
    'workspace-focus-changed app=com.apple.Terminal',
    'if (candidate != "" && clear_candidate)',
):
    if expected not in block:
        raise SystemExit(1)
if 'print absolute_line\\n        exit' in block:
    raise SystemExit(1)
PY
then
  echo "real app smoke self-test expected primary Ghostty suggestion scan to reject prompt-row suggestions invalidated later in the same log slice" >&2
  exit 1
fi
if ! grep -F 'found prompt-row suggestion at diagnostics line' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Claude Code terminal proof to print the matched prompt-row suggestion line" >&2
  exit 1
fi
if ! grep -F 'CLAUDE_CODE_TERMINAL_TYPING_TRIGGER_LINE="$(line_count "$LOG_PATH")"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'wait_for_claude_code_terminal_proof_suggestion_ready_optional()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'wait_for_claude_code_terminal_log_flush_suggestion_line_optional()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'print_claude_code_terminal_suggestion_diagnostics_tail()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'suggestion_start_line="$pre_trigger_suggestion_start_line"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Ghostty proof to start suggestion discovery from the pre-trigger prompt window and report late diagnostics" >&2
  exit 1
fi
if ! python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
start = source.index("run_claude_code_terminal_host_smoke()")
end = source.index("\nrun_codex_model_latency()", start)
block = source[start:end]
expected_order = [
    'pre_trigger_suggestion_start_line="$suggestion_start_line"',
    'type_claude_code_terminal_smoke_text "$proof_text"',
    'suggestion_start_line="$pre_trigger_suggestion_start_line"',
    'wait_for_claude_code_terminal_proof_suggestion_ready_optional',
    'primary suggestion wait ended; allowing diagnostics flush grace',
    'wait_for_claude_code_terminal_log_flush_suggestion_line_optional',
    'find_claude_code_terminal_suggestion_line_optional "$pre_trigger_suggestion_start_line"',
    'accept_start_line="$pre_trigger_suggestion_start_line"',
    'print_claude_code_terminal_suggestion_diagnostics_tail "$suggestion_start_line"',
]
position = -1
for expected in expected_order:
    next_position = block.find(expected, position + 1)
    if next_position == -1:
        raise SystemExit(1)
    position = next_position
PY
then
  echo "real app smoke self-test expected Ghostty proof to wait from the app-proven pre-trigger prompt window, allow log flush grace, and keep same-line fallback evidence" >&2
  exit 1
fi
if ! python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
start = source.index("wait_for_claude_code_terminal_proof_suggestion_ready_optional()")
end = source.index("\nwait_for_log_fields()", start)
block = source[start:end]
if '"$CLAUDE_CODE_HOST_VARIANT" == "ghostty"' not in block:
    raise SystemExit(1)
if block.index('"$CLAUDE_CODE_HOST_VARIANT" == "ghostty"') > block.index("wait_for_log_line_number_optional"):
    raise SystemExit(1)
if 'print lines[i] > "/dev/stderr"' in block:
    raise SystemExit(1)
if '\' "$LOG_PATH" >&2 2>/dev/null || true' not in block:
    raise SystemExit(1)
PY
then
  echo "real app smoke self-test expected Ghostty proof to avoid the generic suggestion fallback and preserve diagnostics-tail output" >&2
  exit 1
fi
if ! python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
start = source.index("log_since_has_fields()")
end = source.index("\nclaude_code_terminal_suggestion_cancelled_by_screen_geometry()", start)
block = source[start:end]
if 'sed -n "$((start_line + 1)),\\$p" "$LOG_PATH"' not in block:
    raise SystemExit(1)
if 'awk -v prefix="$prefix"' not in block:
    raise SystemExit(1)
if 'tail -n +' in block:
    raise SystemExit(1)
if 'NR > start' in block:
    raise SystemExit(1)
PY
then
  echo "real app smoke self-test expected log field scans to use fast bounded log slices instead of full-file or future-line scans" >&2
  exit 1
fi
cat >"$TMP_DIR/ghostty-recent-suggestion.log" <<'EOF'
2026-05-27T00:00:00Z synthetic-caret app=com.anthropic.claude-code beforeChars=84 caret=x=130,y=868,w=0,h=22 source=terminal-screen-prompt
2026-05-27T00:00:00Z suggestion-presented afterChars=0 anchorRect=x=130,y=868,w=0,h=22 app=com.anthropic.claude-code beforeChars=84 fieldKindReason=claude-code-terminal-host-proof fieldKindSuppressed=false placementAnchorSource=synthetic-caret visibleWords=3
2026-05-27T00:00:01Z status accessibility=AX ok app=Ghostty decision=Shown
EOF
if ! awk -v start="0" '
  NR <= start { next }
  {
    is_terminal_proof_suggestion = index($0, "suggestion-presented") && index($0, "app=com.anthropic.claude-code") && index($0, "fieldKindReason=claude-code-terminal-host-proof") && index($0, "fieldKindSuppressed=false") && index($0, "placementAnchorSource=synthetic-caret")
  }
  index($0, "synthetic-caret") && index($0, "app=com.anthropic.claude-code") && index($0, "source=terminal-screen-prompt") {
    saw_terminal_screen_prompt = 1
  }
  is_terminal_proof_suggestion != 0 {
    if (saw_terminal_screen_prompt == 0) {
      next
    }
    candidate = NR
    next
  }
  {
    clear_candidate = 0
    if (index($0, "suggestion-hidden") && index($0, "app=com.anthropic.claude-code")) {
      clear_candidate = 1
    }
    if (index($0, "keyboard-action") && index($0, "app=com.anthropic.claude-code")) {
      clear_candidate = 1
    }
    if (index($0, "insert ") && index($0, "app=com.anthropic.claude-code")) {
      clear_candidate = 1
    }
    if (index($0, "screen-geometry-changed")) {
      clear_candidate = 1
    }
    if (index($0, "workspace-focus-changed app=com.apple.Terminal")) {
      clear_candidate = 1
    }
    if (candidate != "" && clear_candidate) {
      candidate = ""
    }
  }
  END {
    if (candidate != "") {
      print candidate
    }
  }
' "$TMP_DIR/ghostty-recent-suggestion.log" | grep -Fx "2" >/dev/null; then
  echo "real app smoke self-test expected Ghostty recent-suggestion bridge awk to select a live prompt-row suggestion" >&2
  exit 1
fi
cat >"$TMP_DIR/ghostty-primary-hidden-suggestion.log" <<'EOF'
2026-05-27T00:00:00Z synthetic-caret app=com.anthropic.claude-code beforeChars=42 caret=x=130,y=868,w=0,h=22 source=terminal-screen-prompt
2026-05-27T00:00:00Z suggestion-presented afterChars=0 anchorRect=x=130,y=868,w=0,h=22 app=com.anthropic.claude-code beforeChars=42 fieldKindReason=claude-code-terminal-host-proof fieldKindSuppressed=false placementAnchorSource=synthetic-caret visibleWords=8
2026-05-27T00:00:07Z suggestion-hidden afterChars=0 app=com.anthropic.claude-code beforeChars=42 reason=placement-detached-suggestion-disabled
EOF
if awk -v start="0" -v host_variant="ghostty" '
  {
    absolute_line = NR + start
    is_prompt_caret = index($0, "synthetic-caret") && index($0, "app=com.anthropic.claude-code") && index($0, "source=terminal-screen-prompt")
    is_terminal_proof_suggestion = index($0, "suggestion-presented") && index($0, "app=com.anthropic.claude-code") && index($0, "fieldKindReason=claude-code-terminal-host-proof") && index($0, "fieldKindSuppressed=false") && index($0, "placementAnchorSource=synthetic-caret")
  }
  is_prompt_caret != 0 {
    saw_terminal_screen_prompt = 1
  }
  {
    clear_candidate = 0
    if (index($0, "suggestion-hidden") && index($0, "app=com.anthropic.claude-code")) {
      clear_candidate = 1
    }
    if (index($0, "keyboard-action") && index($0, "app=com.anthropic.claude-code")) {
      clear_candidate = 1
    }
    if (index($0, "insert ") && index($0, "app=com.anthropic.claude-code")) {
      clear_candidate = 1
    }
    if (index($0, "screen-geometry-changed")) {
      clear_candidate = 1
    }
    if (index($0, "workspace-focus-changed app=com.apple.Terminal")) {
      clear_candidate = 1
    }
    if (candidate != "" && clear_candidate) {
      candidate = ""
    }
  }
  is_terminal_proof_suggestion == 0 {
    next
  }
  (host_variant == "ghostty") && (saw_terminal_screen_prompt == 0) {
    next
  }
  {
    candidate = absolute_line
    next
  }
  END {
    if (candidate != "") {
      print candidate
    }
  }
' "$TMP_DIR/ghostty-primary-hidden-suggestion.log" | grep -q .; then
  echo "real app smoke self-test expected primary Ghostty suggestion scan to reject a prompt-row suggestion hidden later in the same log slice" >&2
  exit 1
fi
cat >"$TMP_DIR/ghostty-recent-low-y-live-suggestion.log" <<'EOF'
2026-05-27T00:00:00Z suggestion-presented afterChars=0 anchorRect=x=389,y=74,w=0,h=20 app=com.anthropic.claude-code beforeChars=42 fieldKindReason=claude-code-terminal-host-proof fieldKindSuppressed=false partialWordCharacters=7 placementAnchorSource=synthetic-caret visibleWords=8
2026-05-27T00:00:01Z status accessibility=AX ok app=Ghostty decision=Shown
EOF
if awk -v start="0" '
  NR <= start { next }
  {
    is_terminal_proof_suggestion = index($0, "suggestion-presented") && index($0, "app=com.anthropic.claude-code") && index($0, "fieldKindReason=claude-code-terminal-host-proof") && index($0, "fieldKindSuppressed=false") && index($0, "placementAnchorSource=synthetic-caret")
  }
  index($0, "synthetic-caret") && index($0, "app=com.anthropic.claude-code") && index($0, "source=terminal-screen-prompt") {
    saw_terminal_screen_prompt = 1
  }
  is_terminal_proof_suggestion != 0 {
    if (saw_terminal_screen_prompt == 0) {
      next
    }
    candidate = NR
    next
  }
  END {
    if (candidate != "") {
      print candidate
    }
  }
' "$TMP_DIR/ghostty-recent-low-y-live-suggestion.log" | grep -q .; then
  echo "real app smoke self-test expected Ghostty recent-suggestion bridge awk to reject low-y header suggestions without terminal-screen-prompt proof" >&2
  exit 1
fi
if ! grep -F 'prepare_claude_code_terminal_suggestion_for_hot_accept' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'try_wait_for_frontmost_claude_code_terminal_proof_process' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'reactivating the disposable host process for the hot accept' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'settle_claude_code_terminal_proof_focus' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'open_fresh_claude_code_terminal_proof_context "$host_name" "$marker"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'reason=focus-changed' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'key=escape' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'reason=escape' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'suggestion is no longer visible before Tab; refreshing the disposable prompt' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_REFOCUS_SUGGESTION_WAIT_SECONDS' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'lost its visible suggestion before Tab; launching a fresh disposable context' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'lost its visible suggestion during Tab refocus; launching a fresh disposable context' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Terminal-host Claude Code proof to recover from focus-changed hidden suggestions by launching a fresh disposable host process before Tab" >&2
  exit 1
fi
if ! grep -F 'claude_code_terminal_suggestion_cancelled_by_screen_geometry()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'CLAUDE_CODE_TERMINAL_SUGGESTION_WAIT_CANCELLED_BY_GEOMETRY=1' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'suggestion-request-cancelled" "reason=invalidate"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'screen-geometry-changed" "geometryInvalidationReason=screen-layout-changed"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'pending suggestion invalidated by screen geometry; nudging the same prompt' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'type_claude_code_terminal_smoke_text " "' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Terminal-host Claude Code proof to recover from screen-geometry cancellation with one safe prompt nudge" >&2
  exit 1
fi
if ! grep -F 'press_key_code_cgevent()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'press_key_code_cgevent 48' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'steadytype-cgevent-keypress-v4' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'CGEventSource(stateID: .hidSystemState)' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'let tapArgument = CommandLine.arguments.count == 3 ? CommandLine.arguments[2] : "hid"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'tap = .cgSessionEventTap' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'helper is not warm; refusing to compile on the hot accept path.' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'keyDown.flags = []' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'keyUp.flags = []' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Terminal-host Claude Code proof to press Tab through fresh CGEvents with HID and session tap support" >&2
  exit 1
fi
if ! grep -F 'warm_claude_code_terminal_hot_accept_helpers()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'Claude Code $host_name proof warming CGEvent Tab helper before prompt suggestions.' script/real_app_smoke.sh >/dev/null ||
   ! awk '/run_claude_code_terminal_host_smoke\(\)/ { in_smoke = 1 } /^}/ && in_smoke { in_smoke = 0 } in_smoke && /wait_for_runtime_ready/ { saw_runtime = 1 } in_smoke && saw_runtime && /warm_claude_code_terminal_hot_accept_helpers "\$host_name"/ { saw_warm = 1 } in_smoke && saw_warm && /cleanup_stale_claude_code_terminal_proofs/ { found = 1 } END { exit found ? 0 : 1 }' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Ghostty proof to precompile the CGEvent Tab helper before any visible suggestion can go stale" >&2
  exit 1
fi
if ! grep -F 'type_text_cgevent()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'steadytype-cgevent-text-v1' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'keyboardSetUnicodeString' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'CGEventSource(stateID: .hidSystemState)' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Ghostty proof typing to post Unicode text through fresh HID CGEvents" >&2
  exit 1
fi
if ! grep -F 'press_claude_code_terminal_host_tab()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'Claude Code terminal host is not frontmost for proof Tab.' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'Claude Code terminal host is not frontmost for fallback proof Tab.' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'CGEvent Tab produced no key=tab diagnostic; retrying with System Events Tab' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_TAB_PROBE_SECONDS' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_CGEVENT_TAB_TIMEOUT_SECONDS' script/real_app_smoke.sh >/dev/null ||
   ! grep -F '"session"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F '"warm"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'suggestion hid before fallback Tab; refreshing the disposable prompt' script/real_app_smoke.sh >/dev/null ||
   ! awk '/press_claude_code_terminal_host_tab\(\)/ { in_fn = 1 } /^}/ && in_fn { in_fn = 0 } in_fn && /press_key_code_cgevent_with_timeout/ { found = 1 } END { exit found ? 0 : 1 }' script/real_app_smoke.sh ||
   ! awk '/press_claude_code_terminal_host_tab\(\)/ { in_fn = 1 } /^}/ && in_fn { in_fn = 0 } in_fn && /wait_for_log_fields_optional/ { saw_probe = 1 } in_fn && saw_probe && /key code 48/ { found = 1 } END { exit found ? 0 : 1 }' script/real_app_smoke.sh ||
   ! awk '/run_claude_code_terminal_host_smoke\(\)/ { in_smoke = 1 } /^}/ && in_smoke { in_smoke = 0 } in_smoke && /CLAUDE_CODE_HOST_VARIANT.*ghostty/ { saw_ghostty = 1 } in_smoke && saw_ghostty && /press_claude_code_terminal_host_tab/ { found = 1 } END { exit found ? 0 : 1 }' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Ghostty-host Claude Code proof to verify the focused terminal host before pressing CGEvent Tab, then fall back to guarded System Events Tab only when no key=tab diagnostic appears" >&2
  exit 1
fi
if ! grep -F "automated Terminal-host Claude Code proof" "$TMP_DIR/claude-code-terminal.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the automated Terminal-host Claude Code proof" >&2
  exit 1
fi
script/real_app_smoke.sh claude-code-iterm2 --dry-run >"$TMP_DIR/claude-code-iterm2.txt"
if ! grep -F "Claude Code host: iTerm2 (com.googlecode.iterm2)" "$TMP_DIR/claude-code-iterm2.txt" >/dev/null; then
  echo "real app smoke self-test did not parse the Claude Code iTerm2 alias" >&2
  exit 1
fi
if ! grep -F "automated iTerm2-host Claude Code proof" "$TMP_DIR/claude-code-iterm2.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the automated iTerm2-host Claude Code proof" >&2
  exit 1
fi
script/real_app_smoke.sh claude-code-ghostty --dry-run >"$TMP_DIR/claude-code-ghostty.txt"
if ! grep -F "Claude Code host: Ghostty (com.mitchellh.ghostty)" "$TMP_DIR/claude-code-ghostty.txt" >/dev/null; then
  echo "real app smoke self-test did not parse the Claude Code Ghostty alias" >&2
  exit 1
fi
if ! grep -F "automated Ghostty-host Claude Code proof" "$TMP_DIR/claude-code-ghostty.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the automated Ghostty-host Claude Code proof" >&2
  exit 1
fi
if ! grep -F "run_claude_code_terminal_host_smoke" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF_MARKER_CONFIRMED=1" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Terminal-host Claude Code to automate proof and confirm the no-submit marker" >&2
  exit 1
fi

script/real_app_smoke.sh claude-code-model-latency --dry-run >"$TMP_DIR/claude-code-model-latency.txt"
if ! grep -F "terminal-host Claude Code model latency proof" "$TMP_DIR/claude-code-model-latency.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Claude Code model latency proof lane" >&2
  exit 1
fi
if ! grep -F "scenario claude-code-model-latency" "$TMP_DIR/claude-code-model-latency.txt" >/dev/null; then
  echo "real app smoke self-test did not label the Claude Code model latency proof scenario" >&2
  exit 1
fi
if ! grep -F "never presses Tab, Enter, or full accept" "$TMP_DIR/claude-code-model-latency.txt" >/dev/null; then
  echo "real app smoke self-test did not state the Claude Code model latency no-submit key guard" >&2
  exit 1
fi
if ! grep -F "model-backed visible suggestions without submitting" "$TMP_DIR/claude-code-model-latency.txt" >/dev/null; then
  echo "real app smoke self-test did not state the Claude Code model latency proof target" >&2
  exit 1
fi
if ! grep -F "fresh title-marked disposable Terminal Claude Code prompt per sample" "$TMP_DIR/claude-code-model-latency.txt" >/dev/null; then
  echo "real app smoke self-test did not state the Claude Code model latency fresh-prompt sampling plan" >&2
  exit 1
fi
if ! grep -F "Claude Code host: Terminal (com.apple.Terminal)" "$TMP_DIR/claude-code-model-latency.txt" >/dev/null; then
  echo "real app smoke self-test expected Claude Code model latency to pin Terminal" >&2
  exit 1
fi
if ! grep -F 'Claude Code model latency sample $sample_index must include $marker' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Claude Code model latency samples to carry the current-line proof marker" >&2
  exit 1
fi
if ! grep -F "model-backed visible suggestion during the typed sample window" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Claude Code model latency to count model-backed suggestions from the typed sample window" >&2
  exit 1
fi
if ! grep -F 'expected_before_chars="${#expected_user_text}"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F '"beforeChars=$expected_before_chars"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F '"partialWordCharacters=${#trigger_text}"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Claude Code model latency to match the exact typed sample shape" >&2
  exit 1
fi
if ! grep -F "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEAR_DELAY_SECONDS" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Claude Code Terminal prompt clearing to expose a settle knob" >&2
  exit 1
fi
if ! grep -F "AUTOCOMPLETE_LAB_CLAUDE_CODE_MODEL_LATENCY_SUGGESTION_WAIT_SECONDS" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Claude Code model latency to expose a suggestion wait knob" >&2
  exit 1
fi
if ! grep -F "AUTOCOMPLETE_LAB_CLAUDE_CODE_MODEL_LATENCY_FRESH_PROMPT_PER_SAMPLE" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Claude Code model latency to expose fresh-prompt sampling control" >&2
  exit 1
fi
if ! grep -F "cleanup_stale_claude_code_terminal_proofs" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEANUP_SETTLE_SECONDS" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEANUP_TIMEOUT_SECONDS" script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'run_osascript_with_timeout \' script/real_app_smoke.sh >/dev/null ||
   ! grep -F '"Claude Code terminal stale proof cleanup"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F "make_claude_code_terminal_proof_dir" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "steadytype-claude-code-proof" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_CLEANUP_LEGACY_TMP_WINDOWS" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "kill -KILL" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Claude Code model latency to clean up stale proof Terminal windows without hanging on AppleScript" >&2
  exit 1
fi
if ! python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
start = source.index("cleanup_stale_claude_code_terminal_proofs()")
end = source.index("\nopen_fresh_claude_code_terminal_proof_context()", start)
block = source[start:end]
for expected in (
    'cleanup_host_bundle="$(claude_code_host_bundle_id)"',
    'AUTOCOMPLETE_LAB_CLAUDE_CODE_CLEANUP_HOST_BUNDLE="$cleanup_host_bundle"',
    'set targetHostBundle to system attribute "AUTOCOMPLETE_LAB_CLAUDE_CODE_CLEANUP_HOST_BUNDLE"',
    'if targetHostBundle is "auto" or terminalBundle is targetHostBundle then',
):
    if expected not in block:
        raise SystemExit(1)
if 'CLAUDE_CODE_HOST_VARIANT" == "ghostty"' not in block or 'cleanup_legacy_tmp_windows=0' not in block:
    raise SystemExit(1)
PY
then
  echo "real app smoke self-test expected Ghostty stale proof cleanup to avoid killing the detached Terminal runner" >&2
  exit 1
fi
if ! python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
start = source.index("clear_claude_code_terminal_prompt_line()")
end = source.index("\npress_claude_code_terminal_host_tab()", start)
block = source[start:end]
for expected in (
    'keystroke "k" using command down',
    'keystroke "l" using control down',
    'key code 53',
):
    if expected not in block:
        raise SystemExit(1)
ghostty_start = block.index('if [[ "$CLAUDE_CODE_HOST_VARIANT" == "ghostty" ]]')
ghostty_end = block.index("\n  fi\n\n  AUTOCOMPLETE_LAB_CLAUDE_CODE_HOST_BUNDLE", ghostty_start)
ghostty_block = block[ghostty_start:ghostty_end]
if 'keystroke "u" using control down' not in ghostty_block:
    raise SystemExit(1)
if 'sleep "$(claude_code_ghostty_event_drain_seconds)"' not in ghostty_block:
    raise SystemExit(1)
if "key code 53" in ghostty_block:
    raise SystemExit(1)
if 'send key "u" action press modifiers "control"' in ghostty_block:
    raise SystemExit(1)
for forbidden in ("key code 36", "key code 48", "keystroke return", "keystroke tab"):
    if forbidden in block:
        raise SystemExit(1)
PY
then
  echo "real app smoke self-test expected Claude Code prompt clearing to keep Terminal clear keys while avoiding Escape for Ghostty and never pressing Enter or Tab" >&2
  exit 1
fi
if awk '/wait_for_claude_code_terminal_prompt\(\)/ { in_wait = 1 } /assert_claude_code_terminal_prompt_ready\(\)/ { in_wait = 0 } in_wait && /--hint "❯"/ { found = 1 } END { exit found ? 0 : 1 }' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Claude Code prompt readiness to require Claude-specific chrome, not a generic prompt glyph" >&2
  exit 1
fi
if awk '/wait_for_claude_code_terminal_prompt\(\)/ { in_wait = 1 } /assert_claude_code_terminal_prompt_ready\(\)/ { in_wait = 0 } in_wait && /--hint / { found = 1 } END { exit found ? 0 : 1 }' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Claude Code prompt readiness to use process proof instead of brittle placeholder hints" >&2
  exit 1
fi
if ! awk '/wait_for_claude_code_terminal_prompt\(\)/ { in_wait = 1 } /assert_claude_code_terminal_prompt_ready\(\)/ { in_wait = 0 } in_wait && /wait_for_claude_code_terminal_process/ { found = 1 } END { exit found ? 0 : 1 }' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Claude Code prompt readiness to wait for the launched claude process" >&2
  exit 1
fi
if ! awk '
  /wait_for_claude_code_terminal_prompt\(\)/ { in_wait = 1; saw_hosts = 0 }
  /assert_claude_code_terminal_prompt_ready\(\)/ { in_wait = 0 }
  in_wait && /terminal\|iterm2\|ghostty/ { saw_hosts = 1 }
  in_wait && saw_hosts && /swift script\/terminal_prompt_ax_proof_helper.swift wait/ { found = 1 }
  END { exit found ? 0 : 1 }
' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Terminal, iTerm2, and Ghostty prompt readiness to use the AX proof helper" >&2
  exit 1
fi
if ! awk '/wait_for_claude_code_terminal_prompt\(\)/ { in_wait = 1 } /assert_claude_code_terminal_prompt_ready\(\)/ { in_wait = 0 } in_wait && /--allow-missing-marker-for-empty-text/ { found = 1 } END { exit found ? 0 : 1 }' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Ghostty empty-prompt readiness to allow missing title marker before typed proof text is asserted" >&2
  exit 1
fi
if ! grep -F "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_PROMPT_SETTLE_SECONDS" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Claude Code prompt readiness to settle before typing samples" >&2
  exit 1
fi
if ! grep -F 'claude_code_terminal_proof_primary_pid' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'proof_pid_args=(--pid "$proof_pid")' script/real_app_smoke.sh >/dev/null ||
   ! grep -F '"${proof_pid_args[@]}"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Claude Code prompt AX helper calls to target the disposable terminal pid" >&2
  exit 1
fi
if awk '/assert_claude_code_terminal_prompt_ready\(\)/ { in_assert = 1 } /assert_claude_code_terminal_prompt_retains_marker\(\)/ { in_assert = 0 } in_assert && /claude_code_terminal_ax_helper wait/ { found = 1 } END { exit found ? 0 : 1 }' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected typed Claude Code prompt text checks not to require placeholder hints" >&2
  exit 1
fi
if ! grep -F 'claude_code_terminal_text_wait_seconds()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_TEXT_WAIT_SECONDS' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'wait_seconds="12"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F -- '--discovery-timeout "$(claude_code_terminal_text_wait_seconds)"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Ghostty typed prompt readiness to use a longer host-specific AX wait" >&2
  exit 1
fi
if ! grep -F 'claude_code_terminal_accept_wait_seconds()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_ACCEPT_WAIT_SECONDS' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'wait_seconds="${AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_ACCEPT_WAIT_SECONDS:-90}"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F '"$(claude_code_terminal_accept_wait_seconds)"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Ghostty Tab acceptance to wait for the full verified insertion ladder" >&2
  exit 1
fi
if ! grep -F "CLAUDE_CODE_TERMINAL_PROOF_PIDS" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "CLAUDE_CODE_TERMINAL_PROOF_PROCESS_PID_FILE" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "CLAUDE_CODE_TERMINAL_PROOF_PROCESS_EXIT_FILE" script/real_app_smoke.sh >/dev/null ||
   ! grep -F '"$proof_dir/claude.pid"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'head -n 1 "$CLAUDE_CODE_TERMINAL_PROOF_PROCESS_PID_FILE"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F "process_tree_contains_name" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Claude Code Terminal proof cleanup/readiness to track the disposable Claude process" >&2
  exit 1
fi
if ! grep -F 'set proofWindow to new window' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'input text launchCommand to targetTerminal' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'send key "enter" to targetTerminal' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'CLAUDE_CODE_TERMINAL_PROOF_OWNS_HOST_PROCESS=0' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Ghostty proof launch to create a script-owned disposable shell window without killing the user's Ghostty process" >&2
  exit 1
fi
if ! grep -F "steadytype-claude-code-proof.command" script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'open -na "$host_app" "$launch_script"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F "ghostty_launch_command" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Claude Code terminal-host launch to use disposable command files" >&2
  exit 1
fi
if ! grep -F "close_claude_code_ghostty_proof_window_by_title" script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'close window candidateWindow' script/real_app_smoke.sh >/dev/null ||
   ! grep -F "reset_zero_window_claude_code_ghostty_proof_host" script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_ZERO_WINDOW_CHECK_TIMEOUT_SECONDS' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Ghostty proof cleanup to close the disposable proof window and only reset a proven zero-window host" >&2
  exit 1
fi
if ! grep -F "wait_for_claude_code_terminal_pidfile_process_optional" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "working directory of targetTerminal" script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'send key "u" modifiers "control" to targetTerminal' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_EXIT_HOLD_SECONDS' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'Claude Code Terminal proof $label exit state' script/real_app_smoke.sh >/dev/null ||
   ! grep -F "Claude Code Ghostty proof shell did not exec the disposable proof command." script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Ghostty proof launch to verify, retry, and diagnose the disposable shell command before prompt discovery" >&2
  exit 1
fi
if ! grep -F "mark_claude_code_ghostty_proof_window_title" script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'set_surface_title:' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'set_tab_title:' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Ghostty proof launch to restamp the disposable title marker after Claude starts" >&2
  exit 1
fi
if ! grep -F 'process_id_or_tree_has_name "$proof_pid" "$expected_name"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Claude Code terminal-host readiness to accept the proof pidfile wrapper or child process" >&2
  exit 1
fi
if ! grep -F 'if ! open_claude_code_terminal_proof "$proof_dir" "$CLAUDE_CODE_TERMINAL_PROOF_TITLE"; then' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'try_wait_for_frontmost_claude_code_terminal_proof_process' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'Claude Code Terminal proof process did not become frontmost' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'Claude Code $host_name proof host app did not become frontmost for fresh context attempt $launch_attempt.' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'Claude Code $host_name proof could not launch a fresh disposable context after $max_launch_attempts attempt(s).' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected fresh Claude Code terminal proof launch to fail cleanly when focus activation is blocked" >&2
  exit 1
fi
if ! awk '/run_claude_code_terminal_host_smoke\(\)/ { in_smoke = 1 } /^}/ && in_smoke { in_smoke = 0 } in_smoke && /press_key_code_cgevent 48/ { found = 1 } END { exit found ? 0 : 1 }' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Claude Code terminal-host Tab proof to press Tab through CGEvent session events" >&2
  exit 1
fi
if ! python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
start = source.index("prepare_claude_code_terminal_suggestion_for_hot_accept()")
end = source.index("\nwarm_claude_code_terminal_hot_accept_helpers()", start)
prepare = source[start:end]
for expected in (
    "reason=focus-lost",
    "reason=focus-changed",
    "wait_for_claude_code_terminal_proof_suggestion_ready_optional",
    "CLAUDE_CODE_TERMINAL_HOT_ACCEPT_SUGGESTION_LINE",
    "AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_REFOCUS_SETTLE_SECONDS",
):
    if expected not in prepare:
        raise SystemExit(1)
smoke_start = source.index("run_claude_code_terminal_host_smoke()")
smoke_end = source.index("\nrun_codex_model_latency()", smoke_start)
smoke = source[smoke_start:smoke_end]
if smoke.count('suggestion_line="${CLAUDE_CODE_TERMINAL_HOT_ACCEPT_SUGGESTION_LINE:-$suggestion_line}"') < 2:
    raise SystemExit(1)
PY
then
  echo "real app smoke self-test expected Claude Code terminal-host Tab proof to refresh suggestions after Ghostty focus loss" >&2
  exit 1
fi
if ! awk '
  /open_fresh_claude_code_terminal_proof_context\(\)/ { in_fresh = 1; saw_wait = 0; saw_exact_refocus = 0 }
  /^}/ && in_fresh {
    if (saw_wait && saw_exact_refocus) { found_fresh = 1 }
    in_fresh = 0
  }
  in_fresh && /wait_for_claude_code_terminal_prompt/ { saw_wait = 1 }
  in_fresh && saw_wait && /settle_claude_code_terminal_proof_focus "fresh proof context"/ { saw_exact_refocus = 1 }
  /run_claude_code_terminal_host_smoke\(\)/ { in_smoke = 1; saw_fresh = 0; saw_clear = 0; saw_type = 0 }
  /^}/ && in_smoke {
    if (found_fresh && saw_fresh && saw_clear && saw_type) { found = 1 }
    in_smoke = 0
  }
  in_smoke && /open_fresh_claude_code_terminal_proof_context "\$host_name" "\$marker"/ { saw_fresh = 1 }
  in_smoke && saw_fresh && /clear_claude_code_terminal_prompt_line/ { saw_clear = 1 }
  in_smoke && saw_clear && /type_claude_code_terminal_smoke_text/ { saw_type = 1 }
  END { exit found ? 0 : 1 }
' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Claude Code terminal-host proof to clear stale prompt text before typed proof input" >&2
  exit 1
fi
if ! grep -F 'lost focus while clearing; launching a fresh disposable context' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'lost focus while typing; launching a fresh disposable context' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'could not prove typed prompt readiness; launching a fresh disposable context' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'settle_claude_code_terminal_proof_focus "typed prompt AX check" || return 1' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'settle_claude_code_terminal_proof_focus "proof typing" || return 1' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'settle_claude_code_terminal_proof_focus "prompt clearing" || return 1' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Claude Code terminal-host prompt clear/type/readiness focus loss to be recoverable" >&2
  exit 1
fi
if ! awk '
  /run_claude_code_terminal_host_smoke\(\)/ { in_smoke = 1; saw_type = 0; saw_assert = 0 }
  /^}/ && in_smoke {
    if (saw_type && saw_assert) { found = 1 }
    in_smoke = 0
  }
  in_smoke && /type_claude_code_terminal_smoke_text "\$proof_text"/ { saw_type = 1 }
  in_smoke && saw_type && /assert_claude_code_terminal_prompt_ready "\$proof_text"/ { saw_assert = 1 }
  END { exit found ? 0 : 1 }
' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected every Claude Code terminal proof sample to prove typed prompt readiness before waiting for suggestions" >&2
  exit 1
fi
if ! awk '
  /type_claude_code_terminal_smoke_text\(\)/ { in_type = 1; saw_mode = 0; saw_iterm_key_events = 0; saw_ghostty_cgevent = 0; saw_terminal_bulk = 0 }
  /^}/ && in_type {
    if (saw_mode && saw_iterm_key_events && saw_ghostty_cgevent && saw_terminal_bulk) { found = 1 }
    in_type = 0
  }
  in_type && /AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_TYPING_MODE/ { saw_mode = 1 }
  in_type && /terminal\)/ { terminal_branch = 1 }
  in_type && terminal_branch && /AUTOCOMPLETE_LAB_CLAUDE_CODE_BULK_TYPE=1 type_claude_code_terminal_raw_smoke_text/ { saw_terminal_bulk = 1; terminal_branch = 0 }
  in_type && /iterm2\)/ { iterm_branch = 1 }
  in_type && iterm_branch && /type_claude_code_terminal_raw_smoke_text "\$text"/ { saw_iterm_key_events = 1; iterm_branch = 0 }
  in_type && /ghostty\)/ { ghostty_branch = 1 }
  in_type && ghostty_branch && /type_claude_code_terminal_ghostty_paste_then_key_text "\$text"/ { saw_ghostty_cgevent = 1; ghostty_branch = 0 }
  END { exit found ? 0 : 1 }
' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Ghostty proof typing to use CGEvent text while iTerm2 keeps real key events and Terminal keeps bulk typing" >&2
  exit 1
fi
if ! grep -F 'type_claude_code_terminal_ghostty_paste_then_key_text()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'type_claude_code_terminal_ghostty_native_text()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'claude_code_ghostty_event_drain_seconds()' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'CLAUDE_CODE_TERMINAL_TYPING_TRIGGER_LINE="$(line_count "$LOG_PATH")"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'AUTOCOMPLETE_LAB_CLAUDE_CODE_GHOSTTY_EVENT_DRAIN_SECONDS' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'prefix_text="${text:0:${#text}-1}"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'final_character="${text: -1}"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'type_claude_code_terminal_ghostty_native_text "$prefix_text"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'type_text_cgevent "$final_character"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'sleep "$drain_seconds"' script/real_app_smoke.sh >/dev/null ||
   ! grep -F 'Ghostty proof final trigger typing' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Ghostty proof typing to native-paste the marked prefix, drain setup events, and type one final trigger character" >&2
  exit 1
fi
if ! awk '
  /type_claude_code_terminal_raw_smoke_text\(\)/ { in_type = 1; saw_bulk_flag = 0 }
  /^}/ && in_type { in_type = 0 }
  in_type && /AUTOCOMPLETE_LAB_CLAUDE_CODE_BULK_TYPE/ { saw_bulk_flag = 1 }
  in_type && saw_bulk_flag && /keystroke rawText/ { found = 1 }
  END { exit found ? 0 : 1 }
' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Claude Code terminal-host proof typing to support bulk text input" >&2
  exit 1
fi
if ! awk '
  /type_claude_code_terminal_raw_smoke_text\(\)/ { in_type = 1 }
  /^}/ && in_type { in_type = 0 }
  in_type && /settle_claude_code_terminal_proof_focus "proof typing"/ { found = 1 }
  END { exit found ? 0 : 1 }
' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Claude Code terminal-host proof typing to reactivate the disposable process immediately before key events" >&2
  exit 1
fi
if ! awk '
  /clear_claude_code_terminal_prompt_line\(\)/ { in_clear = 1 }
  /^}/ && in_clear { in_clear = 0 }
  in_clear && /settle_claude_code_terminal_proof_focus "prompt clearing"/ { found = 1 }
  END { exit found ? 0 : 1 }
' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Claude Code terminal-host prompt clearing to reactivate the disposable process immediately before key events" >&2
  exit 1
fi
if ! awk '
  /run_claude_code_terminal_host_smoke\(\)/ { in_smoke = 1; saw_press = 0; saw_screenshot = 0 }
  /^}/ && in_smoke {
    if (saw_press && saw_screenshot) { found = 1 }
    in_smoke = 0
  }
  in_smoke && /press_key_code_cgevent 48/ { saw_press = 1 }
  in_smoke && /wait_for_screenshot_capture_if_enabled/ {
    if (saw_press) { saw_screenshot = 1 }
  }
  END { exit found ? 0 : 1 }
' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Claude Code terminal-host Tab acceptance before screenshot waiting" >&2
  exit 1
fi
if ! awk '
  /run_claude_code_terminal_host_smoke\(\)/ { in_smoke = 1; saw_settle = 0 }
  /^}/ && in_smoke { in_smoke = 0 }
  in_smoke && /settle_claude_code_terminal_proof_focus "Tab hot accept"/ { saw_settle = 1 }
  in_smoke && saw_settle && /press_key_code_cgevent 48/ { found = 1 }
  END { exit found ? 0 : 1 }
' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Claude Code terminal-host Tab proof to reactivate the disposable process immediately before Tab" >&2
  exit 1
fi
if ! python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
start = source.index("run_claude_code_terminal_host_smoke()")
end = source.index("\nrun_codex_model_latency()", start)
block = source[start:end]
type_index = block.index('type_claude_code_terminal_smoke_text "$proof_text"')
assert_index = block.index('assert_claude_code_terminal_prompt_ready "$proof_text"')
suggestion_window_index = block.index('suggestion_start_line="$(line_count "$LOG_PATH")"')
accept_window_index = block.index('accept_start_line="$suggestion_start_line"')
suggestion_wait_index = block.index("wait_for_claude_code_terminal_proof_suggestion_ready_optional")
accept_wait_index = block.index("wait_for_claude_code_terminal_tab_acceptance")
if not (suggestion_window_index < type_index < assert_index < accept_window_index < suggestion_wait_index < accept_wait_index):
    raise SystemExit(1)
if '"$suggestion_start_line"' not in block[suggestion_wait_index:accept_wait_index]:
    raise SystemExit(1)
PY
then
  echo "real app smoke self-test expected Claude Code terminal-host suggestion slices to capture fast suggestions while waits still happen after typed prompt readiness" >&2
  exit 1
fi
if ! awk '
  /wait_for_claude_code_terminal_tab_acceptance\(\)/ { in_helper = 1 }
  /^}/ && in_helper { in_helper = 0 }
  in_helper && /handled=false/ { saw_fail_closed = 1 }
  in_helper && /Observed handled=false/ { saw_message = 1 }
  in_helper && /decision=passthrough-after-typing/ { saw_stale_tab = 1 }
  in_helper && /Tab acceptance went stale before the app could accept it/ { saw_stale_message = 1 }
  END { exit (saw_fail_closed && saw_message && saw_stale_tab && saw_stale_message) ? 0 : 1 }
' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Claude Code terminal-host acceptance helper to fail fast on handled=false and stale after-typing Tab" >&2
  exit 1
fi
if awk '
  /run_claude_code_terminal_host_smoke\(\)/ { in_smoke = 1; after_suggestion = 0 }
  /^}/ && in_smoke { in_smoke = 0 }
  in_smoke && /wait_for_log_line_number_optional/ { after_suggestion = 1 }
  in_smoke && after_suggestion && /assert_frontmost_app/ { found = 1 }
  in_smoke && after_suggestion && /press_key_code_cgevent 48/ { after_suggestion = 0 }
  END { exit found ? 0 : 1 }
' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Claude Code terminal-host hot accept path not to run slow focus checks" >&2
  exit 1
fi
if ! grep -F 'kill "$proof_process_pid"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Claude Code terminal-host cleanup to kill the proof claude pid" >&2
  exit 1
fi
if ! grep -F 'printf '"'"'cd %q\n'"'"' "$ROOT_DIR"' script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Claude Code Terminal proof to launch Claude from the trusted repo root" >&2
  exit 1
fi
if awk '/open_claude_code_terminal_proof\(\)/ { in_open = 1 } /cleanup_claude_code_terminal_proof\(\)/ { in_open = 0 } in_open && /keystroke shellCommand|AUTOCOMPLETE_LAB_CLAUDE_CODE_TERMINAL_COMMAND/ { found = 1 } END { exit found ? 0 : 1 }' script/real_app_smoke.sh; then
  echo "real app smoke self-test expected Claude Code Terminal launch not to type the launch command into a shell" >&2
  exit 1
fi
if ! grep -F "claude_code_host_process_name" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "wait_for_new_terminal_pids" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "wait_for_frontmost_claude_code_terminal_proof_process" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Claude Code terminal-host launch to activate the disposable host process before typing" >&2
  exit 1
fi
if ! python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
first = source.index("activate_process_id()")
second = source.index("activate_process_id()", first + 1)
end = source.index("frontmost_claude_code_terminal_proof_process_is_active()", second)
block = source[second:end]
for expected in (
    'swift - "$target_pid"',
    'wait_for_appkit_activation_frontmost "$target_pid"',
    'set frontmost of first application process whose unix id is targetPid to true',
):
    if expected not in block:
        raise SystemExit(1)
PY
then
  echo "real app smoke self-test expected Claude Code terminal-host process activation to use AppKit before System Events" >&2
  exit 1
fi
if ! python3 - <<'PY'
from pathlib import Path

source = Path("script/real_app_smoke.sh").read_text()
start = source.index("try_wait_for_frontmost_claude_code_terminal_proof_process()")
end = source.index("\nwait_for_frontmost_claude_code_terminal_proof_process()", start)
block = source[start:end]
loop_start = block.index("while ((SECONDS <= deadline)); do")
loop_block = block[loop_start:]
if block.count('activate_process_id "$root_pid"') < 2:
    raise SystemExit(1)
if "activation_attempt=$((activation_attempt + 1))" not in loop_block:
    raise SystemExit(1)
if 'activate_process_id "$root_pid"' not in loop_block:
    raise SystemExit(1)
PY
then
  echo "real app smoke self-test expected Claude Code terminal-host focus wait to reassert activation while waiting" >&2
  exit 1
fi
if ! grep -F "open_claude_code_terminal_proof" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "type_claude_code_terminal_raw_smoke_text" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "check_prompt_app_proof.sh" script/real_app_smoke.sh >/dev/null ||
   ! grep -F "claude-code-model-latency" script/real_app_smoke.sh >/dev/null; then
  echo "real app smoke self-test expected Claude Code model latency helper, typing, prompt proof, and scenario wiring" >&2
  exit 1
fi
if ! grep -F '"source": "cgHardwareKeyEvents"' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null ||
   ! grep -F '"source": "cgHardwareKeyEventsBaseline"' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null ||
   ! grep -F '"source": "cgUnicodeKeyEvents"' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null ||
   ! grep -F '"source": "cgUnicodeKeyEventsBaseline"' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null ||
   ! grep -F '"source": "cgHardwareKeyEventsGlobal"' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null ||
   ! grep -F '"source": "cgHardwareKeyEventsGlobalBaseline"' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null ||
   ! grep -F '"source": "cgUnicodeKeyEventsGlobal"' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null ||
   ! grep -F '"source": "cgUnicodeKeyEventsGlobalBaseline"' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null ||
   ! grep -F 'source: "pasteboardCommandVToPid"' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null ||
   ! grep -F 'baselineSource: "pasteboardCommandVToPidBaseline"' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null ||
   ! grep -F 'source: "pasteboardCommandV"' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null ||
   ! grep -F 'baselineSource: "pasteboardCommandVBaseline"' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null ||
   ! grep -F '"reason": "terminal-verified-insertion-failed"' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null; then
  echo "real app smoke self-test expected Claude Code Terminal insertion to try verified key events and proof-only paste before failing closed" >&2
  exit 1
fi
if grep -F "accessibilityMenuPaste" Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null ||
   grep -F "postClaudeCodeTerminalHostProofPasteViaAccessibilityMenu" Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null ||
   grep -F "pasteboard-prepare-start" Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null; then
  echo "real app smoke self-test expected Claude Code Terminal fallback not to use blocking AX menu paths" >&2
  exit 1
fi
if ! grep -F 'schedulePasteboardRestore' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null ||
   ! grep -F 'pasteboard.changeCount' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null ||
   ! grep -F 'postCommandVKey(processIdentifier: processIdentifier)' Sources/AutocompleteLabApp/App/AppDelegate.swift >/dev/null; then
  echo "real app smoke self-test expected proof-only paste fallback to restore the pasteboard after verified insertion attempts" >&2
  exit 1
fi
if awk '/if Self\.postUnicodeTextKeyEvents/ { in_unicode = 1 } /insertClaudeCodeTerminalHostProofPasteboardText/ { in_unicode = 0 } in_unicode && /return verified/ { found = 1 } END { exit found ? 0 : 1 }' Sources/AutocompleteLabApp/App/AppDelegate.swift; then
  echo "real app smoke self-test expected unverified Claude Code Terminal Unicode insertion not to skip verified paste fallback" >&2
  exit 1
fi
if grep -F "press_key_code 48" script/real_app_smoke.sh | grep -F "claude_code" >/dev/null; then
  echo "real app smoke self-test expected Claude Code model latency not to press Tab" >&2
  exit 1
fi
if script/real_app_smoke.sh claude-code-model-latency --skip-build --dry-run >/dev/null 2>"$TMP_DIR/claude-code-model-latency-skip-build.txt"; then
  echo "real app smoke self-test expected Claude Code model latency to reject --skip-build" >&2
  exit 1
fi
if ! grep -F "claude-code-model-latency cannot be combined with --skip-build" "$TMP_DIR/claude-code-model-latency-skip-build.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Claude Code model latency skip-build failure" >&2
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
