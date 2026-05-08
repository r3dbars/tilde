# Onboarding Permission UX Scorecard - 2026-05-08

**Source**

- Deep Research topic: Onboarding and Permission UX Rubric
- Repo: `/Users/redbars/.codex/worktrees/380f/transcripted-autocomplete-lab`
- Date: 2026-05-08
- Commit inspected: `96cfba969fbd7c82b21ddca30f9fbd2291173d1e` plus this scorecard pass

**Executive Summary**

The research says this app must earn trust before asking for power. Accessibility is core, Screen Recording is diagnostic-only, and model setup is product setup. Autocomplete Lab is already conservative in the typing loop, privacy defaults, app allowlist, and proof gates. The largest onboarding gap was that launch could trigger the macOS Accessibility prompt before the app-owned explanation. This pass changes launch sequencing, tightens local-first copy, adds timed pause controls, adds a clean manual onboarding QA checklist, and updates the public README trust story.

**Product Standard**

Excellent onboarding for this app means a new user sees a short native explanation, grants only Accessibility, proves one safe TextEdit completion, sees that suggestions start app-by-app, understands what stays local, and can pause, block, delete, or repair without digging.

**Non-Negotiables**

- Accessibility must not be requested before the app explains why it is needed.
- Screen Recording must not be part of normal autocomplete setup.
- Suggestions must stay off in secure, private, payment, URL, search, terminal, password manager, and unproven prompt/chat contexts.
- The app must expose pause, app block, trace deletion, and local model recovery.
- Raw typed text and screenshots must stay off by default.
- Mock runtime fallback must not count as beta-ready.
- Broad app support must not be claimed without proof.

**Current App Assessment**

Starting score before this pass: **77/100**. The app had strong Settings copy, default-off app enablement, local model repair controls, redacted exports, and honest proof gates, but launch still called `AccessibilityClient.requestPermissionIfNeeded()` from `AppDelegate.applicationDidFinishLaunching`, which could show the system prompt too early.

Current score after this pass: **85/100**. Launch now defers the Accessibility system prompt behind app-owned Settings via `StartupOnboardingPolicy`. Settings says the model download uses Hugging Face once and suggestions run locally after install. Privacy copy now says what leaves the Mac automatically. README scope is narrower, timed menu pauses exist, and `docs/product/onboarding-permission-qa-checklist.md` makes manual onboarding proof a beta requirement.

**Score**

Overall score: **85/100**

**Score Breakdown**

- Category name: First-run sequencing
- Weight: 20
- Current score: 17/20
- Why this score: Launch now opens app onboarding/Settings before prompting Accessibility, fresh installs start suggestion-capable apps off, and the first success path points to TextEdit.
- Evidence found in repo: `Sources/AutocompleteLabApp/App/StartupOnboardingPolicy.swift`, `Sources/AutocompleteLabApp/App/AppDelegate.swift`, `Tests/AutocompleteLabAppTests/StartupOnboardingPolicyTests.swift`, `Tests/AutocompleteLabCoreTests/DisabledAppSelectionTests.swift`.
- Missing evidence: no dedicated in-app practice field and no fresh clean-user manual run yet.
- What would make it 100/100: clean install proof showing explanation, Accessibility grant, TextEdit practice success, denial recovery, and no optional asks.

- Category name: Permission timing and explanations
- Weight: 25
- Current score: 22/25
- Why this score: Accessibility copy is plain, the prompt is user-triggered, and Screen Recording copy appears only when screenshot proof is enabled.
- Evidence found in repo: `SettingsPermissionState`, `SettingsPrivacyState.screenRecordingPermissionText`, `SettingsWindowControllerStateTests`, `docs/product/onboarding-permission-qa-checklist.md`.
- Missing evidence: no picker-based diagnostics flow proof, and screenshot proof can still be toggled from Settings as a debug control.
- What would make it 100/100: diagnostics-only screen capture flow with active-capture status, denial recovery, restart guidance if needed, and manual proof.

- Category name: Model install and repair
- Weight: 15
- Current score: 12/15
- Why this score: The app owns MLX runtime setup, validates the model folder, shows install progress, supports cancel/repair/retry, and says the Hugging Face download happens once.
- Evidence found in repo: `LocalModelAssetInstaller`, `RuntimeBootstrapPlan`, `RuntimeReadinessGuidance`, `LocalModelAssetInstallerTests`, `RuntimePolicyTests`.
- Missing evidence: no low-disk or low-memory UX proof, no smaller-model switch flow, and no recent manual cancel/resume proof.
- What would make it 100/100: hardware fit, storage preflight, smaller-model fallback, and clean manual model install/repair proof.

- Category name: Menu bar, Settings, and privacy surfaces
- Weight: 20
- Current score: 18/20
- Why this score: Menu status reflects readiness, Settings exposes access/model/apps/privacy/keyboard controls, and privacy copy states that no data leaves automatically.
- Evidence found in repo: `AppDelegate.updateStatusMenu`, `SettingsWindowController`, `SettingsWindowControllerStateTests`, `docs/product/privacy-and-controls.md`.
- Missing evidence: no stable sidebar/toolbar settings layout, no active screen-capture menu state proof, and no clean-user Settings screenshot from this pass.
- What would make it 100/100: native Settings structure with verified status parity across menu, Settings, Diagnostics, and manual proof artifacts.

- Category name: Pause, disable, and per-app control
- Weight: 10
- Current score: 8/10
- Why this score: Global pause, 15-minute pause, 1-hour pause, current-field silence, per-app enable/disable, and delete controls exist and have policy coverage.
- Evidence found in repo: `SuggestionControlPolicy`, `SuggestionPauseSchedulePolicy`, `DisabledAppSelection`, `AppDelegate.togglePauseSuggestions`, `AppDelegate.pauseSuggestionsFor15Minutes`, `AppDelegate.pauseSuggestionsFor1Hour`, `AppDelegate.toggleCurrentApp`, `AppDelegate.silenceCurrentField`, `SuggestionControlPolicyTests`, `SuggestionPauseSchedulePolicyTests`.
- Missing evidence: no "pause until tomorrow" control and no manual proof that timed pause state mirrors instantly in Settings.
- What would make it 100/100: pause-until-tomorrow, pause-current-app wording, and manual proof that states mirror instantly.

- Category name: README and release-page trust proof
- Weight: 10
- Current score: 8/10
- Why this score: README now narrows the promise, explains Accessibility, says Screen Recording is diagnostic-only, states local-first behavior, and names delete controls.
- Evidence found in repo: `README.md`, `docs/product/beta-readiness-checklist.md`, `docs/product/onboarding-permission-qa-checklist.md`.
- Missing evidence: no release page, notarization proof, privacy policy, or signed beta artifact in this worktree.
- What would make it 100/100: signed/notarized release materials with the same trust story and explicit data retention details.

**0/100 Definition**

The app requests Accessibility or Screen Recording on launch without explanation, cannot be paused, hides what it stores, uses cloud inference by default, or asks users to trust broad autocomplete in unproven apps.

**50/100 Definition**

The app has basic Settings and permission copy, but setup still feels technical, denial is awkward, model repair is weak, and privacy controls are spread out or unclear.

**80/100 Definition**

The app explains Accessibility first, defers Screen Recording to diagnostics, keeps model install local-first and recoverable, exposes pause/block/delete controls, and has honest docs. Some manual proof or edge recovery remains missing.

**100/100 Definition**

A clean install feels calm and native. The user sees value before risk, grants only Accessibility, completes a safe first suggestion, sees exact local/cloud status, can pause/block/delete immediately, and every permission/model/diagnostic path has current proof.

**Failure Modes**

1. Accessibility prompt appears before app-owned explanation.
2. Screen Recording appears required for autocomplete.
3. App claims "autocomplete everywhere" without proof.
4. Model setup fails with vague copy or no repair path.
5. Privacy panel does not say what can leave the Mac.
6. User cannot quickly pause or block the current app.
7. Denied permission leaves the app in a dead end.
8. README or release copy says more than the app proves.

**Evidence Requirements**

- Automated: `swift test --filter StartupOnboardingPolicyTests`.
- Automated: `swift test --filter SuggestionPauseSchedulePolicyTests`.
- Automated: `swift test --filter SettingsWindowControllerStateTests`.
- Automated: `swift test --filter RuntimePolicyTests`.
- Automated: `./script/check_proof_manifest.sh`.
- Automated: `./script/check_score_targets.sh` must keep failing honestly until proof gaps close.
- Manual: `docs/product/onboarding-permission-qa-checklist.md` on a clean macOS user account.
- Manual: model install cancel/resume/repair proof.
- Manual: Screen Recording diagnostic proof showing no happy-path prompt.

**Implementation Queue**

- Objective: defer Accessibility prompt until user intent.
- Files likely involved: `AppDelegate.swift`, `StartupOnboardingPolicy.swift`, `StartupOnboardingPolicyTests.swift`.
- Tests to add/update: startup onboarding policy tests.
- Proof required: clean install shows app explanation before system prompt.
- Risk level: low.
- Expected score impact: +5.

- Objective: make local-first/data-leaving copy exact.
- Files likely involved: `RuntimeReadinessGuidance.swift`, `SettingsWindowController.swift`, `README.md`, `RuntimePolicyTests.swift`, `SettingsWindowControllerStateTests.swift`.
- Tests to add/update: Settings and runtime copy tests.
- Proof required: Settings screenshot and clean model install copy review.
- Risk level: low.
- Expected score impact: +2.

- Objective: make onboarding proof a release gate.
- Files likely involved: `docs/product/onboarding-permission-qa-checklist.md`, `docs/product/beta-readiness-checklist.md`.
- Tests to add/update: none unless a checklist presence gate is added.
- Proof required: completed checklist on a clean user account.
- Risk level: low.
- Expected score impact: +1.

- Objective: add timed pause controls.
- Files likely involved: `SuggestionPauseSchedulePolicy.swift`, `AppDelegate.swift`, `SuggestionPauseSchedulePolicyTests.swift`.
- Tests to add/update: pause duration and state expiry tests.
- Proof required: menu and Settings state parity proof.
- Risk level: medium.
- Expected score impact: shipped +1; manual state parity proof can add more.

- Objective: add a dedicated first-success practice field.
- Files likely involved: Settings/onboarding UI, app proof runner, tests.
- Tests to add/update: UI state tests and manual onboarding proof.
- Proof required: clean-user first-run recording.
- Risk level: medium.
- Expected score impact: +5.

**Codex Execution Goal**

Make onboarding and permission UX safe enough for private beta by ensuring launch explains before prompting, Settings tells the exact local-first story, manual onboarding proof is required before beta, timed pause exists, and remaining unautomated proof gaps are explicit.

**Stop Conditions**

- Launch no longer prompts Accessibility before app-owned copy.
- Automated tests for launch, pause scheduling, Settings copy, and runtime copy pass.
- Scorecard exists and names current score honestly.
- Remaining work is manual proof, timed-pause UI parity, or larger onboarding UI.

**Remaining Gaps**

- Clean-user manual onboarding proof is still required.
- No dedicated in-app practice field exists yet.
- Timed pause has policy/menu coverage but no clean-user Settings parity proof.
- Screen Recording diagnostics still need stronger active-capture proof.
- Release/notarization/privacy-policy proof is outside this pass.
