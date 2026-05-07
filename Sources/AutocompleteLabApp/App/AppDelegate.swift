import AppKit
import AutocompleteLabCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let accessibilityClient = AccessibilityClient()
    private let profileStore = CompatibilityProfileStore.mvp
    private let promptEditorPolicy = PromptEditorFingerprintPolicy()
    private let suggestionControlPolicy = SuggestionControlPolicy()
    private let activationPolicy = CompletionActivationPolicy()
    private let triggerPolicy = SuggestionTriggerPolicy(
        charactersBeforePauseRequest: 1,
        wordCompletionDelayMilliseconds: 0,
        wordBoundaryDelayMilliseconds: 0,
        pauseDelayMilliseconds: 15
    )
    private let runtimeLifecycle = AppRuntimeLifecycleController()
    private var completionLengthConfiguration: CompletionLengthConfiguration {
        runtimeLifecycle.completionLengthConfiguration
    }
    private var engine: any CompletionEngine {
        runtimeLifecycle.engine
    }
    private lazy var insertionEngine = InsertionEngine(accessibilityClient: accessibilityClient)
    private let keyboardCapturePolicy = KeyboardCapturePolicy()
    private let insertionVerification = InsertionVerification()
    private let insertionRetryPolicy = InsertionRetryPolicy()
    private let wordCompletionRanker = WordCompletionCandidateRanker()
    private let suggestionTypingProgressPolicy = SuggestionTypingProgressPolicy()
    private let suggestionPresentationGate = SuggestionPresentationGate()
    private let suggestionPresentationPolicy = SuggestionPresentationPolicy()
    private var traceScreenshotCapture = TraceScreenshotCaptureCoordinator()
    private var suggestionDiagnostics = SuggestionDiagnosticsRecorder()
    private let focusedTextUpdateSourcePolicy = FocusedTextUpdateSourcePolicy()
    private let focusedTextPollingCadencePolicy = FocusPollingCadencePolicy()
    private let focusedTextPollingBackoffPolicy = FocusedTextPollingBackoffPolicy.typingBackoff
    private let focusedTextAXHealthPolicy = FocusedTextAXHealthPolicy.typingResponsiveness
    private let recentWordExtractor = RecentWordExtractor()
    private let compatibilityLearningStore = CompatibilityLearningStore.shared
    private lazy var compatibilityLearningActions = CompatibilityLearningActions(
        store: compatibilityLearningStore,
        profileStore: profileStore
    )
    private lazy var privacyControls = LocalPrivacyControls(
        traceLog: RawAutocompleteTraceLog.shared,
        compatibilityLearningStore: compatibilityLearningStore
    )
    private let visibleSuggestionPanel = VisibleSuggestionPanelPresenter()
    private lazy var focusedTextReader = SerialFocusedTextAXReader(accessibilityClient: accessibilityClient)
    private lazy var accessibilityObserver = AccessibilityObserver(
        eventHandler: { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleAccessibilityObserverEvent(event)
            }
        },
        registrationFailureHandler: { failure in
            DiagnosticsLog.shared.record(
                "accessibility-observer-registration-failed",
                metadata: failure.metadata
            )
        }
    )
    private let accessibilityObserverCoordinator = AccessibilityObserverCoordinator()
    private let diagnosticsWindow = DiagnosticsWindowController()
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
        performRuntimeAction: { [weak self] action in
            self?.performRuntimeAction(action)
        },
        toggleCurrentApp: { [weak self] in
            self?.toggleCurrentApp()
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
        cycleAcceptAllShortcut: { [weak self] in
            self?.cycleAcceptAllShortcut()
        }
    )

    private var statusItem: NSStatusItem?
    private var statusMenuItem: NSMenuItem?
    private var runtimeMenuItem: NSMenuItem?
    private var pauseSuggestionsMenuItem: NSMenuItem?
    private var toggleAppMenuItem: NSMenuItem?
    private var pollTimer: Timer?
    private var keyboardEventTap: KeyboardEventTap?
    private var keyboardEventTapStopTask: Task<Void, Never>?
    private var suggestionSession = SuggestionSession()
    private var currentFieldIdentity: FocusedFieldIdentity?
    private var currentProfile: CompatibilityProfile?
    private var lastTextSnapshot: FocusedTextSnapshot?
    private var lastRequestedTextBeforeCursor: String?
    private var suppressedFieldIdentities: Set<FocusedFieldIdentity> = []
    private var disabledBundleIdentifiers: Set<String> = []
    private var debounceTask: Task<Void, Never>?
    private var insertionVerificationTask: Task<Void, Never>?
    private let focusedFieldIdentityPolicy = FocusedFieldIdentityPolicy()
    private var isFocusedTextPollInFlight = false
    private var latestFocusedTextReadRequestID: UInt64?
    private var pendingFocusedTextUpdateSource: FocusedTextUpdateSource?
    private var nextScheduledFocusedTextPollAt = Date.distantPast
    private var focusedTextAXHealthState = FocusedTextAXHealthState()
    private var focusedTextPollLatencyStats = FocusedTextPollLatencyStats()
    private var focusedTextPollSkipStats = FocusedTextPollSkipStats()
    private var suggestionRequestGate = SuggestionRequestGate()
    private var suggestionRepetitionSuppressor = SuggestionRepetitionSuppressor()
    private var currentCompletionRequest: CompletionRequest?
    private var streamingPresentationStates: [String: StreamingPresentationState] = [:]
    private var currentSuggestionID: String?
    private var currentSuggestionAppBundleIdentifier: String?
    private var currentSuggestionFieldIdentity: FocusedFieldIdentity?
    private var currentSuggestionRequestMode: CompletionRequestMode?
    private var currentSuggestionTextBeforeCursor: String?
    private var currentSuggestionDisplayedText: String?
    private var currentSuggestionInvalidatedByUserKeyDown = false
    private var recentWordMemory = ScopedRecentWordMemory()
    private var suppressKeyUntil: [AutocompleteKey: Date] = [:]
    private var lastStatusLine: String?
    private var lastSuggestionDecision = "Starting"
    private var lastSyntheticCaretDiagnosticSignature: String?
    private var lastEligibleTargetApp: RunningApplicationInfo?
    private var lastObservedSettingsApp: RunningApplicationInfo?
    private let focusedTextPollInterval: TimeInterval = 0.05
    private let keyboardEventTapIdleStopDelayMilliseconds = 700
    private let postTypingPollPauseMilliseconds = 220
    private let postInsertionPollPauseMilliseconds = 220
    private let slowFocusedTextPollLatencyMilliseconds = 80
    private var focusedTextPollingPause = FocusedTextPollingPause()
    private var suggestionsPaused = false
    private var keyboardShortcutConfiguration = KeyboardShortcutConfiguration.default

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("AutocompleteLab runs as a persistent menu bar agent.")
        NSApp.setActivationPolicy(.accessory)
        loadPauseState()
        loadDisabledApps()
        loadKeyboardShortcutConfiguration()
        configureStatusItem()
        DiagnosticsLog.shared.record("launch", metadata: ["accessibility": String(accessibilityClient.isTrusted)])
        DiagnosticsLog.shared.record("runtime-bootstrap", metadata: runtimeLifecycle.bootstrapMetadata)
        accessibilityClient.requestPermissionIfNeeded()
        warmModelRuntime()
        if shouldShowSettingsForCurrentReadiness {
            showSettings()
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(frontmostApplicationDidChange(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        startPolling()
    }

    func applicationWillTerminate(_ notification: Notification) {
        DiagnosticsLog.shared.record("terminate")
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        debounceTask?.cancel()
        keyboardEventTapStopTask?.cancel()
        insertionVerificationTask?.cancel()
        runtimeLifecycle.cancel()
        invalidatePendingSuggestionRequest()
        pollTimer?.invalidate()
        accessibilityObserver.stopTrackingAll()
        stopKeyboardEventTapNow(reason: "terminate")
    }

    @objc private func frontmostApplicationDidChange(_ notification: Notification) {
        guard suggestionSession.hasVisibleSuggestion else {
            return
        }

        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        guard app?.bundleIdentifier != currentSuggestionAppBundleIdentifier else {
            return
        }

        invalidatePendingSuggestionRequest()
        hideSuggestion(reason: "app-blur")
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Autocomplete"

        let menu = NSMenu()
        let statusMenu = NSMenuItem(title: "Status: starting", action: nil, keyEquivalent: "")
        let runtimeMenu = NSMenuItem(title: "Model: starting", action: nil, keyEquivalent: "")
        let pauseItem = NSMenuItem(
            title: suggestionControlState.toggleTitle,
            action: #selector(togglePauseSuggestions),
            keyEquivalent: "p"
        )
        let toggleItem = NSMenuItem(title: "Toggle Current App", action: #selector(toggleCurrentApp), keyEquivalent: "t")
        let debugMenuItem = NSMenuItem(title: "Debug", action: nil, keyEquivalent: "")
        let debugMenu = NSMenu()

        menu.addItem(NSMenuItem(title: "Autocomplete Lab", action: nil, keyEquivalent: ""))
        menu.addItem(statusMenu)
        menu.addItem(runtimeMenu)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(pauseItem)
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
        toggleAppMenuItem = toggleItem
        refreshRuntimeChrome()
    }

    private func startPolling() {
        let timer = Timer.scheduledTimer(withTimeInterval: focusedTextPollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollFocusedTextFromTimer()
            }
        }
        timer.tolerance = focusedTextPollInterval / 2
        pollTimer = timer
    }

    private func pollFocusedTextFromTimer() {
        let updateSource = scheduledFocusedTextUpdateSource()
        let now = Date()
        guard now >= nextScheduledFocusedTextPollAt else {
            return
        }

        nextScheduledFocusedTextPollAt = now.addingTimeInterval(
            focusedTextPollInterval(for: updateSource)
        )
        pollFocusedTextIfIdle(source: updateSource)
    }

    private func warmModelRuntime() {
        runtimeLifecycle.warmModelRuntime(onStateApplied: handleRuntimeStateApplication)
    }

    private func reloadModelRuntime(reason: String) {
        runtimeLifecycle.reloadModelRuntime(
            reason: reason,
            onBootstrap: { metadata in
                DiagnosticsLog.shared.record("runtime-bootstrap", metadata: metadata)
            },
            refreshChrome: refreshRuntimeChrome,
            onStateApplied: handleRuntimeStateApplication
        )
    }

    private func installLocalModel(action: RuntimeReadinessAction) {
        runtimeLifecycle.installLocalModel(
            action: action,
            refreshChrome: refreshRuntimeChrome,
            showSettings: showSettings,
            onBootstrap: { metadata in
                DiagnosticsLog.shared.record("runtime-bootstrap", metadata: metadata)
            },
            onStateApplied: handleRuntimeStateApplication
        )
    }

    private func handleRuntimeStateApplication(_ application: AppRuntimeStateApplication) {
        refreshRuntimeChrome()
        if application.shouldRearmFocusedText {
            rearmFocusedTextAfterRuntimeReady()
        }
        if application.shouldShowSettings {
            showSettings()
        }
        DiagnosticsLog.shared.record(
            "runtime",
            metadata: application.diagnosticsMetadata
        )
    }

    private func rearmFocusedTextAfterRuntimeReady() {
        guard currentFieldIdentity != nil else {
            return
        }

        lastTextSnapshot = nil
        lastRequestedTextBeforeCursor = nil
        invalidatePendingSuggestionRequest()
        suggestionDiagnostics.resetBlockedSuggestionGate()
        setSuggestionDecision("Ready: runtime")
        DiagnosticsLog.shared.record(
            "runtime-ready-rearmed",
            metadata: [
                "reason": "runtime-became-ready"
            ]
        )
    }

    private func refreshRuntimeChrome() {
        runtimeMenuItem?.title = runtimeLifecycle.runtimeMenuTitle
        if settingsWindow.isShowing {
            settingsWindow.refresh(
                isTrusted: accessibilityClient.isTrusted,
                suggestionsPaused: suggestionsPaused,
                runtimeReport: runtimeReadinessReport,
                runtimeTargetSummary: runtimeTargetSummary,
                modelDirectoryPath: modelDirectoryPath,
                currentApp: settingsCurrentAppState,
                privacy: settingsPrivacyState,
                keyboardShortcuts: settingsKeyboardShortcutState,
                lastSuggestionDecision: lastSuggestionDecision
            )
        }
    }

    private var runtimeReadinessReport: RuntimeReadinessReport {
        runtimeLifecycle.readinessReport
    }

    private var modelDirectoryPath: String {
        runtimeLifecycle.modelDirectoryPath
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
            disabledAppCount: disabledBundleIdentifiers.count
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
        privacyControls.settingsPrivacyState(diagnosticsPath: DiagnosticsLog.shared.path)
    }

    private var settingsKeyboardShortcutState: SettingsKeyboardShortcutState {
        SettingsKeyboardShortcutState(
            acceptAllShortcut: keyboardShortcutConfiguration.acceptAllShortcut
        )
    }

    private var runtimeTargetSummary: String {
        runtimeLifecycle.runtimeTargetSummary
    }

    private var shouldShowSettingsForCurrentReadiness: Bool {
        if !accessibilityClient.isTrusted {
            return true
        }

        switch runtimeReadinessReport.stage {
        case .downloadNeeded, .repairNeeded, .runtimeUnavailable, .failed:
            return true
        case .installing, .warming, .ready:
            return false
        }
    }

    private var suggestionControlState: SuggestionControlState {
        suggestionControlPolicy.state(isPaused: suggestionsPaused)
    }

    private func scheduledFocusedTextUpdateSource() -> FocusedTextUpdateSource {
        let frontmostApp = accessibilityClient.frontmostApplication()
        let profile = frontmostApp.flatMap { profileStore.profile(for: $0.bundleIdentifier) }
        let appEnabled = frontmostApp.map { !disabledBundleIdentifiers.contains($0.bundleIdentifier) } ?? false
        let hasSupportedProfile = profile?.canPresentSuggestions == true
            && profile?.isSensitive == false
            && appEnabled
        let usesObserverUpdates = frontmostApp.map {
            accessibilityObserverCoordinator.usesObserverUpdates(
                profile: profile,
                isTrackingFocusedApp: accessibilityObserver.isTracking(processIdentifier: $0.processIdentifier)
            )
        } ?? false

        return focusedTextUpdateSourcePolicy.pollingSource(
            isTrustedForAccessibility: accessibilityClient.isTrusted,
            hasSupportedProfile: hasSupportedProfile,
            usesObserverUpdates: usesObserverUpdates,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion
        )
    }

    private func focusedTextPollInterval(for updateSource: FocusedTextUpdateSource) -> TimeInterval {
        guard accessibilityClient.isTrusted else {
            return focusedTextPollingCadencePolicy.untrustedIntervalSeconds
        }

        switch updateSource {
        case .observer, .manualRefresh:
            return 0
        case .activePoll:
            return focusedTextPollingCadencePolicy.activeSuggestionIntervalSeconds
        case .watchPoll:
            return focusedTextPollingCadencePolicy.supportedTypingWatchIntervalSeconds
        case .idlePoll:
            return focusedTextPollingCadencePolicy.idleIntervalSeconds
        }
    }

    private func pollFocusedTextIfIdle(source updateSource: FocusedTextUpdateSource) {
        guard !isFocusedTextPollInFlight else {
            pendingFocusedTextUpdateSource = focusedTextUpdateSourcePolicy.coalesced(
                pendingFocusedTextUpdateSource,
                with: updateSource
            )
            if let notice = focusedTextPollSkipStats.recordSkippedInFlight(now: Date()) {
                DiagnosticsLog.shared.record(
                    "focused-text-poll-skipped",
                    metadata: [
                        "reason": "in-flight",
                        "count": String(notice.count),
                        "updateSource": updateSource.rawValue
                    ]
                )
            }
            return
        }

        isFocusedTextPollInFlight = true
        let startedAt = DispatchTime.now().uptimeNanoseconds
        var completesAsync = false
        pollFocusedText(
            startedAt: startedAt,
            completesAsync: &completesAsync,
            updateSource: updateSource
        )
        if !completesAsync {
            finishFocusedTextPoll(startedAt: startedAt)
        }
    }

    private func finishFocusedTextPoll(startedAt: UInt64) {
        let endedAt = DispatchTime.now().uptimeNanoseconds
        let durationMilliseconds = Int((endedAt - startedAt) / 1_000_000)
        let pendingUpdateSource = pendingFocusedTextUpdateSource
        pendingFocusedTextUpdateSource = nil
        isFocusedTextPollInFlight = false
        latestFocusedTextReadRequestID = nil
        recordFocusedTextPollLatency(durationMilliseconds)
        recordFocusedTextPollSkipSummaryIfNeeded()

        if let pendingUpdateSource {
            pollFocusedTextIfIdle(source: pendingUpdateSource)
        }
    }

    private func pollFocusedText(
        startedAt: UInt64,
        completesAsync: inout Bool,
        updateSource: FocusedTextUpdateSource
    ) {
        if case let .blocked(reason) = suggestionControlPolicy.suggestionAvailability(for: suggestionControlState) {
            setSuggestionDecision(reason.decisionText)
            let frontmostApp = accessibilityClient.frontmostApplication()
            updateStatusMenu(
                app: frontmostApp,
                appEnabled: frontmostApp.map { !disabledBundleIdentifiers.contains($0.bundleIdentifier) } ?? false
            )
            hideSuggestion(reason: reason.hideReason)
            return
        }

        guard accessibilityClient.isTrusted else {
            accessibilityObserver.stopTrackingAll()
            setSuggestionDecision("Blocked: Accessibility permission missing")
            updateStatusMenu(app: nil, appEnabled: false)
            hideSuggestion()
            return
        }

        if focusedTextPollingPause.isPaused(now: Date()), !updateSource.bypassesTypingPause {
            setSuggestionDecision("Waiting: typing")
            return
        }

        let activeApp = accessibilityClient.frontmostApplication()
        guard let frontmostApp = activeApp,
              let profile = profileStore.profile(for: frontmostApp.bundleIdentifier) else {
            accessibilityObserver.stopTrackingAll()
            clearFocusedFieldState()
            currentProfile = nil
            setSuggestionDecision("Blocked: unsupported app")
            updateStatusMenu(app: activeApp, appEnabled: false)
            hideSuggestion()
            return
        }

        rememberEligibleTargetApp(frontmostApp)
        let appEnabled = !disabledBundleIdentifiers.contains(frontmostApp.bundleIdentifier)
        currentProfile = profile
        updateStatusMenu(app: frontmostApp, appEnabled: appEnabled)

        guard appEnabled else {
            accessibilityObserver.stopTrackingAll()
            clearFocusedFieldState()
            setSuggestionDecision("Blocked: app disabled")
            hideSuggestion(reason: "app-disabled")
            return
        }

        guard profile.canPresentSuggestions, !profile.isSensitive else {
            accessibilityObserver.stopTrackingAll()
            clearFocusedFieldState()
            setSuggestionDecision(profile.isSensitive ? "Blocked: sensitive app" : "Blocked: profile disabled")
            hideSuggestion(reason: profile.isSensitive ? "sensitive-app" : "profile-disabled")
            return
        }

        guard allowFocusedTextAXRead(for: frontmostApp.bundleIdentifier) else {
            return
        }

        let requestID = focusedTextReader.readFocusedTextContext(
            for: frontmostApp,
            allowDescendantTextFallback: profile.allowsDescendantTextFallback
        ) { [weak self, profile, startedAt, updateSource] result in
            Task { @MainActor [weak self, profile, startedAt, updateSource] in
                self?.completeFocusedTextPoll(
                    result: result,
                    profile: profile,
                    startedAt: startedAt,
                    updateSource: updateSource
                )
            }
        }
        latestFocusedTextReadRequestID = requestID
        completesAsync = true
    }

    private func completeFocusedTextPoll(
        result: FocusedTextAXReadResult,
        profile: CompatibilityProfile,
        startedAt: UInt64,
        updateSource: FocusedTextUpdateSource
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
            accessibilityObserver.stopTrackingAll()
            setSuggestionDecision("Blocked: focus changed")
            hideSuggestion(reason: "focus-changed")
            return
        }

        refreshAccessibilityObserverIfNeeded(for: result.app, profile: profile)

        guard let rawContext = result.context, !rawContext.isSecure else {
            clearFocusedFieldState()
            currentProfile = profile
            setSuggestionDecision("Blocked: no editable text field or secure field")
            hideSuggestion(reason: result.context?.isSecure == true ? "secure-field" : "missing-focused-context")
            return
        }

        processFocusedTextContext(
            rawContext,
            frontmostApp: result.app,
            profile: profile,
            updateSource: updateSource
        )
    }

    private func refreshAccessibilityObserverIfNeeded(
        for app: RunningApplicationInfo,
        profile: CompatibilityProfile
    ) {
        guard accessibilityObserverCoordinator.observationMode(for: profile) == .observeFocusedApp else {
            accessibilityObserver.stopTrackingAll()
            return
        }

        accessibilityObserver.observe(
            app: app,
            focusedElement: accessibilityClient.focusedElementForObserver(for: app.processIdentifier),
            focusedWindow: accessibilityClient.focusedWindowForObserver(for: app.processIdentifier)
        )
    }

    private func handleAccessibilityObserverEvent(_ event: AccessibilityObserverEvent) {
        guard let frontmostApp = accessibilityClient.frontmostApplication() else {
            return
        }

        guard let decision = accessibilityObserverCoordinator.eventDecision(
            for: event,
            frontmostProcessIdentifier: frontmostApp.processIdentifier
        ) else {
            return
        }

        DiagnosticsLog.shared.record(
            "accessibility-observer-event",
            metadata: decision.metadata
        )

        switch decision.action {
        case .reclassifyFocusedContext:
            clearFocusedFieldState(hideReason: "observer-focus-changed")
        case .refreshFocusedGeometry:
            break
        }

        nextScheduledFocusedTextPollAt = Date()
        pollFocusedTextIfIdle(source: .observer)
    }

    private func processFocusedTextContext(
        _ rawContext: FocusedTextContext,
        frontmostApp: RunningApplicationInfo,
        profile: CompatibilityProfile,
        updateSource: FocusedTextUpdateSource
    ) {
        let promptMatch = promptTextAreaMatch(
            for: frontmostApp.bundleIdentifier,
            context: rawContext
        )
        guard promptMatch.canSuggest else {
            clearFocusedFieldState(resetBlockLogGate: false)
            currentProfile = profile
            setSuggestionDecision("Blocked: \(promptMatch.reason)")
            suggestionDiagnostics.recordBlockedSuggestionEvent(
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
            suggestionDiagnostics.recordBlockedSuggestionEvent(
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
            suggestionDiagnostics.recordBlockedSuggestionEvent(
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
            isFieldSuppressed: suppressedFieldIdentities.contains(fieldIdentity)
        )

        guard activationDecision.canSuggest else {
            setSuggestionDecision("Blocked: \(activationDecision.blockReasonDescription)")
            suggestionDiagnostics.recordBlockedSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                metadata: [
                    "reason": activationDecision.blockReasonDescription
                ]
            )
            hideSuggestion(reason: "activation-\(activationDecision.blockReasonDescription)")
            return
        }

        let presentationCapabilities = SuggestionPresentationCapabilities(
            supportsInlineSuggestions: context.capabilities.supportsInlineSuggestions,
            hasElementRect: context.elementRect != nil,
            hasWindowRect: context.windowRect != nil,
            hasCaretRect: context.caretRect != nil
        )
        let baseRenderMode = suggestionPresentationPolicy.baseRenderMode(
            for: profile,
            capabilities: presentationCapabilities
        )

        guard let baseRenderMode else {
            setSuggestionDecision("Blocked: missing inline capabilities")
            suggestionDiagnostics.recordBlockedSuggestionEvent(
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

        if let suppressionReason = suggestionPresentationPolicy.suppressionReason(
            profile: profile,
            renderMode: renderMode,
            capabilities: presentationCapabilities
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
                reason: suppressionReason.rawValue,
                metadata: suggestionDiagnostics.traceGeometryMetadata(
                    context: context,
                    renderMode: renderMode,
                    updateSource: updateSource
                )
            )
            suggestionDiagnostics.recordBlockedSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                metadata: [
                    "reason": suppressionReason.rawValue
                ]
            )
            hideSuggestion()
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
            suggestionDiagnostics.recordSuggestionEvent(
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
        setSuggestionDecision("Queued: \(requestMode.rawValue)")
        scheduleSuggestion(
            context: context,
            profile: profile,
            appBundleIdentifier: frontmostApp.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            renderMode: renderMode,
            delayMilliseconds: delayMilliseconds,
            requestMode: requestMode,
            updateSource: updateSource
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
            canSetSelectedText: context.capabilities.canSetSelectedText,
            canReadVisibleCharacterRange: context.capabilities.canReadVisibleCharacterRange,
            canReadInsertionPointLineNumber: context.capabilities.canReadInsertionPointLineNumber
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
            visibleCharacterRange: context.visibleCharacterRange,
            insertionPointLineNumber: context.insertionPointLineNumber,
            textStyle: context.textStyle,
            isSecure: context.isSecure,
            caretIsSynthetic: true,
            capabilities: capabilities,
            axReadErrors: context.axReadErrors
        )
    }

    private func supportsSyntheticTextAreaCaret(for bundleIdentifier: String) -> Bool {
        PromptEditorFingerprintPolicy.dogfoodBundleIdentifiers.contains(bundleIdentifier)
            || bundleIdentifier == "md.obsidian"
            || bundleIdentifier == "com.google.Chrome"
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

        guard focusedFieldMatchesCurrentSuggestion() else {
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
            guard let acceptedText = suggestionSession.nextWordAcceptance(),
                  insertAcceptedText(acceptedText) else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "insert-failed")
                return false
            }

            suggestionSession.commitNextWordAcceptance(acceptedText)
            recordAcceptedText(acceptedText)
            advanceCurrentSuggestionBaseline(afterAccepting: acceptedText)
            suggestionRepetitionSuppressor.recordAcceptance(
                acceptedText,
                mode: currentSuggestionRequestMode,
                scope: currentSuggestionAppBundleIdentifier ?? currentProfile?.bundleIdentifier ?? ""
            )
            recordRawAcceptance(action: action, acceptedText: acceptedText)
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
            guard let acceptedText = suggestionSession.allVisibleAcceptance(),
                  insertAcceptedText(acceptedText) else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "insert-failed")
                return false
            }

            suggestionSession.commitAllVisibleAcceptance(acceptedText)
            recordAcceptedText(acceptedText)
            suggestionRepetitionSuppressor.recordAcceptance(
                acceptedText,
                mode: currentSuggestionRequestMode,
                scope: currentSuggestionAppBundleIdentifier ?? currentProfile?.bundleIdentifier ?? ""
            )
            recordRawAcceptance(action: action, acceptedText: acceptedText)
            setSuggestionDecision("Accepted: full suggestion")
            hideSuggestion(reason: "accepted-all")
            scheduleInsertionVerification(acceptedText: acceptedText, baseline: verificationBaseline)
            suppressKey(key)
            recordKeyboardAction(key: key, action: action, handled: true, reason: "accepted")
            return true

        case .dismiss:
            suppressCurrentField(reason: "escape")
            hideSuggestion(reason: "escape")
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

    private func focusedFieldMatchesCurrentSuggestion() -> Bool {
        guard let currentSuggestionAppBundleIdentifier,
              let currentSuggestionFieldIdentity,
              let frontmostApp = accessibilityClient.frontmostApplication(),
              frontmostApp.bundleIdentifier == currentSuggestionAppBundleIdentifier,
              let profile = profileStore.profile(for: frontmostApp.bundleIdentifier),
              let rawContext = accessibilityClient.focusedTextContext(
                  allowDescendantTextFallback: profile.allowsDescendantTextFallback
              ),
              !rawContext.isSecure,
              rawContext.selectedTextLength == 0,
              promptTextAreaMatch(
                  for: frontmostApp.bundleIdentifier,
                  context: rawContext
              ).canSuggest else {
            return false
        }

        let context = presentationAdjustedContext(rawContext, app: frontmostApp, profile: profile)
        return fieldIdentity(
            app: frontmostApp,
            context: context,
            profile: profile
        ) == currentSuggestionFieldIdentity
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
        }
    }

    private func scheduleSuggestion(
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity,
        renderMode: SuggestionRenderMode,
        delayMilliseconds: Int,
        requestMode: CompletionRequestMode,
        updateSource: FocusedTextUpdateSource
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
        let updateSourceMetadata = suggestionDiagnostics.traceUpdateSourceMetadata(updateSource)

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
            .merging(updateSourceMetadata) { current, _ in current }
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
                        .merging(updateSourceMetadata) { current, _ in current }
                    )
                    suggestionDiagnostics.recordSuggestionEvent(
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
                    triggerReason: "fast-word-completion",
                    updateSource: updateSource
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
                .merging(updateSourceMetadata) { current, _ in current }
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
                                triggerReason: "model-stream",
                                updateSource: updateSource
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
                            reason: "empty-suggestion",
                            metadata: updateSourceMetadata
                        )
                        self.suggestionDiagnostics.recordSuggestionEvent(
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
                            metadata: updateSourceMetadata
                        )
                        self.suggestionDiagnostics.recordSuggestionEvent(
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
                        latencyMilliseconds: latencyMilliseconds,
                        metadata: updateSourceMetadata
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
                            metadata: updateSourceMetadata
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
                        updateSource: updateSource
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
        triggerReason: String,
        updateSource: FocusedTextUpdateSource
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
                metadata: suggestionDiagnostics.traceGeometryMetadata(
                    context: originalContext,
                    renderMode: renderMode,
                    updateSource: updateSource
                )
            )
            suggestionDiagnostics.recordSuggestionEvent(
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

        let storedLearningAdjustment = compatibilityLearningStore.engine().adjustment(
            for: profile.bundleIdentifier,
            profileRenderMode: renderMode
        )
        let learningAdjustment = supportsSyntheticTextAreaCaret(for: profile.bundleIdentifier)
            ? storedLearningAdjustment.trustedVisualOffsetOnly
            : storedLearningAdjustment
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
                metadata: suggestionDiagnostics.traceGeometryMetadata(
                    context: context,
                    renderMode: learningAdjustment.effectiveRenderMode,
                    updateSource: updateSource
                )
                    .merging(learningAdjustment.metadata) { current, _ in current }
                    .merging(suppression.metadata) { current, _ in current }
            )
            suggestionDiagnostics.recordSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                metadata: [
                    "reason": suppression.reason.rawValue
                ]
                .merging(learningAdjustment.metadata) { current, _ in current }
                .merging(suppression.metadata) { current, _ in current }
            )
            hideSuggestion(reason: "placement-\(suppression.reason.rawValue)")
            return
        }

        guard let panelPresentation = visibleSuggestionPanel.show(
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
                metadata: suggestionDiagnostics.traceGeometryMetadata(
                    context: context,
                    renderMode: placement.renderMode,
                    updateSource: updateSource
                )
                    .merging(learningAdjustment.metadata) { current, _ in current }
                    .merging(placement.metadata) { current, _ in current }
            )
            suggestionDiagnostics.recordSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                metadata: [
                    "reason": reason
                ]
                .merging(learningAdjustment.metadata) { current, _ in current }
                .merging(placement.metadata) { current, _ in current }
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
        currentSuggestionInvalidatedByUserKeyDown = false
        keyboardEventTap?.resetPassthroughObservation()
        updateKeyboardEventTapSnapshot()
        guard startKeyboardEventTapIfPossible() else {
            setSuggestionDecision("Blocked: keyboard capture unavailable")
            hideSuggestion(reason: "keyboard-capture-unavailable")
            return
        }

        let screenshotCapture = traceScreenshotCapture.capture(
            around: [
                placement.anchorRect,
                placement.textLineRect,
                panelPresentation.accessibilityFrame,
                placement.clippingRect
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
                "effectiveRenderMode": placement.renderMode.rawValue,
                "visibleChars": String(suggestion.visibleText.count),
                "visibleWords": String(suggestion.visibleWordCount),
                "anchorRect": compactRectDescription(placement.anchorRect),
                "textLineRect": placement.textLineRect.map(compactRectDescription) ?? "none",
                "suggestionPanelRect": compactRectDescription(panelPresentation.accessibilityFrame),
                "clippingRect": placement.clippingRect.map(compactRectDescription) ?? "none",
                "screenshotCaptureRect": screenshotCapture.rectDescription
            ]
            .merging(suggestionDiagnostics.traceGeometryMetadata(
                context: context,
                renderMode: placement.renderMode,
                updateSource: updateSource
            )) { current, _ in current }
            .merging(learningAdjustment.metadata) { current, _ in current }
            .merging(placement.metadata) { current, _ in current }
            .merging(panelPresentation.traceMetadata) { current, _ in current }
        )
        suggestionDiagnostics.recordSuggestionEvent(
            "suggestion-presented",
            context: context,
            profile: profile,
            metadata: [
                "effectiveRenderMode": placement.renderMode.rawValue,
                "requestMode": request.mode.rawValue,
                "traceID": String(suggestionID.prefix(8)),
                "visibleChars": String(suggestion.visibleText.count),
                "visibleWords": String(suggestion.visibleWordCount),
                "suggestionID": suggestionID,
                "latencyMilliseconds": String(latencyMilliseconds),
                "anchorRect": compactRectDescription(placement.anchorRect),
                "textLineRect": placement.textLineRect.map(compactRectDescription) ?? "none",
                "suggestionPanelRect": compactRectDescription(panelPresentation.accessibilityFrame),
                "clippingRect": placement.clippingRect.map(compactRectDescription) ?? "none",
                "screenshotCaptureRect": screenshotCapture.rectDescription
            ]
            .merging(learningAdjustment.metadata) { current, _ in current }
            .merging(placement.metadata) { current, _ in current }
            .merging(panelPresentation.traceMetadata) { current, _ in current }
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
        let hasTrustedVisualAdjustment = learningAdjustment.profile?.hasTrustedVisualAdjustment == true
        let isGreenProfile = profile.supportLevel == .green

        return PlacementTrustPolicy(
            allowsLowConfidencePlacement: isGreenProfile || hasTrustedVisualAdjustment,
            allowsSyntheticCaretPlacement: isGreenProfile || hasTrustedVisualAdjustment
        )
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

    private func recordRawAcceptance(action: KeyboardAction, acceptedText: String) {
        guard let appBundleIdentifier = currentSuggestionAppBundleIdentifier ?? currentProfile?.bundleIdentifier else {
            return
        }

        RawAutocompleteTraceLog.shared.recordAcceptance(
            action: action.diagnosticName,
            appBundleIdentifier: appBundleIdentifier,
            acceptedText: acceptedText,
            remainingVisibleText: suggestionSession.visibleSuggestion?.visibleText,
            suggestionID: currentSuggestionID ?? "",
            fieldIdentity: currentSuggestionFieldIdentity?.traceDescription
                ?? currentFieldIdentity?.traceDescription
                ?? "",
            requestMode: currentSuggestionRequestMode?.rawValue ?? ""
        )
    }

    private func refreshVisibleSuggestion() {
        guard let suggestion = suggestionSession.visibleSuggestion else {
            hideSuggestion()
            return
        }

        currentSuggestionDisplayedText = suggestion.visibleText
        switch visibleSuggestionPanel.refresh(text: suggestion.visibleText) {
        case .presented:
            updateKeyboardEventTapSnapshot()
        case .missingPlacement:
            hideSuggestion()
        case .panelFrameUnusable:
            hideSuggestion(reason: "panel-frame-unusable")
        }
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
        let learningAdjustment = supportsSyntheticTextAreaCaret(for: profile.bundleIdentifier)
            ? storedLearningAdjustment.trustedVisualOffsetOnly
            : storedLearningAdjustment
        let placementPlan = placementHealthPlan(
            context: context,
            profile: profile,
            learningAdjustment: learningAdjustment
        )

        guard case let .present(placement) = placementPlan else {
            if case let .suppress(suppression) = placementPlan {
                suggestionDiagnostics.recordSuggestionEvent(
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

        visibleSuggestionPanel.updatePlacement(
            anchorRect: placement.anchorRect,
            textLineRect: placement.textLineRect,
            clippingRect: placement.clippingRect,
            style: context.textStyle,
            renderMode: placement.renderMode
        )
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
            hideSuggestion(reason: "typed-over")
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
        currentSuggestionRequestMode = nil
        currentSuggestionTextBeforeCursor = nil
        currentSuggestionDisplayedText = nil
        currentSuggestionInvalidatedByUserKeyDown = false
        streamingPresentationStates.removeAll(keepingCapacity: true)
        visibleSuggestionPanel.hide()
        updateKeyboardEventTapSnapshot()
        scheduleKeyboardEventTapStopIfIdle()
    }

    private func updateStatusMenu(
        app: RunningApplicationInfo?,
        appEnabled: Bool
    ) {
        if let app,
           app.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastObservedSettingsApp = app
        }

        let supportStatus = app.map { profileStore.supportStatus(for: $0.bundleIdentifier) } ?? .unsupported
        let statusState = StatusMenuStateBuilder.make(
            isTrustedForAccessibility: accessibilityClient.isTrusted,
            controlState: suggestionControlState,
            appDisplayName: app?.localizedName,
            appBundleIdentifier: app?.bundleIdentifier,
            supportStatus: supportStatus,
            appEnabled: appEnabled,
            disabledAppCount: disabledBundleIdentifiers.count,
            lastSuggestionDecision: lastSuggestionDecision
        )

        statusMenuItem?.title = statusState.title
        statusMenuItem?.toolTip = statusState.tooltip
        pauseSuggestionsMenuItem?.title = statusState.pauseTitle
        toggleAppMenuItem?.title = statusState.toggleTitle
        toggleAppMenuItem?.isEnabled = statusState.toggleEnabled
        if settingsWindow.isShowing {
            settingsWindow.refresh(
                isTrusted: accessibilityClient.isTrusted,
                suggestionsPaused: suggestionsPaused,
                runtimeReport: runtimeReadinessReport,
                runtimeTargetSummary: runtimeTargetSummary,
                modelDirectoryPath: modelDirectoryPath,
                currentApp: settingsCurrentAppState,
                privacy: settingsPrivacyState,
                keyboardShortcuts: settingsKeyboardShortcutState,
                lastSuggestionDecision: lastSuggestionDecision
            )
        }

        guard lastStatusLine != statusState.diagnosticsSignature else {
            return
        }

        lastStatusLine = statusState.diagnosticsSignature
        DiagnosticsLog.shared.record(
            "status",
            metadata: statusState.diagnosticsMetadata
        )
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
        }

        currentFieldIdentity = fieldIdentity
        lastTextSnapshot = nil
        lastRequestedTextBeforeCursor = nil
        suggestionDiagnostics.resetBlockedSuggestionGate()
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
        }

        currentFieldIdentity = nil
        lastTextSnapshot = nil
        lastRequestedTextBeforeCursor = nil
        if resetBlockLogGate {
            suggestionDiagnostics.resetBlockedSuggestionGate()
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
            runtimeReport: runtimeReadinessReport,
            runtimeTargetSummary: runtimeTargetSummary,
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
    private func showSettings() {
        settingsWindow.show(
            isTrusted: accessibilityClient.isTrusted,
            suggestionsPaused: suggestionsPaused,
            runtimeReport: runtimeReadinessReport,
            runtimeTargetSummary: runtimeTargetSummary,
            modelDirectoryPath: modelDirectoryPath,
            currentApp: settingsCurrentAppState,
            privacy: settingsPrivacyState,
            keyboardShortcuts: settingsKeyboardShortcutState,
            lastSuggestionDecision: lastSuggestionDecision
        )
    }

    @objc
    private func revealModelFolder() {
        do {
            try FileManager.default.createDirectory(
                at: runtimeLifecycle.modelDirectoryURL,
                withIntermediateDirectories: true
            )
            NSWorkspace.shared.activateFileViewerSelecting([runtimeLifecycle.modelDirectoryURL])
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

    private func performRuntimeAction(_ action: RuntimeReadinessAction) {
        switch action {
        case .installLocalModel, .repairLocalModel:
            installLocalModel(action: action)
        case .revealModelFolder:
            revealModelFolder()
        case .retry:
            reloadModelRuntime(reason: "manual retry")
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
        let result = privacyControls.toggleTracePause()
        DiagnosticsLog.shared.record(result.eventName, metadata: result.metadata)
        showDiagnostics()
    }

    private func toggleSettingsTracingPaused() {
        let result = privacyControls.toggleTracePause(surface: "settings")
        DiagnosticsLog.shared.record(result.eventName, metadata: result.metadata)
        refreshRuntimeChrome()
    }

    private func toggleRawContentTracing() {
        let result = privacyControls.toggleRawContentTracing(surface: "settings")
        DiagnosticsLog.shared.record(result.eventName, metadata: result.metadata)
        refreshRuntimeChrome()
    }

    private func toggleGlobalScreenshotTracing() {
        let result = privacyControls.toggleScreenshotTracing(surface: "settings")
        DiagnosticsLog.shared.record(result.eventName, metadata: result.metadata)
        refreshRuntimeChrome()
    }

    private func deleteLocalPrivacyLogs(refreshSettings: Bool = true) {
        let result = privacyControls.deleteTraceAndCompatibilityLogs(
            surface: refreshSettings ? "settings" : "diagnostics"
        )
        DiagnosticsLog.shared.deleteAll()
        DiagnosticsLog.shared.record(result.eventName, metadata: result.metadata)
        if refreshSettings {
            refreshRuntimeChrome()
        }
    }

    private func cycleAcceptAllShortcut() {
        keyboardShortcutConfiguration.acceptAllShortcut = keyboardShortcutConfiguration.acceptAllShortcut.next
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

    private func toggleScreenshotTracing(for bundleIdentifier: String) {
        guard !bundleIdentifier.isEmpty else {
            _ = privacyControls.toggleScreenshotTracing()
            showDiagnostics()
            return
        }

        guard let result = compatibilityLearningActions.toggleScreenshotTracing(for: bundleIdentifier) else {
            return
        }
        DiagnosticsLog.shared.record(
            "screenshot-trace-control",
            metadata: result.metadata
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
        guard let result = compatibilityLearningActions.nudge(
            dx: dx,
            dy: dy,
            visibleSuggestionBundleIdentifier: visibleSuggestionBundleIdentifier,
            fallbackBundleIdentifier: targetAppForControls()?.bundleIdentifier,
            applyVisibleSuggestionNudge: { [weak self] bundleIdentifier in
                self?.applyVisibleSuggestionNudge(dx: dx, dy: dy, bundleIdentifier: bundleIdentifier) ?? false
            }
        ) else {
            DiagnosticsLog.shared.record(
                "compatibility-learning-nudge-skipped",
                metadata: ["reason": "no-eligible-app"]
            )
            return
        }

        DiagnosticsLog.shared.record(
            "compatibility-learning-nudge",
            metadata: result.metadata
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
              visibleSuggestionBundleIdentifier == bundleIdentifier else {
            return false
        }

        guard visibleSuggestionPanel.offsetPlacement(dx: CGFloat(dx), dy: CGFloat(dy)) else {
            return false
        }
        refreshVisibleSuggestion()
        return true
    }

    @objc
    private func resetCurrentAppLearning() {
        guard let result = compatibilityLearningActions.reset(
            visibleSuggestionBundleIdentifier: visibleSuggestionBundleIdentifier,
            fallbackBundleIdentifier: targetAppForControls()?.bundleIdentifier
        ) else {
            return
        }

        DiagnosticsLog.shared.record(
            "compatibility-learning-reset",
            metadata: result.metadata
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
        guard let reportURL = RawAutocompleteTraceLog.shared.exportHTMLReport() else {
            DiagnosticsLog.shared.record("trace-report-export-failed")
            showDiagnostics()
            return
        }

        NSWorkspace.shared.open(reportURL)
        DiagnosticsLog.shared.record(
            "trace-report-exported",
            metadata: ["path": reportURL.path]
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
            appEnabled: frontmostApp.map { !disabledBundleIdentifiers.contains($0.bundleIdentifier) } ?? false
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

    static var acceptAllShortcutDefaultsKey: String {
        "AcceptAllShortcut"
    }

    func loadPauseState() {
        suggestionsPaused = UserDefaults.standard.bool(forKey: Self.suggestionsPausedDefaultsKey)
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
