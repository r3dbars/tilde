# Visual Placement Screenshot Checklist

Use this before adding a screenshot to this folder or marking a scorecard row as
screenshot-backed.

## Hard Rules

- Use only local fixtures, disposable documents, or disposable prompt text.
- Do not capture real notes, vault pages, customer text, messages, or prompts.
- Do not press Enter in Codex, Claude desktop, or Claude Code.
- Keep screenshots small and focused on the editor plus ghost text.
- After adding a screenshot link, run `./script/check_visual_placement_evidence.sh`.

## Safe Automated Proof

```bash
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh textedit
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture all
```

## Manual-Gated Proof

```bash
AUTOCOMPLETE_LAB_SMOKE_PROOF_LABEL=notes-title AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes --manual-gate
AUTOCOMPLETE_LAB_SMOKE_PROOF_LABEL=notes-body AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes --manual-gate
AUTOCOMPLETE_LAB_SMOKE_PROOF_LABEL=notes-checklist AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude --manual-gate
AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-code --manual-gate
```

## Known Blockers

- Notes: automation must not create, delete, search, or choose private notes.
  Use the disposable autocomplete smoke note and run title, body, and checklist
  as separate proof labels.
- Obsidian: automation must not open or scan a private vault. Use a disposable
  note and treat detached-suggestion suppression as safety evidence, not a full
  placement pass.
- Codex, Claude desktop, and Claude Code: automation must not submit prompts.
  Use harmless local text, validate Tab/backtick only where the profile supports
  it, then press Esc or clear the prompt manually.
