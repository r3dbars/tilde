#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
Usage: script/real_app_smoke.sh <textedit|textedit-light|textedit-dark|textedit-long-wrap|textedit-wrapped|textedit-narrow|textedit-scrolled|textedit-selected-suppression|textedit-undo-one-word|textedit-undo-full|textedit-fast-typing|textedit-model-latency|textedit-default-model-latency|chrome|chrome-textarea-model-latency|chrome-contenteditable-model-latency|notes-title|notes-title-short|notes-title-long|notes-body|notes-body-short|notes-body-long|notes-checklist|notes-checklist-checked|notes-checklist-long|notes-title-undo|notes-body-undo|notes-checklist-undo|notes|obsidian|obsidian-theme|obsidian-pane|obsidian-long-note|obsidian-font-zoom|obsidian-markdown-bold|obsidian-markdown-list|obsidian-multiline|obsidian-run-on|codex|codex-full-accept|codex-model-latency|claude-code|claude-code-terminal|claude-code-model-latency|claude-code-terminal-model-latency|claude-code-iterm2|claude-code-warp|claude-code-ghostty|claude-code-kitty|claude-code-alacritty|claude-code-wezterm|claude|claude-model-latency|claude-empty|claude-long|claude-wrapped|claude-narrow|claude-context|claude-light|claude-dark> [--dry-run] [--manual-gate] [--skip-build] [--native-undo-proof] [--fixture <textarea|contenteditable|editor-like|monaco-like|prosemirror-like|monaco-real|prosemirror-real|textarea-public|contenteditable-public|production-text-fields|codemirror-official|monaco-official|prosemirror-official|chat-like|browser-chat-harness|google-docs|notion|browser-webmail|browser-gmail|browser-outlook|browser-chatgpt|browser-slack|browser-discord|all>] [--chrome-accessibility <forced|default>] [--include-default-real-editor-proof] [--host <terminal|iterm2|warp|ghostty|kitty|alacritty|wezterm|auto>]

Runs a real app smoke pass where it is safe to automate. Notes title/body/
checklist proof has guarded disposable-note drivers; Obsidian, Codex,
Claude Code, and Claude desktop are manual-gated so this script never types
into private notes, vaults, terminal prompts, or agent prompts by surprise.
The Codex and Terminal-host Claude Code lanes use targeted disposable proof
helpers after the manual gate: they seed marked proof text, press Tab once, and
never press Enter. Use codex-full-accept for the separate bounded no-submit
full-accept proof lane; it is tagged with a proof-only runtime scenario.

Notes proof must use notes-title, notes-body, notes-checklist, their
notes-*-undo variants, or explicit Notes variant lanes such as
notes-title-short, notes-title-long, notes-body-short, notes-body-long,
notes-checklist-checked, and notes-checklist-long. A generic notes run only
prints the surface picker and does not record proof.

TextEdit proof can use textedit-light, textedit-dark, textedit-long-wrap,
textedit-narrow, textedit-scrolled, textedit-selected-suppression, textedit-undo-one-word,
textedit-undo-full, textedit-fast-typing, textedit-model-latency, or
textedit-default-model-latency. These are still narrow TextEdit lanes, not a
generic native-app claim. The TextEdit undo lanes automatically use native
single-edit Command-Z proof.

Obsidian proof must keep default, theme, pane, long-note, font-zoom,
markdown-bold, markdown-list, multiline, and run-on lanes separate before it can
be complete.

Claude desktop proof can use claude-empty, claude-long, claude-wrapped,
claude-narrow, claude-context, claude-light, or claude-dark to record bounded
one-word no-submit layout variants. Full accept stays disabled until a separate
safe no-submit proof lane exists.

Chrome defaults to the textarea fixture in an isolated Chrome process with
renderer accessibility forced. Use --fixture chat-like to prove Tab/full-accept
do not submit a chat-style composer. Use --fixture monaco-real or
--fixture prosemirror-real for pinned upstream editor-engine fixtures. Use
--chrome-accessibility default to run local fixtures in the normal frontmost
Chrome window as an experimental default-AX exposure proof. Use
--fixture codemirror-official, monaco-official, or prosemirror-official to run
bounded proof against the public official editor demo pages in normal Chrome.
Use --fixture textarea-public, contenteditable-public, or production-text-fields
to run bounded proof against top-level public demo pages with disposable text.
Use --fixture browser-chat-harness, or script/real_browser_chat_proof.sh, for a
bounded HTTP browser-chat no-submit proof harness. That harness proves only the
disposable harness surface, not Slack, Discord, ChatGPT, or broad chat support.
The google-docs, notion, browser-webmail, browser-gmail, browser-outlook, browser-chatgpt, browser-slack, and browser-discord
fixtures are blocked preflight labels: they document the next high-value
surfaces but refuse to type until a safe disposable proof path exists.
Use
--fixture all to run every local Chrome browser/editor fixture with one app
build. Add --include-default-real-editor-proof with --fixture all to rerun real
Monaco and ProseMirror in default Chrome AX mode after the forced lane.
Use chrome-textarea-model-latency or chrome-contenteditable-model-latency to
relaunch SteadyType with fast completions and phrase continuations disabled,
then prove the local model path in a disposable Chrome fixture.
Use codex-model-latency with --manual-gate to seed disposable Codex prompt text,
keep Enter untouched, and prove prompt no-submit local model timing in one
bounded launch.
Use claude-model-latency with --manual-gate to seed disposable Claude desktop
prompt text, keep Enter untouched, and prove prompt no-submit local model timing
in one bounded launch.
Use claude-code-model-latency with --manual-gate to open a disposable Terminal
Claude Code prompt, type marked disposable proof context and trigger
characters, and prove terminal-host no-submit local model timing without Tab,
Enter, or full accept.

Claude Code is proof-only through supported terminal hosts. Use --host or the
claude-code-<host> aliases to record host-specific proof labels without enabling
normal terminal suggestions.

--skip-build reuses the already-running AutocompleteLab app. It fails closed unless
the only running SteadyType process is this checkout's dist/SteadyType.app binary
and that process already has any proof-mode environment needed by the smoke pass.
The model-latency lanes do not allow --skip-build because they must relaunch
SteadyType with fast word completions disabled before sampling. For packaged
release artifact proof only, set AUTOCOMPLETE_LAB_ALLOW_MODEL_LATENCY_SKIP_BUILD=1
after launching that exact app with the required proof-mode environment; the
strict latency selector must still prove the tagged runtime launch.

--native-undo-proof relaunches AutocompleteLab with app rollback disabled,
passes Command-Z through to the target app, and records native single-edit undo
proof only after the target text returns to its pre-accept value.
EOF
