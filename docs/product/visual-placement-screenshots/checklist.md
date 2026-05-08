# Visual Placement Screenshot Checklist

Use this before adding a screenshot to this folder or marking a scorecard row as
screenshot-backed.

## Hard Rules

- Use only local fixtures, disposable documents, or disposable prompt text.
- Do not capture real notes, vault pages, customer text, messages, or prompts.
- Do not press Enter in Codex or Claude desktop. Do not test terminal-hosted
  Claude Code until a separate adapter exists.
- Keep screenshots small and focused on the editor plus ghost text.
- After adding a screenshot link, run `./script/check_visual_placement_evidence.sh`.

## Safe Automated Proof

```bash
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh textedit
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture all
```

## Manual-Gated Proof

```bash
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-code --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude --manual-gate
```

## Known Blockers

- Notes: automation must not create, delete, search, or choose private notes.
  Use the disposable autocomplete smoke note and run title, body, and checklist
  as separate proof labels. A generic `notes` run does not count.
- Obsidian: automation must not open or scan a private vault. Use a disposable
  note and treat detached-suggestion suppression as safety evidence, not a full
  placement pass.
- Chrome real editor fixtures: `monaco-real` and `prosemirror-real` install
  pinned npm packages into a temp folder and use an isolated Chrome process with
  renderer accessibility forced. Only add screenshots from a bounded strict
  trace slice that verifies insertion. Keep the score below target until default
  Chrome AX exposure and caret-quality placement are proven.
- Codex and Claude desktop: automation must not submit prompts. Use harmless
  local text, validate one-word Tab accept only, then press Esc or clear the
  prompt manually. Codex proof must include the disposable marker
  `AUTOCOMPLETE_LAB_CODEX_PROOF` before the recorder can accept it.
  Backtick/full accept needs separate full-accept no-submit proof before prompt
  profiles can enable it.
- Claude Code: direct `com.anthropic.claude-code` proof is diagnostics-only in
  this build because real typing happens in a terminal host. Only use the
  marker-gated terminal-host proof lane, keep the prompt disposable, and do not
  press Enter.
