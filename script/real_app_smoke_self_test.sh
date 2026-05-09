#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

script/real_app_smoke.sh textedit --help >"$TMP_DIR/help.txt"
if ! grep -F "requires that process" "$TMP_DIR/help.txt" >/dev/null; then
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
if ! grep -F "Chrome setup text is sent to the Chrome process and verified through the focused AX editor" "$TMP_DIR/chrome.txt" >/dev/null; then
  echo "real app smoke self-test did not explain targeted Chrome setup insertion" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture contenteditable --dry-run >"$TMP_DIR/chrome-contenteditable.txt"
if ! grep -F "disposable Chrome contenteditable fixture" "$TMP_DIR/chrome-contenteditable.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome contenteditable dry-run plan" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture textarea-public --dry-run >"$TMP_DIR/chrome-textarea-public.txt"
if ! grep -F "public W3Schools textarea-public demo page" "$TMP_DIR/chrome-textarea-public.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome public textarea dry-run plan" >&2
  exit 1
fi
if ! grep -F "Allow JavaScript from Apple Events" "$TMP_DIR/chrome-textarea-public.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome public textarea JavaScript preflight requirement" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture contenteditable-public --dry-run >"$TMP_DIR/chrome-contenteditable-public.txt"
if ! grep -F "public W3Schools contenteditable-public demo page" "$TMP_DIR/chrome-contenteditable-public.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome public contenteditable dry-run plan" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture production-text-fields --dry-run >"$TMP_DIR/chrome-production-text-fields.txt"
if ! grep -F "bounded public Chrome textarea and contenteditable proof" "$TMP_DIR/chrome-production-text-fields.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome production text fields dry-run plan" >&2
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
  if ! grep -F "Allow JavaScript from Apple Events" "$TMP_DIR/chrome-$official_fixture.txt" >/dev/null; then
    echo "real app smoke self-test did not print the Chrome $official_fixture JavaScript preflight requirement" >&2
    exit 1
  fi
done

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

for notes_surface in notes-title notes-body notes-checklist notes-title-undo notes-body-undo notes-checklist-undo; do
  script/real_app_smoke.sh "$notes_surface" --dry-run >"$TMP_DIR/$notes_surface.txt"
  if ! grep -F "manual-gated Apple Notes ${notes_surface#notes-} proof" "$TMP_DIR/$notes_surface.txt" >/dev/null; then
    echo "real app smoke self-test did not print the $notes_surface proof plan" >&2
    exit 1
  fi
done

script/real_app_smoke.sh obsidian --dry-run >"$TMP_DIR/obsidian.txt"
if ! grep -F "manual-gated disposable Obsidian default-note smoke" "$TMP_DIR/obsidian.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Obsidian manual gate" >&2
  exit 1
fi

if ! grep -F "script/real_app_smoke.sh obsidian-theme --manual-gate" "$TMP_DIR/obsidian.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Obsidian theme command" >&2
  exit 1
fi

for obsidian_variant in obsidian-theme obsidian-pane obsidian-long-note; do
  script/real_app_smoke.sh "$obsidian_variant" --dry-run >"$TMP_DIR/$obsidian_variant.txt"
  if ! grep -F "manual-gated Obsidian" "$TMP_DIR/$obsidian_variant.txt" >/dev/null; then
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
if AUTOCOMPLETE_LAB_REAL_APP_SMOKE_PROCESS_LIST="" AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_DIR="$LOCK_DIR" AUTOCOMPLETE_LAB_REAL_APP_SMOKE_LOCK_WAIT_SECONDS=0 script/real_app_smoke.sh codex >/dev/null 2>"$TMP_DIR/lock-fail.txt"; then
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
if ! grep -F "refuses to overwrite non-disposable prompt text" "$TMP_DIR/codex.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Codex overwrite guard" >&2
  exit 1
fi
if ! grep -F "Proof mode bundle(s): com.openai.codex" "$TMP_DIR/codex.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Codex proof mode bundle" >&2
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

if script/real_app_smoke.sh codex >/dev/null 2>"$TMP_DIR/codex-fail.txt"; then
  echo "real app smoke self-test expected Codex to require --manual-gate" >&2
  exit 1
fi

if ! grep -F "requires --manual-gate" "$TMP_DIR/codex-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Codex safety gate" >&2
  exit 1
fi

if script/real_app_smoke.sh claude-code >/dev/null 2>"$TMP_DIR/claude-code-fail.txt"; then
  echo "real app smoke self-test expected Claude Code to require --manual-gate" >&2
  exit 1
fi

if ! grep -F "requires --manual-gate" "$TMP_DIR/claude-code-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Claude Code safety gate" >&2
  exit 1
fi

if script/real_app_smoke.sh notes >/dev/null 2>"$TMP_DIR/notes-fail.txt"; then
  echo "real app smoke self-test expected Notes to require --manual-gate" >&2
  exit 1
fi

if ! grep -F "private Apple Notes content" "$TMP_DIR/notes-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Notes safety gate" >&2
  exit 1
fi

if script/real_app_smoke.sh notes --manual-gate >/dev/null 2>"$TMP_DIR/notes-generic-fail.txt"; then
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

if script/real_app_smoke.sh obsidian >/dev/null 2>"$TMP_DIR/obsidian-fail.txt"; then
  echo "real app smoke self-test expected Obsidian to require --manual-gate" >&2
  exit 1
fi

if ! grep -F "private Obsidian vault" "$TMP_DIR/obsidian-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Obsidian safety gate" >&2
  exit 1
fi

if script/real_app_smoke.sh obsidian-theme >/dev/null 2>"$TMP_DIR/obsidian-theme-fail.txt"; then
  echo "real app smoke self-test expected Obsidian variants to require --manual-gate" >&2
  exit 1
fi

if ! grep -F "private Obsidian vault" "$TMP_DIR/obsidian-theme-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Obsidian variant safety gate" >&2
  exit 1
fi

if script/real_app_smoke.sh claude >/dev/null 2>"$TMP_DIR/claude-fail.txt"; then
  echo "real app smoke self-test expected Claude to require --manual-gate" >&2
  exit 1
fi

if ! grep -F "requires --manual-gate" "$TMP_DIR/claude-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Claude safety gate" >&2
  exit 1
fi

if script/real_app_smoke.sh claude-empty >/dev/null 2>"$TMP_DIR/claude-empty-fail.txt"; then
  echo "real app smoke self-test expected Claude layout variants to require --manual-gate" >&2
  exit 1
fi

if ! grep -F "requires --manual-gate" "$TMP_DIR/claude-empty-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Claude layout safety gate" >&2
  exit 1
fi

echo "Real app smoke self-test passed."
