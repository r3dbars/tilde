# Beta Readiness Checklist

Use this before inviting private beta testers.

## Build Gate

- [ ] `./script/beta_readiness.sh --check-only` reports only expected external
  blockers before the full gate.
- [ ] `./script/beta_readiness.sh` passes.
- [ ] `dist/AutocompleteLab.zip` exists.
- [ ] `dist/private-beta/checksums.txt` matches the archive.
- [ ] The app is signed and the package check passes.
- [x] Notarization status is known before sending the build.

## Runtime Gate

- [ ] The menu bar or Diagnostics shows the model is ready.
- [ ] The preferred asset is `Qwen3.5-4B-4bit`.
- [ ] `AUTOCOMPLETE_LAB_REQUIRE_READY=1 AUTOCOMPLETE_LAB_EXPECTED_ASSET=Qwen3.5-4B-4bit ./script/check_diagnostics_log.sh`
  passes on the latest launch slice.
- [ ] Settings installs or repairs the local model without shell commands.
- [ ] `./script/model_latency_report.py --default-model-proof` passes.
- [ ] `./script/latency_benchmark_report.py --beta-gate` passes with current
  first-visible, first-token, total-generation, AX, event-tap, and stale-late
  suppression numbers.

- [ ] Suggestions stay off while the runtime warms or fails.
- [ ] Mock fallback is not used for beta; the diagnostics gate must show
  `activeCandidate=mlx`, `nativeRuntimeAvailable=true`, and
  `readinessStage=ready state=ready (MLX)`.
- [ ] Latest launch diagnostics include `launch-health` and
  `runtime-warm-succeeded ... durationMilliseconds=...` so crashy relaunches
  and slow warms are visible.
- [ ] Missing or invalid model setup is handled by Settings `Install Model` or
  `Repair Model`.
- [ ] Testers do not run Ollama, llama.cpp, Python, or a model server.

## Compatibility Gate

- [ ] TextEdit passes at least the caveated gate.
- [ ] Notes has verified insertion before writing use.
- [ ] Chrome proof is limited to local textareas.
- [ ] Obsidian or CodeMirror suppresses detached whole-editor suggestions.
- [ ] One Electron writing app has its own trace slice before beta use.
- [ ] Mail is diagnostics-only.
- [ ] Atlas is diagnostics-only.
- [ ] Any blocked app stays off.

## Privacy Gate

- [ ] The tester hears the privacy promise in plain language.
- [ ] `docs/product/onboarding-permission-qa-checklist.md` passes on a clean
  macOS user account.
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

- 2026-05-09 runtime update: the diagnostics checker now reads launch/runtime
  facts from the latest launch slice instead of requiring `launch accessibility=`
  inside the last 120 noisy log lines. `script/check_diagnostics_log_self_test.sh`
  covers the stale-pattern failure and rejects mock fallback or the wrong model
  asset.

- Screenshot-backed proof now exists for Obsidian, Notes title, Notes body, and
  Notes checklist in `docs/product/visual-placement-screenshots/`, but rerun
  those proof paths after app code changes before treating this branch as
  beta-current.
- Manual proof is still pending for Codex one-word no-submit, Claude Code
  one-word no-submit, and Claude desktop one-word no-submit. Run
  `script/manual_proof_queue.sh --print` for the exact user-gated proof
  sequence.
- Screenshot-backed proof is still pending for Claude Code and Claude desktop.
- Codex has a screenshot, but still needs one strict same-slice proof that shows
  screenshot, one-word Tab accept, verified insertion, and no prompt submit.
- `dist/AutocompleteLab.zip` and `dist/private-beta/checksums.txt` have been
  created and verified locally, but `dist/` is ignored; recreate them if app
  code changes after the remaining proof blockers close.
- Current local `dist/AutocompleteLab.zip` was submitted with
  `NOTARYTOOL_PROFILE=Transcripted`, accepted by Apple, stapled, validated, and
  Gatekeeper-accepted on 2026-05-07. Submission:
  `9b9c09f5-585b-4007-b8e1-55a9ac0f6ae2`.
- All-history trace eval is diagnostic only; beta proof must use fresh marked
  slices from disposable text.
