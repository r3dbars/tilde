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
- [ ] Chrome proof is limited to local textarea/contenteditable fixtures.
- [ ] Obsidian default, theme, pane, and long-note proof is current.
- [ ] Codex, Claude, chat apps, Mail, terminal hosts, public browser pages, and
  production browser apps stay proof-only, diagnostics-only, or blocked.
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
- [x] The visible exporter's redaction and six-file artifact contract work
  through `./script/check_redacted_report_export.sh`.

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

## Current Gate - 2026-06-14

HOLD. `./script/beta_readiness.sh --check-only` still blocks. Green lanes in the
latest run: model asset, runtime production gate, controls/diagnostics readiness,
redacted report export, issue template validation, clipboard fallback disabled,
production mock fallback disabled, prompt app manifest proof, visual placement
proof, and release package prerequisites.

Current blockers:

- Runtime no-egress proof is stale, older than the latest runtime launch, and
  its executable SHA-256 does not match the current `dist/SteadyType.app`.
- Onboarding walkthrough proof has no completed clean-user pass row.
- Onboarding permission QA still has 48 unchecked checklist items and 3 pending
  proof rows.
- Manual app proof requires current app/source refresh for the 10 beta-safe rows:
  TextEdit, Notes title/body/checklist, Obsidian stock/theme/panes/long note,
  Chrome textarea, and Chrome contenteditable. Obsidian stock is still pending.
- Latency beta gate has no eligible default runtime launch for the current app.
- Private beta artifact is missing: `dist/SteadyType.dmg`.

Next 3 actions:

1. Refresh the runtime no-egress proof against the current app binary.
2. Record the clean-user TextEdit onboarding walkthrough row.
3. Complete the clean-user permission QA checklist rows.

All-history trace eval is diagnostic only; beta proof must use fresh marked
slices from disposable text.
