# Beta Readiness Checklist

Use this before inviting private beta testers.

## Build Gate

- [ ] `./script/beta_readiness.sh --check-only` reports only expected external
  blockers before the full gate.
- [ ] `./script/beta_readiness.sh` passes.
- [ ] `dist/SteadyType.dmg` exists as the primary tester artifact.
- [ ] `dist/private-beta/checksums.txt` matches the current DMG.
- [ ] The app is signed and the package check passes.
- [x] Notarization status is known before sending the build.

## Runtime Gate

- [ ] The menu bar or Diagnostics shows the model is ready.
- [ ] The preferred asset is `Qwen3.5-4B-4bit`.
- [ ] Settings installs or repairs the local model without shell commands.
- [ ] `./script/model_latency_report.py --default-model-proof` passes.
- [ ] `./script/beta_readiness.sh --check-only` passes the latency gate with current
  first-visible, first-token, total-generation, AX, event-tap, and stale-late
  suppression numbers.

- [ ] Suggestions stay off while the runtime warms or fails.
- [ ] Mock fallback is not used for beta.
- [ ] Missing or invalid model setup is handled by Settings `Install Local Model` or
  `Repair Local Model`.
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
- [ ] The tester can repeat the first-run map: suggestions appear near the
  cursor, `Tab` accepts one word, `Esc` dismisses, Pause stops everything, text
  stays local, and supported apps are limited.
- [ ] `docs/product/onboarding-permission-qa-checklist.md` passes on a clean
  macOS user account.
- [ ] `./script/check_onboarding_walkthrough_proof.py` passes for the current
  guided TextEdit walkthrough row.
- [ ] Raw debug tracing is off.
- [ ] Screenshot tracing is off.
- [ ] The tester knows how to pause tracing.
- [ ] The tester knows how to pause the current app.
- [ ] The tester knows how to delete traces.
- [x] A redacted report export works through
  `./script/check_redacted_report_export.sh`.
- [x] Dependency/SDK inventory works through
  `./script/check_dependency_inventory.sh`.
- [x] Current app build redacted export proof works through
  `./script/check_current_build_privacy_export.sh`.

## Feedback Ops Gate

- [x] `./script/validate_beta_issue_template.sh` passes.
- [x] The menu bar `Submit Feedback...` path opens the structured beta issue
  form without attaching diagnostics or typed content automatically.
- [x] `.github/labels.yml` defines `beta feedback`, `needs triage`,
  `beta stop`, `beta trust blocker`, `beta high`, `beta needs report`,
  `beta docs`, and `beta ready to close`.
- [x] `docs/product/private-beta-ops-loop.md` ties the daily checklist,
  redacted export, triage labels, stop dashboard, and readiness summary
  together.
- [ ] `dist/private-beta/beta-readiness-summary.md` is regenerated from the
  exact tester DMG after the next app-code change.
- [ ] The first real tester feedback issue has been triaged with the new labels
  and a redacted report, or there are no tester issues yet.

## Trust Gate

- [ ] `FIRST-RUN-BETA.md` matches the current Settings first-run copy and
  generated private-beta packet.
- [ ] `Tab` accepts one word in TextEdit.
- [ ] `Esc` dismisses the suggestion.
- [ ] Search, login, URL, secure, payment, address, and short form fields are
  blocked.
- [ ] App switching does not insert in the wrong place.
- [ ] Duplicate insertion is zero.
- [ ] Wrong insertion is zero.
- [ ] Focus steal is zero.

Invite testers only when every applicable box is checked.

## Current Blockers - 2026-05-12

- `./script/beta_readiness.sh --check-only` currently blocks on fresh latency
  proof, current manual app proof refresh, release package proof, and
  notarized install proof.
- `./script/manual_smoke_status.sh --strict` still requires current-head proof
  refresh for 30 target app rows. Do not treat stale screenshot-backed rows as
  beta-current.
- `./script/check_onboarding_walkthrough_proof.py` is expected to block until
  the guided TextEdit walkthrough table has a current clean-user pass row.
- `./script/private_beta_packet.sh --check` must be rerun after any app-code or
  artifact change and now validates the current DMG with stapler and spctl.
- Current local SteadyType artifacts are not beta-current until a Developer ID
  signed DMG, Apple notarization, stapling, and fresh-install Gatekeeper proof
  are all regenerated. A stored notarytool profile may exist under a shared
  product alias such as `Transcripted`, but older `AutocompleteLab.zip`
  notarization does not count for the current SteadyType DMG.
- Recreate `dist/SteadyType.dmg`, the secondary `dist/SteadyType.zip`, and
  `dist/private-beta/checksums.txt` if app code changes after the remaining
  proof blockers close.
- All-history trace eval is diagnostic only; beta proof must use fresh marked
  slices from disposable text.
