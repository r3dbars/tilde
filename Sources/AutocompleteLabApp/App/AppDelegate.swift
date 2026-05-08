import AppKit
import AutocompleteLabCore

struct MenuBarStatusItemConfiguration: Equatable {
    let symbolName: String
    let fallbackTitle: String
    let accessibilityLabel: String

    static let autocompleteLab = MenuBarStatusItemConfiguration(
        symbolName: "text.cursor",
        fallbackTitle: "Autocomplete",
        accessibilityLabel: "Autocomplete Lab"
    )
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let accessibilityClient = AccessibilityClient()
    private let startupOnboardingPolicy = StartupOnboardingPolicy()
    private let profileStore = CompatibilityProfileStore.mvp
    private let promptEditorPolicy = PromptEditorFingerprintPolicy()
    private let browserHostedSurfacePolicy = BrowserHostedSurfacePolicy()
    private let suggestionControlPolicy = SuggestionControlPolicy()
    private let suggestionPauseSchedulePolicy = SuggestionPauseSchedulePolicy()
    private let activationPolicy = CompletionActivationPolicy()
    private let fieldClassifier = AXFieldClassifier()
    private let textContextRepairPolicy = TextContextRepairPolicy()
    private let tracePrivacySecretStore = TracePrivacySecretStore()
    private var triggerPolicy: SuggestionTriggerPolicy {
        suggestionAggressiveness.triggerPolicy
    }
    private let suggestionCadenceResetPolicy = SuggestionCadenceResetPolicy()
    private var modelRuntimeBundle = AppModelRuntimeFactory.makeRuntime()
    private var completionLengthConfiguration: CompletionLengthConfiguration {
        modelRuntimeBundle.lengthConfiguration
    }
    private var modelRuntime: any ModelRuntime {
        modelRuntimeBundle.runtime
    }
    private lazy var engine: any CompletionEngine = RuntimeBackedCompletionEngine(runtime: modelRuntime)
    private lazy var insertionEngine = InsertionEngine(
        accessibilityClient: accessibilityClient,
        clipboardFallbackEnabled: true
    )
    private let keyboardCapturePolicy = KeyboardCapturePolicy()
    private let keyboardEventTapIdleStopPolicy = KeyboardEventTapIdleStopPolicy()
    private let insertionVerification = InsertionVerification()
    private let insertionRetryPolicy = InsertionRetryPolicy()
    private let insertionVerificationTimingPolicy = InsertionVerificationTimingPolicy()
    private let suggestionAcceptanceProofPolicy = SuggestionAcceptanceProofPolicy()
    private let acceptanceSafetyPolicy = AcceptanceSafetyPolicy()
    private let suggestionPresentationTracePayloadBuilder = SuggestionPresentationTracePayloadBuilder()
    private let wordCompletionRanker = WordCompletionCandidateRanker()
    private lazy var suggestionOrchestrator = SuggestionOrchestrator(
        engine: engine,
        wordCompletionRanker: wordCompletionRanker,
        prefixFamilyCooldownPolicy: makePrefixFamilyCooldownPolicy()
    )
    private let suggestionTypingProgressPolicy = SuggestionTypingProgressPolicy()
    private var displayScorePolicy: DisplayScorePolicy {
        suggestionAggressiveness.displayScorePolicy
    }
    private var acceptedAndKeptLearning = AcceptedAndKeptLearningStore()
    private var acceptedTextStyleMemory = AcceptedTextStyleMemoryStore()
    private var activeAppProofBundleIdentifiers: Set<String> = []
    private var appProofExpirationTasks: [String: Task<Void, Never>] = [:]
    private let annoyanceSuppressor = AnnoyanceSuppressorActor()
    private let traceScreenshotCaptureCoordinator = TraceScreenshotCaptureCoordinator()
    private let focusedTextPollingBackoffPolicy = FocusedTextPollingBackoffPolicy.typingBackoff
    private let focusedTextAXHealthPolicy = FocusedTextAXHealthPolicy.typingResponsiveness
    private let focusedTextPollDiagnosticsPolicy = FocusedTextPollDiagnosticsPolicy.typingDiagnostics
    private let focusedTextAXHealthSuggestionVisibilityPolicy = FocusedTextAXHealthSuggestionVisibilityPolicy()
    private let focusedTextPollingThrottleSuggestionVisibilityPolicy =
        FocusedTextPollingThrottleSuggestionVisibilityPolicy()
    private let focusPollingCadencePolicy = FocusPollingCadencePolicy()
    private let recentWordExtractor = RecentWordExtractor()
    private let compatibilityLearningStore = CompatibilityLearningStore.shared
    private let suggestionPanel = SuggestionPanelController()
    private lazy var focusedTextReader = SerialFocusedTextAXReader(accessibilityClient: accessibilityClient)
    private let diagnosticsWindow = DiagnosticsWindowController()
    private let appProofCommandCoordinator = AppProofCommandCoordinator()
    private lazy var settingsWindow = SettingsWindowController(
        requestPermission: { [weak self] in
            self?.requestAccessibilityPermission()
        },
        openAccessibilitySettings: { [weak self] in
            self?.openAccessibilitySettings()
        },
        toggleSuggestionsPaused: { [weak self] in
            self?.togglePauseSuggestions()
        },
        silenceCurrentField: { [weak self] in
            self?.silenceCurrentField()
        },
        performRuntimeAction: { [weak self] action in
            self?.performRuntimeAction(action)
        },
        toggleCurrentApp: { [weak self] in
            self?.toggleCurrentApp()
        },
        toggleCurrentAppMirrorMode: { [weak self] in
            self?.toggleCurrentAppMirrorMode()
        },
        startCurrentAppProof: { [weak self] in
            self?.startCurrentAppProof()
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
        clearLearningData: { [weak self] in
            self?.clearLearningData()
        },
        cycleAcceptAllShortcut: { [weak self] in
            self?.cycleAcceptAllShortcut()
        },
        setAcceptAllShortcut: { [weak self] shortcut in
            self?.setAcceptAllShortcut(shortcut)
        },
        cycleSuggestionAggressiveness: { [weak self] in
            self?.cycleSuggestionAggressiveness()
        }
    )

    private var statusItem: NSStatusItem?
    private var statusMenuItem: NSMenuItem?
    private var runtimeMenuItem: NSMenuItem?
    private var pauseSuggestionsMenuItem: NSMenuItem?
    private var silenceFieldMenuItem: NSMenuItem?
    private var toggleAppMenuItem: NSMenuItem?
    private var workspaceFocusObservers: [NSObjectProtocol] = []
    private var pollTimer: Timer?
    private var keyboardEventTap: KeyboardEventTap?
    private var keyboardEventTapStopTask: Task<Void, Never>?
    private var suggestionSession = SuggestionSession()
    private var lastCaretRect: CGRect?
    private var lastTextLineRect: CGRect?
    private var lastClippingRect: CGRect?
    private var lastTextStyle: FocusedTextStyle?
    private var lastRenderMode: SuggestionRenderMode?
    private var lastCompatibilityLearningTrustContext: CompatibilityLearningVisualTrustContext?
    private var currentFieldIdentity: FocusedFieldIdentity?
    private var currentProfile: CompatibilityProfile?
    private var lastTextSnapshot: FocusedTextSnapshot?
    private var lastFocusedTextChangeAt: Date?
    private var lastRequestedTextBeforeCursor: String?
    private var suppressedFieldIdentities: Set<FocusedFieldIdentity> = []
    private var disabledBundleIdentifiers: Set<String> = []
    private var debounceTask: Task<Void, Never>?
    private var insertionVerificationTask: Task<Void, Never>?
    private let acceptanceSurvivalChecker = AcceptanceSurvivalChecker()
    private var acceptanceSurvivalTasks: [String: Task<Void, Never>] = [:]
    private var runtimeWarmTask: Task<Void, Never>?
    private var pauseExpirationTask: Task<Void, Never>?
    private let focusedFieldIdentityPolicy = FocusedFieldIdentityPolicy()
    private var isFocusedTextPollInFlight = false
    private var latestFocusedTextReadRequestID: UInt64?
    private var focusedTextAXHealthState = FocusedTextAXHealthState()
    private var focusedTextPollLatencyStats = FocusedTextPollLatencyStats()
    private var focusedTextPollSkipStats = FocusedTextPollSkipStats()
    private var suggestionBlockLogGate = SuggestionBlockLogGate()
    private var suggestionRepetitionSuppressor = SuggestionRepetitionSuppressor()
    private var currentSuggestionID: String?
    private var currentSuggestionAppBundleIdentifier: String?
    private var currentSuggestionFieldIdentity: FocusedFieldIdentity?
    private var currentSuggestionRequestMode: CompletionRequestMode?
    private var currentSuggestionTextBeforeCursor: String?
    private var currentSuggestionDisplayedText: String?
    private var currentSuggestionFieldClassification: AXFieldClassification?
    private var currentSuggestionPresentedAt: Date?
    private var currentSuggestionDisplayScoreFinal: Double?
    private var currentSuggestionInvalidatedByUserKeyDown = false
    private var recentWordMemory = ScopedRecentWordMemory()
    private var suppressKeyUntil: [AutocompleteKey: Date] = [:]
    private var pendingAcceptedInsertionUndo: AcceptedInsertionUndo?
    private var acceptedInsertionUndoExpirationTask: Task<Void, Never>?
    private var lastStatusLine: String?
    private var lastSuggestionDecision = "Starting"
    private var lastSyntheticCaretDiagnosticSignature: String?
    private var lastClaudeCodeTerminalProofInputSignature: String?
    private var lastTextContextRepairDiagnosticSignature: String?
    private var lastEligibleTargetApp: RunningApplicationInfo?
    private var lastObservedSettingsApp: RunningApplicationInfo?
    private var lastFieldControlTarget: FieldControlTarget?
    private var currentRuntimeState: LocalRuntimeState = .unavailable(reason: "starting")
    private var modelInstallTask: Task<Void, Never>?
    private var modelInstallStatusText: String?
    private var isModelInstallCancelRequested = false
    private let focusedTextPollInterval: TimeInterval = 0.05
    private let keyboardEventTapIdleStopDelayMilliseconds = 700
    private let postTypingPollPauseMilliseconds = 220
    private let postInsertionPollPauseMilliseconds = 220
    private let maximumPreservedSuggestionGeometryAgeDuringAXPauseMilliseconds = 750
    private var focusedTextPollingPause = FocusedTextPollingPause()
    private var lastFocusedTextPollAttemptAt: Date?
    private var suggestionsPaused = false
    private var suggestionsPausedUntil: Date?
    private var appEnablementSetupCompleted = true
    private var keyboardShortcutConfiguration = KeyboardShortcutConfiguration.default
    private var suggestionAggressiveness = SuggestionAggressiveness.normal

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("AutocompleteLab runs as a persistent menu bar agent.")
        NSApp.setActivationPolicy(.accessory)
        loadPauseState()
        loadDisabledApps()
        loadKeyboardShortcutConfiguration()
        loadSuggestionAggressiveness()
        loadAcceptedAndKeptLearning()
        loadAcceptedTextStyleMemory()
        loadProofModeOverrides()
        configureStatusItem()
        DiagnosticsLog.shared.record("launch", metadata: ["accessibility": String(accessibilityClient.isTrusted)])
        DiagnosticsLog.shared.record("runtime-bootstrap", metadata: modelRuntimeBundle.diagnosticsMetadata)
        if startupOnboardingPolicy.shouldRequestAccessibilityPromptOnLaunch(
            isTrusted: accessibilityClient.isTrusted
        ) {
            accessibilityClient.requestPermissionIfNeeded()
        }
        warmModelRuntime()
        if shouldShowSettingsForCurrentReadiness {
            showSettings()
        }
        startWorkspaceFocusObservers()
        startPolling()
    }

    func applicationWillTerminate(_ notification: Notification) {
        DiagnosticsLog.shared.record("terminate")
        debounceTask?.cancel()
        pauseExpirationTask?.cancel()
        keyboardEventTapStopTask?.cancel()
        insertionVerificationTask?.cancel()
        acceptedInsertionUndoExpirationTask?.cancel()
        runtimeWarmTask?.cancel()
        invalidatePendingSuggestionRequest()
        modelRuntime.cancel()
        pollTimer?.invalidate()
        stopWorkspaceFocusObservers()
        stopKeyboardEventTapNow(reason: "terminate")
    }

    private func startWorkspaceFocusObservers() {
        guard workspaceFocusObservers.isEmpty else {
            return
        }

        let center = NSWorkspace.shared.notificationCenter
        workspaceFocusObservers = [
            center.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleWorkspaceFocusChange(reason: "workspace-app-activated")
                }
            },
            center.addObserver(
                forName: NSWorkspace.didDeactivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleWorkspaceFocusChange(reason: "workspace-app-deactivated")
                }
            }
        ]
    }

    private func stopWorkspaceFocusObservers() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceFocusObservers.forEach { center.removeObserver($0) }
        workspaceFocusObservers.removeAll()
    }

    private func handleWorkspaceFocusChange(reason: String) {
        guard suggestionSession.hasVisibleSuggestion
            || suggestionOrchestrator.currentRequest != nil
            || currentFieldIdentity != nil else {
            return
        }

        setSuggestionDecision("Blocked: focus changed")
        clearFocusedFieldState(hideReason: "focus-changed", resetBlockLogGate: false)
        stopKeyboardEventTapNow(reason: reason)
        DiagnosticsLog.shared.record(
            "workspace-focus-changed",
            metadata: [
                "reason": reason
            ]
        )
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureStatusButton(item.button, configuration: .autocompleteLab)

        let menu = NSMenu()
        let statusMenu = NSMenuItem(title: "Status: starting", action: nil, keyEquivalent: "")
        let runtimeMenu = NSMenuItem(title: "Model: starting", action: nil, keyEquivalent: "")
        let pauseItem = NSMenuItem(title: pauseSuggestionsTitle, action: #selector(togglePauseSuggestions), keyEquivalent: "p")
        let pause15Item = NSMenuItem(title: "Pause for 15 Minutes", action: #selector(pauseSuggestionsFor15Minutes), keyEquivalent: "")
        let pause1HourItem = NSMenuItem(title: "Pause for 1 Hour", action: #selector(pauseSuggestionsFor1Hour), keyEquivalent: "")
        let silenceFieldItem = NSMenuItem(
            title: "Silence This Field",
            action: #selector(silenceCurrentField),
            keyEquivalent: "s"
        )
        let toggleItem = NSMenuItem(title: "Toggle Current App", action: #selector(toggleCurrentApp), keyEquivalent: "t")
        let debugMenuItem = NSMenuItem(title: "Debug", action: nil, keyEquivalent: "")
        let debugMenu = NSMenu()

        menu.addItem(NSMenuItem(title: "Autocomplete Lab", action: nil, keyEquivalent: ""))
        menu.addItem(statusMenu)
        menu.addItem(runtimeMenu)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(pauseItem)
        menu.addItem(pause15Item)
        menu.addItem(pause1HourItem)
        menu.addItem(silenceFieldItem)
        menu.addItem(toggleItem)
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
        silenceFieldMenuItem = silenceFieldItem
        toggleAppMenuItem = toggleItem
        refreshRuntimeChrome()
    }

    private func configureStatusButton(
        _ button: NSStatusBarButton?,
        configuration: MenuBarStatusItemConfiguration
    ) {
        guard let button else {
            return
        }

        if let image = NSImage(
            systemSymbolName: configuration.symbolName,
            accessibilityDescription: configuration.accessibilityLabel
        ) {
            image.isTemplate = true
            button.image = image
            button.title = ""
        } else {
            button.title = configuration.fallbackTitle
        }
        button.toolTip = configuration.accessibilityLabel
    }

    private func startPolling() {
        let timer = Timer.scheduledTimer(withTimeInterval: focusedTextPollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollFocusedTextIfIdle()
            }
        }
        timer.tolerance = focusedTextPollInterval / 2
        pollTimer = timer
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

    private func applyRuntimeState(_ state: LocalRuntimeState) {
        let wasReadyForSuggestions = runtimeReadinessReport.allowsSuggestions
        currentRuntimeState = state
        refreshRuntimeChrome()
        let report = runtimeReadinessReport
        if report.allowsSuggestions,
           modelInstallTask == nil,
           modelInstallStatusText != nil {
            modelInstallStatusText = "Model install: ready"
            refreshRuntimeChrome()
        }
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
        lastFocusedTextChangeAt = nil
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
        if settingsWindow.isShowing {
            settingsWindow.refresh(
                isTrusted: accessibilityClient.isTrusted,
                suggestionsPaused: suggestionsPaused,
                runtimeReport: runtimeReadinessReport,
                runtimeTargetSummary: runtimeTargetSummary,
                modelDirectoryPath: modelDirectoryPath,
                modelInstallStatusText: modelInstallStatusText,
                isModelInstallInProgress: modelInstallTask != nil,
                currentApp: settingsCurrentAppState,
                fieldControl: settingsFieldControlState,
                privacy: settingsPrivacyState,
                keyboardShortcuts: settingsKeyboardShortcutState,
                suggestionAggressiveness: settingsSuggestionAggressivenessState,
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
                disabledAppCount: disabledBundleIdentifiers.count,
                renderModeOverride: nil
            )
        }

        return SettingsCurrentAppState(
            displayName: app.localizedName,
            bundleIdentifier: app.bundleIdentifier,
            supportStatus: profileStore.supportStatus(for: app.bundleIdentifier),
            isEnabled: !disabledBundleIdentifiers.contains(app.bundleIdentifier),
            disabledAppCount: disabledBundleIdentifiers.count,
            renderModeOverride: compatibilityLearningStore.profile(for: app.bundleIdentifier)?.renderModeOverride
        )
    }

    private var settingsFieldControlState: SettingsFieldControlState {
        guard let target = fieldControlTarget else {
            return SettingsFieldControlState(
                appDisplayName: nil,
                hasFieldTarget: false,
                isCurrentField: false,
                isSilenced: false
            )
        }

        return SettingsFieldControlState(
            appDisplayName: target.appDisplayName,
            hasFieldTarget: true,
            isCurrentField: target.fieldIdentity == currentFieldIdentity,
            isSilenced: suppressedFieldIdentities.contains(target.fieldIdentity)
        )
    }

    private var fieldControlTarget: FieldControlTarget? {
        if let currentFieldIdentity,
           let target = lastFieldControlTarget,
           target.fieldIdentity == currentFieldIdentity {
            return target
        }

        return lastFieldControlTarget
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

    private func rememberFieldControlTarget(
        app: RunningApplicationInfo,
        fieldIdentity: FocusedFieldIdentity,
        requestMode: CompletionRequestMode?,
        fieldKind: AXFieldKind
    ) {
        lastFieldControlTarget = FieldControlTarget(
            appBundleIdentifier: app.bundleIdentifier,
            appDisplayName: app.localizedName,
            fieldIdentity: fieldIdentity,
            requestMode: requestMode,
            fieldKind: fieldKind
        )
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

    private var settingsSuggestionAggressivenessState: SettingsSuggestionAggressivenessState {
        SettingsSuggestionAggressivenessState(aggressiveness: suggestionAggressiveness)
    }

    private var runtimeTargetSummary: String {
        "\(modelRuntimeBundle.bootstrapPlan.preferredAsset.model.rawValue) • \(completionLengthConfiguration.displaySummary) • \(suggestionAggressiveness.displayName.lowercased())"
    }

    private var shouldShowSettingsForCurrentReadiness: Bool {
        startupOnboardingPolicy.shouldShowSettingsOnLaunch(
            isTrusted: accessibilityClient.isTrusted,
            runtimeStage: runtimeReadinessReport.stage,
            appEnablementSetupCompleted: appEnablementSetupCompleted
        )
    }

    private var pauseSuggestionsTitle: String {
        suggestionControlState.toggleTitle
    }

    private var pauseStatusTitle: String {
        guard let suggestionsPausedUntil,
              suggestionsPausedUntil > Date() else {
            return "Paused"
        }

        let time = DateFormatter.localizedString(
            from: suggestionsPausedUntil,
            dateStyle: .none,
            timeStyle: .short
        )
        return "Paused until \(time)"
    }

    private var suggestionControlState: SuggestionControlState {
        expireTimedPauseIfNeeded(now: Date())
        return suggestionControlPolicy.state(isPaused: suggestionsPaused)
    }

    private func pollFocusedTextIfIdle() {
        let now = Date()
        guard shouldRunFocusedTextPoll(now: now) else {
            return
        }
        lastFocusedTextPollAttemptAt = now

        guard !isFocusedTextPollInFlight else {
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
        }

        isFocusedTextPollInFlight = true
        let startedAt = DispatchTime.now().uptimeNanoseconds
        var completesAsync = false
        pollFocusedText(startedAt: startedAt, completesAsync: &completesAsync)
        if !completesAsync {
            finishFocusedTextPoll(startedAt: startedAt)
        }
    }

    private func shouldRunFocusedTextPoll(now: Date) -> Bool {
        let activeApp = accessibilityClient.frontmostApplication()
        let hasSupportedProfile = activeApp.flatMap { app -> Bool? in
            guard let profile = effectiveProfile(for: app) else {
                return false
            }

            return profile.canPresentSuggestions
                && !profile.isSensitive
                && isSuggestionEnabled(for: app, profile: profile)
        } ?? false
        let interval = focusPollingCadencePolicy.interval(
            isTrustedForAccessibility: accessibilityClient.isTrusted,
            hasSupportedProfile: hasSupportedProfile,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion,
            hasRecentTextChange: focusPollingCadencePolicy.hasRecentTextChange(
                lastTextChangeAt: lastFocusedTextChangeAt,
                now: now
            )
        )

        guard let lastFocusedTextPollAttemptAt else {
            return true
        }

        return now.timeIntervalSince(lastFocusedTextPollAttemptAt) >= interval
    }

    private func effectiveProfile(for app: RunningApplicationInfo) -> CompatibilityProfile? {
        if let terminalProofProfile = claudeCodeTerminalHostProofProfile(for: app) {
            return terminalProofProfile
        }

        return profileStore.profile(for: app.bundleIdentifier)
    }

    private func isSuggestionEnabled(
        for app: RunningApplicationInfo,
        profile: CompatibilityProfile
    ) -> Bool {
        if isClaudeCodeTerminalHostProof(profile: profile, hostBundleIdentifier: app.bundleIdentifier) {
            return activeAppProofBundleIdentifiers.contains(
                ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier
            )
        }

        return !disabledBundleIdentifiers.contains(app.bundleIdentifier)
    }

    private func claudeCodeTerminalHostProofProfile(for app: RunningApplicationInfo) -> CompatibilityProfile? {
        guard ClaudeCodeTerminalHostProofPolicy.supportedTerminalHosts.contains(app.bundleIdentifier),
              activeAppProofBundleIdentifiers.contains(
                  ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier
              ) else {
            return nil
        }

        return ClaudeCodeTerminalHostProofPolicy.proofProfile
    }

    private func isClaudeCodeTerminalHostProof(
        profile: CompatibilityProfile,
        hostBundleIdentifier: String
    ) -> Bool {
        profile.bundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier
            && ClaudeCodeTerminalHostProofPolicy.supportedTerminalHosts.contains(hostBundleIdentifier)
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
                profile: frontmostApp.flatMap { effectiveProfile(for: $0) },
                appEnabled: frontmostApp
                    .flatMap { app in effectiveProfile(for: app).map { isSuggestionEnabled(for: app, profile: $0) } }
                    ?? false
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
              let profile = effectiveProfile(for: frontmostApp) else {
            clearFocusedFieldState()
            currentProfile = nil
            setSuggestionDecision("Blocked: unsupported app")
            updateStatusMenu(app: activeApp, profile: nil, appEnabled: false)
            hideSuggestion()
            return
        }

        rememberEligibleTargetApp(frontmostApp)
        let appEnabled = isSuggestionEnabled(for: frontmostApp, profile: profile)
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
                await self?.completeFocusedTextPoll(
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
    ) async {
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

        if focusedTextPollDiagnosticsPolicy.shouldRecordSlowAXReadMarker(
            queueDelayMilliseconds: result.queueDelayMilliseconds,
            readDurationMilliseconds: result.readDurationMilliseconds
        ) {
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

        if applyFocusedTextPollingThrottleIfNeeded(
            focusedTextPollingBackoffPolicy.throttleRecommendation(
                queueDelayMilliseconds: result.queueDelayMilliseconds,
                readDurationMilliseconds: result.readDurationMilliseconds
            )
        ) {
            setSuggestionDecision("Waiting: AX read")
            return
        }

        guard let activeApp = accessibilityClient.frontmostApplication(),
              activeApp.bundleIdentifier == result.app.bundleIdentifier,
              activeApp.processIdentifier == result.app.processIdentifier else {
            setSuggestionDecision("Blocked: focus changed")
            hideSuggestion(reason: "focus-changed")
            return
        }

        if result.context == nil {
            recordMissingFocusedContextDiagnostics(app: result.app, profile: profile)
        }

        guard let rawContext = result.context, !rawContext.isSecure else {
            clearFocusedFieldState()
            currentProfile = profile
            setSuggestionDecision("Blocked: no editable text field or secure field")
            hideSuggestion()
            return
        }

        await processFocusedTextContext(
            rawContext,
            frontmostApp: result.app,
            profile: profile
        )
    }

    private func recordMissingFocusedContextDiagnostics(
        app: RunningApplicationInfo,
        profile: CompatibilityProfile
    ) {
        guard let diagnostics = accessibilityClient.focusedTextDiagnostics(
            for: app,
            allowDescendantTextFallback: profile.allowsDescendantTextFallback
        ) else {
            DiagnosticsLog.shared.record(
                "focused-text-context-missing",
                metadata: [
                    "app": app.bundleIdentifier,
                    "diagnostics": "unavailable"
                ]
            )
            return
        }

        let searchable = diagnostics.fingerprint.searchableText
        DiagnosticsLog.shared.record(
            "focused-text-context-missing",
            metadata: [
                "app": app.bundleIdentifier,
                "role": diagnostics.role ?? "none",
                "subrole": diagnostics.subrole ?? "none",
                "selectedRange": diagnostics.selectedRangeDescription,
                "isSecure": String(diagnostics.isSecure),
                "beforeChars": String(diagnostics.textBeforeCursorLength),
                "afterChars": String(diagnostics.textAfterCursorLength),
                "hasCaretRect": String(diagnostics.caretRect != nil),
                "hasElementRect": String(diagnostics.elementRect != nil),
                "hasWindowRect": String(diagnostics.windowRect != nil),
                "canReadValue": String(diagnostics.capabilities.canReadValue),
                "canReadRange": String(diagnostics.capabilities.canReadSelectedTextRange),
                "canReadBounds": String(diagnostics.capabilities.canReadBoundsForRange),
                "canSetSelectedText": String(diagnostics.capabilities.canSetSelectedText),
                "chromeSmokeHint": String(searchable.contains("autocomplete lab chrome")
                    && searchable.contains("smoke")),
                "monacoHint": String(searchable.contains("monaco")),
                "prosemirrorHint": String(searchable.contains("prosemirror")),
                "attributeNames": diagnostics.attributeDump.attributes
                    .map(\.name)
                    .joined(separator: ",")
            ]
        )
    }

    private func processFocusedTextContext(
        _ rawContext: FocusedTextContext,
        frontmostApp: RunningApplicationInfo,
        profile: CompatibilityProfile
    ) async {
        if let terminalHostBlockReason = claudeCodeTerminalHostProofBlockReason(
            app: frontmostApp,
            context: rawContext,
            profile: profile
        ) {
            clearFocusedFieldState(resetBlockLogGate: false)
            currentProfile = profile
            setSuggestionDecision("Blocked: \(terminalHostBlockReason)")
            recordBlockedSuggestionEvent(
                "suggestion-blocked",
                context: rawContext,
                profile: profile,
                fieldIdentity: fieldIdentity(app: frontmostApp, context: rawContext, profile: profile),
                metadata: [
                    "reason": terminalHostBlockReason,
                    "terminalHostBundleIdentifier": frontmostApp.bundleIdentifier
                ]
            )
            hideSuggestion()
            return
        }

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

        let hostedSurfaceDecision = browserHostedSurfacePolicy.decision(
            bundleIdentifier: frontmostApp.bundleIdentifier,
            fingerprint: rawContext.fingerprint
        )
        guard case let .blocked(hostedSurfaceBlock) = hostedSurfaceDecision else {
            return await continueProcessingFocusedTextContext(
                rawContext,
                frontmostApp: frontmostApp,
                profile: profile
            )
        }

        let hostedSurfaceFieldIdentity = fieldIdentity(
            app: frontmostApp,
            context: rawContext,
            profile: profile
        )
        clearFocusedFieldState(resetBlockLogGate: false)
        currentProfile = profile
        setSuggestionDecision("Blocked: \(hostedSurfaceBlock.userFacingReason)")
        RawAutocompleteTraceLog.shared.record(
            type: .suggestionSuppressed,
            suggestionID: UUID().uuidString,
            appBundleIdentifier: profile.bundleIdentifier,
            fieldIdentity: hostedSurfaceFieldIdentity.traceDescription,
            requestMode: "",
            triggerReason: "browser-hosted-surface-policy",
            textBeforeCursor: rawContext.textBeforeCursor,
            textAfterCursor: rawContext.textAfterCursor,
            reason: hostedSurfaceBlock.traceReason,
            metadata: hostedSurfaceBlock.traceMetadata
        )
        recordBlockedSuggestionEvent(
            "suggestion-blocked",
            context: rawContext,
            profile: profile,
            fieldIdentity: hostedSurfaceFieldIdentity,
            metadata: hostedSurfaceBlock.traceMetadata
        )
        hideSuggestion(reason: hostedSurfaceBlock.traceReason)
    }

    private func continueProcessingFocusedTextContext(
        _ rawContext: FocusedTextContext,
        frontmostApp: RunningApplicationInfo,
        profile: CompatibilityProfile
    ) async {
        let rawFieldIdentity = fieldIdentity(
            app: frontmostApp,
            context: rawContext,
            profile: profile
        )
        transitionToField(rawFieldIdentity)

        let previousSnapshot = lastTextSnapshot
        let context = presentationAdjustedContext(
            rawContext,
            app: frontmostApp,
            profile: profile,
            previousSnapshot: previousSnapshot
        )
        let fieldIdentity = fieldIdentity(
            app: frontmostApp,
            context: context,
            profile: profile
        )
        let fieldClassification = fieldClassification(for: context)
        rememberFieldControlTarget(
            app: frontmostApp,
            fieldIdentity: fieldIdentity,
            requestMode: nil,
            fieldKind: fieldClassification.kind
        )

        let snapshot = FocusedTextSnapshot(
            fieldIdentity: fieldIdentity,
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor
        )

        guard snapshot != previousSnapshot else {
            setSuggestionDecision(
                suggestionSession.hasVisibleSuggestion
                    ? "Shown: tracking current field"
                    : "Ready: waiting for text change"
            )
            repositionVisibleSuggestion(context: context, profile: profile)
            return
        }

        if previousSnapshot != nil {
            lastFocusedTextChangeAt = Date()
        }

        recordTypedOverSuggestionIfNeeded(
            newTextBeforeCursor: context.textBeforeCursor,
            fieldIdentity: fieldIdentity,
            profile: profile
        )
        rememberTypedWordsIfNeeded(
            previousSnapshot: previousSnapshot,
            currentSnapshot: snapshot,
            appBundleIdentifier: frontmostApp.bundleIdentifier
        )
        if advanceVisibleSuggestionForTypingProgressIfNeeded(
            context: context,
            profile: profile,
            fieldIdentity: fieldIdentity,
            snapshot: snapshot
        ) {
            return
        }

        lastTextSnapshot = snapshot
        invalidatePendingSuggestionRequest()
        if suggestionCadenceResetPolicy.shouldResetLastRequestedText(
            previousTextBeforeCursor: previousSnapshot?.textBeforeCursor,
            currentTextBeforeCursor: context.textBeforeCursor,
            selectedTextLength: context.selectedTextLength
        ) {
            lastRequestedTextBeforeCursor = nil
        }

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

        let activationDecision = activationPolicy.decision(
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            isSecure: context.isSecure,
            selectedTextLength: context.selectedTextLength,
            isFieldSuppressed: suppressedFieldIdentities.contains(fieldIdentity),
            fieldKind: fieldClassification.kind
        )
        rememberFieldControlTarget(
            app: frontmostApp,
            fieldIdentity: fieldIdentity,
            requestMode: activationDecision.requestMode,
            fieldKind: fieldClassification.kind
        )

        guard activationDecision.canSuggest else {
            setSuggestionDecision("Blocked: \(activationDecision.blockReasonDescription)")
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: UUID().uuidString,
                appBundleIdentifier: profile.bundleIdentifier,
                fieldIdentity: fieldIdentity.traceDescription,
                requestMode: activationDecision.requestMode?.rawValue ?? "",
                triggerReason: "activation-policy",
                textBeforeCursor: context.textBeforeCursor,
                textAfterCursor: context.textAfterCursor,
                reason: activationDecision.blockReasonDescription,
                metadata: fieldClassification.traceMetadata
            )
            recordBlockedSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                metadata: [
                    "reason": activationDecision.blockReasonDescription
                ]
                .merging(fieldClassification.traceMetadata) { current, _ in current }
            )
            hideSuggestion()
            return
        }

        let requestMode = activationDecision.requestMode ?? .phraseContinuation
        let prefixCooldownInput = PrefixFamilyCooldownInput(
            appBundleIdentifier: profile.bundleIdentifier,
            fieldIdentifier: fieldIdentity.traceDescription,
            requestMode: requestMode,
            textBeforeCursor: context.textBeforeCursor
        )
        if let previousSnapshot,
           previousSnapshot.fieldIdentity == fieldIdentity,
           context.textBeforeCursor.count < previousSnapshot.textBeforeCursor.count {
            _ = recordPrefixFamilyCooldown(.deletion, input: prefixCooldownInput)
        }

        switch suggestionOrchestrator.prefixCooldownDecision(for: prefixCooldownInput) {
        case .allowed:
            break
        case let .coolingDown(cooldown):
            setSuggestionDecision("Waiting: prefix \(cooldown.reason.rawValue)")
            let metadata = fieldClassification.traceMetadata
                .merging(cooldown.metadata) { current, _ in current }
                .merging(["reason": "prefix-family-cooldown"]) { current, _ in current }
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: UUID().uuidString,
                appBundleIdentifier: profile.bundleIdentifier,
                fieldIdentity: fieldIdentity.traceDescription,
                requestMode: requestMode.rawValue,
                triggerReason: "prefix-family-cooldown",
                textBeforeCursor: context.textBeforeCursor,
                textAfterCursor: context.textAfterCursor,
                reason: cooldown.reason.rawValue,
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

        let annoyanceContext = annoyanceContext(
            appBundleIdentifier: profile.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            requestMode: requestMode,
            fieldKind: fieldClassification.kind
        )
        let quietMode = await annoyanceSuppressor.quietMode(for: annoyanceContext)
        guard !quietMode.isActive else {
            setSuggestionDecision("Waiting: \(quietMode.traceReason)")
            let metadata = fieldClassification.traceMetadata
                .merging(quietMode.metadata) { current, _ in current }
                .merging(["reason": quietMode.traceReason]) { current, _ in current }
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: UUID().uuidString,
                appBundleIdentifier: profile.bundleIdentifier,
                fieldIdentity: fieldIdentity.traceDescription,
                requestMode: requestMode.rawValue,
                triggerReason: "annoyance-quiet-mode",
                textBeforeCursor: context.textBeforeCursor,
                textAfterCursor: context.textAfterCursor,
                reason: quietMode.traceReason,
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
        let renderMode = compatibilityLearningStore.engine()
            .adjustment(for: profile.bundleIdentifier, profileRenderMode: baseRenderMode)
            .effectiveRenderMode

        if shouldSuppressDetachedSuggestion(
            profile: profile,
            context: context,
            renderMode: renderMode
        ) {
            setSuggestionDecision("Blocked: detached suggestion disabled")
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: UUID().uuidString,
                appBundleIdentifier: profile.bundleIdentifier,
                fieldIdentity: fieldIdentity.traceDescription,
                requestMode: (activationDecision.requestMode ?? .phraseContinuation).rawValue,
                triggerReason: "policy",
                textBeforeCursor: context.textBeforeCursor,
                textAfterCursor: context.textAfterCursor,
                reason: "detached-suggestion-disabled",
                metadata: traceGeometryMetadata(context: context, renderMode: renderMode)
            )
            recordBlockedSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                metadata: [
                    "reason": "detached-suggestion-disabled"
                ]
            )
            hideSuggestion()
            return
        }

        let currentLineStructure = CurrentLineStructure.from(textBeforeCursor: context.textBeforeCursor)
        let triggerBehaviorProfile = AutocompleteBehaviorProfileResolver().profile(for: AutocompleteBehaviorProfileInput(
            appBundleIdentifier: frontmostApp.bundleIdentifier,
            fieldKind: fieldClassification.kind,
            currentLineStructure: currentLineStructure
        ))
        let triggerDecision = triggerPolicy.decision(
            previousTextBeforeCursor: lastRequestedTextBeforeCursor,
            currentTextBeforeCursor: context.textBeforeCursor,
            lineStartBehavior: SuggestionLineStartBehavior.behavior(
                for: triggerBehaviorProfile.id,
                currentLineStructure: currentLineStructure
            ),
            behaviorProfileID: triggerBehaviorProfile.id
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

        setSuggestionDecision("Queued: \(requestMode.rawValue)")
        scheduleSuggestion(
            context: context,
            profile: profile,
            appBundleIdentifier: suggestionBundleIdentifier(for: frontmostApp, profile: profile),
            fieldIdentity: fieldIdentity,
            fieldClassification: fieldClassification,
            renderMode: renderMode,
            delayMilliseconds: delayMilliseconds,
            requestMode: requestMode
        )
    }

    private func claudeCodeTerminalHostProofBlockReason(
        app: RunningApplicationInfo,
        context: FocusedTextContext,
        profile: CompatibilityProfile
    ) -> String? {
        guard isClaudeCodeTerminalHostProof(
            profile: profile,
            hostBundleIdentifier: app.bundleIdentifier
        ) else {
            return nil
        }

        let focusedLine = ClaudeCodeTerminalHostProofPolicy.focusedInputLine(
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor
        )
        let decision = ClaudeCodeTerminalHostProofPolicy.evaluate(
            ClaudeCodeTerminalHostProofContext(
                hostBundleIdentifier: app.bundleIdentifier,
                windowTitle: context.fingerprint.windowTitle ?? "",
                focusedText: focusedLine,
                proofModeEnabled: activeAppProofBundleIdentifiers.contains(
                    ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier
                )
            )
        )

        switch decision {
        case .eligible:
            return nil
        case let .blocked(reason):
            return "claude-code-terminal-host-\(reason.rawValue)"
        }
    }

    private func suggestionBundleIdentifier(
        for app: RunningApplicationInfo,
        profile: CompatibilityProfile
    ) -> String {
        if isClaudeCodeTerminalHostProof(profile: profile, hostBundleIdentifier: app.bundleIdentifier) {
            return ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier
        }

        return app.bundleIdentifier
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
            handleFocusedTextAXHealthCooldown(cooldown, source: "poll")
            setSuggestionDecision("Waiting: AX cooldown")
            return false
        }
    }

    private func applyFocusedTextAXHealthObservation(_ result: FocusedTextAXReadResult) -> Bool {
        let observation = focusedTextAXHealthPolicy.recordRead(
            bundleIdentifier: result.app.bundleIdentifier,
            queueDelayMilliseconds: result.queueDelayMilliseconds,
            readDurationMilliseconds: result.readDurationMilliseconds,
            hasContext: result.context != nil,
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
        handleFocusedTextAXHealthCooldown(cooldown, source: "read")
        setSuggestionDecision("Waiting: AX cooldown")
        return true
    }

    private func handleFocusedTextAXHealthCooldown(
        _ cooldown: FocusedTextAXHealthCooldown,
        source: String
    ) {
        invalidatePendingSuggestionRequest()
        guard suggestionSession.hasVisibleSuggestion else {
            return
        }

        if focusedTextAXHealthSuggestionVisibilityPolicy.shouldHideVisibleSuggestion(
            during: cooldown,
            currentSuggestionBundleIdentifier: currentSuggestionAppBundleIdentifier,
            currentSuggestionFieldIdentity: currentSuggestionFieldIdentity,
            currentFieldIdentity: currentFieldIdentity,
            isInvalidatedByUserTyping: currentSuggestionInvalidatedByUserKeyDown,
            currentSuggestionAgeMilliseconds: currentSuggestionAgeMilliseconds(),
            maximumPreservedAgeMilliseconds: maximumPreservedSuggestionGeometryAgeDuringAXPauseMilliseconds
        ) {
            hideSuggestion(reason: "focused-text-ax-health-\(cooldown.reason.rawValue)")
            return
        }

        updateKeyboardEventTapSnapshot()
        DiagnosticsLog.shared.record(
            "focused-text-ax-health-suggestion-preserved",
            metadata: [
                "app": cooldown.bundleIdentifier,
                "reason": cooldown.reason.rawValue,
                "source": source,
                "remainingMilliseconds": String(cooldown.remainingMilliseconds),
                "suggestionAgeMilliseconds": currentSuggestionAgeMilliseconds().map(String.init) ?? "unknown",
                "maximumPreservedAgeMilliseconds": String(maximumPreservedSuggestionGeometryAgeDuringAXPauseMilliseconds)
            ]
        )
    }

    private func recordFocusedTextPollLatency(_ durationMilliseconds: Int) {
        if focusedTextPollDiagnosticsPolicy.shouldRecordSlowPollMarker(
            durationMilliseconds: durationMilliseconds
        ) {
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

    @discardableResult
    private func applyFocusedTextPollingThrottleIfNeeded(
        _ recommendation: FocusedTextPollingThrottleRecommendation
    ) -> Bool {
        guard recommendation.shouldThrottle,
              let reason = recommendation.reason,
              recommendation.pauseMilliseconds > 0 else {
            return false
        }

        focusedTextPollingPause.pause(
            now: Date(),
            durationMilliseconds: recommendation.pauseMilliseconds,
            policy: focusedTextPollingBackoffPolicy
        )
        invalidatePendingSuggestionRequest()
        if suggestionSession.hasVisibleSuggestion {
            let frontmostBundleIdentifier = accessibilityClient.frontmostApplication()?.bundleIdentifier
            if focusedTextPollingThrottleSuggestionVisibilityPolicy.shouldHideVisibleSuggestion(
                currentSuggestionBundleIdentifier: currentSuggestionAppBundleIdentifier,
                currentSuggestionFieldIdentity: currentSuggestionFieldIdentity,
                currentFieldIdentity: currentFieldIdentity,
                frontmostBundleIdentifier: frontmostBundleIdentifier,
                isInvalidatedByUserTyping: currentSuggestionInvalidatedByUserKeyDown,
                currentSuggestionAgeMilliseconds: currentSuggestionAgeMilliseconds(),
                maximumPreservedAgeMilliseconds: maximumPreservedSuggestionGeometryAgeDuringAXPauseMilliseconds
            ) {
                hideSuggestion(reason: "focused-text-poll-\(reason.rawValue)")
            } else {
                updateKeyboardEventTapSnapshot()
                DiagnosticsLog.shared.record(
                    "focused-text-poll-suggestion-preserved",
                    metadata: [
                        "app": currentSuggestionAppBundleIdentifier ?? "",
                        "frontmostApp": frontmostBundleIdentifier ?? "",
                        "reason": reason.rawValue,
                        "pauseMilliseconds": String(recommendation.pauseMilliseconds),
                        "suggestionAgeMilliseconds": currentSuggestionAgeMilliseconds().map(String.init) ?? "unknown",
                        "maximumPreservedAgeMilliseconds": String(maximumPreservedSuggestionGeometryAgeDuringAXPauseMilliseconds)
                    ]
                )
            }
        }
        DiagnosticsLog.shared.record(
            "focused-text-poll-throttled",
            metadata: [
                "reason": reason.rawValue,
                "pauseMilliseconds": String(recommendation.pauseMilliseconds)
            ]
        )
        return true
    }

    private func currentSuggestionAgeMilliseconds(now: Date = Date()) -> Int? {
        guard let currentSuggestionPresentedAt else {
            return nil
        }

        return max(0, Int(now.timeIntervalSince(currentSuggestionPresentedAt) * 1000))
    }

    private func shouldSuppressDetachedSuggestion(
        profile: CompatibilityProfile,
        context: FocusedTextContext,
        renderMode: SuggestionRenderMode
    ) -> Bool {
        renderMode == .floatingMirror
            && context.caretRect == nil
            && !profile.allowsDetachedSuggestions
    }

    private func presentationAdjustedContext(
        _ context: FocusedTextContext,
        app: RunningApplicationInfo,
        profile: CompatibilityProfile,
        previousSnapshot: FocusedTextSnapshot? = nil
    ) -> FocusedTextContext {
        let repair = textContextRepairPolicy.repair(TextContextRepairInput(
            bundleIdentifier: app.bundleIdentifier,
            role: context.role,
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            selectedTextLength: context.selectedTextLength,
            previousTextBeforeCursor: previousSnapshot?.textBeforeCursor,
            previousTextAfterCursor: previousSnapshot?.textAfterCursor
        ))
        var context = repair.wasRepaired
            ? contextReplacingText(
                context,
                textBeforeCursor: repair.textBeforeCursor,
                textAfterCursor: repair.textAfterCursor
            )
            : context
        if repair.wasRepaired {
            recordTextContextRepairIfNeeded(repair, context: context, profile: profile)
        }

        if let proofInputText = claudeCodeTerminalHostProofInputText(
            app: app,
            context: context,
            profile: profile
        ) {
            context = contextReplacingText(
                context,
                textBeforeCursor: proofInputText,
                textAfterCursor: ""
            )
            recordClaudeCodeTerminalHostProofInputRepair(
                context: context,
                hostBundleIdentifier: app.bundleIdentifier,
                profile: profile
            )
        }

        let syntheticCaretBundleIdentifier = syntheticTextAreaCaretBundleIdentifier(
            for: app,
            profile: profile
        )
        guard supportsSyntheticTextAreaCaret(for: app, profile: profile),
              promptTextAreaMatch(for: app.bundleIdentifier, context: context).canSuggest,
              context.caretRect == nil,
              let syntheticCaret = syntheticTextAreaCaretRect(
                for: context,
                bundleIdentifier: syntheticCaretBundleIdentifier
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
            selectedTextLength: context.selectedTextLength,
            caretRect: syntheticCaret,
            elementRect: context.elementRect,
            windowRect: context.windowRect,
            textLineRect: syntheticCaret,
            textStyle: context.textStyle,
            isSecure: context.isSecure,
            caretIsSynthetic: true,
            capabilities: capabilities
        )
    }

    private func contextReplacingText(
        _ context: FocusedTextContext,
        textBeforeCursor: String,
        textAfterCursor: String
    ) -> FocusedTextContext {
        FocusedTextContext(
            elementIdentifier: context.elementIdentifier,
            role: context.role,
            subrole: context.subrole,
            fingerprint: context.fingerprint,
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor,
            selectedTextLength: context.selectedTextLength,
            caretRect: context.caretRect,
            elementRect: context.elementRect,
            windowRect: context.windowRect,
            textLineRect: context.textLineRect,
            textStyle: context.textStyle,
            isSecure: context.isSecure,
            caretIsSynthetic: context.caretIsSynthetic,
            capabilities: context.capabilities
        )
    }

    private func claudeCodeTerminalHostProofInputText(
        app: RunningApplicationInfo,
        context: FocusedTextContext,
        profile: CompatibilityProfile
    ) -> String? {
        guard isClaudeCodeTerminalHostProof(
            profile: profile,
            hostBundleIdentifier: app.bundleIdentifier
        ),
              claudeCodeTerminalHostProofBlockReason(
                app: app,
                context: context,
                profile: profile
              ) == nil else {
            return nil
        }

        return ClaudeCodeTerminalHostProofPolicy.proofInputText(
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor
        )
    }

    private func recordClaudeCodeTerminalHostProofInputRepair(
        context: FocusedTextContext,
        hostBundleIdentifier: String,
        profile: CompatibilityProfile
    ) {
        let signature = [
            hostBundleIdentifier,
            String(context.elementIdentifier),
            String(context.textBeforeCursor.count),
            String(context.textAfterCursor.count)
        ].joined(separator: "|")

        guard signature != lastClaudeCodeTerminalProofInputSignature else {
            return
        }

        lastClaudeCodeTerminalProofInputSignature = signature
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-input",
            metadata: [
                "app": profile.bundleIdentifier,
                "host": hostBundleIdentifier,
                "source": "focused-input-line",
                "beforeChars": String(context.textBeforeCursor.count),
                "afterChars": String(context.textAfterCursor.count)
            ]
        )
    }

    private func supportsSyntheticTextAreaCaret(
        for app: RunningApplicationInfo,
        profile: CompatibilityProfile
    ) -> Bool {
        if isClaudeCodeTerminalHostProof(
            profile: profile,
            hostBundleIdentifier: app.bundleIdentifier
        ) {
            return true
        }

        return PromptEditorFingerprintPolicy.dogfoodBundleIdentifiers.contains(app.bundleIdentifier)
            || app.bundleIdentifier == "md.obsidian"
            || app.bundleIdentifier == "com.google.Chrome"
    }

    private func syntheticTextAreaCaretBundleIdentifier(
        for app: RunningApplicationInfo,
        profile: CompatibilityProfile
    ) -> String {
        if isClaudeCodeTerminalHostProof(
            profile: profile,
            hostBundleIdentifier: app.bundleIdentifier
        ) {
            return profile.bundleIdentifier
        }

        return app.bundleIdentifier
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
            centerSingleLineWhenTall: tuning.centerSingleLineWhenTall,
            widthOfText: { width(of: $0, font: font) }
        )
    }

    private struct SyntheticTextAreaTuning {
        let font: NSFont?
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        let inlineGap: CGFloat
        let centerSingleLineWhenTall: Bool
    }

    private func syntheticTextAreaTuning(
        for context: FocusedTextContext,
        bundleIdentifier: String
    ) -> SyntheticTextAreaTuning {
        if bundleIdentifier == "com.anthropic.claudefordesktop" {
            return SyntheticTextAreaTuning(
                font: NSFont.systemFont(ofSize: 21),
                horizontalPadding: 14,
                verticalPadding: 4,
                inlineGap: 2,
                centerSingleLineWhenTall: true
            )
        }

        if bundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier {
            return SyntheticTextAreaTuning(
                font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                horizontalPadding: 18,
                verticalPadding: 4,
                inlineGap: 8,
                centerSingleLineWhenTall: false
            )
        }

        if PromptEditorFingerprintPolicy.dogfoodBundleIdentifiers.contains(bundleIdentifier) {
            return SyntheticTextAreaTuning(
                font: NSFont.systemFont(ofSize: 15),
                horizontalPadding: 0,
                verticalPadding: 4,
                inlineGap: 8,
                centerSingleLineWhenTall: false
            )
        }

        guard bundleIdentifier == "com.google.Chrome" else {
            return SyntheticTextAreaTuning(
                font: nil,
                horizontalPadding: 18,
                verticalPadding: 4,
                inlineGap: 8,
                centerSingleLineWhenTall: false
            )
        }

        let searchable = context.fingerprint.searchableText
        if searchable.contains("monaco") {
            return SyntheticTextAreaTuning(
                font: nil,
                horizontalPadding: 18,
                verticalPadding: 4,
                inlineGap: 44,
                centerSingleLineWhenTall: false
            )
        }

        if searchable.contains("prosemirror") {
            return SyntheticTextAreaTuning(
                font: NSFont.systemFont(ofSize: 18),
                horizontalPadding: 18,
                verticalPadding: 14,
                inlineGap: 8,
                centerSingleLineWhenTall: false
            )
        }

        if usesChromeRichEditorSyntheticTuning(for: context, bundleIdentifier: bundleIdentifier) {
            return SyntheticTextAreaTuning(
                font: nil,
                horizontalPadding: 18,
                verticalPadding: 14,
                inlineGap: 20,
                centerSingleLineWhenTall: false
            )
        }

        return SyntheticTextAreaTuning(
            font: nil,
            horizontalPadding: 18,
            verticalPadding: 4,
            inlineGap: 8,
            centerSingleLineWhenTall: false
        )
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

    private func recordTextContextRepairIfNeeded(
        _ repair: TextContextRepairResult,
        context: FocusedTextContext,
        profile: CompatibilityProfile
    ) {
        guard let reason = repair.reason else {
            return
        }

        let signature = [
            profile.bundleIdentifier,
            String(context.elementIdentifier),
            reason.rawValue,
            String(context.textBeforeCursor.count),
            String(context.textAfterCursor.count)
        ].joined(separator: "|")

        guard signature != lastTextContextRepairDiagnosticSignature else {
            return
        }

        lastTextContextRepairDiagnosticSignature = signature
        DiagnosticsLog.shared.record(
            "text-context-repaired",
            metadata: [
                "app": profile.bundleIdentifier,
                "reason": reason.rawValue,
                "role": context.role ?? "unknown",
                "beforeChars": String(context.textBeforeCursor.count),
                "afterChars": String(context.textAfterCursor.count),
                "hasCaretRect": String(context.caretRect != nil),
                "hasElementRect": String(context.elementRect != nil)
            ]
        )
    }

    @discardableResult
    private func startKeyboardEventTapIfPossible() -> Bool {
        cancelKeyboardEventTapIdleStop()

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
            hasPendingAcceptedInsertionUndo: acceptedInsertionUndoIsActive(),
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
                  self.keyboardEventTapIdleStopPolicy.shouldStopKeyboardCapture(
                      hasVisibleSuggestion: self.suggestionSession.hasVisibleSuggestion,
                      isSuggestionPanelVisible: self.suggestionPanel.isVisible,
                      hasPendingAcceptedInsertionUndo: self.acceptedInsertionUndoIsActive()
                  ) else {
                return
            }

            self.stopKeyboardEventTapNow(reason: "idle")
        }
    }

    private func cancelKeyboardEventTapIdleStop() {
        keyboardEventTapStopTask?.cancel()
        keyboardEventTapStopTask = nil
    }

    private func stopKeyboardEventTapNow(reason: String) {
        cancelKeyboardEventTapIdleStop()

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
        clearPendingAcceptedInsertionUndo(reason: "typing")

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
            clearPendingAcceptedInsertionUndo(reason: "typing")
        }

        let action = KeyboardActionRouter(shortcutConfiguration: keyboardShortcutConfiguration).action(
            for: key,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion,
            hasPendingAcceptedInsertionUndo: acceptedInsertionUndoIsActive()
        )

        if action == .undoAcceptedInsertion {
            let handled = undoAcceptedInsertion()
            if handled {
                suppressKey(key)
            }
            recordKeyboardAction(
                key: key,
                action: action,
                handled: handled,
                reason: handled ? "accepted-insertion-undone" : "undo-unavailable"
            )
            return handled
        }

        guard suggestionSession.hasVisibleSuggestion else {
            suppressKeyUntil[key] = nil
            return false
        }

        recordClaudeCodeTerminalHostProofKeyboardProgress(
            stage: "focus-check-start",
            key: key,
            action: action
        )
        guard focusedFieldMatchesCurrentSuggestion(
            allowTerminalHostProofSnapshotFastPath: action == .acceptNextWord
        ) else {
            setSuggestionDecision("Blocked: focus changed")
            hideSuggestion(reason: "focus-changed")
            recordKeyboardAction(
                key: key,
                action: .passThrough,
                handled: false,
                reason: "focus-changed"
            )
            return false
        }
        recordClaudeCodeTerminalHostProofKeyboardProgress(
            stage: "focus-check-passed",
            key: key,
            action: action
        )

        if currentSuggestionInvalidatedByUserKeyDown {
            recordClaudeCodeTerminalHostProofKeyboardProgress(
                stage: "blocked-stale-after-keydown",
                key: key,
                action: action
            )
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
            recordClaudeCodeTerminalHostProofKeyboardProgress(
                stage: "suppressed-autorepeat",
                key: key,
                action: action
            )
            recordKeyboardAction(key: key, action: .passThrough, handled: true, reason: "suppressed-autorepeat")
            return true
        }

        switch action {
        case .undoAcceptedInsertion:
            return false

        case .acceptNextWord:
            recordClaudeCodeTerminalHostProofKeyboardProgress(
                stage: "accept-next-word-entered",
                key: key,
                action: action
            )
            guard currentProfile?.supportsOneWordAcceptance == true else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "unsupported-one-word")
                return false
            }

            let acceptanceID = UUID().uuidString
            let acceptedAt = Date()
            let verificationBaseline = insertionVerificationBaseline(
                acceptanceID: acceptanceID,
                acceptedAt: acceptedAt,
                acceptMode: action.diagnosticName
            )
            recordClaudeCodeTerminalHostProofKeyboardProgress(
                stage: "accept-next-word-baseline-ready",
                key: key,
                action: action,
                metadata: [
                    "hasBaseline": String(verificationBaseline != nil)
                ]
            )
            guard let acceptedText = suggestionSession.nextWordAcceptance() else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "missing-accepted-text")
                return false
            }
            recordClaudeCodeTerminalHostProofKeyboardProgress(
                stage: "accept-next-word-text-ready",
                key: key,
                action: action,
                metadata: [
                    "acceptedChars": String(acceptedText.count)
                ]
            )
            guard let acceptanceProof = suggestionAcceptanceProof(action: action, acceptedText: acceptedText) else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "acceptance-proof-failed")
                return false
            }
            recordClaudeCodeTerminalHostProofKeyboardProgress(
                stage: "accept-next-word-proof-ready",
                key: key,
                action: action,
                metadata: acceptanceProof.traceMetadata
            )
            recordClaudeCodeTerminalHostProofKeyboardProgress(
                stage: "accept-next-word-insert-start",
                key: key,
                action: action
            )
            guard insertAcceptedText(acceptedText) else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "insert-failed")
                return false
            }
            recordClaudeCodeTerminalHostProofKeyboardProgress(
                stage: "accept-next-word-insert-succeeded",
                key: key,
                action: action
            )

            armAcceptedInsertionUndo(
                acceptedText: acceptedText,
                acceptanceID: acceptanceID,
                acceptedAt: acceptedAt
            )
            suggestionSession.commitNextWordAcceptance(acceptedText, keepsResidual: false)
            recordAcceptedText(acceptedText)
            advanceCurrentSuggestionBaseline(afterAccepting: acceptedText)
            suggestionRepetitionSuppressor.recordAcceptance(
                acceptedText,
                mode: currentSuggestionRequestMode,
                scope: currentSuggestionAppBundleIdentifier ?? currentProfile?.bundleIdentifier ?? ""
            )
            recordRawAcceptance(
                action: action,
                acceptedText: acceptedText,
                acceptanceID: acceptanceID,
                acceptanceProof: acceptanceProof
            )
            recordAnnoyanceSignal(
                .accepted,
                context: currentAnnoyanceContext(),
                suggestionID: currentSuggestionID ?? "",
                reason: action.diagnosticName
            )
            setSuggestionDecision("Accepted: next word; waiting for recompute")
            hideSuggestion(reason: "accepted-next-word-recompute")
            scheduleInsertionVerification(acceptedText: acceptedText, baseline: verificationBaseline)
            suppressKey(key)
            recordKeyboardAction(key: key, action: action, handled: true, reason: "accepted")
            return true

        case .acceptAllVisible:
            guard currentProfile?.supportsFullAcceptance == true else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "unsupported-full")
                return false
            }

            let acceptanceID = UUID().uuidString
            let acceptedAt = Date()
            let verificationBaseline = insertionVerificationBaseline(
                acceptanceID: acceptanceID,
                acceptedAt: acceptedAt,
                acceptMode: action.diagnosticName
            )
            guard let acceptedText = suggestionSession.allVisibleAcceptance() else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "missing-accepted-text")
                return false
            }
            guard let acceptanceProof = suggestionAcceptanceProof(action: action, acceptedText: acceptedText) else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "acceptance-proof-failed")
                return false
            }
            guard insertAcceptedText(acceptedText) else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "insert-failed")
                return false
            }

            armAcceptedInsertionUndo(
                acceptedText: acceptedText,
                acceptanceID: acceptanceID,
                acceptedAt: acceptedAt
            )
            suggestionSession.commitAllVisibleAcceptance(acceptedText)
            recordAcceptedText(acceptedText)
            suggestionRepetitionSuppressor.recordAcceptance(
                acceptedText,
                mode: currentSuggestionRequestMode,
                scope: currentSuggestionAppBundleIdentifier ?? currentProfile?.bundleIdentifier ?? ""
            )
            recordRawAcceptance(
                action: action,
                acceptedText: acceptedText,
                acceptanceID: acceptanceID,
                acceptanceProof: acceptanceProof
            )
            recordAnnoyanceSignal(
                .accepted,
                context: currentAnnoyanceContext(),
                suggestionID: currentSuggestionID ?? "",
                reason: action.diagnosticName
            )
            setSuggestionDecision("Accepted: full suggestion")
            hideSuggestion(reason: "accepted-all")
            scheduleInsertionVerification(acceptedText: acceptedText, baseline: verificationBaseline)
            suppressKey(key)
            recordKeyboardAction(key: key, action: action, handled: true, reason: "accepted")
            return true

        case .dismiss:
            var metadata = currentSuggestionLifetimeMetadata()
            metadata["escapeDismissalInsertedText"] = String(action.insertsSuggestionText)
            metadata["escapeDismissalInsertedTextChars"] = "0"
            if let input = currentPrefixFamilyCooldownInput() {
                metadata.merge(recordPrefixFamilyCooldown(.escapeDismissal, input: input)) { current, _ in current }
            }
            recordAnnoyanceSignal(
                .rapidEscDismissal,
                context: currentAnnoyanceContext(),
                suggestionID: currentSuggestionID ?? "",
                reason: "escape",
                metadata: metadata
            )
            suppressCurrentField(reason: "escape")
            hideSuggestion(
                reason: "escape",
                metadata: [
                    "escapeDismissalInsertedText": String(action.insertsSuggestionText),
                    "escapeDismissalInsertedTextChars": "0"
                ]
            )
            suppressKey(key)
            recordKeyboardAction(key: key, action: action, handled: true, reason: "dismissed")
            return true

        case .passThrough:
            if key != .other {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "pass-through")
            }
            return false
        }
    }

    private func recordClaudeCodeTerminalHostProofKeyboardProgress(
        stage: String,
        key: AutocompleteKey,
        action: KeyboardAction,
        metadata: [String: String] = [:]
    ) {
        guard currentSuggestionAppBundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier
            || currentProfile?.bundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier else {
            return
        }

        var payload = metadata
        payload["app"] = ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier
        payload["key"] = key.diagnosticName
        payload["action"] = action.diagnosticName
        payload["stage"] = stage
        payload["hasVisibleSuggestion"] = String(suggestionSession.hasVisibleSuggestion)
        payload["requestMode"] = currentSuggestionRequestMode?.rawValue ?? "unknown"
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-keyboard-progress",
            metadata: payload
        )
    }

    private func focusedFieldMatchesCurrentSuggestion(
        allowTerminalHostProofSnapshotFastPath: Bool = false
    ) -> Bool {
        if allowTerminalHostProofSnapshotFastPath,
           terminalHostProofSnapshotMatchesCurrentSuggestion() {
            return true
        }

        guard let currentSuggestionAppBundleIdentifier,
              let currentSuggestionFieldIdentity,
              let frontmostApp = accessibilityClient.frontmostApplication(),
              let profile = effectiveProfile(for: frontmostApp),
              frontmostAppMatchesSuggestion(
                  frontmostApp,
                  expectedBundleIdentifier: currentSuggestionAppBundleIdentifier,
                  profile: profile
              ),
              let rawContext = accessibilityClient.focusedTextContext(
                  allowDescendantTextFallback: profile.allowsDescendantTextFallback
              ),
              !rawContext.isSecure,
              rawContext.selectedTextLength == 0,
              claudeCodeTerminalHostProofBlockReason(
                  app: frontmostApp,
                  context: rawContext,
                  profile: profile
              ) == nil,
              promptTextAreaMatch(
                  for: frontmostApp.bundleIdentifier,
                  context: rawContext
              ).canSuggest else {
            return false
        }

        let context = presentationAdjustedContext(
            rawContext,
            app: frontmostApp,
            profile: profile,
            previousSnapshot: lastTextSnapshot
        )
        return fieldIdentity(
            app: frontmostApp,
            context: context,
            profile: profile
        ) == currentSuggestionFieldIdentity
    }

    private func terminalHostProofSnapshotMatchesCurrentSuggestion() -> Bool {
        guard currentSuggestionAppBundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
              currentSuggestionRequestMode == .wordCompletion,
              let currentProfile,
              currentProfile.bundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
              currentProfile.supportsOneWordAcceptance,
              !currentProfile.supportsFullAcceptance,
              currentProfile.requiresNoSubmitAcceptanceProof,
              currentProfile.insertionMode == .clipboardFallbackOptIn,
              let currentSuggestionFieldIdentity,
              let lastTextSnapshot,
              lastTextSnapshot.fieldIdentity == currentSuggestionFieldIdentity,
              let frontmostApp = accessibilityClient.frontmostApplication(),
              let profile = effectiveProfile(for: frontmostApp),
              profile == currentProfile,
              frontmostAppMatchesSuggestion(
                  frontmostApp,
                  expectedBundleIdentifier: ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                  profile: profile
              ),
              isClaudeCodeTerminalHostProof(
                  profile: profile,
                  hostBundleIdentifier: frontmostApp.bundleIdentifier
              ),
              let rawContext = accessibilityClient.focusedTextContext(
                  allowDescendantTextFallback: profile.allowsDescendantTextFallback
              ),
              !rawContext.isSecure,
              rawContext.selectedTextLength == 0,
              claudeCodeTerminalHostProofBlockReason(
                  app: frontmostApp,
                  context: rawContext,
                  profile: profile
              ) == nil,
              promptTextAreaMatch(
                  for: frontmostApp.bundleIdentifier,
                  context: rawContext
              ).canSuggest else {
            return false
        }

        let context = presentationAdjustedContext(
            rawContext,
            app: frontmostApp,
            profile: profile,
            previousSnapshot: lastTextSnapshot
        )
        guard fieldIdentity(app: frontmostApp, context: context, profile: profile) == currentSuggestionFieldIdentity else {
            return false
        }

        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-focus-fast-path",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "host": frontmostApp.bundleIdentifier,
                "requestMode": currentSuggestionRequestMode?.rawValue ?? "unknown"
            ]
        )
        return true
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
                "insertsSuggestionText": String(action.insertsSuggestionText),
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

    private func acceptedInsertionUndoIsActive(now: Date = Date()) -> Bool {
        guard let pendingAcceptedInsertionUndo else {
            return false
        }

        return pendingAcceptedInsertionUndo.expiresAt > now
    }

    private func armAcceptedInsertionUndo(
        acceptedText: String,
        acceptanceID: String,
        acceptedAt: Date
    ) {
        guard let currentFieldIdentity,
              let lastTextSnapshot,
              lastTextSnapshot.fieldIdentity == currentFieldIdentity,
              let appBundleIdentifier = currentSuggestionAppBundleIdentifier ?? currentProfile?.bundleIdentifier else {
            clearPendingAcceptedInsertionUndo(reason: "missing-baseline")
            return
        }

        let expiresAt = acceptedAt.addingTimeInterval(8)
        pendingAcceptedInsertionUndo = AcceptedInsertionUndo(
            acceptanceID: acceptanceID,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: currentFieldIdentity,
            textBeforeCursor: lastTextSnapshot.textBeforeCursor,
            textAfterCursor: lastTextSnapshot.textAfterCursor,
            acceptedTextLength: acceptedText.count,
            acceptedAt: acceptedAt,
            expiresAt: expiresAt
        )
        DiagnosticsLog.shared.record(
            "accepted-insertion-undo-armed",
            metadata: [
                "acceptanceID": acceptanceID,
                "app": appBundleIdentifier,
                "fieldIdentity": currentFieldIdentity.traceDescription,
                "acceptedTextLength": String(acceptedText.count),
                "previousBeforeLength": String(lastTextSnapshot.textBeforeCursor.count),
                "previousAfterLength": String(lastTextSnapshot.textAfterCursor.count),
                "expiresInMilliseconds": "8000"
            ]
        )
        updateKeyboardEventTapSnapshot()
        scheduleAcceptedInsertionUndoExpiration(acceptanceID: acceptanceID, expiresAt: expiresAt)
    }

    private func scheduleAcceptedInsertionUndoExpiration(acceptanceID: String, expiresAt: Date) {
        acceptedInsertionUndoExpirationTask?.cancel()
        acceptedInsertionUndoExpirationTask = Task { @MainActor [weak self] in
            let delay = max(0, expiresAt.timeIntervalSinceNow)
            try? await Task.sleep(for: .milliseconds(Int(delay * 1_000)))
            guard !Task.isCancelled,
                  let self,
                  self.pendingAcceptedInsertionUndo?.acceptanceID == acceptanceID else {
                return
            }

            self.clearPendingAcceptedInsertionUndo(reason: "expired")
            self.scheduleKeyboardEventTapStopIfIdle()
        }
    }

    private func clearPendingAcceptedInsertionUndo(reason: String) {
        guard let pendingAcceptedInsertionUndo else {
            return
        }

        acceptedInsertionUndoExpirationTask?.cancel()
        acceptedInsertionUndoExpirationTask = nil
        self.pendingAcceptedInsertionUndo = nil
        DiagnosticsLog.shared.record(
            "accepted-insertion-undo-cleared",
            metadata: [
                "acceptanceID": pendingAcceptedInsertionUndo.acceptanceID,
                "reason": reason
            ]
        )
        updateKeyboardEventTapSnapshot()
    }

    private func undoAcceptedInsertion() -> Bool {
        guard let undo = pendingAcceptedInsertionUndo,
              undo.expiresAt > Date() else {
            clearPendingAcceptedInsertionUndo(reason: "expired")
            return false
        }

        guard let frontmostApp = accessibilityClient.frontmostApplication(),
              let profile = effectiveProfile(for: frontmostApp),
              frontmostAppMatchesSuggestion(
                  frontmostApp,
                  expectedBundleIdentifier: undo.appBundleIdentifier,
                  profile: profile
              ),
              let rawContext = accessibilityClient.focusedTextContext(
                  allowDescendantTextFallback: profile.allowsDescendantTextFallback
              ),
              !rawContext.isSecure,
              rawContext.selectedTextLength == 0,
              claudeCodeTerminalHostProofBlockReason(
                  app: frontmostApp,
                  context: rawContext,
                  profile: profile
              ) == nil,
              promptTextAreaMatch(for: frontmostApp.bundleIdentifier, context: rawContext).canSuggest else {
            clearPendingAcceptedInsertionUndo(reason: "stale-focus")
            return false
        }

        let context = presentationAdjustedContext(
            rawContext,
            app: frontmostApp,
            profile: profile,
            previousSnapshot: lastTextSnapshot
        )
        guard fieldIdentity(app: frontmostApp, context: context, profile: profile) == undo.fieldIdentity else {
            clearPendingAcceptedInsertionUndo(reason: "stale-field")
            return false
        }

        let restoredText = undo.textBeforeCursor + undo.textAfterCursor
        guard accessibilityClient.restoreFocusedTextValue(
            restoredText,
            cursorUTF16Offset: undo.textBeforeCursor.utf16.count
        ) else {
            clearPendingAcceptedInsertionUndo(reason: "restore-failed")
            return false
        }

        lastTextSnapshot = FocusedTextSnapshot(
            fieldIdentity: undo.fieldIdentity,
            textBeforeCursor: undo.textBeforeCursor,
            textAfterCursor: undo.textAfterCursor
        )
        focusedTextPollingPause.pause(
            now: Date(),
            durationMilliseconds: postInsertionPollPauseMilliseconds
        )
        DiagnosticsLog.shared.record(
            "accepted-insertion-undone",
            metadata: [
                "acceptanceID": undo.acceptanceID,
                "app": undo.appBundleIdentifier,
                "fieldIdentity": undo.fieldIdentity.traceDescription,
                "acceptedTextLength": String(undo.acceptedTextLength),
                "restoredTextLength": String(restoredText.count)
            ]
        )
        clearAcceptanceSurvivalForAcceptedInsertionUndo(undo)
        clearPendingAcceptedInsertionUndo(reason: "undone")
        setSuggestionDecision("Accepted insertion undone")
        scheduleKeyboardEventTapStopIfIdle()
        return true
    }

    private func clearAcceptanceSurvivalForAcceptedInsertionUndo(_ undo: AcceptedInsertionUndo) {
        acceptanceSurvivalTasks[undo.acceptanceID]?.cancel()
        acceptanceSurvivalTasks[undo.acceptanceID] = nil

        Task { @MainActor [weak self] in
            guard let self,
                  let tracker = await self.acceptanceSurvivalChecker.finishTracking(
                      acceptanceID: undo.acceptanceID
                  ) else {
                return
            }

            RawAutocompleteTraceLog.shared.record(
                type: .acceptanceRetentionCleared,
                suggestionID: tracker.suggestionID,
                appBundleIdentifier: tracker.appBundleIdentifier,
                fieldIdentity: tracker.fieldIdentity.traceDescription,
                requestMode: tracker.requestMode,
                outcome: "undone",
                reason: "accepted-insertion-undone",
                metadata: [
                    "acceptanceID": tracker.acceptanceID,
                    "acceptMode": tracker.acceptMode,
                    "fieldKind": tracker.fieldKind.rawValue,
                    "fieldKindReason": tracker.fieldKindReason,
                    "behaviorProfile": tracker.behaviorProfileID.rawValue,
                    "acceptedChars": String(tracker.acceptedText.count),
                    "restoredTextLength": String(undo.textBeforeCursor.count + undo.textAfterCursor.count)
                ]
            )
        }
    }

    private func insertionVerificationBaseline(
        acceptanceID: String,
        acceptedAt: Date,
        acceptMode: String
    ) -> InsertionVerificationBaseline? {
        guard let currentFieldIdentity,
              let lastTextSnapshot,
              lastTextSnapshot.fieldIdentity == currentFieldIdentity,
              let profile = currentProfile else {
            return nil
        }
        let fieldClassification = currentSuggestionFieldClassification
        let fieldKind = fieldClassification?.kind ?? .unknown
        let behaviorProfileID = suggestionOrchestrator.currentRequest?.behaviorProfile.id
            ?? AutocompleteBehaviorProfileResolver().profile(for: AutocompleteBehaviorProfileInput(
                appBundleIdentifier: profile.bundleIdentifier,
                fieldKind: fieldKind,
                currentLineStructure: CurrentLineStructure.from(textBeforeCursor: lastTextSnapshot.textBeforeCursor)
            )).id

        return InsertionVerificationBaseline(
            fieldIdentity: currentFieldIdentity,
            previousTextBeforeCursor: lastTextSnapshot.textBeforeCursor,
            previousTextAfterCursor: lastTextSnapshot.textAfterCursor,
            profile: profile,
            suggestionID: currentSuggestionID,
            requestMode: currentSuggestionRequestMode,
            acceptanceID: acceptanceID,
            acceptedAt: acceptedAt,
            acceptMode: acceptMode,
            fieldKind: fieldKind,
            fieldKindReason: fieldClassification?.reason ?? "unknown",
            behaviorProfileID: behaviorProfileID,
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
            try? await Task.sleep(for: .milliseconds(
                insertionVerificationTimingPolicy.delayMilliseconds(
                    for: baseline.profile,
                    retryCount: baseline.retryCount
                )
            ))
            guard !Task.isCancelled else {
                return
            }

            let verificationContextRead = focusedInsertionVerificationContext(for: baseline)
            guard case let .ready(context: verificationContext) = verificationContextRead else {
                recordInsertionVerificationContextFailure(
                    verificationContextRead,
                    acceptedText: acceptedText,
                    baseline: baseline
                )
                return
            }

            var context = verificationContext
            var result = insertionVerification.verify(
                previousTextBeforeCursor: baseline.previousTextBeforeCursor,
                acceptedText: acceptedText,
                currentTextBeforeCursor: context.textBeforeCursor,
                previousTextAfterCursor: baseline.previousTextAfterCursor,
                currentTextAfterCursor: context.textAfterCursor
            )

            DiagnosticsLog.shared.record(
                "insert-verification",
                metadata: [
                    "app": baseline.profile.bundleIdentifier,
                    "result": String(describing: result),
                    "acceptedChars": String(acceptedText.count),
                    "previousBeforeChars": String(baseline.previousTextBeforeCursor.count),
                    "currentBeforeChars": String(context.textBeforeCursor.count),
                    "previousAfterChars": String(baseline.previousTextAfterCursor.count),
                    "currentAfterChars": String(context.textAfterCursor.count)
                ]
            )

            if !result.isVerified,
               let recheckDelayMilliseconds = insertionVerificationTimingPolicy.readOnlyRecheckDelayMilliseconds(
                   for: baseline.profile,
                   result: result,
                   retryCount: baseline.retryCount
               ) {
                try? await Task.sleep(for: .milliseconds(recheckDelayMilliseconds))
                guard !Task.isCancelled else {
                    return
                }

                if case let .ready(context: recheckContext) = focusedInsertionVerificationContext(for: baseline) {
                    context = recheckContext
                    result = insertionVerification.verify(
                        previousTextBeforeCursor: baseline.previousTextBeforeCursor,
                        acceptedText: acceptedText,
                        currentTextBeforeCursor: context.textBeforeCursor,
                        previousTextAfterCursor: baseline.previousTextAfterCursor,
                        currentTextAfterCursor: context.textAfterCursor
                    )
                    DiagnosticsLog.shared.record(
                        "insert-verification",
                        metadata: [
                            "app": baseline.profile.bundleIdentifier,
                            "result": String(describing: result),
                            "acceptedChars": String(acceptedText.count),
                            "previousBeforeChars": String(baseline.previousTextBeforeCursor.count),
                            "currentBeforeChars": String(context.textBeforeCursor.count),
                            "previousAfterChars": String(baseline.previousTextAfterCursor.count),
                            "currentAfterChars": String(context.textAfterCursor.count),
                            "source": "read-only-recheck",
                            "recheckDelayMilliseconds": String(recheckDelayMilliseconds)
                        ]
                    )
                }
            }

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
                            previousTextAfterCursor: baseline.previousTextAfterCursor,
                            profile: baseline.profile,
                            suggestionID: baseline.suggestionID,
                            requestMode: baseline.requestMode,
                            acceptanceID: baseline.acceptanceID,
                            acceptedAt: baseline.acceptedAt,
                            acceptMode: baseline.acceptMode,
                            fieldKind: baseline.fieldKind,
                            fieldKindReason: baseline.fieldKindReason,
                            behaviorProfileID: baseline.behaviorProfileID,
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
                        "acceptanceID": baseline.acceptanceID,
                        "acceptMode": baseline.acceptMode,
                        "fieldKind": baseline.fieldKind.rawValue,
                        "fieldKindReason": baseline.fieldKindReason,
                        "behaviorProfile": baseline.behaviorProfileID.rawValue,
                        "previousBeforeChars": String(baseline.previousTextBeforeCursor.count),
                        "currentBeforeChars": String(context.textBeforeCursor.count),
                        "previousAfterChars": String(baseline.previousTextAfterCursor.count),
                        "currentAfterChars": String(context.textAfterCursor.count)
                    ]
                )
                recordAnnoyanceSignal(
                    .wrongInsertion,
                    context: annoyanceContext(
                        appBundleIdentifier: baseline.profile.bundleIdentifier,
                        fieldIdentity: baseline.fieldIdentity,
                        requestMode: baseline.requestMode,
                        fieldKind: baseline.fieldKind
                    ),
                    suggestionID: baseline.suggestionID ?? "",
                    reason: "insert-verification-failed",
                    metadata: [
                        "acceptanceID": baseline.acceptanceID,
                        "acceptMode": baseline.acceptMode,
                        "insertionResult": String(describing: result)
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
                outcome: "verified",
                metadata: [
                    "acceptanceID": baseline.acceptanceID,
                    "acceptMode": baseline.acceptMode,
                    "fieldKind": baseline.fieldKind.rawValue,
                    "fieldKindReason": baseline.fieldKindReason,
                    "behaviorProfile": baseline.behaviorProfileID.rawValue
                ]
            )
            let tracker = AcceptanceSurvivalTracker(
                acceptanceID: baseline.acceptanceID,
                suggestionID: baseline.suggestionID ?? "",
                appBundleIdentifier: baseline.profile.bundleIdentifier,
                fieldIdentity: baseline.fieldIdentity,
                requestMode: baseline.requestMode?.rawValue ?? "",
                acceptMode: baseline.acceptMode,
                acceptedText: acceptedText,
                expectedInsertionUTF16Offset: baseline.previousTextBeforeCursor.utf16.count,
                acceptedAt: baseline.acceptedAt,
                profile: baseline.profile,
                fieldKind: baseline.fieldKind,
                fieldKindReason: baseline.fieldKindReason,
                behaviorProfileID: baseline.behaviorProfileID
            )
            startAcceptanceSurvivalTracking(tracker)
        }
    }

    private func recordInsertionVerificationContextFailure(
        _ contextRead: FocusedInsertionVerificationContext,
        acceptedText: String,
        baseline: InsertionVerificationBaseline
    ) {
        guard let outcome = contextRead.failureOutcome,
              let reason = contextRead.failureReason else {
            return
        }

        DiagnosticsLog.shared.record(
            "insert-verification",
            metadata: [
                "app": baseline.profile.bundleIdentifier,
                "result": outcome,
                "acceptedChars": String(acceptedText.count),
                "previousBeforeChars": String(baseline.previousTextBeforeCursor.count),
                "previousAfterChars": String(baseline.previousTextAfterCursor.count),
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
            outcome: outcome,
            reason: reason,
            metadata: [
                "acceptanceID": baseline.acceptanceID,
                "acceptMode": baseline.acceptMode,
                "fieldKind": baseline.fieldKind.rawValue,
                "fieldKindReason": baseline.fieldKindReason,
                "behaviorProfile": baseline.behaviorProfileID.rawValue,
                "previousBeforeChars": String(baseline.previousTextBeforeCursor.count),
                "previousAfterChars": String(baseline.previousTextAfterCursor.count),
                "retryCount": String(baseline.retryCount)
            ]
        )
        recordAnnoyanceSignal(
            .wrongInsertion,
            context: annoyanceContext(
                appBundleIdentifier: baseline.profile.bundleIdentifier,
                fieldIdentity: baseline.fieldIdentity,
                requestMode: baseline.requestMode,
                fieldKind: baseline.fieldKind
            ),
            suggestionID: baseline.suggestionID ?? "",
            reason: reason,
            metadata: [
                "acceptanceID": baseline.acceptanceID,
                "acceptMode": baseline.acceptMode,
                "insertionResult": outcome
            ]
        )
        if baseline.profile.suppressesAfterInsertionFailure {
            suppressCurrentField(reason: reason)
        }
        hideSuggestion()
    }

    private func focusedInsertionVerificationContext(
        for baseline: InsertionVerificationBaseline
    ) -> FocusedInsertionVerificationContext {
        guard let frontmostApp = accessibilityClient.frontmostApplication(),
              let context = accessibilityClient.focusedTextContext(
                  allowDescendantTextFallback: baseline.profile.allowsDescendantTextFallback
              ) else {
            return .missingContext
        }

        let previousSnapshot = FocusedTextSnapshot(
            fieldIdentity: baseline.fieldIdentity,
            textBeforeCursor: baseline.previousTextBeforeCursor,
            textAfterCursor: baseline.previousTextAfterCursor
        )
        let adjustedContext = presentationAdjustedContext(
            context,
            app: frontmostApp,
            profile: baseline.profile,
            previousSnapshot: previousSnapshot
        )

        let currentIdentity = fieldIdentity(
            app: frontmostApp,
            context: adjustedContext,
            profile: baseline.profile
        )

        guard currentIdentity == baseline.fieldIdentity else {
            return .fieldChanged
        }

        return .ready(context: adjustedContext)
    }

    private func startAcceptanceSurvivalTracking(_ tracker: AcceptanceSurvivalTracker) {
        acceptanceSurvivalTasks[tracker.acceptanceID]?.cancel()
        acceptanceSurvivalTasks[tracker.acceptanceID] = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            await self.acceptanceSurvivalChecker.beginTracking(tracker)
            let checkpoints: [(AcceptanceSurvivalCheckpoint, Duration)] = [
                (.twoSeconds, .seconds(2)),
                (.tenSeconds, .seconds(8)),
                (.thirtySeconds, .seconds(20))
            ]

            for (checkpoint, delay) in checkpoints {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else {
                    return
                }

                await self.measureAcceptanceSurvival(
                    acceptanceID: tracker.acceptanceID,
                    checkpoint: checkpoint
                )
            }
        }
    }

    private func measureAcceptanceSurvival(
        acceptanceID: String,
        checkpoint: AcceptanceSurvivalCheckpoint
    ) async {
        guard let tracker = await acceptanceSurvivalChecker.tracker(acceptanceID: acceptanceID) else {
            return
        }

        guard let currentTextWindow = currentTextWindow(for: tracker) else {
            if checkpoint.isFinalMetricCheckpoint {
                acceptanceSurvivalTasks[acceptanceID] = nil
                _ = await acceptanceSurvivalChecker.finishTracking(acceptanceID: acceptanceID)
            }
            return
        }

        guard let result = await acceptanceSurvivalChecker.measure(
            acceptanceID: acceptanceID,
            checkpoint: checkpoint,
            currentTextWindow: currentTextWindow
        ) else {
            return
        }

        recordAcceptanceSurvivalResult(result)
        if result.shouldFinish {
            acceptanceSurvivalTasks[acceptanceID] = nil
            _ = await acceptanceSurvivalChecker.finishTracking(acceptanceID: acceptanceID)
        }
    }

    private func finalizeAcceptanceSurvivalForCurrentField() {
        guard let currentFieldIdentity,
              let lastTextSnapshot,
              lastTextSnapshot.fieldIdentity == currentFieldIdentity else {
            return
        }

        finalizeAcceptanceSurvival(
            fieldIdentity: currentFieldIdentity,
            currentTextWindow: lastTextSnapshot.textBeforeCursor + lastTextSnapshot.textAfterCursor
        )
    }

    private func finalizeAcceptanceSurvival(
        fieldIdentity: FocusedFieldIdentity,
        currentTextWindow: String
    ) {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            let results = await self.acceptanceSurvivalChecker.measureFieldBlur(
                fieldIdentity: fieldIdentity,
                currentTextWindow: currentTextWindow
            )
            for result in results {
                self.recordAcceptanceSurvivalResult(result)
                if result.shouldFinish {
                    self.acceptanceSurvivalTasks[result.tracker.acceptanceID]?.cancel()
                    self.acceptanceSurvivalTasks[result.tracker.acceptanceID] = nil
                    _ = await self.acceptanceSurvivalChecker.finishTracking(
                        acceptanceID: result.tracker.acceptanceID
                    )
                }
            }
        }
    }

    private func currentTextWindow(for tracker: AcceptanceSurvivalTracker) -> String? {
        guard let frontmostApp = accessibilityClient.frontmostApplication(),
              frontmostAppMatchesSuggestion(
                  frontmostApp,
                  expectedBundleIdentifier: tracker.appBundleIdentifier,
                  profile: tracker.profile
              ),
              let rawContext = accessibilityClient.focusedTextContext(
                  allowDescendantTextFallback: tracker.profile.allowsDescendantTextFallback
              ),
              !rawContext.isSecure else {
            return nil
        }

        let context = presentationAdjustedContext(
            rawContext,
            app: frontmostApp,
            profile: tracker.profile,
            previousSnapshot: lastTextSnapshot
        )
        guard fieldIdentity(
            app: frontmostApp,
            context: context,
            profile: tracker.profile
        ) == tracker.fieldIdentity else {
            return nil
        }

        return context.textBeforeCursor + context.textAfterCursor
    }

    private func recordAcceptanceSurvivalResult(_ result: AcceptanceSurvivalCheckResult) {
        var metadata = result.measurement.traceMetadata
        metadata["acceptanceID"] = result.tracker.acceptanceID
        metadata["acceptMode"] = result.tracker.acceptMode
        metadata["fieldKind"] = result.tracker.fieldKind.rawValue
        metadata["fieldKindReason"] = result.tracker.fieldKindReason
        metadata["behaviorProfile"] = result.tracker.behaviorProfileID.rawValue
        if let learningSignal = recordAcceptedAndKeptLearningIfNeeded(result) {
            metadata.merge(learningSignal.traceMetadata) { current, _ in current }
        }
        if let finishReason = result.finishReason {
            metadata["finishReason"] = finishReason
        }

        RawAutocompleteTraceLog.shared.record(
            type: .acceptedTextEdited,
            suggestionID: result.tracker.suggestionID,
            appBundleIdentifier: result.tracker.appBundleIdentifier,
            fieldIdentity: result.tracker.fieldIdentity.traceDescription,
            requestMode: result.tracker.requestMode,
            acceptedText: result.tracker.acceptedText,
            outcome: result.measurement.survivalClass.rawValue,
            reason: result.finishReason ?? result.measurement.checkpoint.rawValue,
            metadata: metadata
        )

        if result.shouldRecordAcceptedAndKept {
            recordAnnoyanceSignal(
                .acceptedAndKept,
                context: annoyanceContext(for: result.tracker),
                suggestionID: result.tracker.suggestionID,
                reason: result.finishReason ?? result.measurement.checkpoint.rawValue,
                metadata: metadata
            )
        }

        guard result.shouldRecordAcceptedThenDeleted else {
            return
        }

        recordAnnoyanceSignal(
            .acceptedThenDeleted,
            context: annoyanceContext(for: result.tracker),
            suggestionID: result.tracker.suggestionID,
            reason: "accepted-then-deleted",
            metadata: metadata
        )

        RawAutocompleteTraceLog.shared.record(
            type: .acceptanceRetentionCleared,
            suggestionID: result.tracker.suggestionID,
            appBundleIdentifier: result.tracker.appBundleIdentifier,
            fieldIdentity: result.tracker.fieldIdentity.traceDescription,
            requestMode: result.tracker.requestMode,
            acceptedText: result.tracker.acceptedText,
            outcome: result.measurement.survivalClass.rawValue,
            reason: "accepted-then-deleted",
            metadata: metadata
        )
    }

    private func recordAcceptedAndKeptLearningIfNeeded(
        _ result: AcceptanceSurvivalCheckResult
    ) -> AcceptedAndKeptLearningSignal? {
        guard let requestMode = CompletionRequestMode(rawValue: result.tracker.requestMode) else {
            return nil
        }

        let outcome: AcceptedAndKeptLearningOutcome
        if result.shouldRecordAcceptedThenDeleted {
            outcome = .rejected
        } else if result.measurement.checkpoint.isFinalMetricCheckpoint,
                  !result.measurement.deletedWithinTwoSeconds {
            outcome = result.measurement.isFinalAcceptedAndKept ? .kept : .rejected
        } else {
            return nil
        }

        let signal = acceptedAndKeptLearning.record(
            outcome,
            key: AcceptedAndKeptLearningKey(
                appBundleIdentifier: result.tracker.appBundleIdentifier,
                fieldKind: result.tracker.fieldKind,
                requestMode: requestMode,
                behaviorProfileID: result.tracker.behaviorProfileID
            )
        )
        if outcome == .kept {
            acceptedTextStyleMemory.recordKeptText(
                result.tracker.acceptedText,
                key: AcceptedTextStyleMemoryKey(
                    appBundleIdentifier: result.tracker.appBundleIdentifier,
                    fieldKind: result.tracker.fieldKind,
                    behaviorProfileID: result.tracker.behaviorProfileID
                )
            )
            persistAcceptedTextStyleMemory()
        }
        persistAcceptedAndKeptLearning()
        return signal
    }

    private func scheduleSuggestion(
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity,
        fieldClassification: AXFieldClassification,
        renderMode: SuggestionRenderMode,
        delayMilliseconds: Int,
        requestMode: CompletionRequestMode
    ) {
        lastRequestedTextBeforeCursor = context.textBeforeCursor

        let acceptedTextStyleKey = suggestionOrchestrator.acceptedTextStyleKey(
            appBundleIdentifier: appBundleIdentifier,
            fieldKind: fieldClassification.kind,
            textBeforeCursor: context.textBeforeCursor
        )
        let acceptedTextStyleSketch = acceptedTextStyleMemory.sketch(
            for: acceptedTextStyleKey
        )
        let orchestration = suggestionOrchestrator.beginRequest(SuggestionRequestInput(
            context: context,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentity,
            fieldClassification: fieldClassification,
            acceptedTextStyleSketch: acceptedTextStyleSketch,
            maxVisibleWords: completionLengthConfiguration.maxVisibleWords,
            requestMode: requestMode,
            suggestionAggressiveness: suggestionAggressiveness
        ))
        let request = orchestration.request
        let suggestionID = orchestration.suggestionID
        let fieldIdentityDescription = orchestration.fieldIdentityDescription
        let requestMetadata = orchestration.requestMetadata
        suggestionOrchestrator.startStreamingPresentation(suggestionID: suggestionID)
        let requestTicket = orchestration.ticket
        let requestStartedAt = orchestration.startedAt

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
            .merging(requestMetadata) { current, _ in current }
        )

        if requestMode == .wordCompletion {
            let fastSelection = suggestionOrchestrator.fastWordSelection(
                for: context.textBeforeCursor,
                recentWords: recentWordMemory.words(for: appBundleIdentifier)
            )
            let fastSelectionMetadata = fastSelection.traceMetadata
            if let fastSuggestion = fastSelection.suggestion {
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
                        .merging(fastSelectionMetadata) { current, _ in current }
                        .merging(requestMetadata) { current, _ in current }
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
                    recordAnnoyanceSignal(
                        .repeatedRejection,
                        context: annoyanceContext(
                            appBundleIdentifier: appBundleIdentifier,
                            fieldIdentity: fieldIdentity,
                            requestMode: request.mode,
                            fieldKind: fieldClassification.kind
                        ),
                        suggestionID: suggestionID,
                        reason: "repeated-miss"
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
                    triggerReason: "fast-word-completion",
                    candidateSelectionMetadata: fastSelectionMetadata,
                    refreshBeforePresenting: false
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
                .merging(fastSelectionMetadata) { current, _ in current }
                .merging(requestMetadata) { current, _ in current }
            )
            if suggestionSession.hasVisibleSuggestion {
                setSuggestionDecision("Shown: no fast word replacement")
                repositionVisibleSuggestion(context: context, profile: profile)
                return
            }

            hideSuggestion()
            return
        }

        debounceTask = Task { [suggestionOrchestrator, requestTicket, fieldIdentity] in
            let renderDelay = renderMode == .inlineAdjacent ? delayMilliseconds : max(delayMilliseconds, 60)
            try? await Task.sleep(for: .milliseconds(renderDelay))
            guard !Task.isCancelled else {
                return
            }

            do {
                let suggestion = try await suggestionOrchestrator.suggestion(
                    for: request,
                    onPartialSuggestion: { partialSuggestion in
                        Task { @MainActor in
                            let latencyMilliseconds = max(0, Int(Date().timeIntervalSince(requestStartedAt) * 1000))
                            guard self.suggestionOrchestrator.allows(
                                requestTicket,
                                fieldIdentity: fieldIdentity,
                                currentFieldIdentity: self.currentFieldIdentity
                            ) else {
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

                            guard self.suggestionOrchestrator.shouldPresentStreamingPartial(
                                partialSuggestion,
                                suggestionID: suggestionID,
                                mode: request.mode,
                                nowMilliseconds: Int(ProcessInfo.processInfo.systemUptime * 1000)
                            ) else {
                                return
                            }

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
                    guard self.suggestionOrchestrator.allows(
                        requestTicket,
                        fieldIdentity: fieldIdentity,
                        currentFieldIdentity: self.currentFieldIdentity
                    ) else {
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
                            reason: "empty-suggestion",
                            metadata: requestMetadata
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
                            reason: "missing-anchor",
                            metadata: requestMetadata
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

                    let appModelResultMetadata = self.suggestionOrchestrator.appModelResultCandidateSelectionMetadata(
                        for: suggestion
                    )
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
                        latencyMilliseconds: latencyMilliseconds,
                        metadata: requestMetadata
                            .merging(appModelResultMetadata) { current, _ in current }
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
                            reason: "repeated-miss",
                            metadata: requestMetadata
                        )
                        self.recordAnnoyanceSignal(
                            .repeatedRejection,
                            context: self.annoyanceContext(
                                appBundleIdentifier: appBundleIdentifier,
                                fieldIdentity: fieldIdentity,
                                requestMode: request.mode,
                                fieldKind: fieldClassification.kind
                            ),
                            suggestionID: suggestionID,
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
                        triggerReason: "model-result",
                        candidateSelectionMetadata: appModelResultMetadata
                    )
                    self.suggestionOrchestrator.finishStreamingPresentation(suggestionID: suggestionID)
                }
            } catch {
                await MainActor.run {
                    self.suggestionOrchestrator.finishStreamingPresentation(suggestionID: suggestionID)
                    guard self.suggestionOrchestrator.shouldHideVisibleSuggestionAfterFailure(
                        ticket: requestTicket,
                        failedRequestFieldIdentity: fieldIdentity,
                        currentFieldIdentity: self.currentFieldIdentity
                    ) else {
                        return
                    }
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
        triggerReason: String,
        candidateSelectionMetadata: [String: String] = [:],
        refreshBeforePresenting: Bool = true
    ) {
        let originalContext = context
        let refreshedContext = refreshBeforePresenting
            ? refreshedPresentationContext(
                for: request,
                profile: profile,
                fieldIdentity: fieldIdentity
            )
            : (context: Optional(context), reason: nil)
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
                    .merging(traceRequestMetadata(request: request, context: originalContext)) { current, _ in current }
                    .merging(candidateSelectionMetadata) { current, _ in current }
            )
            recordSuggestionEvent(
                "suggestion-blocked",
                context: originalContext,
                profile: profile,
                metadata: [
                    "reason": reason
                ]
                .merging(traceRequestMetadata(request: request, context: originalContext)) { current, _ in current }
                .merging(candidateSelectionMetadata) { current, _ in current }
            )
            hideSuggestion(reason: reason)
            return
        }

        let storedLearningAdjustment = compatibilityLearningStore.engine().adjustment(
            for: profile.bundleIdentifier,
            profileRenderMode: renderMode
        )
        let visualTrustContext = compatibilityLearningVisualTrustContext(
            for: context,
            bundleIdentifier: profile.bundleIdentifier
        )
        let learningAdjustment = storedLearningAdjustment.trustedVisualOffsetOnly(context: visualTrustContext)
        let placementPlan = suggestionOrchestrator.placementHealthPlan(
            context: context,
            profile: profile,
            learningAdjustment: learningAdjustment,
            screenshotTracingEnabled: RawAutocompleteTraceLog.shared.screenshotTracingEnabled
        )

        guard case let .present(placement) = placementPlan else {
            let placementSuppression = suggestionOrchestrator.placementSuppressionResolution(
                for: placementPlan,
                requestedRenderMode: learningAdjustment.effectiveRenderMode,
                profile: profile,
                fieldKind: request.fieldKind
            )
            let suppression = placementSuppression.suppression
            let commandFallbackMetadata = placementSuppression.metadata
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
                    .merging(traceRequestMetadata(request: request, context: context)) { current, _ in current }
                    .merging(learningAdjustment.metadata) { current, _ in current }
                    .merging(commandFallbackMetadata) { current, _ in current }
                    .merging(suppression.metadata) { current, _ in current }
            )
            recordSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                metadata: [
                    "reason": suppression.reason.rawValue
                ]
                .merging(traceRequestMetadata(request: request, context: context)) { current, _ in current }
                .merging(learningAdjustment.metadata) { current, _ in current }
                .merging(commandFallbackMetadata) { current, _ in current }
                .merging(suppression.metadata) { current, _ in current }
            )
            let placementMetadata = traceGeometryMetadata(context: context, renderMode: learningAdjustment.effectiveRenderMode)
                .merging(traceRequestMetadata(request: request, context: context)) { current, _ in current }
                .merging(learningAdjustment.metadata) { current, _ in current }
                .merging(commandFallbackMetadata) { current, _ in current }
                .merging(suppression.metadata) { current, _ in current }
            recordPlacementUncertainty(
                suggestionID: suggestionID,
                appBundleIdentifier: request.appBundleIdentifier ?? profile.bundleIdentifier,
                fieldIdentity: fieldIdentity,
                requestMode: request.mode,
                context: context,
                reason: suppression.reason.rawValue,
                metadata: placementMetadata
            )
            setSuggestionDecision("Blocked: placement \(suppression.reason.rawValue)\(placementSuppression.fallbackSuffix)")
            hideSuggestion(reason: "placement-\(suppression.reason.rawValue)")
            return
        }

        let displayFieldClassification = fieldClassification(for: context)
        let acceptedAndKeptSignal = acceptedAndKeptSignal(
            request: request,
            fieldClassification: displayFieldClassification,
            profile: profile
        )
        let isRepeatedMiss = suggestionRepetitionSuppressor.shouldSuppress(
            suggestion.visibleText,
            mode: request.mode,
            scope: request.appBundleIdentifier ?? profile.bundleIdentifier
        )
        let orchestratedDisplayDecision = suggestionOrchestrator.displayScoreDecision(
            suggestion: suggestion,
            request: request,
            context: context,
            fieldClassification: displayFieldClassification,
            profile: profile,
            fieldIdentity: fieldIdentity,
            triggerReason: triggerReason,
            latencyMilliseconds: latencyMilliseconds,
            acceptedAndKeptSignal: acceptedAndKeptSignal,
            isRepeatedMiss: isRepeatedMiss,
            displayScorePolicy: displayScorePolicy
        )
        let displayScoreDecision = orchestratedDisplayDecision.decision
        let displayScoreMetadata = orchestratedDisplayDecision.metadata
        let displayScoreTrace = displayScoreDecision.trace
        guard displayScoreDecision.shouldDisplay else {
            let reason = displayScoreMetadata["displayScoreSuppressionReason"] ?? "display-score"
            setSuggestionDecision("Blocked: display score \(reason)")
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
                metadata: traceGeometryMetadata(context: context, renderMode: placement.renderMode)
                    .merging(traceRequestMetadata(request: request, context: context)) { current, _ in current }
                    .merging(learningAdjustment.metadata) { current, _ in current }
                    .merging(placement.metadata) { current, _ in current }
                    .merging(candidateSelectionMetadata) { current, _ in current }
                    .merging(displayScoreMetadata) { current, _ in current }
            )
            recordSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                metadata: [
                    "reason": reason
                ]
                .merging(traceRequestMetadata(request: request, context: context)) { current, _ in current }
                .merging(learningAdjustment.metadata) { current, _ in current }
                .merging(placement.metadata) { current, _ in current }
                .merging(candidateSelectionMetadata) { current, _ in current }
                .merging(displayScoreMetadata) { current, _ in current }
            )
            hideSuggestion(reason: reason)
            return
        }

        let replacementDecision = suggestionOrchestrator.replacementDecision(
            currentVisibleText: suggestionSession.visibleSuggestion?.visibleText,
            proposedVisibleText: suggestion.visibleText,
            currentSuggestionID: currentSuggestionID,
            proposedSuggestionID: suggestionID,
            currentPresentedAt: currentSuggestionPresentedAt,
            currentScore: currentSuggestionDisplayScoreFinal,
            proposedScore: displayScoreTrace.score.finalScore
        )
        let replacementMetadata = replacementDecision.metadata
        guard replacementDecision.shouldPresent else {
            let reason = replacementDecision.reason?.rawValue ?? "replacement-gate"
            setSuggestionDecision("Kept current suggestion: \(reason)")
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
                metadata: traceGeometryMetadata(context: context, renderMode: placement.renderMode)
                    .merging(traceRequestMetadata(request: request, context: context)) { current, _ in current }
                    .merging(learningAdjustment.metadata) { current, _ in current }
                    .merging(placement.metadata) { current, _ in current }
                    .merging(candidateSelectionMetadata) { current, _ in current }
                    .merging(displayScoreMetadata) { current, _ in current }
                    .merging(replacementMetadata) { current, _ in current }
            )
            recordSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                metadata: [
                    "reason": reason
                ]
                .merging(traceRequestMetadata(request: request, context: context)) { current, _ in current }
                .merging(learningAdjustment.metadata) { current, _ in current }
                .merging(placement.metadata) { current, _ in current }
                .merging(candidateSelectionMetadata) { current, _ in current }
                .merging(displayScoreMetadata) { current, _ in current }
                .merging(replacementMetadata) { current, _ in current }
            )
            let placementMetadata = traceGeometryMetadata(context: context, renderMode: placement.renderMode)
                .merging(traceRequestMetadata(request: request, context: context)) { current, _ in current }
                .merging(learningAdjustment.metadata) { current, _ in current }
                .merging(placement.metadata) { current, _ in current }
                .merging(candidateSelectionMetadata) { current, _ in current }
                .merging(displayScoreMetadata) { current, _ in current }
                .merging(replacementMetadata) { current, _ in current }
            recordPlacementUncertainty(
                suggestionID: suggestionID,
                appBundleIdentifier: request.appBundleIdentifier ?? profile.bundleIdentifier,
                fieldIdentity: fieldIdentity,
                requestMode: request.mode,
                context: context,
                reason: reason,
                metadata: placementMetadata
            )
            hideSuggestion(reason: reason)
            return
        }

        lastCaretRect = placement.anchorRect
        lastTextLineRect = placement.textLineRect
        lastClippingRect = placement.clippingRect
        lastTextStyle = context.textStyle
        lastRenderMode = placement.renderMode
        lastCompatibilityLearningTrustContext = visualTrustContext
        cancelKeyboardEventTapIdleStop()
        guard let panelRect = suggestionPanel.show(
            text: suggestion.visibleText,
            near: placement.anchorRect,
            alignedTo: placement.renderMode == .inlineAdjacent ? placement.textLineRect : nil,
            boundedBy: placement.clippingRect,
            style: context.textStyle,
            renderMode: placement.renderMode
        ) else {
            let reason = "panel-frame-unusable"
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
                metadata: traceGeometryMetadata(context: context, renderMode: placement.renderMode)
                    .merging(traceRequestMetadata(request: request, context: context)) { current, _ in current }
                    .merging(learningAdjustment.metadata) { current, _ in current }
                    .merging(placement.metadata) { current, _ in current }
                    .merging(candidateSelectionMetadata) { current, _ in current }
                    .merging(displayScoreMetadata) { current, _ in current }
                    .merging(replacementMetadata) { current, _ in current }
            )
            recordSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                metadata: [
                    "reason": reason
                ]
                .merging(traceRequestMetadata(request: request, context: context)) { current, _ in current }
                .merging(learningAdjustment.metadata) { current, _ in current }
                .merging(placement.metadata) { current, _ in current }
                .merging(candidateSelectionMetadata) { current, _ in current }
                .merging(displayScoreMetadata) { current, _ in current }
                .merging(replacementMetadata) { current, _ in current }
            )
            hideSuggestion(reason: reason)
            return
        }

        suggestionSession.present(suggestion)
        setSuggestionDecision("Shown: \(triggerReason) \(latencyMilliseconds)ms")
        currentSuggestionID = suggestionID
        currentSuggestionAppBundleIdentifier = request.appBundleIdentifier ?? profile.bundleIdentifier
        currentSuggestionFieldIdentity = fieldIdentity
        currentSuggestionRequestMode = request.mode
        currentSuggestionTextBeforeCursor = request.textBeforeCursor
        currentSuggestionDisplayedText = suggestion.visibleText
        currentSuggestionFieldClassification = fieldClassification(for: context)
        currentSuggestionPresentedAt = Date()
        currentSuggestionDisplayScoreFinal = displayScoreTrace.score.finalScore
        currentSuggestionInvalidatedByUserKeyDown = false
        keyboardEventTap?.resetPassthroughObservation()
        updateKeyboardEventTapSnapshot()
        guard startKeyboardEventTapIfPossible() else {
            setSuggestionDecision("Blocked: keyboard capture unavailable")
            hideSuggestion(reason: "keyboard-capture-unavailable")
            return
        }
        keyboardEventTap?.suppressPassthroughObservation(for: 0.35)

        let screenshotCapture = traceScreenshotCaptureCoordinator.capture(
            TraceScreenshotCaptureRequest(
                rects: [
                    placement.anchorRect,
                    placement.textLineRect,
                    panelRect,
                    placement.clippingRect
                ].compactMap { $0 },
                expectedSignalRect: traceScreenshotCaptureCoordinator.expectedSignalRect(
                    panelRect: panelRect
                ),
                suggestionID: suggestionID,
                bundleIdentifier: request.appBundleIdentifier ?? profile.bundleIdentifier,
                triggerReason: triggerReason,
                appScreenshotTracingEnabled: learningAdjustment.shouldCaptureScreenshot,
                visualTrustContext: visualTrustContext
            )
        )
        compatibilityLearningStore.recordObservation(
            for: profile.bundleIdentifier,
            reason: "suggestion-presented"
        )
        let presentationTracePayload = suggestionPresentationTracePayloadBuilder.presented(
            suggestionID: suggestionID,
            requestMode: request.mode.rawValue,
            renderMode: placement.renderMode.rawValue,
            visibleText: suggestion.visibleText,
            visibleWordCount: suggestion.visibleWordCount,
            latencyMilliseconds: latencyMilliseconds,
            anchorRect: placement.anchorRect,
            textLineRect: placement.textLineRect,
            panelRect: panelRect,
            clippingRect: placement.clippingRect,
            screenshotCaptureRect: screenshotCapture.rectDescription,
            requestMetadata: traceRequestMetadata(request: request, context: context),
            geometryMetadata: traceGeometryMetadata(context: context, renderMode: placement.renderMode),
            learningMetadata: learningAdjustment.metadata,
            placementMetadata: placement.metadata,
            candidateSelectionMetadata: candidateSelectionMetadata,
            displayScoreMetadata: displayScoreMetadata,
            replacementMetadata: replacementMetadata
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
            metadata: presentationTracePayload.rawTraceMetadata
        )
        recordSuggestionEvent(
            "suggestion-presented",
            context: context,
            profile: profile,
            metadata: presentationTracePayload.diagnosticsMetadata
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
              frontmostAppMatchesSuggestion(
                  frontmostApp,
                  expectedBundleIdentifier: expectedBundleIdentifier,
                  profile: profile
              ) else {
            return (nil, "stale-app")
        }

        guard let rawContext = accessibilityClient.focusedTextContext(
            allowDescendantTextFallback: profile.allowsDescendantTextFallback
        ), !rawContext.isSecure,
           rawContext.selectedTextLength == 0 else {
            return (nil, "stale-focused-context")
        }

        guard claudeCodeTerminalHostProofBlockReason(
            app: frontmostApp,
            context: rawContext,
            profile: profile
        ) == nil else {
            return (nil, "stale-terminal-host-proof")
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
            profile: profile,
            previousSnapshot: lastTextSnapshot
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

    private func frontmostAppMatchesSuggestion(
        _ frontmostApp: RunningApplicationInfo,
        expectedBundleIdentifier: String,
        profile: CompatibilityProfile
    ) -> Bool {
        if frontmostApp.bundleIdentifier == expectedBundleIdentifier {
            return true
        }

        return expectedBundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier
            && isClaudeCodeTerminalHostProof(
                profile: profile,
                hostBundleIdentifier: frontmostApp.bundleIdentifier
            )
    }

    private func compatibilityLearningVisualTrustContext(
        for context: FocusedTextContext,
        bundleIdentifier: String
    ) -> CompatibilityLearningVisualTrustContext {
        CompatibilityLearningVisualTrustContext(
            appVersion: appVersionFingerprint(for: bundleIdentifier),
            screenFingerprint: visualRectFingerprint(context.windowRect ?? context.elementRect ?? context.caretRect),
            fieldShapeFingerprint: [
                context.role ?? "unknown",
                context.subrole ?? "none",
                "synthetic=\(context.caretIsSynthetic)",
                "inline=\(context.capabilities.supportsInlineSuggestions)",
                visualRectFingerprint(context.elementRect) ?? "element=none",
                visualRectFingerprint(context.textLineRect) ?? "line=none"
            ].joined(separator: "|")
        )
    }

    private func appVersionFingerprint(for bundleIdentifier: String) -> String? {
        guard !bundleIdentifier.isEmpty,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
              let bundle = Bundle(url: appURL) else {
            return nil
        }

        let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let versionParts = [shortVersion, buildVersion]
            .compactMap { value -> String? in
                guard let value,
                      !value.isEmpty else {
                    return nil
                }
                return value
            }

        guard !versionParts.isEmpty else {
            return nil
        }

        return versionParts.joined(separator: "#")
    }

    private func visualRectFingerprint(_ rect: CGRect?) -> String? {
        guard let rect else {
            return nil
        }

        return [
            Int((rect.minX / 8).rounded()),
            Int((rect.minY / 8).rounded()),
            Int((rect.width / 8).rounded()),
            Int((rect.height / 8).rounded())
        ].map(String.init).joined(separator: "x")
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
        .merging(traceFieldMetadata(context: context)) { current, _ in current }
    }

    private func traceFieldMetadata(context: FocusedTextContext) -> [String: String] {
        fieldClassification(for: context).traceMetadata
    }

    private func traceRequestMetadata(
        request: CompletionRequest,
        context: FocusedTextContext
    ) -> [String: String] {
        traceRequestMetadata(
            request: request,
            fieldClassification: fieldClassification(for: context)
        )
    }

    private func traceRequestMetadata(
        request: CompletionRequest,
        fieldClassification: AXFieldClassification
    ) -> [String: String] {
        request.behaviorProfileTraceMetadata
            .merging(fieldClassification.traceMetadata) { current, _ in current }
            .merging(suggestionAggressiveness.traceMetadata) { current, _ in current }
    }

    private func acceptedAndKeptSignal(
        request: CompletionRequest,
        fieldClassification: AXFieldClassification,
        profile: CompatibilityProfile
    ) -> AcceptedAndKeptLearningSignal {
        let requestFieldKind = request.fieldKind == .unknown ? fieldClassification.kind : request.fieldKind
        let appBundleIdentifier = request.appBundleIdentifier ?? profile.bundleIdentifier
        let acceptedAndKeptKey = AcceptedAndKeptLearningKey(
            appBundleIdentifier: appBundleIdentifier,
            fieldKind: requestFieldKind,
            requestMode: request.mode,
            behaviorProfileID: request.behaviorProfile.id
        )

        return activeAppProofBundleIdentifiers.contains(appBundleIdentifier)
            ? AcceptedAndKeptLearningStore().signal(for: acceptedAndKeptKey)
            : acceptedAndKeptLearning.signal(for: acceptedAndKeptKey)
    }

    private func fieldClassification(for context: FocusedTextContext) -> AXFieldClassification {
        fieldClassifier.classification(
            for: AXFieldClassifierInput(
                role: context.role,
                subrole: context.subrole,
                title: context.fingerprint.title,
                placeholder: context.fingerprint.placeholder,
                windowTitle: context.fingerprint.windowTitle,
                isSecure: context.isSecure,
                textBeforeCursorLength: context.textBeforeCursor.count,
                textAfterCursorLength: context.textAfterCursor.count,
                selectedTextLength: context.selectedTextLength,
                lineCount: lineCount(for: context)
            )
        )
    }

    private func lineCount(for context: FocusedTextContext) -> Int {
        let text = context.textBeforeCursor + context.textAfterCursor
        guard !text.isEmpty else {
            return 0
        }

        return text.split(
            omittingEmptySubsequences: false,
            whereSeparator: \.isNewline
        ).count
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
        safeMetadata["fieldIdentityMode"] = profile.fieldIdentityMode.rawValue
        safeMetadata["role"] = context.role ?? "unknown"
        safeMetadata["subrole"] = context.subrole ?? "none"
        safeMetadata["beforeChars"] = String(context.textBeforeCursor.count)
        safeMetadata["afterChars"] = String(context.textAfterCursor.count)
        safeMetadata["hasCaretRect"] = String(context.caretRect != nil)
        safeMetadata["hasElementRect"] = String(context.elementRect != nil)
        safeMetadata["hasWindowRect"] = String(context.windowRect != nil)
        safeMetadata["canReadValue"] = String(context.capabilities.canReadValue)
        safeMetadata["canReadRange"] = String(context.capabilities.canReadSelectedTextRange)
        safeMetadata["canReadBounds"] = String(context.capabilities.canReadBoundsForRange)
        safeMetadata["canSetSelectedText"] = String(context.capabilities.canSetSelectedText)
        safeMetadata.merge(traceFieldMetadata(context: context)) { current, _ in current }

        DiagnosticsLog.shared.record(event, metadata: safeMetadata)
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
            return accessibilityClient.insertText(acceptedText)
        }

        keyboardEventTap?.suppressPassthroughObservation(
            until: Date().addingTimeInterval(
                shouldUseClaudeCodeTerminalHostProofDirectInsertion(profile: profile) ? 0.75 : 0.25
            )
        )

        if shouldUseClaudeCodeTerminalHostProofDirectInsertion(profile: profile) {
            let succeeded = insertClaudeCodeTerminalHostProofText(acceptedText)
            DiagnosticsLog.shared.record(
                "insert",
                metadata: [
                    "app": profile.bundleIdentifier,
                    "mode": InsertionMode.clipboardFallbackOptIn.rawValue,
                    "success": String(succeeded),
                    "skippedModes": skippedModes
                        .map(\.rawValue)
                        .sorted()
                        .joined(separator: ",")
                ]
            )
            if succeeded {
                focusedTextPollingPause.pause(
                    now: Date(),
                    durationMilliseconds: postInsertionPollPauseMilliseconds
                )
            }
            return succeeded
        }

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

    private func shouldUseClaudeCodeTerminalHostProofDirectInsertion(profile: CompatibilityProfile) -> Bool {
        currentSuggestionAppBundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier
            && profile.bundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier
            && currentSuggestionRequestMode == .wordCompletion
            && profile.insertionMode == .clipboardFallbackOptIn
            && profile.requiresNoSubmitAcceptanceProof
    }

    private func insertClaudeCodeTerminalHostProofText(_ acceptedText: String) -> Bool {
        guard !acceptedText.isEmpty else {
            return false
        }

        guard terminalHostProofSnapshotMatchesCurrentSuggestion() else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "target-recheck-failed"
                ]
            )
            return false
        }
        guard let frontmostApp = accessibilityClient.frontmostApplication() else {
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(acceptedText, forType: .string) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "pasteboard-set-failed",
                    "source": "helperPaste"
                ]
            )
            return false
        }

        let posted = Self.postClaudeCodeTerminalHostProofPasteViaAccessibilityMenu(
            processIdentifier: frontmostApp.processIdentifier
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "posted": String(posted),
                "source": "accessibilityMenuPaste"
            ]
        )

        return posted
    }

    nonisolated private static func postClaudeCodeTerminalHostProofPasteViaAccessibilityMenu(
        processIdentifier: pid_t
    ) -> Bool {
        let appElement = AXUIElementCreateApplication(processIdentifier)
        guard let menuBarValue = axAttribute(appElement, kAXMenuBarAttribute),
              let editItem = axDescendant(
                  in: menuBarValue as! AXUIElement,
                  title: "Edit",
                  role: kAXMenuBarItemRole as String,
                  maxDepth: 2
              ) else {
            return false
        }

        AXUIElementPerformAction(editItem, kAXPressAction as CFString)
        Thread.sleep(forTimeInterval: 0.05)

        guard let pasteItem = axDescendant(
            in: editItem,
            title: "Paste",
            role: kAXMenuItemRole as String,
            maxDepth: 4
        ) else {
            return false
        }

        return AXUIElementPerformAction(pasteItem, kAXPressAction as CFString) == .success
    }

    nonisolated private static func axAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else {
            return nil
        }
        return value
    }

    nonisolated private static func axTitle(_ element: AXUIElement) -> String? {
        axAttribute(element, kAXTitleAttribute) as? String
    }

    nonisolated private static func axRole(_ element: AXUIElement) -> String? {
        axAttribute(element, kAXRoleAttribute) as? String
    }

    nonisolated private static func axChildren(_ element: AXUIElement) -> [AXUIElement] {
        axAttribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }

    nonisolated private static func axDescendant(
        in element: AXUIElement,
        title: String,
        role: String,
        maxDepth: Int
    ) -> AXUIElement? {
        guard maxDepth >= 0 else {
            return nil
        }

        if axTitle(element) == title,
           axRole(element) == role {
            return element
        }

        for child in axChildren(element) {
            if let match = axDescendant(
                in: child,
                title: title,
                role: role,
                maxDepth: maxDepth - 1
            ) {
                return match
            }
        }

        return nil
    }

    private func recordRawAcceptance(
        action: KeyboardAction,
        acceptedText: String,
        acceptanceID: String,
        acceptanceProof: SuggestionAcceptanceProof
    ) {
        guard let appBundleIdentifier = currentSuggestionAppBundleIdentifier ?? currentProfile?.bundleIdentifier else {
            return
        }

        var metadata = [
            "acceptanceID": acceptanceID,
            "acceptMode": action.diagnosticName,
            "acceptanceSafety": "passed",
            "requiresNoSubmitAcceptanceProof": String(
                currentProfile?.requiresNoSubmitAcceptanceProof == true
            )
        ]
        if let fieldClassification = currentSuggestionFieldClassification {
            metadata.merge(fieldClassification.traceMetadata) { current, _ in current }
        }
        metadata.merge(acceptanceProof.traceMetadata) { current, _ in current }

        RawAutocompleteTraceLog.shared.recordAcceptance(
            action: action.diagnosticName,
            appBundleIdentifier: appBundleIdentifier,
            acceptedText: acceptedText,
            remainingVisibleText: suggestionSession.visibleSuggestion?.visibleText,
            suggestionID: currentSuggestionID ?? "",
            fieldIdentity: currentSuggestionFieldIdentity?.traceDescription
                ?? currentFieldIdentity?.traceDescription
                ?? "",
            requestMode: currentSuggestionRequestMode?.rawValue ?? "",
            metadata: metadata
        )
    }

    private func suggestionAcceptanceProof(
        action: KeyboardAction,
        acceptedText: String
    ) -> SuggestionAcceptanceProof? {
        let visibleText = currentSuggestionDisplayedText ?? suggestionSession.visibleSuggestion?.visibleText
        guard let profile = currentProfile else {
            recordAcceptanceSafetyBlocked(
                action: action,
                acceptedText: acceptedText,
                visibleText: visibleText,
                reason: "missing-profile"
            )
            return nil
        }

        switch acceptanceSafetyPolicy.decision(
            action: action,
            acceptedText: acceptedText,
            visibleText: visibleText,
            profile: profile
        ) {
        case .allowed:
            break
        case let .blocked(reason):
            recordAcceptanceSafetyBlocked(
                action: action,
                acceptedText: acceptedText,
                visibleText: visibleText,
                reason: reason.rawValue
            )
            return nil
        }

        let decision = suggestionAcceptanceProofPolicy.decision(
            action: action,
            acceptedText: acceptedText,
            visibleText: visibleText
        )

        switch decision {
        case let .allowed(proof):
            return proof
        case let .blocked(reason):
            let metadata = [
                "reason": "acceptance-proof-failed",
                "acceptanceProof": "failed",
                "acceptanceProofReason": reason.rawValue,
                "acceptMode": action.diagnosticName,
                "acceptedChars": String(acceptedText.count),
                "visibleChars": String(visibleText?.count ?? 0)
            ]
            DiagnosticsLog.shared.record("acceptance-proof-failed", metadata: metadata)
            if let suggestionID = currentSuggestionID {
                RawAutocompleteTraceLog.shared.record(
                    type: .suggestionSuppressed,
                    suggestionID: suggestionID,
                    appBundleIdentifier: currentSuggestionAppBundleIdentifier ?? currentProfile?.bundleIdentifier ?? "",
                    fieldIdentity: currentSuggestionFieldIdentity?.traceDescription
                        ?? currentFieldIdentity?.traceDescription
                        ?? "",
                    requestMode: currentSuggestionRequestMode?.rawValue ?? "",
                    reason: "acceptance-proof-failed",
                    metadata: metadata
                )
            }
            setSuggestionDecision("Blocked: acceptance proof failed")
            hideSuggestion(reason: "acceptance-proof-failed", metadata: metadata)
            return nil
        }
    }

    private func recordAcceptanceSafetyBlocked(
        action: KeyboardAction,
        acceptedText: String,
        visibleText: String?,
        reason: String
    ) {
        let metadata = [
            "reason": "acceptance-safety-blocked",
            "acceptanceSafety": "blocked",
            "acceptanceSafetyReason": reason,
            "acceptMode": action.diagnosticName,
            "acceptedChars": String(acceptedText.count),
            "visibleChars": String(visibleText?.count ?? 0)
        ]
        DiagnosticsLog.shared.record("acceptance-safety-blocked", metadata: metadata)
        if let suggestionID = currentSuggestionID {
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: suggestionID,
                appBundleIdentifier: currentSuggestionAppBundleIdentifier ?? currentProfile?.bundleIdentifier ?? "",
                fieldIdentity: currentSuggestionFieldIdentity?.traceDescription
                    ?? currentFieldIdentity?.traceDescription
                    ?? "",
                requestMode: currentSuggestionRequestMode?.rawValue ?? "",
                reason: "acceptance-safety-blocked",
                metadata: metadata
            )
        }
        setSuggestionDecision("Blocked: acceptance safety failed")
        hideSuggestion(reason: "acceptance-safety-blocked", metadata: metadata)
    }

    private func refreshVisibleSuggestion() {
        guard let suggestion = suggestionSession.visibleSuggestion,
              let caretRect = lastCaretRect else {
            hideSuggestion()
            return
        }

        currentSuggestionDisplayedText = suggestion.visibleText
        cancelKeyboardEventTapIdleStop()
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

        let storedLearningAdjustment = compatibilityLearningStore.engine().adjustment(
            for: profile.bundleIdentifier,
            profileRenderMode: renderMode
        )
        let visualTrustContext = compatibilityLearningVisualTrustContext(
            for: context,
            bundleIdentifier: profile.bundleIdentifier
        )
        let learningAdjustment = storedLearningAdjustment.trustedVisualOffsetOnly(context: visualTrustContext)
        let placementPlan = suggestionOrchestrator.placementHealthPlan(
            context: context,
            profile: profile,
            learningAdjustment: learningAdjustment,
            screenshotTracingEnabled: RawAutocompleteTraceLog.shared.screenshotTracingEnabled
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
                hideSuggestion(reason: "placement-\(suppression.reason.rawValue)")
            }
            return
        }

        lastCaretRect = placement.anchorRect
        lastTextLineRect = placement.textLineRect
        lastClippingRect = placement.clippingRect
        lastTextStyle = context.textStyle
        lastRenderMode = placement.renderMode
        lastCompatibilityLearningTrustContext = visualTrustContext
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
            return
        }

        if let currentSuggestionTextBeforeCursor {
            self.currentSuggestionTextBeforeCursor = currentSuggestionTextBeforeCursor + acceptedText
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

        var metadata = [
            "typedSuffix": typedSuffix
        ]
        metadata.merge(recordPrefixFamilyCooldown(
            .typedOver,
            input: PrefixFamilyCooldownInput(
                appBundleIdentifier: profile.bundleIdentifier,
                fieldIdentifier: fieldIdentity.traceDescription,
                requestMode: currentSuggestionRequestMode,
                textBeforeCursor: newTextBeforeCursor
            )
        )) { current, _ in current }
        metadata.merge(currentSuggestionLifetimeMetadata()) { current, _ in current }

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
            metadata: metadata
        )
        recordAnnoyanceSignal(
            .typedOver,
            context: annoyanceContext(
                appBundleIdentifier: profile.bundleIdentifier,
                fieldIdentity: fieldIdentity,
                requestMode: currentSuggestionRequestMode,
                fieldKind: currentSuggestionFieldClassification?.kind ?? .unknown
            ),
            suggestionID: suggestionID,
            reason: "typed-against-visible-suggestion",
            metadata: metadata
        )
    }

    private func advanceVisibleSuggestionForTypingProgressIfNeeded(
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        snapshot: FocusedTextSnapshot
    ) -> Bool {
        guard suggestionSession.hasVisibleSuggestion,
              fieldIdentity == currentFieldIdentity,
              let originalTextBeforeCursor = currentSuggestionTextBeforeCursor,
              let displayedText = currentSuggestionDisplayedText,
              context.textBeforeCursor.hasPrefix(originalTextBeforeCursor),
              context.textBeforeCursor != originalTextBeforeCursor else {
            return false
        }

        let progress = suggestionTypingProgressPolicy.progress(
            originalTextBeforeCursor: originalTextBeforeCursor,
            displayedText: displayedText,
            newTextBeforeCursor: context.textBeforeCursor
        )

        if case let .typedThroughVisiblePrefix(typedSuffix) = progress {
            guard suggestionSession.commitTypedVisiblePrefix(typedSuffix) else {
                return false
            }

            lastTextSnapshot = snapshot
            invalidatePendingSuggestionRequest()
            currentSuggestionTextBeforeCursor = context.textBeforeCursor
            setSuggestionDecision("Shown: typing through suggestion")
            recordSuggestionEvent(
                "suggestion-typed-through",
                context: context,
                profile: profile,
                metadata: [
                    "reason": "visible-prefix-advanced",
                    "typedSuffixChars": String(typedSuffix.count),
                    "remainingVisibleChars": String(suggestionSession.visibleSuggestion?.visibleText.count ?? 0)
                ]
            )
            keyboardEventTap?.suppressPassthroughObservation(for: 0.35)
            repositionVisibleSuggestion(context: context, profile: profile)
            return true
        } else if case .typedOver = progress {
            suggestionRepetitionSuppressor.recordMiss(
                displayedText,
                mode: currentSuggestionRequestMode,
                scope: currentSuggestionAppBundleIdentifier ?? currentProfile?.bundleIdentifier ?? ""
            )
            hideSuggestion(reason: "typed-over")
        }

        return false
    }

    private func hideSuggestion(
        reason: String = "hidden",
        metadata extraMetadata: [String: String] = [:]
    ) {
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
            let lifetimeMilliseconds = currentSuggestionLifetimeMilliseconds()
            var metadata = currentSuggestionLifetimeMetadata(lifetimeMilliseconds: lifetimeMilliseconds)

            if outcome == "ignored" {
                let missRecord = suggestionRepetitionSuppressor.recordIgnored(
                    displayedText,
                    mode: currentSuggestionRequestMode,
                    scope: appBundleIdentifier,
                    lifetimeMilliseconds: lifetimeMilliseconds
                )
                if let missRecord {
                    metadata.merge(missRecord.traceMetadata) { current, _ in current }
                }
            }
            metadata.merge(extraMetadata) { current, _ in current }

            RawAutocompleteTraceLog.shared.record(
                type: .suggestionHidden,
                suggestionID: suggestionID,
                appBundleIdentifier: appBundleIdentifier,
                fieldIdentity: fieldIdentityDescription,
                requestMode: currentSuggestionRequestMode?.rawValue ?? "",
                displayedText: displayedText,
                outcome: outcome,
                reason: reason,
                metadata: metadata
            )
            setSuggestionDecision("Hidden: \(reason)")
        }

        suggestionSession.dismiss()
        currentSuggestionID = nil
        currentSuggestionAppBundleIdentifier = nil
        currentSuggestionFieldIdentity = nil
        currentSuggestionRequestMode = nil
        currentSuggestionTextBeforeCursor = nil
        currentSuggestionDisplayedText = nil
        currentSuggestionFieldClassification = nil
        currentSuggestionPresentedAt = nil
        currentSuggestionDisplayScoreFinal = nil
        currentSuggestionInvalidatedByUserKeyDown = false
        suggestionOrchestrator.clearStreamingPresentations()
        lastCaretRect = nil
        lastTextLineRect = nil
        lastClippingRect = nil
        lastTextStyle = nil
        lastRenderMode = nil
        lastCompatibilityLearningTrustContext = nil
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
        let supportStatus = profile.map { CompatibilitySupportStatus.supported($0) }
            ?? app.map { profileStore.supportStatus(for: $0.bundleIdentifier) }
            ?? .unsupported
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
                renderModeOverride: compatibilityLearningStore.profile(for: $0.bundleIdentifier)?.renderModeOverride
            )
        }
        let fieldControlState = settingsFieldControlState
        let statusLine = statusMenuTitle(
            app: app,
            supportStatus: supportStatus,
            appEnabled: appEnabled
        )
        let statusSignature = [
            control,
            permission,
            appStatus,
            appControlState?.fallbackText ?? "",
            lastSuggestionDecision,
            statusLine,
            fieldControlState.statusText
        ].joined(separator: "|")

        statusMenuItem?.title = statusLine
        statusMenuItem?.toolTip = lastSuggestionDecision
        pauseSuggestionsMenuItem?.title = pauseSuggestionsTitle
        silenceFieldMenuItem?.title = fieldControlState.buttonTitle
        silenceFieldMenuItem?.isEnabled = fieldControlState.canSilence
        silenceFieldMenuItem?.toolTip = fieldControlState.detailText
        toggleAppMenuItem?.title = appControlState?.menuToggleTitle ?? "Toggle Current App"
        toggleAppMenuItem?.isEnabled = appControlState?.canToggle ?? false
        toggleAppMenuItem?.toolTip = appControlState?.fallbackText
        if settingsWindow.isShowing {
            settingsWindow.refresh(
                isTrusted: accessibilityClient.isTrusted,
                suggestionsPaused: suggestionsPaused,
                runtimeReport: runtimeReadinessReport,
                runtimeTargetSummary: runtimeTargetSummary,
                modelDirectoryPath: modelDirectoryPath,
                modelInstallStatusText: modelInstallStatusText,
                isModelInstallInProgress: modelInstallTask != nil,
                currentApp: settingsCurrentAppState,
                fieldControl: settingsFieldControlState,
                privacy: settingsPrivacyState,
                keyboardShortcuts: settingsKeyboardShortcutState,
                suggestionAggressiveness: settingsSuggestionAggressivenessState,
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
            return pauseStatusTitle
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

    private func annoyanceContext(
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity?,
        requestMode: CompletionRequestMode?,
        fieldKind: AXFieldKind = .unknown
    ) -> AnnoyanceContext {
        AnnoyanceContext(
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentifier: fieldIdentity?.traceDescription ?? "\(appBundleIdentifier)|app",
            requestMode: requestMode,
            fieldKind: fieldKind
        )
    }

    private func currentAnnoyanceContext(
        appBundleIdentifier: String? = nil,
        fieldKind: AXFieldKind? = nil
    ) -> AnnoyanceContext? {
        let resolvedAppBundleIdentifier = appBundleIdentifier
            ?? currentSuggestionAppBundleIdentifier
            ?? currentProfile?.bundleIdentifier
            ?? targetAppForControls()?.bundleIdentifier
        guard let resolvedAppBundleIdentifier else {
            return nil
        }

        return annoyanceContext(
            appBundleIdentifier: resolvedAppBundleIdentifier,
            fieldIdentity: currentSuggestionFieldIdentity ?? currentFieldIdentity,
            requestMode: currentSuggestionRequestMode,
            fieldKind: fieldKind
                ?? currentSuggestionFieldClassification?.kind
                ?? .unknown
        )
    }

    private func annoyanceContext(for tracker: AcceptanceSurvivalTracker) -> AnnoyanceContext {
        annoyanceContext(
            appBundleIdentifier: tracker.appBundleIdentifier,
            fieldIdentity: tracker.fieldIdentity,
            requestMode: CompletionRequestMode(rawValue: tracker.requestMode),
            fieldKind: tracker.fieldKind
        )
    }

    private func currentSuggestionLifetimeMetadata(now: Date = Date()) -> [String: String] {
        currentSuggestionLifetimeMetadata(lifetimeMilliseconds: currentSuggestionLifetimeMilliseconds(now: now))
    }

    private func currentSuggestionLifetimeMetadata(lifetimeMilliseconds: Int?) -> [String: String] {
        guard let lifetimeMilliseconds else {
            return [:]
        }

        return [
            "lifetimeMs": String(lifetimeMilliseconds)
        ]
    }

    private func currentSuggestionLifetimeMilliseconds(now: Date = Date()) -> Int? {
        guard let currentSuggestionPresentedAt else {
            return nil
        }

        return max(0, Int(now.timeIntervalSince(currentSuggestionPresentedAt) * 1_000))
    }

    private func currentPrefixFamilyCooldownInput(
        textBeforeCursor: String? = nil
    ) -> PrefixFamilyCooldownInput? {
        let appBundleIdentifier = currentSuggestionAppBundleIdentifier ?? currentProfile?.bundleIdentifier
        let fieldIdentity = currentSuggestionFieldIdentity ?? currentFieldIdentity
        let textBeforeCursor = textBeforeCursor ?? currentSuggestionTextBeforeCursor
        guard let appBundleIdentifier,
              let fieldIdentity,
              let textBeforeCursor else {
            return nil
        }

        return PrefixFamilyCooldownInput(
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentifier: fieldIdentity.traceDescription,
            requestMode: currentSuggestionRequestMode,
            textBeforeCursor: textBeforeCursor
        )
    }

    private func recordPrefixFamilyCooldown(
        _ reason: PrefixFamilyCooldownReason,
        input: PrefixFamilyCooldownInput
    ) -> [String: String] {
        guard let cooldown = suggestionOrchestrator.recordPrefixFamilyCooldown(reason, input: input) else {
            return [:]
        }

        DiagnosticsLog.shared.record(
            "prefix-family-cooldown",
            metadata: cooldown.metadata.merging([
                "app": input.appBundleIdentifier,
                "reason": reason.rawValue,
                "durationMilliseconds": String(cooldown.durationMilliseconds)
            ]) { current, _ in current }
        )
        return cooldown.metadata
    }

    private func recordPlacementUncertainty(
        suggestionID: String,
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity,
        requestMode: CompletionRequestMode,
        context: FocusedTextContext,
        reason: String,
        metadata: [String: String]
    ) {
        RawAutocompleteTraceLog.shared.record(
            type: .caretGeometryFailed,
            suggestionID: suggestionID,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentity.traceDescription,
            requestMode: requestMode.rawValue,
            triggerReason: "placement-uncertainty",
            reason: reason,
            metadata: metadata
        )

        let classification = fieldClassification(for: context)
        recordAnnoyanceSignal(
            .caretGeometryFailed,
            context: annoyanceContext(
                appBundleIdentifier: appBundleIdentifier,
                fieldIdentity: fieldIdentity,
                requestMode: requestMode,
                fieldKind: classification.kind
            ),
            suggestionID: suggestionID,
            reason: reason,
            metadata: metadata
        )
    }

    private func recordAnnoyanceSignal(
        _ signal: AnnoyanceSignal,
        context: AnnoyanceContext?,
        suggestionID: String = "",
        reason: String,
        metadata: [String: String] = [:]
    ) {
        guard let context else {
            return
        }

        Task { @MainActor [weak self, signal, context, suggestionID, reason, metadata] in
            guard let self else {
                return
            }

            let update = await self.annoyanceSuppressor.record(signal, context: context)
            self.recordAnnoyanceUpdate(
                update,
                context: context,
                suggestionID: suggestionID,
                reason: reason,
                metadata: metadata
            )
        }
    }

    private func recordAnnoyanceUpdate(
        _ actorUpdate: AnnoyanceSuppressorActorUpdate,
        context: AnnoyanceContext,
        suggestionID: String,
        reason: String,
        metadata: [String: String]
    ) {
        let update = actorUpdate.update
        var traceMetadata = metadata
        traceMetadata["annoyanceSignal"] = update.signal.rawValue
        traceMetadata["annoyanceReason"] = reason
        traceMetadata["annoyanceFieldScore"] = String(format: "%.3f", update.fieldScore)
        traceMetadata["annoyanceAppScore"] = String(format: "%.3f", update.appScore)
        traceMetadata["annoyanceGlobalScore"] = String(format: "%.3f", update.globalScore)
        traceMetadata["quietMode"] = actorUpdate.quietMode.traceReason
        traceMetadata["fieldKind"] = context.fieldKind.rawValue
        traceMetadata.merge(actorUpdate.quietMode.metadata) { current, _ in current }

        DiagnosticsLog.shared.record(
            "annoyance-signal",
            metadata: [
                "app": context.appBundleIdentifier,
                "signal": update.signal.rawValue,
                "reason": reason,
                "quietMode": actorUpdate.quietMode.traceReason,
                "fieldScore": String(format: "%.3f", update.fieldScore),
                "appScore": String(format: "%.3f", update.appScore),
                "globalScore": String(format: "%.3f", update.globalScore)
            ]
        )

        guard !update.startedQuietModes.isEmpty else {
            return
        }

        RawAutocompleteTraceLog.shared.record(
            type: .suggestionSuppressed,
            suggestionID: suggestionID,
            appBundleIdentifier: context.appBundleIdentifier,
            fieldIdentity: context.fieldIdentifier,
            requestMode: context.requestMode?.rawValue ?? "",
            triggerReason: "annoyance-signal",
            outcome: update.signal.rawValue,
            reason: "quiet-mode-started",
            metadata: traceMetadata
        )
    }

    private func transitionToField(_ fieldIdentity: FocusedFieldIdentity) {
        guard currentFieldIdentity != fieldIdentity else {
            return
        }

        finalizeAcceptanceSurvivalForCurrentField()
        if suggestionSession.hasVisibleSuggestion {
            hideSuggestion(reason: "focus-changed")
        }
        invalidatePendingSuggestionRequest()

        if let currentFieldIdentity {
            suppressedFieldIdentities.remove(currentFieldIdentity)
            Task { [annoyanceSuppressor] in
                await annoyanceSuppressor.clearField(currentFieldIdentity.traceDescription)
            }
        }

        currentFieldIdentity = fieldIdentity
        lastTextSnapshot = nil
        lastFocusedTextChangeAt = nil
        lastRequestedTextBeforeCursor = nil
        suggestionBlockLogGate.reset()
    }

    private func clearFocusedFieldState(
        hideReason: String = "focus-lost",
        resetBlockLogGate: Bool = true
    ) {
        finalizeAcceptanceSurvivalForCurrentField()
        if suggestionSession.hasVisibleSuggestion {
            hideSuggestion(reason: hideReason)
        }
        invalidatePendingSuggestionRequest()

        if let currentFieldIdentity {
            suppressedFieldIdentities.remove(currentFieldIdentity)
            Task { [annoyanceSuppressor] in
                await annoyanceSuppressor.clearField(currentFieldIdentity.traceDescription)
            }
        }

        currentFieldIdentity = nil
        lastTextSnapshot = nil
        lastFocusedTextChangeAt = nil
        lastRequestedTextBeforeCursor = nil
        if resetBlockLogGate {
            suggestionBlockLogGate.reset()
        }
    }

    private func invalidatePendingSuggestionRequest() {
        debounceTask?.cancel()
        debounceTask = nil
        suggestionOrchestrator.clearStreamingPresentations()
        suggestionOrchestrator.invalidate()
    }

    @objc
    private func requestAccessibilityPermission() {
        accessibilityClient.requestPermissionIfNeeded()
        settingsWindow.refresh(
            isTrusted: accessibilityClient.isTrusted,
            suggestionsPaused: suggestionsPaused,
            runtimeReport: runtimeReadinessReport,
            runtimeTargetSummary: runtimeTargetSummary,
            modelDirectoryPath: modelDirectoryPath,
            modelInstallStatusText: modelInstallStatusText,
            isModelInstallInProgress: modelInstallTask != nil,
            currentApp: settingsCurrentAppState,
            fieldControl: settingsFieldControlState,
            privacy: settingsPrivacyState,
            keyboardShortcuts: settingsKeyboardShortcutState,
            suggestionAggressiveness: settingsSuggestionAggressivenessState,
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
    private func showSettings() {
        settingsWindow.show(
            isTrusted: accessibilityClient.isTrusted,
            suggestionsPaused: suggestionsPaused,
            runtimeReport: runtimeReadinessReport,
            runtimeTargetSummary: runtimeTargetSummary,
            modelDirectoryPath: modelDirectoryPath,
            modelInstallStatusText: modelInstallStatusText,
            isModelInstallInProgress: modelInstallTask != nil,
            currentApp: settingsCurrentAppState,
            fieldControl: settingsFieldControlState,
            privacy: settingsPrivacyState,
            keyboardShortcuts: settingsKeyboardShortcutState,
            suggestionAggressiveness: settingsSuggestionAggressivenessState,
            lastSuggestionDecision: lastSuggestionDecision
        )
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

    private func startModelInstall() {
        guard modelInstallTask == nil else {
            return
        }

        let manifest = modelRuntimeBundle.bootstrapPlan.preferredAsset
        let destinationURL = modelRuntimeBundle.modelDirectoryURL
        isModelInstallCancelRequested = false
        modelInstallStatusText = "Model install: preparing download"
        refreshRuntimeChrome()
        DiagnosticsLog.shared.record(
            "model-install-start",
            metadata: [
                "model": manifest.model.rawValue,
                "repoID": manifest.source?.repoID ?? "",
                "target": destinationURL.path
            ]
        )

        let installer = LocalModelAssetInstaller(
            manifest: manifest,
            destinationURL: destinationURL
        )
        modelInstallTask = Task { [weak self, installer] in
            do {
                let installedURL = try await installer.install { progress in
                    self?.modelInstallStatusText = progress.userFacingText
                    self?.refreshRuntimeChrome()
                }

                await MainActor.run {
                    DiagnosticsLog.shared.record(
                        "model-install-succeeded",
                        metadata: [
                            "model": manifest.model.rawValue,
                            "target": installedURL.path
                        ]
                    )
                    self?.modelInstallTask = nil
                    self?.modelInstallStatusText = "Model install: warming local runtime"
                    self?.reloadModelRuntimeAfterInstall()
                }
            } catch {
                await MainActor.run {
                    if error is CancellationError || self?.isModelInstallCancelRequested == true {
                        DiagnosticsLog.shared.record(
                            "model-install-canceled",
                            metadata: [
                                "model": manifest.model.rawValue
                            ]
                        )
                        self?.modelInstallTask = nil
                        self?.isModelInstallCancelRequested = false
                        self?.modelInstallStatusText = "Model install canceled."
                        self?.refreshRuntimeChrome()
                        self?.showSettings()
                        return
                    }

                    DiagnosticsLog.shared.record(
                        "model-install-failed",
                        metadata: [
                            "model": manifest.model.rawValue,
                            "reason": error.localizedDescription
                        ]
                    )
                    self?.modelInstallTask = nil
                    self?.modelInstallStatusText = "Model install failed: \(error.localizedDescription)"
                    self?.refreshRuntimeChrome()
                    self?.showSettings()
                }
            }
        }
    }

    private func reloadModelRuntimeAfterInstall() {
        runtimeWarmTask?.cancel()
        modelRuntimeBundle = AppModelRuntimeFactory.makeRuntime()
        engine = RuntimeBackedCompletionEngine(runtime: modelRuntime)
        suggestionOrchestrator.updateEngine(engine)
        currentRuntimeState = .unavailable(reason: "model install completed")
        DiagnosticsLog.shared.record("runtime-bootstrap", metadata: modelRuntimeBundle.diagnosticsMetadata)
        refreshRuntimeChrome()
        warmModelRuntime()
    }

    private func cancelModelInstall() {
        guard let modelInstallTask else {
            return
        }

        isModelInstallCancelRequested = true
        modelInstallStatusText = "Model install: canceling"
        DiagnosticsLog.shared.record(
            "model-install-cancel-requested",
            metadata: [
                "model": modelRuntimeBundle.bootstrapPlan.preferredAsset.model.rawValue
            ]
        )
        refreshRuntimeChrome()
        modelInstallTask.cancel()
    }

    private func performRuntimeAction(_ action: RuntimeReadinessAction) {
        switch action {
        case .installModel, .repairModel:
            startModelInstall()
        case .cancelModelInstall:
            cancelModelInstall()
        case .revealModelFolder:
            revealModelFolder()
        case .retry:
            warmModelRuntime()
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

    private func clearLearningData() {
        acceptedAndKeptLearning = AcceptedAndKeptLearningStore()
        acceptedTextStyleMemory = AcceptedTextStyleMemoryStore()
        recentWordMemory = ScopedRecentWordMemory()
        suggestionRepetitionSuppressor = SuggestionRepetitionSuppressor()
        suggestionOrchestrator.resetPrefixFamilyCooldownPolicy(makePrefixFamilyCooldownPolicy())
        UserDefaults.standard.removeObject(forKey: Self.acceptedAndKeptLearningDefaultsKey)
        UserDefaults.standard.removeObject(forKey: Self.acceptedTextStyleMemoryDefaultsKey)
        DiagnosticsLog.shared.record(
            "learning-data-cleared",
            metadata: ["surface": "settings"]
        )
        refreshRuntimeChrome()
    }

    private func cycleAcceptAllShortcut() {
        setAcceptAllShortcut(keyboardShortcutConfiguration.acceptAllShortcut.next)
    }

    private func makePrefixFamilyCooldownPolicy() -> PrefixFamilyCooldownPolicy {
        PrefixFamilyCooldownPolicy(traceFingerprintSecret: tracePrivacySecretStore.secret())
    }

    private func setAcceptAllShortcut(_ shortcut: AcceptAllShortcut) {
        keyboardShortcutConfiguration.acceptAllShortcut = shortcut
        persistKeyboardShortcutConfiguration()
        updateKeyboardEventTapSnapshot()
        DiagnosticsLog.shared.record(
            "keyboard-shortcut-control",
            metadata: [
                "surface": "settings",
                "acceptAllShortcut": shortcut.rawValue
            ]
        )
        refreshRuntimeChrome()
    }

    private func cycleSuggestionAggressiveness() {
        suggestionAggressiveness = suggestionAggressiveness.next
        persistSuggestionAggressiveness()
        lastRequestedTextBeforeCursor = nil
        invalidatePendingSuggestionRequest()
        if suggestionSession.hasVisibleSuggestion {
            hideSuggestion(reason: "aggressiveness-changed")
        }
        setSuggestionDecision("Ready: \(suggestionAggressiveness.displayName.lowercased()) suggestions")
        DiagnosticsLog.shared.record(
            "suggestion-aggressiveness-control",
            metadata: [
                "surface": "settings",
                "suggestionAggressiveness": suggestionAggressiveness.rawValue
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
            visualTrustContext: lastCompatibilityLearningTrustContext
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
        guard let bundleURL = RawAutocompleteTraceLog.shared.exportPrivacyBundle() else {
            DiagnosticsLog.shared.record("trace-privacy-bundle-export-failed")
            showDiagnostics()
            return
        }

        NSWorkspace.shared.open(bundleURL)
        DiagnosticsLog.shared.record(
            "trace-privacy-bundle-exported",
            metadata: ["path": bundleURL.path]
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

        if !shouldDisable {
            markAppEnablementSetupCompleted()
        }

        if shouldDisable {
            let context = currentAnnoyanceContext(appBundleIdentifier: app.bundleIdentifier)
                ?? annoyanceContext(
                    appBundleIdentifier: app.bundleIdentifier,
                    fieldIdentity: currentFieldIdentity,
                    requestMode: currentSuggestionRequestMode
                )
            RawAutocompleteTraceLog.shared.record(
                type: .appDisabled,
                suggestionID: currentSuggestionID ?? "",
                appBundleIdentifier: app.bundleIdentifier,
                fieldIdentity: context.fieldIdentifier,
                requestMode: context.requestMode?.rawValue ?? "",
                reason: "manual"
            )
            recordAnnoyanceSignal(
                .appDisable,
                context: context,
                suggestionID: currentSuggestionID ?? "",
                reason: "manual"
            )
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

    @objc
    private func toggleCurrentAppMirrorMode() {
        guard let app = targetAppForControls(),
              let profile = profileStore.profile(for: app.bundleIdentifier),
              profile.canPresentSuggestions,
              !profile.isSensitive,
              profile.renderMode != .disabled else {
            return
        }

        let currentOverride = compatibilityLearningStore
            .profile(for: app.bundleIdentifier)?
            .renderModeOverride
        let nextOverride: SuggestionRenderMode? = currentOverride == .floatingMirror ? nil : .floatingMirror
        compatibilityLearningStore.setRenderModeOverride(nextOverride, for: app.bundleIdentifier)

        let overrideText = nextOverride?.rawValue ?? "profile"
        let suggestionID = currentSuggestionID ?? ""
        setSuggestionDecision("Ready: app mode \(overrideText)")
        lastTextSnapshot = nil
        lastFocusedTextChangeAt = nil
        lastRequestedTextBeforeCursor = nil
        invalidatePendingSuggestionRequest()
        if suggestionSession.hasVisibleSuggestion {
            hideSuggestion(reason: "render-mode-changed")
        }

        RawAutocompleteTraceLog.shared.record(
            type: .renderModeChanged,
            suggestionID: suggestionID,
            appBundleIdentifier: app.bundleIdentifier,
            fieldIdentity: currentFieldIdentity?.traceDescription ?? "",
            requestMode: currentSuggestionRequestMode?.rawValue ?? "",
            reason: "manual",
            metadata: [
                "renderModeOverride": overrideText
            ]
        )
        DiagnosticsLog.shared.record(
            "app-mode-control",
            metadata: [
                "app": app.bundleIdentifier,
                "renderModeOverride": overrideText
            ]
        )
        refreshRuntimeChrome()
        updateStatusMenu(
            app: app,
            profile: profile,
            appEnabled: !disabledBundleIdentifiers.contains(app.bundleIdentifier)
        )
    }

    @objc
    private func startCurrentAppProof() {
        guard let app = targetAppForControls(),
              let profile = profileStore.profile(for: app.bundleIdentifier),
              !profile.isSensitive else {
            return
        }

        guard !disabledBundleIdentifiers.contains(app.bundleIdentifier) else {
            setSuggestionDecision("Blocked: enable this app first")
            refreshRuntimeChrome()
            DiagnosticsLog.shared.record(
                "app-proof-blocked",
                metadata: [
                    "app": app.bundleIdentifier,
                    "reason": "disabled"
                ]
            )
            return
        }

        beginAppProofMode(for: app.bundleIdentifier)
        compatibilityLearningStore.setScreenshotTracing(true, for: app.bundleIdentifier)
        DiagnosticsLog.shared.record(
            "app-proof-started",
            metadata: [
                "app": app.bundleIdentifier,
                "support": profile.supportLevel.rawValue
            ]
        )

        if appProofCommandCoordinator.supportsAutomaticPlan(for: app.bundleIdentifier) {
            runAutomaticAppProof(app: app)
            return
        }

        setSuggestionDecision("Ready: app proof started")
        refreshRuntimeChrome()
        showDiagnostics()
    }

    private func runAutomaticAppProof(app: RunningApplicationInfo) {
        let outcome = appProofCommandCoordinator.start(for: app.bundleIdentifier) { [weak self] completion in
            guard let self else {
                return
            }

            self.setSuggestionDecision(completion.decisionText)
            self.endAppProofMode(for: completion.plan.bundleIdentifier, reason: completion.endReason)
            DiagnosticsLog.shared.record(
                "app-proof-command-finished",
                metadata: [
                    "app": completion.plan.bundleIdentifier,
                    "outcome": completion.passed ? "passed" : "failed",
                    "status": String(completion.status),
                    "log": completion.plan.logURL.path
                ]
            )
            self.refreshRuntimeChrome()
        }
        if let endReason = outcome.proofModeEndReasonAfterStartAttempt {
            endAppProofMode(for: app.bundleIdentifier, reason: endReason)
        }

        switch outcome {
        case .unsupported:
            setSuggestionDecision("Ready: app proof started")
            refreshRuntimeChrome()
            showDiagnostics()
        case let .unavailable(bundleIdentifier):
            setSuggestionDecision("Blocked: proof script unavailable")
            DiagnosticsLog.shared.record(
                "app-proof-command-unavailable",
                metadata: [
                    "app": bundleIdentifier
                ]
            )
            refreshRuntimeChrome()
            showDiagnostics()
        case let .started(plan):
            setSuggestionDecision(outcome.decisionText ?? "Running: app proof")
            DiagnosticsLog.shared.record(
                "app-proof-command-started",
                metadata: [
                    "app": plan.bundleIdentifier,
                    "command": plan.commandText,
                    "log": plan.logURL.path
                ]
            )
            refreshRuntimeChrome()
            showDiagnostics()
        case let .alreadyRunning(bundleIdentifier):
            setSuggestionDecision(outcome.decisionText ?? "Running: app proof already in progress")
            DiagnosticsLog.shared.record(
                "app-proof-command-skipped",
                metadata: [
                    "app": bundleIdentifier,
                    "reason": "already-running"
                ]
            )
            refreshRuntimeChrome()
            showDiagnostics()
        case let .failedToStart(bundleIdentifier, logURL, reason):
            setSuggestionDecision(outcome.decisionText ?? "Blocked: proof command failed to start")
            DiagnosticsLog.shared.record(
                "app-proof-command-failed",
                metadata: [
                    "app": bundleIdentifier,
                    "reason": reason,
                    "log": logURL?.path ?? ""
                ]
            )
            refreshRuntimeChrome()
            showDiagnostics()
        }
    }

    private func beginAppProofMode(for bundleIdentifier: String) {
        activeAppProofBundleIdentifiers.insert(bundleIdentifier)
        appProofExpirationTasks[bundleIdentifier]?.cancel()
        appProofExpirationTasks[bundleIdentifier] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10 * 60 * 1_000_000_000)
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self?.endAppProofMode(for: bundleIdentifier, reason: "expired")
            }
        }
        DiagnosticsLog.shared.record(
            "app-proof-mode-started",
            metadata: [
                "app": bundleIdentifier
            ]
        )
    }

    private func endAppProofMode(for bundleIdentifier: String, reason: String) {
        appProofExpirationTasks[bundleIdentifier]?.cancel()
        appProofExpirationTasks.removeValue(forKey: bundleIdentifier)
        guard activeAppProofBundleIdentifiers.remove(bundleIdentifier) != nil else {
            return
        }

        DiagnosticsLog.shared.record(
            "app-proof-mode-ended",
            metadata: [
                "app": bundleIdentifier,
                "reason": reason
            ]
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
        markAppEnablementSetupCompleted()
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
    private func silenceCurrentField() {
        guard let target = fieldControlTarget else {
            setSuggestionDecision("Blocked: no current field")
            refreshRuntimeChrome()
            DiagnosticsLog.shared.record(
                "field-control",
                metadata: [
                    "action": "silence",
                    "outcome": "no-field"
                ]
            )
            return
        }

        suppressedFieldIdentities.insert(target.fieldIdentity)
        let suggestionID = currentSuggestionID ?? ""
        setSuggestionDecision("Blocked: current field silenced")
        invalidatePendingSuggestionRequest()
        if suggestionSession.hasVisibleSuggestion {
            hideSuggestion(reason: "field-silenced")
        }

        let context = annoyanceContext(
            appBundleIdentifier: target.appBundleIdentifier,
            fieldIdentity: target.fieldIdentity,
            requestMode: target.requestMode,
            fieldKind: target.fieldKind
        )
        RawAutocompleteTraceLog.shared.record(
            type: .fieldPaused,
            suggestionID: suggestionID,
            appBundleIdentifier: target.appBundleIdentifier,
            fieldIdentity: target.fieldIdentity.traceDescription,
            requestMode: target.requestMode?.rawValue ?? "",
            reason: "manual-field",
            metadata: [
                "scope": "field"
            ]
        )
        recordAnnoyanceSignal(
            .manualPause,
            context: context,
            suggestionID: suggestionID,
            reason: "manual-field",
            metadata: [
                "scope": "field"
            ]
        )
        DiagnosticsLog.shared.record(
            "field-control",
            metadata: [
                "action": "silence",
                "app": target.appBundleIdentifier,
                "field": target.fieldIdentity.traceDescription
            ]
        )
        refreshRuntimeChrome()
        updateStatusMenu(
            app: targetAppForControls(),
            profile: profileStore.profile(for: target.appBundleIdentifier),
            appEnabled: !disabledBundleIdentifiers.contains(target.appBundleIdentifier)
        )
    }

    @objc
    private func togglePauseSuggestions() {
        let transition = suggestionControlPolicy.toggle(suggestionControlState)
        suggestionsPaused = transition.nextState.isPaused
        suggestionsPausedUntil = nil
        pauseExpirationTask?.cancel()
        pauseExpirationTask = nil

        setSuggestionDecision(transition.decisionText)

        let cleanupReason = transition.cleanupReason?.hideReason
        if suggestionsPaused {
            let context = currentAnnoyanceContext()
            RawAutocompleteTraceLog.shared.record(
                type: .appPaused,
                suggestionID: currentSuggestionID ?? "",
                appBundleIdentifier: context?.appBundleIdentifier ?? currentProfile?.bundleIdentifier ?? "",
                fieldIdentity: context?.fieldIdentifier ?? "",
                requestMode: context?.requestMode?.rawValue ?? "",
                reason: "manual"
            )
            recordAnnoyanceSignal(
                .manualPause,
                context: context,
                suggestionID: currentSuggestionID ?? "",
                reason: "manual"
            )
        }

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
    private func pauseSuggestionsFor15Minutes() {
        pauseSuggestions(for: 15 * 60, label: "15 minutes")
    }

    @objc
    private func pauseSuggestionsFor1Hour() {
        pauseSuggestions(for: 60 * 60, label: "1 hour")
    }

    private func pauseSuggestions(for durationSeconds: TimeInterval, label: String) {
        let state = suggestionPauseSchedulePolicy.timedPause(
            now: Date(),
            durationSeconds: durationSeconds
        )
        suggestionsPaused = state.isPaused
        suggestionsPausedUntil = state.pausedUntil
        setSuggestionDecision("Paused for \(label)")
        clearFocusedFieldState(hideReason: "timed-pause")
        stopKeyboardEventTapNow(reason: "timed-pause")
        persistPauseState()
        schedulePauseExpiration()
        DiagnosticsLog.shared.record(
            "suggestions-control",
            metadata: [
                "paused": String(suggestionsPaused),
                "durationSeconds": String(Int(durationSeconds)),
                "pausedUntil": suggestionsPausedUntil.map { ISO8601DateFormatter().string(from: $0) } ?? ""
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

private extension AppDelegate {
    static var disabledAppsDefaultsKey: String {
        "DisabledBundleIdentifiers"
    }

    static var suggestionsPausedDefaultsKey: String {
        "SuggestionsPaused"
    }

    static var suggestionsPausedUntilDefaultsKey: String {
        "SuggestionsPausedUntil"
    }

    static var appEnablementSetupCompletedDefaultsKey: String {
        "AppEnablementSetupCompleted"
    }

    static var acceptAllShortcutDefaultsKey: String {
        "AcceptAllShortcut"
    }

    static var suggestionAggressivenessDefaultsKey: String {
        "SuggestionAggressiveness"
    }

    static var temporarilyEnabledBundleIDsEnvironmentKey: String {
        "AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS"
    }

    static var proofModeBundleIDsEnvironmentKey: String {
        "AUTOCOMPLETE_LAB_PROOF_MODE_BUNDLE_IDS"
    }

    static var acceptedAndKeptLearningDefaultsKey: String {
        "AcceptedAndKeptLearning"
    }

    static var acceptedTextStyleMemoryDefaultsKey: String {
        "AcceptedTextStyleMemory"
    }

    func loadPauseState() {
        let defaults = UserDefaults.standard
        let pausedUntilValue = defaults.double(forKey: Self.suggestionsPausedUntilDefaultsKey)
        let pausedUntil = pausedUntilValue > 0 ? Date(timeIntervalSince1970: pausedUntilValue) : nil
        let state = suggestionPauseSchedulePolicy.normalizedState(
            isPaused: defaults.bool(forKey: Self.suggestionsPausedDefaultsKey),
            pausedUntil: pausedUntil,
            now: Date()
        )
        suggestionsPaused = state.isPaused
        suggestionsPausedUntil = state.pausedUntil
        persistPauseState()
        schedulePauseExpiration()
    }

    func persistPauseState() {
        let defaults = UserDefaults.standard
        defaults.set(suggestionsPaused, forKey: Self.suggestionsPausedDefaultsKey)
        if let suggestionsPausedUntil {
            defaults.set(
                suggestionsPausedUntil.timeIntervalSince1970,
                forKey: Self.suggestionsPausedUntilDefaultsKey
            )
        } else {
            defaults.removeObject(forKey: Self.suggestionsPausedUntilDefaultsKey)
        }
    }

    func expireTimedPauseIfNeeded(now: Date) {
        let state = suggestionPauseSchedulePolicy.normalizedState(
            isPaused: suggestionsPaused,
            pausedUntil: suggestionsPausedUntil,
            now: now
        )
        guard state.isPaused != suggestionsPaused || state.pausedUntil != suggestionsPausedUntil else {
            return
        }

        suggestionsPaused = state.isPaused
        suggestionsPausedUntil = state.pausedUntil
        persistPauseState()
        if !suggestionsPaused {
            pauseExpirationTask?.cancel()
            pauseExpirationTask = nil
            setSuggestionDecision("Ready: timed pause ended")
            refreshRuntimeChrome()
        }
    }

    func schedulePauseExpiration() {
        pauseExpirationTask?.cancel()
        pauseExpirationTask = nil

        guard suggestionsPaused,
              let suggestionsPausedUntil else {
            return
        }

        let delay = max(0, suggestionsPausedUntil.timeIntervalSinceNow)
        pauseExpirationTask = Task { [weak self, suggestionsPausedUntil] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await MainActor.run {
                self?.expireTimedPauseIfNeeded(now: suggestionsPausedUntil)
            }
        }
    }

    func loadDisabledApps() {
        let defaults = UserDefaults.standard
        let disabledAppsKeyExists = defaults.object(forKey: Self.disabledAppsDefaultsKey) != nil
        let setupKeyExists = defaults.object(forKey: Self.appEnablementSetupCompletedDefaultsKey) != nil
        let temporarilyEnabledBundleIDs = ProcessInfo.processInfo.environment[
            Self.temporarilyEnabledBundleIDsEnvironmentKey
        ]

        if disabledAppsKeyExists {
            let persisted = defaults.stringArray(forKey: Self.disabledAppsDefaultsKey) ?? []
            var selection = DisabledAppSelection(
                persistedBundleIdentifiers: persisted
            )
            selection.temporarilyEnable(bundleIdentifiers: temporarilyEnabledBundleIDs)
            disabledBundleIdentifiers = selection.bundleIdentifiers
            appEnablementSetupCompleted = setupKeyExists
                ? defaults.bool(forKey: Self.appEnablementSetupCompletedDefaultsKey)
                : true
            defaults.set(appEnablementSetupCompleted, forKey: Self.appEnablementSetupCompletedDefaultsKey)
            return
        }

        var defaultOffSelection = DisabledAppSelection(
            defaultOffProfileStore: profileStore
        )
        disabledBundleIdentifiers = defaultOffSelection.bundleIdentifiers
        appEnablementSetupCompleted = false
        defaults.set(false, forKey: Self.appEnablementSetupCompletedDefaultsKey)
        persistDisabledApps()

        defaultOffSelection.temporarilyEnable(bundleIdentifiers: temporarilyEnabledBundleIDs)
        disabledBundleIdentifiers = defaultOffSelection.bundleIdentifiers
    }

    func loadProofModeOverrides() {
        let environment = ProcessInfo.processInfo.environment
        let proofBundleIdentifiers = Set(
            DisabledAppSelection.parseBundleIdentifierList(environment[Self.temporarilyEnabledBundleIDsEnvironmentKey])
                + DisabledAppSelection.parseBundleIdentifierList(environment[Self.proofModeBundleIDsEnvironmentKey])
        )
        guard !proofBundleIdentifiers.isEmpty else {
            return
        }

        for bundleIdentifier in proofBundleIdentifiers.sorted() {
            beginAppProofMode(for: bundleIdentifier)
        }
        DiagnosticsLog.shared.record(
            "app-proof-mode-env",
            metadata: [
                "apps": proofBundleIdentifiers.sorted().joined(separator: ",")
            ]
        )
    }

    func persistDisabledApps() {
        let selection = DisabledAppSelection(bundleIdentifiers: disabledBundleIdentifiers)
        UserDefaults.standard.set(
            selection.persistedBundleIdentifiers,
            forKey: Self.disabledAppsDefaultsKey
        )
    }

    func markAppEnablementSetupCompleted() {
        guard !appEnablementSetupCompleted else {
            return
        }

        appEnablementSetupCompleted = true
        UserDefaults.standard.set(true, forKey: Self.appEnablementSetupCompletedDefaultsKey)
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

    func loadSuggestionAggressiveness() {
        suggestionAggressiveness = SuggestionAggressiveness.parsed(
            UserDefaults.standard.string(forKey: Self.suggestionAggressivenessDefaultsKey)
        )
    }

    func persistSuggestionAggressiveness() {
        UserDefaults.standard.set(
            suggestionAggressiveness.rawValue,
            forKey: Self.suggestionAggressivenessDefaultsKey
        )
    }

    func loadAcceptedAndKeptLearning() {
        guard let data = UserDefaults.standard.data(forKey: Self.acceptedAndKeptLearningDefaultsKey),
              let store = AcceptedAndKeptLearningStore(jsonData: data) else {
            acceptedAndKeptLearning = AcceptedAndKeptLearningStore()
            return
        }

        acceptedAndKeptLearning = store
    }

    func persistAcceptedAndKeptLearning() {
        guard let data = acceptedAndKeptLearning.jsonData() else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: Self.acceptedAndKeptLearningDefaultsKey
        )
    }

    func loadAcceptedTextStyleMemory() {
        guard let data = UserDefaults.standard.data(forKey: Self.acceptedTextStyleMemoryDefaultsKey),
              let store = AcceptedTextStyleMemoryStore(jsonData: data) else {
            acceptedTextStyleMemory = AcceptedTextStyleMemoryStore()
            return
        }

        acceptedTextStyleMemory = store
    }

    func persistAcceptedTextStyleMemory() {
        guard let data = acceptedTextStyleMemory.jsonData() else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: Self.acceptedTextStyleMemoryDefaultsKey
        )
    }
}

    private struct InsertionVerificationBaseline: Equatable {
        let fieldIdentity: FocusedFieldIdentity
        let previousTextBeforeCursor: String
        let previousTextAfterCursor: String
        let profile: CompatibilityProfile
    let suggestionID: String?
    let requestMode: CompletionRequestMode?
    let acceptanceID: String
    let acceptedAt: Date
    let acceptMode: String
    let fieldKind: AXFieldKind
    let fieldKindReason: String
    let behaviorProfileID: AutocompleteBehaviorProfileID
    let retryCount: Int
}

private enum FocusedInsertionVerificationContext {
    case ready(context: FocusedTextContext)
    case missingContext
    case fieldChanged

    var failureOutcome: String? {
        switch self {
        case .ready:
            return nil
        case .missingContext:
            return "missingContext"
        case .fieldChanged:
            return "fieldChanged"
        }
    }

    var failureReason: String? {
        switch self {
        case .ready:
            return nil
        case .missingContext:
            return "insert-verification-missing-context"
        case .fieldChanged:
            return "insert-verification-field-changed"
        }
    }
}

private struct AcceptedInsertionUndo: Equatable {
    let acceptanceID: String
    let appBundleIdentifier: String
    let fieldIdentity: FocusedFieldIdentity
    let textBeforeCursor: String
    let textAfterCursor: String
    let acceptedTextLength: Int
    let acceptedAt: Date
    let expiresAt: Date
}

private struct FieldControlTarget: Equatable {
    let appBundleIdentifier: String
    let appDisplayName: String
    let fieldIdentity: FocusedFieldIdentity
    let requestMode: CompletionRequestMode?
    let fieldKind: AXFieldKind
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
