#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

script/real_app_smoke.sh textedit --dry-run >"$TMP_DIR/textedit.txt"
if ! grep -F "Real app smoke: textedit" "$TMP_DIR/textedit.txt" >/dev/null; then
  echo "real app smoke self-test did not print the TextEdit dry-run plan" >&2
  exit 1
fi

if ! grep -F "temporarily enables TextEdit only for this proof pass" "$TMP_DIR/textedit.txt" >/dev/null; then
  echo "real app smoke self-test did not explain temporary TextEdit enablement" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --dry-run >"$TMP_DIR/chrome.txt"
if ! grep -F "disposable Chrome textarea fixture" "$TMP_DIR/chrome.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome dry-run plan" >&2
  exit 1
fi

if ! grep -F "temporarily enables Chrome only for this proof pass" "$TMP_DIR/chrome.txt" >/dev/null; then
  echo "real app smoke self-test did not explain temporary Chrome enablement" >&2
  exit 1
fi

script/real_app_smoke.sh chrome --fixture contenteditable --dry-run >"$TMP_DIR/chrome-contenteditable.txt"
if ! grep -F "disposable Chrome contenteditable fixture" "$TMP_DIR/chrome-contenteditable.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome contenteditable dry-run plan" >&2
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

script/real_app_smoke.sh chrome --fixture all --dry-run >"$TMP_DIR/chrome-all.txt"
if ! grep -F "textarea, contenteditable, editor-like, Monaco-like, ProseMirror-like, real Monaco, real ProseMirror, and chat-like no-submit local fixtures" "$TMP_DIR/chrome-all.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Chrome all-fixtures dry-run plan" >&2
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

for notes_surface in notes-title notes-body notes-checklist; do
  script/real_app_smoke.sh "$notes_surface" --dry-run >"$TMP_DIR/$notes_surface.txt"
  if ! grep -F "manual-gated Apple Notes ${notes_surface#notes-} proof" "$TMP_DIR/$notes_surface.txt" >/dev/null; then
    echo "real app smoke self-test did not print the $notes_surface proof plan" >&2
    exit 1
  fi
done

script/real_app_smoke.sh obsidian --dry-run >"$TMP_DIR/obsidian.txt"
if ! grep -F "manual-gated disposable Obsidian smoke" "$TMP_DIR/obsidian.txt" >/dev/null; then
  echo "real app smoke self-test did not print the Obsidian manual gate" >&2
  exit 1
fi

if script/real_app_smoke.sh chrome --fixture unknown --dry-run >/dev/null 2>&1; then
  echo "real app smoke self-test expected unknown Chrome fixtures to fail" >&2
  exit 1
fi

if script/real_app_smoke.sh chrome --fixture >/dev/null 2>&1; then
  echo "real app smoke self-test expected missing Chrome fixture values to fail" >&2
  exit 1
fi

if script/real_app_smoke.sh textedit --fixture contenteditable --dry-run >/dev/null 2>&1; then
  echo "real app smoke self-test expected non-Chrome fixtures to fail" >&2
  exit 1
fi

script/real_app_smoke.sh codex --dry-run >"$TMP_DIR/codex.txt"
if ! grep -F "one-word Tab accept without submit" "$TMP_DIR/codex.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Codex one-word no-submit proof" >&2
  exit 1
fi

script/real_app_smoke.sh claude-code --dry-run >"$TMP_DIR/claude-code.txt"
if ! grep -F "one-word Tab accept without submit" "$TMP_DIR/claude-code.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Claude Code one-word no-submit proof" >&2
  exit 1
fi
if ! grep -F "terminal-host Claude Code proof" "$TMP_DIR/claude-code.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Claude Code terminal-host proof lane" >&2
  exit 1
fi

script/real_app_smoke.sh claude --dry-run >"$TMP_DIR/claude.txt"
if ! grep -F "full accept waits for separate full-accept no-submit proof" "$TMP_DIR/claude.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Claude full-accept gate" >&2
  exit 1
fi

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

if script/real_app_smoke.sh obsidian >/dev/null 2>"$TMP_DIR/obsidian-fail.txt"; then
  echo "real app smoke self-test expected Obsidian to require --manual-gate" >&2
  exit 1
fi

if ! grep -F "private Obsidian vault" "$TMP_DIR/obsidian-fail.txt" >/dev/null; then
  echo "real app smoke self-test did not explain the Obsidian safety gate" >&2
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

echo "Real app smoke self-test passed."
