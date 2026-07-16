# Private Beta Readiness Scorecard - 2026-05-08

## Source

- Deep Research topic: Private beta readiness for a local-first macOS autocomplete app
- Repo: `transcripted-autocomplete-lab`
- Date: 2026-05-08
- Commit inspected: `771f14dee37a4c8a44d89f1059f8a2aec9ca4e40`

## Executive Summary

The research raises the bar from "the autocomplete loop works" to "this is safe
to hand to external testers." For this app, beta readiness means the install
path, local runtime, privacy defaults, app compatibility proof, pause/delete
controls, and feedback loop are all proven together.

The current repo has serious trust machinery: local MLX runtime policy, secure
field blocking, accept-time focus guards, redacted tracing, manual smoke
recorders, screenshot proof gates, and private beta packet scripts. This pass
added preferred DMG packaging, a saved release-proof checklist, required beta
docs, a structured feedback issue form, and a generated private beta packet. It
also reconciled the default proof manifest with the scorecard so completed
Notes and Obsidian screenshots are no longer treated as unreferenced. This ops
and privacy pass adds a privacy-safe menu feedback path, triage labels,
issue-template validation, a daily tester checklist, a redacted export flow, a
stop dashboard, a generated readiness summary artifact, the dependency/SDK
inventory, the field-level data checklist, and current-build redacted export
proof. The app is still not private-beta ready because the current checkout has
no fresh notarized artifact, no fresh VM/install proof, and no safe same-slice
prompt-app no-submit proof.

## Product Standard

Excellent private beta readiness means a tester can install a signed,
notarized, stapled build, grant or deny Accessibility safely, use one-word Tab
acceptance only in proven writing contexts, export a redacted local diagnostic
bundle, delete local traces, and submit structured feedback without sharing raw
typed text. The app must prefer silence over risk, and every compatibility claim
must point to current proof.

## Non-Negotiables

- Any wrong-window, wrong-field, duplicate, partial, stale, or secure-field
  insertion blocks beta.
- Any accidental prompt/chat submit blocks beta.
- Any default upload of typed text, nearby context, screenshots, window titles,
  or retained diagnostics blocks beta.
- Any mock runtime fallback presented as beta-ready blocks beta.
- Any build that fails signing, notarization, stapling, or Gatekeeper assessment
  blocks external distribution.
- Any app compatibility claim without current screenshot-backed/manual proof
  must stay partial or pending.
- The app must have obvious pause, quit, per-app disable, diagnostics export,
  and local trace deletion paths.

## Current App Assessment

The app is a strong internal lab build, not yet a clean private beta. Runtime
and privacy foundations are good. The highest-risk beta gaps are distribution
proof and proof freshness: the release path now creates a signed ZIP and
preferred DMG with saved local proof files, but the research also requires
notarization, stapling, fresh install proof, and same-slice prompt-app
no-submit proof. Packaging, tester-facing docs, and proof-doc consistency are
better after this pass, but the missing live proof still blocks beta.

Current local evidence:

- `./script/package_release.sh --check` found a Developer ID identity and ready
  model asset. Current packaging checks resolve explicit `NOTARYTOOL_PROFILE`
  first, then stored profile aliases such as `Transcripted`.
- `./script/package_release.sh archive` creates `dist/SteadyType.zip`,
  `dist/SteadyType.dmg`, checksums, and `dist/release-proof/`.
- `./script/private_beta_packet.sh` created and verified
  `dist/private-beta/`.
- `./script/check_proof_manifest.sh` now passes; the remaining proof problems
  are not manifest-linking errors.
- `./script/check_visual_placement_evidence.sh --require-all` still fails on
  Codex same-slice proof plus Claude Code/Claude desktop screenshot proof.
- `./script/check_score_targets.sh` failed with 77 score/proof target misses.
- `docs/product/beta-readiness-checklist.md` still lists fresh/manual proof
  blockers and says `dist/` artifacts must be recreated after app changes.
- `Sources/AutocompleteLabCore/Session/SuggestionAcceptanceGuard.swift` blocks
  accept after app, field, selected text, or surrounding text changes.
- `Sources/AutocompleteLabCore/Session/SensitiveTextFieldPolicy.swift` blocks
  native secure fields and password/token/API-key-like fingerprints.
- `Sources/AutocompleteLabCore/Tracing/AutocompleteTracePrivacyFilter.swift`
  and `Sources/AutocompleteLabApp/Mac/RawAutocompleteTraceLog.swift` redact
  raw text and screenshots by default.
- `script/private_beta_packet.sh` creates local feedback/checksum/privacy packet
  files and now points at the required beta docs and issue form.
- `script/check_dependency_inventory.sh` verifies package pins, bundled code,
  app permissions, and script egress paths for the current app build.
- `script/check_current_build_privacy_export.sh` runs the built app binary in
  proof mode and verifies a redacted privacy bundle from synthetic private
  sentinels.

## Score

Starting score before this ops pass: 80/100

Current score after this ops and privacy pass: 84/100

Score movement: +4

## Implementation Progress

- Added preferred `dist/SteadyType.dmg` packaging next to the `dist/SteadyType.zip`
  path in `script/package_release.sh`.
- Added `dist/release-proof/` checklist/checksum/proof output scaffolding for
  codesign, entitlements, notarization, stapler, and Gatekeeper evidence.
- Added `script/package_release_self_test.sh` and wired it into
  `script/smoke_test.sh`.
- Added beta-facing docs: `PRIVACY-BETA.md`, `KNOWN-LIMITATIONS.md`,
  `UNINSTALL-DELETE-DATA.md`, `DIAGNOSTIC-EXPORT.md`, and `RELEASE-NOTES.md`.
- Added `.github/ISSUE_TEMPLATE/autocomplete-beta-feedback.yml` with required
  build, app, permission, severity, expected/actual, repro, and redacted
  diagnostics fields.
- Updated `script/private_beta_packet.sh` and its self-test so the generated
  beta packet points testers at the required docs and feedback form.
- Fixed `script/build_and_run.sh --verify` to call the current app-stop helper
  and added `script/build_and_run_self_test.sh` so stale launch helper names do
  not silently break the smoke gate again.
- Ran the updated archive and packet flow locally. `script/beta_readiness.sh
  --check-only` now reports the release archive and beta packet as OK, with the
  remaining blockers limited to manual app proof and visual placement proof.
- Reconciled `docs/product/deep-dive-scorecard-2026-05-06.md` with existing
  tracked Notes and Obsidian screenshot proof. The default proof manifest check
  now passes, while the strict visual proof gate still blocks on prompt-app
  evidence.
- Added `docs/product/dependency-sdk-data-inventory.md`,
  `docs/product/beta-privacy-data-checklist.md`,
  `script/check_dependency_inventory.sh`, and
  `script/check_current_build_privacy_export.sh`.
- Added app-binary redacted export proof mode plus tests proving the default
  export strips typed text, prompts, model output, accepted text, screenshot
  paths, URLs, document titles, recipients, and subject lines.
- Added `docs/product/private-beta-ops-loop.md`, generated packet files for the
  daily tester checklist, redacted report flow, triage labels, stop-condition
  dashboard, issue-template validation, and beta readiness summary.
- Added `.github/labels.yml` and `script/validate_beta_issue_template.sh`, then
  wired the validator into `script/beta_readiness.sh` and the private packet
  self-test.
- Added a privacy-safe menu bar `Submit Feedback...` path that opens the
  structured GitHub issue form without attaching diagnostics, typed text, or
  screenshots automatically.

## Score Breakdown

### Build, Signing, Notarization, And Install Integrity

- Weight: 20
- Current score: 15/20
- Why this score: The repo can find a Developer ID identity, verify a release
  app bundle, create `dist/SteadyType.zip`, create a preferred
  `dist/SteadyType.dmg`, and write release-proof/checksum outputs. The
  latest local archive path ran successfully, but the artifact is still
  unnotarized. The current checkout has no saved successful notary/stapler
  proof, no quarantine/fresh-VM proof, and no current notary profile in the
  environment.
- Evidence found in repo: `script/package_release.sh`,
  `script/check_app_bundle.sh`, `script/beta_readiness.sh`,
  `script/private_beta_packet.sh`, `script/package_release_self_test.sh`,
  `docs/product/beta-readiness-checklist.md`, local
  `dist/release-proof/release-proof-checklist.md`,
  `dist/release-proof/checksums.txt`.
- Missing evidence: notarized DMG, saved successful notary/stapler/spctl logs,
  fresh-machine Gatekeeper proof, Accessibility grant/deny install proof,
  offline staple proof.
- What would make it 100/100: A reproducible signed DMG flow, accepted
  notarization for the exact tester artifact, stapled artifact validation,
  Gatekeeper assessment from a quarantined fresh download, checksums, and saved
  proof outputs.

### Runtime And Model Readiness

- Weight: 20
- Current score: 16/20
- Why this score: Local runtime ownership, model-asset checks, runtime readiness
  gating, insertion verification, stale request suppression, and key-path
  diagnostics are strong. The remaining beta gaps are fresh production-runtime
  proof, crash/hang readiness evidence, and proof that mock fallback cannot be
  mistaken for beta readiness.
- Evidence found in repo: `Sources/AutocompleteLabApp/Runtime/AppModelRuntimeFactory.swift`,
  `Sources/AutocompleteLabCore/Runtime/RuntimeBootstrapPlan.swift`,
  `Sources/AutocompleteLabCore/Runtime/RuntimeReadinessGuidance.swift`,
  `Sources/AutocompleteLabCore/Session/InsertionVerification.swift`,
  `Sources/AutocompleteLabApp/App/AppDelegate.swift`,
  `Tests/AutocompleteLabCoreTests/RuntimePolicyTests.swift`,
  `Tests/AutocompleteLabCoreTests/InsertionVerificationTests.swift`,
  `script/check_model_asset.py`, `script/model_latency_report.py`,
  `script/build_and_run.sh`, `script/build_and_run_self_test.sh`.
- Missing evidence: MetricKit/crash-hang proof, fresh p95 typing-path proof for
  this build, and a beta gate artifact proving no mock fallback.
- What would make it 100/100: Fresh build proof with native MLX ready, zero mock
  fallback, p95 under the target threshold, no typing hangs, crash/hang
  diagnostics verified after relaunch, and all insertion verification gates
  green in supported apps.

### Privacy

- Weight: 20
- Current score: 20/20
- Why this score: Defaults are local-first and redacted. Raw trace and
  screenshot capture are opt-in. Diagnostics export avoids raw text by default.
  The repo now has beta privacy docs, diagnostic export docs, a dependency/SDK
  inventory, a field-level data checklist, redaction coverage for
  URL/title/recipient/subject metadata, and a current-build export proof command
  that runs from the app binary.
- Evidence found in repo: `docs/product/privacy-and-controls.md`,
  `Sources/AutocompleteLabCore/Tracing/AutocompleteTracePrivacyFilter.swift`,
  `Sources/AutocompleteLabCore/Text/DiagnosticsMetadataRedactor.swift`,
  `Sources/AutocompleteLabApp/Mac/RawAutocompleteTraceLog.swift`,
  `Sources/AutocompleteLabApp/Mac/LocalReportExporter.swift`,
  `Tests/AutocompleteLabCoreTests/AutocompleteTracePrivacyFilterTests.swift`,
  `Tests/AutocompleteLabAppTests/TraceLoggerTests.swift`,
  `Tests/AutocompleteLabAppTests/RawTraceReportExportTests.swift`,
  `script/check_redacted_report_export.sh`, `PRIVACY-BETA.md`,
  `DIAGNOSTIC-EXPORT.md`,
  `script/delete_local_traces.sh`,
  `docs/product/dependency-sdk-data-inventory.md`,
  `docs/product/beta-privacy-data-checklist.md`,
  `Sources/AutocompleteLabApp/App/PrivacyExportProofCommand.swift`,
  `Tests/AutocompleteLabAppTests/PrivacyExportProofCommandTests.swift`,
  `script/check_dependency_inventory.sh`,
  `script/check_current_build_privacy_export.sh`.
- Missing evidence: none for the beta privacy story. Runtime packet capture and
  onboarding comprehension still matter to broader product trust.
- What would make it 100/100: Versioned privacy docs that match the build,
  explicit dependency/SDK inventory, verified redacted export contents, clear
  opt-in paths, and proof that no raw typed text leaves the device by default.

### App Compatibility

- Weight: 15
- Current score: 9/15
- Why this score: The app has narrow compatibility profiles and significant
  smoke/proof infrastructure, and the default proof manifest now verifies after
  reconciling the scorecard with tracked Notes and Obsidian screenshots. The
  proof is still not fully current or complete. Prompt apps remain the strictest
  gap because no-submit proof must be same-slice and screenshot-backed.
- Evidence found in repo: `Sources/AutocompleteLabCore/Compatibility/AppCompatibilityProfile.swift`,
  `Sources/AutocompleteLabCore/Compatibility/CompatibilityRouter.swift`,
  `docs/product/compatibility-matrix.md`,
  `docs/product/app-proof-matrix.md`,
  `docs/product/manual-smoke-runs.md`,
  `docs/product/proof-manifest.json`,
  `docs/product/deep-dive-scorecard-2026-05-06.md`,
  `script/manual_smoke_status.sh`,
  `script/check_proof_manifest.sh`,
  `script/check_visual_placement_evidence.sh`.
- Missing evidence: current prompt-app no-submit proof, real production Monaco
  and ProseMirror proof beyond local fixtures, fresh unsupported/denied
  permission proof, and proof across macOS versions/hardware.
- What would make it 100/100: Every supported surface has bounded current
  trace slices, screenshots, verified accept proof, no-submit proof where
  needed, unsupported cases explicitly blocked, and a matrix covering at least
  two macOS versions and hardware profiles.

### Trust And Safety

- Weight: 15
- Current score: 13/15
- Why this score: The app has visible controls, per-app disable, pause/delete
  trace controls, secure-field blocking, accept-time focus guards, and severe
  failure tracing. This pass added uninstall/delete-data documentation. It is
  still missing manual proof that these controls work through install, deny,
  uninstall, and prompt-app cases.
- Evidence found in repo: `Sources/AutocompleteLabApp/UI/MenuBarIcon.swift`,
  `Sources/AutocompleteLabApp/UI/SettingsWindowController.swift`,
  `Sources/AutocompleteLabCore/Session/SuggestionAcceptanceGuard.swift`,
  `Sources/AutocompleteLabCore/Session/CompletionActivationPolicy.swift`,
  `Sources/AutocompleteLabCore/Session/AcceptedTextSafetyPolicy.swift`,
  `Tests/AutocompleteLabCoreTests/SuggestionAcceptanceGuardTests.swift`,
  `Tests/AutocompleteLabCoreTests/SensitiveTextFieldPolicyTests.swift`,
  `Tests/AutocompleteLabCoreTests/AcceptedTextSafetyPolicyTests.swift`,
  `script/manual_proof_queue.sh`, `UNINSTALL-DELETE-DATA.md`.
- Missing evidence: verified fresh Accessibility grant/deny proof, fresh
  no-submit proof in Codex/Claude surfaces, and build-specific stop-condition
  proof.
- What would make it 100/100: All hard-stop flows are tested from the beta
  artifact, prompt apps cannot submit accidentally, pause/disable/delete are
  verified, and every severe trust failure has a proof gate.

### Documentation And Feedback Operations

- Weight: 10
- Current score: 10/10
- Why this score: Product docs, the generated private beta packet, the issue
  form, and the menu feedback path now cover the whole tester loop: install,
  use, pause, export, report, triage, stop, and remove. The feedback path is
  privacy-safe because it opens the structured GitHub form and does not attach
  diagnostics, typed text, or screenshots automatically. The triage labels and
  stop dashboard make hard stops explicit instead of relying on a separate
  explanation from Justin.
- Evidence found in repo: `README.md`, `docs/product/private-beta-plan.md`,
  `docs/product/beta-readiness-checklist.md`,
  `docs/product/private-beta-ops-loop.md`,
  `docs/product/privacy-and-controls.md`,
  `script/private_beta_packet.sh`,
  `script/private_beta_packet_self_test.sh`,
  `script/validate_beta_issue_template.sh`, `PRIVACY-BETA.md`,
  `KNOWN-LIMITATIONS.md`, `UNINSTALL-DELETE-DATA.md`,
  `DIAGNOSTIC-EXPORT.md`, `RELEASE-NOTES.md`,
  `.github/ISSUE_TEMPLATE/autocomplete-beta-feedback.yml`, `.github/labels.yml`,
  `Sources/AutocompleteLabApp/UI/BetaFeedbackLink.swift`, local
  `dist/private-beta/`.
- Missing evidence: none for docs and feedback operations. The first real
  tester issue still needs to run through this process before beta expansion,
  but the operational path is now defined and validated.
- What would make it 100/100: A beta packet and repo docs that tell testers
  exactly what is supported, what is unsafe, how to install, how to remove all
  local traces, how to export redacted diagnostics, and how to file feedback
  with build/app/permission metadata.

## 0/100 Definition

This area is 0/100 if the app can insert into the wrong field, submit a prompt,
read or store secure/private field text, upload typed content by default,
corrupt normal typing, ship a mock fallback as beta-ready, or distribute an
unsigned/unnotarized artifact as an external beta.

## 50/100 Definition

A 50/100 build can run locally and has some tests, but distribution proof is
manual, privacy docs are incomplete, compatibility claims are fuzzy, and beta
feedback depends on the tester explaining problems in free text.

## 80/100 Definition

An 80/100 build is dogfood-ready. It has a signed artifact path, strong local
runtime/privacy defaults, narrow compatibility proof for a few apps, redacted
diagnostics, pause/delete controls, and honest known limitations. It still
needs fresh notarized install proof and broader manual evidence before external
testers.

## 100/100 Definition

A 100/100 build is ready for a 20-tester private beta. The exact artifact is
signed, notarized, stapled, checksummed, Gatekeeper-verified from a fresh
quarantined install, and backed by current proof for every supported app. It
has versioned privacy, known-limitations, uninstall/delete-data, diagnostic
export, release notes, structured feedback intake, and zero unresolved trust
bugs.

## Failure Modes

1. Wrong-field or wrong-window insertion.
2. Prompt/chat submit from Tab or full accept.
3. Secure/password/private field suggestion or trace leak.
4. Stale suggestion accepted after focus/caret/text changed.
5. Text corruption, duplicate insertion, broken undo, or selection overwrite.
6. Mock runtime fallback treated as beta-ready.
7. Typing lag or event tap interference.
8. Unnotarized or unstapled artifact sent to testers.
9. Raw typed text or screenshots collected without explicit opt-in.
10. Broad app compatibility claimed from fixture-only proof.
11. No clear pause, quit, per-app disable, export, or delete-data path.
12. Vague feedback reports without build/app/permission metadata.

## Evidence Requirements

- `swift test` passes.
- `./script/smoke_test.sh` passes or its external blockers are recorded.
- `./script/beta_readiness.sh --check-only` reports only expected manual or
  environment blockers.
- `./script/package_release.sh archive` creates signed tester artifacts.
- `./script/package_release.sh notarize` records notary, staple, and Gatekeeper
  proof for the exact artifact.
- `./script/private_beta_packet.sh --check` verifies packet checksums.
- `./script/check_dependency_inventory.sh` verifies the dependency/SDK privacy
  inventory against the current app bundle.
- `./script/check_current_build_privacy_export.sh` verifies a redacted privacy
  export from the current app build.
- `./script/check_proof_manifest.sh --require-all --require-current-commit`
  passes before external beta.
- `./script/manual_smoke_status.sh --strict` passes for every claimed surface.
- `./script/check_visual_placement_evidence.sh --require-all` passes.
- Fresh VM or clean-user proof covers install, grant Accessibility, deny
  Accessibility, uninstall, delete data, offline launch, and diagnostic export.
- Prompt-app proof shows screenshot, one-word Tab accept, verified insertion,
  and no submit in one bounded trace slice.

## Implementation Queue

### 1. Add Saved Release Proof And Preferred DMG Packaging

- Objective: Make the release script produce a preferred DMG, checksums, and a
  saved proof checklist without replacing the existing ZIP path.
- Files likely involved: `script/package_release.sh`, a new package self-test,
  `script/smoke_test.sh`, beta docs.
- Tests to add/update: package script self-test and smoke gate.
- Proof required: `./script/package_release.sh --check`, package self-test,
  and archive/notary output when environment permits.
- Risk level: Medium, because packaging changes affect beta distribution.
- Expected score impact: +4 to +7.

### 2. Add Required Beta Docs And Structured Feedback Intake

- Objective: Add privacy, known limitations, uninstall/delete-data, diagnostic
  export, release-notes template, and issue-form files that match current app
  behavior.
- Files likely involved: root docs, `.github/ISSUE_TEMPLATE/`,
  `script/private_beta_packet.sh`, `script/private_beta_packet_self_test.sh`.
- Tests to add/update: private beta packet self-test.
- Proof required: generated templates contain no request for raw typed text by
  default and require build/app/permission metadata.
- Risk level: Low.
- Expected score impact: +5 to +8.

### 3. Reconcile Proof Manifest With Score Docs

- Objective: Stop stale score docs from contradicting current proof manifest
  rows.
- Files likely involved: `docs/product/app-proof-matrix.md`,
  `docs/product/deep-dive-scorecard-2026-05-06.md`,
  `script/check_proof_manifest.py` only if the default scorecard path should
  move.
- Tests to add/update: `./script/check_proof_manifest.sh`.
- Proof required: manifest check passes without weakening pending prompt-app
  rows.
- Risk level: Medium, because score inflation would be worse than a failing
  gate.
- Expected score impact: +2 to +4.

### 4. Add Fresh Manual Proof

- Objective: Close Codex, Claude Code, Claude desktop, and remaining production
  editor proof rows.
- Files likely involved: `docs/product/manual-smoke-runs.md`,
  `docs/product/proof-manifest.json`, screenshots.
- Tests to add/update: `manual_smoke_status.sh --strict`,
  `check_visual_placement_evidence.sh --require-all`.
- Proof required: bounded current trace slices and screenshots.
- Risk level: High, because prompt apps can submit text.
- Expected score impact: +8 to +12.

### 5. Add Fresh Install/VM Proof

- Objective: Prove the exact beta artifact installs and removes cleanly.
- Files likely involved: generated proof folder and beta checklist docs.
- Tests to add/update: none unless a repeatable local VM harness is added.
- Proof required: signed/notarized/stapled DMG, quarantine Gatekeeper test,
  Accessibility grant/deny, offline launch, uninstall/delete-data.
- Risk level: Medium.
- Expected score impact: +8 to +12.

### 6. Finish Beta Privacy Story - Completed This Pass

- Objective: Give beta testers and reviewers a complete map of what data exists
  and why.
- Files involved: `PRIVACY-BETA.md`, `DIAGNOSTIC-EXPORT.md`,
  `docs/product/dependency-sdk-data-inventory.md`,
  `docs/product/beta-privacy-data-checklist.md`,
  `Sources/AutocompleteLabApp/App/PrivacyExportProofCommand.swift`,
  `Sources/AutocompleteLabCore/Text/DiagnosticsMetadataRedactor.swift`,
  `script/check_dependency_inventory.sh`,
  `script/check_current_build_privacy_export.sh`.
- Tests added/updated: redacted export tests, metadata redaction tests, and
  current-build proof command tests.
- Proof required: dependency inventory check, current-build privacy export
  proof, redacted export self-test, delete-local-traces self-test, and
  `swift test`.
- Result: Beta privacy is now 20/20.

## Codex Execution Goal

Make the private beta readiness score materially better by first closing
automatable gaps: add release-proof/DMG scaffolding, add the required beta docs
and structured feedback intake, wire self-tests for those artifacts, update this
scorecard with the new score, and leave manual prompt-app and fresh-VM proof as
explicit blockers unless they are safely runnable.

## Stop Conditions

- The score reaches 100/100 with current proof, or
- all automatable code/docs/test improvements are complete, or
- the remaining work requires Apple notarization credentials, a fresh VM,
  external testers, or risky prompt-app manual proof, or
- a command failure reveals a real bug that is out of scope for this private
  beta readiness pass.

## Remaining Gaps

- Fresh notarized DMG and Gatekeeper proof for this branch.
- Fresh VM install/grant/deny/uninstall/delete-data proof.
- Codex, Claude Code, and Claude desktop no-submit proof.
- Real production Monaco/ProseMirror proof beyond local fixtures.
- Crash/hang diagnostics after relaunch.
- Two-macOS-version and two-hardware-profile matrix evidence.
