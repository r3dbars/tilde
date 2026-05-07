# Beta Readiness Checklist

Use this before inviting private beta testers.

## Build Gate

- [ ] `./script/beta_readiness.sh --check-only` reports only expected external
  blockers before the full gate.
- [ ] `./script/beta_readiness.sh` passes.
- [ ] `dist/AutocompleteLab.zip` exists.
- [ ] `dist/private-beta/checksums.txt` matches the archive.
- [ ] The app is signed and the package check passes.
- [ ] Notarization status is known before sending the build.

## Runtime Gate

- [ ] The menu bar or Diagnostics shows the model is ready.
- [ ] The preferred asset is `Qwen3.5-4B-4bit`.
- [ ] Suggestions stay off while the runtime warms or fails.
- [ ] Mock fallback is not used for beta.
- [ ] Testers do not run Ollama, llama.cpp, Python, or a model server.

## Compatibility Gate

- [ ] TextEdit passes at least the caveated gate.
- [ ] Notes has verified insertion before writing use.
- [ ] Chrome proof is limited to local textareas.
- [ ] Obsidian or CodeMirror suppresses detached whole-editor suggestions.
- [ ] One Electron writing app has its own trace slice before beta use.
- [ ] Mail is diagnostics-only.
- [ ] Any blocked app stays off.

## Privacy Gate

- [ ] The tester hears the privacy promise in plain language.
- [ ] Raw debug tracing is off.
- [ ] Screenshot tracing is off.
- [ ] The tester knows how to pause tracing.
- [ ] The tester knows how to disable the current app.
- [ ] The tester knows how to delete traces.
- [x] A redacted report export works through
  `./script/check_redacted_report_export.sh`.

## Trust Gate

- [ ] `Tab` accepts one word in TextEdit.
- [ ] `Esc` dismisses the suggestion.
- [ ] Search, login, URL, secure, payment, address, and short form fields are
  blocked.
- [ ] App switching does not insert in the wrong place.
- [ ] Duplicate insertion is zero.
- [ ] Wrong insertion is zero.
- [ ] Focus steal is zero.

Invite testers only when every applicable box is checked.

## Current Blockers - 2026-05-07

- Manual proof is still pending for Notes title, Notes body, Notes checklist,
  Codex one-word no-submit, Claude Code one-word no-submit, and Claude desktop
  one-word no-submit.
- Screenshot-backed proof is still pending for Obsidian, Notes title, Notes
  body, Notes checklist, Claude Code, and Claude desktop.
- Codex has a screenshot, but still needs one strict same-slice proof that shows
  screenshot, one-word Tab accept, verified insertion, and no prompt submit.
- `dist/AutocompleteLab.zip` and `dist/private-beta/checksums.txt` have been
  created and verified locally, but `dist/` is ignored; recreate them after the
  remaining proof and notarization blockers close.
- `NOTARYTOOL_PROFILE` is not set, so notarization cannot be submitted yet.
- All-history trace eval is diagnostic only; beta proof must use fresh marked
  slices from disposable text.
