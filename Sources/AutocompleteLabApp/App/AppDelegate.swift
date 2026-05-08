import AppKit
import AutocompleteLabCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let accessibilityClient = AccessibilityClient()
    private let profileStore = CompatibilityProfileStore.mvp
    private let promptEditorPolicy = PromptEditorFingerprintPolicy()
    private let suggestionControlPolicy = SuggestionControlPolicy()
    private let confidencePolicy = CompletionConfidencePolicy()
    private let triggerPolicy = SuggestionTriggerPolicy(
        charactersBeforePauseRequest: 1,
        wordCompletionDelayMilliseconds: 0,
        wordBoundaryDelayMilliseconds: 0,
        pauseDelayMilliseconds: 15
    )
    private var modelRuntimeBundle = AppModelRuntimeFactory.makeRuntime()
    private var completionLengthConfiguration: CompletionLengthConfiguration {
        modelRuntimeBundle.lengthConfiguration
    }
    private var modelRuntime: any ModelRuntime {
        modelRuntimeBundle.runtime
    }
    private lazy var engine: any CompletionEngine = RuntimeBackedCompletionEngine(runtime: modelRuntime)
    private lazy var insertionEngine = InsertionEngine(accessibilityClient: accessibilityClient)
    private let keyboardCapturePolicy = KeyboardCapturePolicy()
    private let insertionVerification = InsertionVerification()
    private let insertionRetryPolicy = InsertionRetryPolicy()
    private let suggestionAcceptanceGuard = SuggestionAcceptanceGuard()
    private let wordCompletionRanker = WordCompletionCandidateRanker()
    private let suggestionTypingProgressPolicy = SuggestionTypingProgressPolicy()
    private let suggestionPresentationGate = SuggestionPresentationGate()
    private let suggestionAggressivenessPolicy = SuggestionAggressivenessPolicy()
    private let screenshotTraceCapturePolicy = ScreenshotTraceCapturePolicy()
    private let focusedTextPollingBackoffPolicy = FocusedTextPollingBackoffPolicy.typingBackoff
    private let focusPollingCadencePolicy = FocusPollingCadencePolicy()
    private lazy var focusedTextPollGatePolicy = FocusedTextPollGatePolicy(
        cadencePolicy: focusPollingCadencePolicy
    )
    private let focusedTextAXHealthPolicy = FocusedTextAXHealthPolicy.typingResponsiveness
    private let focusChangePolicy = SuggestionFocusChangePolicy()
    private let geometryChangePolicy = SuggestionGeometryChangePolicy()
    private let placementPreflightPolicy = SuggestionPlacementPreflightPolicy()
    private let acceptedTextSafetyPolicy = AcceptedTextSafetyPolicy()
    private let recentWordExtractor = RecentWordExtractor()
    private let typingBurstPolicy = TypingBurstPolicy()
    private let compatibilityLearningStore = CompatibilityLearningStore.shared
    private let suggestionPanel = SuggestionPanelController()
    private lazy var focusedTextReader = SerialFocusedTextAXReader(accessibilityClient: accessibilityClient)
    private let diagnosticsWindow = DiagnosticsWindowController()
    private lazy var settingsWindow = SettingsWindowController(
        requestPermission: { [weak self] in
            self?.requestAccessibilityPermission()
        },
        openAccessibilitySettings: { [weak self] in
            self?.openAccessibilitySettings()
        },
        openScreenRecordingSettings: { [weak self] in
            self?.openScreenRecordingSettings()
        },
        toggleSuggestionsPaused: { [weak self] in
            self?.togglePauseSuggestions()
        },
        openTextEditTest: { [weak self] in
            self?.openDisposableTextEditTest()
        },
        performRuntimeAction: { [weak self] action in
            self?.performRuntimeAction(action)
        },
        toggleCurrentApp: { [weak self] in
            self?.toggleCurrentApp()
        },
        toggleMirrorMode: { [weak self] in
            self?.toggleMirrorModeForCurrentApp()
        },
        quietCurrentField: { [weak self] in
            self?.quietCurrentFieldFromControl()
        },
        copyProofCommand: { [weak self] command in
            self?.copyProofCommandToPasteboard(command)
        },
        openCommandContext: { [weak self] in
            self?.showCommandContextPanel()
        },
        enableAllApps: { [weak self] in
            self?.enableAllDisabledApps()
        },
        toggleTracingPaused: { [weak self] in
            self?.toggleSettingsTracingPaused()
        },
        toggleRawContentTracing: { [weak self] in
            self?.toggleRawContentTracing()
        },
        toggleScreenshotTracing: { [weak self] in
            self?.toggleGlobalScreenshotTracing()
        },
        deleteLocalLogs: { [weak self] in
            self?.deleteLocalPrivacyLogs()
        },
        showPrivacyStatus: { [weak self] statusText in
            self?.showPrivacyStatus(statusText)
        },
        setAcceptAllShortcut: { [weak self] shortcut in
            self?.setAcceptAllShortcut(shortcut)
        },
        setSuggestionPace: { [weak self] pace in
            self?.setSuggestionPace(pace)
        }
    )
    private lazy var commandContextPanel = CommandContextPanelController(
        requestSuggestion: { [weak self] in
            self?.requestCommandContextSuggestion()
        },
        copySuggestion: { [weak self] in
            self?.copyCommandContextSuggestionToPasteboard()
        },
        closePanel: { [weak self] in
            self?.cancelCommandContextRequest()
        }
    )

    private var statusItem: NSStatusItem?
    private var statusMenuItem: NSMenuItem?
    private var runtimeMenuItem: NSMenuItem?
    private var pauseSuggestionsMenuItem: NSMenuItem?
    private var toggleAppMenuItem: NSMenuItem?
    private var quietFieldMenuItem: NSMenuItem?
    private var pollTimer: Timer?
    private var keyboardEventTap: KeyboardEventTap?
    private var keyboardEventTapStopTask: Task<Void, Never>?
    private var suggestionSession = SuggestionSession()
    private var lastCaretRect: CGRect?
    private var lastTextLineRect: CGRect?
    private var lastClippingRect: CGRect?
    private var lastTextStyle: FocusedTextStyle?
    private var lastRenderMode: SuggestionRenderMode?
    private var currentFieldIdentity: FocusedFieldIdentity?
    private var currentProfile: CompatibilityProfile?
    private var lastTextSnapshot: FocusedTextSnapshot?
    private var lastRequestedTextBeforeCursor: String?
    private var suppressedFieldIdentities: Set<FocusedFieldIdentity> = []
    private var disabledBundleIdentifiers: Set<String> = []
    private var debounceTask: Task<Void, Never>?
    private var insertionVerificationTask: Task<Void, Never>?
    private var runtimeWarmTask: Task<Void, Never>?
    private var modelInstallTask: Task<Void, Never>?
    private var modelInstallStatusText: String?
    private var commandContextRequestTask: Task<Void, Never>?
    private let focusedFieldIdentityPolicy = FocusedFieldIdentityPolicy()
    private var isFocusedTextPollInFlight = false
    private var latestFocusedTextReadRequestID: UInt64?
    private var focusedTextAXHealthState = FocusedTextAXHealthState()
    private var focusedTextPollLatencyStats = FocusedTextPollLatencyStats()
    private var focusedTextPollSkipStats = FocusedTextPollSkipStats()
    private var suggestionRequestGate = SuggestionRequestGate()
    private var suggestionBlockLogGate = SuggestionBlockLogGate()
    private var placementUncertaintySuppressor = PlacementUncertaintySuppressor()
    private var suggestionRepetitionSuppressor = SuggestionRepetitionSuppressor()
    private var annoyanceSuppressor = AnnoyanceSuppressor()
    private var currentCompletionRequest: CompletionRequest?
    private var streamingPresentationStates: [String: StreamingPresentationState] = [:]
    private var currentSuggestionID: String?
    private var currentSuggestionAppBundleIdentifier: String?
    private var currentSuggestionFieldIdentity: FocusedFieldIdentity?
    private var currentSuggestionVisualScope: CompatibilityLearningVisualScope?
    private var currentSuggestionRequestMode: CompletionRequestMode?
    private var currentSuggestionTextBeforeCursor: String?
    private var currentSuggestionAcceptanceSnapshot: SuggestionAcceptanceSnapshot?
    private var currentSuggestionDisplayedText: String?
    private var currentSuggestionInvalidatedByUserKeyDown = false
    private var lastScreenLayoutFingerprint: String?
    private var scheduledScreenshotSuggestionIDs: Set<String> = []
    private let maxScheduledScreenshotSuggestionIDs = 256
    private var recentWordMemory = ScopedRecentWordMemory()
    private var suppressKeyUntil: [AutocompleteKey: Date] = [:]
    private var lastStatusLine: String?
    private var lastSuggestionDecision = "Starting"
    private var lastSyntheticCaretDiagnosticSignature: String?
    private var lastEligibleTargetApp: RunningApplicationInfo?
    private var lastObservedSettingsApp: RunningApplicationInfo?
    private var currentRuntimeState: LocalRuntimeState = .unavailable(reason: "starting")
    private var commandContextDraft: CommandContextDraft?
    private var commandContextSuggestionText: String?
    private var commandContextStatusMessage = ""
    private var commandContextIsLoading = false
    private var commandContextRequestID: String?
    private var lastFocusedTextPollStartedAt: Date?
    private let focusedTextPollTickInterval: TimeInterval = 0.033
    private let keyboardEventTapIdleStopDelayMilliseconds = 700
    private let postTypingPollPauseMilliseconds = 220
    private let postInsertionPollPauseMilliseconds = 220
    private let slowFocusedTextPollLatencyMilliseconds = 80
    private var focusedTextPollingPause = FocusedTextPollingPause()
    private var typingBurstState = TypingBurstState()
    private var suggestionsPaused = false
    private var suggestionPace = SuggestionPace.normal
    private var keyboardShortcutConfiguration = KeyboardShortcutConfiguration.default
    private func activationPolicy(for profile: CompatibilityProfile) -> CompletionActivationPolicy {
        CompletionActivationPolicy(
            pace: suggestionAggressivenessPolicy.pace(
                userPace: suggestionPace,
                supportStatus: .supported(profile)
            )
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("AutocompleteLab runs as a persistent menu bar agent.")
        NSApp.setActivationPolicy(.accessory)
        loadPauseState()
        loadDisabledApps()
        loadKeyboardShortcutConfiguration()
        loadSuggestionPace()
        configureStatusItem()
        DiagnosticsLog.shared.record("launch", metadata: ["accessibility": String(accessibilityClient.isTrusted)])
        DiagnosticsLog.shared.record("runtime-bootstrap", metadata: modelRuntimeBundle.diagnosticsMetadata)
        accessibilityClient.requestPermissionIfNeeded()
        warmModelRuntime()
        if shouldShowSettingsForCurrentReadiness {
            showSettings()
        }
        lastScreenLayoutFingerprint = screenLayoutFingerprint()
        observeWorkspaceActivation()
        observeDisplayGeometryChanges()
        startPolling()
    }

    func applicationWillTerminate(_ notification: Notification) {
        DiagnosticsLog.shared.record("terminate")
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        debounceTask?.cancel()
        keyboardEventTapStopTask?.cancel()
        insertionVerificationTask?.cancel()
        runtimeWarmTask?.cancel()
        modelInstallTask?.cancel()
        commandContextRequestTask?.cancel()
        invalidatePendingSuggestionRequest()
        modelRuntime.cancel()
        pollTimer?.invalidate()
        stopKeyboardEventTapNow(reason: "terminate")
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = ""
        item.button?.imagePosition = .imageOnly

        let menu = NSMenu()
        let statusMenu = NSMenuItem(title: "Status: starting", action: nil, keyEquivalent: "")
        let runtimeMenu = NSMenuItem(title: "Model: starting", action: nil, keyEquivalent: "")
        let pauseItem = NSMenuItem(title: pauseSuggestionsTitle, action: #selector(togglePauseSuggestions), keyEquivalent: "p")
        let toggleItem = NSMenuItem(title: "Toggle Current App", action: #selector(toggleCurrentApp), keyEquivalent: "t")
        let quietFieldItem = NSMenuItem(title: "Quiet Current Field", action: #selector(quietCurrentFieldFromControl), keyEquivalent: "")
        let debugMenuItem = NSMenuItem(title: "Debug", action: nil, keyEquivalent: "")
        let debugMenu = NSMenu()

        menu.addItem(NSMenuItem(title: "Autocomplete Lab", action: nil, keyEquivalent: ""))
        menu.addItem(statusMenu)
        menu.addItem(runtimeMenu)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(pauseItem)
        menu.addItem(toggleItem)
        menu.addItem(quietFieldItem)
        menu.addItem(NSMenuItem(title: "Command Context...", action: #selector(showCommandContextPanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Request Accessibility", action: #selector(requestAccessibilityPermission), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        debugMenu.addItem(NSMenuItem(title: "Diagnostics", action: #selector(showDiagnostics), keyEquivalent: "d"))
        debugMenu.addItem(NSMenuItem(title: "Model Folder", action: #selector(revealModelFolder), keyEquivalent: "m"))
        debugMenu.addItem(NSMenuItem.separator())
        debugMenu.addItem(NSMenuItem(title: "Nudge Suggestion Up", action: #selector(nudgeCurrentAppSuggestionUp), keyEquivalent: ""))
        debugMenu.addItem(NSMenuItem(title: "Nudge Suggestion Down", action: #selector(nudgeCurrentAppSuggestionDown), keyEquivalent: ""))
        debugMenu.addItem(NSMenuItem(title: "Nudge Suggestion Left", action: #selector(nudgeCurrentAppSuggestionLeft), keyEquivalent: ""))
        debugMenu.addItem(NSMenuItem(title: "Nudge Suggestion Right", action: #selector(nudgeCurrentAppSuggestionRight), keyEquivalent: ""))
        debugMenu.addItem(NSMenuItem(title: "Reset Current App Learning", action: #selector(resetCurrentAppLearning), keyEquivalent: ""))
        menu.setSubmenu(debugMenu, for: debugMenuItem)
        menu.addItem(debugMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
        statusMenuItem = statusMenu
        runtimeMenuItem = runtimeMenu
        pauseSuggestionsMenuItem = pauseItem
        toggleAppMenuItem = toggleItem
        quietFieldMenuItem = quietFieldItem
        refreshMenuBarIcon()
        refreshRuntimeChrome()
    }

    private func startPolling() {
        let timer = Timer.scheduledTimer(withTimeInterval: focusedTextPollTickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollFocusedTextIfIdle()
            }
        }
        timer.tolerance = focusedTextPollTickInterval / 2
        pollTimer = timer
    }

    private func observeWorkspaceActivation() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidActivateApplication(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    private func observeDisplayGeometryChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displayGeometryDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc
    private func workspaceDidActivateApplication(_ notification: Notification) {
        guard suggestionSession.hasVisibleSuggestion else {
            return
        }

        let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        let visibleSuggestionBundleIdentifier = currentSuggestionAppBundleIdentifier
            ?? currentProfile?.bundleIdentifier
        guard focusChangePolicy.shouldHideVisibleSuggestion(
            visibleSuggestionBundleIdentifier: visibleSuggestionBundleIdentifier,
            activatedBundleIdentifier: activatedApp?.bundleIdentifier
        ) else {
            return
        }

        DiagnosticsLog.shared.record(
            "workspace-focus-changed",
            metadata: [
                "visibleSuggestionApp": visibleSuggestionBundleIdentifier ?? "unknown",
                "activatedApp": activatedApp?.bundleIdentifier ?? "unknown"
            ]
        )
        clearFocusedFieldState(hideReason: "focus-changed")
        setSuggestionDecision("Blocked: focus changed")
    }

    @objc
    private func displayGeometryDidChange(_ notification: Notification) {
        let previousFingerprint = lastScreenLayoutFingerprint
        let currentFingerprint = screenLayoutFingerprint()
        lastScreenLayoutFingerprint = currentFingerprint

        let hasVisibleSuggestion = suggestionSession.hasVisibleSuggestion
        let hasPendingSuggestionRequest = debounceTask != nil || currentCompletionRequest != nil
        guard geometryChangePolicy.shouldInvalidateSuggestionState(
            hasVisibleSuggestion: hasVisibleSuggestion,
            hasPendingSuggestionRequest: hasPendingSuggestionRequest,
            previousScreenLayoutFingerprint: previousFingerprint,
            currentScreenLayoutFingerprint: currentFingerprint
        ) else {
            return
        }

        DiagnosticsLog.shared.record(
            "display-geometry-changed",
            metadata: [
                "visibleSuggestionApp": currentSuggestionAppBundleIdentifier ?? currentProfile?.bundleIdentifier ?? "unknown",
                "hadVisibleSuggestion": String(hasVisibleSuggestion),
                "hadPendingSuggestionRequest": String(hasPendingSuggestionRequest),
                "previousScreenLayout": previousFingerprint ?? "unknown",
                "currentScreenLayout": currentFingerprint
            ]
        )

        if hasVisibleSuggestion {
            clearFocusedFieldState(hideReason: "display-geometry-changed")
        } else {
            invalidatePendingSuggestionRequest()
        }
        setSuggestionDecision("Blocked: display changed")
    }

    private func warmModelRuntime() {
        let candidate = modelRuntimeBundle.activeCandidate
        let runtime = modelRuntime

        applyRuntimeState(.warming(candidate: candidate))
        DiagnosticsLog.shared.record(
            "runtime-warm-start",
            metadata: [
                "candidate": candidate.rawValue,
                "modelDirectory": modelRuntimeBundle.modelDirectoryURL.path
            ]
        )

        runtimeWarmTask?.cancel()
        runtimeWarmTask = Task { [weak self, runtime, candidate] in
            do {
                try await runtime.warm()
            } catch {
                await MainActor.run {
                    DiagnosticsLog.shared.record(
                        "runtime-warm-failed",
                        metadata: [
                            "candidate": candidate.rawValue,
                            "reason": error.localizedDescription
                        ]
                    )
                    self?.applyRuntimeState(.failed(candidate: candidate, reason: error.localizedDescription))
                }
                return
            }

            let state = await runtime.state
            await MainActor.run {
                DiagnosticsLog.shared.record(
                    "runtime-warm-succeeded",
                    metadata: [
                        "candidate": candidate.rawValue,
                        "state": state.statusSummary
                    ]
                )
                self?.applyRuntimeState(state)
            }
        }
    }

    private func reloadModelRuntime(reason: String) {
        runtimeWarmTask?.cancel()
        invalidatePendingSuggestionRequest()
        hideSuggestion(reason: "runtime-reload")

        modelRuntimeBundle = AppModelRuntimeFactory.makeRuntime()
        engine = RuntimeBackedCompletionEngine(runtime: modelRuntime)
        currentRuntimeState = .unavailable(reason: "rechecking model")

        var metadata = modelRuntimeBundle.diagnosticsMetadata
        metadata["reason"] = reason
        DiagnosticsLog.shared.record("runtime-bootstrap", metadata: metadata)
        refreshRuntimeChrome()
        warmModelRuntime()
    }

    private func applyRuntimeState(_ state: LocalRuntimeState) {
        let wasReadyForSuggestions = runtimeReadinessReport.allowsSuggestions
        currentRuntimeState = state
        refreshRuntimeChrome()
        let report = runtimeReadinessReport
        if !wasReadyForSuggestions && report.allowsSuggestions {
            rearmFocusedTextAfterRuntimeReady()
        }
        if report.stage == .failed {
            showSettings()
        }
        DiagnosticsLog.shared.record(
            "runtime",
            metadata: [
                "state": state.statusSummary,
                "completionLength": completionLengthConfiguration.displaySummary,
                "readinessStage": report.stage.rawValue,
                "readinessAction": report.action.rawValue
            ]
        )
    }

    private func rearmFocusedTextAfterRuntimeReady() {
        guard currentFieldIdentity != nil else {
            return
        }

        lastTextSnapshot = nil
        lastRequestedTextBeforeCursor = nil
        invalidatePendingSuggestionRequest()
        suggestionBlockLogGate.reset()
        setSuggestionDecision("Ready: runtime")
        DiagnosticsLog.shared.record(
            "runtime-ready-rearmed",
            metadata: [
                "reason": "runtime-became-ready"
            ]
        )
    }

    private func refreshRuntimeChrome() {
        runtimeMenuItem?.title = "Model: \(modelRuntimeBundle.bootstrapPlan.preferredAsset.model.rawValue) • \(runtimeReadinessReport.summary) • \(completionLengthConfiguration.displaySummary)"
        refreshMenuBarIcon()
        if settingsWindow.isShowing {
            settingsWindow.refresh(
                isTrusted: accessibilityClient.isTrusted,
                suggestionsPaused: suggestionsPaused,
                suggestionPace: suggestionPace,
                runtimeReport: runtimeReadinessReport,
                runtimeTargetSummary: runtimeTargetSummary,
                runtimeInstallStatus: modelInstallStatusText,
                runtimeInstallInProgress: modelInstallTask != nil,
                modelDirectoryPath: modelDirectoryPath,
                currentApp: settingsCurrentAppState,
                privacy: settingsPrivacyState,
                keyboardShortcuts: settingsKeyboardShortcutState,
                lastSuggestionDecision: lastSuggestionDecision
            )
        }
    }

    private var runtimeReadinessReport: RuntimeReadinessReport {
        modelRuntimeBundle.bootstrapPlan.readinessReport(for: currentRuntimeState)
    }

    private var modelDirectoryPath: String {
        modelRuntimeBundle.modelDirectoryURL.path
    }

    private var settingsCurrentAppState: SettingsCurrentAppState {
        guard let app = appForSettingsState else {
            return SettingsCurrentAppState(
                displayName: "None",
                bundleIdentifier: nil,
                supportStatus: .unsupported,
                isEnabled: false,
                disabledAppCount: disabledBundleIdentifiers.count
            )
        }

        return SettingsCurrentAppState(
            displayName: app.localizedName,
            bundleIdentifier: app.bundleIdentifier,
            supportStatus: profileStore.supportStatus(for: app.bundleIdentifier),
            isEnabled: !disabledBundleIdentifiers.contains(app.bundleIdentifier),
            disabledAppCount: disabledBundleIdentifiers.count,
            renderModeOverride: compatibilityLearningStore.profile(for: app.bundleIdentifier)?.renderModeOverride,
            canQuietCurrentField: canQuietCurrentField
        )
    }

    private var appForSettingsState: RunningApplicationInfo? {
        if let app = accessibilityClient.frontmostApplication(),
           app.bundleIdentifier != Bundle.main.bundleIdentifier {
            return app
        }

        return lastObservedSettingsApp ?? targetAppForControls()
    }

    private func targetAppForControls() -> RunningApplicationInfo? {
        if let app = accessibilityClient.frontmostApplication(),
           profileStore.allows(bundleIdentifier: app.bundleIdentifier) {
            rememberEligibleTargetApp(app)
            return app
        }

        guard let app = lastEligibleTargetApp,
              profileStore.allows(bundleIdentifier: app.bundleIdentifier) else {
            return nil
        }

        return app
    }

    private func rememberEligibleTargetApp(_ app: RunningApplicationInfo) {
        guard profileStore.allows(bundleIdentifier: app.bundleIdentifier) else {
            return
        }

        lastEligibleTargetApp = app
    }

    private var settingsPrivacyState: SettingsPrivacyState {
        SettingsPrivacyState(
            tracingPaused: RawAutocompleteTraceLog.shared.isPaused,
            rawContentTracingEnabled: RawAutocompleteTraceLog.shared.rawContentTracingEnabled,
            rawContentTracingExpiresAt: RawAutocompleteTraceLog.shared.rawContentTracingExpiresAt,
            screenshotTracingEnabled: RawAutocompleteTraceLog.shared.screenshotTracingEnabled,
            screenshotTracingExpiresAt: RawAutocompleteTraceLog.shared.screenshotTracingExpiresAt,
            diagnosticsPath: DiagnosticsLog.shared.path,
            tracePath: RawAutocompleteTraceLog.shared.path
        )
    }

    private var settingsKeyboardShortcutState: SettingsKeyboardShortcutState {
        SettingsKeyboardShortcutState(
            acceptAllShortcut: keyboardShortcutConfiguration.acceptAllShortcut
        )
    }

    private var runtimeTargetSummary: String {
        let manifest = modelRuntimeBundle.bootstrapPlan.preferredAsset
        let sourceSummary = manifest.source.map { " • source: \($0.displaySummary)" } ?? ""
        return "\(manifest.model.rawValue) • \(completionLengthConfiguration.displaySummary)\(sourceSummary)"
    }

    private var shouldShowSettingsForCurrentReadiness: Bool {
        if !accessibilityClient.isTrusted {
            return true
        }

        switch runtimeReadinessReport.stage {
        case .downloadNeeded, .repairNeeded, .runtimeUnavailable, .failed:
            return true
        case .warming, .ready:
            return false
        }
    }

    private var pauseSuggestionsTitle: String {
        suggestionControlState.toggleTitle
    }

    private var suggestionControlState: SuggestionControlState {
        suggestionControlPolicy.state(isPaused: suggestionsPaused)
    }

    private func pollFocusedTextIfIdle() {
        let now = Date()
        let gateDecision = focusedTextPollGatePolicy.decision(
            now: now,
            lastPollAt: lastFocusedTextPollStartedAt,
            isPollInFlight: isFocusedTextPollInFlight,
            isTrustedForAccessibility: accessibilityClient.isTrusted,
            hasSupportedProfile: hasSupportedProfileForFocusedTextPoll,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion,
            isPausedForTyping: focusedTextPollingPause.isPaused(now: now)
        )

        switch gateDecision {
        case .waitForCadence:
            return
        case .waitForTypingPause:
            setSuggestionDecision("Waiting: typing")
            return
        case .skipInFlight:
            if let notice = focusedTextPollSkipStats.recordSkippedInFlight(now: now) {
                DiagnosticsLog.shared.record(
                    "focused-text-poll-skipped",
                    metadata: [
                        "reason": "in-flight",
                        "count": String(notice.count)
                    ]
                )
            }
            return
        case .startPoll:
            break
        }

        lastFocusedTextPollStartedAt = now
        isFocusedTextPollInFlight = true
        let startedAt = DispatchTime.now().uptimeNanoseconds
        var completesAsync = false
        pollFocusedText(startedAt: startedAt, completesAsync: &completesAsync)
        if !completesAsync {
            finishFocusedTextPoll(startedAt: startedAt)
        }
    }

    private var hasSupportedProfileForFocusedTextPoll: Bool {
        currentProfile.map { profile in
            profile.canPresentSuggestions && !profile.isSensitive && !suggestionsPaused
        } ?? false
    }

    private func finishFocusedTextPoll(startedAt: UInt64) {
        let endedAt = DispatchTime.now().uptimeNanoseconds
        let durationMilliseconds = Int((endedAt - startedAt) / 1_000_000)
        isFocusedTextPollInFlight = false
        latestFocusedTextReadRequestID = nil
        recordFocusedTextPollLatency(durationMilliseconds)
        recordFocusedTextPollSkipSummaryIfNeeded()
    }

    private func pollFocusedText(startedAt: UInt64, completesAsync: inout Bool) {
        if case let .blocked(reason) = suggestionControlPolicy.suggestionAvailability(for: suggestionControlState) {
            setSuggestionDecision(reason.decisionText)
            let frontmostApp = accessibilityClient.frontmostApplication()
            updateStatusMenu(
                app: frontmostApp,
                profile: frontmostApp.flatMap { profileStore.profile(for: $0.bundleIdentifier) },
                appEnabled: frontmostApp.map { !disabledBundleIdentifiers.contains($0.bundleIdentifier) } ?? false
            )
            hideSuggestion(reason: reason.hideReason)
            return
        }

        guard accessibilityClient.isTrusted else {
            setSuggestionDecision("Blocked: Accessibility permission missing")
            updateStatusMenu(app: nil, profile: nil, appEnabled: false)
            hideSuggestion()
            return
        }

        if focusedTextPollingPause.isPaused(now: Date()) {
            setSuggestionDecision("Waiting: typing")
            return
        }

        let activeApp = accessibilityClient.frontmostApplication()
        guard let frontmostApp = activeApp,
              let profile = profileStore.profile(for: frontmostApp.bundleIdentifier) else {
            clearFocusedFieldState()
            currentProfile = nil
            setSuggestionDecision("Blocked: unsupported app")
            updateStatusMenu(app: activeApp, profile: nil, appEnabled: false)
            hideSuggestion()
            return
        }

        rememberEligibleTargetApp(frontmostApp)
        let appEnabled = !disabledBundleIdentifiers.contains(frontmostApp.bundleIdentifier)
        currentProfile = profile
        updateStatusMenu(app: frontmostApp, profile: profile, appEnabled: appEnabled)

        guard appEnabled else {
            clearFocusedFieldState()
            setSuggestionDecision("Blocked: app disabled")
            hideSuggestion()
            return
        }

        guard profile.canPresentSuggestions, !profile.isSensitive else {
            clearFocusedFieldState()
            setSuggestionDecision(profile.isSensitive ? "Blocked: sensitive app" : "Blocked: profile disabled")
            hideSuggestion()
            return
        }

        guard allowFocusedTextAXRead(for: frontmostApp.bundleIdentifier) else {
            return
        }

        let requestID = focusedTextReader.readFocusedTextContext(
            for: frontmostApp,
            allowDescendantTextFallback: profile.allowsDescendantTextFallback
        ) { [weak self, profile, startedAt] result in
            Task { @MainActor [weak self, profile, startedAt] in
                self?.completeFocusedTextPoll(
                    result: result,
                    profile: profile,
                    startedAt: startedAt
                )
            }
        }
        latestFocusedTextReadRequestID = requestID
        completesAsync = true
    }

    private func completeFocusedTextPoll(
        result: FocusedTextAXReadResult,
        profile: CompatibilityProfile,
        startedAt: UInt64
    ) {
        defer {
            finishFocusedTextPoll(startedAt: startedAt)
        }

        guard latestFocusedTextReadRequestID == result.requestID else {
            DiagnosticsLog.shared.record(
                "focused-text-ax-read-dropped",
                metadata: [
                    "reason": "stale-request",
                    "requestID": String(result.requestID)
                ]
            )
            return
        }

        if result.queueDelayMilliseconds >= slowFocusedTextPollLatencyMilliseconds
            || result.readDurationMilliseconds >= slowFocusedTextPollLatencyMilliseconds {
            DiagnosticsLog.shared.record(
                "focused-text-ax-read-slow",
                metadata: [
                    "app": result.app.bundleIdentifier,
                    "queueDelayMilliseconds": String(result.queueDelayMilliseconds),
                    "readDurationMilliseconds": String(result.readDurationMilliseconds),
                    "hasContext": String(result.context != nil)
                ]
            )
        }

        if applyFocusedTextAXHealthObservation(result) {
            return
        }

        guard let activeApp = accessibilityClient.frontmostApplication(),
              activeApp.bundleIdentifier == result.app.bundleIdentifier,
              activeApp.processIdentifier == result.app.processIdentifier else {
            setSuggestionDecision("Blocked: focus changed")
            hideSuggestion(reason: "focus-changed")
            return
        }

        guard let rawContext = result.context, !rawContext.isSecure else {
            clearFocusedFieldState()
            currentProfile = profile
            setSuggestionDecision("Blocked: no editable text field or secure field")
            hideSuggestion()
            return
        }

        processFocusedTextContext(
            rawContext,
            frontmostApp: result.app,
            profile: profile
        )
    }

    private func processFocusedTextContext(
        _ rawContext: FocusedTextContext,
        frontmostApp: RunningApplicationInfo,
        profile: CompatibilityProfile
    ) {
        let promptMatch = promptTextAreaMatch(
            for: frontmostApp.bundleIdentifier,
            context: rawContext
        )
        guard promptMatch.canSuggest else {
            clearFocusedFieldState(resetBlockLogGate: false)
            currentProfile = profile
            setSuggestionDecision("Blocked: \(promptMatch.reason)")
            recordBlockedSuggestionEvent(
                "suggestion-blocked",
                context: rawContext,
                profile: profile,
                fieldIdentity: fieldIdentity(app: frontmostApp, context: rawContext, profile: profile),
                metadata: [
                    "reason": promptMatch.reason
                ]
            )
            hideSuggestion()
            return
        }
        let context = presentationAdjustedContext(rawContext, app: frontmostApp, profile: profile)

        let fieldIdentity = fieldIdentity(
            app: frontmostApp,
            context: context,
            profile: profile
        )
        transitionToField(fieldIdentity)

        let snapshot = FocusedTextSnapshot(
            fieldIdentity: fieldIdentity,
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor
        )

        guard snapshot != lastTextSnapshot else {
            setSuggestionDecision(
                suggestionSession.hasVisibleSuggestion
                    ? "Shown: tracking current field"
                    : "Ready: waiting for text change"
            )
            repositionVisibleSuggestion(context: context, profile: profile)
            return
        }

        let typingBurstDecision = typingBurstPolicy.observe(
            previousTextBeforeCursor: lastTextSnapshot?.textBeforeCursor,
            currentTextBeforeCursor: context.textBeforeCursor,
            nowMilliseconds: Int(ProcessInfo.processInfo.systemUptime * 1000),
            state: &typingBurstState
        )
        recordTypedOverSuggestionIfNeeded(
            newTextBeforeCursor: context.textBeforeCursor,
            fieldIdentity: fieldIdentity,
            profile: profile
        )
        rememberTypedWordsIfNeeded(
            previousSnapshot: lastTextSnapshot,
            currentSnapshot: snapshot,
            appBundleIdentifier: frontmostApp.bundleIdentifier
        )
        hideStaleSuggestionIfNeeded(
            newTextBeforeCursor: context.textBeforeCursor,
            fieldIdentity: fieldIdentity
        )

        lastTextSnapshot = snapshot
        invalidatePendingSuggestionRequest()

        guard profile.canPresentSuggestions else {
            setSuggestionDecision("Blocked: profile diagnostics only")
            recordBlockedSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                metadata: [
                    "reason": "profile-diagnostics-only"
                ]
            )
            hideSuggestion()
            return
        }

        let runtimeReport = runtimeReadinessReport
        guard runtimeReport.allowsSuggestions else {
            setSuggestionDecision("Blocked: runtime \(runtimeReport.stage.rawValue)")
            recordBlockedSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                metadata: [
                    "reason": "runtime-not-ready",
                    "readinessStage": runtimeReport.stage.rawValue
                ]
            )
            hideSuggestion()
            return
        }

        let activationDecision = activationPolicy(for: profile).decision(
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            isSecure: context.isSecure,
            selectedTextLength: context.selectedTextLength,
            isFieldSuppressed: suppressedFieldIdentities.contains(fieldIdentity),
            fieldKind: context.fieldClassification.kind
        )

        guard activationDecision.canSuggest else {
            let decisionText = activationBlockDecisionText(
                activationDecision,
                fieldClassification: context.fieldClassification
            )
            setSuggestionDecision("Blocked: \(decisionText)")
            recordBlockedSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                metadata: ["reason": activationDecision.blockReasonDescription]
                    .merging(context.fieldClassification.traceMetadata) { current, _ in current }
            )
            hideSuggestion()
            return
        }

        let baseRenderMode = RenderModePlan.effectiveMode(
            for: profile,
            supportsInlineSuggestions: context.capabilities.supportsInlineSuggestions,
            hasMirrorAnchor: context.elementRect != nil || context.windowRect != nil
        )

        guard let baseRenderMode else {
            setSuggestionDecision("Blocked: missing inline capabilities")
            recordBlockedSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                metadata: [
                    "reason": "missing-inline-capabilities"
                ]
            )
            hideSuggestion()
            return
        }
        let visualScope = compatibilityVisualScope(
            bundleIdentifier: profile.bundleIdentifier,
            context: context
        )
        let learningAdjustment = compatibilityLearningStore.engine().adjustment(
            for: profile.bundleIdentifier,
            profileRenderMode: baseRenderMode
        ).trustedVisualOffsetOnly(matching: visualScope)
        let renderMode = learningAdjustment.effectiveRenderMode

        let placementPreflight = placementPreflightPolicy.decision(
            for: placementHealthPlan(
                context: context,
                profile: profile,
                learningAdjustment: learningAdjustment
            )
        )
        if let suppression = placementPreflight.suppression {
            blockSuggestionForPlacementPreflight(
                suppression: suppression,
                requestMode: activationDecision.requestMode ?? .phraseContinuation,
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                learningAdjustment: learningAdjustment
            )
            return
        }

        let triggerDecision = triggerPolicy.decision(
            previousTextBeforeCursor: lastRequestedTextBeforeCursor,
            currentTextBeforeCursor: context.textBeforeCursor
        )

        guard case let .request(delayMilliseconds) = triggerDecision else {
            if suggestionSession.hasVisibleSuggestion {
                setSuggestionDecision("Shown: waiting for cadence")
                repositionVisibleSuggestion(context: context, profile: profile)
                return
            }

            setSuggestionDecision("Waiting: cadence policy")
            recordSuggestionEvent(
                "suggestion-trigger-skipped",
                context: context,
                profile: profile,
                metadata: [
                    "reason": "cadence-policy"
                ]
            )
            hideSuggestion()
            return
        }

        let requestMode = activationDecision.requestMode ?? .phraseContinuation
        if requestMode == .phraseContinuation,
           typingBurstDecision.shouldSuppressPhraseContinuation {
            setSuggestionDecision("Waiting: typing burst")
            let metadata: [String: String]
            switch typingBurstDecision {
            case let .burst(insertedCharacterCount, eventCount):
                metadata = [
                    "reason": "typing-burst",
                    "burstInsertedCharacters": String(insertedCharacterCount),
                    "burstEvents": String(eventCount)
                ]
            case .idle:
                metadata = ["reason": "typing-burst"]
            }
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: UUID().uuidString,
                appBundleIdentifier: frontmostApp.bundleIdentifier,
                fieldIdentity: fieldIdentity.traceDescription,
                requestMode: requestMode.rawValue,
                triggerReason: "policy",
                textBeforeCursor: context.textBeforeCursor,
                textAfterCursor: context.textAfterCursor,
                reason: "typing-burst",
                metadata: metadata
            )
            recordBlockedSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                metadata: metadata
            )
            hideSuggestion()
            return
        }
        setSuggestionDecision("Queued: \(requestMode.rawValue)")
        scheduleSuggestion(
            context: context,
            profile: profile,
            appBundleIdentifier: frontmostApp.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            renderMode: renderMode,
            delayMilliseconds: delayMilliseconds,
            requestMode: requestMode
        )
    }

    private func allowFocusedTextAXRead(for bundleIdentifier: String) -> Bool {
        switch focusedTextAXHealthPolicy.pollDecision(
            for: bundleIdentifier,
            now: Date(),
            state: &focusedTextAXHealthState
        ) {
        case let .allowed(recovery?):
            DiagnosticsLog.shared.record(
                "focused-text-ax-health-recovered",
                metadata: [
                    "app": recovery.bundleIdentifier,
                    "reason": recovery.reason.rawValue,
                    "cooldownMilliseconds": String(recovery.cooldownMilliseconds)
                ]
            )
            return true
        case .allowed(nil):
            return true
        case let .coolingDown(cooldown):
            DiagnosticsLog.shared.record(
                "focused-text-ax-health-cooldown",
                metadata: [
                    "app": cooldown.bundleIdentifier,
                    "reason": cooldown.reason.rawValue,
                    "slowReadCount": String(cooldown.slowReadCount),
                    "remainingMilliseconds": String(cooldown.remainingMilliseconds)
                ]
            )
            invalidatePendingSuggestionRequest()
            if suggestionSession.hasVisibleSuggestion {
                hideSuggestion(reason: "focused-text-ax-health-\(cooldown.reason.rawValue)")
            }
            setSuggestionDecision("Waiting: AX cooldown")
            return false
        }
    }

    private func applyFocusedTextAXHealthObservation(_ result: FocusedTextAXReadResult) -> Bool {
        let observation = focusedTextAXHealthPolicy.recordRead(
            bundleIdentifier: result.app.bundleIdentifier,
            queueDelayMilliseconds: result.queueDelayMilliseconds,
            readDurationMilliseconds: result.readDurationMilliseconds,
            now: Date(),
            state: &focusedTextAXHealthState
        )

        guard observation.didStartCooldown,
              let cooldown = observation.cooldown else {
            return false
        }

        DiagnosticsLog.shared.record(
            "focused-text-ax-health-cooldown-started",
            metadata: [
                "app": cooldown.bundleIdentifier,
                "reason": cooldown.reason.rawValue,
                "slowReadCount": String(cooldown.slowReadCount),
                "cooldownMilliseconds": String(cooldown.cooldownMilliseconds),
                "queueDelayMilliseconds": String(result.queueDelayMilliseconds),
                "readDurationMilliseconds": String(result.readDurationMilliseconds),
                "hasContext": String(result.context != nil)
            ]
        )
        invalidatePendingSuggestionRequest()
        if suggestionSession.hasVisibleSuggestion {
            hideSuggestion(reason: "focused-text-ax-health-\(cooldown.reason.rawValue)")
        }
        setSuggestionDecision("Waiting: AX cooldown")
        return true
    }

    private func recordFocusedTextPollLatency(_ durationMilliseconds: Int) {
        if durationMilliseconds >= slowFocusedTextPollLatencyMilliseconds {
            DiagnosticsLog.shared.record(
                "focused-text-poll-latency-slow",
                metadata: [
                    "durationMilliseconds": String(durationMilliseconds)
                ]
            )
        }

        if let summary = focusedTextPollLatencyStats.record(durationMilliseconds) {
            DiagnosticsLog.shared.record(
                "focused-text-poll-latency-summary",
                metadata: [
                    "count": String(summary.count),
                    "p50Milliseconds": String(summary.p50Milliseconds),
                    "p95Milliseconds": String(summary.p95Milliseconds),
                    "maxMilliseconds": String(summary.maxMilliseconds)
                ]
            )
            applyFocusedTextPollingThrottleIfNeeded(
                focusedTextPollingBackoffPolicy.throttleRecommendation(
                    latencySummary: summary,
                    skipSummary: nil
                )
            )
        }
    }

    private func recordFocusedTextPollSkipSummaryIfNeeded() {
        guard let summary = focusedTextPollSkipStats.drain(now: Date()) else {
            return
        }

        DiagnosticsLog.shared.record(
            "focused-text-poll-skip-summary",
            metadata: [
                "reason": "in-flight",
                "count": String(summary.count),
                "durationMilliseconds": String(summary.durationMilliseconds)
            ]
        )
        applyFocusedTextPollingThrottleIfNeeded(
            focusedTextPollingBackoffPolicy.throttleRecommendation(
                latencySummary: nil,
                skipSummary: summary
            )
        )
    }

    private func applyFocusedTextPollingThrottleIfNeeded(
        _ recommendation: FocusedTextPollingThrottleRecommendation
    ) {
        guard recommendation.shouldThrottle,
              let reason = recommendation.reason,
              recommendation.pauseMilliseconds > 0 else {
            return
        }

        focusedTextPollingPause.pause(
            now: Date(),
            durationMilliseconds: recommendation.pauseMilliseconds,
            policy: focusedTextPollingBackoffPolicy
        )
        invalidatePendingSuggestionRequest()
        if suggestionSession.hasVisibleSuggestion {
            hideSuggestion(reason: "focused-text-poll-\(reason.rawValue)")
        }
        DiagnosticsLog.shared.record(
            "focused-text-poll-throttled",
            metadata: [
                "reason": reason.rawValue,
                "pauseMilliseconds": String(recommendation.pauseMilliseconds)
            ]
        )
    }

    private func presentationAdjustedContext(
        _ context: FocusedTextContext,
        app: RunningApplicationInfo,
        profile: CompatibilityProfile
    ) -> FocusedTextContext {
        guard supportsSyntheticTextAreaCaret(for: app.bundleIdentifier),
              promptTextAreaMatch(for: app.bundleIdentifier, context: context).canSuggest,
              context.caretRect == nil,
              let syntheticCaret = syntheticTextAreaCaretRect(
                for: context,
                bundleIdentifier: app.bundleIdentifier
              ) else {
            return context
        }

        let capabilities = FocusedTextCapabilities(
            canReadValue: context.capabilities.canReadValue,
            canReadSelectedTextRange: context.capabilities.canReadSelectedTextRange,
            canReadBoundsForRange: true,
            canReadAttributedText: context.capabilities.canReadAttributedText,
            canSetSelectedText: context.capabilities.canSetSelectedText
        )

        recordSyntheticCaretIfNeeded(syntheticCaret, context: context, profile: profile)

        return FocusedTextContext(
            elementIdentifier: context.elementIdentifier,
            role: context.role,
            subrole: context.subrole,
            fingerprint: context.fingerprint,
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            selectedText: context.selectedText,
            selectedTextLength: context.selectedTextLength,
            caretRect: syntheticCaret,
            elementRect: context.elementRect,
            windowRect: context.windowRect,
            textLineRect: syntheticCaret,
            textStyle: context.textStyle,
            isSecure: context.isSecure,
            fieldClassification: context.fieldClassification,
            caretIsSynthetic: true,
            capabilities: capabilities
        )
    }

    private func supportsSyntheticTextAreaCaret(for bundleIdentifier: String) -> Bool {
        PromptEditorFingerprintPolicy.dogfoodBundleIdentifiers.contains(bundleIdentifier)
            || bundleIdentifier == "md.obsidian"
            || bundleIdentifier == "com.google.Chrome"
    }

    private func compatibilityVisualScope(
        bundleIdentifier: String,
        context: FocusedTextContext
    ) -> CompatibilityLearningVisualScope {
        CompatibilityLearningVisualScope(
            appVersion: appVersionFingerprint(bundleIdentifier: bundleIdentifier),
            screen: screenLayoutFingerprint(),
            fieldShape: fieldShapeFingerprint(context: context)
        )
    }

    private func appVersionFingerprint(bundleIdentifier: String) -> String {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
              let bundle = Bundle(url: appURL) else {
            return "\(bundleIdentifier):unknown"
        }

        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String
        return "\(bundleIdentifier):\(version ?? "unknown"):\(build ?? "unknown")"
    }

    private func screenLayoutFingerprint() -> String {
        NSScreen.screens
            .map { screen in
                let frame = screen.frame
                let scale = Int((screen.backingScaleFactor * 100).rounded())
                let x = Int(frame.minX.rounded())
                let y = Int(frame.minY.rounded())
                let width = Int(frame.width.rounded())
                let height = Int(frame.height.rounded())
                return "\(x),\(y),\(width)x\(height)@\(scale)"
            }
            .sorted()
            .joined(separator: "|")
    }

    private func fieldShapeFingerprint(context: FocusedTextContext) -> String {
        [
            "role=\(context.role ?? "unknown")",
            "subrole=\(context.subrole ?? "none")",
            "element=\(rectSizeFingerprint(context.elementRect))",
            "window=\(rectSizeFingerprint(context.windowRect))",
            "line=\(rectSizeFingerprint(context.textLineRect))",
            "synthetic=\(context.caretIsSynthetic)"
        ].joined(separator: ";")
    }

    private func rectSizeFingerprint(_ rect: CGRect?) -> String {
        guard let rect else {
            return "missing"
        }

        return "w=\(Int(rect.width.rounded())),h=\(Int(rect.height.rounded()))"
    }

    private struct PromptTextAreaMatch {
        let canSuggest: Bool
        let reason: String
    }

    private func promptTextAreaMatch(
        for bundleIdentifier: String,
        context: FocusedTextContext
    ) -> PromptTextAreaMatch {
        let decision = promptEditorPolicy.decision(
            bundleIdentifier: bundleIdentifier,
            role: context.role,
            fingerprintText: context.fingerprint.searchableText,
            elementRect: context.elementRect,
            windowRect: context.windowRect
        )
        return PromptTextAreaMatch(canSuggest: decision.canSuggest, reason: decision.reason)
    }

    private func syntheticTextAreaCaretRect(
        for context: FocusedTextContext,
        bundleIdentifier: String
    ) -> CGRect? {
        guard context.role == "AXTextArea",
              let elementRect = context.elementRect,
              elementRect.width > 80,
              elementRect.height > 20 else {
            return nil
        }

        let tuning = syntheticTextAreaTuning(for: context, bundleIdentifier: bundleIdentifier)
        let font = tuning.font ?? syntheticTextAreaFont(for: context, bundleIdentifier: bundleIdentifier)
        let lineHeight = max(font.ascender - font.descender + font.leading, 20)

        return SyntheticCaretEstimator.caretRect(
            textBeforeCursor: context.textBeforeCursor,
            elementRect: elementRect,
            windowRect: context.windowRect,
            lineHeight: lineHeight,
            horizontalPadding: tuning.horizontalPadding,
            verticalPadding: tuning.verticalPadding,
            inlineGap: tuning.inlineGap,
            widthOfText: { width(of: $0, font: font) }
        )
    }

    private struct SyntheticTextAreaTuning {
        let font: NSFont?
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        let inlineGap: CGFloat
    }

    private func syntheticTextAreaTuning(
        for context: FocusedTextContext,
        bundleIdentifier: String
    ) -> SyntheticTextAreaTuning {
        if PromptEditorFingerprintPolicy.dogfoodBundleIdentifiers.contains(bundleIdentifier) {
            return SyntheticTextAreaTuning(
                font: NSFont.systemFont(ofSize: 15),
                horizontalPadding: 0,
                verticalPadding: 4,
                inlineGap: 8
            )
        }

        guard bundleIdentifier == "com.google.Chrome" else {
            return SyntheticTextAreaTuning(font: nil, horizontalPadding: 18, verticalPadding: 4, inlineGap: 8)
        }

        let searchable = context.fingerprint.searchableText
        if searchable.contains("monaco") {
            return SyntheticTextAreaTuning(font: nil, horizontalPadding: 18, verticalPadding: 4, inlineGap: 44)
        }

        if searchable.contains("prosemirror") {
            return SyntheticTextAreaTuning(
                font: NSFont.systemFont(ofSize: 18),
                horizontalPadding: 18,
                verticalPadding: 14,
                inlineGap: 8
            )
        }

        if usesChromeRichEditorSyntheticTuning(for: context, bundleIdentifier: bundleIdentifier) {
            return SyntheticTextAreaTuning(font: nil, horizontalPadding: 18, verticalPadding: 14, inlineGap: 20)
        }

        return SyntheticTextAreaTuning(font: nil, horizontalPadding: 18, verticalPadding: 4, inlineGap: 8)
    }

    private func syntheticTextAreaFont(
        for context: FocusedTextContext,
        bundleIdentifier: String
    ) -> NSFont {
        guard let textStyle = context.textStyle else {
            return NSFont.systemFont(ofSize: 18)
        }

        return textStyle.font
    }

    private func usesChromeRichEditorSyntheticTuning(
        for context: FocusedTextContext,
        bundleIdentifier: String
    ) -> Bool {
        guard bundleIdentifier == "com.google.Chrome" else {
            return false
        }

        let searchable = context.fingerprint.searchableText
        let richEditorTerms = [
            "codemirror",
            "contenteditable",
            "editor-like",
            "monaco",
            "prosemirror",
            "rich text editor"
        ]
        return richEditorTerms.contains { searchable.contains($0) }
    }

    private func width(of text: String, font: NSFont) -> CGFloat {
        text.size(withAttributes: [.font: font]).width
    }

    private func compactRectDescription(_ rect: CGRect) -> String {
        "x=\(Int(rect.origin.x.rounded())),y=\(Int(rect.origin.y.rounded())),w=\(Int(rect.width.rounded())),h=\(Int(rect.height.rounded()))"
    }

    private func recordSyntheticCaretIfNeeded(
        _ caret: CGRect,
        context: FocusedTextContext,
        profile: CompatibilityProfile
    ) {
        let signature = [
            profile.bundleIdentifier,
            String(context.textBeforeCursor.count),
            compactRectDescription(caret)
        ].joined(separator: "|")

        guard signature != lastSyntheticCaretDiagnosticSignature else {
            return
        }

        lastSyntheticCaretDiagnosticSignature = signature
        DiagnosticsLog.shared.record(
            "synthetic-caret",
            metadata: [
                "app": profile.bundleIdentifier,
                "source": "text-area-estimate",
                "caret": compactRectDescription(caret),
                "beforeChars": String(context.textBeforeCursor.count)
            ]
        )
    }

    @discardableResult
    private func startKeyboardEventTapIfPossible() -> Bool {
        keyboardEventTapStopTask?.cancel()
        keyboardEventTapStopTask = nil

        guard keyboardEventTap == nil else {
            return true
        }

        guard keyboardCapturePolicy.shouldCaptureKeys(
            isTrustedForAccessibility: accessibilityClient.isTrusted,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion,
            controlState: suggestionControlState
        ) else {
            return false
        }

        let eventTap = KeyboardEventTap(
            handler: { [weak self] key, isAutorepeat, didObservePassthroughKeyDown in
                self?.handleAutocompleteKey(
                    key,
                    isAutorepeat: isAutorepeat,
                    didObservePassthroughKeyDown: didObservePassthroughKeyDown
                ) ?? false
            },
            passthroughKeyDownObserver: { [weak self] in
                self?.observePassthroughTypingKeyDown()
            },
            disabledObserver: { [weak self] reason in
                self?.handleKeyboardEventTapDisabled(reason: reason)
            }
        )
        eventTap.updateSnapshot(keyboardEventTapSnapshot())

        if eventTap.start() {
            keyboardEventTap = eventTap
            DiagnosticsLog.shared.record("keyboard-event-tap-started")
            return true
        }

        DiagnosticsLog.shared.record("keyboard-event-tap-start-failed")
        return false
    }

    private func keyboardEventTapSnapshot() -> KeyboardEventTapSnapshot {
        KeyboardEventTapSnapshot(
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion,
            supportsOneWordAcceptance: currentProfile?.supportsOneWordAcceptance == true,
            supportsFullAcceptance: currentProfile?.supportsFullAcceptance == true,
            isInvalidatedByUserTyping: currentSuggestionInvalidatedByUserKeyDown,
            acceptAllShortcut: keyboardShortcutConfiguration.acceptAllShortcut
        )
    }

    private func updateKeyboardEventTapSnapshot() {
        keyboardEventTap?.updateSnapshot(keyboardEventTapSnapshot())
    }

    private func handleKeyboardEventTapDisabled(reason: String) {
        stopKeyboardEventTapNow(reason: "system-\(reason)")
        currentSuggestionInvalidatedByUserKeyDown = true
        invalidatePendingSuggestionRequest()
        setSuggestionDecision("Blocked: keyboard capture disabled")
        hideSuggestion(reason: "keyboard-event-tap-\(reason)")
        DiagnosticsLog.shared.record(
            "keyboard-event-tap-failed-closed",
            metadata: [
                "reason": reason
            ]
        )
    }

    private func scheduleKeyboardEventTapStopIfIdle() {
        guard keyboardEventTap != nil else {
            return
        }

        keyboardEventTapStopTask?.cancel()
        let idleStopDelayMilliseconds = keyboardEventTapIdleStopDelayMilliseconds
        keyboardEventTapStopTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(idleStopDelayMilliseconds))
            guard !Task.isCancelled,
                  let self,
                  !self.suggestionSession.hasVisibleSuggestion else {
                return
            }

            self.stopKeyboardEventTapNow(reason: "idle")
        }
    }

    private func stopKeyboardEventTapNow(reason: String) {
        keyboardEventTapStopTask?.cancel()
        keyboardEventTapStopTask = nil

        guard let keyboardEventTap else {
            return
        }

        keyboardEventTap.stop(reason: reason)
        self.keyboardEventTap = nil
        DiagnosticsLog.shared.record(
            "keyboard-event-tap-stopped",
            metadata: [
                "reason": reason
            ]
        )
    }

    private func observePassthroughTypingKeyDown() {
        focusedTextPollingPause.pause(
            now: Date(),
            durationMilliseconds: postTypingPollPauseMilliseconds
        )

        guard suggestionSession.hasVisibleSuggestion else {
            return
        }

        currentSuggestionInvalidatedByUserKeyDown = true
        invalidatePendingSuggestionRequest()
        setSuggestionDecision("Waiting: typing")
        hideSuggestion(reason: "typing-continued")
    }

    private func handleAutocompleteKey(
        _ key: AutocompleteKey,
        isAutorepeat: Bool = false,
        didObservePassthroughKeyDown: Bool = false
    ) -> Bool {
        if didObservePassthroughKeyDown {
            currentSuggestionInvalidatedByUserKeyDown = true
        }

        guard suggestionSession.hasVisibleSuggestion else {
            suppressKeyUntil[key] = nil
            return false
        }

        let acceptanceDecision = currentSuggestionAcceptanceDecision()
        guard acceptanceDecision.canAccept else {
            let blockReason = acceptanceDecision.blockReason ?? .missingCurrentSnapshot
            setSuggestionDecision("Blocked: \(blockReason.rawValue)")
            recordAcceptanceGuardBlock(reason: blockReason)
            hideSuggestion(reason: "wrong-app-or-field-before-accept")
            recordKeyboardAction(
                key: key,
                action: .passThrough,
                handled: false,
                reason: blockReason.rawValue
            )
            return false
        }

        if currentSuggestionInvalidatedByUserKeyDown {
            setSuggestionDecision("Blocked: stale suggestion passed through")
            hideSuggestion(reason: "stale-after-keydown")
            recordKeyboardAction(
                key: key,
                action: .passThrough,
                handled: false,
                reason: "stale-after-keydown"
            )
            return false
        }

        if shouldSuppressKey(key, isAutorepeat: isAutorepeat) {
            recordKeyboardAction(key: key, action: .passThrough, handled: true, reason: "suppressed-autorepeat")
            return true
        }

        let action = KeyboardActionRouter(shortcutConfiguration: keyboardShortcutConfiguration).action(
            for: key,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion
        )

        switch action {
        case .acceptNextWord:
            guard currentProfile?.supportsOneWordAcceptance == true else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "unsupported-one-word")
                return false
            }

            let verificationBaseline = insertionVerificationBaseline()
            guard let acceptance = suggestionSession.nextWordAcceptancePreview() else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "no-visible-acceptance")
                return false
            }
            guard visibleAcceptanceMatchesDisplayedSuggestion(acceptance) else {
                setSuggestionDecision("Blocked: visible suggestion changed")
                hideSuggestion(reason: "visible-acceptance-mismatch")
                recordKeyboardAction(key: key, action: action, handled: false, reason: "visible-acceptance-mismatch")
                return false
            }
            guard insertAcceptedText(acceptance.acceptedText) else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "insert-failed")
                return false
            }

            let acceptedText = acceptance.acceptedText
            suggestionSession.commitNextWordAcceptance(acceptedText)
            recordAcceptedText(acceptedText)
            advanceCurrentSuggestionBaseline(afterAccepting: acceptedText)
            suggestionRepetitionSuppressor.recordAcceptance(
                acceptedText,
                mode: currentSuggestionRequestMode,
                scope: currentSuggestionAppBundleIdentifier ?? currentProfile?.bundleIdentifier ?? ""
            )
            recordRawAcceptance(action: action, acceptance: acceptance)
            setSuggestionDecision("Accepted: next word")
            if suggestionSession.hasVisibleSuggestion {
                refreshVisibleSuggestion()
            } else {
                hideSuggestion(reason: "accepted-next-word-final")
            }
            scheduleInsertionVerification(acceptedText: acceptedText, baseline: verificationBaseline)
            suppressKey(key)
            recordKeyboardAction(key: key, action: action, handled: true, reason: "accepted")
            return true

        case .acceptAllVisible:
            guard currentProfile?.supportsFullAcceptance == true else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "unsupported-full")
                return false
            }

            let verificationBaseline = insertionVerificationBaseline()
            guard let acceptance = suggestionSession.allVisibleAcceptancePreview() else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "no-visible-acceptance")
                return false
            }
            guard visibleAcceptanceMatchesDisplayedSuggestion(acceptance) else {
                setSuggestionDecision("Blocked: visible suggestion changed")
                hideSuggestion(reason: "visible-acceptance-mismatch")
                recordKeyboardAction(key: key, action: action, handled: false, reason: "visible-acceptance-mismatch")
                return false
            }
            guard insertAcceptedText(acceptance.acceptedText) else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "insert-failed")
                return false
            }

            let acceptedText = acceptance.acceptedText
            suggestionSession.commitAllVisibleAcceptance(acceptedText)
            recordAcceptedText(acceptedText)
            suggestionRepetitionSuppressor.recordAcceptance(
                acceptedText,
                mode: currentSuggestionRequestMode,
                scope: currentSuggestionAppBundleIdentifier ?? currentProfile?.bundleIdentifier ?? ""
            )
            recordRawAcceptance(action: action, acceptance: acceptance)
            setSuggestionDecision("Accepted: full suggestion")
            hideSuggestion(reason: "accepted-all")
            scheduleInsertionVerification(acceptedText: acceptedText, baseline: verificationBaseline)
            suppressKey(key)
            recordKeyboardAction(key: key, action: action, handled: true, reason: "accepted")
            return true

        case .dismiss:
            invalidatePendingSuggestionRequest()
            suppressCurrentField(reason: "escape")
            hideSuggestion(reason: "escape")
            suppressKey(key)
            recordKeyboardAction(key: key, action: action, handled: true, reason: "dismissed")
            return true

        case .undoAcceptedInsertion:
            recordKeyboardAction(key: key, action: action, handled: false, reason: "undo-unavailable")
            return false

        case .passThrough:
            if key != .other {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "pass-through")
            }
            return false
        }
    }

    private func currentSuggestionAcceptanceDecision() -> SuggestionAcceptanceDecision {
        guard let shownSnapshot = currentSuggestionAcceptanceSnapshot else {
            return .block(.missingShownSnapshot)
        }

        var blockReason: SuggestionAcceptanceBlockReason?
        guard let currentSnapshot = currentFocusedAcceptanceSnapshot(
            expected: shownSnapshot.fieldIdentity,
            blockReason: &blockReason
        ) else {
            return .block(blockReason ?? .missingCurrentSnapshot)
        }

        return suggestionAcceptanceGuard.decision(
            shown: shownSnapshot,
            current: currentSnapshot
        )
    }

    private func currentFocusedAcceptanceSnapshot(
        expected shownIdentity: FocusedFieldIdentity,
        blockReason: inout SuggestionAcceptanceBlockReason?
    ) -> SuggestionAcceptanceSnapshot? {
        guard let frontmostApp = accessibilityClient.frontmostApplication() else {
            return nil
        }

        guard frontmostApp.bundleIdentifier == shownIdentity.bundleIdentifier,
              frontmostApp.processIdentifier == shownIdentity.processIdentifier else {
            blockReason = .appChanged
            return nil
        }

        guard let profile = profileStore.profile(for: frontmostApp.bundleIdentifier),
              let rawContext = accessibilityClient.focusedTextContext(
                  allowDescendantTextFallback: profile.allowsDescendantTextFallback
              ) else {
            return nil
        }

        guard !rawContext.isSecure else {
            blockReason = .currentBecameSecure
            return nil
        }

        guard promptTextAreaMatch(
            for: frontmostApp.bundleIdentifier,
            context: rawContext
        ).canSuggest else {
            blockReason = .promptTargetChanged
            return nil
        }

        let context = presentationAdjustedContext(rawContext, app: frontmostApp, profile: profile)
        return SuggestionAcceptanceSnapshot(
            fieldIdentity: fieldIdentity(
                app: frontmostApp,
                context: context,
                profile: profile
            ),
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            selectedTextLength: context.selectedTextLength
        )
    }

    private func recordAcceptanceGuardBlock(reason: SuggestionAcceptanceBlockReason) {
        guard suggestionSession.hasVisibleSuggestion,
              let suggestionID = currentSuggestionID else {
            return
        }

        RawAutocompleteTraceLog.shared.record(
            type: .suggestionSuppressed,
            suggestionID: suggestionID,
            appBundleIdentifier: currentSuggestionAppBundleIdentifier ?? currentProfile?.bundleIdentifier ?? "",
            fieldIdentity: currentSuggestionFieldIdentity?.traceDescription ?? "",
            requestMode: currentSuggestionRequestMode?.rawValue ?? "",
            displayedText: currentSuggestionDisplayedText ?? suggestionSession.visibleSuggestion?.visibleText ?? "",
            reason: "wrong-app-or-field-before-accept",
            metadata: [
                "acceptanceGuardReason": reason.rawValue,
                "doNotShip": "true",
                "focusMismatch": String(reason.isFocusMismatch),
                "severe": "true"
            ]
        )
    }

    private func recordKeyboardAction(
        key: AutocompleteKey,
        action: KeyboardAction,
        handled: Bool,
        reason: String
    ) {
        DiagnosticsLog.shared.record(
            "keyboard-action",
            metadata: [
                "app": currentSuggestionAppBundleIdentifier ?? currentProfile?.bundleIdentifier ?? "unknown",
                "key": key.diagnosticName,
                "action": action.diagnosticName,
                "handled": String(handled),
                "reason": reason
            ]
        )
    }

    private func shouldSuppressKey(_ key: AutocompleteKey, isAutorepeat: Bool) -> Bool {
        guard isAutorepeat else {
            suppressKeyUntil[key] = nil
            return false
        }

        guard let until = suppressKeyUntil[key] else {
            return false
        }

        if until > Date() {
            return true
        }

        suppressKeyUntil[key] = nil
        return false
    }

    private func suppressKey(_ key: AutocompleteKey) {
        suppressKeyUntil[key] = Date().addingTimeInterval(0.25)
    }

    private func insertionVerificationBaseline() -> InsertionVerificationBaseline? {
        guard let currentFieldIdentity,
              let lastTextSnapshot,
              lastTextSnapshot.fieldIdentity == currentFieldIdentity,
              let profile = currentProfile else {
            return nil
        }

        return InsertionVerificationBaseline(
            fieldIdentity: currentFieldIdentity,
            previousTextBeforeCursor: lastTextSnapshot.textBeforeCursor,
            profile: profile,
            suggestionID: currentSuggestionID,
            requestMode: currentSuggestionRequestMode,
            retryCount: 0
        )
    }

    private func scheduleInsertionVerification(
        acceptedText: String,
        baseline: InsertionVerificationBaseline?
    ) {
        guard let baseline else {
            return
        }

        insertionVerificationTask?.cancel()
        insertionVerificationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else {
                return
            }

            guard let frontmostApp = accessibilityClient.frontmostApplication(),
                  let context = accessibilityClient.focusedTextContext(
                      allowDescendantTextFallback: baseline.profile.allowsDescendantTextFallback
                  ) else {
                DiagnosticsLog.shared.record(
                    "insert-verification",
                    metadata: [
                        "app": baseline.profile.bundleIdentifier,
                        "result": "missing-context"
                    ]
                )
                hideSuggestion()
                return
            }

            let currentIdentity = fieldIdentity(
                app: frontmostApp,
                context: context,
                profile: baseline.profile
            )

            guard currentIdentity == baseline.fieldIdentity else {
                return
            }

            let result = insertionVerification.verify(
                previousTextBeforeCursor: baseline.previousTextBeforeCursor,
                acceptedText: acceptedText,
                currentTextBeforeCursor: context.textBeforeCursor
            )

            DiagnosticsLog.shared.record(
                "insert-verification",
                metadata: [
                    "app": baseline.profile.bundleIdentifier,
                    "result": String(describing: result),
                    "acceptedChars": String(acceptedText.count),
                    "previousBeforeChars": String(baseline.previousTextBeforeCursor.count),
                    "currentBeforeChars": String(context.textBeforeCursor.count)
                ]
            )

            guard result.isVerified else {
                if insertionRetryPolicy.shouldRetry(
                    result: result,
                    insertionMode: baseline.profile.insertionMode,
                    retryCount: baseline.retryCount
                ) {
                    DiagnosticsLog.shared.record(
                        "insert-verification-retry",
                        metadata: [
                            "app": baseline.profile.bundleIdentifier,
                            "acceptedChars": String(acceptedText.count),
                            "retryCount": String(baseline.retryCount + 1),
                            "result": String(describing: result)
                        ]
                    )

                    let skippedModes = insertionRetrySkippedModes(
                        result: result,
                        profile: baseline.profile,
                        retryCount: baseline.retryCount
                    )
                    if insertAcceptedText(acceptedText, skippingInsertionModes: skippedModes) {
                        let retryBaseline = InsertionVerificationBaseline(
                            fieldIdentity: baseline.fieldIdentity,
                            previousTextBeforeCursor: baseline.previousTextBeforeCursor,
                            profile: baseline.profile,
                            suggestionID: baseline.suggestionID,
                            requestMode: baseline.requestMode,
                            retryCount: baseline.retryCount + 1
                        )
                        scheduleInsertionVerification(acceptedText: acceptedText, baseline: retryBaseline)
                        return
                    }
                }

                DiagnosticsLog.shared.record(
                    "insert-verification-final-failure",
                    metadata: [
                        "app": baseline.profile.bundleIdentifier,
                        "result": String(describing: result),
                        "acceptedChars": String(acceptedText.count),
                        "retryCount": String(baseline.retryCount)
                    ]
                )
                RawAutocompleteTraceLog.shared.record(
                    type: .insertionFailed,
                    suggestionID: baseline.suggestionID ?? "",
                    appBundleIdentifier: baseline.profile.bundleIdentifier,
                    fieldIdentity: baseline.fieldIdentity.traceDescription,
                    requestMode: baseline.requestMode?.rawValue ?? "",
                    acceptedText: acceptedText,
                    outcome: String(describing: result),
                    reason: "insert-verification-failed",
                    metadata: [
                        "previousBeforeChars": String(baseline.previousTextBeforeCursor.count),
                        "currentBeforeChars": String(context.textBeforeCursor.count)
                    ]
                )
                if baseline.profile.suppressesAfterInsertionFailure {
                    suppressCurrentField(reason: "insert-verification-failed")
                }
                hideSuggestion()
                return
            }

            if baseline.retryCount > 0 {
                DiagnosticsLog.shared.record(
                    "insert-verification-recovered",
                    metadata: [
                        "app": baseline.profile.bundleIdentifier,
                        "acceptedChars": String(acceptedText.count),
                        "retryCount": String(baseline.retryCount)
                    ]
                )
            }
            RawAutocompleteTraceLog.shared.record(
                type: .insertionVerified,
                suggestionID: baseline.suggestionID ?? "",
                appBundleIdentifier: baseline.profile.bundleIdentifier,
                fieldIdentity: baseline.fieldIdentity.traceDescription,
                requestMode: baseline.requestMode?.rawValue ?? "",
                acceptedText: acceptedText,
                outcome: "verified"
            )
            recordAnnoyance(
                .acceptedAndKept,
                appBundleIdentifier: baseline.profile.bundleIdentifier,
                fieldIdentity: baseline.fieldIdentity,
                requestMode: baseline.requestMode
            )
        }
    }

    private func scheduleSuggestion(
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity,
        renderMode: SuggestionRenderMode,
        delayMilliseconds: Int,
        requestMode: CompletionRequestMode
    ) {
        lastRequestedTextBeforeCursor = context.textBeforeCursor

        let suggestionID = UUID().uuidString
        let request = CompletionRequest(
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            appBundleIdentifier: appBundleIdentifier,
            maxVisibleWords: completionLengthConfiguration.maxVisibleWords,
            mode: requestMode,
            suggestionID: suggestionID
        )
        currentCompletionRequest = request
        streamingPresentationStates[suggestionID] = StreamingPresentationState()
        let requestTicket = suggestionRequestGate.issue(request: request)
        let requestStartedAt = Date()
        let fieldIdentityDescription = fieldIdentity.traceDescription

        RawAutocompleteTraceLog.shared.record(
            type: .suggestionRequested,
            suggestionID: suggestionID,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentityDescription,
            requestMode: request.mode.rawValue,
            triggerReason: "poll",
            textBeforeCursor: request.textBeforeCursor,
            textAfterCursor: request.textAfterCursor,
            metadata: [
                "renderMode": renderMode.rawValue,
                "delayMilliseconds": String(delayMilliseconds)
            ]
        )

        if requestMode == .wordCompletion {
            if let fastSuggestion = wordCompletionRanker.suggestion(
                for: context.textBeforeCursor,
                recentWords: recentWordMemory.words(for: appBundleIdentifier)
            ) {
                guard !suggestionRepetitionSuppressor.shouldSuppress(
                    fastSuggestion.visibleText,
                    mode: request.mode,
                    scope: appBundleIdentifier
                ) else {
                    RawAutocompleteTraceLog.shared.record(
                        type: .suggestionSuppressed,
                        suggestionID: suggestionID,
                        appBundleIdentifier: appBundleIdentifier,
                        fieldIdentity: fieldIdentityDescription,
                        requestMode: request.mode.rawValue,
                        triggerReason: "fast-word-completion",
                        textBeforeCursor: request.textBeforeCursor,
                        textAfterCursor: request.textAfterCursor,
                        cleanedVisibleText: fastSuggestion.visibleText,
                        displayedText: fastSuggestion.visibleText,
                        latencyMilliseconds: 0,
                        reason: "repeated-miss",
                        metadata: [
                            "renderMode": renderMode.rawValue
                        ]
                    )
                    recordSuggestionEvent(
                        "suggestion-blocked",
                        context: context,
                        profile: profile,
                        metadata: [
                            "reason": "repeated-miss",
                            "triggerReason": "fast-word-completion"
                        ]
                    )
                    hideSuggestion()
                    return
                }

                presentSuggestion(
                    fastSuggestion,
                    suggestionID: suggestionID,
                    request: request,
                    context: context,
                    profile: profile,
                    fieldIdentity: fieldIdentity,
                    renderMode: renderMode,
                    latencyMilliseconds: 0,
                    triggerReason: "fast-word-completion"
                )
                return
            }

            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: suggestionID,
                appBundleIdentifier: appBundleIdentifier,
                fieldIdentity: fieldIdentityDescription,
                requestMode: request.mode.rawValue,
                triggerReason: "fast-word-completion",
                textBeforeCursor: request.textBeforeCursor,
                textAfterCursor: request.textAfterCursor,
                reason: "no-fast-word-candidate",
                metadata: [
                    "renderMode": renderMode.rawValue
                ]
            )
            if suggestionSession.hasVisibleSuggestion {
                setSuggestionDecision("Shown: no fast word replacement")
                repositionVisibleSuggestion(context: context, profile: profile)
                return
            }

            hideSuggestion()
            return
        }

        debounceTask = Task { [engine, requestTicket, fieldIdentity] in
            let renderDelay = renderMode == .inlineAdjacent ? delayMilliseconds : max(delayMilliseconds, 60)
            try? await Task.sleep(for: .milliseconds(renderDelay))
            guard !Task.isCancelled else {
                return
            }

            do {
                let suggestion = try await engine.suggestion(
                    for: request,
                    onPartialSuggestion: { partialSuggestion in
                        Task { @MainActor in
                            let latencyMilliseconds = max(0, Int(Date().timeIntervalSince(requestStartedAt) * 1000))
                            guard self.suggestionRequestGate.allows(
                                requestTicket,
                                currentRequest: self.currentCompletionRequest
                            ), self.currentFieldIdentity == fieldIdentity else {
                                return
                            }

                            guard !partialSuggestion.isEmpty,
                                  !self.suggestionRepetitionSuppressor.shouldSuppress(
                                      partialSuggestion.visibleText,
                                      mode: request.mode,
                                      scope: appBundleIdentifier
                                  ) else {
                                return
                            }

                            var streamingState = self.streamingPresentationStates[suggestionID]
                                ?? StreamingPresentationState()
                            guard self.suggestionPresentationGate.shouldPresentStreamingPartial(
                                partialSuggestion,
                                mode: request.mode,
                                state: &streamingState,
                                nowMilliseconds: Int(ProcessInfo.processInfo.systemUptime * 1000)
                            ) else {
                                return
                            }
                            self.streamingPresentationStates[suggestionID] = streamingState

                            self.presentSuggestion(
                                partialSuggestion,
                                suggestionID: suggestionID,
                                request: request,
                                context: context,
                                profile: profile,
                                fieldIdentity: fieldIdentity,
                                renderMode: renderMode,
                                latencyMilliseconds: latencyMilliseconds,
                                triggerReason: "model-stream"
                            )
                        }
                    }
                )
                await MainActor.run {
                    let latencyMilliseconds = max(0, Int(Date().timeIntervalSince(requestStartedAt) * 1000))
                    guard self.suggestionRequestGate.allows(
                        requestTicket,
                        currentRequest: self.currentCompletionRequest
                    ), self.currentFieldIdentity == fieldIdentity else {
                        return
                    }

                    let anchorRect = RenderModePlan.anchorRect(
                        for: renderMode,
                        caretRect: context.caretRect,
                        elementRect: context.elementRect,
                        windowRect: context.windowRect
                    )
                    guard let suggestion, !suggestion.isEmpty else {
                        RawAutocompleteTraceLog.shared.record(
                            type: .suggestionSuppressed,
                            suggestionID: suggestionID,
                            appBundleIdentifier: appBundleIdentifier,
                            fieldIdentity: fieldIdentityDescription,
                            requestMode: request.mode.rawValue,
                            triggerReason: "model-result",
                            textBeforeCursor: request.textBeforeCursor,
                            textAfterCursor: request.textAfterCursor,
                            latencyMilliseconds: latencyMilliseconds,
                            reason: "empty-suggestion"
                        )
                        self.recordSuggestionEvent(
                            "suggestion-blocked",
                            context: context,
                            profile: profile,
                            metadata: [
                                "reason": "empty-suggestion"
                            ]
                        )
                        self.hideSuggestion()
                        return
                    }

                    guard anchorRect != nil else {
                        RawAutocompleteTraceLog.shared.record(
                            type: .suggestionSuppressed,
                            suggestionID: suggestionID,
                            appBundleIdentifier: appBundleIdentifier,
                            fieldIdentity: fieldIdentityDescription,
                            requestMode: request.mode.rawValue,
                            triggerReason: "model-result",
                            textBeforeCursor: request.textBeforeCursor,
                            textAfterCursor: request.textAfterCursor,
                            cleanedVisibleText: suggestion.visibleText,
                            displayedText: suggestion.visibleText,
                            latencyMilliseconds: latencyMilliseconds,
                            reason: "missing-anchor"
                        )
                        self.recordSuggestionEvent(
                            "suggestion-blocked",
                            context: context,
                            profile: profile,
                            metadata: [
                                "reason": "missing-anchor"
                            ]
                        )
                        self.hideSuggestion()
                        return
                    }

                    RawAutocompleteTraceLog.shared.record(
                        type: .modelResult,
                        suggestionID: suggestionID,
                        appBundleIdentifier: appBundleIdentifier,
                        fieldIdentity: fieldIdentityDescription,
                        requestMode: request.mode.rawValue,
                        triggerReason: "model-result",
                        textBeforeCursor: request.textBeforeCursor,
                        textAfterCursor: request.textAfterCursor,
                        cleanedVisibleText: suggestion.visibleText,
                        displayedText: suggestion.visibleText,
                        latencyMilliseconds: latencyMilliseconds
                    )
                    guard !self.suggestionRepetitionSuppressor.shouldSuppress(
                        suggestion.visibleText,
                        mode: request.mode,
                        scope: appBundleIdentifier
                    ) else {
                        RawAutocompleteTraceLog.shared.record(
                            type: .suggestionSuppressed,
                            suggestionID: suggestionID,
                            appBundleIdentifier: appBundleIdentifier,
                            fieldIdentity: fieldIdentityDescription,
                            requestMode: request.mode.rawValue,
                            triggerReason: "model-result",
                            textBeforeCursor: request.textBeforeCursor,
                            textAfterCursor: request.textAfterCursor,
                            cleanedVisibleText: suggestion.visibleText,
                            displayedText: suggestion.visibleText,
                            latencyMilliseconds: latencyMilliseconds,
                            reason: "repeated-miss"
                        )
                        self.hideSuggestion()
                        return
                    }
                    self.presentSuggestion(
                        suggestion,
                        suggestionID: suggestionID,
                        request: request,
                        context: context,
                        profile: profile,
                        fieldIdentity: fieldIdentity,
                        renderMode: renderMode,
                        latencyMilliseconds: latencyMilliseconds,
                        triggerReason: "model-result"
                    )
                    self.streamingPresentationStates[suggestionID] = nil
                }
            } catch {
                await MainActor.run {
                    self.streamingPresentationStates[suggestionID] = nil
                    self.hideSuggestion(reason: "engine-error")
                }
            }
        }
    }

    private func presentSuggestion(
        _ suggestion: CompletionSuggestion,
        suggestionID: String,
        request: CompletionRequest,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        renderMode: SuggestionRenderMode,
        latencyMilliseconds: Int,
        triggerReason: String
    ) {
        let originalContext = context
        let refreshedContext = refreshedPresentationContext(
            for: request,
            profile: profile,
            fieldIdentity: fieldIdentity
        )
        guard let context = refreshedContext.context else {
            let reason = refreshedContext.reason ?? "stale-focused-context"
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: suggestionID,
                appBundleIdentifier: request.appBundleIdentifier ?? profile.bundleIdentifier,
                fieldIdentity: fieldIdentity.traceDescription,
                requestMode: request.mode.rawValue,
                triggerReason: triggerReason,
                textBeforeCursor: request.textBeforeCursor,
                textAfterCursor: request.textAfterCursor,
                displayedText: suggestion.visibleText,
                latencyMilliseconds: latencyMilliseconds,
                reason: reason,
                metadata: traceGeometryMetadata(context: originalContext, renderMode: renderMode)
            )
            recordSuggestionEvent(
                "suggestion-blocked",
                context: originalContext,
                profile: profile,
                metadata: [
                    "reason": reason
                ]
            )
            hideSuggestion(reason: reason)
            return
        }

        let presentationBundleIdentifier = request.appBundleIdentifier ?? profile.bundleIdentifier
        let visualScope = compatibilityVisualScope(
            bundleIdentifier: presentationBundleIdentifier,
            context: context
        )
        let confidenceDecision = confidencePolicy.decision(
            suggestion: suggestion,
            mode: request.mode,
            textBeforeCursor: context.textBeforeCursor,
            latencyMilliseconds: latencyMilliseconds,
            supportLevel: profile.supportLevel
        )
        guard confidenceDecision.canDisplay else {
            let reason = "low-confidence"
            setSuggestionDecision("Blocked: \(reason)")
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: suggestionID,
                appBundleIdentifier: request.appBundleIdentifier ?? profile.bundleIdentifier,
                fieldIdentity: fieldIdentity.traceDescription,
                requestMode: request.mode.rawValue,
                triggerReason: triggerReason,
                textBeforeCursor: request.textBeforeCursor,
                textAfterCursor: request.textAfterCursor,
                displayedText: suggestion.visibleText,
                latencyMilliseconds: latencyMilliseconds,
                reason: reason,
                metadata: [
                    "confidenceBucket": confidenceDecision.bucket.rawValue,
                    "confidenceScore": String(confidenceDecision.score),
                    "confidenceReasons": confidenceDecision.reasons.joined(separator: ",")
                ]
            )
            recordSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                metadata: [
                    "reason": reason,
                    "confidenceBucket": confidenceDecision.bucket.rawValue,
                    "confidenceScore": String(confidenceDecision.score),
                    "confidenceReasons": confidenceDecision.reasons.joined(separator: ",")
                ]
            )
            hideSuggestion(reason: reason)
            return
        }

        let learningAdjustment = compatibilityLearningStore.engine().adjustment(
            for: profile.bundleIdentifier,
            profileRenderMode: renderMode
        ).trustedVisualOffsetOnly(matching: visualScope)
        let placementPlan = placementHealthPlan(
            context: context,
            profile: profile,
            learningAdjustment: learningAdjustment
        )

        guard case let .present(placement) = placementPlan else {
            let suppression: PlacementHealthSuppression
            if case let .suppress(value) = placementPlan {
                suppression = value
            } else {
                suppression = PlacementHealthSuppression(
                    requestedRenderMode: learningAdjustment.effectiveRenderMode,
                    reason: .missingAnchor
                )
            }
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: suggestionID,
                appBundleIdentifier: request.appBundleIdentifier ?? profile.bundleIdentifier,
                fieldIdentity: fieldIdentity.traceDescription,
                requestMode: request.mode.rawValue,
                triggerReason: triggerReason,
                textBeforeCursor: request.textBeforeCursor,
                textAfterCursor: request.textAfterCursor,
                displayedText: suggestion.visibleText,
                latencyMilliseconds: latencyMilliseconds,
                reason: suppression.reason.rawValue,
                metadata: traceGeometryMetadata(context: context, renderMode: learningAdjustment.effectiveRenderMode)
                    .merging(learningAdjustment.metadata) { current, _ in current }
                    .merging(suppression.metadata) { current, _ in current }
            )
            recordSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                metadata: [
                    "reason": suppression.reason.rawValue
                ]
                .merging(learningAdjustment.metadata) { current, _ in current }
                .merging(suppression.metadata) { current, _ in current }
            )
            let uncertainty = recordPlacementUncertainty(
                reason: suppression.reason.rawValue,
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                metadata: learningAdjustment.metadata
                    .merging(suppression.metadata) { current, _ in current }
            )
            hideSuggestion(
                reason: uncertainty.shouldSuppressField
                    ? "repeated-placement-uncertainty"
                    : "placement-\(suppression.reason.rawValue)"
            )
            return
        }

        let presentationAttempt = SuggestionPanelPresentationPolicy.attempt(
            initialPlacement: placement,
            fallbackRenderMode: profile.fallbackRenderMode
        ) { activePlacement in
            suggestionPanel.show(
                text: suggestion.visibleText,
                near: activePlacement.anchorRect,
                alignedTo: activePlacement.renderMode == .inlineAdjacent ? activePlacement.textLineRect : nil,
                boundedBy: activePlacement.clippingRect,
                style: context.textStyle,
                renderMode: activePlacement.renderMode
            )
        }
        let activePlacement = presentationAttempt.placement

        guard let panelRect = presentationAttempt.panelRect else {
            let failureReason = presentationAttempt.failureReason
                ?? SuggestionPanelPresentationPolicy.panelFrameUnusableReason
            setSuggestionDecision("Blocked: \(failureReason)")
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: suggestionID,
                appBundleIdentifier: request.appBundleIdentifier ?? profile.bundleIdentifier,
                fieldIdentity: fieldIdentity.traceDescription,
                requestMode: request.mode.rawValue,
                triggerReason: triggerReason,
                textBeforeCursor: request.textBeforeCursor,
                textAfterCursor: request.textAfterCursor,
                displayedText: suggestion.visibleText,
                latencyMilliseconds: latencyMilliseconds,
                reason: failureReason,
                metadata: traceGeometryMetadata(context: context, renderMode: activePlacement.renderMode)
                    .merging(learningAdjustment.metadata) { current, _ in current }
                    .merging(activePlacement.metadata) { current, _ in current }
            )
            recordSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                metadata: [
                    "reason": failureReason
                ]
                .merging(learningAdjustment.metadata) { current, _ in current }
                .merging(activePlacement.metadata) { current, _ in current }
            )
            _ = recordPlacementUncertainty(
                reason: failureReason,
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                metadata: learningAdjustment.metadata
                    .merging(activePlacement.metadata) { current, _ in current }
            )
            hideSuggestion(reason: failureReason)
            return
        }

        lastCaretRect = activePlacement.anchorRect
        lastTextLineRect = activePlacement.textLineRect
        lastClippingRect = activePlacement.clippingRect
        lastTextStyle = context.textStyle
        lastRenderMode = activePlacement.renderMode

        placementUncertaintySuppressor.reset(fieldIdentifier: fieldIdentity.traceDescription)
        suggestionSession.present(suggestion)
        setSuggestionDecision("Shown: \(triggerReason) \(latencyMilliseconds)ms")
        currentSuggestionID = suggestionID
        currentSuggestionAppBundleIdentifier = presentationBundleIdentifier
        currentSuggestionFieldIdentity = fieldIdentity
        currentSuggestionVisualScope = visualScope
        currentSuggestionRequestMode = request.mode
        currentSuggestionTextBeforeCursor = request.textBeforeCursor
        currentSuggestionAcceptanceSnapshot = SuggestionAcceptanceSnapshot(
            fieldIdentity: fieldIdentity,
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            selectedTextLength: context.selectedTextLength
        )
        currentSuggestionDisplayedText = suggestion.visibleText
        currentSuggestionInvalidatedByUserKeyDown = false
        keyboardEventTap?.resetPassthroughObservation()
        updateKeyboardEventTapSnapshot()
        guard startKeyboardEventTapIfPossible() else {
            setSuggestionDecision("Blocked: keyboard capture unavailable")
            hideSuggestion(reason: "keyboard-capture-unavailable")
            return
        }

        let screenshotCapture = captureTraceScreenshot(
            around: [
                activePlacement.anchorRect,
                activePlacement.textLineRect,
                panelRect,
                activePlacement.clippingRect
            ].compactMap { $0 },
            suggestionID: suggestionID,
            bundleIdentifier: request.appBundleIdentifier ?? profile.bundleIdentifier,
            triggerReason: triggerReason,
            appScreenshotTracingEnabled: learningAdjustment.shouldCaptureScreenshot
        )
        compatibilityLearningStore.recordObservation(
            for: profile.bundleIdentifier,
            reason: "suggestion-presented"
        )
        RawAutocompleteTraceLog.shared.record(
            type: .suggestionPresented,
            suggestionID: suggestionID,
            appBundleIdentifier: request.appBundleIdentifier ?? profile.bundleIdentifier,
            fieldIdentity: fieldIdentity.traceDescription,
            requestMode: request.mode.rawValue,
            triggerReason: triggerReason,
            textBeforeCursor: request.textBeforeCursor,
            textAfterCursor: request.textAfterCursor,
            cleanedVisibleText: suggestion.visibleText,
            displayedText: suggestion.visibleText,
            latencyMilliseconds: latencyMilliseconds,
            screenshotPath: screenshotCapture.path,
            metadata: [
                "effectiveRenderMode": activePlacement.renderMode.rawValue,
                "visibleChars": String(suggestion.visibleText.count),
                "visibleWords": String(suggestion.visibleWordCount),
                "anchorRect": compactRectDescription(activePlacement.anchorRect),
                "textLineRect": activePlacement.textLineRect.map(compactRectDescription) ?? "none",
                "suggestionPanelRect": compactRectDescription(panelRect),
                "clippingRect": activePlacement.clippingRect.map(compactRectDescription) ?? "none",
                "screenshotCaptureRect": screenshotCapture.rectDescription
            ]
            .merging(traceGeometryMetadata(context: context, renderMode: activePlacement.renderMode)) { current, _ in current }
            .merging(learningAdjustment.metadata) { current, _ in current }
            .merging(activePlacement.metadata) { current, _ in current }
        )
        recordSuggestionEvent(
            "suggestion-presented",
            context: context,
            profile: profile,
            metadata: [
                "effectiveRenderMode": activePlacement.renderMode.rawValue,
                "requestMode": request.mode.rawValue,
                "traceID": String(suggestionID.prefix(8)),
                "visibleChars": String(suggestion.visibleText.count),
                "visibleWords": String(suggestion.visibleWordCount),
                "suggestionID": suggestionID,
                "latencyMilliseconds": String(latencyMilliseconds),
                "anchorRect": compactRectDescription(activePlacement.anchorRect),
                "textLineRect": activePlacement.textLineRect.map(compactRectDescription) ?? "none",
                "suggestionPanelRect": compactRectDescription(panelRect),
                "clippingRect": activePlacement.clippingRect.map(compactRectDescription) ?? "none",
                "screenshotCaptureRect": screenshotCapture.rectDescription
            ]
            .merging(learningAdjustment.metadata) { current, _ in current }
            .merging(activePlacement.metadata) { current, _ in current }
        )
        updateKeyboardEventTapSnapshot()
    }

    private func refreshedPresentationContext(
        for request: CompletionRequest,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity
    ) -> (context: FocusedTextContext?, reason: String?) {
        let expectedBundleIdentifier = request.appBundleIdentifier ?? profile.bundleIdentifier
        guard let frontmostApp = accessibilityClient.frontmostApplication(),
              frontmostApp.bundleIdentifier == expectedBundleIdentifier else {
            return (nil, "stale-app")
        }

        guard let rawContext = accessibilityClient.focusedTextContext(
            allowDescendantTextFallback: profile.allowsDescendantTextFallback
        ), !rawContext.isSecure,
           rawContext.selectedTextLength == 0 else {
            return (nil, "stale-focused-context")
        }

        guard promptTextAreaMatch(
            for: frontmostApp.bundleIdentifier,
            context: rawContext
        ).canSuggest else {
            return (nil, "stale-prompt-target")
        }

        let context = presentationAdjustedContext(
            rawContext,
            app: frontmostApp,
            profile: profile
        )
        guard self.fieldIdentity(
            app: frontmostApp,
            context: context,
            profile: profile
        ) == fieldIdentity else {
            return (nil, "stale-field")
        }

        guard context.textBeforeCursor == request.textBeforeCursor,
              context.textAfterCursor == request.textAfterCursor else {
            return (nil, "stale-text")
        }

        return (context, nil)
    }

    private func placementHealthPlan(
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        learningAdjustment: CompatibilityLearningAdjustment
    ) -> PlacementHealthPlan {
        PlacementHealth.plan(
            requestedRenderMode: learningAdjustment.effectiveRenderMode,
            fallbackRenderMode: profile.fallbackRenderMode,
            caretRect: learningAdjustment.adjusted(context.caretRect),
            elementRect: learningAdjustment.adjusted(context.elementRect),
            windowRect: learningAdjustment.adjusted(context.windowRect),
            textLineRect: learningAdjustment.adjusted(context.textLineRect),
            caretIsSynthetic: context.caretIsSynthetic,
            allowsDetachedSuggestions: profile.allowsDetachedSuggestions,
            trustPolicy: placementTrustPolicy(profile: profile, learningAdjustment: learningAdjustment)
        )
    }

    private func placementTrustPolicy(
        profile: CompatibilityProfile,
        learningAdjustment: CompatibilityLearningAdjustment
    ) -> PlacementTrustPolicy {
        .compatibility(profile: profile, learningAdjustment: learningAdjustment)
    }

    private func captureTraceScreenshot(
        around rects: [CGRect],
        suggestionID: String,
        bundleIdentifier: String,
        triggerReason: String,
        appScreenshotTracingEnabled: Bool
    ) -> TraceScreenshotCapture {
        guard let captureRect = ScreenshotCaptureRegion.enclosing(rects) else {
            return .none
        }

        if scheduledScreenshotSuggestionIDs.count >= maxScheduledScreenshotSuggestionIDs {
            scheduledScreenshotSuggestionIDs.removeAll(keepingCapacity: true)
        }

        let globalScreenshotTracingEnabled = RawAutocompleteTraceLog.shared.screenshotTracingEnabled
        guard screenshotTraceCapturePolicy.shouldCapture(
            triggerReason: triggerReason,
            globalScreenshotTracingEnabled: globalScreenshotTracingEnabled,
            appScreenshotTracingEnabled: appScreenshotTracingEnabled,
            hasCaptureRegion: true,
            hasAlreadyCapturedSuggestionID: scheduledScreenshotSuggestionIDs.contains(suggestionID)
        ) else {
            return .none
        }
        scheduledScreenshotSuggestionIDs.insert(suggestionID)

        let folderURL = RawAutocompleteTraceLog.shared.screenshotFolderURL
        let screenshotURL = folderURL.appendingPathComponent("\(suggestionID).png")

        ScreenshotTraceCapture.shared.capture(
            rect: captureRect,
            to: screenshotURL,
            bundleIdentifier: bundleIdentifier
        )
        return TraceScreenshotCapture(
            path: screenshotURL.path,
            rectDescription: compactRectDescription(captureRect)
        )
    }

    private func traceGeometryMetadata(
        context: FocusedTextContext,
        renderMode: SuggestionRenderMode
    ) -> [String: String] {
        [
            "effectiveRenderMode": renderMode.rawValue,
            "hasCaretRect": String(context.caretRect != nil),
            "caretIsSynthetic": String(context.caretIsSynthetic),
            "hasElementRect": String(context.elementRect != nil),
            "hasWindowRect": String(context.windowRect != nil),
            "canReadBounds": String(context.capabilities.canReadBoundsForRange)
        ]
        .merging(context.fieldClassification.traceMetadata) { current, _ in current }
    }

    private func blockSuggestionForPlacementPreflight(
        suppression: PlacementHealthSuppression,
        requestMode: CompletionRequestMode,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        learningAdjustment: CompatibilityLearningAdjustment
    ) {
        let reason = suppression.reason.rawValue
        let metadata = traceGeometryMetadata(
            context: context,
            renderMode: learningAdjustment.effectiveRenderMode
        )
        .merging(learningAdjustment.metadata) { current, _ in current }
        .merging(suppression.metadata) { current, _ in current }

        setSuggestionDecision(
            suppression.reason == .detachedSuggestionDisabled
                ? "Blocked: detached suggestion disabled"
                : "Blocked: placement \(reason)"
        )
        RawAutocompleteTraceLog.shared.record(
            type: .suggestionSuppressed,
            suggestionID: UUID().uuidString,
            appBundleIdentifier: profile.bundleIdentifier,
            fieldIdentity: fieldIdentity.traceDescription,
            requestMode: requestMode.rawValue,
            triggerReason: "placement-preflight",
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            reason: reason,
            metadata: metadata
        )
        recordBlockedSuggestionEvent(
            "suggestion-blocked",
            context: context,
            profile: profile,
            fieldIdentity: fieldIdentity,
            metadata: ["reason": reason]
                .merging(learningAdjustment.metadata) { current, _ in current }
                .merging(suppression.metadata) { current, _ in current }
        )
        _ = recordPlacementUncertainty(
            reason: reason,
            context: context,
            profile: profile,
            fieldIdentity: fieldIdentity,
            metadata: metadata
        )
        hideSuggestion()
    }

    private func recordSuggestionEvent(
        _ event: String,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        metadata: [String: String] = [:]
    ) {
        var safeMetadata = metadata
        safeMetadata["app"] = profile.bundleIdentifier
        safeMetadata["renderMode"] = profile.renderMode.rawValue
        safeMetadata["insertionMode"] = profile.insertionMode.rawValue
        safeMetadata["promptSafetyMode"] = profile.promptAppSafetyMode.rawValue
        safeMetadata["fieldIdentityMode"] = profile.fieldIdentityMode.rawValue
        safeMetadata["role"] = context.role ?? "unknown"
        safeMetadata["subrole"] = context.subrole ?? "none"
        safeMetadata["beforeChars"] = String(context.textBeforeCursor.count)
        safeMetadata["afterChars"] = String(context.textAfterCursor.count)
        safeMetadata["fieldKind"] = context.fieldClassification.kind.rawValue
        safeMetadata["fieldKindReason"] = context.fieldClassification.reason
        safeMetadata["fieldKindSuppressed"] = String(context.fieldClassification.suppressesSuggestionsByDefault)
        safeMetadata["hasCaretRect"] = String(context.caretRect != nil)
        safeMetadata["hasElementRect"] = String(context.elementRect != nil)
        safeMetadata["hasWindowRect"] = String(context.windowRect != nil)
        safeMetadata["canReadValue"] = String(context.capabilities.canReadValue)
        safeMetadata["canReadRange"] = String(context.capabilities.canReadSelectedTextRange)
        safeMetadata["canReadBounds"] = String(context.capabilities.canReadBoundsForRange)
        safeMetadata["canSetSelectedText"] = String(context.capabilities.canSetSelectedText)

        DiagnosticsLog.shared.record(event, metadata: safeMetadata)
    }

    private func activationBlockDecisionText(
        _ decision: CompletionActivationDecision,
        fieldClassification: AXFieldClassification
    ) -> String {
        guard case .block(.blockedFieldKind) = decision else {
            return decision.blockReasonDescription
        }

        switch fieldClassification.kind {
        case .search:
            return "search field"
        case .form:
            return "form field"
        case .secure:
            return "secure field"
        case .url:
            return "URL field"
        case .unprovenSurface:
            return "unproven surface"
        case .multilineCompose, .singlelineCompose, .unknown:
            return "blocked field kind"
        }
    }

    @discardableResult
    private func recordPlacementUncertainty(
        reason: String,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        metadata: [String: String] = [:]
    ) -> PlacementUncertaintyDecision {
        let decision = placementUncertaintySuppressor.record(
            reason: reason,
            fieldIdentifier: fieldIdentity.traceDescription
        )
        var uncertaintyMetadata = metadata
            .merging(decision.metadata) { current, _ in current }
        uncertaintyMetadata["reason"] = reason

        recordSuggestionEvent(
            "placement-uncertainty",
            context: context,
            profile: profile,
            metadata: uncertaintyMetadata
        )

        guard decision.shouldSuppressField else {
            return decision
        }

        suppressedFieldIdentities.insert(fieldIdentity)
        setSuggestionDecision("Blocked: repeated placement uncertainty")
        var suppressionMetadata = uncertaintyMetadata
        suppressionMetadata["reason"] = "repeated-placement-uncertainty"
        recordSuggestionEvent(
            "suggestion-blocked",
            context: context,
            profile: profile,
            metadata: suppressionMetadata
        )

        return decision
    }

    private func recordBlockedSuggestionEvent(
        _ event: String,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        metadata: [String: String] = [:]
    ) {
        let signature = blockedSuggestionSignature(
            context: context,
            profile: profile,
            fieldIdentity: fieldIdentity,
            metadata: metadata
        )

        guard suggestionBlockLogGate.shouldRecord(signature: signature) else {
            return
        }

        recordSuggestionEvent(event, context: context, profile: profile, metadata: metadata)
    }

    private func blockedSuggestionSignature(
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        metadata: [String: String]
    ) -> String {
        [
            profile.bundleIdentifier,
            String(fieldIdentity.processIdentifier),
            String(fieldIdentity.elementIdentifier),
            metadata["reason"] ?? "unknown",
            metadata["readinessStage"] ?? "none",
            String(context.textBeforeCursor.count),
            String(context.textAfterCursor.count)
        ].joined(separator: "|")
    }

    private func fieldIdentity(
        app: RunningApplicationInfo,
        context: FocusedTextContext,
        profile: CompatibilityProfile
    ) -> FocusedFieldIdentity {
        focusedFieldIdentityPolicy.identity(
            bundleIdentifier: app.bundleIdentifier,
            processIdentifier: app.processIdentifier,
            mode: profile.fieldIdentityMode,
            input: FocusedFieldIdentityInput(context: context)
        )
    }

    private func insertionRetrySkippedModes(
        result: InsertionVerificationResult,
        profile: CompatibilityProfile,
        retryCount: Int
    ) -> Set<InsertionMode> {
        guard result == .unchanged,
              retryCount == 0,
              profile.fallbackInsertionMode != nil else {
            return []
        }

        return [profile.insertionMode]
    }

    private func insertAcceptedText(
        _ acceptedText: String,
        skippingInsertionModes skippedModes: Set<InsertionMode> = []
    ) -> Bool {
        guard let profile = currentProfile else {
            setSuggestionDecision("Blocked: missing compatibility profile")
            DiagnosticsLog.shared.record(
                "insert-blocked",
                metadata: [
                    "reason": "missing-compatibility-profile",
                    "acceptedChars": String(acceptedText.count)
                ]
            )
            RawAutocompleteTraceLog.shared.record(
                type: .insertionFailed,
                suggestionID: currentSuggestionID ?? "",
                appBundleIdentifier: currentSuggestionAppBundleIdentifier ?? "",
                fieldIdentity: currentSuggestionFieldIdentity?.traceDescription
                    ?? currentFieldIdentity?.traceDescription
                    ?? "",
                requestMode: currentSuggestionRequestMode?.rawValue ?? "",
                acceptedText: acceptedText,
                reason: "missing-compatibility-profile",
                metadata: [
                    "safetyGate": "compatibilityProfile"
                ]
            )
            hideSuggestion(reason: "insert-missing-compatibility-profile")
            return false
        }

        let safetyDecision = acceptedTextSafetyPolicy.decision(
            acceptedText: acceptedText,
            profile: profile
        )
        guard safetyDecision.canInsert else {
            let reason = safetyDecision.blockReason ?? "accepted-text-blocked"
            setSuggestionDecision("Blocked: \(reason)")
            DiagnosticsLog.shared.record(
                "insert-blocked",
                metadata: [
                    "app": profile.bundleIdentifier,
                    "reason": reason,
                    "acceptedChars": String(acceptedText.count),
                    "profileInsertionMode": profile.insertionMode.rawValue
                ]
            )
            RawAutocompleteTraceLog.shared.record(
                type: .insertionFailed,
                suggestionID: currentSuggestionID ?? "",
                appBundleIdentifier: profile.bundleIdentifier,
                fieldIdentity: currentSuggestionFieldIdentity?.traceDescription
                    ?? currentFieldIdentity?.traceDescription
                    ?? "",
                requestMode: currentSuggestionRequestMode?.rawValue ?? "",
                acceptedText: acceptedText,
                reason: reason,
                metadata: [
                    "profileInsertionMode": profile.insertionMode.rawValue,
                    "promptSafetyMode": profile.promptAppSafetyMode.rawValue,
                    "safetyGate": "acceptedText"
                ]
            )
            hideSuggestion(reason: "insert-\(reason)")
            return false
        }

        keyboardEventTap?.suppressPassthroughObservation(
            until: Date().addingTimeInterval(0.25)
        )

        let result = insertionEngine.insert(
            acceptedText,
            profile: profile,
            skipping: skippedModes
        )
        DiagnosticsLog.shared.record(
            "insert",
            metadata: [
                "app": profile.bundleIdentifier,
                "mode": result.mode.rawValue,
                "promptSafetyMode": profile.promptAppSafetyMode.rawValue,
                "success": String(result.succeeded),
                "skippedModes": skippedModes
                    .map(\.rawValue)
                    .sorted()
                    .joined(separator: ",")
            ]
        )

        if result.succeeded {
            focusedTextPollingPause.pause(
                now: Date(),
                durationMilliseconds: postInsertionPollPauseMilliseconds
            )
        }

        return result.succeeded
    }

    private func recordRawAcceptance(action: KeyboardAction, acceptance: SuggestionAcceptancePreview) {
        guard let appBundleIdentifier = currentSuggestionAppBundleIdentifier ?? currentProfile?.bundleIdentifier else {
            return
        }

        var metadata = acceptance.traceMetadata
        metadata["acceptMode"] = action == .acceptNextWord ? "tab" : "full"

        RawAutocompleteTraceLog.shared.recordAcceptance(
            action: action.diagnosticName,
            appBundleIdentifier: appBundleIdentifier,
            acceptedText: acceptance.acceptedText,
            remainingVisibleText: acceptance.remainingVisibleTextAfterAccept,
            displayedText: acceptance.visibleTextBeforeAccept,
            suggestionID: currentSuggestionID ?? "",
            fieldIdentity: currentSuggestionFieldIdentity?.traceDescription
                ?? currentFieldIdentity?.traceDescription
                ?? "",
            requestMode: currentSuggestionRequestMode?.rawValue ?? "",
            metadata: metadata
        )
    }

    private func visibleAcceptanceMatchesDisplayedSuggestion(_ acceptance: SuggestionAcceptancePreview) -> Bool {
        guard let currentSuggestionDisplayedText else {
            return false
        }

        return currentSuggestionDisplayedText == acceptance.visibleTextBeforeAccept
    }

    private func refreshVisibleSuggestion() {
        guard let suggestion = suggestionSession.visibleSuggestion,
              let caretRect = lastCaretRect else {
            hideSuggestion()
            return
        }

        currentSuggestionDisplayedText = suggestion.visibleText
        guard suggestionPanel.show(
            text: suggestion.visibleText,
            near: caretRect,
            alignedTo: lastTextLineRect,
            boundedBy: lastClippingRect,
            style: lastTextStyle,
            renderMode: lastRenderMode ?? .inlineAdjacent
        ) != nil else {
            hideSuggestion(reason: "panel-frame-unusable")
            return
        }
        updateKeyboardEventTapSnapshot()
    }

    private func repositionVisibleSuggestion(
        context: FocusedTextContext,
        profile: CompatibilityProfile
    ) {
        guard suggestionSession.hasVisibleSuggestion,
              let renderMode = RenderModePlan.effectiveMode(
                  for: profile,
                  supportsInlineSuggestions: context.capabilities.supportsInlineSuggestions,
                  hasMirrorAnchor: context.elementRect != nil || context.windowRect != nil
              ) else {
            return
        }

        let visualScope = compatibilityVisualScope(
            bundleIdentifier: profile.bundleIdentifier,
            context: context
        )
        let learningAdjustment = compatibilityLearningStore.engine().adjustment(
            for: profile.bundleIdentifier,
            profileRenderMode: renderMode
        ).trustedVisualOffsetOnly(matching: visualScope)
        let placementPlan = placementHealthPlan(
            context: context,
            profile: profile,
            learningAdjustment: learningAdjustment
        )

        guard case let .present(placement) = placementPlan else {
            if case let .suppress(suppression) = placementPlan {
                recordSuggestionEvent(
                    "suggestion-hidden",
                    context: context,
                    profile: profile,
                    metadata: [
                        "reason": "placement-\(suppression.reason.rawValue)"
                    ]
                    .merging(learningAdjustment.metadata) { current, _ in current }
                    .merging(suppression.metadata) { current, _ in current }
                )
                if let fieldIdentity = currentSuggestionFieldIdentity ?? currentFieldIdentity {
                    _ = recordPlacementUncertainty(
                        reason: suppression.reason.rawValue,
                        context: context,
                        profile: profile,
                        fieldIdentity: fieldIdentity,
                        metadata: learningAdjustment.metadata
                            .merging(suppression.metadata) { current, _ in current }
                    )
                }
                hideSuggestion(reason: "placement-\(suppression.reason.rawValue)")
            }
            return
        }

        lastCaretRect = placement.anchorRect
        lastTextLineRect = placement.textLineRect
        lastClippingRect = placement.clippingRect
        lastTextStyle = context.textStyle
        lastRenderMode = placement.renderMode
        currentSuggestionVisualScope = visualScope
        if let currentSuggestionFieldIdentity {
            placementUncertaintySuppressor.reset(fieldIdentifier: currentSuggestionFieldIdentity.traceDescription)
        }
        refreshVisibleSuggestion()
    }

    private func recordAcceptedText(_ acceptedText: String) {
        rememberAcceptedWords(
            in: acceptedText,
            appBundleIdentifier: currentSuggestionAppBundleIdentifier ?? currentProfile?.bundleIdentifier
        )

        guard let currentFieldIdentity,
              let lastTextSnapshot,
              lastTextSnapshot.fieldIdentity == currentFieldIdentity else {
            return
        }

        self.lastTextSnapshot = FocusedTextSnapshot(
            fieldIdentity: currentFieldIdentity,
            textBeforeCursor: lastTextSnapshot.textBeforeCursor + acceptedText,
            textAfterCursor: lastTextSnapshot.textAfterCursor
        )
    }

    private func advanceCurrentSuggestionBaseline(afterAccepting acceptedText: String) {
        guard !acceptedText.isEmpty else {
            return
        }

        if let lastTextSnapshot,
           lastTextSnapshot.fieldIdentity == currentFieldIdentity {
            currentSuggestionTextBeforeCursor = lastTextSnapshot.textBeforeCursor
            currentSuggestionAcceptanceSnapshot = SuggestionAcceptanceSnapshot(
                fieldIdentity: lastTextSnapshot.fieldIdentity,
                textBeforeCursor: lastTextSnapshot.textBeforeCursor,
                textAfterCursor: lastTextSnapshot.textAfterCursor,
                selectedTextLength: 0
            )
            return
        }

        if let currentSuggestionTextBeforeCursor {
            let advancedTextBeforeCursor = currentSuggestionTextBeforeCursor + acceptedText
            self.currentSuggestionTextBeforeCursor = advancedTextBeforeCursor
            if let currentSuggestionAcceptanceSnapshot {
                self.currentSuggestionAcceptanceSnapshot = SuggestionAcceptanceSnapshot(
                    fieldIdentity: currentSuggestionAcceptanceSnapshot.fieldIdentity,
                    textBeforeCursor: advancedTextBeforeCursor,
                    textAfterCursor: currentSuggestionAcceptanceSnapshot.textAfterCursor,
                    selectedTextLength: 0
                )
            }
        }
    }

    private func rememberAcceptedWords(in text: String, appBundleIdentifier: String?) {
        rememberRecentWords(
            recentWordExtractor.words(in: text),
            appBundleIdentifier: appBundleIdentifier
        )
    }

    private func rememberTypedWordsIfNeeded(
        previousSnapshot: FocusedTextSnapshot?,
        currentSnapshot: FocusedTextSnapshot,
        appBundleIdentifier: String
    ) {
        guard let previousSnapshot,
              previousSnapshot.fieldIdentity == currentSnapshot.fieldIdentity else {
            return
        }

        rememberRecentWords(recentWordExtractor.completedWords(
            previousTextBeforeCursor: previousSnapshot.textBeforeCursor,
            currentTextBeforeCursor: currentSnapshot.textBeforeCursor
        ), appBundleIdentifier: appBundleIdentifier)
    }

    private func rememberRecentWords(_ words: [String], appBundleIdentifier: String?) {
        guard let appBundleIdentifier else {
            return
        }

        recentWordMemory.remember(words, scope: appBundleIdentifier)
    }

    private func recordTypedOverSuggestionIfNeeded(
        newTextBeforeCursor: String,
        fieldIdentity: FocusedFieldIdentity,
        profile: CompatibilityProfile
    ) {
        guard suggestionSession.hasVisibleSuggestion,
              let suggestionID = currentSuggestionID,
              let originalTextBeforeCursor = currentSuggestionTextBeforeCursor,
              let displayedText = currentSuggestionDisplayedText,
              fieldIdentity == currentFieldIdentity,
              newTextBeforeCursor.hasPrefix(originalTextBeforeCursor),
              newTextBeforeCursor != originalTextBeforeCursor else {
            return
        }

        let progress = suggestionTypingProgressPolicy.progress(
            originalTextBeforeCursor: originalTextBeforeCursor,
            displayedText: displayedText,
            newTextBeforeCursor: newTextBeforeCursor
        )

        guard case let .typedOver(typedSuffix) = progress else {
            return
        }

        RawAutocompleteTraceLog.shared.record(
            type: .suggestionTypedOver,
            suggestionID: suggestionID,
            appBundleIdentifier: profile.bundleIdentifier,
            fieldIdentity: fieldIdentity.traceDescription,
            requestMode: currentSuggestionRequestMode?.rawValue ?? "",
            textBeforeCursor: originalTextBeforeCursor,
            displayedText: displayedText,
            outcome: "typed-over",
            reason: "typed-against-visible-suggestion",
            metadata: [
                "typedSuffix": typedSuffix
            ]
        )
    }

    private func hideStaleSuggestionIfNeeded(
        newTextBeforeCursor: String,
        fieldIdentity: FocusedFieldIdentity
    ) {
        guard suggestionSession.hasVisibleSuggestion,
              fieldIdentity == currentFieldIdentity,
              let originalTextBeforeCursor = currentSuggestionTextBeforeCursor,
              let displayedText = currentSuggestionDisplayedText,
              newTextBeforeCursor.hasPrefix(originalTextBeforeCursor),
              newTextBeforeCursor != originalTextBeforeCursor else {
            return
        }

        let progress = suggestionTypingProgressPolicy.progress(
            originalTextBeforeCursor: originalTextBeforeCursor,
            displayedText: displayedText,
            newTextBeforeCursor: newTextBeforeCursor
        )

        if case .typedThroughVisiblePrefix = progress {
            hideSuggestion(reason: "typed-through-visible-prefix")
        } else if case .typedOver = progress {
            suggestionRepetitionSuppressor.recordMiss(
                displayedText,
                mode: currentSuggestionRequestMode,
                scope: currentSuggestionAppBundleIdentifier ?? currentProfile?.bundleIdentifier ?? ""
            )
            let annoyanceUpdate = recordAnnoyance(
                .typedOver,
                appBundleIdentifier: currentSuggestionAppBundleIdentifier ?? currentProfile?.bundleIdentifier ?? "",
                fieldIdentity: fieldIdentity,
                requestMode: currentSuggestionRequestMode
            )
            hideSuggestion(reason: "typed-over")
            if startedFieldQuiet(for: .typedOver, update: annoyanceUpdate) {
                suppressCurrentField(reason: "repeated-typed-over")
                setSuggestionDecision("Blocked: repeated typed-over")
            }
        }
    }

    private func hideSuggestion(reason: String = "hidden") {
        if suggestionSession.hasVisibleSuggestion,
           let suggestionID = currentSuggestionID {
            let appBundleIdentifier = currentSuggestionAppBundleIdentifier ?? currentProfile?.bundleIdentifier ?? ""
            let fieldIdentityDescription = currentSuggestionFieldIdentity?.traceDescription
                ?? currentFieldIdentity?.traceDescription
                ?? ""
            let outcome: String
            if reason.hasPrefix("accepted") {
                outcome = "accepted"
            } else if reason == "typed-through-visible-prefix" {
                outcome = "typed-through"
            } else if reason == "typed-over" {
                outcome = "typed-over"
            } else {
                outcome = "ignored"
            }
            let displayedText = currentSuggestionDisplayedText ?? suggestionSession.visibleSuggestion?.visibleText ?? ""

            if outcome == "ignored" {
                suggestionRepetitionSuppressor.recordMiss(
                    displayedText,
                    mode: currentSuggestionRequestMode,
                    scope: appBundleIdentifier
                )
            }

            RawAutocompleteTraceLog.shared.record(
                type: .suggestionHidden,
                suggestionID: suggestionID,
                appBundleIdentifier: appBundleIdentifier,
                fieldIdentity: fieldIdentityDescription,
                requestMode: currentSuggestionRequestMode?.rawValue ?? "",
                displayedText: displayedText,
                outcome: outcome,
                reason: reason
            )
            setSuggestionDecision("Hidden: \(reason)")
        }

        suggestionSession.dismiss()
        currentSuggestionID = nil
        currentSuggestionAppBundleIdentifier = nil
        currentSuggestionFieldIdentity = nil
        currentSuggestionVisualScope = nil
        currentSuggestionRequestMode = nil
        currentSuggestionTextBeforeCursor = nil
        currentSuggestionAcceptanceSnapshot = nil
        currentSuggestionDisplayedText = nil
        currentSuggestionInvalidatedByUserKeyDown = false
        streamingPresentationStates.removeAll(keepingCapacity: true)
        lastCaretRect = nil
        lastTextLineRect = nil
        lastClippingRect = nil
        lastTextStyle = nil
        lastRenderMode = nil
        suggestionPanel.hide()
        updateKeyboardEventTapSnapshot()
        scheduleKeyboardEventTapStopIfIdle()
    }

    private func updateStatusMenu(
        app: RunningApplicationInfo?,
        profile: CompatibilityProfile?,
        appEnabled: Bool
    ) {
        if let app,
           app.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastObservedSettingsApp = app
        }

        let permission = accessibilityClient.isTrusted ? "AX ok" : "AX missing"
        let control = suggestionControlState.statusName
        let appName = app?.localizedName ?? "No app"
        let enabled = appEnabled ? "on" : "off"
        let supportStatus = app.map { profileStore.supportStatus(for: $0.bundleIdentifier) } ?? .unsupported
        let profileName = app.map { _ in supportStatus.summary } ?? "none"
        let appStatus = app.map {
            supportStatus.menuText(appDisplayName: $0.localizedName, isEnabled: appEnabled)
        } ?? appName
        let appControlState = app.map {
            SettingsCurrentAppState(
                displayName: $0.localizedName,
                bundleIdentifier: $0.bundleIdentifier,
                supportStatus: supportStatus,
                isEnabled: appEnabled,
                disabledAppCount: disabledBundleIdentifiers.count,
                renderModeOverride: compatibilityLearningStore.profile(for: $0.bundleIdentifier)?.renderModeOverride,
                canQuietCurrentField: canQuietCurrentField
            )
        }
        let statusLine = statusMenuTitle(
            app: app,
            supportStatus: supportStatus,
            appEnabled: appEnabled
        )
        let statusSignature = "\(control)|\(suggestionPace.rawValue)|\(permission)|\(appStatus)|\(lastSuggestionDecision)|\(statusLine)"

        statusMenuItem?.title = statusLine
        statusMenuItem?.toolTip = lastSuggestionDecision
        refreshMenuBarIcon(statusLine: statusLine)
        pauseSuggestionsMenuItem?.title = pauseSuggestionsTitle
        toggleAppMenuItem?.title = appControlState?.menuToggleTitle ?? "Toggle Current App"
        toggleAppMenuItem?.isEnabled = appControlState?.canToggle ?? false
        quietFieldMenuItem?.isEnabled = canQuietCurrentField
        if settingsWindow.isShowing {
            settingsWindow.refresh(
                isTrusted: accessibilityClient.isTrusted,
                suggestionsPaused: suggestionsPaused,
                suggestionPace: suggestionPace,
                runtimeReport: runtimeReadinessReport,
                runtimeTargetSummary: runtimeTargetSummary,
                runtimeInstallStatus: modelInstallStatusText,
                runtimeInstallInProgress: modelInstallTask != nil,
                modelDirectoryPath: modelDirectoryPath,
                currentApp: settingsCurrentAppState,
                privacy: settingsPrivacyState,
                keyboardShortcuts: settingsKeyboardShortcutState,
                lastSuggestionDecision: lastSuggestionDecision
            )
        }

        guard lastStatusLine != statusSignature else {
            return
        }

        lastStatusLine = statusSignature
        DiagnosticsLog.shared.record(
            "status",
            metadata: [
                "accessibility": permission,
                "control": control,
                "suggestionPace": suggestionPace.rawValue,
                "app": appName,
                "profile": profileName,
                "enabled": enabled,
                "paused": String(suggestionsPaused),
                "decision": lastSuggestionDecision
            ]
        )
    }

    private func statusMenuTitle(
        app: RunningApplicationInfo?,
        supportStatus: CompatibilitySupportStatus,
        appEnabled: Bool
    ) -> String {
        guard accessibilityClient.isTrusted else {
            return "Needs Accessibility"
        }

        if suggestionsPaused {
            return "Paused"
        }

        guard let app else {
            return "Ready"
        }

        guard supportStatus.canToggleSuggestions else {
            switch supportStatus.supportLevel {
            case .diagnosticsOnly:
                return "Diagnostics only in \(app.localizedName)"
            case .unsupported:
                return "Unsupported in \(app.localizedName)"
            case .green, .yellow:
                return "Off in \(app.localizedName)"
            }
        }

        guard appEnabled else {
            return "Blocked in \(app.localizedName)"
        }

        if lastSuggestionDecision.hasPrefix("Shown") {
            return "Showing in \(app.localizedName)"
        }

        if lastSuggestionDecision.hasPrefix("Queued") {
            return "Thinking in \(app.localizedName)"
        }

        if lastSuggestionDecision.hasPrefix("Waiting") {
            return "Waiting in \(app.localizedName)"
        }

        return "Ready in \(app.localizedName)"
    }

    private func setSuggestionDecision(_ decision: String) {
        lastSuggestionDecision = decision
    }

    private func refreshMenuBarIcon(statusLine: String? = nil) {
        let presentation = MenuBarIconPresentation(
            isTrusted: accessibilityClient.isTrusted,
            suggestionsPaused: suggestionsPaused,
            runtimeReport: runtimeReadinessReport
        )
        statusItem?.button?.image = MenuBarIconFactory.image(for: presentation)
        statusItem?.button?.imagePosition = .imageOnly
        statusItem?.button?.toolTip = [
            presentation.accessibilityDescription,
            statusLine ?? statusMenuItem?.title
        ]
            .compactMap { $0 }
            .joined(separator: ": ")
    }

    private var canQuietCurrentField: Bool {
        currentFieldIdentity != nil && currentProfile?.suppressesUntilBlurAfterEscape == true
    }

    private func suppressCurrentField(reason: String) {
        guard let currentProfile,
              currentProfile.suppressesUntilBlurAfterEscape,
              let currentFieldIdentity else {
            return
        }

        suppressedFieldIdentities.insert(currentFieldIdentity)
        DiagnosticsLog.shared.record(
            "field-suppressed",
            metadata: [
                "app": currentProfile.bundleIdentifier,
                "reason": reason
            ]
        )
    }

    @discardableResult
    private func recordAnnoyance(
        _ signal: AnnoyanceSignal,
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity,
        requestMode: CompletionRequestMode?
    ) -> AnnoyanceUpdate {
        annoyanceSuppressor.record(
            signal,
            context: AnnoyanceContext(
                appBundleIdentifier: appBundleIdentifier,
                fieldIdentifier: fieldIdentity.traceDescription,
                requestMode: requestMode
            )
        )
    }

    private func startedFieldQuiet(
        for signal: AnnoyanceSignal,
        update: AnnoyanceUpdate
    ) -> Bool {
        update.startedQuietModes.contains { mode in
            if case let .field(_, reason, _) = mode {
                return reason == signal
            }
            return false
        }
    }

    @objc
    private func quietCurrentFieldFromControl() {
        guard canQuietCurrentField else {
            return
        }

        suppressCurrentField(reason: "user-quiet-field")
        hideSuggestion(reason: "user-quiet-field")
        setSuggestionDecision("Blocked: current field quieted")

        let app = targetAppForControls()
        updateStatusMenu(
            app: app,
            profile: app.flatMap { profileStore.profile(for: $0.bundleIdentifier) },
            appEnabled: app.map { !disabledBundleIdentifiers.contains($0.bundleIdentifier) } ?? false
        )
    }

    private func copyProofCommandToPasteboard(_ command: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        DiagnosticsLog.shared.record(
            "proof-command-copied",
            metadata: [
                "app": settingsCurrentAppState.bundleIdentifier ?? "none"
            ]
        )
    }

    private func transitionToField(_ fieldIdentity: FocusedFieldIdentity) {
        guard currentFieldIdentity != fieldIdentity else {
            return
        }

        if suggestionSession.hasVisibleSuggestion {
            hideSuggestion(reason: "focus-changed")
        }
        invalidatePendingSuggestionRequest()

        if let currentFieldIdentity {
            suppressedFieldIdentities.remove(currentFieldIdentity)
            placementUncertaintySuppressor.reset(fieldIdentifier: currentFieldIdentity.traceDescription)
        }

        currentFieldIdentity = fieldIdentity
        lastTextSnapshot = nil
        lastRequestedTextBeforeCursor = nil
        typingBurstState.reset()
        suggestionBlockLogGate.reset()
    }

    private func clearFocusedFieldState(
        hideReason: String = "focus-lost",
        resetBlockLogGate: Bool = true
    ) {
        if suggestionSession.hasVisibleSuggestion {
            hideSuggestion(reason: hideReason)
        }
        invalidatePendingSuggestionRequest()

        if let currentFieldIdentity {
            suppressedFieldIdentities.remove(currentFieldIdentity)
            placementUncertaintySuppressor.reset(fieldIdentifier: currentFieldIdentity.traceDescription)
        }

        currentFieldIdentity = nil
        lastTextSnapshot = nil
        lastRequestedTextBeforeCursor = nil
        typingBurstState.reset()
        if resetBlockLogGate {
            suggestionBlockLogGate.reset()
        }
    }

    private func invalidatePendingSuggestionRequest() {
        debounceTask?.cancel()
        debounceTask = nil
        currentCompletionRequest = nil
        streamingPresentationStates.removeAll(keepingCapacity: true)
        suggestionRequestGate.invalidate()
    }

    @objc
    private func requestAccessibilityPermission() {
        accessibilityClient.requestPermissionIfNeeded()
        settingsWindow.refresh(
            isTrusted: accessibilityClient.isTrusted,
            suggestionsPaused: suggestionsPaused,
            suggestionPace: suggestionPace,
            runtimeReport: runtimeReadinessReport,
            runtimeTargetSummary: runtimeTargetSummary,
            runtimeInstallStatus: modelInstallStatusText,
            runtimeInstallInProgress: modelInstallTask != nil,
            modelDirectoryPath: modelDirectoryPath,
            currentApp: settingsCurrentAppState,
            privacy: settingsPrivacyState,
            keyboardShortcuts: settingsKeyboardShortcutState,
            lastSuggestionDecision: lastSuggestionDecision
        )
        DiagnosticsLog.shared.record("request-accessibility")
    }

    @objc
    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        if let url, NSWorkspace.shared.open(url) {
            DiagnosticsLog.shared.record("open-accessibility-settings")
        } else {
            DiagnosticsLog.shared.record("open-accessibility-settings-failed")
        }
    }

    @objc
    private func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        if let url, NSWorkspace.shared.open(url) {
            DiagnosticsLog.shared.record("open-screen-recording-settings")
        } else {
            DiagnosticsLog.shared.record("open-screen-recording-settings-failed")
        }
    }

    @objc
    private func showSettings() {
        settingsWindow.show(
            isTrusted: accessibilityClient.isTrusted,
            suggestionsPaused: suggestionsPaused,
            suggestionPace: suggestionPace,
            runtimeReport: runtimeReadinessReport,
            runtimeTargetSummary: runtimeTargetSummary,
            runtimeInstallStatus: modelInstallStatusText,
            runtimeInstallInProgress: modelInstallTask != nil,
            modelDirectoryPath: modelDirectoryPath,
            currentApp: settingsCurrentAppState,
            privacy: settingsPrivacyState,
            keyboardShortcuts: settingsKeyboardShortcutState,
            lastSuggestionDecision: lastSuggestionDecision
        )
    }

    @objc
    private func showCommandContextPanel() {
        cancelCommandContextRequest()
        commandContextDraft = makeCommandContextDraft()
        commandContextSuggestionText = nil
        commandContextStatusMessage = ""
        commandContextIsLoading = false

        let state = commandContextPanelState()
        commandContextPanel.show(state: state)
        DiagnosticsLog.shared.record(
            "command-context-opened",
            metadata: [
                "app": state.bundleIdentifier ?? "none",
                "support": state.supportStatus.summary,
                "hasContext": String(state.context != nil),
                "source": state.context?.sourceName ?? "none"
            ]
        )
    }

    private func makeCommandContextDraft() -> CommandContextDraft {
        guard let app = appForCommandContext() else {
            return CommandContextDraft(app: nil, supportStatus: .unsupported, context: nil)
        }

        let supportStatus = profileStore.supportStatus(for: app.bundleIdentifier)
        let profile = profileStore.profile(for: app.bundleIdentifier)
        let canReadContext: Bool
        switch supportStatus {
        case let .supported(profile):
            canReadContext = !profile.isSensitive
        case .denylisted:
            canReadContext = false
        case .unsupported:
            canReadContext = true
        }

        let context = canReadContext
            ? accessibilityClient.focusedTextContext(
                for: app,
                allowDescendantTextFallback: profile?.allowsDescendantTextFallback == true
            )
            : nil

        return CommandContextDraft(
            app: app,
            supportStatus: supportStatus,
            context: context
        )
    }

    private func appForCommandContext() -> RunningApplicationInfo? {
        if let app = accessibilityClient.frontmostApplication(),
           app.bundleIdentifier != Bundle.main.bundleIdentifier {
            return app
        }

        return lastObservedSettingsApp ?? lastEligibleTargetApp
    }

    private func commandContextPanelState() -> CommandContextPanelState {
        let app = commandContextDraft?.app
        let bundleIdentifier = app?.bundleIdentifier
        let supportStatus = commandContextDraft?.supportStatus ?? .unsupported

        return CommandContextPanelState(
            appDisplayName: app?.localizedName ?? "None",
            bundleIdentifier: bundleIdentifier,
            supportStatus: supportStatus,
            isAppEnabled: bundleIdentifier.map { !disabledBundleIdentifiers.contains($0) } ?? false,
            runtimeReport: runtimeReadinessReport,
            context: commandContextDraft?.context.map(CommandContextSnapshot.init(context:)),
            suggestionText: commandContextSuggestionText,
            isLoading: commandContextIsLoading,
            statusMessage: commandContextStatusMessage
        )
    }

    private func requestCommandContextSuggestion() {
        let state = commandContextPanelState()
        guard state.canRequestSuggestion,
              let draft = commandContextDraft,
              let requestText = commandContextRequestText(from: draft) else {
            commandContextStatusMessage = "Not ready: \(state.requestUnavailableReason ?? "No context available.")"
            commandContextPanel.refresh(state: commandContextPanelState())
            return
        }

        let requestID = UUID().uuidString
        let request = CompletionRequest(
            textBeforeCursor: requestText,
            textAfterCursor: draft.context?.textAfterCursor ?? "",
            appBundleIdentifier: draft.app?.bundleIdentifier,
            maxVisibleWords: completionLengthConfiguration.maxVisibleWords,
            mode: .phraseContinuation,
            suggestionID: requestID
        )

        commandContextRequestTask?.cancel()
        commandContextRequestID = requestID
        commandContextSuggestionText = nil
        commandContextStatusMessage = "Thinking locally..."
        commandContextIsLoading = true
        commandContextPanel.refresh(state: commandContextPanelState())

        DiagnosticsLog.shared.record(
            "command-context-requested",
            metadata: [
                "app": draft.app?.bundleIdentifier ?? "none",
                "source": draft.context?.selectedText.isEmpty == false ? "selected-text" : "current-field",
                "contextChars": String(requestText.count)
            ]
        )

        commandContextRequestTask = Task { [weak self, engine, request, requestID] in
            do {
                let suggestion = try await engine.suggestion(for: request)
                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    self?.completeCommandContextRequest(
                        requestID: requestID,
                        suggestionText: suggestion?.visibleText,
                        errorMessage: nil
                    )
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    self?.completeCommandContextRequest(
                        requestID: requestID,
                        suggestionText: nil,
                        errorMessage: error.localizedDescription
                    )
                }
            }
        }
    }

    private func commandContextRequestText(from draft: CommandContextDraft) -> String? {
        guard let context = draft.context, !context.isSecure else {
            return nil
        }

        let selectedText = context.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !selectedText.isEmpty {
            return context.selectedText
        }

        if case .unsupported = draft.supportStatus {
            return nil
        }

        let textBeforeCursor = context.textBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textBeforeCursor.isEmpty else {
            return nil
        }

        return context.textBeforeCursor
    }

    private func completeCommandContextRequest(
        requestID: String,
        suggestionText: String?,
        errorMessage: String?
    ) {
        guard commandContextRequestID == requestID else {
            return
        }

        commandContextRequestTask = nil
        commandContextRequestID = nil
        commandContextIsLoading = false

        if let errorMessage {
            commandContextSuggestionText = nil
            commandContextStatusMessage = "Model error: \(errorMessage)"
        } else if let suggestionText,
                  !suggestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            commandContextSuggestionText = suggestionText
            commandContextStatusMessage = "Ready: copy when you want it."
        } else {
            commandContextSuggestionText = nil
            commandContextStatusMessage = "No suggestion returned."
        }

        commandContextPanel.refresh(state: commandContextPanelState())
        DiagnosticsLog.shared.record(
            "command-context-result",
            metadata: [
                "app": commandContextDraft?.app?.bundleIdentifier ?? "none",
                "hasSuggestion": String(commandContextSuggestionText != nil),
                "suggestionChars": String(commandContextSuggestionText?.count ?? 0)
            ]
        )
    }

    private func copyCommandContextSuggestionToPasteboard() {
        let state = commandContextPanelState()
        guard state.canCopySuggestion,
              let suggestionText = commandContextSuggestionText else {
            commandContextStatusMessage = "Nothing to copy yet."
            commandContextPanel.refresh(state: commandContextPanelState())
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(suggestionText, forType: .string)
        commandContextStatusMessage = "Copied to clipboard. Paste it where you want it."
        commandContextPanel.refresh(state: commandContextPanelState())

        DiagnosticsLog.shared.record(
            "command-context-copied",
            metadata: [
                "app": commandContextDraft?.app?.bundleIdentifier ?? "none",
                "suggestionChars": String(suggestionText.count)
            ]
        )
    }

    private func cancelCommandContextRequest() {
        commandContextRequestTask?.cancel()
        commandContextRequestTask = nil
        commandContextRequestID = nil
        commandContextIsLoading = false
    }

    private func openDisposableTextEditTest() {
        let fileName = "autocomplete-lab-textedit-test-\(UUID().uuidString).txt"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(fileURL)
            DiagnosticsLog.shared.record(
                "open-textedit-test",
                metadata: ["path": fileURL.path]
            )
        } catch {
            DiagnosticsLog.shared.record(
                "open-textedit-test-failed",
                metadata: ["reason": error.localizedDescription]
            )
        }
    }

    @objc
    private func revealModelFolder() {
        do {
            try FileManager.default.createDirectory(
                at: modelRuntimeBundle.modelDirectoryURL,
                withIntermediateDirectories: true
            )
            NSWorkspace.shared.activateFileViewerSelecting([modelRuntimeBundle.modelDirectoryURL])
            DiagnosticsLog.shared.record(
                "reveal-model-folder",
                metadata: ["path": modelDirectoryPath]
            )
        } catch {
            DiagnosticsLog.shared.record(
                "reveal-model-folder-failed",
                metadata: ["reason": error.localizedDescription]
            )
        }
    }

    private func startModelAssetInstall(reason: String) {
        guard modelInstallTask == nil else {
            return
        }

        let manifest = modelRuntimeBundle.bootstrapPlan.preferredAsset
        let targetURL = modelRuntimeBundle.modelDirectoryURL
        modelInstallStatusText = "Model install: preparing \(manifest.model.rawValue)"
        setSuggestionDecision("Blocked: model install")
        DiagnosticsLog.shared.record(
            "model-install-start",
            metadata: [
                "reason": reason,
                "model": manifest.model.rawValue,
                "target": targetURL.path,
                "repo": manifest.source?.repoID ?? ""
            ]
        )
        refreshRuntimeChrome()

        modelInstallTask = Task { [manifest, targetURL, reason] in
            do {
                try await ModelAssetInstaller().install(
                    manifest: manifest,
                    targetURL: targetURL
                ) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.modelInstallStatusText = progress.statusText
                        self?.refreshRuntimeChrome()
                    }
                }

                await MainActor.run {
                    modelInstallTask = nil
                    modelInstallStatusText = "Model install: complete. Warming local model."
                    DiagnosticsLog.shared.record(
                        "model-install-complete",
                        metadata: [
                            "reason": reason,
                            "model": manifest.model.rawValue,
                            "target": targetURL.path
                        ]
                    )
                    reloadModelRuntime(reason: "\(reason)-install-complete")
                }
            } catch is CancellationError {
                await MainActor.run {
                    modelInstallTask = nil
                    modelInstallStatusText = "Model install: canceled."
                    refreshRuntimeChrome()
                    DiagnosticsLog.shared.record(
                        "model-install-canceled",
                        metadata: ["reason": reason]
                    )
                }
            } catch {
                await MainActor.run {
                    modelInstallTask = nil
                    modelInstallStatusText = "Model install failed: \(error.localizedDescription)"
                    refreshRuntimeChrome()
                    DiagnosticsLog.shared.record(
                        "model-install-failed",
                        metadata: [
                            "reason": reason,
                            "error": error.localizedDescription
                        ]
                    )
                }
            }
        }
    }

    private func cancelModelAssetInstall() {
        guard let modelInstallTask else {
            return
        }

        modelInstallStatusText = "Model install: canceling..."
        DiagnosticsLog.shared.record("model-install-cancel-requested")
        modelInstallTask.cancel()
        refreshRuntimeChrome()
    }

    private func performRuntimeAction(_ action: RuntimeReadinessAction) {
        switch action {
        case .installModel:
            startModelAssetInstall(reason: "install-action")
        case .repairModel:
            startModelAssetInstall(reason: "repair-action")
        case .cancelModelInstall:
            cancelModelAssetInstall()
        case .revealModelFolder:
            revealModelFolder()
            reloadModelRuntime(reason: "model-folder-action")
        case .retry:
            reloadModelRuntime(reason: "retry-action")
        case .wait, .none:
            break
        }
    }

    @objc
    private func showDiagnostics() {
        let app = targetAppForControls()
        let compatibilityStatus = app
            .map { profileStore.supportStatus(for: $0.bundleIdentifier) }
            ?? .unsupported
        let profile = app.flatMap { profileStore.profile(for: $0.bundleIdentifier) }
        let appEnabled = app.map { !disabledBundleIdentifiers.contains($0.bundleIdentifier) } ?? false
        let bundleIdentifier = app?.bundleIdentifier ?? ""

        diagnosticsWindow.show(
            diagnostics: app.flatMap {
                accessibilityClient.focusedTextDiagnostics(
                    for: $0,
                    allowDescendantTextFallback: profile?.allowsDescendantTextFallback == true
                )
            },
            profile: profile,
            compatibilityStatus: compatibilityStatus,
            appEnabled: appEnabled,
            appTrusted: accessibilityClient.isTrusted,
            lastSuggestionDecision: lastSuggestionDecision,
            runtimeReport: runtimeReadinessReport,
            runtimeTargetSummary: runtimeTargetSummary,
            modelDirectoryPath: modelDirectoryPath,
            recentEvents: DiagnosticsLog.shared.recentLines(limit: 24),
            traceSummary: RawAutocompleteTraceLog.shared.summary(),
            recentTraceEvents: RawAutocompleteTraceLog.shared.recentEvents(limit: 48),
            tracePath: RawAutocompleteTraceLog.shared.path,
            tracingPaused: RawAutocompleteTraceLog.shared.isPaused,
            screenshotTracingEnabled: RawAutocompleteTraceLog.shared.screenshotTracingEnabled
                || compatibilityLearningStore.profile(for: bundleIdentifier)?.screenshotTracingEnabled == true,
            compatibilityLearningPath: compatibilityLearningStore.path,
            compatibilityLearningProfile: compatibilityLearningStore.profile(for: bundleIdentifier),
            refreshAction: { [weak self] in
                self?.showDiagnostics()
            },
            toggleTracingAction: { [weak self] in
                self?.toggleTracing()
            },
            toggleScreenshotTracingAction: { [weak self] in
                self?.toggleScreenshotTracing(for: bundleIdentifier)
            },
            openTraceFolderAction: {
                self.openTraceFolder()
            },
            exportReportAction: {
                self.exportTraceReport()
            },
            deleteTracesAction: { [weak self] in
                self?.deleteLocalPrivacyLogs(refreshSettings: false)
                self?.showDiagnostics()
            }
        )
    }

    private func toggleTracing() {
        let nextPaused = !RawAutocompleteTraceLog.shared.isPaused
        RawAutocompleteTraceLog.shared.setPaused(nextPaused)
        DiagnosticsLog.shared.record(
            "trace-control",
            metadata: ["paused": String(nextPaused)]
        )
        showDiagnostics()
    }

    private func toggleSettingsTracingPaused() {
        let nextPaused = !RawAutocompleteTraceLog.shared.isPaused
        RawAutocompleteTraceLog.shared.setPaused(nextPaused)
        DiagnosticsLog.shared.record(
            "trace-control",
            metadata: [
                "surface": "settings",
                "paused": String(nextPaused)
            ]
        )
        refreshRuntimeChrome()
    }

    private func toggleRawContentTracing() {
        let nextEnabled = !RawAutocompleteTraceLog.shared.rawContentTracingEnabled
        RawAutocompleteTraceLog.shared.setRawContentTracingEnabled(nextEnabled)
        DiagnosticsLog.shared.record(
            "raw-trace-control",
            metadata: [
                "surface": "settings",
                "enabled": String(nextEnabled)
            ]
        )
        refreshRuntimeChrome()
    }

    private func toggleGlobalScreenshotTracing() {
        let nextEnabled = !RawAutocompleteTraceLog.shared.screenshotTracingEnabled
        RawAutocompleteTraceLog.shared.setScreenshotTracingEnabled(nextEnabled)
        DiagnosticsLog.shared.record(
            "screenshot-trace-control",
            metadata: [
                "surface": "settings",
                "enabled": String(nextEnabled)
            ]
        )
        refreshRuntimeChrome()
    }

    private func deleteLocalPrivacyLogs(refreshSettings: Bool = true) {
        RawAutocompleteTraceLog.shared.deleteAll()
        compatibilityLearningStore.disableScreenshotTracing()
        DiagnosticsLog.shared.deleteAll()
        DiagnosticsLog.shared.record(
            "local-privacy-logs-deleted",
            metadata: ["surface": refreshSettings ? "settings" : "diagnostics"]
        )
        if refreshSettings {
            refreshRuntimeChrome()
        }
    }

    private func showPrivacyStatus(_ statusText: String) {
        let alert = NSAlert()
        alert.messageText = "Privacy Status"
        alert.informativeText = statusText
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()

        DiagnosticsLog.shared.record(
            "privacy-status-opened",
            metadata: ["surface": "settings"]
        )
    }

    private func setAcceptAllShortcut(_ shortcut: AcceptAllShortcut) {
        keyboardShortcutConfiguration.acceptAllShortcut = shortcut
        persistKeyboardShortcutConfiguration()
        updateKeyboardEventTapSnapshot()
        DiagnosticsLog.shared.record(
            "keyboard-shortcut-control",
            metadata: [
                "surface": "settings",
                "acceptAllShortcut": keyboardShortcutConfiguration.acceptAllShortcut.rawValue
            ]
        )
        refreshRuntimeChrome()
    }

    private func setSuggestionPace(_ pace: SuggestionPace) {
        guard suggestionPace != pace else {
            refreshRuntimeChrome()
            return
        }

        suggestionPace = pace
        persistSuggestionPace()
        invalidatePendingSuggestionRequest()
        hideSuggestion(reason: "suggestion-pace-changed")
        lastTextSnapshot = nil
        setSuggestionDecision("Ready: \(pace.displayName.lowercased()) pace")
        DiagnosticsLog.shared.record(
            "suggestion-pace-control",
            metadata: [
                "surface": "settings",
                "pace": pace.rawValue
            ]
        )
        refreshRuntimeChrome()
    }

    private func toggleScreenshotTracing(for bundleIdentifier: String) {
        guard !bundleIdentifier.isEmpty else {
            RawAutocompleteTraceLog.shared.setScreenshotTracingEnabled(!RawAutocompleteTraceLog.shared.screenshotTracingEnabled)
            showDiagnostics()
            return
        }

        let current = compatibilityLearningStore.profile(for: bundleIdentifier)?.screenshotTracingEnabled == true
        compatibilityLearningStore.setScreenshotTracing(!current, for: bundleIdentifier)
        DiagnosticsLog.shared.record(
            "screenshot-trace-control",
            metadata: [
                "app": bundleIdentifier,
                "enabled": String(!current)
            ]
        )
        showDiagnostics()
    }

    @objc
    private func nudgeCurrentAppSuggestionUp() {
        nudgeCurrentAppSuggestion(dx: 0, dy: -2)
    }

    @objc
    private func nudgeCurrentAppSuggestionDown() {
        nudgeCurrentAppSuggestion(dx: 0, dy: 2)
    }

    @objc
    private func nudgeCurrentAppSuggestionLeft() {
        nudgeCurrentAppSuggestion(dx: -2, dy: 0)
    }

    @objc
    private func nudgeCurrentAppSuggestionRight() {
        nudgeCurrentAppSuggestion(dx: 2, dy: 0)
    }

    private func nudgeCurrentAppSuggestion(dx: Double, dy: Double) {
        guard let bundleIdentifier = visibleSuggestionBundleIdentifier
                ?? targetAppForControls()?.bundleIdentifier,
              profileStore.allows(bundleIdentifier: bundleIdentifier) else {
            DiagnosticsLog.shared.record(
                "compatibility-learning-nudge-skipped",
                metadata: ["reason": "no-eligible-app"]
            )
            return
        }

        compatibilityLearningStore.nudgeOffset(
            dx: dx,
            dy: dy,
            for: bundleIdentifier,
            visualScope: currentSuggestionVisualScope
        )
        let appliedToVisibleSuggestion = applyVisibleSuggestionNudge(dx: dx, dy: dy, bundleIdentifier: bundleIdentifier)
        DiagnosticsLog.shared.record(
            "compatibility-learning-nudge",
            metadata: [
                "app": bundleIdentifier,
                "dx": String(dx),
                "dy": String(dy),
                "appliedToVisibleSuggestion": String(appliedToVisibleSuggestion)
            ]
        )
    }

    private var visibleSuggestionBundleIdentifier: String? {
        guard suggestionSession.hasVisibleSuggestion else {
            return nil
        }

        return currentSuggestionAppBundleIdentifier ?? currentProfile?.bundleIdentifier
    }

    private func applyVisibleSuggestionNudge(dx: Double, dy: Double, bundleIdentifier: String) -> Bool {
        guard suggestionSession.hasVisibleSuggestion,
              visibleSuggestionBundleIdentifier == bundleIdentifier,
              lastCaretRect != nil else {
            return false
        }

        let deltaX = CGFloat(dx)
        let deltaY = CGFloat(dy)
        lastCaretRect = lastCaretRect?.offsetBy(dx: deltaX, dy: deltaY)
        lastTextLineRect = lastTextLineRect?.offsetBy(dx: deltaX, dy: deltaY)
        lastClippingRect = lastClippingRect?.offsetBy(dx: deltaX, dy: deltaY)
        refreshVisibleSuggestion()
        return true
    }

    @objc
    private func resetCurrentAppLearning() {
        guard let bundleIdentifier = visibleSuggestionBundleIdentifier
                ?? targetAppForControls()?.bundleIdentifier else {
            return
        }

        compatibilityLearningStore.reset(bundleIdentifier: bundleIdentifier)
        DiagnosticsLog.shared.record(
            "compatibility-learning-reset",
            metadata: ["app": bundleIdentifier]
        )
    }

    private func openTraceFolder() {
        do {
            try FileManager.default.createDirectory(
                at: RawAutocompleteTraceLog.shared.folderURL,
                withIntermediateDirectories: true
            )
            NSWorkspace.shared.activateFileViewerSelecting([RawAutocompleteTraceLog.shared.folderURL])
        } catch {
            DiagnosticsLog.shared.record(
                "trace-folder-open-failed",
                metadata: ["reason": error.localizedDescription]
            )
        }
    }

    private func exportTraceReport() {
        guard let reportURL = RawAutocompleteTraceLog.shared.exportHTMLReport(),
              let survivalReportURL = RawAutocompleteTraceLog.shared.exportRedactedSurvivalReport() else {
            DiagnosticsLog.shared.record("trace-report-export-failed")
            showDiagnostics()
            return
        }

        NSWorkspace.shared.open(reportURL)
        DiagnosticsLog.shared.record(
            "trace-report-exported",
            metadata: [
                "path": reportURL.path,
                "survivalReportPath": survivalReportURL.path
            ]
        )
        showDiagnostics()
    }

    @objc
    private func toggleCurrentApp() {
        guard let app = targetAppForControls(),
              profileStore.allows(bundleIdentifier: app.bundleIdentifier) else {
            return
        }

        let shouldDisable = !disabledBundleIdentifiers.contains(app.bundleIdentifier)
        var selection = DisabledAppSelection(bundleIdentifiers: disabledBundleIdentifiers)
        selection.set(app.bundleIdentifier, disabled: shouldDisable)
        disabledBundleIdentifiers = selection.bundleIdentifiers

        if shouldDisable {
            clearFocusedFieldState()
            hideSuggestion()
        }

        persistDisabledApps()
        DiagnosticsLog.shared.record(
            "app-control",
            metadata: [
                "app": app.bundleIdentifier,
                "enabled": String(!shouldDisable),
                "disabledCount": String(disabledBundleIdentifiers.count)
            ]
        )
        updateStatusMenu(
            app: app,
            profile: profileStore.profile(for: app.bundleIdentifier),
            appEnabled: !disabledBundleIdentifiers.contains(app.bundleIdentifier)
        )
    }

    private func enableAllDisabledApps() {
        var selection = DisabledAppSelection(bundleIdentifiers: disabledBundleIdentifiers)
        guard !selection.isEmpty else {
            return
        }

        let disabledCount = selection.count
        selection.clear()
        disabledBundleIdentifiers = selection.bundleIdentifiers
        persistDisabledApps()

        let frontmostApp = targetAppForControls()
        DiagnosticsLog.shared.record(
            "app-control",
            metadata: [
                "action": "enable-all",
                "disabledCount": String(disabledCount)
            ]
        )
        updateStatusMenu(
            app: frontmostApp,
            profile: frontmostApp.flatMap { profileStore.profile(for: $0.bundleIdentifier) },
            appEnabled: frontmostApp.map { !disabledBundleIdentifiers.contains($0.bundleIdentifier) } ?? false
        )
    }

    @objc
    private func toggleMirrorModeForCurrentApp() {
        guard let app = targetAppForControls(),
              let profile = profileStore.profile(for: app.bundleIdentifier),
              profile.canPresentSuggestions,
              !profile.isSensitive else {
            return
        }

        let currentOverride = compatibilityLearningStore.profile(for: app.bundleIdentifier)?.renderModeOverride
        guard currentOverride == .floatingMirror
            || (profile.renderMode == .inlineAdjacent && profile.fallbackRenderMode == .floatingMirror) else {
            return
        }

        let nextOverride: SuggestionRenderMode? = currentOverride == .floatingMirror ? nil : .floatingMirror
        compatibilityLearningStore.setRenderModeOverride(nextOverride, for: app.bundleIdentifier)
        hideSuggestion(reason: nextOverride == .floatingMirror ? "mirror-mode-forced" : "profile-mode-restored")

        DiagnosticsLog.shared.record(
            "app-render-mode-control",
            metadata: [
                "app": app.bundleIdentifier,
                "renderModeOverride": nextOverride?.rawValue ?? "profile"
            ]
        )
        updateStatusMenu(
            app: app,
            profile: profile,
            appEnabled: !disabledBundleIdentifiers.contains(app.bundleIdentifier)
        )
    }

    @objc
    private func togglePauseSuggestions() {
        let transition = suggestionControlPolicy.toggle(suggestionControlState)
        suggestionsPaused = transition.nextState.isPaused

        setSuggestionDecision(transition.decisionText)

        let cleanupReason = transition.cleanupReason?.hideReason
        if transition.shouldClearFocusedField {
            clearFocusedFieldState(hideReason: cleanupReason ?? "control-toggle")
        }

        if transition.shouldStopKeyboardCapture {
            stopKeyboardEventTapNow(reason: cleanupReason ?? "control-toggle")
        }

        persistPauseState()
        DiagnosticsLog.shared.record(
            "suggestions-control",
            metadata: [
                "paused": String(suggestionsPaused)
            ]
        )
        let frontmostApp = targetAppForControls()
        updateStatusMenu(
            app: frontmostApp,
            profile: frontmostApp.flatMap { profileStore.profile(for: $0.bundleIdentifier) },
            appEnabled: frontmostApp.map { !disabledBundleIdentifiers.contains($0.bundleIdentifier) } ?? false
        )
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }
}

private struct TraceScreenshotCapture {
    let path: String
    let rectDescription: String

    static let none = TraceScreenshotCapture(path: "", rectDescription: "none")
}

private struct CommandContextDraft {
    let app: RunningApplicationInfo?
    let supportStatus: CompatibilitySupportStatus
    let context: FocusedTextContext?
}

private extension AppDelegate {
    static var disabledAppsDefaultsKey: String {
        "DisabledBundleIdentifiers"
    }

    static var suggestionsPausedDefaultsKey: String {
        "SuggestionsPaused"
    }

    static var acceptAllShortcutDefaultsKey: String {
        "AcceptAllShortcut"
    }

    static var suggestionPaceDefaultsKey: String {
        "SuggestionPace"
    }

    func loadPauseState() {
        let persistedPause: Bool?
        if UserDefaults.standard.object(forKey: Self.suggestionsPausedDefaultsKey) == nil {
            persistedPause = nil
        } else {
            persistedPause = UserDefaults.standard.bool(forKey: Self.suggestionsPausedDefaultsKey)
        }

        suggestionsPaused = suggestionControlPolicy.startupState(
            persistedIsPaused: persistedPause
        ).isPaused
    }

    func persistPauseState() {
        UserDefaults.standard.set(
            suggestionsPaused,
            forKey: Self.suggestionsPausedDefaultsKey
        )
    }

    func loadDisabledApps() {
        let persisted = UserDefaults.standard.stringArray(forKey: Self.disabledAppsDefaultsKey) ?? []
        disabledBundleIdentifiers = DisabledAppSelection(
            persistedBundleIdentifiers: persisted
        ).bundleIdentifiers
    }

    func persistDisabledApps() {
        let selection = DisabledAppSelection(bundleIdentifiers: disabledBundleIdentifiers)
        UserDefaults.standard.set(
            selection.persistedBundleIdentifiers,
            forKey: Self.disabledAppsDefaultsKey
        )
    }

    func loadKeyboardShortcutConfiguration() {
        keyboardShortcutConfiguration = KeyboardShortcutConfiguration(
            persistedAcceptAllShortcutRawValue: UserDefaults.standard.string(forKey: Self.acceptAllShortcutDefaultsKey)
        )
    }

    func persistKeyboardShortcutConfiguration() {
        UserDefaults.standard.set(
            keyboardShortcutConfiguration.acceptAllShortcut.rawValue,
            forKey: Self.acceptAllShortcutDefaultsKey
        )
    }

    func loadSuggestionPace() {
        suggestionPace = SuggestionPace(
            persistedRawValue: UserDefaults.standard.string(forKey: Self.suggestionPaceDefaultsKey)
        )
    }

    func persistSuggestionPace() {
        UserDefaults.standard.set(
            suggestionPace.rawValue,
            forKey: Self.suggestionPaceDefaultsKey
        )
    }
}

private struct InsertionVerificationBaseline: Equatable {
    let fieldIdentity: FocusedFieldIdentity
    let previousTextBeforeCursor: String
    let profile: CompatibilityProfile
    let suggestionID: String?
    let requestMode: CompletionRequestMode?
    let retryCount: Int
}

private extension FocusedFieldIdentityInput {
    init(context: FocusedTextContext) {
        self.init(
            elementIdentifier: context.elementIdentifier,
            role: context.role,
            subrole: context.subrole,
            fingerprint: context.fingerprint,
            elementRect: context.elementRect,
            windowRect: context.windowRect
        )
    }
}

private extension CompletionActivationDecision {
    var blockReasonDescription: String {
        switch self {
        case .allow:
            return "allowed"
        case let .block(reason):
            return reason.rawValue
        }
    }
}
