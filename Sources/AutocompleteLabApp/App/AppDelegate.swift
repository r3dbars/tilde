import AppKit
import AutocompleteLabCore
import CoreGraphics

struct MenuBarStatusItemConfiguration: Equatable {
    let symbolName: String
    let fallbackTitle: String
    let accessibilityLabel: String

    static let autocompleteLab = MenuBarStatusItemConfiguration(
        symbolName: "text.cursor",
        fallbackTitle: "SteadyType",
        accessibilityLabel: "SteadyType"
    )
}

private struct ObsidianPostAcceptanceSuppression {
    let textBeforeCursor: String
    let textAfterCursor: String
    let expiresAt: Date

    func matches(context: FocusedTextContext, now: Date = Date()) -> Bool {
        expiresAt > now
            && context.textBeforeCursor == textBeforeCursor
            && context.textAfterCursor == textAfterCursor
    }
}

private final class ProcessResourceDiagnosticsSampler {
    private var previousCPUSeconds: Double?
    private var previousWallTime: Date?

    func sample() -> [String: String] {
        let now = Date()
        let cpuSeconds = Self.currentCPUSeconds()
        var metadata: [String: String] = [
            "lowPowerMode": String(ProcessInfo.processInfo.isLowPowerModeEnabled),
            "processorCount": String(ProcessInfo.processInfo.activeProcessorCount),
            "thermalState": ProcessInfo.processInfo.thermalState.diagnosticsValue
        ]

        if let rssMB = Self.currentResidentMemoryMegabytes() {
            metadata["rssMB"] = String(rssMB)
        }

        if let cpuSeconds {
            if let previousCPUSeconds, let previousWallTime {
                let elapsed = max(0.001, now.timeIntervalSince(previousWallTime))
                let cpuPercent = max(0, ((cpuSeconds - previousCPUSeconds) / elapsed) * 100)
                metadata["cpuPercent"] = String(format: "%.1f", cpuPercent)
            } else {
                metadata["cpuPercent"] = "0.0"
            }
            previousCPUSeconds = cpuSeconds
            previousWallTime = now
        }

        return metadata
    }

    private static func currentCPUSeconds() -> Double? {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else {
            return nil
        }

        return seconds(from: usage.ru_utime) + seconds(from: usage.ru_stime)
    }

    private static func seconds(from timeValue: timeval) -> Double {
        Double(timeValue.tv_sec) + (Double(timeValue.tv_usec) / 1_000_000)
    }

    private static func currentResidentMemoryMegabytes() -> Int? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.stride / MemoryLayout<natural_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    reboundPointer,
                    &count
                )
            }
        }
        guard result == KERN_SUCCESS else {
            return nil
        }

        let megabyte = UInt64(1_048_576)
        return Int((UInt64(info.resident_size) + megabyte - 1) / megabyte)
    }
}

private extension ProcessInfo.ThermalState {
    var diagnosticsValue: String {
        switch self {
        case .nominal:
            "nominal"
        case .fair:
            "fair"
        case .serious:
            "serious"
        case .critical:
            "critical"
        @unknown default:
            "unknown"
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let accessibilityClient = AccessibilityClient()
    private let startupOnboardingPolicy = StartupOnboardingPolicy()
    private let appSettings = AppSettings()
    private let profileStore = CompatibilityProfileStore.mvp
    private let promptEditorPolicy = PromptEditorFingerprintPolicy()
    private let browserHostedSurfacePolicy = BrowserHostedSurfacePolicy()
    private let suggestionSilenceExplanationPolicy = SuggestionSilenceExplanationPolicy()
    private let suggestionControlPolicy = SuggestionControlPolicy()
    private let suggestionPauseSchedulePolicy = SuggestionPauseSchedulePolicy()
    private let suggestionRequestSchedulingPolicy = SuggestionRequestSchedulingPolicy()
    private let suggestionAggressivenessPolicy = SuggestionAggressivenessPolicy()
    private let fieldClassifier = AXFieldClassifier()
    private let textContextRepairPolicy = TextContextRepairPolicy()
    private let obsidianTrustedEndOfDocumentSnapshotPolicy = ObsidianTrustedEndOfDocumentSnapshotPolicy()
    private let tracePrivacySecretStore = TracePrivacySecretStore()
    private let suggestionCadenceResetPolicy = SuggestionCadenceResetPolicy()
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
    private let keyboardCaptureSafetyPolicy = KeyboardCaptureSafetyPolicy()
    private let keyboardEventTapIdleStopPolicy = KeyboardEventTapIdleStopPolicy()
    private let insertionVerification = InsertionVerification()
    private let insertionVerificationContextRecoveryPolicy = InsertionVerificationContextRecoveryPolicy()
    private let obsidianInsertionVerificationFastPathPolicy = ObsidianInsertionVerificationFastPathPolicy()
    private let insertionRetryPolicy = InsertionRetryPolicy()
    private let insertionVerificationTimingPolicy = InsertionVerificationTimingPolicy()
    private let acceptanceReceiptPolicy = AcceptanceReceiptPolicy()
    private let suggestionAcceptanceGuard = SuggestionAcceptanceGuard()
    private let acceptanceSafetyPolicy = AcceptanceSafetyPolicy()
    private let acceptedTextSafetyPolicy = AcceptedTextSafetyPolicy()
    private let suggestionReplacementVisibilityPolicy = SuggestionReplacementVisibilityPolicy()
    private let suggestionGeometryChangePolicy = SuggestionGeometryChangePolicy()
    private let obsidianTabPassthroughRepairPolicy = ObsidianTabPassthroughRepairPolicy()
    private let obsidianFullAcceptCaretRepairPolicy = ObsidianFullAcceptCaretRepairPolicy()
    private let suggestionInterruptionPolicy = SuggestionInterruptionPolicy()
    private let workspaceFocusChangePolicy = WorkspaceFocusChangePolicy()
    private let visibleSuggestionPersistencePolicy = VisibleSuggestionPersistencePolicy()
    private let wordCompletionRanker = WordCompletionCandidateRanker()
    private lazy var suggestionOrchestrator = SuggestionOrchestrator(
        engine: engine,
        wordCompletionRanker: wordCompletionRanker,
        prefixFamilyCooldownPolicy: makePrefixFamilyCooldownPolicy()
    )
    private let typeThroughPrefixStateMachine = TypeThroughPrefixStateMachine()
    private let suggestionTypingProgressPolicy = SuggestionTypingProgressPolicy()
    private var displayScorePolicy: DisplayScorePolicy {
        suggestionTuning.displayScorePolicy
    }
    private let annoyanceSuppressor = AnnoyanceSuppressorActor()
    private let traceScreenshotCaptureCoordinator = TraceScreenshotCaptureCoordinator()
    private let focusedTextAXHealthPolicy = FocusedTextAXHealthPolicy.typingResponsiveness
    private let focusedTextAXHealthSuggestionVisibilityPolicy = FocusedTextAXHealthSuggestionVisibilityPolicy()
    private let focusedTextPollingThrottleSuggestionVisibilityPolicy =
        FocusedTextPollingThrottleSuggestionVisibilityPolicy()
    private let compatibilityLearningStore = CompatibilityLearningStore.shared
    private let suggestionPanel = SuggestionPanelController()
    private let fieldStatusIndicator = FieldStatusIndicatorController()
    private lazy var suggestionPresentationDelivery = SuggestionPresentationDelivery(
        panelPresenter: { [suggestionPanel] text, anchorRect, textLineRect, clippingRect, textStyle, renderMode in
            suggestionPanel.show(
                text: text,
                near: anchorRect,
                alignedTo: textLineRect,
                boundedBy: clippingRect,
                style: textStyle,
                renderMode: renderMode
            )
        },
        fieldStatusPresenter: { [weak self] context in
            self?.showFieldStatusIndicator(.shown, context: context)
        }
    )
    private lazy var focusedTextReader = SerialFocusedTextAXReader(accessibilityClient: accessibilityClient)
    /// First extracted slice of the suggestion pipeline: owns the focused-text polling driver
    /// (timer, cadence, in-flight guard, throttle/pause, latency/skip stats). AppDelegate holds
    /// it and delegates timing concerns to it via `SuggestionPipelineHost` (see extension below).
    private lazy var suggestionPipeline = SuggestionPipelineController(host: self)
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
        pauseSuggestionsFor15Minutes: { [weak self] in
            self?.pauseSuggestionsFor15Minutes()
        },
        pauseSuggestionsFor1Hour: { [weak self] in
            self?.pauseSuggestionsFor1Hour()
        },
        pauseSuggestionsUntilTomorrow: { [weak self] in
            self?.pauseSuggestionsUntilTomorrowFromControl()
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
        startTextEditPractice: { [weak self] in
            self?.startTextEditPractice()
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
        exportPrivacyBundle: { [weak self] in
            self?.exportTraceReport()
        },
        cycleAcceptAllShortcut: { [weak self] in
            self?.cycleAcceptAllShortcut()
        },
        setAcceptAllShortcut: { [weak self] shortcut in
            self?.setAcceptAllShortcut(shortcut)
        },
        setSuggestionAggressivenessLevel: { [weak self] level in
            self?.setSuggestionAggressivenessLevel(level)
        },
        setSuggestionMaxVisibleWords: { [weak self] words in
            self?.setSuggestionMaxVisibleWords(words)
        },
        setSuggestionWordStartCharacters: { [weak self] characters in
            self?.setSuggestionWordStartCharacters(characters)
        },
        setSuggestionPhraseStartWords: { [weak self] words in
            self?.setSuggestionPhraseStartWords(words)
        },
        setSuggestionResponseSpeedLevel: { [weak self] level in
            self?.setSuggestionResponseSpeedLevel(level)
        },
        setSuggestionConfidenceLevel: { [weak self] level in
            self?.setSuggestionConfidenceLevel(level)
        },
        setSuggestionLearningRestraintLevel: { [weak self] level in
            self?.setSuggestionLearningRestraintLevel(level)
        },
        resetSuggestionTuning: { [weak self] in
            self?.resetSuggestionTuning()
        }
    )

    private var statusItem: NSStatusItem?
    private var statusMenuItem: NSMenuItem?
    private var suggestionDecisionMenuItem: NSMenuItem?
    private var runtimeMenuItem: NSMenuItem?
    private var pauseSuggestionsMenuItem: NSMenuItem?
    private var silenceFieldMenuItem: NSMenuItem?
    private var toggleAppMenuItem: NSMenuItem?
    private var workspaceFocusObservers: [NSObjectProtocol] = []
    private var screenGeometryObserver: NSObjectProtocol?
    private var resourceDiagnosticsTimer: Timer?
    private let resourceDiagnosticsSampler = ProcessResourceDiagnosticsSampler()
    private lazy var suggestionSummonHotKey = SuggestionSummonHotKey { [weak self] in
        self?.requestSuggestionNow(source: "hotkey")
    }
    private var keyboardEventTap: KeyboardEventTap?
    private var keyboardEventTapStopTask: Task<Void, Never>?
    private var prefixCooldownRetryTask: Task<Void, Never>?
    private var suggestionSession = SuggestionSession()
    private var lastCaretRect: CGRect?
    private var lastTextLineRect: CGRect?
    private var lastClippingRect: CGRect?
    private var lastTextStyle: FocusedTextStyle?
    private var lastRenderMode: SuggestionRenderMode?
    private var lastCompatibilityLearningTrustContext: CompatibilityLearningVisualTrustContext?
    private var lastVisibleSuggestionGeometrySnapshot: SuggestionGeometrySnapshot?
    private var currentFieldIdentity: FocusedFieldIdentity?
    private var currentProfile: CompatibilityProfile?
    private var lastTextSnapshot: FocusedTextSnapshot?
    private var lastTrustedObsidianEndOfDocumentSnapshot: FocusedTextSnapshot?
    private var lastFocusedTextChangeAt: Date?
    private var lastRequestedTextBeforeCursor: String?
    private var manualSuggestionRequestPending = false
    private var manualSuggestionRetryTask: Task<Void, Never>?
    private var suppressedFieldIdentities: Set<FocusedFieldIdentity> = []
    private var disabledBundleIdentifiers: Set<String> = []
    private var debounceTask: Task<Void, Never>?
    private var debounceTaskSuggestionID: String?
    private var insertionVerificationTask: Task<Void, Never>?
    private let acceptanceSurvivalChecker = AcceptanceSurvivalChecker()
    private var acceptanceSurvivalTasks: [String: Task<Void, Never>] = [:]
    private var runtimeWarmTask: Task<Void, Never>?
    private var pauseExpirationTask: Task<Void, Never>?
    private let focusedFieldIdentityPolicy = FocusedFieldIdentityPolicy()
    private let insertionVerificationPreflightPolicy = InsertionVerificationPreflightPolicy()
    private let insertionFailureSuppressionPolicy = InsertionFailureSuppressionPolicy()
    private var focusedTextAXHealthState = FocusedTextAXHealthState()
    private var suggestionBlockLogGate = SuggestionBlockLogGate()
    private var suggestionRepetitionSuppressor = SuggestionRepetitionSuppressor()
    private let typingBurstPolicy = TypingBurstPolicy()
    private var typingBurstState = TypingBurstState()
    private var currentSuggestionState = CurrentSuggestionState()
    private var preservesResidualSuggestionAfterNextWordAccept = false
    private var obsidianPostAcceptanceSuppression: ObsidianPostAcceptanceSuppression?
    private var suppressKeyUntil: [AutocompleteKey: Date] = [:]
    private var pendingAcceptedInsertionUndo: AcceptedInsertionUndo?
    private var acceptedInsertionUndoExpirationTask: Task<Void, Never>?
    private let acceptedInsertionUndoRecoveryMode = AcceptedInsertionUndoRecoveryMode.fromEnvironment()
    private var lastStatusLine: String?
    private var lastSuggestionDecision = "Starting"
    private var lastSyntheticCaretDiagnosticSignature: String?
    private var lastTextContextRepairDiagnosticSignature: String?
    private var lastEligibleTargetApp: RunningApplicationInfo?
    private var lastObservedSettingsApp: RunningApplicationInfo?
    private var lastFieldControlTarget: FieldControlTarget?
    private var currentRuntimeState: LocalRuntimeState = .unavailable(reason: "starting")
    private var automaticTerminationActivity: NSObjectProtocol?
    private var didDisableAutomaticTermination = false
    private var modelInstallTask: Task<Void, Never>?
    private var modelInstallStatusText: String?
    private var isModelInstallCancelRequested = false
    private let keyboardEventTapIdleStopDelayMilliseconds = 700
    private let postTypingPollPauseMilliseconds = 220
    private let visibleSuggestionTypingPollPauseMilliseconds = 60
    private let postInsertionPollPauseMilliseconds = 220
    private let maximumPreservedSuggestionGeometryAgeDuringAXPauseMilliseconds = 750
    private let maximumPreservedSuggestionDisplaySuppressionAgeMilliseconds = 5_000
    private var suggestionsPaused = false
    private var suggestionsPausedUntil: Date?
    private var appEnablementSetupCompleted = true
    private var keyboardShortcutConfiguration = KeyboardShortcutConfiguration.default
    private var suggestionTuning = SuggestionTuning()

    func applicationDidFinishLaunching(_ notification: Notification) {
        keepProcessResident()
        NSApp.setActivationPolicy(.accessory)
        loadPauseState()
        loadDisabledApps()
        loadKeyboardShortcutConfiguration()
        loadSuggestionTuning()
        configureStatusItem()
        DiagnosticsLog.shared.record("launch", metadata: launchDiagnosticsMetadata())
        DiagnosticsLog.shared.record("runtime-bootstrap", metadata: modelRuntimeBundle.diagnosticsMetadata)
        if startupOnboardingPolicy.shouldRequestAccessibilityPromptOnLaunch(
            isTrusted: accessibilityClient.isTrusted
        ) {
            accessibilityClient.requestPermissionIfNeeded()
        }
        warmModelRuntime()
        startSuggestionSummonHotKey()
        if shouldShowSettingsForCurrentReadiness {
            showSettings()
        }
        startWorkspaceFocusObservers()
        startScreenGeometryObserver()
        suggestionPipeline.startPolling()
        startResourceDiagnostics()
        DispatchQueue.main.async { [weak self] in
            self?.keepProcessResident()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        DiagnosticsLog.shared.record("terminate")
        if let automaticTerminationActivity {
            ProcessInfo.processInfo.endActivity(automaticTerminationActivity)
            self.automaticTerminationActivity = nil
        }
        debounceTask?.cancel()
        pauseExpirationTask?.cancel()
        keyboardEventTapStopTask?.cancel()
        insertionVerificationTask?.cancel()
        acceptedInsertionUndoExpirationTask?.cancel()
        runtimeWarmTask?.cancel()
        invalidatePendingSuggestionRequest()
        modelRuntime.cancel()
        suggestionPipeline.stopPolling()
        resourceDiagnosticsTimer?.invalidate()
        suggestionSummonHotKey.stop()
        manualSuggestionRetryTask?.cancel()
        stopWorkspaceFocusObservers()
        stopScreenGeometryObserver()
        stopKeyboardEventTapNow(reason: "terminate")
        fieldStatusIndicator.hide()
    }

    private func keepProcessResident() {
        if !didDisableAutomaticTermination {
            ProcessInfo.processInfo.disableAutomaticTermination(AppResidencyPolicy.automaticTerminationReason)
            didDisableAutomaticTermination = true
        }
        if automaticTerminationActivity == nil {
            automaticTerminationActivity = ProcessInfo.processInfo.beginActivity(
                options: AppResidencyPolicy.activityOptions,
                reason: AppResidencyPolicy.automaticTerminationReason
            )
        }
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
            ) { [weak self] notification in
                let bundleIdentifier = (
                    notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                )?.bundleIdentifier
                Task { @MainActor in
                    self?.handleWorkspaceFocusChange(
                        reason: "workspace-app-activated",
                        kind: .activated,
                        bundleIdentifier: bundleIdentifier
                    )
                }
            },
            center.addObserver(
                forName: NSWorkspace.didDeactivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let bundleIdentifier = (
                    notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                )?.bundleIdentifier
                Task { @MainActor in
                    self?.handleWorkspaceFocusChange(
                        reason: "workspace-app-deactivated",
                        kind: .deactivated,
                        bundleIdentifier: bundleIdentifier
                    )
                }
            },
            center.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleSuggestionInterruption(.systemWillSleep)
                }
            },
            center.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleSuggestionInterruption(.systemDidWake)
                }
            },
            center.addObserver(
                forName: NSWorkspace.screensDidSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleSuggestionInterruption(.displaysDidSleep)
                }
            },
            center.addObserver(
                forName: NSWorkspace.screensDidWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleSuggestionInterruption(.displaysDidWake)
                }
            }
        ]
    }

    private func stopWorkspaceFocusObservers() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceFocusObservers.forEach { center.removeObserver($0) }
        workspaceFocusObservers.removeAll()
    }

    private func startScreenGeometryObserver() {
        guard screenGeometryObserver == nil else {
            return
        }

        screenGeometryObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleScreenGeometryChange()
            }
        }
    }

    private func stopScreenGeometryObserver() {
        guard let observer = screenGeometryObserver else {
            return
        }

        NotificationCenter.default.removeObserver(observer)
        screenGeometryObserver = nil
    }







    private func handleScreenGeometryChange() {
        let currentFingerprint = currentScreenLayoutFingerprint()
        let shouldInvalidate = suggestionGeometryChangePolicy.shouldInvalidateSuggestionState(
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion,
            hasPendingSuggestionRequest: suggestionOrchestrator.currentRequest != nil,
            previousScreenLayoutFingerprint: lastVisibleSuggestionGeometrySnapshot?.screenLayoutFingerprint,
            currentScreenLayoutFingerprint: currentFingerprint
        )

        guard shouldInvalidate else {
            return
        }

        let interruption = suggestionInterruptionPolicy.decision(for: .screenGeometryChanged)
        invalidatePendingSuggestionRequest()
        let metadata = SuggestionGeometryInvalidationDecision
            .invalidate(.screenLayoutChanged)
            .metadata
            .merging(interruption.diagnosticMetadata) { current, _ in current }
            .merging(geometryTraceMetadata()) { current, _ in current }
        hideSuggestion(reason: "stale-geometry-screen-layout-changed", metadata: metadata)
        stopKeyboardEventTapNow(reason: interruption.keyboardCaptureStopReason)
        fieldStatusIndicator.hide()
        DiagnosticsLog.shared.record(
            interruption.diagnosticEvent,
            metadata: metadata
        )
    }

    private func handleSuggestionInterruption(_ kind: SuggestionInterruptionKind) {
        let decision = suggestionInterruptionPolicy.decision(for: kind)

        setSuggestionDecision(decision.decisionText)
        if decision.shouldClearFocusedField {
            clearFocusedFieldState(hideReason: decision.hideReason, resetBlockLogGate: false)
        } else {
            if decision.shouldInvalidatePendingRequest {
                invalidatePendingSuggestionRequest()
            }
            if suggestionSession.hasVisibleSuggestion {
                hideSuggestion(reason: decision.hideReason, metadata: decision.diagnosticMetadata)
            }
        }

        if decision.shouldStopKeyboardCapture {
            stopKeyboardEventTapNow(reason: decision.keyboardCaptureStopReason)
        }
        if decision.shouldHideFieldStatus {
            fieldStatusIndicator.hide()
        }
        DiagnosticsLog.shared.record(
            decision.diagnosticEvent,
            metadata: decision.diagnosticMetadata
        )
    }

    private func handleWorkspaceFocusChange(
        reason: String,
        kind: WorkspaceFocusChangePolicy.ChangeKind,
        bundleIdentifier: String?
    ) {
        guard suggestionSession.hasVisibleSuggestion
            || suggestionOrchestrator.currentRequest != nil
            || currentFieldIdentity != nil
            || fieldStatusIndicator.isVisible else {
            return
        }

        let currentBundleIdentifier = currentFieldIdentity?.bundleIdentifier ?? "unknown"
        let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard workspaceFocusChangePolicy.shouldClearFocus(
            kind: kind,
            notificationBundleIdentifier: bundleIdentifier,
            frontmostBundleIdentifier: frontmostBundleIdentifier,
            currentFieldIdentity: currentFieldIdentity
        ) else {
            DiagnosticsLog.shared.record(
                "workspace-focus-retained",
                metadata: [
                    "reason": reason,
                    "app": bundleIdentifier ?? "unknown",
                    "frontmostApp": frontmostBundleIdentifier ?? "unknown",
                    "currentApp": currentBundleIdentifier
                ]
            )
            return
        }

        setSuggestionDecision("Blocked: focus changed")
        clearFocusedFieldState(hideReason: "focus-changed", resetBlockLogGate: false)
        stopKeyboardEventTapNow(reason: reason)
        DiagnosticsLog.shared.record(
            "workspace-focus-changed",
            metadata: [
                "reason": reason,
                "app": bundleIdentifier ?? "unknown",
                "frontmostApp": frontmostBundleIdentifier ?? "unknown",
                "currentApp": currentBundleIdentifier
            ]
        )
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureStatusButton(item.button, configuration: .autocompleteLab)

        let menu = NSMenu()

        // A single, calm status line. The full decision + model detail lives in its tooltip.
        let statusMenu = NSMenuItem(title: "SteadyType", action: nil, keyEquivalent: "")
        menu.addItem(statusMenu)
        menu.addItem(NSMenuItem.separator())

        let suggestNowItem = NSMenuItem(
            title: "Ask for a Suggestion",
            action: #selector(suggestNowFromMenu),
            keyEquivalent: "`"
        )
        suggestNowItem.keyEquivalentModifierMask = [.control]
        suggestNowItem.toolTip = "\(SuggestionSummonHotKeyDescriptor.controlBacktick.displayName) asks for one suggestion without changing Tab."
        menu.addItem(suggestNowItem)

        // Pause options live in one submenu so the top level stays uncluttered.
        let pauseParentItem = NSMenuItem(title: "Pause Suggestions", action: nil, keyEquivalent: "")
        let pauseMenu = NSMenu()
        let pauseItem = NSMenuItem(title: pauseSuggestionsTitle, action: #selector(togglePauseSuggestions), keyEquivalent: "p")
        pauseMenu.addItem(pauseItem)
        pauseMenu.addItem(NSMenuItem.separator())
        pauseMenu.addItem(NSMenuItem(title: "For 15 Minutes", action: #selector(pauseSuggestionsFor15Minutes), keyEquivalent: ""))
        pauseMenu.addItem(NSMenuItem(title: "For 1 Hour", action: #selector(pauseSuggestionsFor1Hour), keyEquivalent: ""))
        pauseMenu.addItem(NSMenuItem(title: "Until Tomorrow", action: #selector(pauseSuggestionsUntilTomorrowFromControl), keyEquivalent: ""))
        menu.setSubmenu(pauseMenu, for: pauseParentItem)
        menu.addItem(pauseParentItem)

        let toggleItem = NSMenuItem(title: "Pause Current App", action: #selector(toggleCurrentApp), keyEquivalent: "t")
        menu.addItem(toggleItem)
        let silenceFieldItem = NSMenuItem(
            title: "Silence This Field",
            action: #selector(silenceCurrentField),
            keyEquivalent: "s"
        )
        menu.addItem(silenceFieldItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ","))
        let feedbackItem = NSMenuItem(
            title: BetaFeedbackLink.menuTitle,
            action: #selector(openFeedbackForm),
            keyEquivalent: ""
        )
        feedbackItem.toolTip = BetaFeedbackLink.privacyNote
        menu.addItem(feedbackItem)

        // Developer tools stay hidden unless explicitly enabled, so everyday users never see them.
        if developerMenuEnabled {
            let debugMenuItem = NSMenuItem(title: "Developer", action: nil, keyEquivalent: "")
            let debugMenu = NSMenu()
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
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit SteadyType", action: #selector(quit), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
        statusMenuItem = statusMenu
        suggestionDecisionMenuItem = nil
        runtimeMenuItem = nil
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

    private func startResourceDiagnostics() {
        recordResourceDiagnostics(reason: "launch")

        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordResourceDiagnostics(reason: "periodic")
            }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        resourceDiagnosticsTimer = timer
    }

    private func startSuggestionSummonHotKey() {
        let didStart = suggestionSummonHotKey.start()
        DiagnosticsLog.shared.record(
            didStart ? "suggestion-summon-hotkey-started" : "suggestion-summon-hotkey-start-failed",
            metadata: [
                "shortcut": suggestionSummonHotKey.descriptor.diagnosticName,
                "safetyFailure": String(!didStart)
            ]
        )
    }

    private func recordResourceDiagnostics(reason: String) {
        var metadata = resourceDiagnosticsSampler.sample()
        metadata["reason"] = reason
        DiagnosticsLog.shared.record("runtime-resource-sample", metadata: metadata)
    }

    private func warmModelRuntime() {
        let candidate = modelRuntimeBundle.activeCandidate
        let runtime = modelRuntime
        let startedAt = Date()

        guard modelRuntimeBundle.bootstrapPlan.canWarmPreferredRuntime else {
            let reason = modelRuntimeBundle.bootstrapPlan.unavailableReason ?? "local model runtime is not ready"
            applyRuntimeState(.unavailable(reason: reason))
            DiagnosticsLog.shared.record(
                "runtime-warm-skipped",
                metadata: [
                    "candidate": candidate.rawValue,
                    "reason": reason,
                    "modelDirectory": modelRuntimeBundle.modelDirectoryURL.path
                ]
            )
            return
        }

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
            } catch is CancellationError {
                await MainActor.run {
                    DiagnosticsLog.shared.record(
                        "runtime-warm-cancelled",
                        metadata: [
                            "candidate": candidate.rawValue,
                            "warmMilliseconds": String(Self.elapsedMilliseconds(since: startedAt))
                        ]
                    )
                }
                return
            } catch {
                await MainActor.run {
                    DiagnosticsLog.shared.record(
                        "runtime-warm-failed",
                        metadata: [
                            "candidate": candidate.rawValue,
                            "reason": error.localizedDescription,
                            "warmMilliseconds": String(Self.elapsedMilliseconds(since: startedAt))
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
                        "state": state.statusSummary,
                        "warmMilliseconds": String(Self.elapsedMilliseconds(since: startedAt))
                    ]
                )
                self?.applyRuntimeState(state)
            }
        }
    }

    private static func elapsedMilliseconds(since startedAt: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(startedAt) * 1_000))
    }

    private func applyRuntimeState(_ state: LocalRuntimeState) {
        let wasReadyForSuggestions = runtimeReadinessReport.allowsSuggestions
        currentRuntimeState = refreshModelAssetStateIfNeeded(for: state)
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
        if report.stage == .failed || report.action == .repairModel {
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

    private func refreshModelAssetStateIfNeeded(for state: LocalRuntimeState) -> LocalRuntimeState {
        guard case let .failed(candidate, reason) = state,
              RuntimeBootstrapPlan.isRepairableModelAssetFailure(reason) else {
            return state
        }

        modelRuntimeBundle = AppModelRuntimeFactory.makeRuntime()
        engine = RuntimeBackedCompletionEngine(runtime: modelRuntime)
        suggestionOrchestrator.updateEngine(engine)
        DiagnosticsLog.shared.record("runtime-bootstrap", metadata: modelRuntimeBundle.diagnosticsMetadata)
        DiagnosticsLog.shared.record(
            "runtime-model-asset-state-refreshed",
            metadata: [
                "candidate": candidate.rawValue,
                "reason": reason,
                "assetState": modelRuntimeBundle.bootstrapPlan.assetState.statusSummary
            ]
        )

        guard !modelRuntimeBundle.bootstrapPlan.assetState.isUsable else {
            return state
        }

        return .unavailable(
            reason: modelRuntimeBundle.bootstrapPlan.unavailableReason ?? reason
        )
    }

    private func rearmFocusedTextAfterRuntimeReady() {
        guard currentFieldIdentity != nil else {
            return
        }

        cancelPrefixCooldownRetry()
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
                suggestionsPausedUntil: suggestionsPausedUntil,
                runtimeReport: runtimeReadinessReport,
                runtimeTargetSummary: runtimeTargetSummary,
                modelDirectoryPath: modelDirectoryPath,
                modelInstallStatusText: modelInstallStatusText,
                isModelInstallInProgress: modelInstallTask != nil,
                currentApp: settingsCurrentAppState,
                fieldControl: settingsFieldControlState,
                practice: settingsPracticeState,
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

    private var settingsPracticeState: SettingsPracticeState {
        SettingsPracticeState(
            isTrusted: accessibilityClient.isTrusted,
            suggestionsPaused: suggestionsPaused,
            runtimeReport: runtimeReadinessReport,
            isModelInstallInProgress: modelInstallTask != nil,
            isTextEditEnabled: !disabledBundleIdentifiers.contains(Self.textEditPracticeBundleIdentifier)
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
            screenCaptureAccessGranted: CGPreflightScreenCaptureAccess(),
            diagnosticsPath: DiagnosticsLog.shared.path,
            tracePath: RawAutocompleteTraceLog.shared.path
        )
    }

    private var settingsKeyboardShortcutState: SettingsKeyboardShortcutState {
        SettingsKeyboardShortcutState(
            acceptAllShortcut: keyboardShortcutConfiguration.acceptAllShortcut,
            currentApp: settingsCurrentAppState
        )
    }

    private var settingsSuggestionAggressivenessState: SettingsSuggestionAggressivenessState {
        SettingsSuggestionAggressivenessState(tuning: suggestionTuning)
    }

    private var runtimeTargetSummary: String {
        "\(modelRuntimeBundle.bootstrapPlan.preferredAsset.model.rawValue) • \(completionLengthConfiguration.displaySummary) • \(suggestionTuning.displayName.lowercased()) • showing up to \(suggestionTuning.maxVisibleWords)"
    }

    private var shouldShowSettingsForCurrentReadiness: Bool {
        startupOnboardingPolicy.shouldShowSettingsOnLaunch(
            isTrusted: accessibilityClient.isTrusted,
            runtimeStage: runtimeReadinessReport.stage,
            appEnablementSetupCompleted: appEnablementSetupCompleted
        )
    }

    private var pauseSuggestionsTitle: String {
        pauseControlState.toggleTitle
    }

    /// Developer tooling (Diagnostics, nudges, journal folder) is hidden from the menu by
    /// default. Enable with `defaults write <bundle id> settings.showDeveloperMenu -bool true`.
    private var developerMenuEnabled: Bool {
        UserDefaults.standard.bool(forKey: "settings.showDeveloperMenu")
    }

    private var pauseStatusTitle: String {
        pauseControlState.menuPausedTitle
    }

    private var pauseControlState: ControlPauseState {
        expireTimedPauseIfNeeded(now: Date())
        return ControlPauseState(
            isPaused: suggestionsPaused,
            pausedUntil: suggestionsPausedUntil
        )
    }

    private var suggestionControlState: SuggestionControlState {
        expireTimedPauseIfNeeded(now: Date())
        return suggestionControlPolicy.state(isPaused: suggestionsPaused)
    }

    private func effectiveProfile(for app: RunningApplicationInfo) -> CompatibilityProfile? {
        profileStore.profile(for: app.bundleIdentifier)
    }




    private func isSuggestionEnabled(
        for app: RunningApplicationInfo,
        profile: CompatibilityProfile
    ) -> Bool {
        !disabledBundleIdentifiers.contains(app.bundleIdentifier)
            && !disabledBundleIdentifiers.contains(profile.bundleIdentifier)
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
            fieldStatusIndicator.hide()
            return
        }

        guard accessibilityClient.isTrusted else {
            handleSuggestionInterruption(.accessibilityPermissionLost)
            updateStatusMenu(app: nil, profile: nil, appEnabled: false)
            return
        }

        if suggestionPipeline.isPollingPaused(now: Date()) {
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
            fieldStatusIndicator.hide()
            return
        }

        rememberEligibleTargetApp(frontmostApp)
        let appEnabled = isSuggestionEnabled(for: frontmostApp, profile: profile)
        currentProfile = profile
        updateStatusMenu(app: frontmostApp, profile: profile, appEnabled: appEnabled)

        guard appEnabled else {
            clearFocusedFieldState(hideReason: "app-disabled")
            stopKeyboardEventTapNow(reason: "app-disabled")
            setSuggestionDecision("Blocked: app disabled")
            return
        }

        guard profile.canPresentSuggestions, !profile.isSensitive else {
            clearFocusedFieldState(hideReason: profile.isSensitive ? "sensitive-app" : "profile-disabled")
            stopKeyboardEventTapNow(reason: profile.isSensitive ? "sensitive-app" : "profile-disabled")
            setSuggestionDecision(profile.isSensitive ? "Blocked: sensitive app" : "Blocked: profile disabled")
            return
        }

        guard allowFocusedTextAXRead(for: frontmostApp.bundleIdentifier) else {
            return
        }

        let requestID = focusedTextReader.readFocusedTextContext(
            for: frontmostApp,
            allowDescendantTextFallback: profile.allowsDescendantTextFallback,
            options: FocusedTextReadOptionsPolicy.options(for: frontmostApp, profile: profile)
        ) { [weak self, profile, startedAt] result in
            Task { @MainActor [weak self, profile, startedAt] in
                await self?.completeFocusedTextPoll(
                    result: result,
                    profile: profile,
                    startedAt: startedAt
                )
            }
        }
        suggestionPipeline.noteReadStarted(requestID: requestID)
        completesAsync = true
    }

    private func completeFocusedTextPoll(
        result: FocusedTextAXReadResult,
        profile: CompatibilityProfile,
        startedAt: UInt64
    ) async {
        let pollStartedWithManualSuggestionRequest = manualSuggestionRequestPending
        var latencySummarySuppressionReason: String?
        defer {
            if pollStartedWithManualSuggestionRequest && manualSuggestionRequestPending {
                manualSuggestionRequestPending = false
            }
            suggestionPipeline.finishPoll(
                startedAt: startedAt,
                latencySummarySuppressionReason: latencySummarySuppressionReason
            )
        }

        guard suggestionPipeline.isCurrentRead(result.requestID) else {
            latencySummarySuppressionReason = "stale-request"
            DiagnosticsLog.shared.record(
                "focused-text-ax-read-dropped",
                metadata: [
                    "reason": "stale-request",
                    "requestID": String(result.requestID)
                ]
            )
            return
        }

        if suggestionPipeline.shouldRecordSlowAXReadMarker(
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
            latencySummarySuppressionReason = "ax-health-cooldown-started"
            return
        }

        let axThrottleRecommendation = suggestionPipeline.throttleRecommendation(
            queueDelayMilliseconds: result.queueDelayMilliseconds,
            readDurationMilliseconds: result.readDurationMilliseconds
        )
        let shouldProcessCurrentAXRead = suggestionPipeline.shouldProcessCurrentAXReadBeforeThrottle(
            hasContext: result.context != nil
        )

        if !shouldProcessCurrentAXRead,
           applyFocusedTextPollingThrottleIfNeeded(axThrottleRecommendation) {
            setSuggestionDecision("Waiting: AX read")
            return
        }

        guard let activeApp = accessibilityClient.frontmostApplication(),
              activeApp.bundleIdentifier == result.app.bundleIdentifier,
              activeApp.processIdentifier == result.app.processIdentifier else {
            setSuggestionDecision("Blocked: focus changed")
            hideSuggestion(reason: "focus-changed")
            fieldStatusIndicator.hide()
            return
        }

        if result.context == nil {
            recordMissingFocusedContextDiagnostics(app: result.app, profile: profile)
        }

        guard let rawContext = result.context else {
            clearFocusedFieldState()
            currentProfile = profile
            setSuggestionDecision(
                "Blocked: \(suggestionSilenceExplanationPolicy.focusedTextUnavailable(isSecure: false))"
            )
            hideSuggestion()
            return
        }

        guard !rawContext.isSecure else {
            clearFocusedFieldState()
            currentProfile = profile
            setSuggestionDecision(
                "Blocked: \(suggestionSilenceExplanationPolicy.focusedTextUnavailable(isSecure: true))"
            )
            hideSuggestion()
            return
        }

        suggestionPipeline.pauseAfterProcessingCurrentAXRead(axThrottleRecommendation)
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
        let promptMatch = promptTextAreaMatch(
            for: frontmostApp.bundleIdentifier,
            context: rawContext
        )
        guard promptMatch.canSuggest else {
            clearFocusedFieldState(resetBlockLogGate: false)
            currentProfile = profile
            setSuggestionDecision("Blocked: \(promptMatch.reason)")
            showFieldStatusIndicator(.blocked.withReason(promptMatch.reason), context: rawContext)
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
        let hostedSurfaceTraceMetadata = hostedSurfaceBlock.redactedTraceMetadata(
            textBeforeCursorLength: rawContext.textBeforeCursor.count,
            textAfterCursorLength: rawContext.textAfterCursor.count
        )
        clearFocusedFieldState(resetBlockLogGate: false)
        currentProfile = profile
        setSuggestionDecision("Blocked: \(hostedSurfaceBlock.userFacingReason)")
        showFieldStatusIndicator(.blocked.withReason(hostedSurfaceBlock.userFacingReason), context: rawContext)
        RawAutocompleteTraceLog.shared.record(
            type: .suggestionSuppressed,
            suggestionID: UUID().uuidString,
            appBundleIdentifier: profile.bundleIdentifier,
            fieldIdentity: hostedSurfaceFieldIdentity.traceDescription,
            requestMode: "",
            triggerReason: "browser-hosted-surface-policy",
            textBeforeCursor: "",
            textAfterCursor: "",
            reason: hostedSurfaceBlock.traceReason,
            metadata: hostedSurfaceTraceMetadata
        )
        recordBlockedSuggestionEvent(
            "suggestion-blocked",
            context: rawContext,
            profile: profile,
            fieldIdentity: hostedSurfaceFieldIdentity,
            metadata: hostedSurfaceTraceMetadata
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
        let rawSnapshot = FocusedTextSnapshot(
            fieldIdentity: rawFieldIdentity,
            textBeforeCursor: rawContext.textBeforeCursor,
            textAfterCursor: rawContext.textAfterCursor
        )
        if repairObsidianTabPassthroughIfNeeded(
            previousSnapshot: previousSnapshot,
            currentSnapshot: rawSnapshot,
            context: rawContext,
            profile: profile,
            fieldIdentity: rawFieldIdentity,
            source: "raw"
        ) {
            return
        }

        let repairPreviousSnapshot = obsidianTrustedEndOfDocumentSnapshotPolicy.repairPreviousSnapshot(
            fieldIdentity: rawFieldIdentity,
            previousSnapshot: previousSnapshot,
            trustedSnapshot: lastTrustedObsidianEndOfDocumentSnapshot
        )
        let context = presentationAdjustedContext(
            rawContext,
            app: frontmostApp,
            profile: profile,
            previousSnapshot: repairPreviousSnapshot
        )
        let fieldIdentity = fieldIdentity(
            app: frontmostApp,
            context: context,
            profile: profile
        )
        let fieldClassification = fieldClassification(for: context)
        let suggestionFieldClassification = effectiveSuggestionFieldClassification(
            app: frontmostApp,
            context: context,
            profile: profile,
            raw: fieldClassification
        )
        rememberFieldControlTarget(
            app: frontmostApp,
            fieldIdentity: fieldIdentity,
            requestMode: nil,
            fieldKind: fieldClassification.kind
        )
        showFieldStatusIndicator(
            suggestionSession.hasVisibleSuggestion ? .shown : .ready,
            context: context
        )

        let snapshot = FocusedTextSnapshot(
            fieldIdentity: fieldIdentity,
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor
        )
        rememberTrustedObsidianEndOfDocumentSnapshotIfNeeded(snapshot)

        if repairObsidianTabPassthroughIfNeeded(
            previousSnapshot: previousSnapshot,
            currentSnapshot: snapshot,
            context: context,
            profile: profile,
            fieldIdentity: fieldIdentity,
            source: "adjusted"
        ) {
            return
        }

        guard snapshot != previousSnapshot else {
            if shouldPreserveVisibleSuggestionDuringTransientEmptyContext(
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity
            ) {
                updateKeyboardEventTapSnapshot()
                setSuggestionDecision("Shown: preserving current suggestion")
                recordSuggestionEvent(
                    "suggestion-preserved",
                    context: context,
                    profile: profile,
                    metadata: [
                        "reason": "transient-empty-context-stable",
                        "blockReason": CompletionActivationBlockReason.tooLittleContext.rawValue,
                        "fieldIdentity": fieldIdentity.traceDescription
                    ]
                )
                return
            }
            setSuggestionDecision(
                suggestionSession.hasVisibleSuggestion
                    ? "Shown: tracking current field"
                    : "Ready: waiting for text change"
            )
            showFieldStatusIndicator(
                suggestionSession.hasVisibleSuggestion ? .shown : .ready,
                context: context
            )
            repositionVisibleSuggestion(context: context, profile: profile)
            return
        }

        if previousSnapshot != nil {
            lastFocusedTextChangeAt = Date()
        }
        cancelPrefixCooldownRetry()
        let typingBurstDecision = observeTypingBurst(
            previousSnapshot: previousSnapshot,
            currentSnapshot: snapshot
        )

        recordTypedOverSuggestionIfNeeded(
            newTextBeforeCursor: context.textBeforeCursor,
            fieldIdentity: fieldIdentity,
            profile: profile
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
            showFieldStatusIndicator(.blocked.withReason("diagnostics only"), context: context)
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
            showFieldStatusIndicator(.waiting.withReason(runtimeReport.summary), context: context)
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
            fieldKind: suggestionFieldClassification.kind,
            allowsUnknownFieldKind: profile.allowsUnknownFieldKind
        )
        rememberFieldControlTarget(
            app: frontmostApp,
            fieldIdentity: fieldIdentity,
            requestMode: activationDecision.requestMode,
            fieldKind: suggestionFieldClassification.kind
        )

        guard activationDecision.canSuggest else {
            if shouldPreserveVisibleSuggestionAfterActivationBlock(
                activationDecision: activationDecision,
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity
            ) {
                updateKeyboardEventTapSnapshot()
                setSuggestionDecision("Shown: preserving current suggestion")
                recordSuggestionEvent(
                    "suggestion-preserved",
                    context: context,
                    profile: profile,
                    metadata: [
                        "reason": "transient-empty-context",
                        "blockReason": activationDecision.blockReasonDescription,
                        "fieldIdentity": fieldIdentity.traceDescription
                    ]
                )
                return
            }

            let userFacingReason: String
            if let blockReason = activationDecision.blockedReason {
                userFacingReason = suggestionSilenceExplanationPolicy.activationBlockReason(
                    blockReason,
                    fieldKind: fieldClassification.kind
                )
            } else {
                userFacingReason = "field quieted"
            }
            setSuggestionDecision("Blocked: \(userFacingReason)")
            showFieldStatusIndicator(.blocked.withReason(userFacingReason), context: context)
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
                metadata: suggestionFieldClassification.traceMetadata
                    .merging(["silenceExplanation": userFacingReason]) { current, _ in current }
            )
            recordBlockedSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                metadata: [
                    "reason": activationDecision.blockReasonDescription,
                    "silenceExplanation": userFacingReason
                ]
                .merging(suggestionFieldClassification.traceMetadata) { current, _ in current }
            )
            hideSuggestion()
            return
        }

        let requestMode = activationDecision.requestMode ?? .phraseContinuation
        if shouldSuppressObsidianPostAcceptanceRefresh(context: context, profile: profile) {
            invalidatePendingSuggestionRequest()
            let metadata = suggestionFieldClassification.traceMetadata
                .merging(["reason": "obsidian-post-acceptance-settle"]) { current, _ in current }
            setSuggestionDecision("Waiting: Obsidian accepted text settled")
            showFieldStatusIndicator(.ready, context: context)
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: UUID().uuidString,
                appBundleIdentifier: profile.bundleIdentifier,
                fieldIdentity: fieldIdentity.traceDescription,
                requestMode: requestMode.rawValue,
                triggerReason: "obsidian-post-acceptance-settle",
                textBeforeCursor: context.textBeforeCursor,
                textAfterCursor: context.textAfterCursor,
                reason: "obsidian-post-acceptance-settle",
                metadata: metadata
            )
            recordBlockedSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                metadata: metadata
            )
            if suggestionSession.hasVisibleSuggestion {
                hideSuggestion(reason: "obsidian-post-acceptance-settle")
            }
            return
        }
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
            cancelPrefixCooldownRetry()
            break
        case let .coolingDown(cooldown):
            setSuggestionDecision(SuggestionStatusText.notShown(reason: "prefix-family-cooldown"))
            showFieldStatusIndicator(.waiting.withReason("recent miss cooldown"), context: context)
            schedulePrefixCooldownRetry(
                for: snapshot,
                cooldown: cooldown
            )
            let metadata = suggestionFieldClassification.traceMetadata
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
            fieldKind: suggestionFieldClassification.kind
        )
        let quietMode = await annoyanceSuppressor.quietMode(for: annoyanceContext)
        guard !quietMode.isActive else {
            setSuggestionDecision(SuggestionStatusText.notShown(reason: quietMode.traceReason))
            showFieldStatusIndicator(.waiting.withReason("recent rejects"), context: context)
            let metadata = suggestionFieldClassification.traceMetadata
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
            showFieldStatusIndicator(.blocked.withReason("placement unavailable"), context: context)
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
            showFieldStatusIndicator(.blocked.withReason("placement fallback unavailable"), context: context)
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
        let suggestionAppBundleIdentifier = suggestionBundleIdentifier(for: frontmostApp, profile: profile)
        let triggerBehaviorProfile = AutocompleteBehaviorProfileResolver().profile(for: AutocompleteBehaviorProfileInput(
            appBundleIdentifier: suggestionAppBundleIdentifier,
            fieldKind: suggestionFieldClassification.kind,
            currentLineStructure: currentLineStructure
        ))
        let triggerDecision = triggerPolicy(for: profile).decision(
            previousTextBeforeCursor: lastRequestedTextBeforeCursor,
            currentTextBeforeCursor: context.textBeforeCursor,
            lineStartBehavior: SuggestionLineStartBehavior.behavior(
                for: triggerBehaviorProfile.id,
                currentLineStructure: currentLineStructure
            ),
            behaviorProfileID: triggerBehaviorProfile.id,
            requestMode: requestMode
        )
        let isManualSuggestionRequest = manualSuggestionRequestPending
        if isManualSuggestionRequest {
            manualSuggestionRequestPending = false
        }

        let delayMilliseconds: Int
        let timingLane: SuggestionTimingLane
        if isManualSuggestionRequest {
            delayMilliseconds = 0
            if case let .request(_, policyTimingLane) = triggerDecision {
                timingLane = policyTimingLane
            } else {
                timingLane = switch requestMode {
                case .wordCompletion:
                    .instantWord
                case .sentenceContinuation:
                    .longPauseThought
                case .phraseContinuation:
                    .pausePhrase
                }
            }
        } else if case let .request(policyDelayMilliseconds, policyTimingLane) = triggerDecision {
            delayMilliseconds = policyDelayMilliseconds
            timingLane = policyTimingLane
        } else {
            if suggestionSession.hasVisibleSuggestion {
                setSuggestionDecision("Shown: waiting for cadence")
                showFieldStatusIndicator(.shown, context: context)
                repositionVisibleSuggestion(context: context, profile: profile)
                return
            }

            setSuggestionDecision("Waiting: cadence policy")
            showFieldStatusIndicator(.waiting.withReason("typing cadence"), context: context)
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

        setSuggestionDecision(
            isManualSuggestionRequest
                ? "Queued: asked once \(timingLane.rawValue)"
                : "Queued: \(requestMode.rawValue) \(timingLane.rawValue)"
        )
        showFieldStatusIndicator(.thinking, context: context)
        scheduleSuggestion(
            context: context,
            profile: profile,
            appBundleIdentifier: suggestionAppBundleIdentifier,
            fieldIdentity: fieldIdentity,
            fieldClassification: suggestionFieldClassification,
            renderMode: renderMode,
            delayMilliseconds: delayMilliseconds,
            timingLane: timingLane,
            requestMode: requestMode,
            typingBurstDecision: typingBurstDecision,
            triggerReason: isManualSuggestionRequest ? "manual-summon" : "poll"
        )
    }






    private func effectiveSuggestionFieldClassification(
        app _: RunningApplicationInfo,
        context _: FocusedTextContext,
        profile _: CompatibilityProfile,
        raw classification: AXFieldClassification
    ) -> AXFieldClassification {
        classification
    }

    private func effectiveSuggestionFieldClassificationForCurrentFrontmost(
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        raw classification: AXFieldClassification
    ) -> AXFieldClassification {
        guard let frontmostApp = accessibilityClient.frontmostApplication() else {
            return classification
        }

        return effectiveSuggestionFieldClassification(
            app: frontmostApp,
            context: context,
            profile: profile,
            raw: classification
        )
    }

    private func suggestionBundleIdentifier(
        for app: RunningApplicationInfo,
        profile: CompatibilityProfile
    ) -> String {
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
            currentSuggestionBundleIdentifier: currentSuggestionState.appBundleIdentifier,
            currentSuggestionHostBundleIdentifier: currentSuggestionHostBundleIdentifierForVisibility(),
            currentSuggestionFieldIdentity: currentSuggestionState.fieldIdentity,
            currentFieldIdentity: currentFieldIdentity,
            isInvalidatedByUserTyping: currentSuggestionState.invalidatedByUserKeyDown,
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

    @discardableResult
    private func applyFocusedTextPollingThrottleIfNeeded(
        _ recommendation: FocusedTextPollingThrottleRecommendation
    ) -> Bool {
        guard recommendation.shouldThrottle,
              let reason = recommendation.reason,
              recommendation.pauseMilliseconds > 0 else {
            return false
        }

        suggestionPipeline.pausePollingWithBackoff(
            now: Date(),
            durationMilliseconds: recommendation.pauseMilliseconds
        )
        invalidatePendingSuggestionRequest()
        if suggestionSession.hasVisibleSuggestion {
            let frontmostBundleIdentifier = accessibilityClient.frontmostApplication()?.bundleIdentifier
            if focusedTextPollingThrottleSuggestionVisibilityPolicy.shouldHideVisibleSuggestion(
                currentSuggestionBundleIdentifier: currentSuggestionState.appBundleIdentifier,
                currentSuggestionHostBundleIdentifier: currentSuggestionHostBundleIdentifierForVisibility(),
                currentSuggestionFieldIdentity: currentSuggestionState.fieldIdentity,
                currentFieldIdentity: currentFieldIdentity,
                frontmostBundleIdentifier: frontmostBundleIdentifier,
                isInvalidatedByUserTyping: currentSuggestionState.invalidatedByUserKeyDown,
                currentSuggestionAgeMilliseconds: currentSuggestionAgeMilliseconds(),
                maximumPreservedAgeMilliseconds: maximumPreservedSuggestionGeometryAgeDuringAXPauseMilliseconds
            ) {
                hideSuggestion(reason: "focused-text-poll-\(reason.rawValue)")
            } else {
                updateKeyboardEventTapSnapshot()
                DiagnosticsLog.shared.record(
                    "focused-text-poll-suggestion-preserved",
                    metadata: [
                        "app": currentSuggestionState.appBundleIdentifier ?? "",
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
                "pauseMilliseconds": String(recommendation.pauseMilliseconds),
                "pendingRequestPreserved": "false"
            ]
        )
        return true
    }


    private func currentSuggestionAgeMilliseconds(now: Date = Date()) -> Int? {
        guard let currentSuggestionPresentedAt = currentSuggestionState.presentedAt else {
            return nil
        }

        return max(0, Int(now.timeIntervalSince(currentSuggestionPresentedAt) * 1000))
    }

    private func currentSuggestionHostBundleIdentifierForVisibility() -> String? {
        nil
    }

    private func shouldPreserveVisibleSuggestionAfterActivationBlock(
        activationDecision: CompletionActivationDecision,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity
    ) -> Bool {
        guard case let .block(blockReason) = activationDecision else {
            return false
        }

        return visibleSuggestionPersistencePolicy.shouldPreserveAfterActivationBlock(
            blockReason: blockReason,
            appBundleIdentifier: profile.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: currentSuggestionState.appBundleIdentifier,
            currentSuggestionFieldIdentity: currentSuggestionState.fieldIdentity,
            currentSuggestionTextBeforeCursor: currentSuggestionState.textBeforeCursor,
            currentSuggestionAgeMilliseconds: currentSuggestionAgeMilliseconds(),
            isInvalidatedByUserTyping: currentSuggestionState.invalidatedByUserKeyDown,
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor
        )
    }

    private func shouldPreserveVisibleSuggestionDuringTransientEmptyContext(
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity
    ) -> Bool {
        visibleSuggestionPersistencePolicy.shouldPreserveAfterActivationBlock(
            blockReason: .tooLittleContext,
            appBundleIdentifier: profile.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: currentSuggestionState.appBundleIdentifier,
            currentSuggestionFieldIdentity: currentSuggestionState.fieldIdentity,
            currentSuggestionTextBeforeCursor: currentSuggestionState.textBeforeCursor,
            currentSuggestionAgeMilliseconds: currentSuggestionAgeMilliseconds(),
            isInvalidatedByUserTyping: currentSuggestionState.invalidatedByUserKeyDown,
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor
        )
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
            previousTextAfterCursor: previousSnapshot?.textAfterCursor,
            windowTitle: context.fingerprint.windowTitle,
            fingerprintText: context.fingerprint.searchableText
        ))
        let context = repair.wasRepaired
            ? contextReplacingText(
                context,
                textBeforeCursor: repair.textBeforeCursor,
                textAfterCursor: repair.textAfterCursor
            )
            : context
        if repair.wasRepaired {
            recordTextContextRepairIfNeeded(repair, context: context, profile: profile)
        }

        let syntheticCaretBundleIdentifier = syntheticTextAreaCaretBundleIdentifier(
            for: app,
            profile: profile
        )
        guard supportsSyntheticTextAreaCaret(for: app, profile: profile),
              promptTextAreaMatch(for: app.bundleIdentifier, context: context).canSuggest,
              shouldUseSyntheticTextAreaCaret(for: app, profile: profile, context: context),
              let syntheticCaret = syntheticTextAreaCaretRect(
                for: context,
                bundleIdentifier: syntheticCaretBundleIdentifier
              ) else {
            return context
        }

        let syntheticCaretSource = "text-area-estimate"
        let capabilities = FocusedTextCapabilities(
            canReadValue: context.capabilities.canReadValue,
            canReadSelectedTextRange: context.capabilities.canReadSelectedTextRange,
            canReadBoundsForRange: true,
            canReadAttributedText: context.capabilities.canReadAttributedText,
            canSetSelectedText: context.capabilities.canSetSelectedText
        )

        recordSyntheticCaretIfNeeded(
            syntheticCaret,
            context: context,
            profile: profile,
            source: syntheticCaretSource
        )

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
            windowIdentifier: context.windowIdentifier,
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
            windowIdentifier: context.windowIdentifier,
            textLineRect: context.textLineRect,
            textStyle: context.textStyle,
            isSecure: context.isSecure,
            caretIsSynthetic: context.caretIsSynthetic,
            capabilities: context.capabilities
        )
    }

    private func shouldUseSyntheticTextAreaCaret(
        for app: RunningApplicationInfo,
        profile: CompatibilityProfile,
        context: FocusedTextContext
    ) -> Bool {
        context.caretRect == nil
    }





    private func supportsSyntheticTextAreaCaret(
        for app: RunningApplicationInfo,
        profile: CompatibilityProfile
    ) -> Bool {
        return PromptEditorFingerprintPolicy.dogfoodBundleIdentifiers.contains(app.bundleIdentifier)
            || app.bundleIdentifier == "md.obsidian"
            || app.bundleIdentifier == "com.google.Chrome"
    }

    private func syntheticTextAreaCaretBundleIdentifier(
        for app: RunningApplicationInfo,
        profile: CompatibilityProfile
    ) -> String {
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

        if let obsidianScrolledCaret = obsidianScrolledCodeMirrorSyntheticCaretRect(
            for: context,
            bundleIdentifier: bundleIdentifier,
            elementRect: elementRect,
            font: font,
            lineHeight: lineHeight
        ) {
            return obsidianScrolledCaret
        }

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

    private func obsidianScrolledCodeMirrorSyntheticCaretRect(
        for context: FocusedTextContext,
        bundleIdentifier: String,
        elementRect: CGRect,
        font: NSFont,
        lineHeight: CGFloat
    ) -> CGRect? {
        guard bundleIdentifier == "md.obsidian",
              elementRect.width > 20,
              elementRect.width <= 80,
              elementRect.height >= lineHeight * 4,
              let windowRect = context.windowRect,
              windowRect.insetBy(dx: -24, dy: -24).intersects(elementRect) else {
            return nil
        }

        let currentLine = context.textBeforeCursor
            .split(separator: "\n", omittingEmptySubsequences: false)
            .last
            .map(String.init) ?? context.textBeforeCursor
        guard !currentLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let rowY = min(
            max(elementRect.maxY - lineHeight - 12, windowRect.minY + 8),
            windowRect.maxY - lineHeight - 8
        )
        let maxRight = min(
            windowRect.maxX - 24,
            max(elementRect.maxX + 160, windowRect.maxX - 96)
        )
        let rowWidth = max(160, maxRight - elementRect.minX)
        let visibleRowRect = CGRect(
            x: elementRect.minX,
            y: rowY,
            width: rowWidth,
            height: lineHeight + 18
        )

        return SyntheticCaretEstimator.caretRect(
            textBeforeCursor: currentLine,
            elementRect: visibleRowRect,
            windowRect: windowRect,
            lineHeight: lineHeight,
            horizontalPadding: 18,
            verticalPadding: 4,
            inlineGap: 8,
            centerSingleLineWhenTall: false,
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
        profile: CompatibilityProfile,
        source: String = "text-area-estimate"
    ) {
        let signature = [
            profile.bundleIdentifier,
            String(context.textBeforeCursor.count),
            compactRectDescription(caret),
            source
        ].joined(separator: "|")

        if source != "terminal-screen-prompt" {
            guard signature != lastSyntheticCaretDiagnosticSignature else {
                return
            }
        }

        lastSyntheticCaretDiagnosticSignature = signature
        DiagnosticsLog.shared.record(
            "synthetic-caret",
            metadata: [
                "app": profile.bundleIdentifier,
                "source": source,
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

    private func rememberTrustedObsidianEndOfDocumentSnapshotIfNeeded(_ snapshot: FocusedTextSnapshot) {
        guard obsidianTrustedEndOfDocumentSnapshotPolicy.shouldRemember(snapshot: snapshot) else {
            return
        }

        lastTrustedObsidianEndOfDocumentSnapshot = snapshot
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
                ) ?? .replayOriginalKey(.noVisibleSuggestion)
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
            DiagnosticsLog.shared.record(
                "keyboard-event-tap-started",
                metadata: [
                    "diagnosticLayer": "keyCapture",
                    "tapLocation": eventTap.tapPlacement.rawValue
                ]
            )
            return true
        }

        DiagnosticsLog.shared.record(
            "keyboard-event-tap-start-failed",
            metadata: [
                "diagnosticLayer": "keyCapture",
                "safetyFailure": "true"
            ]
        )
        return false
    }

    private func keyboardEventTapSnapshot() -> KeyboardEventTapSnapshot {
        return KeyboardEventTapSnapshot(
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion,
            supportsOneWordAcceptance: currentProfile?.supportsOneWordAcceptance == true,
            supportsFullAcceptance: currentProfile?.supportsFullAcceptance == true,
            isInvalidatedByUserTyping: currentSuggestionState.invalidatedByUserKeyDown,
            allowsAutocompleteKeyAfterPassthroughObservation: false,
            hasPendingAcceptedInsertionUndo: acceptedInsertionUndoIsActive(),
            acceptAllShortcut: keyboardShortcutConfiguration.acceptAllShortcut,
            visibleSuggestionID: currentSuggestionState.id
        )
    }

    private func updateKeyboardEventTapSnapshot() {
        keyboardEventTap?.updateSnapshot(keyboardEventTapSnapshot())
    }

    private func handleKeyboardEventTapDisabled(reason: String) {
        stopKeyboardEventTapNow(reason: "system-\(reason)")
        currentSuggestionState.invalidatedByUserKeyDown = true
        invalidatePendingSuggestionRequest()
        setSuggestionDecision("Blocked: keyboard capture disabled")
        hideSuggestion(reason: "keyboard-event-tap-\(reason)")
        DiagnosticsLog.shared.record(
            "keyboard-event-tap-failed-closed",
            metadata: [
                "reason": reason,
                "diagnosticLayer": "keyCapture",
                "safetyFailure": "true"
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
        suggestionPipeline.pausePolling(
            now: Date(),
            durationMilliseconds: suggestionSession.hasVisibleSuggestion
                ? visibleSuggestionTypingPollPauseMilliseconds
                : postTypingPollPauseMilliseconds
        )
        clearPendingAcceptedInsertionUndo(reason: "typing")

        guard suggestionSession.hasVisibleSuggestion else {
            return
        }

        currentSuggestionState.invalidatedByUserKeyDown = true
        invalidatePendingSuggestionRequest()
        setSuggestionDecision("Shown: tracking typing")
        updateKeyboardEventTapSnapshot()
    }



    private func handleAutocompleteKey(
        _ key: AutocompleteKey,
        isAutorepeat: Bool = false,
        didObservePassthroughKeyDown: Bool = false
    ) -> KeyboardEventTapHandlingResult {
        if didObservePassthroughKeyDown {
            currentSuggestionState.invalidatedByUserKeyDown = true
            preservesResidualSuggestionAfterNextWordAccept = false
            clearPendingAcceptedInsertionUndo(reason: "typing")
        }

        let action = KeyboardActionRouter(shortcutConfiguration: keyboardShortcutConfiguration).action(
            for: key,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion,
            hasPendingAcceptedInsertionUndo: acceptedInsertionUndoIsActive()
        )

        if action == .requestSuggestionNow {
            requestSuggestionNow(source: "key-tap")
            suppressKey(key)
            recordKeyboardAction(
                key: key,
                action: action,
                handled: true,
                reason: "requested"
            )
            return .handled
        }

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
            return handled ? .handled : .replayOriginalKey(.undoUnavailable)
        }

        guard suggestionSession.hasVisibleSuggestion else {
            suppressKeyUntil[key] = nil
            return .replayOriginalKey(.noVisibleSuggestion)
        }

        guard focusedFieldMatchesCurrentSuggestion(
            allowObsidianSnapshotFastPath: action.insertsSuggestionText
        ) else {
            setSuggestionDecision("Blocked: focus changed")
            hideSuggestion(reason: "focus-changed")
            recordKeyboardAction(
                key: key,
                action: .passThrough,
                handled: false,
                reason: "focus-changed"
            )
            return keyboardCaptureSafetyPolicy.handlingResultForFocusMismatch(key: key)
        }

        if currentSuggestionState.invalidatedByUserKeyDown {
            setSuggestionDecision("Blocked: stale suggestion passed through")
            hideSuggestion(reason: "stale-after-keydown")
            recordKeyboardAction(
                key: key,
                action: .passThrough,
                handled: false,
                reason: "stale-after-keydown"
            )
            return .replayOriginalKey(.staleAfterTyping)
        }

        if shouldSuppressKey(key, isAutorepeat: isAutorepeat) {
            recordKeyboardAction(key: key, action: .passThrough, handled: true, reason: "suppressed-autorepeat")
            return .handled
        }

        switch action {
        case .requestSuggestionNow:
            return .replayOriginalKey(.passThroughAction)

        case .undoAcceptedInsertion:
            return .replayOriginalKey(.undoUnavailable)

        case .acceptNextWord:
            guard currentProfile?.supportsOneWordAcceptance == true else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "unsupported-one-word")
                return .replayOriginalKey(.unsupportedAction)
            }
            if let blockReason = currentSuggestionAcceptanceDecision(
                allowObsidianSnapshotFastPath: true
            ).blockReason {
                recordAcceptanceGuardBlock(reason: blockReason)
                setSuggestionDecision("Blocked: \(blockReason.rawValue)")
                hideSuggestion(reason: blockReason.rawValue)
                recordKeyboardAction(key: key, action: action, handled: false, reason: blockReason.rawValue)
                return keyboardCaptureSafetyPolicy.handlingResult(forAcceptanceBlock: blockReason, key: key)
            }

            let acceptanceID = UUID().uuidString
            let acceptedAt = Date()
            let verificationBaseline = insertionVerificationBaseline(
                acceptanceID: acceptanceID,
                acceptedAt: acceptedAt,
                action: action,
                acceptMode: action.diagnosticName
            )
            guard let rawAcceptedText = suggestionSession.nextWordAcceptance() else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "missing-accepted-text")
                return keyboardCaptureSafetyPolicy.handlingResult(forAcceptanceFailure: .missingAcceptedText)
            }
            let acceptedText = acceptedTextForCurrentAcceptance(rawAcceptedText, action: action)
            guard let acceptanceProof = acceptanceReceipt(action: action, acceptedText: acceptedText) else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "acceptance-proof-failed")
                return keyboardCaptureSafetyPolicy.handlingResult(forAcceptanceFailure: .acceptanceProofFailed)
            }
            guard insertAcceptedText(acceptedText, action: action) else {
                suppressCurrentFieldAfterInsertionFailure(reason: "insert-failed")
                recordKeyboardAction(key: key, action: action, handled: false, reason: "insert-failed")
                return keyboardCaptureSafetyPolicy.handlingResult(forAcceptanceFailure: .insertionFailed)
            }

            completeNextWordAcceptance(
                acceptedText: acceptedText,
                acceptanceID: acceptanceID,
                acceptedAt: acceptedAt,
                action: action,
                acceptanceProof: acceptanceProof,
                verificationBaseline: verificationBaseline
            )
            suppressKey(key)
            recordKeyboardAction(key: key, action: action, handled: true, reason: "accepted")
            return .handled

        case .acceptAllVisible:
            guard currentProfile?.supportsFullAcceptance == true else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "unsupported-full")
                return .replayOriginalKey(.unsupportedAction)
            }
            if let blockReason = currentSuggestionAcceptanceDecision(
                allowObsidianSnapshotFastPath: true
            ).blockReason {
                recordAcceptanceGuardBlock(reason: blockReason)
                setSuggestionDecision("Blocked: \(blockReason.rawValue)")
                hideSuggestion(reason: blockReason.rawValue)
                recordKeyboardAction(key: key, action: action, handled: false, reason: blockReason.rawValue)
                return keyboardCaptureSafetyPolicy.handlingResult(forAcceptanceBlock: blockReason, key: key)
            }

            let acceptanceID = UUID().uuidString
            let acceptedAt = Date()
            let verificationBaseline = insertionVerificationBaseline(
                acceptanceID: acceptanceID,
                acceptedAt: acceptedAt,
                action: action,
                acceptMode: action.diagnosticName
            )
            guard let acceptedText = suggestionSession.allVisibleAcceptance() else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "missing-accepted-text")
                return keyboardCaptureSafetyPolicy.handlingResult(forAcceptanceFailure: .missingAcceptedText)
            }
            guard let acceptanceProof = acceptanceReceipt(action: action, acceptedText: acceptedText) else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "acceptance-proof-failed")
                return keyboardCaptureSafetyPolicy.handlingResult(forAcceptanceFailure: .acceptanceProofFailed)
            }
            guard insertAcceptedText(acceptedText, action: action) else {
                suppressCurrentFieldAfterInsertionFailure(reason: "insert-failed")
                recordKeyboardAction(key: key, action: action, handled: false, reason: "insert-failed")
                return keyboardCaptureSafetyPolicy.handlingResult(forAcceptanceFailure: .insertionFailed)
            }

            armAcceptedInsertionUndo(
                acceptedText: acceptedText,
                acceptanceID: acceptanceID,
                acceptedAt: acceptedAt,
                acceptMode: action.diagnosticName
            )
            suggestionSession.commitAllVisibleAcceptance(acceptedText)
            recordAcceptedText(acceptedText)
            armObsidianPostAcceptanceSuppressionIfNeeded()
            suggestionRepetitionSuppressor.recordAcceptance(
                acceptedText,
                mode: currentSuggestionState.requestMode,
                scope: currentSuggestionState.appBundleIdentifier ?? currentProfile?.bundleIdentifier ?? ""
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
                suggestionID: currentSuggestionState.id ?? "",
                reason: action.diagnosticName
            )
            setSuggestionDecision("Accepted: full suggestion")
            hideSuggestion(reason: "accepted-all")
            scheduleInsertionVerification(acceptedText: acceptedText, baseline: verificationBaseline)
            suppressKey(key)
            recordKeyboardAction(key: key, action: action, handled: true, reason: "accepted")
            return .handled

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
                suggestionID: currentSuggestionState.id ?? "",
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
            return .handled

        case .passThrough:
            if key != .other {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "pass-through")
            }
            return .replayOriginalKey(.passThroughAction)
        }
    }

    private func acceptedTextForCurrentAcceptance(
        _ acceptedText: String,
        action _: KeyboardAction
    ) -> String {
        acceptedText
    }

    private func currentSuggestionAcceptanceDecision(
        allowObsidianSnapshotFastPath: Bool = false
    ) -> SuggestionAcceptanceDecision {
        guard let shownSnapshot = currentSuggestionState.acceptanceSnapshot else {
            return .block(.missingShownSnapshot)
        }

        if allowObsidianSnapshotFastPath,
           obsidianAcceptanceSnapshotMatchesShown(shownSnapshot) {
            recordObsidianSnapshotFastPath(stage: "acceptance")
            return .allow
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
        guard let frontmostApp = accessibilityClient.frontmostApplication(),
              let profile = effectiveProfile(for: frontmostApp) else {
            return nil
        }

        guard frontmostAppMatchesSuggestion(
            frontmostApp,
            expectedBundleIdentifier: shownIdentity.bundleIdentifier,
            profile: profile
        ),
            frontmostApp.processIdentifier == shownIdentity.processIdentifier else {
            blockReason = .appChanged
            return nil
        }

        guard let rawContext = accessibilityClient.focusedTextContext(
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

        guard browserHostedSurfacePolicy.decision(
            bundleIdentifier: frontmostApp.bundleIdentifier,
            fingerprint: rawContext.fingerprint
        ).canSuggest else {
            blockReason = .currentBecameSuppressedField
            return nil
        }

        let context = presentationAdjustedContext(
            rawContext,
            app: frontmostApp,
            profile: profile,
            previousSnapshot: lastTextSnapshot
        )
        let rawFieldClassification = fieldClassification(for: context)
        let acceptanceFieldClassification = effectiveSuggestionFieldClassification(
            app: frontmostApp,
            context: context,
            profile: profile,
            raw: rawFieldClassification
        )
        if acceptanceFieldClassification.suppressesSuggestionsByDefault {
            blockReason = .currentBecameSuppressedField
            return nil
        }

        return SuggestionAcceptanceSnapshot(
            fieldIdentity: fieldIdentity(
                app: frontmostApp,
                context: context,
                profile: profile
            ),
            targetFingerprint: targetFingerprint(context: context),
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            selectedTextLength: context.selectedTextLength
        )
    }

    private func recordAcceptanceGuardBlock(reason: SuggestionAcceptanceBlockReason) {
        guard suggestionSession.hasVisibleSuggestion,
              let suggestionID = currentSuggestionState.id else {
            return
        }

        RawAutocompleteTraceLog.shared.record(
            type: .suggestionSuppressed,
            suggestionID: suggestionID,
            appBundleIdentifier: currentSuggestionState.appBundleIdentifier ?? currentProfile?.bundleIdentifier ?? "",
            fieldIdentity: currentSuggestionState.fieldIdentity?.traceDescription ?? "",
            requestMode: currentSuggestionState.requestMode?.rawValue ?? "",
            displayedText: currentSuggestionState.displayedText ?? suggestionSession.visibleSuggestion?.visibleText ?? "",
            reason: "wrong-app-or-field-before-accept",
            metadata: [
                "acceptanceGuardReason": reason.rawValue,
                "doNotShip": "true",
                "focusMismatch": String(reason.isFocusMismatch),
                "severe": "true"
            ]
        )
    }


    private func focusedFieldMatchesCurrentSuggestion(
        allowObsidianSnapshotFastPath: Bool = false
    ) -> Bool {
        if allowObsidianSnapshotFastPath,
           obsidianSnapshotMatchesCurrentSuggestion() {
            recordObsidianSnapshotFastPath(stage: "focus")
            return true
        }

        guard let currentSuggestionAppBundleIdentifier = currentSuggestionState.appBundleIdentifier,
              let currentSuggestionFieldIdentity = currentSuggestionState.fieldIdentity,
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
              promptTextAreaMatch(
                  for: frontmostApp.bundleIdentifier,
                  context: rawContext
              ).canSuggest,
              browserHostedSurfacePolicy.decision(
                  bundleIdentifier: frontmostApp.bundleIdentifier,
                  fingerprint: rawContext.fingerprint
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





    private func obsidianSnapshotMatchesCurrentSuggestion() -> Bool {
        let bundleIdentifier = "md.obsidian"
        guard currentSuggestionState.appBundleIdentifier == bundleIdentifier,
              suggestionSession.hasVisibleSuggestion,
              let currentProfile,
              currentProfile.bundleIdentifier == bundleIdentifier,
              let currentSuggestionFieldIdentity = currentSuggestionState.fieldIdentity,
              let lastTextSnapshot,
              lastTextSnapshot.fieldIdentity == currentSuggestionFieldIdentity,
              let suggestionAgeMilliseconds = currentSuggestionAgeMilliseconds(),
              suggestionAgeMilliseconds <= 5_000,
              let frontmostApp = accessibilityClient.frontmostApplication(),
              frontmostApp.bundleIdentifier == bundleIdentifier,
              frontmostApp.processIdentifier == currentSuggestionFieldIdentity.processIdentifier else {
            return false
        }

        return true
    }

    private func obsidianAcceptanceSnapshotMatchesShown(
        _ shownSnapshot: SuggestionAcceptanceSnapshot
    ) -> Bool {
        guard obsidianSnapshotMatchesCurrentSuggestion(),
              let currentSuggestionFieldIdentity = currentSuggestionState.fieldIdentity,
              let lastTextSnapshot,
              shownSnapshot.fieldIdentity == currentSuggestionFieldIdentity,
              shownSnapshot.fieldIdentity == lastTextSnapshot.fieldIdentity,
              shownSnapshot.selectedTextLength == 0 else {
            return false
        }

        if shownSnapshot.textBeforeCursor == lastTextSnapshot.textBeforeCursor,
           shownSnapshot.textAfterCursor == lastTextSnapshot.textAfterCursor {
            return true
        }

        return visibleSuggestionPersistencePolicy.shouldPreserveAfterActivationBlock(
            blockReason: .tooLittleContext,
            appBundleIdentifier: "md.obsidian",
            fieldIdentity: currentSuggestionFieldIdentity,
            currentSuggestionBundleIdentifier: currentSuggestionState.appBundleIdentifier,
            currentSuggestionFieldIdentity: currentSuggestionFieldIdentity,
            currentSuggestionTextBeforeCursor: shownSnapshot.textBeforeCursor,
            currentSuggestionAgeMilliseconds: currentSuggestionAgeMilliseconds(),
            isInvalidatedByUserTyping: currentSuggestionState.invalidatedByUserKeyDown,
            textBeforeCursor: lastTextSnapshot.textBeforeCursor,
            textAfterCursor: lastTextSnapshot.textAfterCursor
        )
    }

    private func recordObsidianSnapshotFastPath(stage: String) {
        DiagnosticsLog.shared.record(
            "obsidian-snapshot-fast-path",
            metadata: [
                "app": "md.obsidian",
                "stage": stage,
                "fieldIdentity": currentSuggestionState.fieldIdentity?.traceDescription ?? "",
                "requestMode": currentSuggestionState.requestMode?.rawValue ?? "",
                "suggestionAgeMilliseconds": currentSuggestionAgeMilliseconds().map(String.init) ?? "unknown"
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
                "app": currentSuggestionState.appBundleIdentifier ?? currentProfile?.bundleIdentifier ?? "unknown",
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
        guard acceptedInsertionUndoRecoveryMode == .appRollback else {
            return false
        }

        guard let pendingAcceptedInsertionUndo else {
            return false
        }

        return pendingAcceptedInsertionUndo.expiresAt > now
    }

    private func armAcceptedInsertionUndo(
        acceptedText: String,
        acceptanceID: String,
        acceptedAt: Date,
        acceptMode: String
    ) {
        guard let currentFieldIdentity,
              let lastTextSnapshot,
              lastTextSnapshot.fieldIdentity == currentFieldIdentity,
              let appBundleIdentifier = currentSuggestionState.appBundleIdentifier ?? currentProfile?.bundleIdentifier else {
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
            acceptMode: acceptMode,
            acceptedAt: acceptedAt,
            expiresAt: expiresAt
        )
        DiagnosticsLog.shared.record(
            "accepted-insertion-undo-armed",
            metadata: [
                "acceptanceID": acceptanceID,
                "app": appBundleIdentifier,
                "fieldIdentity": currentFieldIdentity.traceDescription,
                "acceptMode": acceptMode,
                "undoMechanism": acceptedInsertionUndoRecoveryMode.traceMechanism.rawValue,
                "appRollbackEnabled": String(acceptedInsertionUndoRecoveryMode == .appRollback),
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




    private func completeNextWordAcceptance(
        acceptedText: String,
        acceptanceID: String,
        acceptedAt: Date,
        action: KeyboardAction,
        acceptanceProof: AcceptanceReceipt,
        verificationBaseline: InsertionVerificationBaseline?,
        residualReason: String = "Accepted: next word; showing remainder",
        emptyReason: String = "accepted-next-word"
    ) {
        armAcceptedInsertionUndo(
            acceptedText: acceptedText,
            acceptanceID: acceptanceID,
            acceptedAt: acceptedAt,
            acceptMode: action.diagnosticName
        )
        suggestionSession.commitNextWordAcceptance(acceptedText)
        recordAcceptedText(acceptedText)
        armObsidianPostAcceptanceSuppressionIfNeeded()
        advanceCurrentSuggestionBaseline(afterAccepting: acceptedText)
        suggestionRepetitionSuppressor.recordAcceptance(
            acceptedText,
            mode: currentSuggestionState.requestMode,
            scope: currentSuggestionState.appBundleIdentifier ?? currentProfile?.bundleIdentifier ?? ""
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
            suggestionID: currentSuggestionState.id ?? "",
            reason: action.diagnosticName
        )
        refreshAfterNextWordAcceptance(
            residualReason: residualReason,
            emptyReason: emptyReason
        )
        scheduleInsertionVerification(acceptedText: acceptedText, baseline: verificationBaseline)
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
                "reason": reason,
                "acceptMode": pendingAcceptedInsertionUndo.acceptMode,
                "undoMechanism": acceptedInsertionUndoRecoveryMode.traceMechanism.rawValue
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
        suggestionPipeline.pausePolling(
            now: Date(),
            durationMilliseconds: postInsertionPollPauseMilliseconds
        )
        DiagnosticsLog.shared.record(
            "accepted-insertion-undone",
            metadata: [
                "acceptanceID": undo.acceptanceID,
                "app": undo.appBundleIdentifier,
                "fieldIdentity": undo.fieldIdentity.traceDescription,
                "acceptMode": undo.acceptMode,
                "undoMechanism": acceptedInsertionUndoRecoveryMode.traceMechanism.rawValue,
                "restoredOriginalTarget": "true",
                "acceptedTextLength": String(undo.acceptedTextLength),
                "restoredTextLength": String(restoredText.count)
            ]
        )
        RawAutocompleteTraceLog.shared.record(
            type: .acceptedInsertionUndone,
            suggestionID: "",
            appBundleIdentifier: undo.appBundleIdentifier,
            fieldIdentity: undo.fieldIdentity.traceDescription,
            outcome: undo.acceptMode,
            reason: "accepted-insertion-undone",
            metadata: [
                "acceptanceID": undo.acceptanceID,
                "acceptMode": undo.acceptMode,
                "undoMechanism": acceptedInsertionUndoRecoveryMode.traceMechanism.rawValue,
                "restoredOriginalTarget": "true",
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
                    "undoMechanism": self.acceptedInsertionUndoRecoveryMode.traceMechanism.rawValue,
                    "restoredOriginalTarget": "true",
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
        action: KeyboardAction?,
        acceptMode: String
    ) -> InsertionVerificationBaseline? {
        guard let currentFieldIdentity,
              let lastTextSnapshot,
              lastTextSnapshot.fieldIdentity == currentFieldIdentity,
              let currentSuggestionAcceptanceSnapshot = currentSuggestionState.acceptanceSnapshot,
              let profile = currentProfile else {
            return nil
        }
        let fieldClassification = currentSuggestionState.fieldClassification
        let fieldKind = fieldClassification?.kind ?? .unknown
        let behaviorProfileID = suggestionOrchestrator.currentRequest?.behaviorProfile.id
            ?? AutocompleteBehaviorProfileResolver().profile(for: AutocompleteBehaviorProfileInput(
                appBundleIdentifier: profile.bundleIdentifier,
                fieldKind: fieldKind,
                currentLineStructure: CurrentLineStructure.from(textBeforeCursor: lastTextSnapshot.textBeforeCursor)
            )).id

        return InsertionVerificationBaseline(
            fieldIdentity: currentFieldIdentity,
            targetFingerprint: currentSuggestionAcceptanceSnapshot.targetFingerprint.postInsertionScope,
            previousTextBeforeCursor: lastTextSnapshot.textBeforeCursor,
            previousTextAfterCursor: lastTextSnapshot.textAfterCursor,
            profile: profile,
            suggestionID: currentSuggestionState.id,
            requestMode: currentSuggestionState.requestMode,
            acceptanceID: acceptanceID,
            acceptedAt: acceptedAt,
            action: action,
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

            let verificationContextRead = focusedInsertionVerificationContext(
                for: baseline,
                acceptedText: acceptedText
            )
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

            if baseline.profile.bundleIdentifier == "md.obsidian",
               obsidianInsertionVerificationFastPathPolicy.canVerifyLengthMatchedSuffix(
                   previousTextBeforeCursor: baseline.previousTextBeforeCursor,
                   acceptedText: acceptedText,
                   currentTextBeforeCursor: context.textBeforeCursor,
                   previousTextAfterCursor: baseline.previousTextAfterCursor,
                   currentTextAfterCursor: context.textAfterCursor,
                   verificationResult: result
               ) {
                result = .verified
                DiagnosticsLog.shared.record(
                    "obsidian-length-matched-insert-verification-fast-path",
                    metadata: [
                        "app": baseline.profile.bundleIdentifier,
                        "acceptedChars": String(acceptedText.count),
                        "previousBeforeChars": String(baseline.previousTextBeforeCursor.count),
                        "currentBeforeChars": String(context.textBeforeCursor.count),
                        "reason": "length-matched-suffix"
                    ]
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
                        "source": "obsidian-length-matched-suffix"
                    ]
                )
            }

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

                if case let .ready(context: recheckContext) = focusedInsertionVerificationContext(
                    for: baseline,
                    acceptedText: acceptedText
                ) {
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
                    if insertAcceptedText(
                        acceptedText,
                        skippingInsertionModes: skippedModes,
                        action: baseline.action
                    ) {
                        let retryBaseline = InsertionVerificationBaseline(
                            fieldIdentity: baseline.fieldIdentity,
                            targetFingerprint: baseline.targetFingerprint,
                            previousTextBeforeCursor: baseline.previousTextBeforeCursor,
                            previousTextAfterCursor: baseline.previousTextAfterCursor,
                            profile: baseline.profile,
                            suggestionID: baseline.suggestionID,
                            requestMode: baseline.requestMode,
                            acceptanceID: baseline.acceptanceID,
                            acceptedAt: baseline.acceptedAt,
                            action: baseline.action,
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
                    ].merging(insertionFailureRecoverabilityMetadata(baseline: baseline)) { current, _ in current }
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
                    ].merging(insertionFailureRecoverabilityMetadata(baseline: baseline)) { current, _ in current }
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
                    suppressField(
                        baseline.fieldIdentity,
                        profile: baseline.profile,
                        reason: "insert-verification-failed"
                    )
                }
                hideSuggestion(reason: "insert-verification-failed")
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
                textBeforeCursorAtAccept: baseline.previousTextBeforeCursor,
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
            ].merging(insertionFailureRecoverabilityMetadata(baseline: baseline)) { current, _ in current }
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
            ].merging(insertionFailureRecoverabilityMetadata(baseline: baseline)) { current, _ in current }
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
        hideSuggestion(
            reason: "insert-verification-failed",
            metadata: ["insertionFailureReason": reason]
        )
    }

    private func focusedInsertionVerificationContext(
        for baseline: InsertionVerificationBaseline,
        acceptedText: String
    ) -> FocusedInsertionVerificationContext {
        guard let frontmostApp = accessibilityClient.frontmostApplication() else {
            return .missingContext
        }

        guard let context = accessibilityClient.focusedTextContext(
            allowDescendantTextFallback: baseline.profile.allowsDescendantTextFallback
        ) else {
            if let context = obsidianDescendantInsertionVerificationContext(
                baseline: baseline,
                acceptedText: acceptedText,
                frontmostApp: frontmostApp,
                reason: "missing-focused-context"
            ) {
                return .ready(context: context)
            }
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
            if let context = recoveredInsertionVerificationContext(
                adjustedContext,
                acceptedText: acceptedText,
                baseline: baseline,
                frontmostApp: frontmostApp,
                mismatch: .fieldIdentity
            ) {
                return .ready(context: context)
            }
            if let context = obsidianDescendantInsertionVerificationContext(
                baseline: baseline,
                acceptedText: acceptedText,
                frontmostApp: frontmostApp,
                reason: "field-changed"
            ) {
                return .ready(context: context)
            }
            return .fieldChanged
        }

        let currentTargetFingerprint = targetFingerprint(context: adjustedContext).postInsertionScope
        guard baseline.targetFingerprint.matches(currentTargetFingerprint) else {
            if baseline.profile.appFamily == .chromium,
               baseline.fieldKind == .multilineCompose,
               baseline.targetFingerprint.matchesPostInsertionScopeAllowingElementHeightChange(currentTargetFingerprint) {
                DiagnosticsLog.shared.record(
                    "insert-verification-target-resize-allowed",
                    metadata: [
                        "app": baseline.profile.bundleIdentifier,
                        "fieldKind": baseline.fieldKind.rawValue,
                        "reason": "chromium-rich-editor-height-reflow"
                    ]
                )
                return .ready(context: adjustedContext)
            }
            if let context = recoveredInsertionVerificationContext(
                adjustedContext,
                acceptedText: acceptedText,
                baseline: baseline,
                frontmostApp: frontmostApp,
                mismatch: .targetFingerprint
            ) {
                return .ready(context: context)
            }
            if let context = obsidianDescendantInsertionVerificationContext(
                baseline: baseline,
                acceptedText: acceptedText,
                frontmostApp: frontmostApp,
                reason: "target-fingerprint-changed"
            ) {
                return .ready(context: context)
            }
            return .targetFingerprintChanged
        }

        if let context = obsidianDescendantInsertionVerificationContext(
            baseline: baseline,
            acceptedText: acceptedText,
            frontmostApp: frontmostApp,
            reason: "same-field-stale-selection"
        ) {
            return .ready(context: context)
        }

        return .ready(context: adjustedContext)
    }


    private func recoveredInsertionVerificationContext(
        _ context: FocusedTextContext,
        acceptedText: String,
        baseline: InsertionVerificationBaseline,
        frontmostApp: RunningApplicationInfo,
        mismatch: InsertionVerificationContextMismatch
    ) -> FocusedTextContext? {
        let result = insertionVerification.verify(
            previousTextBeforeCursor: baseline.previousTextBeforeCursor,
            acceptedText: acceptedText,
            currentTextBeforeCursor: context.textBeforeCursor,
            previousTextAfterCursor: baseline.previousTextAfterCursor,
            currentTextAfterCursor: context.textAfterCursor
        )
        guard insertionVerificationContextRecoveryPolicy.canRecover(
            InsertionVerificationContextRecoveryInput(
                profile: baseline.profile,
                frontmostBundleIdentifier: frontmostApp.bundleIdentifier,
                frontmostProcessIdentifier: frontmostApp.processIdentifier,
                expectedFieldIdentity: baseline.fieldIdentity,
                contextRole: context.role,
                verificationResult: result,
                mismatch: mismatch,
                previousTextBeforeCursorUTF16Length: baseline.previousTextBeforeCursor.utf16.count,
                acceptedTextUTF16Length: acceptedText.utf16.count,
                currentTextBeforeCursorUTF16Length: context.textBeforeCursor.utf16.count
            )
        ) else {
            return nil
        }

        DiagnosticsLog.shared.record(
            "insert-verification-context-recovered",
            metadata: [
                "app": baseline.profile.bundleIdentifier,
                "acceptedChars": String(acceptedText.count),
                "mismatch": mismatch.rawValue,
                "role": context.role ?? "unknown",
                "result": String(describing: result)
            ]
        )
        return context
    }

    private func obsidianDescendantInsertionVerificationContext(
        baseline: InsertionVerificationBaseline,
        acceptedText: String,
        frontmostApp: RunningApplicationInfo,
        reason: String
    ) -> FocusedTextContext? {
        let bundleIdentifier = "md.obsidian"
        guard baseline.profile.bundleIdentifier == bundleIdentifier,
              frontmostApp.bundleIdentifier == bundleIdentifier,
              frontmostApp.processIdentifier == baseline.fieldIdentity.processIdentifier,
              !acceptedText.isEmpty,
              !baseline.previousTextBeforeCursor.isEmpty else {
            return nil
        }

        let expectedText = baseline.previousTextBeforeCursor + acceptedText + baseline.previousTextAfterCursor
        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        guard Self.axTextAreaDescendant(
            in: appElement,
            matchingValue: expectedText,
            containing: baseline.previousTextBeforeCursor,
            maxDepth: 32
        ) != nil else {
            return nil
        }

        DiagnosticsLog.shared.record(
            "obsidian-descendant-insert-verification-fast-path",
            metadata: [
                "app": bundleIdentifier,
                "acceptedChars": String(acceptedText.count),
                "previousBeforeChars": String(baseline.previousTextBeforeCursor.count),
                "previousAfterChars": String(baseline.previousTextAfterCursor.count),
                "reason": reason
            ]
        )
        return FocusedTextContext(
            elementIdentifier: baseline.fieldIdentity.elementIdentifier,
            role: "AXTextArea",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(),
            textBeforeCursor: baseline.previousTextBeforeCursor + acceptedText,
            textAfterCursor: baseline.previousTextAfterCursor,
            selectedText: "",
            selectedTextLength: 0,
            caretRect: nil,
            elementRect: nil,
            windowRect: nil,
            windowIdentifier: nil,
            textLineRect: nil,
            textStyle: nil,
            isSecure: false,
            fieldClassification: AXFieldClassification(kind: baseline.fieldKind, reason: baseline.fieldKindReason),
            caretIsSynthetic: true,
            capabilities: FocusedTextCapabilities(
                canReadValue: true,
                canReadSelectedTextRange: true,
                canReadBoundsForRange: false,
                canReadAttributedText: false,
                canSetSelectedText: true
            )
        )
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
                (.thirtySeconds, .seconds(20)),
                (.oneMinute, .seconds(30)),
                (.fiveMinutes, .seconds(240))
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
            if checkpoint.isTerminalMetricCheckpoint {
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
        if result.shouldRecordAcceptedThenDeleted {
            metadata.merge(recordAcceptedThenDeletedCooldown(for: result.tracker)) { current, _ in current }
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

    private func recordAcceptedThenDeletedCooldown(
        for tracker: AcceptanceSurvivalTracker
    ) -> [String: String] {
        recordPrefixFamilyCooldown(
            .acceptedThenDeleted,
            input: PrefixFamilyCooldownInput(
                appBundleIdentifier: tracker.appBundleIdentifier,
                fieldIdentifier: tracker.fieldIdentity.traceDescription,
                requestMode: CompletionRequestMode(rawValue: tracker.requestMode),
                textBeforeCursor: tracker.textBeforeCursorAtAccept
            )
        )
    }

    private func recordInsertionVerificationFailure(
        acceptedText: String,
        baseline: InsertionVerificationBaseline,
        outcome: String,
        reason: String,
        metadata: [String: String]
    ) {
        RawAutocompleteTraceLog.shared.record(
            type: .insertionFailed,
            suggestionID: baseline.suggestionID ?? "",
            appBundleIdentifier: baseline.profile.bundleIdentifier,
            fieldIdentity: baseline.fieldIdentity.traceDescription,
            requestMode: baseline.requestMode?.rawValue ?? "",
            acceptedText: acceptedText,
            outcome: outcome,
            reason: reason,
            metadata: metadata
                .merging([
                    "previousBeforeChars": String(baseline.previousTextBeforeCursor.count),
                    "previousAfterChars": String(baseline.previousTextAfterCursor.count)
                ]) { current, _ in current }
                .merging(insertionFailureRecoverabilityMetadata(baseline: baseline)) { current, _ in current }
        )
    }

    private func recordInsertionVerificationPreflightFailure(
        acceptedText: String,
        baseline: InsertionVerificationBaseline,
        currentContext: InsertionVerificationPreflightContext
    ) {
        let decision = insertionVerificationPreflightPolicy.decision(
            expectedFieldIdentity: baseline.fieldIdentity,
            currentContext: currentContext
        )
        guard let reason = decision.failureReason else {
            return
        }

        var metadata = insertionVerificationPreflightMetadata(
            baseline: baseline,
            currentContext: currentContext
        )
        metadata["acceptedChars"] = String(acceptedText.count)
        metadata["retryCount"] = String(baseline.retryCount)
        metadata["result"] = reason.rawValue
        metadata.merge(insertionFailureRecoverabilityMetadata(baseline: baseline)) { current, _ in current }

        DiagnosticsLog.shared.record(
            "insert-verification-final-failure",
            metadata: metadata
        )
        RawAutocompleteTraceLog.shared.record(
            type: .insertionFailed,
            suggestionID: baseline.suggestionID ?? "",
            appBundleIdentifier: baseline.profile.bundleIdentifier,
            fieldIdentity: baseline.fieldIdentity.traceDescription,
            requestMode: baseline.requestMode?.rawValue ?? "",
            acceptedText: acceptedText,
            outcome: reason.rawValue,
            reason: reason.rawValue,
            metadata: metadata
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
            reason: reason.rawValue,
            metadata: metadata
        )

        if baseline.profile.suppressesAfterInsertionFailure {
            suppressField(
                baseline.fieldIdentity,
                profile: baseline.profile,
                reason: reason.rawValue
            )
        }
        hideSuggestion(
            reason: "insert-verification-failed",
            metadata: ["insertionFailureReason": reason.rawValue]
        )
    }

    private func insertionVerificationPreflightMetadata(
        baseline: InsertionVerificationBaseline,
        currentContext: InsertionVerificationPreflightContext
    ) -> [String: String] {
        var metadata = [
            "app": baseline.profile.bundleIdentifier,
            "expectedFieldIdentity": baseline.fieldIdentity.traceDescription
        ]

        switch currentContext {
        case .missingFrontmostApplication:
            metadata["currentApp"] = "missing"
            metadata["currentFieldIdentity"] = "missing"
        case let .frontmostApplication(bundleIdentifier, fieldIdentity):
            metadata["currentApp"] = bundleIdentifier
            metadata["currentFieldIdentity"] = fieldIdentity?.traceDescription ?? "missing"
        }

        return metadata
    }

    private func insertionFailureRecoverabilityMetadata(
        baseline: InsertionVerificationBaseline
    ) -> [String: String] {
        let rollbackAvailable = pendingAcceptedInsertionUndo?.acceptanceID == baseline.acceptanceID
            && acceptedInsertionUndoIsActive()
        return InsertionUndoRecoverabilityModel().failureMetadata(
            profile: baseline.profile,
            acceptMode: baseline.acceptMode,
            rollbackAvailable: rollbackAvailable,
            rollbackMechanism: rollbackAvailable
                ? acceptedInsertionUndoRecoveryMode.traceMechanism
                : nil
        )
    }

    private func scheduleSuggestion(
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity,
        fieldClassification: AXFieldClassification,
        renderMode: SuggestionRenderMode,
        delayMilliseconds: Int,
        timingLane: SuggestionTimingLane,
        requestMode: CompletionRequestMode,
        typingBurstDecision: TypingBurstDecision = .idle,
        triggerReason: String = "poll"
    ) {
        cancelPrefixCooldownRetry()
        cancelPendingSuggestionTask(reason: "new-request")
        lastRequestedTextBeforeCursor = context.textBeforeCursor

        let orchestration = suggestionOrchestrator.beginRequest(SuggestionRequestInput(
            context: context,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentity,
            fieldClassification: fieldClassification,
            maxVisibleWords: maxVisibleWords(for: requestMode, profile: profile),
            requestMode: requestMode,
            suggestionTuning: suggestionTuning
        ))
        let request = orchestration.request
        let suggestionID = orchestration.suggestionID
        let fieldIdentityDescription = orchestration.fieldIdentityDescription
        let requestMetadata = orchestration.requestMetadata
            .merging(timingLane.traceMetadata) { current, _ in current }
        suggestionOrchestrator.startStreamingPresentation(suggestionID: suggestionID)
        let requestTicket = orchestration.ticket
        let requestStartedAt = orchestration.startedAt
        let requestSchedule = suggestionRequestSchedulingPolicy.schedule(
            policyDelayMilliseconds: delayMilliseconds,
            timingLane: timingLane,
            requestMode: request.mode,
            renderMode: renderMode
        )
        let typingBurstMetadata: [String: String] = typingBurstDecision == .idle
            ? [:]
            : typingBurstDecision.traceMetadata

        RawAutocompleteTraceLog.shared.record(
            type: .suggestionRequested,
            suggestionID: suggestionID,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentityDescription,
            requestMode: request.mode.rawValue,
            triggerReason: triggerReason,
            textBeforeCursor: request.textBeforeCursor,
            textAfterCursor: request.textAfterCursor,
            metadata: [
                "renderMode": renderMode.rawValue
            ]
            .merging(typingBurstMetadata) { current, _ in current }
            .merging(requestSchedule.traceMetadata) { current, _ in current }
            .merging(requestMetadata) { current, _ in current }
        )

        if requestMode == .wordCompletion {
            let allowPredictiveFallback = shouldUsePredictiveWordFallback(
                profile: profile
            )
            let fastSelection = suggestionOrchestrator.fastWordSelection(
                for: context.textBeforeCursor,
                allowPredictiveFallback: allowPredictiveFallback
            )
            let fastSelectionMetadata = fastSelection.traceMetadata
                .merging(timingLane.traceMetadata) { current, _ in current }
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
                    setSuggestionDecision(SuggestionStatusText.notShown(reason: "repeated-miss"))
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
                    requestTicket: requestTicket,
                    candidateSelectionMetadata: fastSelectionMetadata,
                    refreshBeforePresenting: false
                )
                return
            }

            if timingLane == .instantWord {
                let reason = "instant-word-no-local-candidate"
                RawAutocompleteTraceLog.shared.record(
                    type: .suggestionSuppressed,
                    suggestionID: suggestionID,
                    appBundleIdentifier: appBundleIdentifier,
                    fieldIdentity: fieldIdentityDescription,
                    requestMode: request.mode.rawValue,
                    triggerReason: "fast-word-completion",
                    textBeforeCursor: request.textBeforeCursor,
                    textAfterCursor: request.textAfterCursor,
                    reason: reason,
                    metadata: [
                        "renderMode": renderMode.rawValue
                    ]
                    .merging(timingLane.traceMetadata) { current, _ in current }
                    .merging(fastSelectionMetadata) { current, _ in current }
                    .merging(requestMetadata) { current, _ in current }
                )
                if suggestionSession.hasVisibleSuggestion {
                    setSuggestionDecision("Shown: no instant word replacement")
                    repositionVisibleSuggestion(context: context, profile: profile)
                    return
                }

                setSuggestionDecision("Waiting: no instant word match")
                hideSuggestion()
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
            if shouldAskModelForWordCompletionFallback() {
                setSuggestionDecision("Queued: model word completion")
            } else if suggestionSession.hasVisibleSuggestion {
                setSuggestionDecision("Shown: no fast word replacement")
                repositionVisibleSuggestion(context: context, profile: profile)
                return
            } else {
                setSuggestionDecision(SuggestionStatusText.notShown(reason: "no-fast-word-candidate"))
                hideSuggestion()
                return
            }
        }

        var fastPhraseFallbackMetadata: [String: String] = [:]
        var didPresentFastPhraseFallback = false
        if requestMode == .phraseContinuation {
            let allowsPredictivePhraseFallback = shouldUsePredictivePhraseFallback(
                profile: profile,
                behaviorProfileID: request.behaviorProfileID
            )
            let fastSelection = suggestionOrchestrator.fastPhraseSelection(
                for: context.textBeforeCursor,
                behaviorProfileID: request.behaviorProfileID,
                maxVisibleWords: request.maxVisibleWords,
                allowPredictiveFallback: allowsPredictivePhraseFallback
            )
            let fastSelectionMetadata = fastSelection.traceMetadata
                .merging(timingLane.traceMetadata) { current, _ in current }
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
                        triggerReason: "canned-bridge",
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
                            "triggerReason": "canned-bridge"
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
                    setSuggestionDecision(SuggestionStatusText.notShown(reason: "repeated-miss"))
                    hideSuggestion()
                    return
                }

                let fastPresentationMetadata = fastSelectionMetadata
                presentSuggestion(
                    fastSuggestion,
                    suggestionID: suggestionID,
                    request: request,
                    context: context,
                    profile: profile,
                    fieldIdentity: fieldIdentity,
                    renderMode: renderMode,
                    latencyMilliseconds: 0,
                    triggerReason: "canned-bridge",
                    requestTicket: requestTicket,
                    candidateSelectionMetadata: fastPresentationMetadata,
                    refreshBeforePresenting: false
                )
                didPresentFastPhraseFallback = suggestionSession.hasVisibleSuggestion
                    && currentSuggestionState.id == suggestionID
                fastPhraseFallbackMetadata = [
                    "fastPhraseFallbackChecked": "true",
                    "fastPhraseFallbackOutcome": didPresentFastPhraseFallback
                        ? "shown-then-model"
                        : "presentation-blocked-model-only",
                    "fastPhraseFallbackVisibleWords": String(fastSuggestion.visibleWordCount)
                ]
                .merging(fastPresentationMetadata) { current, _ in current }
                if didPresentFastPhraseFallback {
                    setSuggestionDecision("Shown: instant phrase; refining with model")
                }
            }

            let fastPhraseFallbackOutcome = fastSelection.suppressionReason ?? "no-suggestion"
            if fastPhraseFallbackMetadata.isEmpty {
                fastPhraseFallbackMetadata = [
                    "fastPhraseFallbackChecked": "true",
                    "fastPhraseFallbackOutcome": fastPhraseFallbackOutcome
                ]
                .merging(fastSelectionMetadata) { current, _ in current }
                setSuggestionDecision("Queued: model phrase after instant \(fastPhraseFallbackOutcome)")
            }
        }

        if typingBurstDecision.shouldSuppress(requestMode: requestMode) {
            if didPresentFastPhraseFallback {
                let metadata = [
                    "renderMode": renderMode.rawValue,
                    "reason": "typing-burst-model-continuation-kept-fast-phrase"
                ]
                .merging(fieldClassification.traceMetadata) { current, _ in current }
                .merging(typingBurstMetadata) { current, _ in current }
                .merging(fastPhraseFallbackMetadata) { current, _ in current }
                .merging(requestMetadata) { current, _ in current }
                setSuggestionDecision("Shown: instant phrase while typing fast")
                showFieldStatusIndicator(.shown, context: context)
                RawAutocompleteTraceLog.shared.record(
                    type: .suggestionSuppressed,
                    suggestionID: suggestionID,
                    appBundleIdentifier: appBundleIdentifier,
                    fieldIdentity: fieldIdentityDescription,
                    requestMode: request.mode.rawValue,
                    triggerReason: "typing-burst-policy",
                    textBeforeCursor: request.textBeforeCursor,
                    textAfterCursor: request.textAfterCursor,
                    reason: "typing-burst-model-continuation-kept-fast-phrase",
                    metadata: metadata
                )
                recordSuggestionEvent(
                    "suggestion-blocked",
                    context: context,
                    profile: profile,
                    metadata: metadata
                )
                repositionVisibleSuggestion(context: context, profile: profile)
                updateKeyboardEventTapSnapshot()
                return
            }

            let metadata = [
                "renderMode": renderMode.rawValue,
                "reason": "typing-burst-model-continuation"
            ]
            .merging(fieldClassification.traceMetadata) { current, _ in current }
            .merging(typingBurstMetadata) { current, _ in current }
            .merging(fastPhraseFallbackMetadata) { current, _ in current }
            .merging(requestMetadata) { current, _ in current }
            setSuggestionDecision("Waiting: fast typing")
            showFieldStatusIndicator(.waiting, context: context)
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: suggestionID,
                appBundleIdentifier: appBundleIdentifier,
                fieldIdentity: fieldIdentityDescription,
                requestMode: request.mode.rawValue,
                triggerReason: "typing-burst-policy",
                textBeforeCursor: request.textBeforeCursor,
                textAfterCursor: request.textAfterCursor,
                reason: "typing-burst-model-continuation",
                metadata: metadata
            )
            recordBlockedSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                metadata: metadata
            )
            hideSuggestion(reason: "typing-burst", metadata: typingBurstMetadata)
            return
        }

        recordSuggestionEvent(
            "suggestion-request-scheduled",
            context: context,
            profile: profile,
            metadata: [
                "requestMode": request.mode.rawValue,
                "triggerReason": triggerReason,
                "traceID": String(suggestionID.prefix(8)),
                "suggestionID": suggestionID
            ]
            .merging(typingBurstMetadata) { current, _ in current }
            .merging(fastPhraseFallbackMetadata) { current, _ in current }
            .merging(requestSchedule.traceMetadata) { current, _ in current }
            .merging(requestMetadata) { current, _ in current }
        )
        debounceTaskSuggestionID = suggestionID
        debounceTask = Task { [suggestionOrchestrator, requestTicket, fieldIdentity, requestSchedule] in
            try? await Task.sleep(for: .milliseconds(requestSchedule.scheduledDelayMilliseconds))
            guard !Task.isCancelled else {
                await MainActor.run {
                    self.clearCompletedSuggestionTask(suggestionID: suggestionID)
                }
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
                                nowMilliseconds: Int(ProcessInfo.processInfo.systemUptime * 1000),
                                latencyMilliseconds: latencyMilliseconds
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
                                triggerReason: "model-stream",
                                requestTicket: requestTicket,
                                candidateSelectionMetadata: self.suggestionOrchestrator
                                    .streamingPresentationMetadata(suggestionID: suggestionID)
                            )
                        }
                    }
                )
                await MainActor.run {
                    let latencyMilliseconds = max(0, Int(Date().timeIntervalSince(requestStartedAt) * 1000))
                    self.suggestionOrchestrator.finishStreamingPresentation(suggestionID: suggestionID)
                    guard self.suggestionOrchestrator.allows(
                        requestTicket,
                        fieldIdentity: fieldIdentity,
                        currentFieldIdentity: self.currentFieldIdentity
                    ) else {
                        return
                    }

                    if self.suggestionRequestSchedulingPolicy.shouldSuppressResult(
                        latencyMilliseconds: latencyMilliseconds,
                        schedule: requestSchedule
                    ) {
                        let shouldKeepStreamedSuggestion = self.suggestionOrchestrator.shouldKeepVisibleStreamingSuggestionAfterEmptyFinal(
                            suggestionID: suggestionID,
                            currentSuggestionID: self.currentSuggestionState.id,
                            ticket: requestTicket,
                            fieldIdentity: fieldIdentity,
                            currentFieldIdentity: self.currentFieldIdentity,
                            hasVisibleSuggestion: self.suggestionSession.hasVisibleSuggestion
                        )
                        let metadata = requestMetadata
                            .merging(requestSchedule.traceMetadata) { current, _ in current }
                            .merging([
                                "resultLatencyBudgetExceeded": "true",
                                "keptVisibleStreamingSuggestion": String(shouldKeepStreamedSuggestion)
                            ]) { current, _ in current }
                        RawAutocompleteTraceLog.shared.record(
                            type: .suggestionSuppressed,
                            suggestionID: suggestionID,
                            appBundleIdentifier: appBundleIdentifier,
                            fieldIdentity: fieldIdentityDescription,
                            requestMode: request.mode.rawValue,
                            triggerReason: "model-result",
                            textBeforeCursor: request.textBeforeCursor,
                            textAfterCursor: request.textAfterCursor,
                            cleanedVisibleText: suggestion?.visibleText ?? "",
                            displayedText: suggestion?.visibleText ?? "",
                            latencyMilliseconds: latencyMilliseconds,
                            reason: "latency-budget-exceeded",
                            metadata: metadata
                        )
                        self.recordSuggestionEvent(
                            "suggestion-blocked",
                            context: context,
                            profile: profile,
                            metadata: [
                                "reason": "latency-budget-exceeded"
                            ].merging(metadata) { current, _ in current }
                        )
                        if shouldKeepStreamedSuggestion {
                            self.setSuggestionDecision("Shown: kept streamed suggestion")
                            self.repositionVisibleSuggestion(context: context, profile: profile)
                            return
                        }

                        self.setSuggestionDecision(SuggestionStatusText.notShown(reason: "latency-budget-exceeded"))
                        self.hideSuggestion(reason: "latency-budget-exceeded")
                        return
                    }

                    let anchorRect = RenderModePlan.anchorRect(
                        for: renderMode,
                        caretRect: context.caretRect,
                        elementRect: context.elementRect,
                        windowRect: context.windowRect
                    )
                    guard let suggestion, !suggestion.isEmpty else {
                        let shouldKeepStreamedSuggestion = self.suggestionOrchestrator.shouldKeepVisibleStreamingSuggestionAfterEmptyFinal(
                            suggestionID: suggestionID,
                            currentSuggestionID: self.currentSuggestionState.id,
                            ticket: requestTicket,
                            fieldIdentity: fieldIdentity,
                            currentFieldIdentity: self.currentFieldIdentity,
                            hasVisibleSuggestion: self.suggestionSession.hasVisibleSuggestion
                        )
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
                            metadata: requestMetadata.merging([
                                "keptVisibleStreamingSuggestion": String(shouldKeepStreamedSuggestion)
                            ]) { current, _ in current }
                        )
                        self.recordSuggestionEvent(
                            "suggestion-blocked",
                            context: context,
                            profile: profile,
                            metadata: [
                                "reason": "empty-suggestion"
                            ]
                        )
                        if shouldKeepStreamedSuggestion {
                            self.setSuggestionDecision("Shown: kept streamed suggestion")
                            self.repositionVisibleSuggestion(context: context, profile: profile)
                            return
                        }

                        self.setSuggestionDecision(SuggestionStatusText.notShown(reason: "empty-suggestion"))
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
                        self.setSuggestionDecision(SuggestionStatusText.notShown(reason: "missing-anchor"))
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
                        self.setSuggestionDecision(SuggestionStatusText.notShown(reason: "repeated-miss"))
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
                        requestTicket: requestTicket,
                        candidateSelectionMetadata: appModelResultMetadata,
                        scheduledDelayMilliseconds: requestSchedule.scheduledDelayMilliseconds
                    )
                }
                await MainActor.run {
                    self.clearCompletedSuggestionTask(suggestionID: suggestionID)
                }
            } catch {
                await MainActor.run {
                    self.suggestionOrchestrator.finishStreamingPresentation(suggestionID: suggestionID)
                    self.clearCompletedSuggestionTask(suggestionID: suggestionID)
                    if self.suggestionOrchestrator.shouldKeepVisibleSuggestionAfterModelContinuationFailure(
                        suggestionID: suggestionID,
                        currentSuggestionID: self.currentSuggestionState.id,
                        ticket: requestTicket,
                        fieldIdentity: fieldIdentity,
                        currentFieldIdentity: self.currentFieldIdentity,
                        hasVisibleSuggestion: self.suggestionSession.hasVisibleSuggestion
                    ) {
                        self.setSuggestionDecision("Shown: kept instant phrase after model error")
                        self.repositionVisibleSuggestion(context: context, profile: profile)
                        self.updateKeyboardEventTapSnapshot()
                        return
                    }
                    guard self.suggestionOrchestrator.shouldHideVisibleSuggestionAfterFailure(
                        ticket: requestTicket,
                        failedRequestFieldIdentity: fieldIdentity,
                        currentFieldIdentity: self.currentFieldIdentity
                    ) else {
                        return
                    }
                    self.setSuggestionDecision(SuggestionStatusText.notShown(reason: "engine-error"))
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
        requestTicket: SuggestionRequestTicket? = nil,
        candidateSelectionMetadata: [String: String] = [:],
        refreshBeforePresenting: Bool = true,
        scheduledDelayMilliseconds: Int = 0
    ) {
        let originalContext = context
        let invalidatedByVisibleUserTyping = currentSuggestionState.invalidatedByUserKeyDown
            && currentSuggestionState.id == suggestionID
        let refreshedContext = refreshBeforePresenting
            ? refreshedPresentationContext(
                for: request,
                profile: profile,
                fieldIdentity: fieldIdentity
            )
            : (context: Optional(context), reason: nil)
        let verifiedRefreshContext = refreshBeforePresenting ? refreshedContext.context : nil
        let freshnessFieldIdentity = verifiedRefreshContext == nil
            ? currentFieldIdentity
            : fieldIdentity
        let freshnessSnapshot = verifiedRefreshContext.map {
            FocusedTextSnapshot(
                fieldIdentity: fieldIdentity,
                textBeforeCursor: $0.textBeforeCursor,
                textAfterCursor: $0.textAfterCursor
            )
        } ?? lastTextSnapshot
        if let suppressionReason = suggestionOrchestrator.presentationSuppressionReason(
            requestTicket: requestTicket,
            request: request,
            fieldIdentity: fieldIdentity,
            currentFieldIdentity: freshnessFieldIdentity,
            currentSnapshot: freshnessSnapshot,
            invalidatedByUserTyping: invalidatedByVisibleUserTyping
        ) {
            let reason = suppressionReason.rawValue
            let metadata = traceGeometryMetadata(context: originalContext, renderMode: renderMode)
                .merging(traceRequestMetadata(request: request, context: originalContext)) { current, _ in current }
                .merging(candidateSelectionMetadata) { current, _ in current }
                .merging([
                    "presentationFreshness": "stale",
                    "presentationFreshnessReason": reason,
                    "presentationFreshnessSource": verifiedRefreshContext == nil ? "cached-snapshot" : "live-refresh"
                ]) { current, _ in current }
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
                metadata: metadata
            )
            recordSuggestionEvent(
                "suggestion-blocked",
                context: originalContext,
                profile: profile,
                metadata: [
                    "reason": reason
                ]
                .merging(metadata) { current, _ in current }
            )
            hideSuggestion(reason: reason)
            return
        }

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
            setSuggestionDecision(SuggestionStatusText.notShown(reason: reason))
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

        let rawDisplayFieldClassification = fieldClassification(for: context)
        let displayFieldClassification = effectiveSuggestionFieldClassificationForCurrentFrontmost(
            context: context,
            profile: profile,
            raw: rawDisplayFieldClassification
        )
        let displayRequestMetadata = traceRequestMetadata(
            request: request,
            fieldClassification: displayFieldClassification
        )
        let isRepeatedMiss = suggestionRepetitionSuppressor.shouldSuppress(
            suggestion.visibleText,
            mode: request.mode,
            scope: request.appBundleIdentifier ?? profile.bundleIdentifier
        )
        // A final model result is "first visible" when nothing is already on screen for the user
        // to read — no instant local phrase and no streamed partial. In that case a slow result
        // would paint cold and late, so displayScoreDecision applies a tighter latency ceiling.
        // When a suggestion is already visible, the model result is a refinement and keeps the
        // looser budget so good late refinements can still replace the instant phrase in place.
        let modelIsFirstVisibleSuggestion = triggerReason == "model-result"
            && !suggestionSession.hasVisibleSuggestion
        let orchestratedDisplayDecision = suggestionOrchestrator.displayScoreDecision(
            suggestion: suggestion,
            request: request,
            context: context,
            fieldClassification: displayFieldClassification,
            profile: profile,
            fieldIdentity: fieldIdentity,
            triggerReason: triggerReason,
            latencyMilliseconds: latencyMilliseconds,
            isRepeatedMiss: isRepeatedMiss,
            displayScorePolicy: displayScorePolicy,
            suggestionTuning: suggestionTuning,
            modelIsFirstVisibleSuggestion: modelIsFirstVisibleSuggestion,
            scheduledDelayMilliseconds: scheduledDelayMilliseconds
        )
        let displayScoreDecision = orchestratedDisplayDecision.decision
        let displayScoreMetadata = orchestratedDisplayDecision.metadata
        let displayScoreTrace = displayScoreDecision.trace
        guard displayScoreDecision.shouldDisplay else {
            let reason = displayScoreMetadata["displayScoreSuppressionReason"] ?? "display-score"
            let displaySuppressionReason = DisplayScoreSuppressionReason(rawValue: reason)
            let shouldKeepStreamedSuggestion: Bool
            if displaySuppressionReason == .tooSlowToDisplay,
               let requestTicket {
                shouldKeepStreamedSuggestion = suggestionOrchestrator.shouldKeepVisibleStreamingSuggestionAfterEmptyFinal(
                    suggestionID: suggestionID,
                    currentSuggestionID: currentSuggestionState.id,
                    ticket: requestTicket,
                    fieldIdentity: fieldIdentity,
                    currentFieldIdentity: currentFieldIdentity,
                    hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion
                )
            } else {
                shouldKeepStreamedSuggestion = false
            }
            let visibleSuggestionAction = suggestionReplacementVisibilityPolicy.action(
                forDisplaySuppressionReason: displaySuppressionReason,
                hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion,
                currentSuggestionInvalidatedByUserTyping: currentSuggestionState.invalidatedByUserKeyDown,
                sameFieldAsCurrentSuggestion: currentSuggestionState.appBundleIdentifier == (request.appBundleIdentifier ?? profile.bundleIdentifier)
                    && currentSuggestionState.fieldIdentity == fieldIdentity,
                currentSuggestionAgeMilliseconds: currentSuggestionAgeMilliseconds(),
                maximumPreservedAgeMilliseconds: maximumPreservedSuggestionDisplaySuppressionAgeMilliseconds
            )
            let shouldKeepCurrentVisibleSuggestion = shouldKeepStreamedSuggestion
                || visibleSuggestionAction == .keepCurrentVisible
            var lateSuggestionMetadata: [String: String] = [:]
            if shouldKeepStreamedSuggestion {
                lateSuggestionMetadata["keptVisibleStreamingSuggestion"] = "true"
            }
            if visibleSuggestionAction == .keepCurrentVisible {
                lateSuggestionMetadata["keptVisibleSuggestionAfterLateSuppression"] = "true"
                lateSuggestionMetadata["lateSuppressionPreservedAgeMilliseconds"] =
                    currentSuggestionAgeMilliseconds().map(String.init) ?? "unknown"
            }
            setSuggestionDecision(SuggestionStatusText.notShown(reason: reason))
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
                    .merging(lateSuggestionMetadata) { current, _ in current }
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
                    .merging(lateSuggestionMetadata) { current, _ in current }
            )
            if shouldKeepCurrentVisibleSuggestion {
                setSuggestionDecision(
                    shouldKeepStreamedSuggestion
                        ? "Shown: kept streamed suggestion"
                        : "Shown: kept visible suggestion after late \(reason)"
                )
                showFieldStatusIndicator(.shown, context: context)
                repositionVisibleSuggestion(context: context, profile: profile)
                updateKeyboardEventTapSnapshot()
                return
            }
            hideSuggestion(reason: reason)
            return
        }

        let replacementDecision = suggestionOrchestrator.replacementDecision(
            currentVisibleText: suggestionSession.visibleSuggestion?.visibleText,
            proposedVisibleText: suggestion.visibleText,
            currentSuggestionID: currentSuggestionState.id,
            proposedSuggestionID: suggestionID,
            currentPresentedAt: currentSuggestionState.presentedAt,
            currentScore: currentSuggestionState.displayScoreFinal,
            proposedScore: displayScoreTrace.score.finalScore,
            currentSuggestionInvalidatedByUserTyping: currentSuggestionState.invalidatedByUserKeyDown
        )
        let replacementMetadata = replacementDecision.metadata
        let replacementVisibilityAction = suggestionReplacementVisibilityPolicy.action(
            for: replacementDecision,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion,
            currentSuggestionInvalidatedByUserTyping: currentSuggestionState.invalidatedByUserKeyDown
        )
        guard replacementVisibilityAction == .presentProposed else {
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

            switch replacementVisibilityAction {
            case .presentProposed:
                break
            case .keepCurrentVisible:
                showFieldStatusIndicator(.shown, context: context)
                repositionVisibleSuggestion(context: context, profile: profile)
                updateKeyboardEventTapSnapshot()
            case .hide:
                hideSuggestion(reason: reason)
            }
            return
        }

        lastCompatibilityLearningTrustContext = visualTrustContext
        cancelKeyboardEventTapIdleStop()
        let presentationDeliveryRequest = SuggestionPresentationDeliveryRequest(
            suggestion: suggestion,
            suggestionID: suggestionID,
            completionRequest: request,
            context: context,
            profile: profile,
            fieldIdentity: fieldIdentity,
            placement: placement,
            latencyMilliseconds: latencyMilliseconds,
            requestMetadata: displayRequestMetadata,
            geometryMetadata: traceGeometryMetadata(context: context, renderMode: placement.renderMode),
            learningMetadata: learningAdjustment.metadata,
            candidateSelectionMetadata: candidateSelectionMetadata,
            displayScoreMetadata: displayScoreMetadata,
            replacementMetadata: replacementMetadata
        )
        let panelRect: CGRect
        let deliveredPlacement: PlacementHealthPresentation
        switch suggestionPresentationDelivery.deliver(presentationDeliveryRequest) {
        case let .success(delivery):
            panelRect = delivery.panelRect
            deliveredPlacement = delivery.placement
        case let .failure(failure):
            let reason = failure.reason
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

        lastCaretRect = deliveredPlacement.anchorRect
        lastTextLineRect = deliveredPlacement.textLineRect
        lastClippingRect = deliveredPlacement.clippingRect
        lastTextStyle = context.textStyle
        lastRenderMode = deliveredPlacement.renderMode
        lastVisibleSuggestionGeometrySnapshot = visibleGeometrySnapshot(
            context: context,
            fieldIdentity: fieldIdentity,
            placement: deliveredPlacement
        )
        suggestionSession.present(suggestion)
        setSuggestionDecision(
            SuggestionStatusText.shown(
                mode: request.mode,
                triggerReason: triggerReason,
                latencyMilliseconds: latencyMilliseconds,
                metadata: candidateSelectionMetadata
            )
        )
        currentSuggestionState.id = suggestionID
        currentSuggestionState.appBundleIdentifier = request.appBundleIdentifier ?? profile.bundleIdentifier
        currentSuggestionState.fieldIdentity = fieldIdentity
        currentSuggestionState.requestMode = request.mode
        currentSuggestionState.textBeforeCursor = request.textBeforeCursor
        let acceptanceSnapshot = SuggestionAcceptanceSnapshot(
            fieldIdentity: fieldIdentity,
            targetFingerprint: targetFingerprint(context: context),
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            selectedTextLength: context.selectedTextLength
        )
        currentSuggestionState.acceptanceSnapshot = acceptanceSnapshot
        let presentedAt = Date()
        currentSuggestionState.displayedText = suggestion.visibleText
        currentSuggestionState.fieldClassification = displayFieldClassification
        currentSuggestionState.presentedAt = presentedAt
        currentSuggestionState.displayScoreFinal = displayScoreTrace.score.finalScore
        currentSuggestionState.invalidatedByUserKeyDown = false
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
                    deliveredPlacement.anchorRect,
                    deliveredPlacement.textLineRect,
                    panelRect,
                    deliveredPlacement.clippingRect
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
        let presentationTracePayload = suggestionPresentationDelivery.tracePayload(
            for: presentationDeliveryRequest,
            placement: deliveredPlacement,
            panelRect: panelRect,
            screenshotCapture: screenshotCapture
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
        guard context.textBeforeCursor == request.textBeforeCursor,
              context.textAfterCursor == request.textAfterCursor else {
            return (nil, "stale-text")
        }

        let refreshedFieldIdentity = self.fieldIdentity(
            app: frontmostApp,
            context: context,
            profile: profile
        )
        if refreshedFieldIdentity != fieldIdentity {
            return (nil, "stale-field")
        }

        return (context, nil)
    }


    private func frontmostAppMatchesSuggestion(
        _ frontmostApp: RunningApplicationInfo,
        expectedBundleIdentifier: String,
        profile _: CompatibilityProfile
    ) -> Bool {
        frontmostApp.bundleIdentifier == expectedBundleIdentifier
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

    private func visibleGeometrySnapshot(
        context: FocusedTextContext,
        fieldIdentity: FocusedFieldIdentity?,
        placement: PlacementHealthPresentation
    ) -> SuggestionGeometrySnapshot {
        SuggestionGeometrySnapshot(
            fieldIdentity: fieldIdentity,
            screenLayoutFingerprint: currentScreenLayoutFingerprint(),
            caretRect: placement.anchorRect,
            textLineRect: placement.textLineRect,
            elementRect: context.elementRect,
            windowRect: context.windowRect
        )
    }

    private func geometryTraceMetadata() -> [String: String] {
        [
            "displayLayoutFingerprint": currentScreenLayoutFingerprint(),
            "displayLayoutVariant": currentDisplayLayoutVariant(),
            "overlayDesktopBehavior": OverlayDesktopBehavior.traceDescription
        ]
    }

    private func currentScreenLayoutFingerprint() -> String {
        NSScreen.screens
            .map { screen in
                let frame = screen.frame
                let scale = Int((screen.backingScaleFactor * 100).rounded())
                return [
                    Int(frame.minX.rounded()),
                    Int(frame.minY.rounded()),
                    Int(frame.width.rounded()),
                    Int(frame.height.rounded()),
                    scale
                ].map(String.init).joined(separator: "x")
            }
            .sorted()
            .joined(separator: "|")
    }

    private func currentDisplayLayoutVariant() -> String {
        let frames = NSScreen.screens.map(\.frame)
        guard frames.count > 1 else {
            return "single-display"
        }

        let duplicateFrameCount = Dictionary(grouping: frames.map { visualRectFingerprint($0) ?? "invalid" }) { $0 }
            .values
            .map(\.count)
            .max() ?? 1
        if duplicateFrameCount > 1 {
            return "mirrored-display"
        }

        let hasVerticalOffset = frames.contains { frame in
            abs(frame.minY) > 1 || abs(frame.maxY - (NSScreen.main?.frame.maxY ?? 0)) > 1
        }

        return hasVerticalOffset ? "vertical-multi-display" : "multi-display"
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
        .merging(geometryTraceMetadata()) { current, _ in current }
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
            .merging(suggestionTuning.traceMetadata) { current, _ in current }
    }

    private func fieldClassification(for context: FocusedTextContext) -> AXFieldClassification {
        fieldClassifier.classification(
            for: AXFieldClassifierInput(
                role: context.role,
                subrole: context.subrole,
                identifier: context.fingerprint.identifier,
                title: context.fingerprint.title,
                description: context.fingerprint.description,
                help: context.fingerprint.help,
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


    private func observeTypingBurst(
        previousSnapshot: FocusedTextSnapshot?,
        currentSnapshot: FocusedTextSnapshot
    ) -> TypingBurstDecision {
        guard let previousSnapshot,
              previousSnapshot.fieldIdentity == currentSnapshot.fieldIdentity else {
            typingBurstState.reset()
            return .idle
        }

        return typingBurstPolicy.observe(
            previousTextBeforeCursor: previousSnapshot.textBeforeCursor,
            currentTextBeforeCursor: currentSnapshot.textBeforeCursor,
            nowMilliseconds: Int(Date().timeIntervalSince1970 * 1_000),
            state: &typingBurstState
        )
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

    private func targetFingerprint(context: FocusedTextContext) -> FocusedTargetFingerprint {
        FocusedTargetFingerprint(
            role: context.role,
            subrole: context.subrole,
            elementFingerprint: context.fingerprint,
            windowIdentifier: context.windowIdentifier,
            elementRect: context.elementRect,
            windowRect: context.windowRect,
            caretRect: context.caretRect,
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor
        )
    }

    private func traceRoundedRect(_ rect: RoundedFocusedRect?) -> String {
        guard let rect else {
            return "nil"
        }
        return "x=\(rect.x),y=\(rect.y),w=\(rect.width),h=\(rect.height)"
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
        skippingInsertionModes skippedModes: Set<InsertionMode> = [],
        action: KeyboardAction? = nil
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
                suggestionID: currentSuggestionState.id ?? "",
                appBundleIdentifier: currentSuggestionState.appBundleIdentifier ?? "",
                fieldIdentity: currentSuggestionState.fieldIdentity?.traceDescription
                    ?? currentFieldIdentity?.traceDescription
                    ?? "",
                requestMode: currentSuggestionState.requestMode?.rawValue ?? "",
                acceptedText: acceptedText,
                reason: "missing-compatibility-profile",
                metadata: [
                    "safetyGate": "compatibilityProfile"
                ]
            )
            hideSuggestion(reason: "insert-missing-compatibility-profile")
            return false
        }

        let acceptedTextDecision = acceptedTextSafetyPolicy.decision(
            acceptedText: acceptedText,
            profile: profile,
            allowsPromptActionWords: false
        )
        if let blockReason = acceptedTextDecision.blockReason {
            setSuggestionDecision("Blocked: unsafe accepted text")
            DiagnosticsLog.shared.record(
                "insert-blocked",
                metadata: [
                    "app": profile.bundleIdentifier,
                    "reason": blockReason,
                    "acceptedChars": String(acceptedText.count),
                    "promptSafetyMode": profile.promptAppSafetyMode.rawValue
                ]
            )
            RawAutocompleteTraceLog.shared.record(
                type: .insertionFailed,
                suggestionID: currentSuggestionState.id ?? "",
                appBundleIdentifier: currentSuggestionState.appBundleIdentifier ?? profile.bundleIdentifier,
                fieldIdentity: currentSuggestionState.fieldIdentity?.traceDescription
                    ?? currentFieldIdentity?.traceDescription
                    ?? "",
                requestMode: currentSuggestionState.requestMode?.rawValue ?? "",
                acceptedText: acceptedText,
                reason: blockReason,
                metadata: [
                    "safetyGate": "acceptedText",
                    "promptSafetyMode": profile.promptAppSafetyMode.rawValue
                ]
            )
            hideSuggestion(reason: "insert-unsafe-accepted-text")
            return false
        }

        keyboardEventTap?.suppressPassthroughObservation(
            until: Date().addingTimeInterval(
                shouldUseObsidianSystemEventsInsertion(profile: profile) ? 0.75 : 0.25
            )
        )

        if shouldUseObsidianSystemEventsInsertion(profile: profile) {
            let succeeded = insertObsidianSystemEventsPasteText(acceptedText)
            DiagnosticsLog.shared.record(
                "insert",
                metadata: [
                    "app": profile.bundleIdentifier,
                    "mode": InsertionMode.clipboardFallbackOptIn.rawValue,
                    "promptSafetyMode": profile.promptAppSafetyMode.rawValue,
                    "success": String(succeeded),
                    "skippedModes": skippedModes
                        .map(\.rawValue)
                        .sorted()
                        .joined(separator: ",")
                ]
            )
            if succeeded {
                suggestionPipeline.pausePolling(
                    now: Date(),
                    durationMilliseconds: postInsertionPollPauseMilliseconds
                )
            }
            return succeeded
        }

        repairObsidianFullAcceptCaretIfNeeded(profile: profile, action: action)

        // Bind the Accessibility write to the field the suggestion was shown for, so focus
        // stolen between the acceptance guard and the write cannot redirect the user's accepted
        // text into another app/field. See docs/security/threat-model.md (F1).
        let result = insertionEngine.insert(
            acceptedText,
            profile: profile,
            expectedFieldIdentity: currentSuggestionState.fieldIdentity,
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
            suggestionPipeline.pausePolling(
                now: Date(),
                durationMilliseconds: postInsertionPollPauseMilliseconds
            )
        }

        return result.succeeded
    }

    private func repairObsidianFullAcceptCaretIfNeeded(
        profile: CompatibilityProfile,
        action: KeyboardAction?
    ) {
        guard obsidianFullAcceptCaretRepairPolicy.shouldRepair(
            bundleIdentifier: profile.bundleIdentifier,
            action: action,
            snapshot: lastTextSnapshot,
            currentFieldIdentity: currentFieldIdentity
        ),
              let lastTextSnapshot,
              let frontmostApp = accessibilityClient.frontmostApplication(),
              frontmostApp.bundleIdentifier == "md.obsidian",
              frontmostApp.processIdentifier == lastTextSnapshot.fieldIdentity.processIdentifier else {
            return
        }

        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        let expectedText = lastTextSnapshot.textBeforeCursor + lastTextSnapshot.textAfterCursor
        let textArea = Self.axTextAreaDescendantContainingText(
            in: appElement,
            containing: lastTextSnapshot.textBeforeCursor,
            elementIdentifier: lastTextSnapshot.fieldIdentity.elementIdentifier,
            maxDepth: 32
        ) ?? Self.axTextAreaDescendant(
            in: appElement,
            matchingValue: expectedText,
            containing: lastTextSnapshot.textBeforeCursor,
            maxDepth: 32
        )

        guard let textArea else {
            DiagnosticsLog.shared.record(
                "obsidian-full-accept-caret-repair",
                metadata: [
                    "app": profile.bundleIdentifier,
                    "success": "false",
                    "reason": "text-area-not-found",
                    "beforeChars": String(lastTextSnapshot.textBeforeCursor.count)
                ]
            )
            return
        }

        let cursorUTF16Offset = lastTextSnapshot.textBeforeCursor.utf16.count
        AXUIElementSetAttributeValue(textArea, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        Self.setAXSelectedTextRange(textArea, location: cursorUTF16Offset, length: 0)
        Thread.sleep(forTimeInterval: 0.05)
        var cursorMatches = Self.axObsidianSelectedTextRangeMatchesInsertionPoint(
            textArea,
            location: cursorUTF16Offset
        )
        var usedCommandRightFallback = false
        var usedDocumentEndFallback = false
        if !cursorMatches {
            Self.postCommandRightKey()
            usedCommandRightFallback = true
            Thread.sleep(forTimeInterval: 0.05)
            Self.setAXSelectedTextRange(textArea, location: cursorUTF16Offset, length: 0)
            Thread.sleep(forTimeInterval: 0.05)
            cursorMatches = Self.axObsidianSelectedTextRangeMatchesInsertionPoint(
                textArea,
                location: cursorUTF16Offset
            )
        }
        if !cursorMatches,
           lastTextSnapshot.textAfterCursor.isEmpty {
            Self.postCommandDownKey()
            usedDocumentEndFallback = true
            Thread.sleep(forTimeInterval: 0.05)
            cursorMatches = Self.axObsidianSelectedTextRangeMatchesInsertionPoint(
                textArea,
                location: cursorUTF16Offset
            )
        }
        DiagnosticsLog.shared.record(
            "obsidian-full-accept-caret-repair",
            metadata: [
                "app": profile.bundleIdentifier,
                "success": String(cursorMatches),
                "commandRightFallback": String(usedCommandRightFallback),
                "documentEndFallback": String(usedDocumentEndFallback),
                "beforeChars": String(lastTextSnapshot.textBeforeCursor.count),
                "cursorUTF16Offset": String(cursorUTF16Offset)
            ]
        )
    }





    private func shouldUseObsidianSystemEventsInsertion(profile: CompatibilityProfile) -> Bool {
        currentSuggestionState.appBundleIdentifier == "md.obsidian"
            && profile.bundleIdentifier == "md.obsidian"
            && profile.insertionMode == .axValueReplacement
    }








    private static func clonePasteboardItems(_ items: [NSPasteboardItem]?) -> [NSPasteboardItem] {
        (items ?? []).map { item in
            let clone = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    clone.setData(data, forType: type)
                } else if let string = item.string(forType: type) {
                    clone.setString(string, forType: type)
                }
            }
            return clone
        }
    }

    private func insertObsidianSystemEventsPasteText(_ acceptedText: String) -> Bool {
        let bundleIdentifier = "md.obsidian"
        guard !acceptedText.isEmpty,
              let currentSuggestionFieldIdentity = currentSuggestionState.fieldIdentity,
              let lastTextSnapshot,
              lastTextSnapshot.fieldIdentity == currentSuggestionFieldIdentity,
              let frontmostApp = accessibilityClient.frontmostApplication(),
              frontmostApp.bundleIdentifier == bundleIdentifier,
              frontmostApp.processIdentifier == currentSuggestionFieldIdentity.processIdentifier else {
            DiagnosticsLog.shared.record(
                "obsidian-system-events-insert",
                metadata: [
                    "app": bundleIdentifier,
                    "posted": "false",
                    "reason": "precondition-failed"
                ]
            )
            return false
        }

        let pasteboard = NSPasteboard.general
        let originalItems = Self.clonePasteboardItems(pasteboard.pasteboardItems)
        func restoreOriginalPasteboard() {
            pasteboard.clearContents()
            if !originalItems.isEmpty {
                pasteboard.writeObjects(originalItems)
            }
        }
        pasteboard.clearContents()
        guard pasteboard.setString(acceptedText, forType: .string) else {
            restoreOriginalPasteboard()
            DiagnosticsLog.shared.record(
                "obsidian-system-events-insert",
                metadata: [
                    "app": bundleIdentifier,
                    "posted": "false",
                    "reason": "pasteboard-set-failed"
                ]
            )
            return false
        }
        let fallbackChangeCount = pasteboard.changeCount

        let pasteDelayMilliseconds = 30
        let posted = Self.postCommandVKeyAsync(afterMilliseconds: pasteDelayMilliseconds)
        if posted {
            schedulePasteboardRestore(
                insertedText: acceptedText,
                fallbackChangeCount: fallbackChangeCount,
                originalItems: originalItems,
                delaySeconds: 0.35
            )
        } else {
            restoreOriginalPasteboard()
        }
        DiagnosticsLog.shared.record(
            "obsidian-system-events-insert",
            metadata: [
                "app": bundleIdentifier,
                "posted": String(posted),
                "source": "cgEventCommandPasteAsync",
                "delayMilliseconds": String(pasteDelayMilliseconds),
                "acceptedChars": String(acceptedText.count)
            ]
        )
        return posted
    }

    private func repairObsidianTabPassthroughIfNeeded(
        previousSnapshot: FocusedTextSnapshot?,
        currentSnapshot: FocusedTextSnapshot,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        source: String
    ) -> Bool {
        let bundleIdentifier = "md.obsidian"
        let suggestionBundleIdentifier = currentSuggestionState.appBundleIdentifier
            ?? currentProfile?.bundleIdentifier
            ?? profile.bundleIdentifier
        let suggestionAgeMilliseconds = currentSuggestionAgeMilliseconds()
        let hasRecentSuggestion = suggestionAgeMilliseconds.map { $0 <= 15_000 } ?? false
        let suggestionFieldMatches = currentSuggestionState.fieldIdentity == fieldIdentity
            || currentSuggestionState.fieldIdentity == previousSnapshot?.fieldIdentity
            || hasRecentSuggestion
        guard profile.bundleIdentifier == bundleIdentifier,
              let previousSnapshot,
              suggestionFieldMatches,
              suggestionBundleIdentifier == bundleIdentifier,
              currentSuggestionState.requestMode == .wordCompletion else {
            return false
        }

        let preview = suggestionSession.nextWordAcceptancePreview()
        let acceptedText = preview?.acceptedText ?? currentSuggestionState.displayedText
        let decision = obsidianTabPassthroughRepairPolicy.decision(
            previousTextBeforeCursor: previousSnapshot.textBeforeCursor,
            currentTextBeforeCursor: currentSnapshot.textBeforeCursor,
            previousTextAfterCursor: previousSnapshot.textAfterCursor,
            currentTextAfterCursor: currentSnapshot.textAfterCursor,
            currentSelectedText: context.selectedText,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion || hasRecentSuggestion,
            acceptedText: acceptedText
        )
        guard decision.shouldRepair, let acceptedText, !acceptedText.isEmpty else {
            if profile.bundleIdentifier == bundleIdentifier,
               currentSnapshot.textBeforeCursor.contains("\t")
                    || context.selectedTextLength > 0 {
                DiagnosticsLog.shared.record(
                    "obsidian-tab-passthrough-repair-skipped",
                    metadata: [
                        "app": bundleIdentifier,
                        "reason": decision.reason,
                        "source": source,
                        "suggestionAgeMilliseconds": suggestionAgeMilliseconds.map(String.init) ?? "unknown",
                        "suggestionVisible": String(suggestionSession.hasVisibleSuggestion),
                        "acceptedChars": String(acceptedText?.count ?? 0),
                        "previousBeforeChars": String(previousSnapshot.textBeforeCursor.count),
                        "currentBeforeChars": String(currentSnapshot.textBeforeCursor.count),
                        "currentAfterChars": String(currentSnapshot.textAfterCursor.count),
                        "selectedChars": String(context.selectedText.count),
                        "selectedTextLength": String(context.selectedTextLength)
                    ]
                )
            }
            return false
        }

        let action = KeyboardAction.acceptNextWord
        let key = AutocompleteKey.tab
        let acceptanceProof = acceptanceReceipt(action: action, acceptedText: acceptedText)
        if acceptanceProof == nil {
            DiagnosticsLog.shared.record(
                "obsidian-tab-passthrough-proof-stale",
                metadata: [
                    "app": bundleIdentifier,
                    "source": source,
                    "acceptedChars": String(acceptedText.count),
                    "suggestionAgeMilliseconds": suggestionAgeMilliseconds.map(String.init) ?? "unknown"
                ]
            )
        }

        let acceptanceID = UUID().uuidString
        let acceptedAt = Date()
        let verificationBaseline = insertionVerificationBaseline(
            acceptanceID: acceptanceID,
            acceptedAt: acceptedAt,
            action: action,
            acceptMode: action.diagnosticName
        )

        DiagnosticsLog.shared.record(
            "obsidian-tab-passthrough-repair",
            metadata: [
                "app": bundleIdentifier,
                "reason": decision.reason,
                "source": source,
                "acceptedChars": String(acceptedText.count),
                "previousBeforeChars": String(previousSnapshot.textBeforeCursor.count),
                "currentBeforeChars": String(currentSnapshot.textBeforeCursor.count),
                "currentAfterChars": String(currentSnapshot.textAfterCursor.count),
                "selectedChars": String(context.selectedText.count),
                "selectedTextLength": String(context.selectedTextLength),
                "suggestionAgeMilliseconds": suggestionAgeMilliseconds.map(String.init) ?? "unknown",
                "suggestionVisible": String(suggestionSession.hasVisibleSuggestion)
            ]
        )

        let repairSucceeded = repairObsidianTabPassthroughByReplacingFocusedText(
            previousSnapshot: previousSnapshot,
            currentSnapshot: currentSnapshot,
            acceptedText: acceptedText
        ) || repairObsidianTabPassthroughByUndoingThenPasting(
            previousSnapshot: previousSnapshot,
            acceptedText: acceptedText
        )
        guard repairSucceeded else {
            recordKeyboardAction(key: key, action: action, handled: false, reason: "obsidian-tab-passthrough-direct-repair-failed")
            return false
        }

        armAcceptedInsertionUndo(
            acceptedText: acceptedText,
            acceptanceID: acceptanceID,
            acceptedAt: acceptedAt,
            acceptMode: action.diagnosticName
        )
        suggestionSession.commitNextWordAcceptance(acceptedText)
        recordAcceptedText(acceptedText)
        advanceCurrentSuggestionBaseline(afterAccepting: acceptedText)
        lastTextSnapshot = FocusedTextSnapshot(
            fieldIdentity: fieldIdentity,
            textBeforeCursor: previousSnapshot.textBeforeCursor + acceptedText,
            textAfterCursor: previousSnapshot.textAfterCursor
        )
        suggestionRepetitionSuppressor.recordAcceptance(
            acceptedText,
            mode: currentSuggestionState.requestMode,
            scope: currentSuggestionState.appBundleIdentifier ?? currentProfile?.bundleIdentifier ?? ""
        )
        if let acceptanceProof {
            recordRawAcceptance(
                action: action,
                acceptedText: acceptedText,
                acceptanceID: acceptanceID,
                acceptanceProof: acceptanceProof
            )
        }
        recordAnnoyanceSignal(
            .accepted,
            context: currentAnnoyanceContext(),
            suggestionID: currentSuggestionState.id ?? "",
            reason: "obsidian-tab-passthrough-repaired"
        )
        refreshAfterNextWordAcceptance(
            residualReason: "Accepted: repaired Obsidian Tab; showing remainder",
            emptyReason: "accepted-obsidian-tab-passthrough-repaired",
            emptyMetadata: [
                "repair": "obsidian-tab-passthrough",
                "fieldBeforeChars": String(context.textBeforeCursor.count)
            ]
        )
        scheduleInsertionVerification(acceptedText: acceptedText, baseline: verificationBaseline)
        suppressKey(key)
        recordKeyboardAction(key: key, action: action, handled: true, reason: "obsidian-tab-passthrough-repaired")
        return true
    }

    private func repairObsidianTabPassthroughByReplacingFocusedText(
        previousSnapshot: FocusedTextSnapshot,
        currentSnapshot: FocusedTextSnapshot,
        acceptedText: String
    ) -> Bool {
        let bundleIdentifier = "md.obsidian"
        guard !acceptedText.isEmpty,
              let frontmostApp = accessibilityClient.frontmostApplication(),
              frontmostApp.bundleIdentifier == bundleIdentifier else {
            DiagnosticsLog.shared.record(
                "obsidian-tab-passthrough-direct-repair",
                metadata: [
                    "app": bundleIdentifier,
                    "success": "false",
                    "reason": "precondition-failed"
                ]
            )
            return false
        }

        let currentText = currentSnapshot.textBeforeCursor + currentSnapshot.textAfterCursor
        let replacementText = previousSnapshot.textBeforeCursor + acceptedText + previousSnapshot.textAfterCursor
        let cursorUTF16Offset = previousSnapshot.textBeforeCursor.utf16.count + acceptedText.utf16.count
        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        guard let textArea = Self.axFocusedTextArea(
            in: appElement,
            matchingValue: currentText,
            containing: currentSnapshot.textBeforeCursor
        ) ?? Self.axTextAreaDescendant(
            in: appElement,
            matchingValue: currentText,
            containing: currentSnapshot.textBeforeCursor,
            maxDepth: 32
        ) else {
            DiagnosticsLog.shared.record(
                "obsidian-tab-passthrough-direct-repair",
                metadata: [
                    "app": bundleIdentifier,
                    "success": "false",
                    "reason": "text-area-not-found",
                    "currentChars": String(currentText.count),
                    "replacementChars": String(replacementText.count)
                ]
            )
            return false
        }

        AXUIElementSetAttributeValue(textArea, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        let valueResult = AXUIElementSetAttributeValue(
            textArea,
            kAXValueAttribute as CFString,
            replacementText as CFTypeRef
        )
        guard valueResult == .success else {
            DiagnosticsLog.shared.record(
                "obsidian-tab-passthrough-direct-repair",
                metadata: [
                    "app": bundleIdentifier,
                    "success": "false",
                    "reason": "value-set-failed",
                    "axResult": String(valueResult.rawValue)
                ]
            )
            return false
        }

        Self.setAXSelectedTextRange(textArea, location: cursorUTF16Offset, length: 0)
        Thread.sleep(forTimeInterval: 0.05)

        var succeeded = false
        var cursorMatches = false
        var currentValue: String?
        for _ in 0..<5 {
            currentValue = Self.axStringAttribute(textArea, kAXValueAttribute)
            cursorMatches = Self.axObsidianSelectedTextRangeMatchesInsertionPoint(
                textArea,
                location: cursorUTF16Offset
            )
            if currentValue == replacementText,
               cursorMatches || previousSnapshot.textAfterCursor.isEmpty {
                succeeded = true
                break
            }
            if currentValue == replacementText {
                Self.setAXSelectedTextRange(textArea, location: cursorUTF16Offset, length: 0)
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        DiagnosticsLog.shared.record(
            "obsidian-tab-passthrough-direct-repair",
            metadata: [
                "app": bundleIdentifier,
                "success": String(succeeded),
                "cursorMatches": String(cursorMatches),
                "acceptedChars": String(acceptedText.count),
                "currentChars": String(currentValue?.count ?? -1),
                "previousBeforeChars": String(previousSnapshot.textBeforeCursor.count),
                "currentBeforeChars": String(currentSnapshot.textBeforeCursor.count)
            ]
        )
        return succeeded
    }

    private func repairObsidianTabPassthroughByUndoingThenPasting(
        previousSnapshot: FocusedTextSnapshot,
        acceptedText: String
    ) -> Bool {
        let bundleIdentifier = "md.obsidian"
        guard !acceptedText.isEmpty,
              let frontmostApp = accessibilityClient.frontmostApplication(),
              frontmostApp.bundleIdentifier == bundleIdentifier else {
            DiagnosticsLog.shared.record(
                "obsidian-tab-passthrough-undo-paste-repair",
                metadata: [
                    "app": bundleIdentifier,
                    "success": "false",
                    "reason": "precondition-failed"
                ]
            )
            return false
        }

        let pasteboard = NSPasteboard.general
        let originalItems = Self.clonePasteboardItems(pasteboard.pasteboardItems)
        func restoreOriginalPasteboard() {
            pasteboard.clearContents()
            if !originalItems.isEmpty {
                pasteboard.writeObjects(originalItems)
            }
        }
        pasteboard.clearContents()
        guard pasteboard.setString(acceptedText, forType: .string) else {
            restoreOriginalPasteboard()
            DiagnosticsLog.shared.record(
                "obsidian-tab-passthrough-undo-paste-repair",
                metadata: [
                    "app": bundleIdentifier,
                    "success": "false",
                    "reason": "pasteboard-set-failed"
                ]
            )
            return false
        }
        let fallbackChangeCount = pasteboard.changeCount

        let script = """
        tell application "System Events"
          tell application process "Obsidian" to set frontmost to true
          keystroke "z" using command down
          delay 0.05
          keystroke "v" using command down
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            restoreOriginalPasteboard()
            DiagnosticsLog.shared.record(
                "obsidian-tab-passthrough-undo-paste-repair",
                metadata: [
                    "app": bundleIdentifier,
                    "success": "false",
                    "reason": "osascript-run-failed"
                ]
            )
            return false
        }

        guard process.terminationStatus == 0 else {
            restoreOriginalPasteboard()
            DiagnosticsLog.shared.record(
                "obsidian-tab-passthrough-undo-paste-repair",
                metadata: [
                    "app": bundleIdentifier,
                    "success": "false",
                    "reason": "osascript-failed",
                    "terminationStatus": String(process.terminationStatus)
                ]
            )
            return false
        }

        schedulePasteboardRestore(
            insertedText: acceptedText,
            fallbackChangeCount: fallbackChangeCount,
            originalItems: originalItems
        )

        let expectedText = previousSnapshot.textBeforeCursor + acceptedText + previousSnapshot.textAfterCursor
        var succeeded = false
        var currentChars = -1
        for _ in 0..<8 {
            if let context = accessibilityClient.focusedTextContext(allowDescendantTextFallback: true) {
                let currentText = context.textBeforeCursor + context.textAfterCursor
                currentChars = currentText.count
                if currentText == expectedText {
                    succeeded = true
                    break
                }
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        DiagnosticsLog.shared.record(
            "obsidian-tab-passthrough-undo-paste-repair",
            metadata: [
                "app": bundleIdentifier,
                "success": String(succeeded),
                "acceptedChars": String(acceptedText.count),
                "currentChars": String(currentChars),
                "expectedChars": String(expectedText.count),
                "previousBeforeChars": String(previousSnapshot.textBeforeCursor.count),
                "previousAfterChars": String(previousSnapshot.textAfterCursor.count)
            ]
        )
        return succeeded
    }


    private func schedulePasteboardRestore(
        insertedText: String,
        fallbackChangeCount: Int,
        originalItems: [NSPasteboardItem],
        delaySeconds: TimeInterval = 0.15
    ) {
        let restorePolicy = ClipboardFallbackRestorePolicy()
        let pasteboard = NSPasteboard.general
        DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) {
            let restoreDecision = restorePolicy.decision(
                insertedText: insertedText,
                currentString: pasteboard.string(forType: .string),
                fallbackChangeCount: fallbackChangeCount,
                currentChangeCount: pasteboard.changeCount
            )
            if restoreDecision == .restoreOriginalPasteboard {
                pasteboard.clearContents()
                pasteboard.writeObjects(originalItems)
            }
        }
    }

    nonisolated private static func postUnicodeTextKeyEvents(
        _ text: String,
        processIdentifier: pid_t? = nil
    ) -> Bool {
        guard !text.isEmpty else {
            return false
        }

        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            return false
        }

        var characters = Array(text.utf16)
        characters.withUnsafeMutableBufferPointer { buffer in
            keyDown.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
            keyUp.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
            if let processIdentifier {
                keyDown.postToPid(processIdentifier)
                keyUp.postToPid(processIdentifier)
            } else {
                keyDown.post(tap: .cghidEventTap)
                keyUp.post(tap: .cghidEventTap)
            }
        }

        return true
    }

    nonisolated private static func bundledTextEventHelperURL() -> URL? {
        let helperName = "SteadyTypeTextEventHelper"
        let fileManager = FileManager.default
        if let auxiliaryURL = Bundle.main.url(forAuxiliaryExecutable: helperName),
           fileManager.isExecutableFile(atPath: auxiliaryURL.path) {
            return auxiliaryURL
        }

        let bundleCandidate = Bundle.main.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent(helperName)
        if fileManager.isExecutableFile(atPath: bundleCandidate.path) {
            return bundleCandidate
        }

        guard let executablePath = CommandLine.arguments.first, !executablePath.isEmpty else {
            return nil
        }
        let siblingURL = URL(fileURLWithPath: executablePath)
            .deletingLastPathComponent()
            .appendingPathComponent(helperName)
        if fileManager.isExecutableFile(atPath: siblingURL.path) {
            return siblingURL
        }
        return nil
    }

    nonisolated private static func postUnicodeTextKeyEventsPerCharacter(
        _ text: String,
        processIdentifier: pid_t? = nil
    ) -> Bool {
        guard !text.isEmpty,
              let source = CGEventSource(stateID: .hidSystemState) else {
            return false
        }

        for character in text {
            var units = Array(String(character).utf16)
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                return false
            }

            keyDown.flags = []
            keyUp.flags = []
            units.withUnsafeMutableBufferPointer { buffer in
                keyDown.keyboardSetUnicodeString(
                    stringLength: buffer.count,
                    unicodeString: buffer.baseAddress
                )
                keyUp.keyboardSetUnicodeString(
                    stringLength: buffer.count,
                    unicodeString: buffer.baseAddress
                )
            }
            if let processIdentifier {
                keyDown.postToPid(processIdentifier)
                Thread.sleep(forTimeInterval: 0.012)
                keyUp.postToPid(processIdentifier)
                Thread.sleep(forTimeInterval: 0.012)
            } else {
                keyDown.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: 0.012)
                keyUp.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: 0.012)
            }
        }

        return true
    }

    nonisolated private static func postHardwareTextKeyEvents(
        _ text: String,
        processIdentifier: pid_t? = nil
    ) -> Bool {
        guard let strokes = KeyboardTextEventPlan.hardwareKeyStrokes(for: text),
              let source = CGEventSource(stateID: .hidSystemState) else {
            return false
        }

        for stroke in strokes {
            guard let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: stroke.virtualKey,
                keyDown: true
            ),
                  let keyUp = CGEvent(
                      keyboardEventSource: source,
                      virtualKey: stroke.virtualKey,
                      keyDown: false
                  ) else {
                return false
            }

            keyDown.flags = stroke.flags
            keyUp.flags = stroke.flags
            if let processIdentifier {
                keyDown.postToPid(processIdentifier)
                Thread.sleep(forTimeInterval: 0.012)
                keyUp.postToPid(processIdentifier)
                Thread.sleep(forTimeInterval: 0.012)
            } else {
                keyDown.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: 0.012)
                keyUp.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: 0.012)
            }
        }

        return true
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

    nonisolated private static func axStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        axAttribute(element, attribute) as? String
    }

    nonisolated private static func axChildren(_ element: AXUIElement) -> [AXUIElement] {
        axAttribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }

    nonisolated private static func axFocusedTextArea(
        in appElement: AXUIElement,
        matchingValue expectedValue: String,
        containing marker: String,
        elementIdentifier: Int
    ) -> AXUIElement? {
        guard let focusedValue = axAttribute(appElement, kAXFocusedUIElementAttribute),
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            return nil
        }

        let focusedElement = focusedValue as! AXUIElement
        return axTextAreaDescendant(
            in: focusedElement,
            matchingValue: expectedValue,
            containing: marker,
            elementIdentifier: elementIdentifier,
            maxDepth: 12
        )
    }

    nonisolated private static func axFocusedTextArea(
        in appElement: AXUIElement,
        matchingValue expectedValue: String,
        containing marker: String
    ) -> AXUIElement? {
        guard let focusedValue = axAttribute(appElement, kAXFocusedUIElementAttribute),
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            return nil
        }

        let focusedElement = focusedValue as! AXUIElement
        guard axRole(focusedElement) == "AXTextArea",
              let value = axStringAttribute(focusedElement, kAXValueAttribute),
              value == expectedValue,
              value.contains(marker) else {
            return nil
        }

        return focusedElement
    }

    nonisolated private static func axTextAreaDescendant(
        in element: AXUIElement,
        matchingValue expectedValue: String,
        containing marker: String,
        maxDepth: Int
    ) -> AXUIElement? {
        guard maxDepth >= 0 else {
            return nil
        }

        if axRole(element) == "AXTextArea",
           let value = axStringAttribute(element, kAXValueAttribute),
           value == expectedValue,
           value.contains(marker) {
            return element
        }

        for child in axChildren(element) {
            if let match = axTextAreaDescendant(
                in: child,
                matchingValue: expectedValue,
                containing: marker,
                maxDepth: maxDepth - 1
            ) {
                return match
            }
        }

        return nil
    }

    nonisolated private static func axTextAreaDescendant(
        in element: AXUIElement,
        matchingValue expectedValue: String,
        containing marker: String,
        elementIdentifier: Int,
        maxDepth: Int
    ) -> AXUIElement? {
        guard maxDepth >= 0 else {
            return nil
        }

        if axRole(element) == "AXTextArea",
           Int(CFHash(element)) == elementIdentifier,
           let value = axStringAttribute(element, kAXValueAttribute),
           value == expectedValue,
           value.contains(marker) {
            return element
        }

        for child in axChildren(element) {
            if let match = axTextAreaDescendant(
                in: child,
                matchingValue: expectedValue,
                containing: marker,
                elementIdentifier: elementIdentifier,
                maxDepth: maxDepth - 1
            ) {
                return match
            }
        }

        return nil
    }

    nonisolated private static func axTextAreaDescendantContainingText(
        in element: AXUIElement,
        containing expectedText: String,
        elementIdentifier: Int,
        maxDepth: Int
    ) -> AXUIElement? {
        guard maxDepth >= 0, !expectedText.isEmpty else {
            return nil
        }

        if axRole(element) == "AXTextArea",
           let value = axStringAttribute(element, kAXValueAttribute),
           Int(CFHash(element)) == elementIdentifier,
           value.contains(expectedText) {
            return element
        }

        for child in axChildren(element) {
            if let match = axTextAreaDescendantContainingText(
                in: child,
                containing: expectedText,
                elementIdentifier: elementIdentifier,
                maxDepth: maxDepth - 1
            ) {
                return match
            }
        }

        return nil
    }

    nonisolated private static func replacementRange(
        in currentValue: String,
        previousText: String,
        textBeforeCursor: String,
        textAfterCursor: String
    ) -> Range<String.Index>? {
        if let exactRange = currentValue.range(of: previousText, options: .backwards) {
            return exactRange
        }

        guard textAfterCursor.isEmpty else {
            return nil
        }

        return currentValue.range(of: textBeforeCursor, options: .backwards)
    }

    nonisolated private static func setAXSelectedTextRange(
        _ element: AXUIElement,
        location: Int,
        length: Int
    ) {
        var range = CFRange(location: location, length: length)
        if let rangeValue = AXValueCreate(.cfRange, &range) {
            AXUIElementSetAttributeValue(
                element,
                kAXSelectedTextRangeAttribute as CFString,
                rangeValue
            )
        }
    }

    nonisolated private static func axSelectedTextRangeMatches(
        _ element: AXUIElement,
        location: Int,
        length: Int
    ) -> Bool {
        guard let value = axAttribute(element, kAXSelectedTextRangeAttribute) else {
            return false
        }
        guard CFGetTypeID(value as CFTypeRef) == AXValueGetTypeID() else {
            return false
        }

        var range = CFRange(location: -1, length: -1)
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else {
            return false
        }

        return range.location == location && range.length == length
    }

    nonisolated private static func axObsidianSelectedTextRangeMatchesInsertionPoint(
        _ element: AXUIElement,
        location: Int
    ) -> Bool {
        axSelectedTextRangeMatches(element, location: location, length: 0)
            || (
                location > 0
                    && axSelectedTextRangeMatches(element, location: location - 1, length: 0)
            )
    }

    nonisolated private static func postCommandRightKey() {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 124, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 124, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    nonisolated private static func postCommandDownKey() {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 125, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 125, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    nonisolated private static func postCommandVKey(processIdentifier: pid_t? = nil) -> Bool {
        postCommandVKey(processIdentifier: processIdentifier, tapLocation: .cghidEventTap)
    }

    nonisolated private static func postCommandVKey(
        processIdentifier: pid_t? = nil,
        tapLocation: CGEventTapLocation
    ) -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        if let processIdentifier {
            keyDown.postToPid(processIdentifier)
            Thread.sleep(forTimeInterval: 0.018)
            keyUp.postToPid(processIdentifier)
        } else {
            keyDown.post(tap: tapLocation)
            Thread.sleep(forTimeInterval: 0.018)
            keyUp.post(tap: tapLocation)
        }
        Thread.sleep(forTimeInterval: 0.012)
        return true
    }

    nonisolated private static func postCommandVKeyAsync(afterMilliseconds delayMilliseconds: Int) -> Bool {
        let postPaste: @Sendable () -> Void = {
            let source = CGEventSource(stateID: .hidSystemState)
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
                DiagnosticsLog.shared.record(
                    "keyboard-post-failed",
                    metadata: [
                        "key": "command-v",
                        "source": "cgEventCommandPasteAsync"
                    ]
                )
                return
            }

            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }

        if delayMilliseconds > 0 {
            DispatchQueue.global(qos: .userInteractive).asyncAfter(
                deadline: .now() + .milliseconds(delayMilliseconds),
                execute: postPaste
            )
        } else {
            DispatchQueue.global(qos: .userInteractive).async(execute: postPaste)
        }
        return true
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
        acceptanceProof: AcceptanceReceipt
    ) {
        guard let appBundleIdentifier = currentSuggestionState.appBundleIdentifier ?? currentProfile?.bundleIdentifier else {
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
        if let fieldClassification = currentSuggestionState.fieldClassification {
            metadata.merge(fieldClassification.traceMetadata) { current, _ in current }
        }
        metadata.merge(acceptanceProof.traceMetadata) { current, _ in current }

        RawAutocompleteTraceLog.shared.recordAcceptance(
            action: action.diagnosticName,
            appBundleIdentifier: appBundleIdentifier,
            acceptedText: acceptedText,
            remainingVisibleText: suggestionSession.visibleSuggestion?.visibleText,
            suggestionID: currentSuggestionState.id ?? "",
            fieldIdentity: currentSuggestionState.fieldIdentity?.traceDescription
                ?? currentFieldIdentity?.traceDescription
                ?? "",
            requestMode: currentSuggestionState.requestMode?.rawValue ?? "",
            metadata: metadata
        )
    }

    private func acceptanceReceipt(
        action: KeyboardAction,
        acceptedText: String
    ) -> AcceptanceReceipt? {
        let visibleText = currentSuggestionState.displayedText ?? suggestionSession.visibleSuggestion?.visibleText
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

        guard let visibleText,
              let receipt = acceptanceReceiptPolicy.receipt(
                  action: action,
                  acceptedText: acceptedText,
                  visibleText: visibleText
              ) else {
            recordAcceptanceSafetyBlocked(
                action: action,
                acceptedText: acceptedText,
                visibleText: visibleText,
                reason: "receipt-mismatch"
            )
            return nil
        }
        return receipt
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
        if let suggestionID = currentSuggestionState.id {
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: suggestionID,
                appBundleIdentifier: currentSuggestionState.appBundleIdentifier ?? currentProfile?.bundleIdentifier ?? "",
                fieldIdentity: currentSuggestionState.fieldIdentity?.traceDescription
                    ?? currentFieldIdentity?.traceDescription
                    ?? "",
                requestMode: currentSuggestionState.requestMode?.rawValue ?? "",
                reason: "acceptance-safety-blocked",
                metadata: metadata
            )
        }
        setSuggestionDecision("Blocked: acceptance safety failed")
        hideSuggestion(reason: "acceptance-safety-blocked", metadata: metadata)
    }

    @discardableResult
    private func refreshVisibleSuggestion(
        placement: PlacementHealthPresentation? = nil,
        fallbackRenderMode: SuggestionRenderMode? = nil
    ) -> PlacementHealthPresentation? {
        guard let suggestion = suggestionSession.visibleSuggestion else {
            hideSuggestion()
            return nil
        }

        let initialPlacement: PlacementHealthPresentation
        if let placement {
            initialPlacement = placement
        } else {
            guard let caretRect = lastCaretRect else {
                hideSuggestion()
                return nil
            }
            let renderMode = lastRenderMode ?? .inlineAdjacent
            initialPlacement = PlacementHealthPresentation(
                requestedRenderMode: renderMode,
                renderMode: renderMode,
                anchorRect: caretRect,
                anchorSource: .caret,
                textLineRect: lastTextLineRect,
                clippingRect: lastClippingRect,
                reason: .healthy
            )
        }

        currentSuggestionState.displayedText = suggestion.visibleText
        cancelKeyboardEventTapIdleStop()
        let attempt = SuggestionPanelPresentationPolicy.attempt(
            initialPlacement: initialPlacement,
            fallbackRenderMode: fallbackRenderMode
        ) { placement in
            suggestionPanel.show(
                text: suggestion.visibleText,
                near: placement.anchorRect,
                alignedTo: placement.renderMode == .inlineAdjacent ? placement.textLineRect : nil,
                boundedBy: placement.clippingRect,
                style: lastTextStyle,
                renderMode: placement.renderMode
            )
        }
        guard attempt.didPresent else {
            hideSuggestion(reason: "panel-frame-unusable")
            return nil
        }

        lastCaretRect = attempt.placement.anchorRect
        lastTextLineRect = attempt.placement.textLineRect
        lastClippingRect = attempt.placement.clippingRect
        lastRenderMode = attempt.placement.renderMode
        updateKeyboardEventTapSnapshot()
        return attempt.placement
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

        let currentGeometrySnapshot = visibleGeometrySnapshot(
            context: context,
            fieldIdentity: currentFieldIdentity,
            placement: placement
        )
        let allowsStableChromeEditorGeometryChurn = allowsStableChromeEditorGeometryChurn(
            context: context,
            profile: profile
        )
        let allowsAcceptedNextWordGeometryChurn = preservesResidualSuggestionAfterNextWordAccept
            && suggestionSession.hasVisibleSuggestion
        let invalidation = suggestionGeometryChangePolicy.invalidationDecision(
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion,
            hasPendingSuggestionRequest: suggestionOrchestrator.currentRequest != nil,
            previousSnapshot: lastVisibleSuggestionGeometrySnapshot,
            currentSnapshot: currentGeometrySnapshot,
            allowsCaretRectChange: allowsStableChromeEditorGeometryChurn || allowsAcceptedNextWordGeometryChurn,
            allowsTextLineRectChange: allowsStableChromeEditorGeometryChurn || allowsAcceptedNextWordGeometryChurn
        )
        if invalidation.shouldInvalidate {
            let reason = invalidation.reason?.rawValue ?? "unknown"
            if let geometryFieldIdentity = currentGeometrySnapshot.fieldIdentity,
               shouldPreserveVisibleSuggestionDuringGeometryInvalidation(
                invalidation: invalidation,
                context: context,
                profile: profile,
                fieldIdentity: geometryFieldIdentity
            ) {
                updateKeyboardEventTapSnapshot()
                setSuggestionDecision("Shown: preserving current suggestion")
                recordSuggestionEvent(
                    "suggestion-preserved",
                    context: context,
                    profile: profile,
                    metadata: [
                        "reason": geometryPreservationReason(
                            context: context,
                            profile: profile
                        ),
                        "geometryInvalidationReason": reason,
                        "fieldIdentity": geometryFieldIdentity.traceDescription
                    ]
                    .merging(invalidation.metadata) { current, _ in current }
                    .merging(geometryTraceMetadata()) { current, _ in current }
                )
                return
            }

            let currentRequest = suggestionOrchestrator.currentRequest
            let preservesPendingRequest = suggestionGeometryChangePolicy
                .shouldPreservePendingRequestWhenVisibleSuggestionInvalidates(
                    hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion,
                    hasPendingSuggestionRequest: currentRequest != nil,
                    pendingRequestTextBeforeCursor: currentRequest?.textBeforeCursor,
                    pendingRequestTextAfterCursor: currentRequest?.textAfterCursor,
                    pendingRequestFieldIdentityDescription: currentRequest?.fieldIdentityDescription,
                    currentTextBeforeCursor: context.textBeforeCursor,
                    currentTextAfterCursor: context.textAfterCursor,
                    currentFieldIdentityDescription: currentGeometrySnapshot.fieldIdentity?.traceDescription
                )
            preservesResidualSuggestionAfterNextWordAccept = false
            if !preservesPendingRequest {
                invalidatePendingSuggestionRequest()
            }
            hideSuggestion(
                reason: "stale-geometry-\(reason)",
                metadata: invalidation.metadata
                    .merging(geometryTraceMetadata()) { current, _ in current }
                    .merging(["pendingRequestPreserved": String(preservesPendingRequest)]) { current, _ in current }
            )
            return
        }

        lastTextStyle = context.textStyle
        lastCompatibilityLearningTrustContext = visualTrustContext
        showFieldStatusIndicator(.shown, context: context)
        guard let refreshedPlacement = refreshVisibleSuggestion(
            placement: placement,
            fallbackRenderMode: profile.fallbackRenderMode
        ) else {
            return
        }
        preservesResidualSuggestionAfterNextWordAccept = false
        lastVisibleSuggestionGeometrySnapshot = visibleGeometrySnapshot(
            context: context,
            fieldIdentity: currentFieldIdentity,
            placement: refreshedPlacement
        )
    }

    private func allowsStableChromeEditorGeometryChurn(
        context: FocusedTextContext,
        profile: CompatibilityProfile
    ) -> Bool {
        let searchableText = context.fingerprint.searchableText
        guard profile.bundleIdentifier == "com.google.Chrome",
              context.role == "AXTextArea",
              context.selectedTextLength == 0,
              (searchableText.contains("codemirror") || searchableText.contains("monaco")),
              let lastTextSnapshot,
              lastTextSnapshot.textBeforeCursor == context.textBeforeCursor,
              lastTextSnapshot.textAfterCursor == context.textAfterCursor else {
            return false
        }

        return true
    }

    private func shouldPreserveVisibleSuggestionDuringGeometryInvalidation(
        invalidation: SuggestionGeometryInvalidationDecision,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity
    ) -> Bool {
        visibleSuggestionPersistencePolicy.shouldPreserveDuringGeometryInvalidation(
            invalidationReason: invalidation.reason,
            appBundleIdentifier: profile.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            currentSuggestionBundleIdentifier: currentSuggestionState.appBundleIdentifier,
            currentSuggestionFieldIdentity: currentSuggestionState.fieldIdentity,
            currentSuggestionTextBeforeCursor: currentSuggestionState.textBeforeCursor,
            currentSuggestionAgeMilliseconds: currentSuggestionAgeMilliseconds(),
            isInvalidatedByUserTyping: currentSuggestionState.invalidatedByUserKeyDown,
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor
        )
    }

    private func geometryPreservationReason(
        context: FocusedTextContext,
        profile: CompatibilityProfile
    ) -> String {
        if profile.bundleIdentifier == "md.obsidian" {
            return "obsidian-document-start-geometry-teleport"
        }

        if currentSuggestionState.textBeforeCursor.map({ context.textBeforeCursor + context.textAfterCursor == $0 }) == true {
            return "transient-same-text-geometry-split"
        }

        return "transient-geometry-change"
    }

    private func recordAcceptedText(_ acceptedText: String) {
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

    private func refreshAfterNextWordAcceptance(
        residualReason: String,
        emptyReason: String,
        emptyMetadata: [String: String] = [:]
    ) {
        guard suggestionSession.hasVisibleSuggestion else {
            preservesResidualSuggestionAfterNextWordAccept = false
            setSuggestionDecision("Accepted: next word")
            hideSuggestion(reason: emptyReason, metadata: emptyMetadata)
            return
        }

        preservesResidualSuggestionAfterNextWordAccept = true
        setSuggestionDecision(residualReason)
        if let currentProfile {
            _ = refreshVisibleSuggestion(
                placement: nil,
                fallbackRenderMode: currentProfile.fallbackRenderMode
            )
        } else {
            updateKeyboardEventTapSnapshot()
        }
    }

    private func armObsidianPostAcceptanceSuppressionIfNeeded() {
        guard (currentSuggestionState.appBundleIdentifier ?? currentProfile?.bundleIdentifier) == "md.obsidian",
              let lastTextSnapshot,
              lastTextSnapshot.fieldIdentity == currentFieldIdentity else {
            return
        }

        obsidianPostAcceptanceSuppression = ObsidianPostAcceptanceSuppression(
            textBeforeCursor: lastTextSnapshot.textBeforeCursor,
            textAfterCursor: lastTextSnapshot.textAfterCursor,
            expiresAt: Date().addingTimeInterval(1.5)
        )
        DiagnosticsLog.shared.record(
            "obsidian-post-acceptance-suppression-armed",
            metadata: [
                "app": "md.obsidian",
                "beforeChars": String(lastTextSnapshot.textBeforeCursor.count),
                "afterChars": String(lastTextSnapshot.textAfterCursor.count)
            ]
        )
    }

    private func shouldSuppressObsidianPostAcceptanceRefresh(
        context: FocusedTextContext,
        profile: CompatibilityProfile
    ) -> Bool {
        guard profile.bundleIdentifier == "md.obsidian",
              let suppression = obsidianPostAcceptanceSuppression else {
            return false
        }

        if suppression.expiresAt <= Date() {
            obsidianPostAcceptanceSuppression = nil
            return false
        }

        guard suppression.matches(context: context) else {
            obsidianPostAcceptanceSuppression = nil
            return false
        }

        return true
    }

    private func advanceCurrentSuggestionBaseline(afterAccepting acceptedText: String) {
        guard !acceptedText.isEmpty else {
            return
        }

        if let lastTextSnapshot,
           lastTextSnapshot.fieldIdentity == currentFieldIdentity,
           let currentSuggestionAcceptanceSnapshot = currentSuggestionState.acceptanceSnapshot {
            currentSuggestionState.textBeforeCursor = lastTextSnapshot.textBeforeCursor
            currentSuggestionState.acceptanceSnapshot = currentSuggestionAcceptanceSnapshot.advancingTextRevision(
                textBeforeCursor: lastTextSnapshot.textBeforeCursor,
                textAfterCursor: lastTextSnapshot.textAfterCursor,
                selectedTextLength: 0
            )
            return
        }

        if let currentSuggestionTextBeforeCursor = currentSuggestionState.textBeforeCursor {
            let advancedTextBeforeCursor = currentSuggestionTextBeforeCursor + acceptedText
            currentSuggestionState.textBeforeCursor = advancedTextBeforeCursor
            if let currentSuggestionAcceptanceSnapshot = currentSuggestionState.acceptanceSnapshot {
                currentSuggestionState.acceptanceSnapshot = currentSuggestionAcceptanceSnapshot.advancingTextRevision(
                    textBeforeCursor: advancedTextBeforeCursor,
                    textAfterCursor: currentSuggestionAcceptanceSnapshot.textAfterCursor,
                    selectedTextLength: 0
                )
            }
        }
    }

    private func recordTypedOverSuggestionIfNeeded(
        newTextBeforeCursor: String,
        fieldIdentity: FocusedFieldIdentity,
        profile: CompatibilityProfile
    ) {
        guard suggestionSession.hasVisibleSuggestion,
              let suggestionID = currentSuggestionState.id,
              let originalTextBeforeCursor = currentSuggestionState.textBeforeCursor,
              let displayedText = currentSuggestionState.displayedText,
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

        guard case let .typedOver(typedSuffix) = progress,
              !shouldPreserveVisibleSuggestionWhileTyping(displayedText: displayedText) else {
            return
        }

        var metadata = [
            "typedSuffixChars": String(typedSuffix.count)
        ]
        metadata.merge(recordPrefixFamilyCooldown(
            .typedOver,
            input: PrefixFamilyCooldownInput(
                appBundleIdentifier: profile.bundleIdentifier,
                fieldIdentifier: fieldIdentity.traceDescription,
                requestMode: currentSuggestionState.requestMode,
                textBeforeCursor: newTextBeforeCursor
            )
        )) { current, _ in current }
        metadata.merge(currentSuggestionLifetimeMetadata()) { current, _ in current }

        RawAutocompleteTraceLog.shared.record(
            type: .suggestionTypedOver,
            suggestionID: suggestionID,
            appBundleIdentifier: profile.bundleIdentifier,
            fieldIdentity: fieldIdentity.traceDescription,
            requestMode: currentSuggestionState.requestMode?.rawValue ?? "",
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
                requestMode: currentSuggestionState.requestMode,
                fieldKind: currentSuggestionState.fieldClassification?.kind ?? .unknown
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
              let originalTextBeforeCursor = currentSuggestionState.textBeforeCursor,
              let displayedText = currentSuggestionState.displayedText,
              context.textBeforeCursor.hasPrefix(originalTextBeforeCursor),
              context.textBeforeCursor != originalTextBeforeCursor else {
            return false
        }

        let baselineSnapshot = currentSuggestionState.acceptanceSnapshot?.focusedTextSnapshot
            ?? FocusedTextSnapshot(
                fieldIdentity: fieldIdentity,
                textBeforeCursor: originalTextBeforeCursor,
                textAfterCursor: context.textAfterCursor
            )
        let transition = typeThroughPrefixStateMachine.apply(
            to: &suggestionSession,
            input: TypeThroughPrefixInput(
                baselineSnapshot: baselineSnapshot,
                currentSnapshot: snapshot
            )
        )

        switch transition {
        case let .survived(survival):
            let hasRemainingSuggestion = suggestionSession.hasVisibleSuggestion
            let survivalMetadata = survival.traceMetadata
            lastTextSnapshot = snapshot
            invalidatePendingSuggestionRequest()
            currentSuggestionState.textBeforeCursor = context.textBeforeCursor
            currentSuggestionState.displayedText = suggestionSession.visibleSuggestion?.visibleText
            if let currentSuggestionAcceptanceSnapshot = currentSuggestionState.acceptanceSnapshot {
                currentSuggestionState.acceptanceSnapshot = currentSuggestionAcceptanceSnapshot.advancingTextRevision(
                    textBeforeCursor: context.textBeforeCursor,
                    textAfterCursor: context.textAfterCursor,
                    selectedTextLength: context.selectedTextLength
                )
            }
            currentSuggestionState.invalidatedByUserKeyDown = false
            setSuggestionDecision(hasRemainingSuggestion ? "Shown: typing through suggestion" : "Queued: refreshing after typed suggestion")
            recordSuggestionEvent(
                "suggestion-typed-through",
                context: context,
                profile: profile,
                metadata: survivalMetadata
            )
            keyboardEventTap?.suppressPassthroughObservation(for: 0.35)
            if hasRemainingSuggestion {
                repositionVisibleSuggestion(context: context, profile: profile)
                return true
            }

            lastRequestedTextBeforeCursor = nil
            return false
        case .invalidated(.mismatch):
            if shouldPreserveVisibleSuggestionWhileTyping(displayedText: displayedText) {
                lastRequestedTextBeforeCursor = nil
                setSuggestionDecision("Shown: refreshing while typing")
                recordSuggestionEvent(
                    "suggestion-refresh-after-typing-diverged",
                    context: context,
                    profile: profile,
                    metadata: [
                        "reason": "typing-diverged-from-visible-suggestion",
                        "visibleSuggestionWords": String(visibleWordCount(in: displayedText))
                    ]
                )
                updateKeyboardEventTapSnapshot()
                return false
            }

            suggestionRepetitionSuppressor.recordMiss(
                displayedText,
                mode: currentSuggestionState.requestMode,
                scope: currentSuggestionState.appBundleIdentifier ?? currentProfile?.bundleIdentifier ?? ""
            )
            hideSuggestion(reason: "typed-over")
        case let .invalidated(reason):
            hideSuggestion(
                reason: "type-through-\(reason.rawValue)",
                metadata: transition.traceMetadata
            )
        case let .suppressed(reason):
            hideSuggestion(
                reason: "type-through-\(reason.rawValue)",
                metadata: transition.traceMetadata
            )
        case .unchanged:
            return false
        }

        return false
    }

    private func shouldPreserveVisibleSuggestionWhileTyping(displayedText: String) -> Bool {
        guard currentSuggestionState.requestMode?.isContinuation == true else {
            return false
        }

        return visibleWordCount(in: displayedText) > 1
    }

    private func visibleWordCount(in text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }

    private func hideSuggestion(
        reason: String = "hidden",
        metadata extraMetadata: [String: String] = [:]
    ) {
        if suggestionSession.hasVisibleSuggestion,
           let suggestionID = currentSuggestionState.id {
            let appBundleIdentifier = currentSuggestionState.appBundleIdentifier ?? currentProfile?.bundleIdentifier ?? ""
            let fieldIdentityDescription = currentSuggestionState.fieldIdentity?.traceDescription
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
            let displayedText = currentSuggestionState.displayedText ?? suggestionSession.visibleSuggestion?.visibleText ?? ""
            let lifetimeMilliseconds = currentSuggestionLifetimeMilliseconds()
            var metadata = currentSuggestionLifetimeMetadata(lifetimeMilliseconds: lifetimeMilliseconds)

            if outcome == "ignored" {
                let missRecord = suggestionRepetitionSuppressor.recordIgnored(
                    displayedText,
                    mode: currentSuggestionState.requestMode,
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
                requestMode: currentSuggestionState.requestMode?.rawValue ?? "",
                displayedText: displayedText,
                outcome: outcome,
                reason: reason,
                metadata: metadata
            )
            setSuggestionDecision("Hidden: \(reason)")
        }

        suggestionSession.dismiss()
        currentSuggestionState.id = nil
        currentSuggestionState.appBundleIdentifier = nil
        currentSuggestionState.fieldIdentity = nil
        currentSuggestionState.requestMode = nil
        currentSuggestionState.textBeforeCursor = nil
        currentSuggestionState.acceptanceSnapshot = nil
        currentSuggestionState.displayedText = nil
        currentSuggestionState.fieldClassification = nil
        currentSuggestionState.presentedAt = nil
        currentSuggestionState.displayScoreFinal = nil
        currentSuggestionState.invalidatedByUserKeyDown = false
        preservesResidualSuggestionAfterNextWordAccept = false
        suggestionOrchestrator.clearStreamingPresentations()
        lastCaretRect = nil
        lastTextLineRect = nil
        lastClippingRect = nil
        lastTextStyle = nil
        lastRenderMode = nil
        lastCompatibilityLearningTrustContext = nil
        lastVisibleSuggestionGeometrySnapshot = nil
        suggestionPanel.hide()
        updateKeyboardEventTapSnapshot()
        scheduleKeyboardEventTapStopIfIdle()
    }

    private func showFieldStatusIndicator(
        _ state: FieldStatusIndicatorState,
        context: FocusedTextContext
    ) {
        guard let anchorRect = context.caretRect
            ?? context.textLineRect
            ?? context.elementRect
            ?? context.windowRect else {
            fieldStatusIndicator.hide()
            return
        }

        fieldStatusIndicator.show(
            state: state,
            near: anchorRect,
            fieldRect: context.elementRect
        )
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

        let decisionPresentation = SuggestionDecisionPresentation(lastSuggestionDecision)
        statusMenuItem?.title = statusLine
        statusMenuItem?.toolTip = lastSuggestionDecision
        suggestionDecisionMenuItem?.title = decisionPresentation.menuTitle
        suggestionDecisionMenuItem?.toolTip = lastSuggestionDecision
        pauseSuggestionsMenuItem?.title = pauseSuggestionsTitle
        silenceFieldMenuItem?.title = fieldControlState.buttonTitle
        silenceFieldMenuItem?.isEnabled = fieldControlState.canSilence
        silenceFieldMenuItem?.toolTip = fieldControlState.detailText
        toggleAppMenuItem?.title = appControlState?.menuToggleTitle ?? "Pause Current App"
        toggleAppMenuItem?.isEnabled = appControlState?.canToggle ?? false
        toggleAppMenuItem?.toolTip = appControlState?.fallbackText
        if settingsWindow.isShowing {
            settingsWindow.refresh(
                isTrusted: accessibilityClient.isTrusted,
                suggestionsPaused: suggestionsPaused,
                suggestionsPausedUntil: suggestionsPausedUntil,
                runtimeReport: runtimeReadinessReport,
                runtimeTargetSummary: runtimeTargetSummary,
                modelDirectoryPath: modelDirectoryPath,
                modelInstallStatusText: modelInstallStatusText,
                isModelInstallInProgress: modelInstallTask != nil,
                currentApp: settingsCurrentAppState,
                fieldControl: settingsFieldControlState,
                practice: settingsPracticeState,
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
                "decision": lastSuggestionDecision,
                "decisionKind": decisionPresentation.diagnosticsKind,
                "decisionSummary": decisionPresentation.summary
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
            return "Not active in \(app.localizedName)"
        }

        guard appEnabled else {
            return "Paused in \(app.localizedName)"
        }

        switch SuggestionDecisionPresentation(lastSuggestionDecision).statusKind {
        case .shown:
            return "Suggesting in \(app.localizedName)"
        case .thinking:
            return "Thinking in \(app.localizedName)"
        case .waiting, .quiet, .ready:
            return "Ready in \(app.localizedName)"
        }
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

        suppressField(currentFieldIdentity, profile: currentProfile, reason: reason)
    }

    private func suppressCurrentFieldAfterInsertionFailure(reason: String) {
        guard let currentProfile,
              let currentFieldIdentity,
              !suppressedFieldIdentities.contains(currentFieldIdentity),
              insertionFailureSuppressionPolicy.shouldSuppressField(
                  profile: currentProfile,
                  failureReason: reason
              ) else {
            return
        }

        suppressField(currentFieldIdentity, profile: currentProfile, reason: reason)
    }

    private func suppressField(
        _ fieldIdentity: FocusedFieldIdentity,
        profile: CompatibilityProfile,
        reason: String
    ) {
        suppressedFieldIdentities.insert(fieldIdentity)
        DiagnosticsLog.shared.record(
            "field-suppressed",
            metadata: [
                "app": profile.bundleIdentifier,
                "fieldIdentity": fieldIdentity.traceDescription,
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
            ?? currentSuggestionState.appBundleIdentifier
            ?? currentProfile?.bundleIdentifier
            ?? targetAppForControls()?.bundleIdentifier
        guard let resolvedAppBundleIdentifier else {
            return nil
        }

        return annoyanceContext(
            appBundleIdentifier: resolvedAppBundleIdentifier,
            fieldIdentity: currentSuggestionState.fieldIdentity ?? currentFieldIdentity,
            requestMode: currentSuggestionState.requestMode,
            fieldKind: fieldKind
                ?? currentSuggestionState.fieldClassification?.kind
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
        guard let currentSuggestionPresentedAt = currentSuggestionState.presentedAt else {
            return nil
        }

        return max(0, Int(now.timeIntervalSince(currentSuggestionPresentedAt) * 1_000))
    }

    private func currentPrefixFamilyCooldownInput(
        textBeforeCursor: String? = nil
    ) -> PrefixFamilyCooldownInput? {
        let appBundleIdentifier = currentSuggestionState.appBundleIdentifier ?? currentProfile?.bundleIdentifier
        let fieldIdentity = currentSuggestionState.fieldIdentity ?? currentFieldIdentity
        let textBeforeCursor = textBeforeCursor ?? currentSuggestionState.textBeforeCursor
        guard let appBundleIdentifier,
              let fieldIdentity,
              let textBeforeCursor else {
            return nil
        }

        return PrefixFamilyCooldownInput(
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentifier: fieldIdentity.traceDescription,
            requestMode: currentSuggestionState.requestMode,
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

    private func schedulePrefixCooldownRetry(
        for snapshot: FocusedTextSnapshot,
        cooldown: PrefixFamilyCooldown
    ) {
        cancelPrefixCooldownRetry()
        let delayMilliseconds = max(
            0,
            Int(cooldown.until.timeIntervalSinceNow * 1_000) + 25
        )
        let reason = cooldown.reason.rawValue
        prefixCooldownRetryTask = Task { [weak self, snapshot, reason, delayMilliseconds] in
            try? await Task.sleep(for: .milliseconds(delayMilliseconds))
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard let self,
                      self.lastTextSnapshot == snapshot,
                      !self.suggestionSession.hasVisibleSuggestion else {
                    return
                }

                self.lastTextSnapshot = nil
                self.lastRequestedTextBeforeCursor = nil
                self.suggestionBlockLogGate.reset()
                self.setSuggestionDecision("Ready: prefix \(reason) expired")
                DiagnosticsLog.shared.record(
                    "prefix-family-cooldown-expired",
                    metadata: [
                        "reason": reason,
                        "fieldIdentity": snapshot.fieldIdentity.traceDescription
                    ]
                )
            }
        }
    }

    private func cancelPrefixCooldownRetry() {
        prefixCooldownRetryTask?.cancel()
        prefixCooldownRetryTask = nil
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
        cancelPrefixCooldownRetry()

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
        typingBurstState.reset()
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
        cancelPrefixCooldownRetry()

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
        typingBurstState.reset()
        fieldStatusIndicator.hide()
        if resetBlockLogGate {
            suggestionBlockLogGate.reset()
        }
    }

    private func invalidatePendingSuggestionRequest() {
        cancelPendingSuggestionTask(reason: "invalidate")
        suggestionOrchestrator.clearStreamingPresentations()
        suggestionOrchestrator.invalidate()
    }

    private func cancelPendingSuggestionTask(reason: String) {
        guard let debounceTask else {
            return
        }

        debounceTask.cancel()
        self.debounceTask = nil
        debounceTaskSuggestionID = nil
        suggestionOrchestrator.clearStreamingPresentations()
        DiagnosticsLog.shared.record(
            "suggestion-request-cancelled",
            metadata: [
                "reason": reason
            ]
        )
    }

    private func clearCompletedSuggestionTask(suggestionID: String) {
        guard debounceTaskSuggestionID == suggestionID else {
            return
        }

        debounceTask = nil
        debounceTaskSuggestionID = nil
    }

    @objc
    private func requestAccessibilityPermission() {
        accessibilityClient.requestPermissionIfNeeded()
        settingsWindow.refresh(
            isTrusted: accessibilityClient.isTrusted,
            suggestionsPaused: suggestionsPaused,
            suggestionsPausedUntil: suggestionsPausedUntil,
            runtimeReport: runtimeReadinessReport,
            runtimeTargetSummary: runtimeTargetSummary,
            modelDirectoryPath: modelDirectoryPath,
            modelInstallStatusText: modelInstallStatusText,
            isModelInstallInProgress: modelInstallTask != nil,
            currentApp: settingsCurrentAppState,
            fieldControl: settingsFieldControlState,
            practice: settingsPracticeState,
            privacy: settingsPrivacyState,
            keyboardShortcuts: settingsKeyboardShortcutState,
            suggestionAggressiveness: settingsSuggestionAggressivenessState,
            lastSuggestionDecision: lastSuggestionDecision
        )
        DiagnosticsLog.shared.record("request-accessibility")
    }

    @objc
    private func suggestNowFromMenu() {
        requestSuggestionNow(source: "menu")
    }

    private func requestSuggestionNow(source: String) {
        guard accessibilityClient.isTrusted else {
            setSuggestionDecision("Blocked: Accessibility permission missing")
            showSettings()
            DiagnosticsLog.shared.record(
                "suggestion-summon-blocked",
                metadata: [
                    "source": source,
                    "reason": "accessibility-permission-missing"
                ]
            )
            return
        }

        guard !suggestionsPaused else {
            setSuggestionDecision("Paused")
            DiagnosticsLog.shared.record(
                "suggestion-summon-blocked",
                metadata: [
                    "source": source,
                    "reason": "global-pause"
                ]
            )
            return
        }

        manualSuggestionRequestPending = true
        lastRequestedTextBeforeCursor = nil
        suggestionPipeline.resetPollingPause()
        setSuggestionDecision("Queued: asked once")
        DiagnosticsLog.shared.record(
            "suggestion-summon-requested",
            metadata: [
                "source": source,
                "shortcut": suggestionSummonHotKey.descriptor.diagnosticName
            ]
        )
        pollFocusedTextForManualSuggestion()
    }

    private func pollFocusedTextForManualSuggestion() {
        let now = Date()
        guard !suggestionPipeline.isPollInFlight else {
            suggestionPipeline.notePollAttempt(at: now)
            setSuggestionDecision("Waiting: checking field")
            scheduleManualSuggestionRetry()
            return
        }

        suggestionPipeline.notePollAttempt(at: now)
        suggestionPipeline.beginInFlightPoll()
        let startedAt = DispatchTime.now().uptimeNanoseconds
        var completesAsync = false
        pollFocusedText(startedAt: startedAt, completesAsync: &completesAsync)
        if !completesAsync {
            manualSuggestionRequestPending = false
            suggestionPipeline.finishPoll(startedAt: startedAt)
        }
    }

    private func scheduleManualSuggestionRetry() {
        manualSuggestionRetryTask?.cancel()
        manualSuggestionRetryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard let self, self.manualSuggestionRequestPending else {
                return
            }
            self.pollFocusedTextForManualSuggestion()
        }
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

    private func startTextEditPractice() {
        guard accessibilityClient.isTrusted else {
            requestAccessibilityPermission()
            return
        }

        guard runtimeReadinessReport.allowsSuggestions else {
            setSuggestionDecision("Blocked: model not ready")
            refreshRuntimeChrome()
            showSettings()
            return
        }

        disabledBundleIdentifiers.remove(Self.textEditPracticeBundleIdentifier)
        markAppEnablementSetupCompleted()
        persistDisabledApps()

        setSuggestionDecision(suggestionsPaused ? "Paused: TextEdit practice ready" : "Ready: TextEdit practice")
        openTextEditPracticeDocument()
        DiagnosticsLog.shared.record(
            "textedit-practice-started",
            metadata: [
                "app": Self.textEditPracticeBundleIdentifier,
                "model": runtimeReadinessReport.summary,
                "globalPaused": String(suggestionsPaused),
                "textEditEnabled": String(!disabledBundleIdentifiers.contains(Self.textEditPracticeBundleIdentifier))
            ]
        )
        refreshRuntimeChrome()
    }

    private func openTextEditPracticeDocument() {
        do {
            let documentURL = try writeTextEditPracticeDocument()
            openTextEditPracticeDocument(at: documentURL)
        } catch {
            DiagnosticsLog.shared.record(
                "textedit-practice-document-failed",
                metadata: ["reason": error.localizedDescription]
            )
            openTextEditWithoutDocument()
        }
    }

    private func writeTextEditPracticeDocument() throws -> URL {
        let documentURL = Self.textEditPracticeDocumentURL
        try FileManager.default.createDirectory(
            at: documentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Self.textEditPracticeDocumentText.write(to: documentURL, atomically: true, encoding: .utf8)
        return documentURL
    }

    private func openTextEditPracticeDocument(at documentURL: URL) {
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: Self.textEditPracticeBundleIdentifier
        ) else {
            NSWorkspace.shared.open(documentURL)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(
            [documentURL],
            withApplicationAt: appURL,
            configuration: configuration
        ) { _, error in
            if let error {
                DiagnosticsLog.shared.record(
                    "textedit-practice-open-failed",
                    metadata: ["reason": error.localizedDescription]
                )
            }
        }
    }

    private func openTextEditWithoutDocument() {
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: Self.textEditPracticeBundleIdentifier
        ) else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
            if let error {
                DiagnosticsLog.shared.record(
                    "textedit-open-failed",
                    metadata: ["reason": error.localizedDescription]
                )
            }
        }
    }

    @objc
    private func showSettings() {
        settingsWindow.show(
            isTrusted: accessibilityClient.isTrusted,
            suggestionsPaused: suggestionsPaused,
            suggestionsPausedUntil: suggestionsPausedUntil,
            runtimeReport: runtimeReadinessReport,
            runtimeTargetSummary: runtimeTargetSummary,
            modelDirectoryPath: modelDirectoryPath,
            modelInstallStatusText: modelInstallStatusText,
            isModelInstallInProgress: modelInstallTask != nil,
            currentApp: settingsCurrentAppState,
            fieldControl: settingsFieldControlState,
            practice: settingsPracticeState,
            privacy: settingsPrivacyState,
            keyboardShortcuts: settingsKeyboardShortcutState,
            suggestionAggressiveness: settingsSuggestionAggressivenessState,
            lastSuggestionDecision: lastSuggestionDecision
        )
    }

    @objc
    private func openFeedbackForm() {
        let link = BetaFeedbackLink()
        if NSWorkspace.shared.open(link.url) {
            DiagnosticsLog.shared.record(
                "feedback-form-opened",
                metadata: ["destination": "github-beta-issue-template"]
            )
        } else {
            DiagnosticsLog.shared.record(
                "feedback-form-open-failed",
                metadata: ["destination": "github-beta-issue-template"]
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
        let previousRuntime = modelRuntime
        runtimeWarmTask?.cancel()
        invalidatePendingSuggestionRequest()
        previousRuntime.cancel()
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

    private func launchDiagnosticsMetadata() -> [String: String] {
        var metadata = ["accessibility": String(accessibilityClient.isTrusted)]
        if let executableURL = Bundle.main.executableURL,
           let executableSHA256 = try? ModelAssetIntegrityReceiptWriter.sha256(executableURL) {
            metadata["executableSHA256"] = executableSHA256
        }
        return metadata
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
            pauseControl: pauseControlState,
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
        compatibilityLearningStore.deleteAll()
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
        suggestionRepetitionSuppressor = SuggestionRepetitionSuppressor()
        suggestionOrchestrator.resetPrefixFamilyCooldownPolicy(makePrefixFamilyCooldownPolicy())
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

    private func effectiveSuggestionPace(for profile: CompatibilityProfile) -> SuggestionPace {
        suggestionAggressivenessPolicy.pace(
            userPace: suggestionTuning.pace,
            supportStatus: .supported(profile)
        )
    }

    private func allowsSentenceBoundaryContinuation(for profile: CompatibilityProfile) -> Bool {
        !profile.promptAppSafetyMode.isPromptSurface
    }

    private func usesDailyDriverLineStartPhraseContinuation(for profile: CompatibilityProfile) -> Bool {
        guard !profile.promptAppSafetyMode.isPromptSurface else {
            return false
        }

        return profile.bundleIdentifier == "md.obsidian" && suggestionTuning.aggressivenessLevel >= 4
    }

    private func minimumPhraseContinuationWords(for profile: CompatibilityProfile) -> Int {
        usesDailyDriverLineStartPhraseContinuation(for: profile)
            ? 1
            : suggestionTuning.phraseStartWords
    }

    private func activationPolicy(for profile: CompatibilityProfile) -> CompletionActivationPolicy {
        suggestionTuning.activationPolicy(
            supportPace: effectiveSuggestionPace(for: profile),
            allowsSentenceBoundaryContinuation: allowsSentenceBoundaryContinuation(for: profile),
            minimumPhraseContinuationWords: minimumPhraseContinuationWords(for: profile)
        )
    }


    private func triggerPolicy(for profile: CompatibilityProfile) -> SuggestionTriggerPolicy {
        suggestionTuning.triggerPolicy(
            supportPace: effectiveSuggestionPace(for: profile),
            allowsSentenceBoundaryContinuation: allowsSentenceBoundaryContinuation(for: profile),
            minimumPhraseContinuationWords: minimumPhraseContinuationWords(for: profile),
            allowsPlainLineStartPhraseContinuation: usesDailyDriverLineStartPhraseContinuation(for: profile),
            allowsListLabelPhraseContinuation: usesDailyDriverLineStartPhraseContinuation(for: profile)
        )
    }

    private func maxVisibleWords(
        for requestMode: CompletionRequestMode,
        profile: CompatibilityProfile
    ) -> Int {
        effectiveSuggestionPace(for: profile).maxVisibleWords(
            defaultMaxVisibleWords: suggestionTuning.maxVisibleWords,
            requestMode: requestMode
        )
    }

    private func shouldAskModelForWordCompletionFallback() -> Bool {
        suggestionTuning.allowsModelWordCompletionFallback()
    }

    private func shouldUsePredictiveWordFallback(
        profile: CompatibilityProfile
    ) -> Bool {
        suggestionTuning.allowsPredictiveWordFallback(
            appBundleIdentifier: profile.bundleIdentifier
        )
    }

    private func shouldUsePredictivePhraseFallback(
        profile: CompatibilityProfile,
        behaviorProfileID: AutocompleteBehaviorProfileID?
    ) -> Bool {
        suggestionTuning.allowsPredictivePhraseFallback(
            appBundleIdentifier: profile.bundleIdentifier,
            behaviorProfileID: behaviorProfileID
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
                "acceptAllShortcut": shortcut.rawValue
            ]
        )
        refreshRuntimeChrome()
    }

    private func setSuggestionAggressivenessLevel(_ level: Int) {
        setSuggestionTuning(
            updatedSuggestionTuning(aggressivenessLevel: level),
            reason: "aggressiveness-changed"
        )
    }

    private func setSuggestionMaxVisibleWords(_ words: Int) {
        setSuggestionTuning(
            updatedSuggestionTuning(maxVisibleWords: words),
            reason: "max-visible-words-changed"
        )
    }

    private func setSuggestionWordStartCharacters(_ characters: Int) {
        setSuggestionTuning(
            updatedSuggestionTuning(wordStartCharacters: characters),
            reason: "word-start-characters-changed"
        )
    }

    private func setSuggestionPhraseStartWords(_ words: Int) {
        setSuggestionTuning(
            updatedSuggestionTuning(phraseStartWords: words),
            reason: "phrase-start-words-changed"
        )
    }

    private func setSuggestionResponseSpeedLevel(_ level: Int) {
        setSuggestionTuning(
            updatedSuggestionTuning(responseSpeedLevel: level),
            reason: "response-speed-changed"
        )
    }

    private func setSuggestionConfidenceLevel(_ level: Int) {
        setSuggestionTuning(
            updatedSuggestionTuning(confidenceLevel: level),
            reason: "confidence-changed"
        )
    }

    private func setSuggestionLearningRestraintLevel(_ level: Int) {
        setSuggestionTuning(
            updatedSuggestionTuning(learningRestraintLevel: level),
            reason: "learning-restraint-changed"
        )
    }

    private func resetSuggestionTuning() {
        setSuggestionTuning(SuggestionTuning(), reason: "reset-tuning")
    }

    private func updatedSuggestionTuning(
        aggressivenessLevel: Int? = nil,
        maxVisibleWords: Int? = nil,
        wordStartCharacters: Int? = nil,
        phraseStartWords: Int? = nil,
        responseSpeedLevel: Int? = nil,
        confidenceLevel: Int? = nil,
        learningRestraintLevel: Int? = nil
    ) -> SuggestionTuning {
        SuggestionTuning(
            aggressivenessLevel: aggressivenessLevel ?? suggestionTuning.aggressivenessLevel,
            maxVisibleWords: maxVisibleWords ?? suggestionTuning.maxVisibleWords,
            wordStartCharacters: wordStartCharacters ?? suggestionTuning.wordStartCharacters,
            phraseStartWords: phraseStartWords ?? suggestionTuning.phraseStartWords,
            responseSpeedLevel: responseSpeedLevel ?? suggestionTuning.responseSpeedLevel,
            confidenceLevel: confidenceLevel ?? suggestionTuning.confidenceLevel,
            learningRestraintLevel: learningRestraintLevel ?? suggestionTuning.learningRestraintLevel
        )
    }

    private func setSuggestionTuning(_ next: SuggestionTuning, reason: String) {
        guard next != suggestionTuning else {
            refreshRuntimeChrome()
            return
        }

        suggestionTuning = next
        persistSuggestionTuning()
        applySuggestionTuningChange(reason: reason)
        DiagnosticsLog.shared.record(
            "suggestion-tuning-control",
            metadata: [
                "surface": "settings",
                "suggestionAggressivenessLevel": String(suggestionTuning.aggressivenessLevel),
                "suggestionAggressiveness": suggestionTuning.legacyAggressiveness.rawValue,
                "suggestionMaxVisibleWords": String(suggestionTuning.maxVisibleWords),
                "suggestionWordStartCharacters": String(suggestionTuning.wordStartCharacters),
                "suggestionPhraseStartWords": String(suggestionTuning.phraseStartWords),
                "suggestionResponseSpeedLevel": String(suggestionTuning.responseSpeedLevel),
                "suggestionConfidenceLevel": String(suggestionTuning.confidenceLevel),
                "suggestionLearningRestraintLevel": String(suggestionTuning.learningRestraintLevel),
                "reason": reason
            ]
        )
        refreshRuntimeChrome()
    }

    private func applySuggestionTuningChange(reason: String) {
        lastRequestedTextBeforeCursor = nil
        invalidatePendingSuggestionRequest()
        if suggestionSession.hasVisibleSuggestion {
            hideSuggestion(reason: reason)
        }
        setSuggestionDecision("Ready: \(suggestionTuning.displayName.lowercased()) suggestions")
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

        return currentSuggestionState.appBundleIdentifier ?? currentProfile?.bundleIdentifier
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
                    requestMode: currentSuggestionState.requestMode
                )
            RawAutocompleteTraceLog.shared.record(
                type: .appDisabled,
                suggestionID: currentSuggestionState.id ?? "",
                appBundleIdentifier: app.bundleIdentifier,
                fieldIdentity: context.fieldIdentifier,
                requestMode: context.requestMode?.rawValue ?? "",
                reason: "manual"
            )
            recordAnnoyanceSignal(
                .appDisable,
                context: context,
                suggestionID: currentSuggestionState.id ?? "",
                reason: "manual"
            )
            clearFocusedFieldState(hideReason: "app-disabled")
            stopKeyboardEventTapNow(reason: "app-disabled")
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
        let suggestionID = currentSuggestionState.id ?? ""
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
            requestMode: currentSuggestionState.requestMode?.rawValue ?? "",
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
        let suggestionID = currentSuggestionState.id ?? ""
        setSuggestionDecision("Blocked: current field silenced")
        invalidatePendingSuggestionRequest()
        if suggestionSession.hasVisibleSuggestion {
            hideSuggestion(reason: "field-silenced")
        }
        stopKeyboardEventTapNow(reason: "field-silenced")

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
                suggestionID: currentSuggestionState.id ?? "",
                appBundleIdentifier: context?.appBundleIdentifier ?? currentProfile?.bundleIdentifier ?? "",
                fieldIdentity: context?.fieldIdentifier ?? "",
                requestMode: context?.requestMode?.rawValue ?? "",
                reason: "manual"
            )
            recordAnnoyanceSignal(
                .manualPause,
                context: context,
                suggestionID: currentSuggestionState.id ?? "",
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

    @objc
    private func pauseSuggestionsUntilTomorrowFromControl() {
        let state = suggestionPauseSchedulePolicy.pauseUntilTomorrow(now: Date())
        applyScheduledPause(
            state: state,
            decisionText: "Paused until tomorrow",
            reason: "pause-until-tomorrow",
            metadata: ["duration": "until-tomorrow"]
        )
    }

    private func pauseSuggestions(for durationSeconds: TimeInterval, label: String) {
        let state = suggestionPauseSchedulePolicy.timedPause(
            now: Date(),
            durationSeconds: durationSeconds
        )
        applyScheduledPause(
            state: state,
            decisionText: "Paused for \(label)",
            reason: "timed-pause",
            metadata: ["durationSeconds": String(Int(durationSeconds))]
        )
    }

    private func applyScheduledPause(
        state: SuggestionPauseScheduleState,
        decisionText: String,
        reason: String,
        metadata: [String: String]
    ) {
        let context = currentAnnoyanceContext()
        let suggestionID = currentSuggestionState.id ?? ""
        suggestionsPaused = state.isPaused
        suggestionsPausedUntil = state.pausedUntil
        setSuggestionDecision(decisionText)
        clearFocusedFieldState(hideReason: reason)
        stopKeyboardEventTapNow(reason: reason)
        RawAutocompleteTraceLog.shared.record(
            type: .appPaused,
            suggestionID: suggestionID,
            appBundleIdentifier: context?.appBundleIdentifier ?? currentProfile?.bundleIdentifier ?? "",
            fieldIdentity: context?.fieldIdentifier ?? "",
            requestMode: context?.requestMode?.rawValue ?? "",
            reason: reason,
            metadata: metadata
        )
        recordAnnoyanceSignal(
            .manualPause,
            context: context,
            suggestionID: suggestionID,
            reason: reason,
            metadata: metadata
        )
        persistPauseState()
        schedulePauseExpiration()
        DiagnosticsLog.shared.record(
            "suggestions-control",
            metadata: metadata.merging([
                "paused": String(suggestionsPaused),
                "pausedUntil": suggestionsPausedUntil.map { ISO8601DateFormatter().string(from: $0) } ?? ""
            ]) { current, _ in current }
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

    static var suggestionAggressivenessLevelDefaultsKey: String {
        "SuggestionAggressivenessLevel"
    }

    static var suggestionMaxVisibleWordsDefaultsKey: String {
        "SuggestionMaxVisibleWords"
    }

    static var suggestionWordStartCharactersDefaultsKey: String {
        "SuggestionWordStartCharacters"
    }

    static var suggestionPhraseStartWordsDefaultsKey: String {
        "SuggestionPhraseStartWords"
    }

    static var suggestionResponseSpeedLevelDefaultsKey: String {
        "SuggestionResponseSpeedLevel"
    }

    static var suggestionConfidenceLevelDefaultsKey: String {
        "SuggestionConfidenceLevel"
    }

    static var suggestionLearningRestraintLevelDefaultsKey: String {
        "SuggestionLearningRestraintLevel"
    }

    static var suggestionTuningDefaultsVersionDefaultsKey: String {
        "SuggestionTuningDefaultsVersion"
    }

    static var currentSuggestionTuningDefaultsVersion: Int {
        6
    }

    static var previousDefaultSuggestionAggressivenessLevel: Int {
        SuggestionAggressiveness.normal.defaultTuningLevel
    }

    static var temporarilyEnabledBundleIDsEnvironmentKey: String {
        "AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS"
    }

    static func environmentFlagEnabled(_ value: String?) -> Bool {
        guard let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }
        return ["1", "true", "yes", "on"].contains(normalized)
    }


    static var textEditPracticeBundleIdentifier: String {
        "com.apple.TextEdit"
    }

    static var textEditPracticeDocumentURL: URL {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return supportDirectory
            .appendingPathComponent("AutocompleteLab", isDirectory: true)
            .appendingPathComponent("TextEdit Practice.txt")
    }

    static var textEditPracticeDocumentText: String {
        """
        SteadyType practice

        This is a disposable local TextEdit file.
        Suggestions appear as a small floating suggestion next to the cursor.
        They do not enter the document until you accept them.

        Press Tab once to accept one word plus a space.
        Press Tab again to accept the next suggested word.
        Press Esc to dismiss a suggestion without changing text.
        Use Pause Suggestions to stop suggestions everywhere.
        Use Pause in TextEdit to stop suggestions only in TextEdit.

        Typed text, prompts, model output, accepted text, screenshots, document names, URLs, recipients, and subject lines stay on this Mac by default.
        Write-test only in TextEdit, Notes, Obsidian, and the included Chrome local practice pages.
        Mail, Atlas, Slack, Discord, Notion, search, login, payment, address, URL, secure, and private fields stay off until proof says otherwise.

        Return to SteadyType Settings to delete traces or export only the redacted Privacy Bundle.

        Practice here:

        """
    }

    func loadPauseState() {
        let defaults = UserDefaults.standard
        let pausedUntilValue = defaults.double(forKey: Self.suggestionsPausedUntilDefaultsKey)
        let pausedUntil = pausedUntilValue > 0 ? Date(timeIntervalSince1970: pausedUntilValue) : nil
        let persistedIsPaused = defaults.object(forKey: Self.suggestionsPausedDefaultsKey) as? Bool
        let startupState = suggestionControlPolicy.startupState(persistedIsPaused: persistedIsPaused)
        let state = suggestionPauseSchedulePolicy.normalizedState(
            isPaused: startupState.isPaused,
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

    func loadSuggestionTuning() {
        let defaults = UserDefaults.standard
        var level: Int
        let hasStoredLevel = defaults.object(forKey: Self.suggestionAggressivenessLevelDefaultsKey) != nil
        if defaults.object(forKey: Self.suggestionAggressivenessLevelDefaultsKey) != nil {
            level = defaults.integer(forKey: Self.suggestionAggressivenessLevelDefaultsKey)
        } else {
            level = SuggestionAggressiveness
                .parsed(defaults.string(forKey: Self.suggestionAggressivenessDefaultsKey))
                .defaultTuningLevel
        }
        if defaults.object(forKey: Self.suggestionTuningDefaultsVersionDefaultsKey) == nil,
           hasStoredLevel,
           level == Self.previousDefaultSuggestionAggressivenessLevel {
            level = SuggestionTuning.defaultAggressivenessLevel
        }

        let storedTuningVersion = defaults.object(forKey: Self.suggestionTuningDefaultsVersionDefaultsKey) as? Int
        let shouldMigrateDailyDriverDefaults = (storedTuningVersion ?? 0) < Self.currentSuggestionTuningDefaultsVersion
        if shouldMigrateDailyDriverDefaults,
           level == 3 {
            level = SuggestionTuning.defaultAggressivenessLevel
        }

        var maxVisibleWords: Int
        if defaults.object(forKey: Self.suggestionMaxVisibleWordsDefaultsKey) != nil {
            maxVisibleWords = defaults.integer(forKey: Self.suggestionMaxVisibleWordsDefaultsKey)
        } else {
            maxVisibleWords = SuggestionTuning.defaultMaxVisibleWords
        }

        let wordStartCharacters = defaults.object(forKey: Self.suggestionWordStartCharactersDefaultsKey) != nil
            ? defaults.integer(forKey: Self.suggestionWordStartCharactersDefaultsKey)
            : SuggestionTuning.defaultWordStartCharacters
        var phraseStartWords = defaults.object(forKey: Self.suggestionPhraseStartWordsDefaultsKey) != nil
            ? defaults.integer(forKey: Self.suggestionPhraseStartWordsDefaultsKey)
            : SuggestionTuning.defaultPhraseStartWords
        var responseSpeedLevel = defaults.object(forKey: Self.suggestionResponseSpeedLevelDefaultsKey) != nil
            ? defaults.integer(forKey: Self.suggestionResponseSpeedLevelDefaultsKey)
            : SuggestionTuning.defaultResponseSpeedLevel
        var confidenceLevel = defaults.object(forKey: Self.suggestionConfidenceLevelDefaultsKey) != nil
            ? defaults.integer(forKey: Self.suggestionConfidenceLevelDefaultsKey)
            : SuggestionTuning.defaultConfidenceLevel
        var learningRestraintLevel = defaults.object(forKey: Self.suggestionLearningRestraintLevelDefaultsKey) != nil
            ? defaults.integer(forKey: Self.suggestionLearningRestraintLevelDefaultsKey)
            : SuggestionTuning.defaultLearningRestraintLevel

        if shouldMigrateDailyDriverDefaults {
            if maxVisibleWords == 3 || maxVisibleWords == 5 {
                maxVisibleWords = SuggestionTuning.defaultMaxVisibleWords
            }
            if phraseStartWords == 3 {
                phraseStartWords = SuggestionTuning.defaultPhraseStartWords
            }
            if responseSpeedLevel == 3 {
                responseSpeedLevel = SuggestionTuning.defaultResponseSpeedLevel
            }
            if confidenceLevel == 3 {
                confidenceLevel = SuggestionTuning.defaultConfidenceLevel
            }
            if learningRestraintLevel == 2 {
                learningRestraintLevel = SuggestionTuning.defaultLearningRestraintLevel
            }
        }

        suggestionTuning = SuggestionTuning(
            aggressivenessLevel: level,
            maxVisibleWords: maxVisibleWords,
            wordStartCharacters: wordStartCharacters,
            phraseStartWords: phraseStartWords,
            responseSpeedLevel: responseSpeedLevel,
            confidenceLevel: confidenceLevel,
            learningRestraintLevel: learningRestraintLevel
        )
        persistSuggestionTuning()
        defaults.set(
            Self.currentSuggestionTuningDefaultsVersion,
            forKey: Self.suggestionTuningDefaultsVersionDefaultsKey
        )
    }

    func persistSuggestionTuning() {
        let defaults = UserDefaults.standard
        defaults.set(
            suggestionTuning.legacyAggressiveness.rawValue,
            forKey: Self.suggestionAggressivenessDefaultsKey
        )
        defaults.set(
            suggestionTuning.aggressivenessLevel,
            forKey: Self.suggestionAggressivenessLevelDefaultsKey
        )
        defaults.set(
            suggestionTuning.maxVisibleWords,
            forKey: Self.suggestionMaxVisibleWordsDefaultsKey
        )
        defaults.set(
            suggestionTuning.wordStartCharacters,
            forKey: Self.suggestionWordStartCharactersDefaultsKey
        )
        defaults.set(
            suggestionTuning.phraseStartWords,
            forKey: Self.suggestionPhraseStartWordsDefaultsKey
        )
        defaults.set(
            suggestionTuning.responseSpeedLevel,
            forKey: Self.suggestionResponseSpeedLevelDefaultsKey
        )
        defaults.set(
            suggestionTuning.confidenceLevel,
            forKey: Self.suggestionConfidenceLevelDefaultsKey
        )
        defaults.set(
            suggestionTuning.learningRestraintLevel,
            forKey: Self.suggestionLearningRestraintLevelDefaultsKey
        )
    }

}

private struct InsertionVerificationBaseline: Equatable {
    let fieldIdentity: FocusedFieldIdentity
    let targetFingerprint: FocusedTargetFingerprint
    let previousTextBeforeCursor: String
    let previousTextAfterCursor: String
    let profile: CompatibilityProfile
    let suggestionID: String?
    let requestMode: CompletionRequestMode?
    let acceptanceID: String
    let acceptedAt: Date
    let action: KeyboardAction?
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
    case targetFingerprintChanged

    var failureOutcome: String? {
        switch self {
        case .ready:
            return nil
        case .missingContext:
            return "missingContext"
        case .fieldChanged:
            return "fieldChanged"
        case .targetFingerprintChanged:
            return "targetFingerprintChanged"
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
        case .targetFingerprintChanged:
            return "insert-verification-target-fingerprint-mismatch"
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
    let acceptMode: String
    let acceptedAt: Date
    let expiresAt: Date
}

private enum AcceptedInsertionUndoRecoveryMode: Equatable {
    case appRollback

    var traceMechanism: InsertionUndoRecoverabilityLevel {
        .appRollback
    }

    static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> AcceptedInsertionUndoRecoveryMode {
        .appRollback
    }
}

private struct FieldControlTarget: Equatable {
    let appBundleIdentifier: String
    let appDisplayName: String
    let fieldIdentity: FocusedFieldIdentity
    let requestMode: CompletionRequestMode?
    let fieldKind: AXFieldKind
}

private extension String {
    func trimmingTrailingWhitespace() -> String {
        var result = self
        while result.last?.isWhitespace == true {
            result.removeLast()
        }
        return result
    }
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
    var blockedReason: CompletionActivationBlockReason? {
        switch self {
        case .allow:
            return nil
        case let .block(reason):
            return reason
        }
    }

    var blockReasonDescription: String {
        switch self {
        case .allow:
            return "allowed"
        case let .block(reason):
            return reason.rawValue
        }
    }
}

// MARK: - SuggestionPipelineHost

extension AppDelegate: SuggestionPipelineHost {
    /// App-computed cadence inputs for the polling driver (relocated from the former
    /// `shouldRunFocusedTextPoll`); the pure cadence policy lives in `SuggestionPipelineController`.
    func focusedTextPollCadenceSignals() -> FocusPollingCadenceSignals {
        let activeApp = accessibilityClient.frontmostApplication()
        let hasSupportedProfile = activeApp.flatMap { app -> Bool? in
            guard let profile = effectiveProfile(for: app) else {
                return false
            }

            return profile.canPresentSuggestions
                && !profile.isSensitive
                && isSuggestionEnabled(for: app, profile: profile)
        } ?? false
        return FocusPollingCadenceSignals(
            isTrustedForAccessibility: accessibilityClient.isTrusted,
            hasSupportedProfile: hasSupportedProfile,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion,
            lastFocusedTextChangeAt: lastFocusedTextChangeAt
        )
    }

    /// Run one focused-text poll (Accessibility read + dispatch). Returns whether the read
    /// completes asynchronously, in which case the controller defers `finishPoll` to the
    /// async completion handler (`completeFocusedTextPoll`).
    func executeFocusedTextPoll(startedAt: UInt64) -> Bool {
        var completesAsync = false
        pollFocusedText(startedAt: startedAt, completesAsync: &completesAsync)
        return completesAsync
    }

    func applyFocusedTextPollingThrottle(_ recommendation: FocusedTextPollingThrottleRecommendation) {
        applyFocusedTextPollingThrottleIfNeeded(recommendation)
    }
}
