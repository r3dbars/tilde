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

struct CodexProofFocusedTargetPolicy {
    static let bundleIdentifier = "com.openai.codex"
    static let marker = "AUTOCOMPLETE_LAB_CODEX_PROOF"

    static func allowsOneWordProofRequestMode(_ requestMode: CompletionRequestMode?) -> Bool {
        requestMode == .wordCompletion || requestMode == .phraseContinuation
    }

    static func allowsPromptProofProfile(_ profile: CompatibilityProfile) -> Bool {
        profile.bundleIdentifier == bundleIdentifier
            && profile.supportsOneWordAcceptance
            && profile.insertionMode == .axValueReplacement
            && (
                (!profile.supportsFullAcceptance && profile.requiresNoSubmitAcceptanceProof)
                    || (profile.supportsFullAcceptance && !profile.requiresNoSubmitAcceptanceProof)
            )
    }

    func matches(
        app: RunningApplicationInfo,
        profile: CompatibilityProfile,
        suggestionBundleIdentifier: String?,
        requestMode: CompletionRequestMode?,
        expectedFieldIdentity: FocusedFieldIdentity,
        snapshot: FocusedTextSnapshot,
        focusedContext: FocusedTextContext,
        focusedFieldIdentity: FocusedFieldIdentity,
        proofModeEnabled: Bool,
        expectedFocusedText: String? = nil,
        shownTargetFingerprint: FocusedTargetFingerprint? = nil
    ) -> Bool {
        guard suggestionBundleIdentifier == Self.bundleIdentifier,
              Self.allowsOneWordProofRequestMode(requestMode),
              profile.bundleIdentifier == Self.bundleIdentifier,
              Self.allowsPromptProofProfile(profile),
              proofModeEnabled,
              app.bundleIdentifier == Self.bundleIdentifier,
              app.processIdentifier == expectedFieldIdentity.processIdentifier,
              snapshot.fieldIdentity == expectedFieldIdentity,
              snapshot.textBeforeCursor.contains(Self.marker),
              snapshot.textAfterCursor.isEmpty,
              focusedContext.role == "AXTextArea",
              focusedContext.selectedTextLength == 0,
              focusedContext.elementRect != nil,
              !focusedContext.isSecure,
              focusedContext.textBeforeCursor.contains(Self.marker),
              focusedContext.textAfterCursor.isEmpty else {
            return false
        }

        let focusedText = focusedContext.textBeforeCursor + focusedContext.textAfterCursor
        let targetText = expectedFocusedText ?? snapshot.textBeforeCursor + snapshot.textAfterCursor
        guard targetText.contains(Self.marker) else {
            return false
        }

        guard focusedText == targetText else {
            return false
        }

        if focusedFieldIdentity == expectedFieldIdentity {
            return true
        }

        guard focusedFieldIdentity.bundleIdentifier == expectedFieldIdentity.bundleIdentifier,
              focusedFieldIdentity.processIdentifier == expectedFieldIdentity.processIdentifier,
              let shownTargetFingerprint else {
            return false
        }

        let focusedTargetFingerprint = FocusedTargetFingerprint(
            role: focusedContext.role,
            subrole: focusedContext.subrole,
            elementFingerprint: focusedContext.fingerprint,
            windowIdentifier: focusedContext.windowIdentifier,
            elementRect: focusedContext.elementRect,
            windowRect: focusedContext.windowRect,
            caretRect: focusedContext.caretRect,
            textBeforeCursor: focusedContext.textBeforeCursor,
            textAfterCursor: focusedContext.textAfterCursor
        )
        return codexProofTargetGeometryMatches(
            shown: shownTargetFingerprint,
            focusedTargetFingerprint
        )
    }

    private func codexProofTargetGeometryMatches(
        shown: FocusedTargetFingerprint,
        _ focused: FocusedTargetFingerprint,
        maxGeometryDelta: Int = 4
    ) -> Bool {
        let expected = shown.postInsertionScope
        let actual = focused.postInsertionScope

        guard expected.role == actual.role,
              expected.subrole == actual.subrole else {
            return false
        }

        if let expectedWindowIdentifier = expected.windowIdentifier,
           let actualWindowIdentifier = actual.windowIdentifier,
           expectedWindowIdentifier != actualWindowIdentifier {
            return false
        }

        if let expectedWindowBounds = expected.windowBounds,
           let actualWindowBounds = actual.windowBounds,
           expectedWindowBounds != actualWindowBounds {
            return false
        }

        guard let expectedBounds = expected.elementBounds,
              let actualBounds = actual.elementBounds else {
            return expected.elementBounds == actual.elementBounds
        }

        return abs(expectedBounds.x - actualBounds.x) <= maxGeometryDelta
            && abs(expectedBounds.y - actualBounds.y) <= maxGeometryDelta
            && abs(expectedBounds.width - actualBounds.width) <= maxGeometryDelta
            && expectedBounds.height > 0
            && actualBounds.height > 0
    }
}

struct PromptProofFieldIdentityRefreshPolicy {
    func canTrustRefresh(
        requestFieldIdentity: FocusedFieldIdentity,
        refreshedFieldIdentity: FocusedFieldIdentity,
        profile: CompatibilityProfile,
        proofModeEnabled: Bool,
        allowsFullAcceptNoSubmitProofProfile: Bool
    ) -> Bool {
        guard profile.promptAppSafetyMode == .wordOnly,
              proofModeEnabled,
              requestFieldIdentity.bundleIdentifier == refreshedFieldIdentity.bundleIdentifier,
              requestFieldIdentity.processIdentifier == refreshedFieldIdentity.processIdentifier else {
            return false
        }

        return profile.requiresNoSubmitAcceptanceProof
            || allowsFullAcceptNoSubmitProofProfile
    }
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

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private struct ProofOnlyAcceptRecentSuggestion {
        let suggestion: CompletionSuggestion
        let suggestionID: String
        let appBundleIdentifier: String
        let fieldIdentity: FocusedFieldIdentity
        let requestMode: CompletionRequestMode
        let textBeforeCursor: String
        let acceptanceSnapshot: SuggestionAcceptanceSnapshot
        let displayedText: String
        let fieldClassification: AXFieldClassification?
        let presentedAt: Date
        let displayScoreFinal: Double?
        let caretRect: CGRect?
        let textLineRect: CGRect?
        let clippingRect: CGRect?
        let textStyle: FocusedTextStyle?
        let renderMode: SuggestionRenderMode?
        let geometrySnapshot: SuggestionGeometrySnapshot?
    }

    private let accessibilityClient = AccessibilityClient()
    private lazy var accessibilityPermissionHost = AccessibilityPermissionHost(client: accessibilityClient)
    private let startupOnboardingPolicy = StartupOnboardingPolicy()
    private let appSettings = AppSettings()
    private let profileStore = CompatibilityProfileStore.mvp
    private let promptEditorPolicy = PromptEditorFingerprintPolicy()
    private let codexProofFocusedTargetPolicy = CodexProofFocusedTargetPolicy()
    private let codexPromptTargetContinuityHost = CodexPromptTargetContinuityHost()
    private let promptProofFieldIdentityRefreshPolicy = PromptProofFieldIdentityRefreshPolicy()
    private let browserHostedSurfacePolicy = BrowserHostedSurfacePolicy()
    private let suggestionSilenceExplanationPolicy = SuggestionSilenceExplanationPolicy()
    private let personalCapturePolicy = PersonalCapturePolicy()
    private let personalCaptureJournal = PersonalCaptureJournalWriter.shared
    private let personalCaptureEpisodes = PersonalCaptureEpisodeStore.shared
    private let personalizationCoordinator = PersonalizationCoordinator()
    private let suggestionControlPolicy = SuggestionControlPolicy()
    private let suggestionPauseSchedulePolicy = SuggestionPauseSchedulePolicy()
    private let suggestionTriggerTimingPolicy = SuggestionTriggerTimingPolicy()
    private let suggestionAggressivenessPolicy = SuggestionAggressivenessPolicy()
    private let visiblePageContextProvider = VisiblePageContextProvider()
    private let fieldClassifier = AXFieldClassifier()
    private let textContextRepairPolicy = TextContextRepairPolicy()
    private let obsidianTrustedEndOfDocumentSnapshotPolicy = ObsidianTrustedEndOfDocumentSnapshotPolicy()
    private let proofActivationModePolicy = ProofActivationModePolicy()
    private let tracePrivacySecretStore = TracePrivacySecretStore()
    private let suggestionCadenceResetPolicy = SuggestionCadenceResetPolicy()
    private var modelRuntimeBundle = AppModelRuntimeFactory.makeRuntime()
    private let modelRuntimeWarmHost = ModelRuntimeWarmHost()
    private lazy var runtimeStatusHost = RuntimeStatusHost(handler: self)
    private lazy var modelInstallLifecycleHost = ModelInstallLifecycleHost(handler: self)
    private let runtimeProofOptions = RuntimeProofOptions.fromProcessEnvironment()
    private lazy var appEnablementHost = AppEnablementHost(profileStore: profileStore)
    private lazy var appTargetStateHost = AppTargetStateHost(profileStore: profileStore)
    private lazy var suggestionPauseStateHost = SuggestionPauseStateHost(
        controlPolicy: suggestionControlPolicy,
        schedulePolicy: suggestionPauseSchedulePolicy,
        onTimedPauseEnded: { [weak self] in
            self?.setSuggestionDecision("Ready: timed pause ended")
            self?.refreshRuntimeChrome()
        }
    )
    private var completionLengthConfiguration: CompletionLengthConfiguration {
        modelRuntimeBundle.lengthConfiguration
    }
    private var modelRuntime: any ModelRuntime {
        modelRuntimeBundle.runtime
    }
    private lazy var engine: any CompletionEngine = RuntimeBackedCompletionEngine(runtime: modelRuntime)
    private lazy var insertionEngine = InsertionEngine(accessibilityClient: accessibilityClient)
    private let keyboardCaptureSafetyPolicy = KeyboardCaptureSafetyPolicy()
    private let insertionVerification = InsertionVerification()
    private let insertionVerificationContextRecoveryPolicy = InsertionVerificationContextRecoveryPolicy()
    private let suggestionAcceptanceProofPolicy = SuggestionAcceptanceProofPolicy()
    private let suggestionAcceptanceGuard = SuggestionAcceptanceGuard()
    private let acceptanceSafetyPolicy = AcceptanceSafetyPolicy()
    private let acceptedTextSafetyPolicy = AcceptedTextSafetyPolicy()
    private let proofOnlyAcceptRecentSuggestionPolicy = ProofOnlyAcceptRecentSuggestionPolicy()
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
        suggestionAnnoyanceBackoffPolicy: makeSuggestionAnnoyanceBackoffPolicy()
    )
    private let typeThroughPrefixStateMachine = TypeThroughPrefixStateMachine()
    private let suggestionTypingProgressPolicy = SuggestionTypingProgressPolicy()
    private var displayScorePolicy: DisplayScorePolicy {
        suggestionTuning.displayScorePolicy
    }
    private lazy var appProofModeCoordinator = AppProofModeCoordinator(runtimeProofOptions: runtimeProofOptions)
    private var activeAppProofBundleIdentifiers: Set<String> {
        appProofModeCoordinator.activeBundleIdentifiers
    }
    private let annoyanceSuppressor = AnnoyanceSuppressorActor()
    private let traceScreenshotCaptureCoordinator = TraceScreenshotCaptureCoordinator()
    private let focusedTextAXHealthPolicy = FocusedTextAXHealthPolicy.typingResponsiveness
    private let focusedTextAXHealthSuggestionVisibilityPolicy = FocusedTextAXHealthSuggestionVisibilityPolicy()
    private let focusedTextPollingThrottleSuggestionVisibilityPolicy =
        FocusedTextPollingThrottleSuggestionVisibilityPolicy()
    private let recentWordExtractor = RecentWordExtractor()
    private let compatibilityLearningStore = CompatibilityLearningStore.shared
    private lazy var suggestionChromeHost = SuggestionChromeHost()
    private lazy var focusedTextReader = SerialFocusedTextAXReader(accessibilityClient: accessibilityClient)
    /// First extracted slice of the suggestion pipeline: owns the focused-text polling driver
    /// (timer, cadence, in-flight guard, throttle/pause, latency/skip stats). AppDelegate holds
    /// it and delegates timing concerns to it via `SuggestionPipelineHost` (see extension below).
    private lazy var suggestionPipeline = SuggestionPipelineController(host: self)
    private lazy var diagnosticsWindowHost = DiagnosticsWindowHost(handler: self)
    private let appProofCommandCoordinator = AppProofCommandCoordinator()
    private lazy var appPreferencePersistenceHost = AppPreferencePersistenceHost()
    private lazy var keyboardEventCaptureHost = KeyboardEventCaptureHost(
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
        passthroughTypingMatchObserver: { [weak self] transition in
            self?.observeOptimisticTypeThrough(transition)
        },
        disabledObserver: { [weak self] reason in
            self?.handleKeyboardEventTapDisabled(reason: reason)
        },
        idleStateProvider: { [weak self] in
            KeyboardEventCaptureIdleState(
                hasVisibleSuggestion: self?.suggestionSession.hasVisibleSuggestion == true,
                isSuggestionPanelVisible: self?.suggestionChromeHost.isSuggestionPanelVisible == true,
                hasPendingAcceptedInsertionUndo: self?.acceptedInsertionUndoIsActive() == true
            )
        }
    )
    private var keyboardEventTap: KeyboardEventCaptureHost? {
        keyboardEventCaptureHost
    }
    private lazy var settingsWindowHost = SettingsWindowHost(handler: self)
    private var settingsWindow: SettingsWindowController {
        settingsWindowHost.controller
    }
    private lazy var statusMenuHost = StatusMenuHost(
        handler: self,
        developerMenuEnabled: developerMenuEnabled
    )
    private lazy var workspaceObserverHost = WorkspaceObserverHost(handler: self)
    private let resourceDiagnosticsHost = ResourceDiagnosticsHost()
    private lazy var appLifecycleHost = AppLifecycleHost(handler: self)

    private var proofOnlyAcceptCommandObserver: NSObjectProtocol?
    private lazy var suggestionSummonHotKeyHost = SuggestionSummonHotKeyHost { [weak self] in
        self?.requestSuggestionNow(source: "hotkey")
    }
    private let prefixCooldownRetryHost = PrefixCooldownRetryHost()
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
    private var personalCaptureLastSnapshot: FocusedTextSnapshot?
    private var lastFocusedTextChangeAt: Date?
    private var lastRequestedTextBeforeCursor: String?
    private let manualSuggestionRequestHost = ManualSuggestionRequestHost()
    private var suppressedFieldIdentities: Set<FocusedFieldIdentity> = []
    private var disabledBundleIdentifiers: Set<String> {
        get { appEnablementHost.disabledBundleIdentifiers }
        set { appEnablementHost.disabledBundleIdentifiers = newValue }
    }
    private let suggestionRequestScheduler = SuggestionRequestScheduler()
    private let codexPromptPresentationRetryHost = CodexPromptPresentationRetryHost()
    private lazy var insertionVerificationHost = InsertionVerificationHost(handler: self)
    private var deferredTerminalHostAcceptanceTask: Task<Void, Never>?
    private let acceptanceSurvivalChecker = AcceptanceSurvivalChecker()
    private let acceptanceSurvivalTaskHost = AcceptanceSurvivalTaskHost()
    private let focusedFieldIdentityPolicy = FocusedFieldIdentityPolicy()
    private let insertionVerificationPreflightPolicy = InsertionVerificationPreflightPolicy()
    private let insertionFailureSuppressionPolicy = InsertionFailureSuppressionPolicy()
    private var focusedTextAXHealthState = FocusedTextAXHealthState()
    private var suggestionBlockLogGate = SuggestionBlockLogGate()
    private let typingBurstPolicy = TypingBurstPolicy()
    private var typingBurstState = TypingBurstState()
    private var suggestionIdleRetryState = SuggestionIdleRetryState()
    private var currentSuggestionState = CurrentSuggestionState()
    private var typeThroughConfidenceCreditedSuggestionIDs: Set<String> = []
    private var proofOnlyAcceptRecentSuggestion: ProofOnlyAcceptRecentSuggestion?
    private var preservesResidualSuggestionAfterNextWordAccept = false
    private var obsidianPostAcceptanceSuppression: ObsidianPostAcceptanceSuppression?
    private var recentWordMemory = ScopedRecentWordMemory()
    private var suppressKeyUntil: [AutocompleteKey: Date] = [:]
    private var pendingAcceptedInsertionUndo: AcceptedInsertionUndo?
    private var acceptedInsertionUndoExpirationTask: Task<Void, Never>?
    private let acceptedInsertionUndoRecoveryMode = AcceptedInsertionUndoRecoveryMode.fromEnvironment()
    private var lastStatusLine: String?
    private var lastSuggestionDecision = "Starting"
    private var lastSyntheticCaretDiagnosticSignature: String?
    private var lastClaudeCodeTerminalProofInputSignature: String?
    private var claudeCodeTerminalScreenPromptAnchorCache = ClaudeCodeTerminalScreenPromptAnchorCache()
    private var lastTextContextRepairDiagnosticSignature: String?
    private let postTypingPollPauseMilliseconds = 220
    private let visibleSuggestionTypingPollPauseMilliseconds = 60
    private let postInsertionPollPauseMilliseconds = 220
    private let maximumPreservedSuggestionGeometryAgeDuringAXPauseMilliseconds = 750
    private let maximumPreservedSuggestionDisplaySuppressionAgeMilliseconds = 5_000
    private var suggestionsPaused: Bool {
        suggestionPauseStateHost.isPaused
    }
    private var suggestionsPausedUntil: Date? {
        suggestionPauseStateHost.pausedUntil
    }
    private var appEnablementSetupCompleted: Bool {
        get { appEnablementHost.setupCompleted }
        set { appEnablementHost.setupCompleted = newValue }
    }
    private var keyboardShortcutConfiguration: KeyboardShortcutConfiguration {
        get { appPreferencePersistenceHost.keyboardShortcutConfiguration }
        set { appPreferencePersistenceHost.keyboardShortcutConfiguration = newValue }
    }
    private var suggestionTuning: SuggestionTuning {
        get { appPreferencePersistenceHost.suggestionTuning }
        set { appPreferencePersistenceHost.suggestionTuning = newValue }
    }
    private var visiblePageContextEnabled: Bool {
        get { appPreferencePersistenceHost.visiblePageContextEnabled }
        set { appPreferencePersistenceHost.visiblePageContextEnabled = newValue }
    }
    private var acceptedAndKeptLearning: AcceptedAndKeptLearningStore {
        get { appPreferencePersistenceHost.acceptedAndKeptLearning }
        set { appPreferencePersistenceHost.acceptedAndKeptLearning = newValue }
    }
    private var acceptedTextStyleMemory: AcceptedTextStyleMemoryStore {
        get { appPreferencePersistenceHost.acceptedTextStyleMemory }
        set { appPreferencePersistenceHost.acceptedTextStyleMemory = newValue }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        appLifecycleHost.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appLifecycleHost.stop()
    }

    private func prepareForAppLaunch() {
        suggestionPauseStateHost.load()
        loadDisabledApps()
        appPreferencePersistenceHost.load()
        personalizationCoordinator.refreshIndexing(isEnabled: appSettings.personalCaptureEnabled)
        loadProofModeOverrides()
    }

    private func recordAppLaunchDiagnostics() {
        DiagnosticsLog.shared.record("launch", metadata: launchDiagnosticsMetadata())
        DiagnosticsLog.shared.record("runtime-bootstrap", metadata: modelRuntimeBundle.diagnosticsMetadata)
    }

    private func requestAccessibilityPermissionIfNeededAtLaunch() {
        if startupOnboardingPolicy.shouldRequestAccessibilityPromptOnLaunch(
            isTrusted: accessibilityPermissionHost.isTrusted
        ) {
            accessibilityPermissionHost.requestPermissionIfNeeded()
        }
    }

    private func showSettingsIfNeededAtLaunch() {
        if shouldShowSettingsForCurrentReadiness {
            showSettings()
        }
    }

    private func stopForAppTermination() {
        DiagnosticsLog.shared.record("terminate")
        cancelPendingSuggestionTask(reason: "terminate")
        suggestionPauseStateHost.stop()
        keyboardEventCaptureHost.cancelIdleStop()
        insertionVerificationHost.cancel()
        deferredTerminalHostAcceptanceTask?.cancel()
        acceptedInsertionUndoExpirationTask?.cancel()
        modelRuntimeWarmHost.cancel()
        invalidatePendingSuggestionRequest()
        modelRuntime.cancel()
        suggestionPipeline.stopPolling()
        resourceDiagnosticsHost.stop()
        personalizationCoordinator.stop()
        suggestionSummonHotKeyHost.stop()
        manualSuggestionRequestHost.cancelRetry()
        workspaceObserverHost.stop()
        stopProofOnlyAcceptCommandObserver()
        stopKeyboardEventTapNow(reason: "terminate")
        suggestionChromeHost.hideFieldStatusIndicator()
    }

    func startProofOnlyAcceptCommandObserver() {
        guard ProofOnlyAcceptCommand.isEnabled(),
              proofOnlyAcceptCommandObserver == nil else {
            return
        }

        proofOnlyAcceptCommandObserver = DistributedNotificationCenter.default().addObserver(
            forName: ProofOnlyAcceptCommand.notificationName,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleProofOnlyAcceptNextWordCommand()
            }
        }
        DiagnosticsLog.shared.record(
            "proof-only-accept-command-listener-started",
            metadata: [
                "enabled": "true"
            ]
        )
    }

    private func stopProofOnlyAcceptCommandObserver() {
        guard let observer = proofOnlyAcceptCommandObserver else {
            return
        }

        DistributedNotificationCenter.default().removeObserver(observer)
        proofOnlyAcceptCommandObserver = nil
    }

    @discardableResult
    private func restoreProofOnlyAcceptRecentSuggestionIfNeeded() -> Bool {
        guard !suggestionSession.hasVisibleSuggestion else {
            return false
        }

        guard let recentSuggestion = proofOnlyAcceptRecentSuggestion else {
            return false
        }

        let ageMilliseconds = max(
            0,
            Int(Date().timeIntervalSince(recentSuggestion.presentedAt) * 1000)
        )
        let lastSnapshotMatchesShownText = proofOnlyAcceptRecentSuggestionStillMatchesShownText(
            recentSuggestion
        )
        let decision = proofOnlyAcceptRecentSuggestionPolicy.decision(
            for: ProofOnlyAcceptRecentSuggestionPolicy.RestoreInput(
                proofModeEnabled: activeAppProofBundleIdentifiers.contains(
                    ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier
                ),
                hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion,
                suggestionBundleIdentifier: recentSuggestion.appBundleIdentifier,
                currentProfileBundleIdentifier: currentProfile?.bundleIdentifier,
                fieldClassification: recentSuggestion.fieldClassification,
                ageMilliseconds: ageMilliseconds,
                invalidatedByUserKeyDown: currentSuggestionState.invalidatedByUserKeyDown,
                suggestionText: recentSuggestion.suggestion.text,
                lastSnapshotMatchesShownText: lastSnapshotMatchesShownText
            )
        )

        switch decision {
        case .allow:
            break
        case let .block(reason):
            DiagnosticsLog.shared.record(
                "proof-only-accept-command-restore-skipped",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "reason": reason.rawValue,
                    "ageMilliseconds": String(ageMilliseconds),
                    "lastSnapshotMatchesShownText": String(lastSnapshotMatchesShownText),
                    "currentProfile": currentProfile?.bundleIdentifier ?? "unknown"
                ]
            )
            return false
        }

        suggestionSession.present(recentSuggestion.suggestion)
        currentSuggestionState.id = recentSuggestion.suggestionID
        currentSuggestionState.appBundleIdentifier = recentSuggestion.appBundleIdentifier
        currentSuggestionState.fieldIdentity = recentSuggestion.fieldIdentity
        currentSuggestionState.requestMode = recentSuggestion.requestMode
        currentSuggestionState.textBeforeCursor = recentSuggestion.textBeforeCursor
        currentSuggestionState.acceptanceSnapshot = recentSuggestion.acceptanceSnapshot
        currentSuggestionState.displayedText = recentSuggestion.displayedText
        currentSuggestionState.fieldClassification = recentSuggestion.fieldClassification
        currentSuggestionState.presentedAt = recentSuggestion.presentedAt
        currentSuggestionState.displayScoreFinal = recentSuggestion.displayScoreFinal
        currentSuggestionState.invalidatedByUserKeyDown = false
        lastCaretRect = recentSuggestion.caretRect
        lastTextLineRect = recentSuggestion.textLineRect
        lastClippingRect = recentSuggestion.clippingRect
        lastTextStyle = recentSuggestion.textStyle
        lastRenderMode = recentSuggestion.renderMode
        lastVisibleSuggestionGeometrySnapshot = recentSuggestion.geometrySnapshot
        keyboardEventCaptureHost.cancelIdleStop()
        updateKeyboardEventTapSnapshot()

        DiagnosticsLog.shared.record(
            "proof-only-accept-command-restored-visible-suggestion",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "ageMilliseconds": String(ageMilliseconds),
                "requestMode": recentSuggestion.requestMode.rawValue,
                "visibleChars": String(recentSuggestion.displayedText.count)
            ]
        )
        return true
    }

    private func proofOnlyAcceptRecentSuggestionStillMatchesShownText(
        _ recentSuggestion: ProofOnlyAcceptRecentSuggestion
    ) -> Bool {
        guard let lastTextSnapshot else {
            return false
        }

        return lastTextSnapshot.fieldIdentity == recentSuggestion.acceptanceSnapshot.fieldIdentity
            && lastTextSnapshot.textBeforeCursor == recentSuggestion.acceptanceSnapshot.textBeforeCursor
            && lastTextSnapshot.textAfterCursor == recentSuggestion.acceptanceSnapshot.textAfterCursor
    }

    private func cacheProofOnlyAcceptRecentSuggestionIfNeeded(
        suggestion: CompletionSuggestion,
        suggestionID: String,
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity,
        requestMode: CompletionRequestMode,
        textBeforeCursor: String,
        acceptanceSnapshot: SuggestionAcceptanceSnapshot,
        displayedText: String,
        fieldClassification: AXFieldClassification?,
        presentedAt: Date,
        displayScoreFinal: Double?
    ) {
        guard appBundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier else {
            proofOnlyAcceptRecentSuggestion = nil
            return
        }

        proofOnlyAcceptRecentSuggestion = ProofOnlyAcceptRecentSuggestion(
            suggestion: suggestion,
            suggestionID: suggestionID,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentity,
            requestMode: requestMode,
            textBeforeCursor: textBeforeCursor,
            acceptanceSnapshot: acceptanceSnapshot,
            displayedText: displayedText,
            fieldClassification: fieldClassification,
            presentedAt: presentedAt,
            displayScoreFinal: displayScoreFinal,
            caretRect: lastCaretRect,
            textLineRect: lastTextLineRect,
            clippingRect: lastClippingRect,
            textStyle: lastTextStyle,
            renderMode: lastRenderMode,
            geometrySnapshot: lastVisibleSuggestionGeometrySnapshot
        )
    }

    private func handleProofOnlyAcceptNextWordCommand() {
        guard ProofOnlyAcceptCommand.isEnabled() else {
            DiagnosticsLog.shared.record(
                "proof-only-accept-command-refused",
                metadata: [
                    "reason": "disabled"
                ]
            )
            return
        }

        let restoredRecentSuggestion = restoreProofOnlyAcceptRecentSuggestionIfNeeded()
        let proofModeEnabled = activeAppProofBundleIdentifiers.contains(
            ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier
        )
        guard proofModeEnabled,
              currentSuggestionState.appBundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
              currentProfile?.bundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
              suggestionSession.hasVisibleSuggestion else {
            DiagnosticsLog.shared.record(
                "proof-only-accept-command-refused",
                metadata: [
                    "reason": "precondition-failed",
                    "app": currentSuggestionState.appBundleIdentifier ?? currentProfile?.bundleIdentifier ?? "unknown",
                    "hasVisibleSuggestion": String(suggestionSession.hasVisibleSuggestion),
                    "proofModeEnabled": String(proofModeEnabled),
                    "restoredRecentSuggestion": String(restoredRecentSuggestion),
                    "recentSuggestionAvailable": String(proofOnlyAcceptRecentSuggestion != nil)
                ]
            )
            return
        }

        DiagnosticsLog.shared.record(
            "proof-only-accept-command-received",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "action": KeyboardAction.acceptNextWord.diagnosticName,
                "hasVisibleSuggestion": String(suggestionSession.hasVisibleSuggestion),
                "requestMode": currentSuggestionState.requestMode?.rawValue ?? "unknown"
            ]
        )
        let result = handleAutocompleteKey(.tab)
        let handled: Bool
        let resultName: String
        switch result {
        case .handled:
            handled = true
            resultName = "handled"
        case let .replayOriginalKey(reason):
            handled = false
            resultName = "replay-\(reason.rawValue)"
        case let .dropOriginalKey(reason):
            handled = false
            resultName = "drop-\(reason.rawValue)"
        }
        DiagnosticsLog.shared.record(
            "proof-only-accept-command-result",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "handled": String(handled),
                "result": resultName
            ]
        )
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
        suggestionChromeHost.hideFieldStatusIndicator()
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
            suggestionChromeHost.hideFieldStatusIndicator()
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
            || suggestionChromeHost.isFieldStatusIndicatorVisible else {
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

    func startSuggestionSummonHotKey() {
        let didStart = suggestionSummonHotKeyHost.start()
        DiagnosticsLog.shared.record(
            didStart ? "suggestion-summon-hotkey-started" : "suggestion-summon-hotkey-start-failed",
            metadata: [
                "shortcut": suggestionSummonHotKeyHost.descriptor.diagnosticName,
                "safetyFailure": String(!didStart)
            ]
        )
    }

    func warmModelRuntime() {
        let candidate = modelRuntimeBundle.activeCandidate
        modelRuntimeWarmHost.start(
            runtime: modelRuntime,
            candidate: candidate,
            canWarm: modelRuntimeBundle.bootstrapPlan.canWarmPreferredRuntime,
            unavailableReason: modelRuntimeBundle.bootstrapPlan.unavailableReason,
            modelDirectoryPath: modelRuntimeBundle.modelDirectoryURL.path,
            applyState: { [weak self] state in
                self?.runtimeStatusHost.apply(state)
            }
        )
    }

    func refreshModelAssetState(for state: LocalRuntimeState) -> LocalRuntimeState {
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
        codexPromptTargetContinuityHost.reset()
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
        if settingsWindow.isShowing {
            settingsWindow.refresh(
                isTrusted: accessibilityClient.isTrusted,
                suggestionsPaused: suggestionsPaused,
                suggestionsPausedUntil: suggestionsPausedUntil,
                runtimeReport: runtimeReadinessReport,
                runtimeTargetSummary: runtimeTargetSummary,
                modelDirectoryPath: modelDirectoryPath,
                modelInstallStatusText: runtimeStatusHost.modelInstallStatus,
                isModelInstallInProgress: modelInstallLifecycleHost.isInstalling,
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
        runtimeStatusHost.runtimeReadinessReport
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
            isModelInstallInProgress: modelInstallLifecycleHost.isInstalling,
            isTextEditEnabled: !disabledBundleIdentifiers.contains(Self.textEditPracticeBundleIdentifier)
        )
    }

    private var fieldControlTarget: FieldControlTarget? {
        appTargetStateHost.fieldControlTarget(currentFieldIdentity: currentFieldIdentity)
    }

    private var appForSettingsState: RunningApplicationInfo? {
        appTargetStateHost.appForSettingsState(
            frontmostApplication: accessibilityClient.frontmostApplication()
        )
    }

    private func targetAppForControls() -> RunningApplicationInfo? {
        appTargetStateHost.targetAppForControls(
            frontmostApplication: accessibilityClient.frontmostApplication()
        )
    }

    private var settingsPrivacyState: SettingsPrivacyState {
        SettingsPrivacyState(
            tracingPaused: RawAutocompleteTraceLog.shared.isPaused,
            rawContentTracingEnabled: RawAutocompleteTraceLog.shared.rawContentTracingEnabled,
            rawContentTracingExpiresAt: RawAutocompleteTraceLog.shared.rawContentTracingExpiresAt,
            screenshotTracingEnabled: RawAutocompleteTraceLog.shared.screenshotTracingEnabled,
            screenshotTracingExpiresAt: RawAutocompleteTraceLog.shared.screenshotTracingExpiresAt,
            visiblePageContextEnabled: visiblePageContextEnabled,
            personalCaptureEnabled: appSettings.personalCaptureEnabled,
            screenCaptureAccessGranted: CGPreflightScreenCaptureAccess(),
            diagnosticsPath: DiagnosticsLog.shared.path,
            tracePath: RawAutocompleteTraceLog.shared.path,
            personalCapturePath: personalCaptureJournal.folderPath
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
        "\(modelRuntimeBundle.bootstrapPlan.preferredAsset.model.rawValue) • \(completionLengthConfiguration.displaySummary) • \(suggestionTuning.displayName.lowercased()) • showing up to \(suggestionTuning.maxVisibleWords) • page context \(visiblePageContextEnabled ? "on" : "off")"
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
        suggestionPauseStateHost.expireTimedPauseIfNeeded(now: Date())
        return ControlPauseState(
            isPaused: suggestionsPaused,
            pausedUntil: suggestionsPausedUntil
        )
    }

    private var suggestionControlState: SuggestionControlState {
        suggestionPauseStateHost.controlState
    }

    private func effectiveProfile(for app: RunningApplicationInfo) -> CompatibilityProfile? {
        if let terminalProofProfile = claudeCodeTerminalHostProofProfile(for: app) {
            return terminalProofProfile
        }

        guard let profile = profileStore.profile(for: app.bundleIdentifier) else {
            return nil
        }

        if shouldUseCodexFullAcceptNoSubmitProofProfile(
            appBundleIdentifier: app.bundleIdentifier,
            profile: profile
        ) {
            return profile.replacingAcceptanceProofMode(
                supportsFullAcceptance: true,
                requiresNoSubmitAcceptanceProof: false,
                notes: "\(profile.notes) Proof-only Codex full-accept no-submit scenario is active."
            )
        }

        return profile
    }

    private func shouldUseCodexFullAcceptNoSubmitProofProfile(
        appBundleIdentifier: String,
        profile: CompatibilityProfile
    ) -> Bool {
        appBundleIdentifier == CodexProofFocusedTargetPolicy.bundleIdentifier
            && profile.bundleIdentifier == CodexProofFocusedTargetPolicy.bundleIdentifier
            && runtimeProofOptions.allowsCodexPromptFullAcceptNoSubmitProof
            && activeAppProofBundleIdentifiers.contains(CodexProofFocusedTargetPolicy.bundleIdentifier)
    }

    private func isCodexFullAcceptNoSubmitProofProfile(_ profile: CompatibilityProfile) -> Bool {
        profile.bundleIdentifier == CodexProofFocusedTargetPolicy.bundleIdentifier
            && profile.supportsFullAcceptance
            && !profile.requiresNoSubmitAcceptanceProof
    }

    private func allowsCodexProofInsertion(profile: CompatibilityProfile) -> Bool {
        CodexProofFocusedTargetPolicy.allowsPromptProofProfile(profile)
            && activeAppProofBundleIdentifiers.contains(CodexProofFocusedTargetPolicy.bundleIdentifier)
            && (
                profile.requiresNoSubmitAcceptanceProof
                    || isCodexFullAcceptNoSubmitProofProfile(profile)
            )
    }

    private func isSuggestionEnabled(
        for app: RunningApplicationInfo,
        profile: CompatibilityProfile
    ) -> Bool {
        guard appProofModeCoordinator.allows(
            appBundleIdentifier: app.bundleIdentifier,
            suggestionBundleIdentifier: profile.bundleIdentifier
        ) else {
            return false
        }

        if isClaudeCodeTerminalHostProof(profile: profile, hostBundleIdentifier: app.bundleIdentifier) {
            return !disabledBundleIdentifiers.contains(app.bundleIdentifier)
        }

        return ProofModeAppEnablementPolicy(
            disabledBundleIdentifiers: disabledBundleIdentifiers,
            activeProofBundleIdentifiers: activeAppProofBundleIdentifiers
        ).isEnabled(
            appBundleIdentifier: app.bundleIdentifier,
            suggestionBundleIdentifier: profile.bundleIdentifier
        )
    }

    private func claudeCodeTerminalHostProofProfile(for app: RunningApplicationInfo) -> CompatibilityProfile? {
        guard ClaudeCodeTerminalHostProofPolicy.supportedTerminalHosts.contains(app.bundleIdentifier) else {
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

    private func pollFocusedText(startedAt: UInt64, completesAsync: inout Bool) {
        if case let .blocked(reason) = suggestionControlPolicy.suggestionAvailability(for: suggestionControlState) {
            if appSettings.personalCaptureEnabled,
               pollPersonalCaptureOnly(startedAt: startedAt, completesAsync: &completesAsync, reason: reason.hideReason) {
                setSuggestionDecision("Capture: suggestions paused")
                return
            }
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
            suggestionChromeHost.hideFieldStatusIndicator()
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
            if appSettings.personalCaptureEnabled,
               pollPersonalCaptureOnly(startedAt: startedAt, completesAsync: &completesAsync, reason: "unsupported-app") {
                setSuggestionDecision("Capture: unsupported app")
                return
            }
            clearFocusedFieldState()
            currentProfile = nil
            setSuggestionDecision("Blocked: unsupported app")
            updateStatusMenu(app: activeApp, profile: nil, appEnabled: false)
            hideSuggestion()
            suggestionChromeHost.hideFieldStatusIndicator()
            return
        }

        appTargetStateHost.rememberEligibleTargetApp(frontmostApp)
        let appEnabled = isSuggestionEnabled(for: frontmostApp, profile: profile)
        currentProfile = profile
        updateStatusMenu(app: frontmostApp, profile: profile, appEnabled: appEnabled)

        guard appEnabled else {
            if appSettings.personalCaptureEnabled,
               pollPersonalCaptureOnly(
                   for: frontmostApp,
                   profile: profile,
                   startedAt: startedAt,
                   completesAsync: &completesAsync,
                   reason: "app-disabled"
               ) {
                clearFocusedFieldState(hideReason: "app-disabled")
                stopKeyboardEventTapNow(reason: "app-disabled")
                setSuggestionDecision("Capture: app disabled for suggestions")
                return
            }
            clearFocusedFieldState(hideReason: "app-disabled")
            stopKeyboardEventTapNow(reason: "app-disabled")
            setSuggestionDecision("Blocked: app disabled")
            return
        }

        guard profile.canPresentSuggestions, !profile.isSensitive else {
            if appSettings.personalCaptureEnabled,
               !profile.isSensitive,
               pollPersonalCaptureOnly(
                   for: frontmostApp,
                   profile: profile,
                   startedAt: startedAt,
                   completesAsync: &completesAsync,
                   reason: "profile-diagnostics-only"
               ) {
                clearFocusedFieldState(hideReason: "profile-diagnostics-only")
                stopKeyboardEventTapNow(reason: "profile-diagnostics-only")
                setSuggestionDecision("Capture: diagnostics-only app")
                return
            }
            clearFocusedFieldState(hideReason: profile.isSensitive ? "sensitive-app" : "profile-disabled")
            stopKeyboardEventTapNow(reason: profile.isSensitive ? "sensitive-app" : "profile-disabled")
            setSuggestionDecision(profile.isSensitive ? "Blocked: sensitive app" : "Blocked: profile disabled")
            return
        }

        guard allowFocusedTextAXRead(for: frontmostApp) else {
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
        let pollStartedWithManualSuggestionRequest = manualSuggestionRequestHost.isPending
        var latencySummarySuppressionReason: String?
        defer {
            if pollStartedWithManualSuggestionRequest && manualSuggestionRequestHost.isPending {
                manualSuggestionRequestHost.clearPendingRequest()
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
            suggestionChromeHost.hideFieldStatusIndicator()
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

    @discardableResult
    private func pollPersonalCaptureOnly(
        startedAt: UInt64,
        completesAsync: inout Bool,
        reason: String
    ) -> Bool {
        guard let app = accessibilityClient.frontmostApplication() else {
            return false
        }

        return pollPersonalCaptureOnly(
            for: app,
            profile: effectiveProfile(for: app),
            startedAt: startedAt,
            completesAsync: &completesAsync,
            reason: reason
        )
    }

    @discardableResult
    private func pollPersonalCaptureOnly(
        for app: RunningApplicationInfo,
        profile: CompatibilityProfile?,
        startedAt: UInt64,
        completesAsync: inout Bool,
        reason: String
    ) -> Bool {
        guard personalCapturePolicy.allowsAppRead(
                  personalCaptureEnabled: appSettings.personalCaptureEnabled,
                  supportStatus: profileStore.supportStatus(for: app.bundleIdentifier)
              ),
              accessibilityClient.isTrusted,
              allowFocusedTextAXRead(for: app) else {
            return false
        }

        let requestID = focusedTextReader.readFocusedTextContext(
            for: app,
            allowDescendantTextFallback: profile?.allowsDescendantTextFallback ?? false,
            options: profile.map { FocusedTextReadOptionsPolicy.options(for: app, profile: $0) } ?? .standard
        ) { [weak self, startedAt, reason] result in
            Task { @MainActor [weak self, startedAt, reason] in
                await self?.completePersonalCaptureOnlyPoll(
                    result: result,
                    startedAt: startedAt,
                    reason: reason
                )
            }
        }
        suggestionPipeline.noteReadStarted(requestID: requestID)
        completesAsync = true
        return true
    }

    private func completePersonalCaptureOnlyPoll(
        result: FocusedTextAXReadResult,
        startedAt: UInt64,
        reason: String
    ) async {
        var latencySummarySuppressionReason: String?
        defer {
            suggestionPipeline.finishPoll(
                startedAt: startedAt,
                latencySummarySuppressionReason: latencySummarySuppressionReason
            )
        }

        guard suggestionPipeline.isCurrentRead(result.requestID) else {
            latencySummarySuppressionReason = "stale-request"
            return
        }

        if applyFocusedTextAXHealthObservation(result) {
            latencySummarySuppressionReason = "ax-health-cooldown-started"
            return
        }

        guard let activeApp = accessibilityClient.frontmostApplication(),
              activeApp.bundleIdentifier == result.app.bundleIdentifier,
              activeApp.processIdentifier == result.app.processIdentifier else {
            personalCaptureLastSnapshot = nil
            return
        }

        guard let context = result.context, !context.isSecure else {
            personalCaptureLastSnapshot = nil
            return
        }

        let fieldClassification = fieldClassification(for: context)
        let fieldIdentity = focusedFieldIdentityPolicy.identity(
            bundleIdentifier: result.app.bundleIdentifier,
            processIdentifier: result.app.processIdentifier,
            mode: effectiveProfile(for: result.app)?.fieldIdentityMode ?? .accessibilityElement,
            input: FocusedFieldIdentityInput(context: context)
        )
        let snapshot = FocusedTextSnapshot(
            fieldIdentity: fieldIdentity,
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor
        )
        recordPersonalCaptureSnapshot(
            context: context,
            app: result.app,
            fieldIdentity: fieldIdentity,
            fieldClassification: fieldClassification,
            snapshot: snapshot,
            source: "capture-only:\(reason)"
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
            showFieldStatusIndicator(.blocked.withReason(terminalHostBlockReason), context: rawContext)
            var metadata = claudeCodeTerminalHostProofDiagnosticMetadata(
                app: frontmostApp,
                context: rawContext,
                profile: profile
            )
            metadata["reason"] = terminalHostBlockReason
            metadata["terminalHostBundleIdentifier"] = frontmostApp.bundleIdentifier
            recordBlockedSuggestionEvent(
                "suggestion-blocked",
                context: rawContext,
                profile: profile,
                fieldIdentity: fieldIdentity(app: frontmostApp, context: rawContext, profile: profile),
                metadata: metadata
            )
            hideSuggestion()
            return
        }

        let promptMatch = promptTextAreaMatch(
            for: frontmostApp.bundleIdentifier,
            context: rawContext
        )
        let promptTargetInvalidationResolution = codexPromptTargetInvalidationResolution(
            app: frontmostApp,
            context: rawContext,
            promptBlockReason: promptMatch.reason
        )
        if !promptMatch.canSuggest,
           promptTargetInvalidationResolution == .preserveWork {
            let hasVisibleSuggestion = suggestionSession.hasVisibleSuggestion
            setSuggestionDecision(
                hasVisibleSuggestion
                    ? "Shown: preserving current suggestion"
                    : "Waiting: Codex prompt refresh"
            )
            suggestionChromeHost.hideFieldStatusIndicator()
            DiagnosticsLog.shared.record(
                "codex-prompt-target-refresh-deferred",
                metadata: [
                    "app": frontmostApp.bundleIdentifier,
                    "reason": promptMatch.reason,
                    "role": rawContext.role ?? "unknown",
                    "beforeChars": String(rawContext.textBeforeCursor.count),
                    "afterChars": String(rawContext.textAfterCursor.count),
                    "hasVisibleSuggestion": String(hasVisibleSuggestion)
                ]
            )
            if hasVisibleSuggestion {
                updateKeyboardEventTapSnapshot()
            }
            return
        }
        if !promptMatch.canSuggest,
           promptTargetInvalidationResolution == .cancelAndRetry {
            cancelAndRearmCodexPromptTargetWork(
                app: frontmostApp,
                context: rawContext,
                profile: profile,
                promptBlockReason: promptMatch.reason,
                source: "prompt-validation"
            )
            setSuggestionDecision("Waiting: Codex prompt refresh")
            suggestionChromeHost.hideFieldStatusIndicator()
            return
        }
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
        appTargetStateHost.rememberFieldControlTarget(
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
        codexPromptTargetContinuityHost.rememberAnchor(
            appBundleIdentifier: frontmostApp.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            context: context
        )
        rememberTrustedObsidianEndOfDocumentSnapshotIfNeeded(snapshot)
        recordPersonalCaptureSnapshot(
            context: context,
            app: frontmostApp,
            fieldIdentity: fieldIdentity,
            fieldClassification: fieldClassification,
            snapshot: snapshot,
            source: "suggestion-poll"
        )
        refreshVisiblePageContextIfNeeded(
            context: context,
            app: frontmostApp,
            textChanged: previousSnapshot == nil || snapshot != previousSnapshot
        )

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

        let idleRetryReason: SuggestionIdleRetryReason?
        if snapshot == previousSnapshot {
            idleRetryReason = suggestionIdleRetryState.consumeRetryIfReady(
                snapshot: snapshot,
                nowMilliseconds: Int(ProcessInfo.processInfo.systemUptime * 1_000),
                hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion
            )
        } else {
            idleRetryReason = nil
        }

        guard snapshot != previousSnapshot || idleRetryReason != nil else {
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
            let isWaitingForIdleRetry = suggestionIdleRetryState.hasPendingRetry
            setSuggestionDecision(
                suggestionSession.hasVisibleSuggestion
                    ? "Shown: tracking current field"
                    : isWaitingForIdleRetry
                        ? "Waiting: typing to settle"
                        : "Ready: waiting for text change"
            )
            showFieldStatusIndicator(
                suggestionSession.hasVisibleSuggestion
                    ? .shown
                    : isWaitingForIdleRetry
                        ? .waiting.withReason("typing to settle")
                        : .ready,
                context: context
            )
            repositionVisibleSuggestion(context: context, profile: profile)
            return
        }

        if previousSnapshot != nil, idleRetryReason == nil {
            lastFocusedTextChangeAt = Date()
        }
        cancelPrefixCooldownRetry()
        let typingBurstDecision: TypingBurstDecision
        if let idleRetryReason {
            typingBurstState.reset()
            typingBurstDecision = .idle
            suggestionBlockLogGate.reset()
            DiagnosticsLog.shared.record(
                "suggestion-idle-retry",
                metadata: [
                    "reason": idleRetryReason.rawValue,
                    "fieldIdentity": fieldIdentity.traceDescription,
                    "beforeChars": String(snapshot.textBeforeCursor.count),
                    "afterChars": String(snapshot.textAfterCursor.count)
                ]
            )
        } else {
            typingBurstDecision = observeTypingBurst(
                previousSnapshot: previousSnapshot,
                currentSnapshot: snapshot
            )
        }

        if idleRetryReason == nil {
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
        }

        lastTextSnapshot = snapshot
        let cancelledPendingRequest = invalidatePendingSuggestionRequest()
        if idleRetryReason == nil {
            suggestionIdleRetryState.noteTextChange(
                snapshot: snapshot,
                cancelledPendingRequest: cancelledPendingRequest,
                nowMilliseconds: Int(ProcessInfo.processInfo.systemUptime * 1_000),
                settleDelayMilliseconds: triggerPolicy(for: profile).pauseDelayMilliseconds
            )
        }
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

        let allowsTrustedProofSensitiveContent = allowsClaudeCodeTerminalHostProofSensitiveActivationBypass(
            app: frontmostApp,
            context: context,
            profile: profile,
            fieldIdentity: fieldIdentity,
            fieldClassification: suggestionFieldClassification
        )
        let rawActivationDecision = activationPolicy(for: profile).decision(
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            isSecure: context.isSecure,
            selectedTextLength: context.selectedTextLength,
            isFieldSuppressed: suppressedFieldIdentities.contains(fieldIdentity),
            fieldKind: suggestionFieldClassification.kind,
            allowsUnknownFieldKind: profile.allowsUnknownFieldKind,
            allowsTrustedProofSensitiveContent: allowsTrustedProofSensitiveContent
        )
        if allowsTrustedProofSensitiveContent {
            recordClaudeCodeTerminalHostProofSensitiveActivationBypass(
                context: context,
                hostBundleIdentifier: frontmostApp.bundleIdentifier,
                rawDecision: rawActivationDecision
            )
        }
        let activationDecision = proofAdjustedActivationDecision(
            rawActivationDecision,
            context: context,
            profile: profile,
            fieldIdentity: fieldIdentity,
            fieldKind: suggestionFieldClassification.kind
        )
        appTargetStateHost.rememberFieldControlTarget(
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
                contentSensitivity: Self.traceContentSensitivity(
                    fieldClassification: suggestionFieldClassification,
                    activationDecision: activationDecision
                ),
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
            showFieldStatusIndicator(.blocked.withReason("placement needs proof first"), context: context)
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
        let triggerDecision = suggestionTriggerTimingPolicy.decision(
            using: triggerPolicy(for: profile),
            previousTextBeforeCursor: lastRequestedTextBeforeCursor,
            currentTextBeforeCursor: context.textBeforeCursor,
            lineStartBehavior: SuggestionLineStartBehavior.behavior(
                for: triggerBehaviorProfile.id,
                currentLineStructure: currentLineStructure
            ),
            behaviorProfileID: triggerBehaviorProfile.id,
            requestMode: requestMode
        )
        let isManualSuggestionRequest = manualSuggestionRequestHost.consumePendingRequest()

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
        } else if idleRetryReason != nil {
            delayMilliseconds = 0
            timingLane = switch requestMode {
            case .wordCompletion:
                .instantWord
            case .sentenceContinuation:
                .longPauseThought
            case .phraseContinuation:
                .pausePhrase
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
            visiblePageContext: cachedVisiblePageContext(
                context: context,
                appBundleIdentifier: frontmostApp.bundleIdentifier
            ),
            triggerReason: isManualSuggestionRequest
                ? "manual-summon"
                : idleRetryReason != nil
                    ? "idle-retry"
                    : "poll"
        )
    }

    static func traceContentSensitivity(
        fieldClassification: AXFieldClassification,
        activationDecision: CompletionActivationDecision
    ) -> TraceContentSensitivity {
        if fieldClassification.suppressesSuggestionsByDefault
            || activationDecision.blockedReason == .sensitiveContent
            || activationDecision.blockedReason == .secureField {
            return .sensitiveSurface
        }

        return .standard
    }

    private func claudeCodeTerminalHostProofContext(
        app: RunningApplicationInfo,
        context: FocusedTextContext,
        profile: CompatibilityProfile
    ) -> ClaudeCodeTerminalHostProofContext? {
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
        let searchableInputText = [
            focusedLine,
            context.textBeforeCursor,
            context.textAfterCursor
        ].joined(separator: "\n")
        let proofModeEnabled = activeAppProofBundleIdentifiers.contains(
            ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier
        )
        let shouldReadTerminalScreenText = app.bundleIdentifier == "com.mitchellh.ghostty"
            || !ClaudeCodeTerminalHostProofPolicy.containsProofMarker(searchableInputText)
        let terminalScreenText = shouldReadTerminalScreenText
            ? (accessibilityClient.focusedWindowText(for: app) ?? "")
            : ""
        return ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: app.bundleIdentifier,
            windowTitle: context.fingerprint.windowTitle ?? "",
            focusedText: focusedLine,
            rawTextBeforeCursor: context.textBeforeCursor,
            rawTextAfterCursor: context.textAfterCursor,
            terminalScreenText: terminalScreenText,
            proofModeEnabled: proofModeEnabled
        )
    }

    private func claudeCodeTerminalHostProofBlockReason(
        app: RunningApplicationInfo,
        context: FocusedTextContext,
        profile: CompatibilityProfile
    ) -> String? {
        guard let proofContext = claudeCodeTerminalHostProofContext(
            app: app,
            context: context,
            profile: profile
        ) else {
            return nil
        }
        let decision = ClaudeCodeTerminalHostProofPolicy.evaluate(proofContext)

        switch decision {
        case .eligible:
            guard ClaudeCodeTerminalHostProofPolicy.proofInputText(for: proofContext) != nil else {
                return "claude-code-terminal-host-unsafeInputLine"
            }
            return nil
        case let .blocked(reason):
            return "claude-code-terminal-host-\(reason.rawValue)"
        }
    }

    private func claudeCodeTerminalHostProofDiagnosticMetadata(
        app: RunningApplicationInfo,
        context: FocusedTextContext,
        profile: CompatibilityProfile
    ) -> [String: String] {
        guard let proofContext = claudeCodeTerminalHostProofContext(
            app: app,
            context: context,
            profile: profile
        ) else {
            return [:]
        }

        return ClaudeCodeTerminalHostProofPolicy.diagnosticMetadata(for: proofContext)
    }

    private func allowsClaudeCodeTerminalHostProofSensitiveActivationBypass(
        app: RunningApplicationInfo,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        fieldClassification: AXFieldClassification
    ) -> Bool {
        guard isClaudeCodeTerminalHostProof(profile: profile, hostBundleIdentifier: app.bundleIdentifier),
              fieldClassification == ClaudeCodeTerminalHostProofPolicy.proofFieldClassification,
              !context.isSecure,
              context.selectedTextLength == 0,
              !suppressedFieldIdentities.contains(fieldIdentity) else {
            return false
        }

        let inputSignature = claudeCodeTerminalHostProofInputSignature(
            context: context,
            hostBundleIdentifier: app.bundleIdentifier
        )
        if inputSignature == lastClaudeCodeTerminalProofInputSignature,
           ClaudeCodeTerminalHostProofPolicy.allowsPreviouslyVerifiedSensitiveActivationBypass(
            proofInputText: context.textBeforeCursor
           ) {
            return true
        }

        guard let proofContext = claudeCodeTerminalHostProofContext(
            app: app,
            context: context,
            profile: profile
        ) else {
            return false
        }

        return ClaudeCodeTerminalHostProofPolicy.allowsSensitiveActivationBypass(
            for: proofContext,
            proofInputText: context.textBeforeCursor
        )
    }

    private func recordClaudeCodeTerminalHostProofSensitiveActivationBypass(
        context: FocusedTextContext,
        hostBundleIdentifier: String,
        rawDecision: CompletionActivationDecision
    ) {
        guard rawDecision.canSuggest else {
            return
        }

        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-sensitive-activation-bypass",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "host": hostBundleIdentifier,
                "beforeChars": String(context.textBeforeCursor.count),
                "afterChars": String(context.textAfterCursor.count),
                "requestMode": rawDecision.requestMode?.rawValue ?? "none"
            ]
        )
    }

    private func effectiveSuggestionFieldClassification(
        app: RunningApplicationInfo,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        raw classification: AXFieldClassification
    ) -> AXFieldClassification {
        if isClaudeCodeTerminalHostProof(profile: profile, hostBundleIdentifier: app.bundleIdentifier),
           claudeCodeTerminalHostProofInputSignature(
            context: context,
            hostBundleIdentifier: app.bundleIdentifier
           ) == lastClaudeCodeTerminalProofInputSignature {
            return ClaudeCodeTerminalHostProofPolicy.proofFieldClassification
        }

        guard let proofContext = claudeCodeTerminalHostProofContext(
            app: app,
            context: context,
            profile: profile
        ) else {
            return classification
        }

        return ClaudeCodeTerminalHostProofPolicy.effectiveFieldClassification(
            raw: classification,
            for: proofContext
        )
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
        if isClaudeCodeTerminalHostProof(profile: profile, hostBundleIdentifier: app.bundleIdentifier) {
            return ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier
        }

        return app.bundleIdentifier
    }

    private func allowFocusedTextAXRead(for app: RunningApplicationInfo) -> Bool {
        switch focusedTextAXHealthPolicy.pollDecision(
            for: app.bundleIdentifier,
            now: Date(),
            state: &focusedTextAXHealthState
        ) {
        case let .allowed(recovery?):
            codexPromptTargetContinuityHost.clearCooldownPreservation()
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
            codexPromptTargetContinuityHost.clearCooldownPreservation()
            return true
        case let .coolingDown(cooldown):
            let hasActiveSuggestionWork = suggestionRequestScheduler.hasPendingRequest
                || codexPromptPresentationRetryHost.hasScheduledRetry
                || suggestionSession.hasVisibleSuggestion
                || suggestionIdleRetryState.hasPendingRetry
                || manualSuggestionRequestHost.isPending
            let shouldPreservePendingRequest = codexPromptTargetContinuityHost
                .canPreserveDuringAXCooldown(
                    app: app,
                    currentFieldIdentity: currentFieldIdentity,
                    currentSnapshot: lastTextSnapshot,
                    hasActiveSuggestionWork: hasActiveSuggestionWork
                )
            if !shouldPreservePendingRequest {
                codexPromptTargetContinuityHost.clearCooldownPreservation()
            }
            DiagnosticsLog.shared.record(
                "focused-text-ax-health-cooldown",
                metadata: [
                    "app": cooldown.bundleIdentifier,
                    "reason": cooldown.reason.rawValue,
                    "slowReadCount": String(cooldown.slowReadCount),
                    "remainingMilliseconds": String(cooldown.remainingMilliseconds)
                ]
            )
            handleFocusedTextAXHealthCooldown(
                cooldown,
                source: "poll",
                preservePendingRequest: shouldPreservePendingRequest
            )
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

        let hasActiveSuggestionWork = suggestionRequestScheduler.hasPendingRequest
            || codexPromptPresentationRetryHost.hasScheduledRetry
            || suggestionSession.hasVisibleSuggestion
            || suggestionIdleRetryState.hasPendingRetry
            || manualSuggestionRequestHost.isPending
        let promptTargetInvalidationResolution = result.context.map {
            codexPromptTargetContinuityHost.axHealthInvalidationResolution(
                app: result.app,
                currentFieldIdentity: currentFieldIdentity,
                currentSnapshot: lastTextSnapshot,
                observedContext: $0
            )
        } ?? .reject
        let rearmedTransientRequest: Bool
        if hasActiveSuggestionWork,
           promptTargetInvalidationResolution == .cancelAndRetry,
           let context = result.context,
           let profile = effectiveProfile(for: result.app) {
            rearmedTransientRequest = cancelAndRearmCodexPromptTargetWork(
                app: result.app,
                context: context,
                profile: profile,
                promptBlockReason: promptTextAreaMatch(
                    for: result.app.bundleIdentifier,
                    context: context
                ).reason,
                source: "ax-health"
            )
        } else {
            rearmedTransientRequest = false
        }
        let shouldPreservePendingRequest: Bool
        if hasActiveSuggestionWork,
           promptTargetInvalidationResolution == .preserveWork {
            shouldPreservePendingRequest = result.context.map {
                codexPromptTargetContinuityHost.beginAXCooldownPreservation(
                    app: result.app,
                    currentFieldIdentity: currentFieldIdentity,
                    currentSnapshot: lastTextSnapshot,
                    observedContext: $0,
                    hasActiveSuggestionWork: hasActiveSuggestionWork,
                    cooldownMilliseconds: cooldown.cooldownMilliseconds
                )
            } ?? false
        } else if rearmedTransientRequest {
            shouldPreservePendingRequest = codexPromptTargetContinuityHost
                .preserveDuringAXCooldown(forMilliseconds: cooldown.cooldownMilliseconds)
        } else {
            shouldPreservePendingRequest = false
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
        handleFocusedTextAXHealthCooldown(
            cooldown,
            source: "read",
            preservePendingRequest: shouldPreservePendingRequest
        )
        setSuggestionDecision("Waiting: AX cooldown")
        return true
    }

    private func handleFocusedTextAXHealthCooldown(
        _ cooldown: FocusedTextAXHealthCooldown,
        source: String,
        preservePendingRequest: Bool = false
    ) {
        suggestionChromeHost.hideFieldStatusIndicator()
        if !preservePendingRequest {
            invalidatePendingSuggestionRequest()
        }
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
        let preservesPendingRequest = shouldPreserveClaudeCodeTerminalHostProofPendingRequestDuringFocusedTextPollingThrottle(
            reason: reason,
            pauseMilliseconds: recommendation.pauseMilliseconds
        )
        if !preservesPendingRequest {
            invalidatePendingSuggestionRequest()
        }
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
                "pendingRequestPreserved": String(preservesPendingRequest)
            ]
        )
        return true
    }

    private func shouldPreserveClaudeCodeTerminalHostProofPendingRequestDuringFocusedTextPollingThrottle(
        reason: FocusedTextPollingThrottleReason,
        pauseMilliseconds: Int
    ) -> Bool {
        let pendingRequest = suggestionOrchestrator.currentRequest
        guard ClaudeCodeTerminalHostProofPolicy.shouldPreservePendingRequestDuringFocusedTextPollingThrottle(
            pendingRequestAppBundleIdentifier: pendingRequest?.appBundleIdentifier,
            pendingRequestTextBeforeCursor: pendingRequest?.textBeforeCursor,
            pendingRequestTextAfterCursor: pendingRequest?.textAfterCursor,
            pendingRequestFieldKind: pendingRequest?.fieldKind,
            pendingRequestMode: pendingRequest?.mode,
            currentProfileBundleIdentifier: currentProfile?.bundleIdentifier,
            currentTextBeforeCursor: lastTextSnapshot?.textBeforeCursor,
            currentTextAfterCursor: lastTextSnapshot?.textAfterCursor
        ) else {
            return false
        }

        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-pending-request-preserved",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "reason": reason.rawValue,
                "pauseMilliseconds": String(pauseMilliseconds),
                "beforeChars": String(pendingRequest?.textBeforeCursor.count ?? 0),
                "afterChars": String(pendingRequest?.textAfterCursor.count ?? 0),
                "requestMode": pendingRequest?.mode.rawValue ?? "unknown"
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
        guard currentSuggestionState.appBundleIdentifier
            == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
            let hostBundleIdentifier = currentSuggestionState.fieldIdentity?.bundleIdentifier,
            ClaudeCodeTerminalHostProofPolicy.supportedTerminalHosts.contains(hostBundleIdentifier)
        else {
            return nil
        }

        return hostBundleIdentifier
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

        var terminalScreenPromptAnchor = claudeCodeTerminalHostProofContext(
            app: app,
            context: context,
            profile: profile
        ).flatMap {
            ClaudeCodeTerminalHostProofPolicy.terminalScreenPromptAnchor(for: $0)
        }
        if let terminalScreenPromptAnchor {
            claudeCodeTerminalScreenPromptAnchorCache.remember(
                terminalScreenPromptAnchor,
                hostBundleIdentifier: app.bundleIdentifier
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-prompt-anchor-cache-remembered",
                metadata: [
                    "app": profile.bundleIdentifier,
                    "host": app.bundleIdentifier,
                    "inputChars": String(terminalScreenPromptAnchor.inputText.count),
                    "promptLineInputChars": String(terminalScreenPromptAnchor.promptLineInputText.count),
                    "lineIndex": String(terminalScreenPromptAnchor.lineIndex),
                    "lineCount": String(terminalScreenPromptAnchor.lineCount)
                ]
            )
        }

        var repairedProofInputText: String?
        if let proofInputText = claudeCodeTerminalHostProofInputText(
            app: app,
            context: context,
            profile: profile
        ) {
            repairedProofInputText = proofInputText
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
        } else if isClaudeCodeTerminalHostProof(
            profile: profile,
            hostBundleIdentifier: app.bundleIdentifier
        ) {
            lastClaudeCodeTerminalProofInputSignature = nil
        }

        let syntheticCaretBundleIdentifier = syntheticTextAreaCaretBundleIdentifier(
            for: app,
            profile: profile
        )
        if terminalScreenPromptAnchor == nil,
           ClaudeCodeTerminalHostProofPolicy.requiresTerminalScreenPromptCaret(
            hostBundleIdentifier: app.bundleIdentifier
           ),
           let repairedProofInputText,
           let cachedAnchor = claudeCodeTerminalScreenPromptAnchorCache.anchorForRepairedInput(
            hostBundleIdentifier: app.bundleIdentifier,
            inputText: repairedProofInputText
           ) {
            terminalScreenPromptAnchor = cachedAnchor
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-prompt-anchor-cache-used",
                metadata: [
                    "app": profile.bundleIdentifier,
                    "host": app.bundleIdentifier,
                    "beforeChars": String(context.textBeforeCursor.count),
                    "promptLineInputChars": String(cachedAnchor.promptLineInputText.count),
                    "lineIndex": String(cachedAnchor.lineIndex),
                    "lineCount": String(cachedAnchor.lineCount)
                ]
            )
        } else if terminalScreenPromptAnchor == nil,
                  ClaudeCodeTerminalHostProofPolicy.requiresTerminalScreenPromptCaret(
                    hostBundleIdentifier: app.bundleIdentifier
                  ),
                  let repairedProofInputText,
                  ClaudeCodeTerminalHostProofPolicy.allowsPreviouslyVerifiedSensitiveActivationBypass(
                    proofInputText: repairedProofInputText
                  ) {
            terminalScreenPromptAnchor = ClaudeCodeTerminalScreenPromptAnchor(
                inputText: repairedProofInputText,
                promptLineInputText: ClaudeCodeTerminalHostProofPolicy
                    .titleScopedDirectPromptLineInputText(for: repairedProofInputText),
                lineIndex: 0,
                lineCount: 4
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-direct-prompt-anchor-used",
                metadata: [
                    "app": profile.bundleIdentifier,
                    "host": app.bundleIdentifier,
                    "beforeChars": String(context.textBeforeCursor.count),
                    "promptLineInputChars": String(repairedProofInputText.count),
                    "lineIndex": "0",
                    "lineCount": "4"
                ]
            )
        } else if terminalScreenPromptAnchor == nil,
                  ClaudeCodeTerminalHostProofPolicy.requiresTerminalScreenPromptCaret(
                    hostBundleIdentifier: app.bundleIdentifier
                  ),
                  let repairedProofInputText {
            var metadata = claudeCodeTerminalScreenPromptAnchorCache.diagnosticMetadata(
                hostBundleIdentifier: app.bundleIdentifier,
                inputText: repairedProofInputText
            )
            metadata.merge([
                "app": profile.bundleIdentifier,
                "host": app.bundleIdentifier,
                "beforeChars": String(context.textBeforeCursor.count)
            ]) { _, newValue in newValue }
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-prompt-anchor-cache-missed",
                metadata: metadata
            )
        }
        if syntheticCaretBundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
           ClaudeCodeTerminalHostProofPolicy.requiresTerminalScreenPromptCaret(
            hostBundleIdentifier: app.bundleIdentifier
           ),
           terminalScreenPromptAnchor == nil {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-placement-blocked",
                metadata: [
                    "app": profile.bundleIdentifier,
                    "host": app.bundleIdentifier,
                    "reason": "missing-terminal-screen-prompt",
                    "beforeChars": String(context.textBeforeCursor.count),
                    "afterChars": String(context.textAfterCursor.count)
                ]
            )
            return context
        }
        guard supportsSyntheticTextAreaCaret(for: app, profile: profile),
              promptTextAreaMatch(for: app.bundleIdentifier, context: context).canSuggest,
              shouldUseSyntheticTextAreaCaret(for: app, profile: profile, context: context),
              let syntheticCaret = syntheticTextAreaCaretRect(
                for: context,
                bundleIdentifier: syntheticCaretBundleIdentifier,
                terminalScreenPromptAnchor: terminalScreenPromptAnchor
              ) else {
            return context
        }

        let syntheticCaretSource = syntheticCaretBundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier
            && terminalScreenPromptAnchor != nil
            ? "terminal-screen-prompt"
            : "text-area-estimate"
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
        guard context.caretRect != nil else {
            return true
        }

        guard isClaudeCodeTerminalHostProof(
            profile: profile,
            hostBundleIdentifier: app.bundleIdentifier
        ) else {
            return false
        }

        return true
    }

    private func claudeCodeTerminalHostProofInputText(
        app: RunningApplicationInfo,
        context: FocusedTextContext,
        profile: CompatibilityProfile
    ) -> String? {
        guard let proofContext = claudeCodeTerminalHostProofContext(
            app: app,
            context: context,
            profile: profile
        ),
              claudeCodeTerminalHostProofBlockReason(
                app: app,
                context: context,
                profile: profile
              ) == nil else {
            return nil
        }

        return ClaudeCodeTerminalHostProofPolicy.proofInputText(for: proofContext)
    }

    private func recordClaudeCodeTerminalHostProofInputRepair(
        context: FocusedTextContext,
        hostBundleIdentifier: String,
        profile: CompatibilityProfile
    ) {
        let signature = claudeCodeTerminalHostProofInputSignature(
            context: context,
            hostBundleIdentifier: hostBundleIdentifier
        )

        guard signature != lastClaudeCodeTerminalProofInputSignature else {
            return
        }

        lastClaudeCodeTerminalProofInputSignature = signature
        let partialWordShape = PartialWordShape.from(textBeforeCursor: context.textBeforeCursor)
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-input",
            metadata: [
                "app": profile.bundleIdentifier,
                "host": hostBundleIdentifier,
                "source": "focused-input-line",
                "beforeChars": String(context.textBeforeCursor.count),
                "afterChars": String(context.textAfterCursor.count),
                "wordCount": String(context.textBeforeCursor.split(whereSeparator: \.isWhitespace).count),
                "hasPromptGlyph": String(context.textBeforeCursor.contains("❯")),
                "hasProofMarker": String(
                    ClaudeCodeTerminalHostProofPolicy.containsProofMarker(context.textBeforeCursor)
                ),
                "partialWordCharacters": String(partialWordShape?.characterCount ?? 0),
                "partialWordLetters": String(partialWordShape?.letterCount ?? 0),
                "partialWordCasing": partialWordShape?.casing.rawValue ?? PartialWordCasing.none.rawValue
            ]
        )
    }

    private func claudeCodeTerminalHostProofInputSignature(
        context: FocusedTextContext,
        hostBundleIdentifier: String
    ) -> String {
        [
            hostBundleIdentifier,
            String(context.elementIdentifier),
            String(context.textBeforeCursor.count),
            String(context.textAfterCursor.count),
            claudeCodeTerminalHostProofInputToken(context.textBeforeCursor)
        ].joined(separator: "|")
    }

    private func claudeCodeTerminalHostProofInputToken(_ text: String) -> String {
        let tokens = AcceptanceSurvivalClassifier.looseTokens(in: text)
        return TracePrivacyFingerprint.prefixFamilyMetadata(
            for: tokens,
            secret: tracePrivacySecretStore.secret()
        )["prefixFamilyHMACToken"] ?? "empty"
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
            windowRect: context.windowRect,
            proofModeEnabled: activeAppProofBundleIdentifiers.contains(bundleIdentifier),
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            selectedTextLength: context.selectedTextLength
        )
        return PromptTextAreaMatch(canSuggest: decision.canSuggest, reason: decision.reason)
    }

    private func codexPromptTargetInvalidationResolution(
        app: RunningApplicationInfo,
        context: FocusedTextContext,
        promptBlockReason: String
    ) -> CodexPromptTargetInvalidationResolution {
        let hasActiveSuggestionWork = suggestionRequestScheduler.hasPendingRequest
            || codexPromptPresentationRetryHost.hasScheduledRetry
            || suggestionSession.hasVisibleSuggestion
            || suggestionIdleRetryState.hasPendingRetry
            || manualSuggestionRequestHost.isPending
        guard hasActiveSuggestionWork else {
            return .reject
        }

        return codexPromptTargetContinuityHost.invalidationResolution(
            app: app,
            promptBlockReason: promptBlockReason,
            currentFieldIdentity: currentFieldIdentity,
            currentSnapshot: lastTextSnapshot,
            observedContext: context,
            hasActiveSuggestionWork: hasActiveSuggestionWork
        )
    }

    @discardableResult
    private func cancelAndRearmCodexPromptTargetWork(
        app: RunningApplicationInfo,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        promptBlockReason: String,
        source: String
    ) -> Bool {
        guard let snapshot = lastTextSnapshot else {
            return false
        }

        let shouldArmRetry = suggestionRequestScheduler.hasPendingRequest
            || codexPromptPresentationRetryHost.hasScheduledRetry
            || suggestionSession.hasVisibleSuggestion
            || manualSuggestionRequestHost.isPending
        let cancelledPendingRequest = invalidatePendingSuggestionRequest()
        suggestionIdleRetryState.noteTextChange(
            snapshot: snapshot,
            cancelledPendingRequest: cancelledPendingRequest || shouldArmRetry,
            nowMilliseconds: Int(ProcessInfo.processInfo.systemUptime * 1_000),
            settleDelayMilliseconds: triggerPolicy(for: profile).pauseDelayMilliseconds
        )
        hideSuggestion(reason: "codex-prompt-target-transient")
        DiagnosticsLog.shared.record(
            "codex-prompt-target-refresh-quarantined",
            metadata: [
                "app": app.bundleIdentifier,
                "reason": promptBlockReason,
                "role": context.role ?? "unknown",
                "beforeChars": String(context.textBeforeCursor.count),
                "afterChars": String(context.textAfterCursor.count),
                "requestCancelled": String(cancelledPendingRequest),
                "retryArmed": String(suggestionIdleRetryState.hasPendingRetry),
                "source": source
            ]
        )
        return suggestionIdleRetryState.hasPendingRetry
    }

    private func syntheticTextAreaCaretRect(
        for context: FocusedTextContext,
        bundleIdentifier: String,
        terminalScreenPromptAnchor: ClaudeCodeTerminalScreenPromptAnchor? = nil
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

        if bundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
           let terminalScreenPromptAnchor,
           let terminalScreenCaret = TerminalScreenPromptCaretEstimator.caretRect(
            promptAnchor: terminalScreenPromptAnchor,
            elementRect: elementRect,
            windowRect: context.windowRect,
            lineHeight: lineHeight,
            horizontalPadding: tuning.horizontalPadding,
            inlineGap: tuning.inlineGap,
            widthOfText: { width(of: $0, font: font) }
           ) {
            return terminalScreenCaret
        }

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
        keyboardEventCaptureHost.startIfPossible(
            isTrustedForAccessibility: accessibilityClient.isTrusted,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion,
            controlState: suggestionControlState,
            snapshot: keyboardEventTapSnapshot()
        )
    }

    private func keyboardEventTapSnapshot() -> KeyboardEventTapSnapshot {
        let isClaudeCodeTerminalHostProofSuggestion =
            ClaudeCodeTerminalHostProofPolicy.shouldPreserveVisibleSuggestionAfterPassthroughKeyDown(
                currentSuggestionBundleIdentifier: currentSuggestionState.appBundleIdentifier,
                profileBundleIdentifier: currentProfile?.bundleIdentifier,
                fieldClassification: currentSuggestionState.fieldClassification,
                hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion
            )
        return KeyboardEventTapSnapshot(
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion,
            supportsOneWordAcceptance: currentProfile?.supportsOneWordAcceptance == true
                || isClaudeCodeTerminalHostProofSuggestion,
            supportsFullAcceptance: currentProfile?.supportsFullAcceptance == true
                && !isClaudeCodeTerminalHostProofSuggestion,
            isInvalidatedByUserTyping: currentSuggestionState.invalidatedByUserKeyDown,
            allowsAutocompleteKeyAfterPassthroughObservation: isClaudeCodeTerminalHostProofSuggestion,
            hasPendingAcceptedInsertionUndo: acceptedInsertionUndoIsActive(),
            acceptAllShortcut: keyboardShortcutConfiguration.acceptAllShortcut,
            visibleSuggestionID: currentSuggestionState.id,
            visibleSuggestionRemainingText: suggestionSession.visibleSuggestion?.visibleText,
            visibleSuggestionOriginalText: currentSuggestionState.optimisticOriginalDisplayedText
                ?? suggestionSession.visibleSuggestion?.visibleText,
            optimisticTypedPrefix: currentSuggestionState.optimisticTypedPrefix,
            allowsOptimisticTypeThrough: currentKeyboardInputSourceAllowsOptimisticTypeThrough()
        )
    }

    private func updateKeyboardEventTapSnapshot() {
        keyboardEventCaptureHost.updateSnapshot(keyboardEventTapSnapshot())
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
        keyboardEventCaptureHost.scheduleStopIfIdle()
    }

    private func cancelKeyboardEventTapIdleStop() {
        keyboardEventCaptureHost.cancelIdleStop()
    }

    private func stopKeyboardEventTapNow(reason: String) {
        keyboardEventCaptureHost.stopNow(reason: reason)
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

        if preserveClaudeCodeTerminalHostProofSuggestionAfterPassthroughIfNeeded(source: "observer") {
            return
        }

        currentSuggestionState.invalidatedByUserKeyDown = true
        invalidatePendingSuggestionRequest()
        setSuggestionDecision("Shown: tracking typing")
        updateKeyboardEventTapSnapshot()
    }

    private func observeOptimisticTypeThrough(_ transition: KeyboardOptimisticTypeThroughTransition) {
        suggestionPipeline.pausePolling(
            now: Date(),
            durationMilliseconds: visibleSuggestionTypingPollPauseMilliseconds
        )
        clearPendingAcceptedInsertionUndo(reason: "typing")
        guard suggestionSession.hasVisibleSuggestion,
              currentSuggestionState.applyOptimisticTypeThrough(transition) else {
            return
        }

        if transition.remainingText.isEmpty {
            currentSuggestionState.invalidatedByUserKeyDown = false
            setSuggestionDecision("Queued: refreshing after typed suggestion")
            hideSuggestion(reason: "typed-through-visible-prefix")
            return
        }

        guard let currentSuggestion = suggestionSession.visibleSuggestion else { return }
        suggestionSession.present(CompletionSuggestion(
            text: transition.remainingText,
            maxVisibleWords: currentSuggestion.maxVisibleWords,
            maxVisibleCharacters: currentSuggestion.maxVisibleCharacters
        ))
        currentSuggestionState.displayedText = transition.remainingText
        currentSuggestionState.invalidatedByUserKeyDown = false
        setSuggestionDecision("Shown: typing through suggestion")
        _ = refreshVisibleSuggestion()
        updateKeyboardEventTapSnapshot()
    }

    private func preserveClaudeCodeTerminalHostProofSuggestionAfterPassthroughIfNeeded(source: String) -> Bool {
        guard let preserveReason = claudeCodeTerminalHostProofPassthroughPreserveReason() else {
            return false
        }

        keyboardEventTap?.resetPassthroughObservation()
        currentSuggestionState.invalidatedByUserKeyDown = false
        updateKeyboardEventTapSnapshot()
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-passthrough-preserved",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "requestMode": currentSuggestionState.requestMode?.rawValue ?? "unknown",
                "fieldKindReason": currentSuggestionState.fieldClassification?.reason ?? "unknown",
                "preserveReason": preserveReason,
                "source": source
            ]
        )
        return true
    }

    private func claudeCodeTerminalHostProofPassthroughPreserveReason() -> String? {
        guard ClaudeCodeTerminalHostProofPolicy.shouldPreserveVisibleSuggestionAfterPassthroughKeyDown(
            currentSuggestionBundleIdentifier: currentSuggestionState.appBundleIdentifier,
            profileBundleIdentifier: currentProfile?.bundleIdentifier,
            fieldClassification: currentSuggestionState.fieldClassification,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion
        ) else {
            return nil
        }

        if terminalHostProofSnapshotMatchesCurrentSuggestion() {
            return "verified-snapshot"
        }

        guard let currentProfile,
              ClaudeCodeTerminalHostProofPolicy.shouldBridgePassthroughAfterVolatileSnapshot(
                  currentSuggestionBundleIdentifier: currentSuggestionState.appBundleIdentifier,
                  profileBundleIdentifier: currentProfile.bundleIdentifier,
                  fieldClassification: currentSuggestionState.fieldClassification,
                  hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion,
                  supportsOneWordAcceptance: currentProfile.supportsOneWordAcceptance,
                  supportsFullAcceptance: currentProfile.supportsFullAcceptance,
                  requiresNoSubmitAcceptanceProof: currentProfile.requiresNoSubmitAcceptanceProof,
                  insertionMode: currentProfile.insertionMode
              ) else {
            return nil
        }

        return "volatile-snapshot-bridge"
    }

    private func handleAutocompleteKey(
        _ key: AutocompleteKey,
        isAutorepeat: Bool = false,
        didObservePassthroughKeyDown: Bool = false
    ) -> KeyboardEventTapHandlingResult {
        if didObservePassthroughKeyDown {
            if preserveClaudeCodeTerminalHostProofSuggestionAfterPassthroughIfNeeded(source: "handler") {
                preservesResidualSuggestionAfterNextWordAccept = false
            } else {
                currentSuggestionState.invalidatedByUserKeyDown = true
                preservesResidualSuggestionAfterNextWordAccept = false
                clearPendingAcceptedInsertionUndo(reason: "typing")
            }
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

        recordClaudeCodeTerminalHostProofKeyboardProgress(
            stage: "focus-check-start",
            key: key,
            action: action
        )
        guard focusedFieldMatchesCurrentSuggestion(
            allowTerminalHostProofSnapshotFastPath: action == .acceptNextWord,
            allowCodexProofSnapshotFastPath: action.insertsSuggestionText,
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
        recordClaudeCodeTerminalHostProofKeyboardProgress(
            stage: "focus-check-passed",
            key: key,
            action: action
        )

        if currentSuggestionState.invalidatedByUserKeyDown {
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
            return .replayOriginalKey(.staleAfterTyping)
        }

        if shouldSuppressKey(key, isAutorepeat: isAutorepeat) {
            recordClaudeCodeTerminalHostProofKeyboardProgress(
                stage: "suppressed-autorepeat",
                key: key,
                action: action
            )
            recordKeyboardAction(key: key, action: .passThrough, handled: true, reason: "suppressed-autorepeat")
            return .handled
        }

        switch action {
        case .requestSuggestionNow:
            return .replayOriginalKey(.passThroughAction)

        case .undoAcceptedInsertion:
            return .replayOriginalKey(.undoUnavailable)

        case .acceptNextWord:
            recordClaudeCodeTerminalHostProofKeyboardProgress(
                stage: "accept-next-word-entered",
                key: key,
                action: action
            )
            guard currentProfile?.supportsOneWordAcceptance == true else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "unsupported-one-word")
                return .replayOriginalKey(.unsupportedAction)
            }
            if let blockReason = currentSuggestionAcceptanceDecision(
                allowCodexProofSnapshotFastPath: true,
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
            recordClaudeCodeTerminalHostProofKeyboardProgress(
                stage: "accept-next-word-baseline-ready",
                key: key,
                action: action,
                metadata: [
                    "hasBaseline": String(verificationBaseline != nil)
                ]
            )
            guard let rawAcceptedText = suggestionSession.nextWordAcceptance() else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "missing-accepted-text")
                return keyboardCaptureSafetyPolicy.handlingResult(forAcceptanceFailure: .missingAcceptedText)
            }
            let acceptedText = acceptedTextForCurrentAcceptance(rawAcceptedText, action: action)
            recordClaudeCodeTerminalHostProofKeyboardProgress(
                stage: "accept-next-word-text-ready",
                key: key,
                action: action,
                metadata: [
                    "acceptedChars": String(acceptedText.count),
                    "rawAcceptedChars": String(rawAcceptedText.count)
                ]
            )
            guard let acceptanceProof = suggestionAcceptanceProof(action: action, acceptedText: acceptedText) else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "acceptance-proof-failed")
                return keyboardCaptureSafetyPolicy.handlingResult(forAcceptanceFailure: .acceptanceProofFailed)
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
            if scheduleDeferredClaudeCodeTerminalHostProofNextWordAcceptance(
                acceptedText: acceptedText,
                acceptanceID: acceptanceID,
                acceptedAt: acceptedAt,
                action: action,
                acceptanceProof: acceptanceProof,
                verificationBaseline: verificationBaseline
            ) {
                suppressKey(key)
                recordKeyboardAction(key: key, action: action, handled: true, reason: "accepted-deferred-insert-scheduled")
                return .handled
            }
            guard insertAcceptedText(acceptedText, action: action) else {
                suppressCurrentFieldAfterInsertionFailure(reason: "insert-failed")
                recordKeyboardAction(key: key, action: action, handled: false, reason: "insert-failed")
                return keyboardCaptureSafetyPolicy.handlingResult(forAcceptanceFailure: .insertionFailed)
            }
            recordClaudeCodeTerminalHostProofKeyboardProgress(
                stage: "accept-next-word-insert-succeeded",
                key: key,
                action: action
            )

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
                allowCodexProofSnapshotFastPath: true,
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
            guard let acceptanceProof = suggestionAcceptanceProof(action: action, acceptedText: acceptedText) else {
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
            suggestionOrchestrator.recordRepetitionAcceptance(
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
        action: KeyboardAction
    ) -> String {
        guard let currentProfile,
              shouldUseClaudeCodeTerminalHostProofDirectInsertion(
                profile: currentProfile,
                action: action
              ) else {
            return acceptedText
        }

        let trimmed = acceptedText.trimmingTrailingWhitespace()
        return trimmed.isEmpty ? acceptedText : trimmed
    }

    private func currentSuggestionAcceptanceDecision(
        allowCodexProofSnapshotFastPath: Bool = false,
        allowObsidianSnapshotFastPath: Bool = false
    ) -> SuggestionAcceptanceDecision {
        guard let shownSnapshot = currentSuggestionState.acceptanceSnapshot else {
            return .block(.missingShownSnapshot)
        }

        if allowCodexProofSnapshotFastPath,
           codexProofAcceptanceSnapshotMatchesShown(shownSnapshot) {
            recordCodexProofSnapshotFastPath(stage: "acceptance")
            return .allow
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

    private func recordClaudeCodeTerminalHostProofKeyboardProgress(
        stage: String,
        key: AutocompleteKey,
        action: KeyboardAction,
        metadata: [String: String] = [:]
    ) {
        if currentSuggestionState.appBundleIdentifier == "md.obsidian"
            || currentProfile?.bundleIdentifier == "md.obsidian" {
            var payload = metadata
            payload["app"] = "md.obsidian"
            payload["key"] = key.diagnosticName
            payload["action"] = action.diagnosticName
            payload["stage"] = stage
            payload["hasVisibleSuggestion"] = String(suggestionSession.hasVisibleSuggestion)
            payload["requestMode"] = currentSuggestionState.requestMode?.rawValue ?? "unknown"
            DiagnosticsLog.shared.record(
                "obsidian-keyboard-progress",
                metadata: payload
            )
        }

        guard currentSuggestionState.appBundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier
            || currentProfile?.bundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier else {
            return
        }

        var payload = metadata
        payload["app"] = ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier
        payload["key"] = key.diagnosticName
        payload["action"] = action.diagnosticName
        payload["stage"] = stage
        payload["hasVisibleSuggestion"] = String(suggestionSession.hasVisibleSuggestion)
        payload["requestMode"] = currentSuggestionState.requestMode?.rawValue ?? "unknown"
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-keyboard-progress",
            metadata: payload
        )
    }

    private func focusedFieldMatchesCurrentSuggestion(
        allowTerminalHostProofSnapshotFastPath: Bool = false,
        allowCodexProofSnapshotFastPath: Bool = false,
        allowObsidianSnapshotFastPath: Bool = false
    ) -> Bool {
        if allowTerminalHostProofSnapshotFastPath,
           terminalHostProofSnapshotMatchesCurrentSuggestion() {
            return true
        }
        if allowCodexProofSnapshotFastPath,
           codexProofSnapshotMatchesCurrentSuggestion() {
            recordCodexProofSnapshotFastPath(stage: "focus")
            return true
        }
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
              claudeCodeTerminalHostProofBlockReason(
                  app: frontmostApp,
                  context: rawContext,
                  profile: profile
              ) == nil,
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

    private func terminalHostProofSnapshotMatchesCurrentSuggestion() -> Bool {
        guard currentSuggestionState.appBundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
              currentSuggestionState.requestMode != nil,
              let currentProfile,
              currentProfile.bundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
              currentProfile.supportsOneWordAcceptance,
              !currentProfile.supportsFullAcceptance,
              currentProfile.requiresNoSubmitAcceptanceProof,
              currentProfile.insertionMode == .clipboardFallbackOptIn,
              let currentSuggestionFieldIdentity = currentSuggestionState.fieldIdentity,
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
                "requestMode": currentSuggestionState.requestMode?.rawValue ?? "unknown"
            ]
        )
        return true
    }

    private func codexProofFocusedTarget(
        app frontmostApp: RunningApplicationInfo,
        profile: CompatibilityProfile,
        suggestionBundleIdentifier: String?,
        requestMode: CompletionRequestMode?,
        expectedFieldIdentity: FocusedFieldIdentity?,
        snapshot: FocusedTextSnapshot?,
        expectedFocusedText: String? = nil,
        shownTargetFingerprint: FocusedTargetFingerprint? = nil
    ) -> (context: FocusedTextContext, fieldIdentity: FocusedFieldIdentity)? {
        let bundleIdentifier = CodexProofFocusedTargetPolicy.bundleIdentifier
        guard let expectedFieldIdentity,
              let snapshot,
              let rawContext = accessibilityClient.focusedTextContext(
                  for: frontmostApp,
                  allowDescendantTextFallback: profile.allowsDescendantTextFallback
              ) else {
            return nil
        }

        let context = presentationAdjustedContext(
            rawContext,
            app: frontmostApp,
            profile: profile,
            previousSnapshot: snapshot
        )
        guard promptTextAreaMatch(
            for: frontmostApp.bundleIdentifier,
            context: context
        ).canSuggest else {
            return nil
        }

        let focusedFieldIdentity = fieldIdentity(
            app: frontmostApp,
            context: context,
            profile: profile
        )
        let focusedTargetFingerprint = targetFingerprint(context: context)
        guard codexProofFocusedTargetPolicy.matches(
            app: frontmostApp,
            profile: profile,
            suggestionBundleIdentifier: suggestionBundleIdentifier,
            requestMode: requestMode,
            expectedFieldIdentity: expectedFieldIdentity,
            snapshot: snapshot,
            focusedContext: context,
            focusedFieldIdentity: focusedFieldIdentity,
            proofModeEnabled: activeAppProofBundleIdentifiers.contains(bundleIdentifier),
            expectedFocusedText: expectedFocusedText,
            shownTargetFingerprint: shownTargetFingerprint
        ) else {
            var metadata: [String: String] = [
                "app": bundleIdentifier,
                "expectedIdentity": expectedFieldIdentity.traceDescription,
                "focusedIdentity": focusedFieldIdentity.traceDescription,
                "identityMatches": String(focusedFieldIdentity == expectedFieldIdentity),
                "hasShownTargetFingerprint": String(shownTargetFingerprint != nil),
                "shownElementBounds": traceRoundedRect(shownTargetFingerprint?.elementBounds),
                "focusedElementBounds": traceRoundedRect(focusedTargetFingerprint.elementBounds),
                "shownWindowBounds": traceRoundedRect(shownTargetFingerprint?.windowBounds),
                "focusedWindowBounds": traceRoundedRect(focusedTargetFingerprint.windowBounds),
                "focusedRole": context.role ?? "",
                "focusedBeforeChars": String(context.textBeforeCursor.count),
                "focusedAfterChars": String(context.textAfterCursor.count),
                "focusedHasMarker": String(context.textBeforeCursor.contains(CodexProofFocusedTargetPolicy.marker)),
                "focusedTextMatchesExpected": expectedFocusedText.map {
                    String(context.textBeforeCursor + context.textAfterCursor == $0)
                } ?? "not-required"
            ]
            if let shownTargetFingerprint {
                metadata["shownTargetMatchesFocused"] = String(
                    shownTargetFingerprint.matchesPostInsertionScopeAllowingElementHeightChange(
                        focusedTargetFingerprint
                    )
                )
                metadata["sameElementFingerprint"] = String(
                    shownTargetFingerprint.elementFingerprint == focusedTargetFingerprint.elementFingerprint
                )
                metadata["sameWindowIdentifier"] = String(
                    shownTargetFingerprint.windowIdentifier == focusedTargetFingerprint.windowIdentifier
                )
                metadata["sameWindowBounds"] = String(
                    shownTargetFingerprint.windowBounds == focusedTargetFingerprint.windowBounds
                )
            } else {
                metadata["shownTargetMatchesFocused"] = "missing"
                metadata["sameElementFingerprint"] = "missing"
                metadata["sameWindowIdentifier"] = "missing"
                metadata["sameWindowBounds"] = "missing"
            }
            DiagnosticsLog.shared.record(
                "codex-proof-focused-target-policy-miss",
                metadata: metadata
            )
            return nil
        }

        return (context, focusedFieldIdentity)
    }

    private func codexProofSnapshotMatchesCurrentSuggestion() -> Bool {
        let bundleIdentifier = CodexProofFocusedTargetPolicy.bundleIdentifier
        let marker = CodexProofFocusedTargetPolicy.marker
        guard currentSuggestionState.appBundleIdentifier == bundleIdentifier,
              CodexProofFocusedTargetPolicy.allowsOneWordProofRequestMode(currentSuggestionState.requestMode),
              let currentProfile,
              currentProfile.bundleIdentifier == bundleIdentifier,
              allowsCodexProofInsertion(profile: currentProfile),
              let currentSuggestionFieldIdentity = currentSuggestionState.fieldIdentity,
              let lastTextSnapshot,
              lastTextSnapshot.fieldIdentity == currentSuggestionFieldIdentity,
              lastTextSnapshot.textBeforeCursor.contains(marker),
              lastTextSnapshot.textAfterCursor.isEmpty,
              let frontmostApp = accessibilityClient.frontmostApplication(),
              let profile = effectiveProfile(for: frontmostApp),
              profile == currentProfile,
              frontmostAppMatchesSuggestion(
                  frontmostApp,
                  expectedBundleIdentifier: bundleIdentifier,
                  profile: profile
              ),
              frontmostApp.processIdentifier == currentSuggestionFieldIdentity.processIdentifier else {
            recordCodexProofSnapshotFastPathMiss(stage: "snapshot", reason: "precondition-failed")
            return false
        }

        let expectedText = lastTextSnapshot.textBeforeCursor + lastTextSnapshot.textAfterCursor
        guard let target = codexProofFocusedTarget(
            app: frontmostApp,
            profile: profile,
            suggestionBundleIdentifier: currentSuggestionState.appBundleIdentifier,
            requestMode: currentSuggestionState.requestMode,
            expectedFieldIdentity: currentSuggestionFieldIdentity,
            snapshot: lastTextSnapshot,
            expectedFocusedText: expectedText,
            shownTargetFingerprint: currentSuggestionState.acceptanceSnapshot?.targetFingerprint
        ) else {
            recordCodexProofSnapshotFastPathMiss(stage: "snapshot", reason: "focused-target-mismatch")
            return false
        }

        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        guard Self.axFocusedTextArea(
            in: appElement,
            matchingValue: expectedText,
            containing: marker,
            elementIdentifier: target.context.elementIdentifier
        ) != nil else {
            recordCodexProofSnapshotFastPathMiss(stage: "snapshot", reason: "focused-text-area-not-found")
            return false
        }

        return true
    }

    private func recordCodexProofSnapshotFastPathMiss(stage: String, reason: String) {
        DiagnosticsLog.shared.record(
            "codex-proof-snapshot-fast-path-miss",
            metadata: [
                "app": "com.openai.codex",
                "stage": stage,
                "reason": reason,
                "fieldIdentity": currentSuggestionState.fieldIdentity?.traceDescription ?? "",
                "requestMode": currentSuggestionState.requestMode?.rawValue ?? "",
                "proofModeEnabled": String(
                    activeAppProofBundleIdentifiers.contains(CodexProofFocusedTargetPolicy.bundleIdentifier)
                )
            ]
        )
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

    private func codexProofAcceptanceSnapshotMatchesShown(
        _ shownSnapshot: SuggestionAcceptanceSnapshot
    ) -> Bool {
        guard codexProofSnapshotMatchesCurrentSuggestion(),
              let currentSuggestionFieldIdentity = currentSuggestionState.fieldIdentity,
              let lastTextSnapshot,
              shownSnapshot.fieldIdentity == currentSuggestionFieldIdentity,
              shownSnapshot.fieldIdentity == lastTextSnapshot.fieldIdentity,
              shownSnapshot.textBeforeCursor == lastTextSnapshot.textBeforeCursor,
              shownSnapshot.textAfterCursor == lastTextSnapshot.textAfterCursor,
              shownSnapshot.selectedTextLength == 0 else {
            return false
        }

        return true
    }

    private func recordCodexProofSnapshotFastPath(stage: String) {
        guard let currentProfile,
              let currentSuggestionFieldIdentity = currentSuggestionState.fieldIdentity else {
            return
        }

        DiagnosticsLog.shared.record(
            "codex-proof-snapshot-fast-path",
            metadata: [
                "app": "com.openai.codex",
                "stage": stage,
                "fieldIdentity": currentSuggestionFieldIdentity.traceDescription,
                "requestMode": currentSuggestionState.requestMode?.rawValue ?? "",
                "promptSafetyMode": currentProfile.promptAppSafetyMode.rawValue
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
                "nativeUndoProofMode": String(acceptedInsertionUndoRecoveryMode == .nativeProofOnly),
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

    private func scheduleDeferredClaudeCodeTerminalHostProofNextWordAcceptance(
        acceptedText: String,
        acceptanceID: String,
        acceptedAt: Date,
        action: KeyboardAction,
        acceptanceProof: SuggestionAcceptanceProof,
        verificationBaseline: InsertionVerificationBaseline?
    ) -> Bool {
        guard ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_PROBE"] == "1",
              let profile = currentProfile,
              shouldUseClaudeCodeTerminalHostProofDirectInsertion(profile: profile, action: action),
              let frontmostApp = accessibilityClient.frontmostApplication(),
              frontmostApp.bundleIdentifier == "com.mitchellh.ghostty" else {
            return false
        }

        let scheduledSuggestionID = currentSuggestionState.id
        let scheduledFieldIdentity = currentSuggestionState.fieldIdentity
        let scheduledRequestMode = currentSuggestionState.requestMode
        let delayMilliseconds = deferredGhosttyInsertionProbeDelayMilliseconds()
        deferredTerminalHostAcceptanceTask?.cancel()
        suggestionPipeline.pausePolling(
            now: Date(),
            durationMilliseconds: delayMilliseconds + postInsertionPollPauseMilliseconds
        )
        keyboardEventTap?.suppressPassthroughObservation(for: TimeInterval(delayMilliseconds) / 1000.0 + 0.75)
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-deferred-accept",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "stage": "scheduled",
                "acceptedChars": String(acceptedText.count),
                "delayMilliseconds": String(delayMilliseconds),
                "suggestionID": scheduledSuggestionID ?? "",
                "requestMode": scheduledRequestMode?.rawValue ?? ""
            ]
        )

        deferredTerminalHostAcceptanceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(delayMilliseconds))
            guard !Task.isCancelled,
                  let self else {
                return
            }
            self.deferredTerminalHostAcceptanceTask = nil
            guard self.suggestionSession.hasVisibleSuggestion,
                  self.currentSuggestionState.id == scheduledSuggestionID,
                  self.currentSuggestionState.fieldIdentity == scheduledFieldIdentity,
                  self.currentSuggestionState.requestMode == scheduledRequestMode,
                  !self.currentSuggestionState.invalidatedByUserKeyDown else {
                self.recordDeferredClaudeCodeTerminalHostProofAcceptance(
                    stage: "aborted",
                    metadata: [
                        "reason": "suggestion-state-changed",
                        "suggestionID": scheduledSuggestionID ?? ""
                    ]
                )
                return
            }

            self.recordDeferredClaudeCodeTerminalHostProofAcceptance(
                stage: "insert-start",
                metadata: [
                    "acceptedChars": String(acceptedText.count),
                    "suggestionID": scheduledSuggestionID ?? ""
                ]
            )
            guard self.insertAcceptedText(acceptedText, action: action) else {
                self.suppressCurrentFieldAfterInsertionFailure(reason: "ghostty-deferred-insert-failed")
                self.recordDeferredClaudeCodeTerminalHostProofAcceptance(
                    stage: "insert-failed",
                    metadata: [
                        "acceptedChars": String(acceptedText.count),
                        "suggestionID": scheduledSuggestionID ?? ""
                    ]
                )
                self.setSuggestionDecision("Blocked: deferred Ghostty insert failed")
                self.hideSuggestion(reason: "ghostty-deferred-insert-failed")
                return
            }

            self.recordDeferredClaudeCodeTerminalHostProofAcceptance(
                stage: "insert-succeeded",
                metadata: [
                    "acceptedChars": String(acceptedText.count),
                    "suggestionID": scheduledSuggestionID ?? ""
                ]
            )
            self.completeNextWordAcceptance(
                acceptedText: acceptedText,
                acceptanceID: acceptanceID,
                acceptedAt: acceptedAt,
                action: action,
                acceptanceProof: acceptanceProof,
                verificationBaseline: verificationBaseline,
                residualReason: "Accepted: deferred Ghostty next word; showing remainder",
                emptyReason: "accepted-ghostty-deferred-next-word"
            )
        }
        return true
    }

    private func deferredGhosttyInsertionProbeDelayMilliseconds() -> Int {
        let configuredDelaySeconds = ProcessInfo.processInfo.environment[
            "AUTOCOMPLETE_LAB_GHOSTTY_DEFERRED_INSERTION_DELAY_SECONDS"
        ].flatMap(TimeInterval.init)
        let delaySeconds = min(3.0, max(0.02, configuredDelaySeconds ?? 0.12))
        return Int((delaySeconds * 1000).rounded())
    }

    private func recordDeferredClaudeCodeTerminalHostProofAcceptance(
        stage: String,
        metadata extraMetadata: [String: String] = [:]
    ) {
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-deferred-accept",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "stage": stage
            ].merging(extraMetadata) { current, _ in current }
        )
    }

    private func completeNextWordAcceptance(
        acceptedText: String,
        acceptanceID: String,
        acceptedAt: Date,
        action: KeyboardAction,
        acceptanceProof: SuggestionAcceptanceProof,
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
        suggestionOrchestrator.recordRepetitionAcceptance(
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
                "sameSliceUndoProof": "true",
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
                "sameSliceUndoProof": "true",
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
        acceptanceSurvivalTaskHost.cancel(acceptanceID: undo.acceptanceID)

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
                    "sameSliceUndoProof": "true",
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
        guard let baseline else { return }
        insertionVerificationHost.schedule(acceptedText: acceptedText, baseline: baseline)
    }

    func handleInsertionVerificationContextFailure(
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
        recordPersonalCaptureSuggestionEpisodeInsertionFailed(
            baseline: baseline,
            outcome: outcome,
            reason: "insert-verification-failed"
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
            if let context = codexProofInsertionVerificationContext(
                baseline: baseline,
                acceptedText: acceptedText,
                frontmostApp: nil,
                reason: "missing-frontmost-app"
            ) {
                return .ready(context: context)
            }
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
            if let context = codexProofInsertionVerificationContext(
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

        if codexProofInsertionVerificationContextIsReady(
            baseline: baseline,
            acceptedText: acceptedText,
            frontmostApp: frontmostApp,
            context: adjustedContext
        ) {
            return .ready(context: adjustedContext)
        }

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
            if let context = codexProofInsertionVerificationContext(
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
            if let context = codexProofInsertionVerificationContext(
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

    private func codexProofInsertionVerificationContextIsReady(
        baseline: InsertionVerificationBaseline,
        acceptedText: String,
        frontmostApp: RunningApplicationInfo,
        context: FocusedTextContext
    ) -> Bool {
        let bundleIdentifier = CodexProofFocusedTargetPolicy.bundleIdentifier
        let marker = CodexProofFocusedTargetPolicy.marker
        let replacementText = baseline.previousTextBeforeCursor + acceptedText + baseline.previousTextAfterCursor
        guard !acceptedText.isEmpty,
              baseline.profile.bundleIdentifier == bundleIdentifier,
              CodexProofFocusedTargetPolicy.allowsOneWordProofRequestMode(baseline.requestMode),
              allowsCodexProofInsertion(profile: baseline.profile),
              frontmostAppMatchesSuggestion(
                  frontmostApp,
                  expectedBundleIdentifier: bundleIdentifier,
                  profile: baseline.profile
              ),
              baseline.previousTextBeforeCursor.contains(marker),
              baseline.previousTextAfterCursor.isEmpty,
              context.textBeforeCursor == baseline.previousTextBeforeCursor + acceptedText,
              context.textAfterCursor == baseline.previousTextAfterCursor,
              context.selectedTextLength == 0,
              !context.isSecure else {
            return false
        }

        let snapshot = FocusedTextSnapshot(
            fieldIdentity: baseline.fieldIdentity,
            textBeforeCursor: baseline.previousTextBeforeCursor,
            textAfterCursor: baseline.previousTextAfterCursor
        )
        let currentFieldIdentity = fieldIdentity(
            app: frontmostApp,
            context: context,
            profile: baseline.profile
        )
        guard codexProofFocusedTargetPolicy.matches(
            app: frontmostApp,
            profile: baseline.profile,
            suggestionBundleIdentifier: baseline.profile.bundleIdentifier,
            requestMode: baseline.requestMode,
            expectedFieldIdentity: baseline.fieldIdentity,
            snapshot: snapshot,
            focusedContext: context,
            focusedFieldIdentity: currentFieldIdentity,
            proofModeEnabled: activeAppProofBundleIdentifiers.contains(bundleIdentifier),
            expectedFocusedText: replacementText
        ) else {
            return false
        }

        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        guard Self.axFocusedTextArea(
            in: appElement,
            matchingValue: replacementText,
            containing: marker,
            elementIdentifier: context.elementIdentifier
        ) != nil else {
            return false
        }

        DiagnosticsLog.shared.record(
            "codex-proof-verification-fast-path",
            metadata: [
                "app": bundleIdentifier,
                "acceptedChars": String(acceptedText.count),
                "currentBeforeChars": String(context.textBeforeCursor.count),
                "previousBeforeChars": String(baseline.previousTextBeforeCursor.count),
                "requestMode": baseline.requestMode?.rawValue ?? ""
            ]
        )
        return true
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
            guard activeAppProofBundleIdentifiers.contains(bundleIdentifier),
                  ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_OBSIDIAN_DIRECT_VALUE_INSERT"] == "1",
                  Self.obsidianProofDocumentConfirmsInsertion(expectedText: expectedText) else {
                return nil
            }

            DiagnosticsLog.shared.record(
                "obsidian-proof-document-insert-verification-fast-path",
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

    private func codexProofInsertionVerificationContext(
        baseline: InsertionVerificationBaseline,
        acceptedText: String,
        frontmostApp providedFrontmostApp: RunningApplicationInfo?,
        reason: String
    ) -> FocusedTextContext? {
        let bundleIdentifier = CodexProofFocusedTargetPolicy.bundleIdentifier
        let marker = CodexProofFocusedTargetPolicy.marker
        guard baseline.profile.bundleIdentifier == bundleIdentifier,
              allowsCodexProofInsertion(profile: baseline.profile),
              baseline.previousTextBeforeCursor.contains(marker),
              baseline.previousTextAfterCursor.isEmpty,
              !acceptedText.isEmpty else {
            return nil
        }

        let frontmostApp = providedFrontmostApp ?? accessibilityClient.frontmostApplication()
        guard let frontmostApp,
              frontmostApp.bundleIdentifier == bundleIdentifier,
              frontmostApp.processIdentifier == baseline.fieldIdentity.processIdentifier else {
            return nil
        }

        let expectedText = baseline.previousTextBeforeCursor + acceptedText + baseline.previousTextAfterCursor
        let snapshot = FocusedTextSnapshot(
            fieldIdentity: baseline.fieldIdentity,
            textBeforeCursor: baseline.previousTextBeforeCursor,
            textAfterCursor: baseline.previousTextAfterCursor
        )
        guard let target = codexProofFocusedTarget(
            app: frontmostApp,
            profile: baseline.profile,
            suggestionBundleIdentifier: baseline.profile.bundleIdentifier,
            requestMode: baseline.requestMode,
            expectedFieldIdentity: baseline.fieldIdentity,
            snapshot: snapshot,
            expectedFocusedText: expectedText,
            shownTargetFingerprint: baseline.targetFingerprint
        ) else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        guard Self.axFocusedTextArea(
            in: appElement,
            matchingValue: expectedText,
            containing: marker,
            elementIdentifier: target.context.elementIdentifier
        ) != nil else {
            return nil
        }

        DiagnosticsLog.shared.record(
            "codex-proof-insert-verification-fast-path",
            metadata: [
                "app": bundleIdentifier,
                "acceptedChars": String(acceptedText.count),
                "previousBeforeChars": String(baseline.previousTextBeforeCursor.count),
                "reason": reason
            ]
        )
        return target.context
    }

    private func startAcceptanceSurvivalTracking(_ tracker: AcceptanceSurvivalTracker) {
        acceptanceSurvivalTaskHost.schedule(
            acceptanceID: tracker.acceptanceID,
            start: { [weak self] in
                await self?.acceptanceSurvivalChecker.beginTracking(tracker)
            },
            measure: { [weak self] checkpoint in
                await self?.measureAcceptanceSurvival(
                    acceptanceID: tracker.acceptanceID,
                    checkpoint: checkpoint
                )
            }
        )
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
                acceptanceSurvivalTaskHost.finish(acceptanceID: acceptanceID)
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
            acceptanceSurvivalTaskHost.finish(acceptanceID: acceptanceID)
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
                    self.acceptanceSurvivalTaskHost.cancel(acceptanceID: result.tracker.acceptanceID)
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
        recordPersonalCaptureAcceptanceSurvival(result)
        recordPersonalCaptureSuggestionEpisodeSurvival(result, metadata: metadata)

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

    private func recordAcceptedAndKeptLearningIfNeeded(
        _ result: AcceptanceSurvivalCheckResult
    ) -> AcceptedAndKeptLearningSignal? {
        guard let requestMode = CompletionRequestMode(rawValue: result.tracker.requestMode) else {
            return nil
        }

        let outcome: AcceptedAndKeptLearningOutcome
        if result.shouldRecordAcceptedThenDeleted {
            outcome = .rejected
        } else if result.measurement.checkpoint.isTerminalMetricCheckpoint,
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
            appPreferencePersistenceHost.persistAcceptedTextStyleMemory()
        }
        appPreferencePersistenceHost.persistAcceptedAndKeptLearning()
        return signal
    }

    private func recordTypeThroughConfidenceCreditIfNeeded(
        _ survival: TypeThroughPrefixSurvival,
        appBundleIdentifier: String
    ) -> [String: String] {
        guard survival.qualifiesForConfidenceCredit,
              let suggestionID = currentSuggestionState.id,
              !typeThroughConfidenceCreditedSuggestionIDs.contains(suggestionID),
              let requestMode = currentSuggestionState.requestMode,
              let fieldKind = currentSuggestionState.fieldClassification?.kind,
              let behaviorProfileID = suggestionOrchestrator.currentRequest?.behaviorProfile.id else {
            return [:]
        }

        typeThroughConfidenceCreditedSuggestionIDs.insert(suggestionID)
        let signal = acceptedAndKeptLearning.record(
            .typeThroughSurvival,
            key: AcceptedAndKeptLearningKey(
                appBundleIdentifier: appBundleIdentifier,
                fieldKind: fieldKind,
                requestMode: requestMode,
                behaviorProfileID: behaviorProfileID
            )
        )
        appPreferencePersistenceHost.persistAcceptedAndKeptLearning()
        var metadata = signal.traceMetadata
        metadata["typeThroughConfidenceCredited"] = "true"
        return metadata
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
        recordPersonalCaptureSuggestionEpisodeInsertionFailed(
            baseline: baseline,
            outcome: reason.rawValue,
            reason: "insert-verification-failed"
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
        visiblePageContext: VisiblePageContext?,
        triggerReason: String = "poll"
    ) {
        cancelPrefixCooldownRetry()
        cancelPendingSuggestionTask(reason: "new-request")
        lastRequestedTextBeforeCursor = context.textBeforeCursor

        let acceptedTextStyleKey = suggestionOrchestrator.acceptedTextStyleKey(
            appBundleIdentifier: appBundleIdentifier,
            fieldKind: fieldClassification.kind,
            textBeforeCursor: context.textBeforeCursor
        )
        let acceptedTextStyleSketch = acceptedTextStyleMemory.sketch(
            for: acceptedTextStyleKey
        )
        let personalization = personalizationCoordinator.selection(isEnabled: appSettings.personalCaptureEnabled, context: context, appBundleIdentifier: appBundleIdentifier, fieldClassification: fieldClassification, requestMode: requestMode)
        let orchestration = suggestionOrchestrator.beginRequest(SuggestionRequestInput(
            context: context,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentity,
            fieldClassification: fieldClassification,
            acceptedTextStyleSketch: acceptedTextStyleSketch,
            personalContext: personalization.context,
            personalWritingMemory: personalization.memory,
            visiblePageContext: visiblePageContext,
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
        let requestSchedule = suggestionTriggerTimingPolicy.schedule(
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

        let disablesFastWordCompletionForProof = runtimeProofOptions.disablesFastWordCompletion(
            appBundleIdentifier: appBundleIdentifier,
            activeProofBundleIdentifiers: activeAppProofBundleIdentifiers
        )
        let disablesWordCompletionForProof = runtimeProofOptions.disablesWordCompletion(
            appBundleIdentifier: appBundleIdentifier,
            activeProofBundleIdentifiers: activeAppProofBundleIdentifiers
        )
        let disablesPhraseContinuationForProof = runtimeProofOptions.disablesPhraseContinuation(
            appBundleIdentifier: appBundleIdentifier,
            activeProofBundleIdentifiers: activeAppProofBundleIdentifiers
        )
        let disablesFastPhraseFallbackForProof = runtimeProofOptions.disablesFastPhraseFallback(
            appBundleIdentifier: appBundleIdentifier,
            activeProofBundleIdentifiers: activeAppProofBundleIdentifiers
        )

        if requestMode == .wordCompletion,
           disablesWordCompletionForProof {
            DiagnosticsLog.shared.record(
                "word-completion-disabled",
                metadata: [
                    "app": appBundleIdentifier,
                    "reason": RuntimeProofOptions.disableWordCompletionEnvironmentKey
                ]
            )
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: suggestionID,
                appBundleIdentifier: appBundleIdentifier,
                fieldIdentity: fieldIdentityDescription,
                requestMode: request.mode.rawValue,
                triggerReason: "proof-word-completion-disabled",
                textBeforeCursor: request.textBeforeCursor,
                textAfterCursor: request.textAfterCursor,
                reason: "proof-word-completion-disabled",
                metadata: [
                    "renderMode": renderMode.rawValue,
                    "proofDisableReason": RuntimeProofOptions.disableWordCompletionEnvironmentKey
                ]
                .merging(requestMetadata) { current, _ in current }
            )
            recordSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                metadata: [
                    "reason": "proof-word-completion-disabled"
                ]
            )
            setSuggestionDecision("Blocked: proof word completion disabled")
            hideSuggestion()
            return
        }

        if requestMode == .wordCompletion,
           !disablesFastWordCompletionForProof {
            let candidateWords = recentWordMemory.words(for: appBundleIdentifier)
                + (visiblePageContext?.completionCandidateWords ?? [])
            let allowPredictiveFallback = shouldUsePredictiveWordFallback(
                profile: profile,
                visiblePageContext: visiblePageContext
            )
            let fastSelection = suggestionOrchestrator.fastWordSelection(
                for: context.textBeforeCursor,
                recentWords: candidateWords,
                allowPredictiveFallback: allowPredictiveFallback
            )
            let fastSelectionMetadata = fastSelection.traceMetadata
                .merging(timingLane.traceMetadata) { current, _ in current }
            if let fastSuggestion = fastSelection.suggestion {
                guard !suggestionOrchestrator.shouldSuppressRepetition(
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
            if shouldAskModelForWordCompletionFallback(visiblePageContext: visiblePageContext) {
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
        } else if requestMode == .wordCompletion,
                  disablesFastWordCompletionForProof {
            DiagnosticsLog.shared.record(
                "fast-word-completion-disabled",
                metadata: [
                    "app": appBundleIdentifier,
                    "reason": RuntimeProofOptions.disableFastWordCompletionEnvironmentKey
                ]
            )
            setSuggestionDecision("Queued: proof model word completion")
        }

        if requestMode == .phraseContinuation,
           disablesPhraseContinuationForProof {
            DiagnosticsLog.shared.record(
                "phrase-continuation-disabled",
                metadata: [
                    "app": appBundleIdentifier,
                    "reason": RuntimeProofOptions.disablePhraseContinuationEnvironmentKey
                ]
            )
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: suggestionID,
                appBundleIdentifier: appBundleIdentifier,
                fieldIdentity: fieldIdentityDescription,
                requestMode: request.mode.rawValue,
                triggerReason: "proof-phrase-continuation-disabled",
                textBeforeCursor: request.textBeforeCursor,
                textAfterCursor: request.textAfterCursor,
                reason: "proof-phrase-continuation-disabled",
                metadata: [
                    "renderMode": renderMode.rawValue,
                    "proofDisableReason": RuntimeProofOptions.disablePhraseContinuationEnvironmentKey
                ]
                .merging(requestMetadata) { current, _ in current }
            )
            recordSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                metadata: [
                    "reason": "proof-phrase-continuation-disabled"
                ]
            )
            setSuggestionDecision("Blocked: proof phrase continuation disabled")
            hideSuggestion()
            return
        }

        var fastPhraseFallbackMetadata: [String: String] = [:]
        var didPresentFastPhraseFallback = false
        if requestMode == .phraseContinuation,
           !disablesFastPhraseFallbackForProof {
            let allowsClaudeCodeProofPromptPrediction =
                appBundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier
                && fieldClassification == ClaudeCodeTerminalHostProofPolicy.proofFieldClassification
            let allowsPredictivePhraseFallback =
                allowsClaudeCodeProofPromptPrediction
                || shouldUsePredictivePhraseFallback(
                    profile: profile,
                    behaviorProfileID: request.behaviorProfileID,
                    visiblePageContext: visiblePageContext
                )
            let fastSelection = suggestionOrchestrator.fastPhraseSelection(
                for: context.textBeforeCursor,
                docLocalContextTexts: orchestration.docLocalContextTexts,
                personalWritingMemory: orchestration.personalWritingMemory,
                behaviorProfileID: request.behaviorProfileID,
                maxVisibleWords: request.maxVisibleWords,
                allowPredictiveFallback: allowsPredictivePhraseFallback,
                allowPromptAppPrediction: allowsClaudeCodeProofPromptPrediction
            )
            let fastSelectionMetadata = fastSelection.traceMetadata
                .merging(timingLane.traceMetadata) { current, _ in current }
            if let fastSuggestion = fastSelection.suggestion {
                guard !suggestionOrchestrator.shouldSuppressRepetition(
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

                let acceptedAndKeptSignal = acceptedAndKeptSignal(
                    request: request,
                    fieldClassification: fieldClassification,
                    profile: profile
                )
                let learningDecision = suggestionOrchestrator.fastPhraseFallbackLearningDecision(
                    acceptedAndKeptSignal: acceptedAndKeptSignal,
                    probabilityThreshold: acceptedAndKeptLearning.probabilityThreshold(for: request.mode)
                )
                let fastPresentationMetadata = fastSelectionMetadata
                    .merging(learningDecision.metadata) { current, _ in current }
                if learningDecision.shouldSuppress {
                    let reason = learningDecision.reason ?? "fast-phrase-learning-restraint"
                    fastPhraseFallbackMetadata = [
                        "fastPhraseFallbackChecked": "true",
                        "fastPhraseFallbackOutcome": reason
                    ]
                    .merging(fastPresentationMetadata) { current, _ in current }
                    RawAutocompleteTraceLog.shared.record(
                        type: .suggestionSuppressed,
                        suggestionID: suggestionID,
                        appBundleIdentifier: appBundleIdentifier,
                        fieldIdentity: fieldIdentityDescription,
                        requestMode: request.mode.rawValue,
                        triggerReason: "canned-bridge",
                        textBeforeCursor: request.textBeforeCursor,
                        textAfterCursor: request.textAfterCursor,
                        latencyMilliseconds: 0,
                        reason: reason,
                        metadata: [
                            "renderMode": renderMode.rawValue
                        ]
                        .merging(fastPresentationMetadata) { current, _ in current }
                        .merging(requestMetadata) { current, _ in current }
                    )
                    recordSuggestionEvent(
                        "suggestion-blocked",
                        context: context,
                        profile: profile,
                        metadata: [
                            "reason": reason,
                            "triggerReason": "canned-bridge"
                        ]
                        .merging(learningDecision.metadata) { current, _ in current }
                    )
                    setSuggestionDecision(SuggestionStatusText.notShown(reason: reason))
                } else {
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
        } else if requestMode == .phraseContinuation,
                  disablesFastPhraseFallbackForProof {
            DiagnosticsLog.shared.record(
                "fast-phrase-fallback-disabled",
                metadata: [
                    "app": appBundleIdentifier,
                    "reason": RuntimeProofOptions.disableFastPhraseFallbackEnvironmentKey
                ]
            )
            setSuggestionDecision("Queued: proof model phrase continuation")
        }

        if typingBurstDecision.shouldSuppress(requestMode: requestMode) {
            if didPresentFastPhraseFallback {
                suggestionIdleRetryState.cancel()
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
            suggestionIdleRetryState.noteTypingBurstSuppression(
                snapshot: FocusedTextSnapshot(
                    fieldIdentity: fieldIdentity,
                    textBeforeCursor: context.textBeforeCursor,
                    textAfterCursor: context.textAfterCursor
                ),
                nowMilliseconds: Int(ProcessInfo.processInfo.systemUptime * 1_000),
                settleDelayMilliseconds: triggerPolicy(for: profile).pauseDelayMilliseconds
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
        suggestionIdleRetryState.cancel()
        suggestionRequestScheduler.schedule(
            suggestionID: suggestionID,
            delayMilliseconds: requestSchedule.scheduledDelayMilliseconds
        ) { [suggestionOrchestrator, requestTicket, fieldIdentity, requestSchedule] in
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
                                  !self.suggestionOrchestrator.shouldSuppressRepetition(
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

                    if self.suggestionTriggerTimingPolicy.shouldSuppressResult(
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
                    guard !self.suggestionOrchestrator.shouldSuppressRepetition(
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
            } catch {
                await MainActor.run {
                    self.suggestionOrchestrator.finishStreamingPresentation(suggestionID: suggestionID)
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
        scheduledDelayMilliseconds: Int = 0,
        presentationRefreshAttempt: Int = 0
    ) {
        let originalContext = context
        let invalidatedByVisibleUserTyping = currentSuggestionState.invalidatedByUserKeyDown
            && currentSuggestionState.id == suggestionID
        let cooldownDelayMilliseconds = refreshBeforePresenting
            ? codexPromptAXCooldownPresentationDelayMilliseconds(
                profile: profile,
                fieldIdentity: fieldIdentity
            )
            : 0
        let refreshedContext: (context: FocusedTextContext?, reason: String?)
        switch codexPromptTargetContinuityHost.presentationPreparationPolicy.preparation(
            refreshBeforePresenting: refreshBeforePresenting,
            cooldownDelayMilliseconds: cooldownDelayMilliseconds
        ) {
        case let .deferForAXCooldown(delayMilliseconds):
            scheduleCodexPromptPresentationAfterAXCooldown(
                suggestion,
                suggestionID: suggestionID,
                request: request,
                context: originalContext,
                profile: profile,
                fieldIdentity: fieldIdentity,
                renderMode: renderMode,
                latencyMilliseconds: latencyMilliseconds,
                triggerReason: triggerReason,
                requestTicket: requestTicket,
                candidateSelectionMetadata: candidateSelectionMetadata,
                scheduledDelayMilliseconds: scheduledDelayMilliseconds,
                presentationRefreshAttempt: presentationRefreshAttempt,
                delayMilliseconds: delayMilliseconds
            )
            return
        case .refreshFocusedContext:
            refreshedContext = refreshedPresentationContext(
                for: request,
                requestContext: context,
                profile: profile,
                fieldIdentity: fieldIdentity
            )
        case .useOriginalContext:
            refreshedContext = (context: context, reason: nil)
        }
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
            let refreshReason = refreshedContext.reason ?? "stale-focused-context"
            if refreshReason == "transient-codex-prompt-target",
               let retry = codexPromptTargetContinuityHost.presentationRefreshRetryPolicy.next(
                after: presentationRefreshAttempt
               ) {
                scheduleCodexPromptPresentationRefreshRetry(
                    suggestion,
                    suggestionID: suggestionID,
                    request: request,
                    context: originalContext,
                    profile: profile,
                    fieldIdentity: fieldIdentity,
                    renderMode: renderMode,
                    latencyMilliseconds: latencyMilliseconds,
                    triggerReason: triggerReason,
                    requestTicket: requestTicket,
                    candidateSelectionMetadata: candidateSelectionMetadata,
                    scheduledDelayMilliseconds: scheduledDelayMilliseconds,
                    retry: retry
                )
                return
            }
            let reason = refreshReason == "transient-codex-prompt-target"
                ? "stale-prompt-target"
                : refreshReason
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

        let requestSnapshot = FocusedTextSnapshot(
            fieldIdentity: fieldIdentity,
            textBeforeCursor: request.textBeforeCursor,
            textAfterCursor: request.textAfterCursor
        )
        let currentSnapshot = FocusedTextSnapshot(
            fieldIdentity: fieldIdentity,
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor
        )
        let typedSinceRequest: String
        switch LateResultContextValidator().validate(
            requestSnapshot: requestSnapshot,
            currentSnapshot: currentSnapshot,
            latencyMilliseconds: latencyMilliseconds
        ) {
        case let .stillValid(typedDelta):
            typedSinceRequest = typedDelta
        case let .invalid(reason):
            hideSuggestion(reason: "late-result-\(reason.rawValue)")
            return
        }
        guard let suggestion = LateResultContextValidator().trimmedSuggestion(
            suggestion,
            typedSinceRequest: typedSinceRequest
        ) else {
            hideSuggestion(reason: "typed-through-visible-prefix")
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
        let acceptedAndKeptSignal = acceptedAndKeptSignal(
            request: request,
            fieldClassification: displayFieldClassification,
            profile: profile
        )
        let isRepeatedMiss = suggestionOrchestrator.shouldSuppressRepetition(
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
            acceptedAndKeptSignal: acceptedAndKeptSignal,
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
        switch suggestionChromeHost.presentationDelivery.deliver(presentationDeliveryRequest) {
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
        currentSuggestionState.optimisticOriginalDisplayedText = suggestion.visibleText
        currentSuggestionState.optimisticTypedPrefix = ""
        currentSuggestionState.fieldClassification = displayFieldClassification
        currentSuggestionState.presentedAt = presentedAt
        currentSuggestionState.displayScoreFinal = displayScoreTrace.score.finalScore
        currentSuggestionState.invalidatedByUserKeyDown = false
        cacheProofOnlyAcceptRecentSuggestionIfNeeded(
            suggestion: suggestion,
            suggestionID: suggestionID,
            appBundleIdentifier: currentSuggestionState.appBundleIdentifier ?? profile.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            requestMode: request.mode,
            textBeforeCursor: request.textBeforeCursor,
            acceptanceSnapshot: acceptanceSnapshot,
            displayedText: suggestion.visibleText,
            fieldClassification: displayFieldClassification,
            presentedAt: presentedAt,
            displayScoreFinal: displayScoreTrace.score.finalScore
        )
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
        let presentationTracePayload = suggestionChromeHost.presentationDelivery.tracePayload(
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
            screenshotPathAuthorized: screenshotCapture.screenshotPathAuthorized,
            metadata: presentationTracePayload.rawTraceMetadata
        )
        recordPersonalCaptureSuggestionEpisodePresented(
            suggestionID: suggestionID,
            request: request,
            context: context,
            profile: profile,
            fieldIdentity: fieldIdentity,
            fieldClassification: rawDisplayFieldClassification,
            suggestion: suggestion,
            latencyMilliseconds: latencyMilliseconds,
            triggerReason: triggerReason,
            placement: deliveredPlacement,
            panelRect: panelRect,
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

    private func scheduleCodexPromptPresentationRefreshRetry(
        _ suggestion: CompletionSuggestion,
        suggestionID: String,
        request: CompletionRequest,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        renderMode: SuggestionRenderMode,
        latencyMilliseconds: Int,
        triggerReason: String,
        requestTicket: SuggestionRequestTicket?,
        candidateSelectionMetadata: [String: String],
        scheduledDelayMilliseconds: Int,
        retry: CodexPromptPresentationRefreshRetry
    ) {
        setSuggestionDecision("Waiting: Codex prompt refresh")
        suggestionChromeHost.hideFieldStatusIndicator()
        DiagnosticsLog.shared.record(
            "codex-prompt-target-refresh-retry-scheduled",
            metadata: [
                "app": profile.bundleIdentifier,
                "attempt": String(retry.attempt),
                "delayMilliseconds": String(retry.delayMilliseconds),
                "beforeChars": String(request.textBeforeCursor.count),
                "afterChars": String(request.textAfterCursor.count)
            ]
        )
        codexPromptPresentationRetryHost.schedule(afterMilliseconds: retry.delayMilliseconds) { [weak self] in
            guard let self else {
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
                latencyMilliseconds: latencyMilliseconds + retry.delayMilliseconds,
                triggerReason: triggerReason,
                requestTicket: requestTicket,
                candidateSelectionMetadata: candidateSelectionMetadata,
                refreshBeforePresenting: true,
                scheduledDelayMilliseconds: scheduledDelayMilliseconds,
                presentationRefreshAttempt: retry.attempt
            )
        }
    }

    private func scheduleCodexPromptPresentationAfterAXCooldown(
        _ suggestion: CompletionSuggestion,
        suggestionID: String,
        request: CompletionRequest,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        renderMode: SuggestionRenderMode,
        latencyMilliseconds: Int,
        triggerReason: String,
        requestTicket: SuggestionRequestTicket?,
        candidateSelectionMetadata: [String: String],
        scheduledDelayMilliseconds: Int,
        presentationRefreshAttempt: Int,
        delayMilliseconds: Int
    ) {
        setSuggestionDecision("Waiting: Codex AX cooldown")
        suggestionChromeHost.hideFieldStatusIndicator()
        DiagnosticsLog.shared.record(
            "codex-prompt-presentation-deferred-for-ax-cooldown",
            metadata: [
                "app": profile.bundleIdentifier,
                "delayMilliseconds": String(delayMilliseconds),
                "beforeChars": String(request.textBeforeCursor.count),
                "afterChars": String(request.textAfterCursor.count)
            ]
        )
        codexPromptPresentationRetryHost.schedule(afterMilliseconds: delayMilliseconds) { [weak self] in
            guard let self else {
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
                latencyMilliseconds: latencyMilliseconds + delayMilliseconds,
                triggerReason: triggerReason,
                requestTicket: requestTicket,
                candidateSelectionMetadata: candidateSelectionMetadata,
                refreshBeforePresenting: true,
                scheduledDelayMilliseconds: scheduledDelayMilliseconds,
                presentationRefreshAttempt: presentationRefreshAttempt
            )
        }
    }

    private func codexPromptAXCooldownPresentationDelayMilliseconds(
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity
    ) -> Int {
        let app = RunningApplicationInfo(
            bundleIdentifier: profile.bundleIdentifier,
            localizedName: profile.displayName,
            processIdentifier: fieldIdentity.processIdentifier
        )
        let canPreserve = codexPromptTargetContinuityHost.canPreserveDuringAXCooldown(
            app: app,
            currentFieldIdentity: currentFieldIdentity,
            currentSnapshot: lastTextSnapshot,
            hasActiveSuggestionWork: true
        )
        guard canPreserve else {
            return 0
        }

        return codexPromptTargetContinuityHost.remainingAXCooldownMilliseconds()
    }

    private func refreshedPresentationContext(
        for request: CompletionRequest,
        requestContext: FocusedTextContext,
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
            for: frontmostApp,
            allowDescendantTextFallback: profile.allowsDescendantTextFallback,
            options: FocusedTextReadOptionsPolicy.options(for: frontmostApp, profile: profile)
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

        let promptMatch = promptTextAreaMatch(
            for: frontmostApp.bundleIdentifier,
            context: rawContext
        )
        if !promptMatch.canSuggest {
            let requestMatchesCurrentSnapshot = lastTextSnapshot?.fieldIdentity == fieldIdentity
                && lastTextSnapshot?.textBeforeCursor == request.textBeforeCursor
                && lastTextSnapshot?.textAfterCursor == request.textAfterCursor
            let resolution = requestMatchesCurrentSnapshot
                ? codexPromptTargetContinuityHost.presentationRefreshResolution(
                    app: frontmostApp,
                    promptBlockReason: promptMatch.reason,
                    currentFieldIdentity: currentFieldIdentity,
                    currentSnapshot: lastTextSnapshot,
                    observedContext: rawContext,
                    trustedContext: requestContext
                )
                : .reject
            guard resolution != .reject else {
                return (nil, "stale-prompt-target")
            }
            if resolution == .cancelAndRetry {
                cancelAndRearmCodexPromptTargetWork(
                    app: frontmostApp,
                    context: rawContext,
                    profile: profile,
                    promptBlockReason: promptMatch.reason,
                    source: "presentation-refresh"
                )
                return (nil, "quarantined-codex-prompt-target")
            }

            DiagnosticsLog.shared.record(
                resolution == .reuseTrustedTextAreaContext
                    ? "codex-prompt-target-bounds-reused"
                    : "codex-prompt-target-refresh-retry-needed",
                metadata: [
                    "app": frontmostApp.bundleIdentifier,
                    "reason": promptMatch.reason,
                    "role": rawContext.role ?? "unknown",
                    "beforeChars": String(rawContext.textBeforeCursor.count),
                    "afterChars": String(rawContext.textAfterCursor.count)
                ]
            )
            return resolution == .reuseTrustedTextAreaContext
                ? (requestContext, nil)
                : (nil, "transient-codex-prompt-target")
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
            if !canTrustPromptProofFieldIdentityRefresh(
                requestFieldIdentity: fieldIdentity,
                refreshedFieldIdentity: refreshedFieldIdentity,
                profile: profile
            ) {
                return (nil, "stale-field")
            }
            DiagnosticsLog.shared.record(
                "prompt-proof-field-identity-refresh-relaxed",
                metadata: [
                    "app": profile.bundleIdentifier,
                    "requestFieldIdentity": fieldIdentity.traceDescription,
                    "refreshedFieldIdentity": refreshedFieldIdentity.traceDescription
                ]
            )
        }

        return (context, nil)
    }

    private func canTrustPromptProofFieldIdentityRefresh(
        requestFieldIdentity: FocusedFieldIdentity,
        refreshedFieldIdentity: FocusedFieldIdentity,
        profile: CompatibilityProfile
    ) -> Bool {
        promptProofFieldIdentityRefreshPolicy.canTrustRefresh(
            requestFieldIdentity: requestFieldIdentity,
            refreshedFieldIdentity: refreshedFieldIdentity,
            profile: profile,
            proofModeEnabled: activeAppProofBundleIdentifiers.contains(profile.bundleIdentifier),
            allowsFullAcceptNoSubmitProofProfile: isCodexFullAcceptNoSubmitProofProfile(profile)
        )
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

    private func refreshVisiblePageContextIfNeeded(
        context: FocusedTextContext,
        app: RunningApplicationInfo,
        textChanged: Bool
    ) {
        visiblePageContextProvider.refreshIfNeeded(
            for: context,
            app: app,
            enabled: visiblePageContextEnabled,
            allowsFreshCacheRefresh: textChanged
        )
    }

    private func cachedVisiblePageContext(
        context: FocusedTextContext,
        appBundleIdentifier: String
    ) -> VisiblePageContext? {
        guard visiblePageContextEnabled else {
            return nil
        }

        return visiblePageContextProvider.cachedContext(
            for: context,
            appBundleIdentifier: appBundleIdentifier
        )
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

    private func recordPersonalCaptureSnapshot(
        context: FocusedTextContext,
        app: RunningApplicationInfo,
        fieldIdentity: FocusedFieldIdentity,
        fieldClassification: AXFieldClassification,
        snapshot: FocusedTextSnapshot,
        source: String
    ) {
        guard appSettings.personalCaptureEnabled else {
            personalCaptureLastSnapshot = nil
            return
        }

        let decision = personalCapturePolicy.decision(for: PersonalCaptureInput(
            bundleIdentifier: app.bundleIdentifier,
            role: context.role,
            subrole: context.subrole,
            fingerprint: context.fingerprint,
            isSecure: context.isSecure,
            fieldClassification: fieldClassification
        ))

        guard decision.canCapture else {
            personalCaptureLastSnapshot = nil
            DiagnosticsLog.shared.record(
                "personal-capture-blocked",
                metadata: decision.metadata.merging([
                    "app": app.bundleIdentifier,
                    "source": source,
                    "textBeforeCursorChars": String(context.textBeforeCursor.count),
                    "textAfterCursorChars": String(context.textAfterCursor.count)
                ]) { current, _ in current }
            )
            return
        }

        personalCaptureJournal.recordSnapshotChange(
            previous: personalCaptureLastSnapshot,
            current: snapshot,
            context: personalCaptureContext(
                app: app,
                fieldIdentity: fieldIdentity,
                fieldClassification: fieldClassification,
                source: source
            )
        )
        personalCaptureLastSnapshot = snapshot
    }

    private func personalCaptureContext(
        app: RunningApplicationInfo,
        fieldIdentity: FocusedFieldIdentity,
        fieldClassification: AXFieldClassification,
        source: String
    ) -> PersonalCaptureJournalContext {
        PersonalCaptureJournalContext(
            appDisplayName: app.localizedName,
            appBundleIdentifier: app.bundleIdentifier,
            fieldIdentity: fieldIdentity.traceDescription,
            fieldKind: fieldClassification.kind,
            fieldKindReason: fieldClassification.reason,
            source: source
        )
    }

    private func recordPersonalCaptureSuggestionEpisodePresented(
        suggestionID: String,
        request: CompletionRequest,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        fieldClassification: AXFieldClassification,
        suggestion: CompletionSuggestion,
        latencyMilliseconds: Int,
        triggerReason: String,
        placement: PlacementHealthPresentation,
        panelRect: CGRect,
        screenshotPath: String,
        metadata: [String: String]
    ) {
        guard appSettings.personalCaptureEnabled,
              !suggestionID.isEmpty else {
            return
        }

        let decision = personalCapturePolicy.decision(for: PersonalCaptureInput(
            bundleIdentifier: request.appBundleIdentifier ?? profile.bundleIdentifier,
            role: context.role,
            subrole: context.subrole,
            fingerprint: context.fingerprint,
            isSecure: context.isSecure,
            fieldClassification: fieldClassification
        ))
        guard decision.canCapture else {
            DiagnosticsLog.shared.record(
                "personal-capture-episode-blocked",
                metadata: decision.metadata.merging([
                    "app": request.appBundleIdentifier ?? profile.bundleIdentifier,
                    "source": "suggestion-presented"
                ]) { current, _ in current }
            )
            return
        }

        let runtimeMetadata = modelRuntimeBundle.diagnosticsMetadata
        let candidateSource = metadata["candidateSelectionSource"] ?? triggerReason
        let replyContext = request.visiblePageContext.flatMap(SuggestionEpisodeReplyContext.init(visiblePageContext:))
        let record = SuggestionEpisodeRecord(
            id: suggestionID,
            createdAt: PersonalCaptureEpisodeStore.timestampString(from: Date()),
            appDisplayName: profile.displayName,
            appBundleIdentifier: request.appBundleIdentifier ?? profile.bundleIdentifier,
            fieldIdentity: fieldIdentity.traceDescription,
            fieldKind: fieldClassification.kind.rawValue,
            fieldKindReason: fieldClassification.reason,
            requestMode: request.mode.rawValue,
            userTypedContext: request.textBeforeCursor,
            textAfterCursor: request.textAfterCursor,
            replyContext: replyContext,
            replayContext: request.visiblePageContext.map { SuggestionEpisodeReplayContext(visiblePageContext: $0, fingerprintSecret: tracePrivacySecretStore.secret(), includeText: true) },
            suggestedText: suggestion.visibleText,
            model: SuggestionEpisodeModelContext(
                modelName: runtimeMetadata["model"] ?? CompletionModelPolicy.mvp.model.rawValue,
                runtime: runtimeMetadata["activeCandidate"] ?? "unknown",
                asset: runtimeMetadata["asset"] ?? "unknown",
                promptVersion: runtimeMetadata["promptStyle"] ?? CompletionPromptBuilder.promptStyleIdentifier,
                experimentArm: runtimeMetadata["experimentArm"] ?? "",
                triggerReason: triggerReason,
                candidateSource: candidateSource,
                latencyMilliseconds: latencyMilliseconds,
                firstTokenLatencyMilliseconds: Int(metadata["firstTokenLatencyMilliseconds"] ?? "")
            ),
            placement: SuggestionEpisodePlacementContext(
                renderMode: placement.renderMode.rawValue,
                anchorRect: compactRectDescription(placement.anchorRect),
                textLineRect: placement.textLineRect.map(compactRectDescription) ?? "none",
                panelRect: compactRectDescription(panelRect),
                confidenceBand: metadata["placementConfidenceBand"] ?? "",
                screenshotCaptured: !screenshotPath.isEmpty
            ),
            metadata: [
                "candidateSource": candidateSource,
                "triggerReason": triggerReason,
                "visibleChars": String(suggestion.visibleText.count),
                "visibleWords": String(suggestion.visibleWordCount)
            ]
            .merging(metadata) { current, _ in current }
        )

        personalCaptureEpisodes.recordPresented(record)
    }

    private func recordPersonalCaptureSuggestionEpisodeAction(
        suggestionID: String,
        appBundleIdentifier: String,
        outcome: SuggestionEpisodeOutcome,
        reason: String,
        acceptedText: String = "",
        metadata: [String: String] = [:]
    ) {
        guard appSettings.personalCaptureEnabled,
              !suggestionID.isEmpty else {
            return
        }

        personalCaptureEpisodes.recordAction(
            suggestionID: suggestionID,
            appBundleIdentifier: appBundleIdentifier,
            outcome: outcome,
            reason: reason,
            acceptedText: acceptedText,
            metadata: metadata
        )
    }

    private func recordPersonalCaptureSuggestionEpisodeInsertionFailed(
        baseline: InsertionVerificationBaseline,
        outcome: String,
        reason: String
    ) {
        recordPersonalCaptureSuggestionEpisodeAction(
            suggestionID: baseline.suggestionID ?? "",
            appBundleIdentifier: baseline.profile.bundleIdentifier,
            outcome: .insertionFailed,
            reason: reason,
            metadata: [
                "acceptanceID": baseline.acceptanceID,
                "acceptMode": baseline.acceptMode,
                "fieldKind": baseline.fieldKind.rawValue,
                "fieldKindReason": baseline.fieldKindReason,
                "behaviorProfile": baseline.behaviorProfileID.rawValue,
                "insertionResult": outcome
            ]
        )
    }

    private func recordPersonalCaptureSuggestionEpisodeSurvival(
        _ result: AcceptanceSurvivalCheckResult,
        metadata: [String: String]
    ) {
        guard appSettings.personalCaptureEnabled,
              !result.tracker.suggestionID.isEmpty else {
            return
        }

        personalCaptureEpisodes.recordSurvival(
            suggestionID: result.tracker.suggestionID,
            appBundleIdentifier: result.tracker.appBundleIdentifier,
            acceptedText: result.tracker.acceptedText,
            checkpoint: result.measurement.checkpoint.rawValue,
            survivalClass: result.measurement.survivalClass.rawValue,
            tokenRecall: result.measurement.tokenRecall,
            normalizedEditDistance: result.measurement.normalizedEditDistance,
            metadata: metadata
        )
    }

    private func personalCaptureEpisodeOutcome(
        hiddenOutcome outcome: String,
        reason: String
    ) -> SuggestionEpisodeOutcome {
        if reason == "escape" {
            return .dismissed
        }
        if outcome == "accepted" {
            return .unknown
        }
        if outcome == "typed-over" || reason == "typed-over" {
            return .typedPast
        }
        if outcome == "typed-through" {
            return .typedPast
        }
        if reason.contains("failed") || reason.contains("unsafe") {
            return .insertionFailed
        }
        if outcome == "ignored" {
            return .ignored
        }
        return .unknown
    }

    private func recordPersonalCaptureAcceptedSuggestion(
        acceptedText: String,
        baseline: InsertionVerificationBaseline
    ) {
        guard appSettings.personalCaptureEnabled,
              !acceptedText.isEmpty,
              !baseline.fieldKind.suppressesSuggestionsByDefault else {
            return
        }

        personalCaptureJournal.recordAcceptedSuggestion(
            acceptedText: acceptedText,
            context: PersonalCaptureJournalContext(
                appDisplayName: baseline.profile.displayName,
                appBundleIdentifier: baseline.profile.bundleIdentifier,
                fieldIdentity: baseline.fieldIdentity.traceDescription,
                fieldKind: baseline.fieldKind,
                fieldKindReason: baseline.fieldKindReason,
                source: "insertion-verified"
            ),
            suggestionID: baseline.suggestionID ?? "",
            acceptanceID: baseline.acceptanceID,
            acceptMode: baseline.acceptMode
        )
    }

    private func recordPersonalCaptureAcceptanceSurvival(_ result: AcceptanceSurvivalCheckResult) {
        guard appSettings.personalCaptureEnabled,
              result.shouldRecordAcceptedAndKept || result.shouldRecordAcceptedThenDeleted,
              !result.tracker.acceptedText.isEmpty,
              !result.tracker.fieldKind.suppressesSuggestionsByDefault else {
            return
        }

        personalCaptureJournal.recordAcceptanceSurvival(
            acceptedText: result.tracker.acceptedText,
            context: PersonalCaptureJournalContext(
                appDisplayName: result.tracker.profile.displayName,
                appBundleIdentifier: result.tracker.appBundleIdentifier,
                fieldIdentity: result.tracker.fieldIdentity.traceDescription,
                fieldKind: result.tracker.fieldKind,
                fieldKindReason: result.tracker.fieldKindReason,
                source: "acceptance-survival"
            ),
            suggestionID: result.tracker.suggestionID,
            acceptanceID: result.tracker.acceptanceID,
            acceptMode: result.tracker.acceptMode,
            checkpoint: result.measurement.checkpoint.rawValue,
            survivalClass: result.measurement.survivalClass.rawValue,
            isStrongPositive: result.measurement.isStrongAcceptedAndKept
                || result.measurement.isFinalAcceptedAndKept
        )
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

    func insertionRetrySkippedModes(
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
            allowsPromptActionWords: shouldUseClaudeCodeTerminalHostProofDirectInsertion(
                profile: profile,
                action: action
            )
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
                shouldUseClaudeCodeTerminalHostProofDirectInsertion(profile: profile, action: action)
                    || shouldUseCodexProofDirectInsertion(profile: profile)
                    || shouldUseClaudeDesktopProofDirectInsertion(profile: profile)
                    || shouldUseObsidianDirectValueInsertion(profile: profile, action: action)
                    || shouldUseObsidianSystemEventsInsertion(profile: profile) ? 0.75 : 0.25
            )
        )

        if shouldUseCodexProofDirectInsertion(profile: profile) {
            let succeeded = insertCodexProofText(acceptedText)
            DiagnosticsLog.shared.record(
                "insert",
                metadata: [
                    "app": profile.bundleIdentifier,
                    "mode": InsertionMode.axValueReplacement.rawValue,
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

        if shouldUseClaudeCodeTerminalHostProofDirectInsertion(profile: profile, action: action) {
            let succeeded = insertClaudeCodeTerminalHostProofText(acceptedText)
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

        if shouldUseClaudeDesktopProofDirectInsertion(profile: profile) {
            let succeeded = insertClaudeDesktopProofText(acceptedText)
            DiagnosticsLog.shared.record(
                "insert",
                metadata: [
                    "app": profile.bundleIdentifier,
                    "mode": InsertionMode.axValueReplacement.rawValue,
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

        if shouldUseObsidianDirectValueInsertion(profile: profile, action: action) {
            let succeeded = insertObsidianDirectValueText(acceptedText, profile: profile)
            DiagnosticsLog.shared.record(
                "insert",
                metadata: [
                    "app": profile.bundleIdentifier,
                    "mode": InsertionMode.axValueReplacement.rawValue,
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

    private func shouldUseClaudeCodeTerminalHostProofDirectInsertion(
        profile: CompatibilityProfile,
        action: KeyboardAction?
    ) -> Bool {
        profile.bundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier
            && action == .acceptNextWord
            && (
                currentSuggestionState.requestMode == .wordCompletion
                    || currentSuggestionState.requestMode == .phraseContinuation
            )
            && profile.insertionMode == .clipboardFallbackOptIn
            && profile.requiresNoSubmitAcceptanceProof
            && profile.promptAppSafetyMode == .wordOnly
    }

    private func shouldUseCodexProofDirectInsertion(profile: CompatibilityProfile) -> Bool {
        currentSuggestionState.appBundleIdentifier == "com.openai.codex"
            && profile.bundleIdentifier == "com.openai.codex"
            && CodexProofFocusedTargetPolicy.allowsOneWordProofRequestMode(currentSuggestionState.requestMode)
            && allowsCodexProofInsertion(profile: profile)
    }

    private func shouldUseClaudeDesktopProofDirectInsertion(profile: CompatibilityProfile) -> Bool {
        currentSuggestionState.appBundleIdentifier == "com.anthropic.claudefordesktop"
            && profile.bundleIdentifier == "com.anthropic.claudefordesktop"
            && currentSuggestionState.requestMode == .wordCompletion
            && profile.insertionMode == .axValueReplacement
            && profile.requiresNoSubmitAcceptanceProof
            && profile.promptAppSafetyMode == .wordOnly
    }

    private func shouldUseObsidianDirectValueInsertion(
        profile: CompatibilityProfile,
        action: KeyboardAction?
    ) -> Bool {
        currentSuggestionState.appBundleIdentifier == "md.obsidian"
            && profile.bundleIdentifier == "md.obsidian"
            && action == .acceptAllVisible
            && activeAppProofBundleIdentifiers.contains("md.obsidian")
            && ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_OBSIDIAN_DIRECT_VALUE_INSERT"] == "1"
    }

    private func shouldUseObsidianSystemEventsInsertion(profile: CompatibilityProfile) -> Bool {
        currentSuggestionState.appBundleIdentifier == "md.obsidian"
            && profile.bundleIdentifier == "md.obsidian"
            && profile.insertionMode == .axValueReplacement
    }

    private func insertObsidianDirectValueText(
        _ acceptedText: String,
        profile: CompatibilityProfile
    ) -> Bool {
        let bundleIdentifier = "md.obsidian"
        guard !acceptedText.isEmpty,
              let lastTextSnapshot,
              !lastTextSnapshot.textBeforeCursor.isEmpty,
              let frontmostApp = accessibilityClient.frontmostApplication(),
              frontmostApp.bundleIdentifier == bundleIdentifier else {
            DiagnosticsLog.shared.record(
                "obsidian-direct-value-insert",
                metadata: [
                    "app": bundleIdentifier,
                    "success": "false",
                    "reason": "precondition-failed"
                ]
            )
            return false
        }

        let previousText = lastTextSnapshot.textBeforeCursor + lastTextSnapshot.textAfterCursor
        let acceptedReplacementText = lastTextSnapshot.textBeforeCursor + acceptedText + lastTextSnapshot.textAfterCursor
        let proofDocumentPlan = Self.obsidianProofDocumentInsertionPlan(
            acceptedText: acceptedText,
            snapshot: lastTextSnapshot
        )
        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        let exactTextArea = Self.axTextAreaDescendant(
            in: appElement,
            matchingValue: previousText,
            containing: lastTextSnapshot.textBeforeCursor,
            maxDepth: 32
        )
        let focusedContext = accessibilityClient.focusedTextContext(
            for: frontmostApp,
            allowDescendantTextFallback: profile.allowsDescendantTextFallback,
            options: FocusedTextReadOptionsPolicy.options(for: frontmostApp, profile: profile)
        )
        let focusedTextAreaElementIdentifier: Int?
        if let focusedContext,
           fieldIdentity(app: frontmostApp, context: focusedContext, profile: profile) == lastTextSnapshot.fieldIdentity,
           focusedContext.textBeforeCursor == lastTextSnapshot.textBeforeCursor,
           focusedContext.textAfterCursor == lastTextSnapshot.textAfterCursor {
            focusedTextAreaElementIdentifier = focusedContext.elementIdentifier
        } else {
            focusedTextAreaElementIdentifier = nil
        }

        let matchedTextArea: AXUIElement?
        let replacementText: String
        let cursorUTF16Offset: Int
        let matchSource: String
        if let exactTextArea {
            matchedTextArea = exactTextArea
            replacementText = proofDocumentPlan?.replacementText ?? acceptedReplacementText
            cursorUTF16Offset = proofDocumentPlan?.cursorUTF16Offset
                ?? lastTextSnapshot.textBeforeCursor.utf16.count + acceptedText.utf16.count
            matchSource = proofDocumentPlan?.matchSource ?? "exact"
        } else if let focusedTextAreaElementIdentifier,
                  let containingTextArea = Self.axTextAreaDescendantContainingText(
            in: appElement,
            containing: lastTextSnapshot.textBeforeCursor,
            elementIdentifier: focusedTextAreaElementIdentifier,
            maxDepth: 32
        ),
                  let currentValue = Self.axStringAttribute(containingTextArea, kAXValueAttribute),
                  let replacementRange = Self.replacementRange(
                    in: currentValue,
                    previousText: previousText,
                    textBeforeCursor: lastTextSnapshot.textBeforeCursor,
                    textAfterCursor: lastTextSnapshot.textAfterCursor
                  ) {
            matchedTextArea = containingTextArea
            if let proofDocumentPlan {
                replacementText = proofDocumentPlan.replacementText
                cursorUTF16Offset = proofDocumentPlan.cursorUTF16Offset
                matchSource = proofDocumentPlan.matchSource
            } else {
                replacementText = currentValue.replacingCharacters(
                    in: replacementRange,
                    with: acceptedReplacementText
                )
                cursorUTF16Offset = currentValue[..<replacementRange.lowerBound].utf16.count
                    + lastTextSnapshot.textBeforeCursor.utf16.count
                    + acceptedText.utf16.count
                matchSource = "containingText"
            }
        } else {
            DiagnosticsLog.shared.record(
                "obsidian-direct-value-insert",
                metadata: [
                    "app": bundleIdentifier,
                    "success": "false",
                    "reason": "text-area-not-found"
                ]
            )
            return false
        }
        guard let textArea = matchedTextArea else {
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
                "obsidian-direct-value-insert",
                metadata: [
                    "app": bundleIdentifier,
                    "success": "false",
                    "reason": "value-set-failed",
                    "axResult": String(valueResult.rawValue)
                ]
            )
            return false
        }

        let canUseDocumentEndCursorFallback = lastTextSnapshot.textAfterCursor.isEmpty
        var usedDocumentEndCursorFallback = false
        Self.setAXSelectedTextRange(textArea, location: cursorUTF16Offset, length: 0)
        Thread.sleep(forTimeInterval: 0.05)
        if !Self.axObsidianSelectedTextRangeMatchesInsertionPoint(
            textArea,
            location: cursorUTF16Offset
        ) {
            if canUseDocumentEndCursorFallback {
                Self.postCommandDownKey()
                usedDocumentEndCursorFallback = true
            } else {
                Self.postCommandRightKey()
                Thread.sleep(forTimeInterval: 0.05)
                Self.setAXSelectedTextRange(textArea, location: cursorUTF16Offset, length: 0)
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        var succeeded = false
        var cursorMatches = false
        var proofDocumentVerified = false
        var currentText: String?
        for _ in 0..<5 {
            currentText = Self.axStringAttribute(textArea, kAXValueAttribute)
            cursorMatches = Self.axObsidianSelectedTextRangeMatchesInsertionPoint(
                textArea,
                location: cursorUTF16Offset
            )
            let acceptedDocumentEndFallback = usedDocumentEndCursorFallback
                && canUseDocumentEndCursorFallback
            if currentText == replacementText,
               cursorMatches || acceptedDocumentEndFallback {
                succeeded = true
                break
            }
            if currentText == replacementText {
                if canUseDocumentEndCursorFallback {
                    Self.postCommandDownKey()
                    usedDocumentEndCursorFallback = true
                } else {
                    Self.setAXSelectedTextRange(textArea, location: cursorUTF16Offset, length: 0)
                }
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        if !succeeded,
           proofDocumentPlan != nil {
            for _ in 0..<40 {
                if Self.obsidianProofDocumentText() == replacementText
                    || Self.obsidianProofDocumentConfirmsInsertion(expectedText: acceptedReplacementText) {
                    proofDocumentVerified = true
                    break
                }
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
        if !succeeded,
           proofDocumentVerified {
            if let currentText {
                let visibleCursorUTF16Offset = currentText.utf16.count
                Self.setAXSelectedTextRange(textArea, location: visibleCursorUTF16Offset, length: 0)
                Thread.sleep(forTimeInterval: 0.05)
                cursorMatches = Self.axObsidianSelectedTextRangeMatchesInsertionPoint(
                    textArea,
                    location: visibleCursorUTF16Offset
                )
            }
            succeeded = true
        }
        DiagnosticsLog.shared.record(
            "obsidian-direct-value-insert",
            metadata: [
                "app": bundleIdentifier,
                "success": String(succeeded),
                "cursorMatches": String(cursorMatches),
                "proofDocumentVerified": String(proofDocumentVerified),
                "documentEndCursorFallback": String(usedDocumentEndCursorFallback),
                "acceptedChars": String(acceptedText.count),
                "currentChars": String(currentText?.count ?? -1),
                "previousBeforeChars": String(lastTextSnapshot.textBeforeCursor.count),
                "previousAfterChars": String(lastTextSnapshot.textAfterCursor.count),
                "matchSource": matchSource
            ]
        )
        return succeeded
    }

    nonisolated private static func obsidianProofDocumentInsertionPlan(
        acceptedText: String,
        snapshot: FocusedTextSnapshot
    ) -> ObsidianProofDocumentInsertionPlan? {
        guard let proofDocumentText = obsidianProofDocumentText() else {
            return nil
        }

        return ObsidianProofDocumentInsertionPlanner().plan(
            proofDocumentText: proofDocumentText,
            textBeforeCursor: snapshot.textBeforeCursor,
            textAfterCursor: snapshot.textAfterCursor,
            acceptedText: acceptedText,
            marker: obsidianProofDocumentMarker()
        )
    }

    nonisolated private static func obsidianProofDocumentText() -> String? {
        let url = obsidianProofDocumentURL()
        guard isSafeObsidianProofDocumentURL(url) else {
            return nil
        }

        return try? String(contentsOf: url, encoding: .utf8)
    }

    nonisolated private static func obsidianProofDocumentURL() -> URL {
        if let configuredPath = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_FILE"],
           !configuredPath.isEmpty {
            return URL(fileURLWithPath: configuredPath)
        }

        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AutocompleteLab/ObsidianProofVault/Proof/placement-proof.md")
    }

    nonisolated private static func obsidianProofDocumentMarker() -> String {
        ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_OBSIDIAN_SMOKE_MARKER"]
            ?? "Autocomplete Lab Obsidian proof"
    }

    nonisolated private static func obsidianProofDocumentConfirmsInsertion(expectedText: String) -> Bool {
        guard !expectedText.isEmpty,
              let proofDocumentText = obsidianProofDocumentText() else {
            return false
        }

        return proofDocumentText.hasSuffix(expectedText)
            || proofDocumentText.contains(expectedText)
    }

    nonisolated private static func isSafeObsidianProofDocumentURL(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return path.contains("/Library/Application Support/AutocompleteLab/ObsidianProofVault/")
            && url.pathExtension == "md"
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
        let acceptanceProof = suggestionAcceptanceProof(action: action, acceptedText: acceptedText)
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
        suggestionOrchestrator.recordRepetitionAcceptance(
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

    private func insertCodexProofText(_ acceptedText: String) -> Bool {
        let bundleIdentifier = CodexProofFocusedTargetPolicy.bundleIdentifier
        let marker = CodexProofFocusedTargetPolicy.marker
        guard !acceptedText.isEmpty,
              let currentProfile,
              currentProfile.bundleIdentifier == bundleIdentifier,
              let currentSuggestionFieldIdentity = currentSuggestionState.fieldIdentity,
              let lastTextSnapshot,
              lastTextSnapshot.fieldIdentity == currentSuggestionFieldIdentity,
              lastTextSnapshot.textBeforeCursor.contains(marker),
              lastTextSnapshot.textAfterCursor.isEmpty,
              let frontmostApp = accessibilityClient.frontmostApplication(),
              frontmostApp.bundleIdentifier == bundleIdentifier,
              frontmostApp.processIdentifier == currentSuggestionFieldIdentity.processIdentifier else {
            DiagnosticsLog.shared.record(
                "codex-proof-insert",
                metadata: [
                    "app": bundleIdentifier,
                    "success": "false",
                    "reason": "precondition-failed"
                ]
            )
            return false
        }

        let previousText = lastTextSnapshot.textBeforeCursor + lastTextSnapshot.textAfterCursor
        let replacementText = lastTextSnapshot.textBeforeCursor + acceptedText + lastTextSnapshot.textAfterCursor
        let cursorUTF16Offset = lastTextSnapshot.textBeforeCursor.utf16.count + acceptedText.utf16.count
        guard let target = codexProofFocusedTarget(
            app: frontmostApp,
            profile: currentProfile,
            suggestionBundleIdentifier: currentSuggestionState.appBundleIdentifier,
            requestMode: currentSuggestionState.requestMode,
            expectedFieldIdentity: currentSuggestionFieldIdentity,
            snapshot: lastTextSnapshot,
            expectedFocusedText: previousText,
            shownTargetFingerprint: currentSuggestionState.acceptanceSnapshot?.targetFingerprint
        ) else {
            DiagnosticsLog.shared.record(
                "codex-proof-insert",
                metadata: [
                    "app": bundleIdentifier,
                    "success": "false",
                    "reason": "focused-target-mismatch"
                ]
            )
            return false
        }

        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        guard let textArea = Self.axFocusedTextArea(
            in: appElement,
            matchingValue: previousText,
            containing: marker,
            elementIdentifier: target.context.elementIdentifier
        ) else {
            DiagnosticsLog.shared.record(
                "codex-proof-insert",
                metadata: [
                    "app": bundleIdentifier,
                    "success": "false",
                    "reason": "focused-text-area-not-found"
                ]
            )
            return false
        }

        let valueResult = AXUIElementSetAttributeValue(
            textArea,
            kAXValueAttribute as CFString,
            replacementText as CFTypeRef
        )
        guard valueResult == .success else {
            DiagnosticsLog.shared.record(
                "codex-proof-insert",
                metadata: [
                    "app": bundleIdentifier,
                    "success": "false",
                    "reason": "set-value-failed",
                    "axResult": String(valueResult.rawValue)
                ]
            )
            return false
        }

        Self.setAXSelectedTextRange(textArea, location: cursorUTF16Offset, length: 0)
        Thread.sleep(forTimeInterval: 0.05)
        if !Self.axSelectedTextRangeMatches(textArea, location: cursorUTF16Offset, length: 0) {
            Self.postCommandRightKey()
            Thread.sleep(forTimeInterval: 0.05)
            Self.setAXSelectedTextRange(textArea, location: cursorUTF16Offset, length: 0)
        }

        let currentText = Self.axStringAttribute(textArea, kAXValueAttribute)
        let cursorMatches = Self.axSelectedTextRangeMatches(textArea, location: cursorUTF16Offset, length: 0)
        let succeeded = currentText == replacementText
        let insertMetadata: [String: String] = [
            "app": bundleIdentifier,
            "success": String(succeeded),
            "source": "focusedAXTextArea",
            "cursorMatches": String(cursorMatches),
            "previousBeforeChars": String(lastTextSnapshot.textBeforeCursor.count),
            "acceptedChars": String(acceptedText.count),
            "currentChars": String(currentText?.count ?? -1)
        ]
        DiagnosticsLog.shared.record(
            "codex-proof-insert",
            metadata: insertMetadata
        )
        return succeeded
    }

    private func insertClaudeDesktopProofText(_ acceptedText: String) -> Bool {
        let bundleIdentifier = "com.anthropic.claudefordesktop"
        guard !acceptedText.isEmpty,
              let currentSuggestionFieldIdentity = currentSuggestionState.fieldIdentity,
              let lastTextSnapshot,
              lastTextSnapshot.fieldIdentity == currentSuggestionFieldIdentity,
              !lastTextSnapshot.textBeforeCursor.isEmpty,
              lastTextSnapshot.textAfterCursor.isEmpty,
              let frontmostApp = accessibilityClient.frontmostApplication(),
              frontmostApp.bundleIdentifier == bundleIdentifier,
              frontmostApp.processIdentifier == currentSuggestionFieldIdentity.processIdentifier else {
            DiagnosticsLog.shared.record(
                "claude-desktop-proof-insert",
                metadata: [
                    "app": bundleIdentifier,
                    "success": "false",
                    "reason": "precondition-failed"
                ]
            )
            return false
        }

        let previousText = lastTextSnapshot.textBeforeCursor + lastTextSnapshot.textAfterCursor
        let replacementText = lastTextSnapshot.textBeforeCursor + acceptedText + lastTextSnapshot.textAfterCursor
        let cursorUTF16Offset = lastTextSnapshot.textBeforeCursor.utf16.count + acceptedText.utf16.count
        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        guard let textArea = Self.axTextAreaDescendant(
            in: appElement,
            matchingValue: previousText,
            containing: lastTextSnapshot.textBeforeCursor,
            maxDepth: 32
        ) else {
            DiagnosticsLog.shared.record(
                "claude-desktop-proof-insert",
                metadata: [
                    "app": bundleIdentifier,
                    "success": "false",
                    "reason": "text-area-not-found"
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
                "claude-desktop-proof-insert",
                metadata: [
                    "app": bundleIdentifier,
                    "success": "false",
                    "reason": "set-value-failed",
                    "axResult": String(valueResult.rawValue)
                ]
            )
            return false
        }

        Self.setAXSelectedTextRange(textArea, location: cursorUTF16Offset, length: 0)
        Thread.sleep(forTimeInterval: 0.05)
        if !Self.axSelectedTextRangeMatches(textArea, location: cursorUTF16Offset, length: 0) {
            Self.postCommandRightKey()
            Thread.sleep(forTimeInterval: 0.05)
            Self.setAXSelectedTextRange(textArea, location: cursorUTF16Offset, length: 0)
        }

        let currentText = Self.axStringAttribute(textArea, kAXValueAttribute)
        let cursorMatches = Self.axSelectedTextRangeMatches(textArea, location: cursorUTF16Offset, length: 0)
        let succeeded = currentText == replacementText && cursorMatches
        DiagnosticsLog.shared.record(
            "claude-desktop-proof-insert",
            metadata: [
                "app": bundleIdentifier,
                "success": String(succeeded),
                "source": "promptAXTextArea",
                "cursorMatches": String(cursorMatches),
                "previousBeforeChars": String(lastTextSnapshot.textBeforeCursor.count),
                "acceptedChars": String(acceptedText.count),
                "currentChars": String(currentText?.count ?? -1)
            ]
        )
        return succeeded
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
        if let blockReason = currentSuggestionAcceptanceDecision().blockReason {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "acceptance-recheck-failed",
                    "blockReason": blockReason.rawValue
                ]
            )
            return false
        }
        guard let frontmostApp = accessibilityClient.frontmostApplication(),
              let lastTextSnapshot else {
            return false
        }

        let expectedProofInputText = lastTextSnapshot.textBeforeCursor
            + acceptedText
            + lastTextSnapshot.textAfterCursor
        let originalProofInputText = lastTextSnapshot.textBeforeCursor
            + lastTextSnapshot.textAfterCursor

        if accessibilityClient.insertText(
            acceptedText,
            expectedFieldIdentity: currentSuggestionState.fieldIdentity,
            allowDescendantTextFallback: false
        ) {
            let verified = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: expectedProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "true",
                    "source": "axSelectedText",
                    "verified": String(verified)
                ]
            )
            return verified
        }

        let prefersFastGhosttyPasteboardInsertion =
            ClaudeCodeTerminalHostProofPolicy.shouldPreferFastPasteboardInsertion(
                hostBundleIdentifier: frontmostApp.bundleIdentifier,
                insertionMode: currentProfile?.insertionMode,
                requiresNoSubmitAcceptanceProof: currentProfile?.requiresNoSubmitAcceptanceProof == true
        )
        if prefersFastGhosttyPasteboardInsertion {
            keyboardEventTap?.suppressPassthroughObservation(for: 0.5)
            let runsExtendedGhosttyInsertionProbes =
                ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_GHOSTTY_EXTENDED_INSERTION_PROBES"] == "1"
            let configuredGhosttyFastInsertionBudgetSeconds =
                ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_GHOSTTY_FAST_INSERTION_BUDGET_SECONDS"]
                    .flatMap { TimeInterval($0) }
            let ghosttyFastInsertionBudgetSeconds = max(
                2.0,
                configuredGhosttyFastInsertionBudgetSeconds ?? 8.0
            )
            let ghosttyFastInsertionStartedAt = Date()

            func recordGhosttyFastFailClosed(reason: String) -> Bool {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": reason,
                        "source": "ghosttyFastFailClosed"
                    ]
                )
                return false
            }

            func shouldContinueGhosttyFastInsertion(before source: String) -> Bool {
                let elapsedSeconds = Date().timeIntervalSince(ghosttyFastInsertionStartedAt)
                if !runsExtendedGhosttyInsertionProbes,
                   elapsedSeconds > ghosttyFastInsertionBudgetSeconds {
                    DiagnosticsLog.shared.record(
                        "claude-code-terminal-host-proof-insert",
                        metadata: [
                            "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                            "posted": "false",
                            "reason": "ghostty-fast-insertion-budget-exceeded",
                            "source": "ghosttyFastInsertionBudget",
                            "nextSource": source,
                            "elapsedMilliseconds": String(Int(elapsedSeconds * 1000)),
                            "budgetMilliseconds": String(Int(ghosttyFastInsertionBudgetSeconds * 1000))
                        ]
                    )
                    return false
                }
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "source": source,
                        "stage": "source-start",
                        "elapsedMilliseconds": String(Int(elapsedSeconds * 1000)),
                        "budgetMilliseconds": String(Int(ghosttyFastInsertionBudgetSeconds * 1000)),
                        "extendedProbes": String(runsExtendedGhosttyInsertionProbes)
                    ]
                )
                return true
            }

            if ProcessInfo.processInfo.environment[
                "AUTOCOMPLETE_LAB_GHOSTTY_PRE_PROMPT_FOCUS_RAW_SYSTEM_EVENTS_INSERTION_PROBE"
            ] == "1" {
                guard shouldContinueGhosttyFastInsertion(
                    before: "ghosttyPrePromptFocusBundleSystemEventsRawKeystroke"
                ) else {
                    return recordGhosttyFastFailClosed(reason: "ghostty-fast-insertion-budget-exceeded")
                }
                let ghosttyPrePromptFocusRawOutcome =
                    insertGhosttyTerminalHostProofBundleSystemEventsRawKeystroke(
                        acceptedText,
                        expectedProofInputText: expectedProofInputText,
                        originalProofInputText: originalProofInputText,
                        frontmostApp: frontmostApp,
                        profile: currentProfile,
                        source: "ghosttyPrePromptFocusBundleSystemEventsRawKeystroke",
                        baselineSource: "ghosttyPrePromptFocusBundleSystemEventsRawKeystrokeBaseline",
                        stopReason: nil
                    )
                if ghosttyPrePromptFocusRawOutcome.verified {
                    return true
                }
                guard ghosttyPrePromptFocusRawOutcome.safeToContinue else {
                    return false
                }
            }

            guard prepareGhosttyTerminalHostProofInsertionTarget(
                frontmostApp: frontmostApp,
                originalProofInputText: originalProofInputText,
                profile: currentProfile
            ) else {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": "ghostty-fast-target-recheck-failed",
                        "source": "ghosttyFocusReassertion"
                    ]
                )
                return false
            }

            stopKeyboardEventTapNow(reason: "ghostty-fast-insertion-prompt-focus")
            if focusGhosttyTerminalHostProofPromptByClickIfAvailable(
                source: "ghosttyPromptFocusClick"
            ) {
                guard prepareGhosttyTerminalHostProofInsertionTarget(
                    frontmostApp: frontmostApp,
                    originalProofInputText: originalProofInputText,
                    profile: currentProfile
                ) else {
                    DiagnosticsLog.shared.record(
                        "claude-code-terminal-host-proof-insert",
                        metadata: [
                            "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                            "posted": "false",
                            "reason": "ghostty-fast-post-click-target-recheck-failed",
                            "source": "ghosttyPromptFocusClick"
                        ]
                    )
                    return false
                }
            }

            if ProcessInfo.processInfo.environment[
                "AUTOCOMPLETE_LAB_GHOSTTY_RAW_SYSTEM_EVENTS_INSERTION_PROBE"
            ] == "1" {
                guard shouldContinueGhosttyFastInsertion(before: "ghosttyBundleSystemEventsRawKeystroke") else {
                    return recordGhosttyFastFailClosed(reason: "ghostty-fast-insertion-budget-exceeded")
                }
                let ghosttyBundleSystemEventsRawOutcome =
                    insertGhosttyTerminalHostProofBundleSystemEventsRawKeystroke(
                        acceptedText,
                        expectedProofInputText: expectedProofInputText,
                        originalProofInputText: originalProofInputText,
                        frontmostApp: frontmostApp,
                        profile: currentProfile
                    )
                if ghosttyBundleSystemEventsRawOutcome.verified {
                    return true
                }
                guard ghosttyBundleSystemEventsRawOutcome.safeToContinue else {
                    return false
                }
            }

            guard shouldContinueGhosttyFastInsertion(before: "ghosttyFocusedSystemEventsBulkKeystroke") else {
                return recordGhosttyFastFailClosed(reason: "ghostty-fast-insertion-budget-exceeded")
            }
            let ghosttyFocusedSystemEventsOutcome = insertGhosttyTerminalHostProofFocusedSystemEventsBulkKeystroke(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile
            )
            if ghosttyFocusedSystemEventsOutcome.verified {
                return true
            }
            guard ghosttyFocusedSystemEventsOutcome.safeToContinue else {
                return false
            }

            guard shouldContinueGhosttyFastInsertion(before: "ghosttySendKey") else {
                return recordGhosttyFastFailClosed(reason: "ghostty-fast-insertion-budget-exceeded")
            }
            let ghosttySendKeyOutcome = insertGhosttyTerminalHostProofSendKey(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile
            )
            if ghosttySendKeyOutcome.verified {
                return true
            }
            guard ghosttySendKeyOutcome.safeToContinue else {
                return false
            }

            guard shouldContinueGhosttyFastInsertion(before: "ghosttySystemEventsBulkKeystroke") else {
                return recordGhosttyFastFailClosed(reason: "ghostty-fast-insertion-budget-exceeded")
            }
            let ghosttyBulkSystemEventsOutcome = insertGhosttyTerminalHostProofSystemEventsKeystroke(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile,
                delayMilliseconds: 0,
                bulkKeystroke: true
            )
            if ghosttyBulkSystemEventsOutcome.verified {
                return true
            }
            guard ghosttyBulkSystemEventsOutcome.safeToContinue else {
                return false
            }

            guard shouldContinueGhosttyFastInsertion(before: "ghosttyFocusedActionText") else {
                return recordGhosttyFastFailClosed(reason: "ghostty-fast-insertion-budget-exceeded")
            }
            let ghosttyFocusedActionTextOutcome = insertGhosttyTerminalHostProofFocusedActionText(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile
            )
            if ghosttyFocusedActionTextOutcome.verified {
                return true
            }
            guard ghosttyFocusedActionTextOutcome.safeToContinue else {
                return false
            }

            guard shouldContinueGhosttyFastInsertion(before: "ghosttyPasteAction") else {
                return recordGhosttyFastFailClosed(reason: "ghostty-fast-insertion-budget-exceeded")
            }
            let ghosttyPasteActionOutcome = insertGhosttyTerminalHostProofPasteAction(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile
            )
            if ghosttyPasteActionOutcome.verified {
                return true
            }
            guard ghosttyPasteActionOutcome.safeToContinue else {
                return false
            }

            let ghosttyPasteboardOutcome = insertClaudeCodeTerminalHostProofPasteboardText(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile
            )
            if ghosttyPasteboardOutcome.verified {
                return true
            }
            guard ghosttyPasteboardOutcome.safeToContinue else {
                return false
            }

            let runsBundledGhosttyInputTextHelperProbe =
                ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_GHOSTTY_BUNDLED_INPUT_TEXT_HELPER_PROBE"] == "1"
            let ghosttyBundledInputTextHelperOutcome: (verified: Bool, safeToContinue: Bool)
            if runsBundledGhosttyInputTextHelperProbe {
                guard shouldContinueGhosttyFastInsertion(before: "bundledGhosttyInputTextHelper") else {
                    return recordGhosttyFastFailClosed(reason: "ghostty-fast-insertion-budget-exceeded")
                }
                ghosttyBundledInputTextHelperOutcome =
                    insertClaudeCodeTerminalHostProofBundledGhosttyInputTextHelper(
                        acceptedText,
                        expectedProofInputText: expectedProofInputText,
                        originalProofInputText: originalProofInputText,
                        frontmostApp: frontmostApp,
                        profile: currentProfile
                    )
                if ghosttyBundledInputTextHelperOutcome.verified {
                    return true
                }
                guard ghosttyBundledInputTextHelperOutcome.safeToContinue else {
                    return false
                }
            } else {
                ghosttyBundledInputTextHelperOutcome = (verified: false, safeToContinue: true)
            }

            if ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_GHOSTTY_NATIVE_PREFIX_FINAL_KEY_PROBE"] == "1" {
                guard shouldContinueGhosttyFastInsertion(before: "ghosttyNativePrefixFinalKeyText") else {
                    return recordGhosttyFastFailClosed(reason: "ghostty-fast-insertion-budget-exceeded")
                }
                let ghosttyNativePrefixFinalKeyAcceptedPrefixText = String(acceptedText.dropLast())
                let ghosttyNativePrefixExpectedProofInputText = lastTextSnapshot.textBeforeCursor
                    + ghosttyNativePrefixFinalKeyAcceptedPrefixText
                    + lastTextSnapshot.textAfterCursor
                let ghosttyNativePrefixFinalKeyOutcome = insertGhosttyTerminalHostProofNativePrefixFinalKeyText(
                    acceptedText,
                    prefixExpectedProofInputText: ghosttyNativePrefixExpectedProofInputText,
                    expectedProofInputText: expectedProofInputText,
                    originalProofInputText: originalProofInputText,
                    frontmostApp: frontmostApp,
                    profile: currentProfile
                )
                if ghosttyNativePrefixFinalKeyOutcome.verified {
                    return true
                }
                guard ghosttyNativePrefixFinalKeyOutcome.safeToContinue else {
                    return false
                }
            }

            guard shouldContinueGhosttyFastInsertion(before: "ghosttyInProcessInputText") else {
                return recordGhosttyFastFailClosed(reason: "ghostty-fast-insertion-budget-exceeded")
            }
            let ghosttyInProcessInputTextOutcome = insertGhosttyTerminalHostProofInProcessInputText(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile
            )
            if ghosttyInProcessInputTextOutcome.verified {
                return true
            }
            guard ghosttyInProcessInputTextOutcome.safeToContinue else {
                return false
            }

            guard shouldContinueGhosttyFastInsertion(before: "ghosttyFrontWindowInputText") else {
                return recordGhosttyFastFailClosed(reason: "ghostty-fast-insertion-budget-exceeded")
            }
            let ghosttyFrontWindowInputTextOutcome = insertGhosttyTerminalHostProofFrontWindowInputText(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile
            )
            if ghosttyFrontWindowInputTextOutcome.verified {
                return true
            }
            guard ghosttyFrontWindowInputTextOutcome.safeToContinue else {
                return false
            }

            if !runsExtendedGhosttyInsertionProbes {
                let promptStayedUnchangedAfterInitialNoopCluster =
                    verifyClaudeCodeTerminalHostProofInsertion(
                        expectedProofInputText: originalProofInputText,
                        frontmostApp: frontmostApp,
                        profile: currentProfile,
                        attempts: 4
                    )
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "source": "ghosttyInitialNoopClusterBaseline",
                        "verified": String(promptStayedUnchangedAfterInitialNoopCluster)
                    ]
                )
                guard promptStayedUnchangedAfterInitialNoopCluster else {
                    DiagnosticsLog.shared.record(
                        "claude-code-terminal-host-proof-insert",
                        metadata: [
                            "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                            "posted": "false",
                            "reason": "ghostty-initial-noop-cluster-mutated-input",
                            "source": "ghosttyInitialNoopClusterBaseline"
                        ]
                    )
                    return false
                }

                let initialNoopCluster = GhosttyInitialInsertionNoopInput(
                    hostBundleIdentifier: frontmostApp.bundleIdentifier,
                    proofProfileBundleIdentifier: currentProfile?.bundleIdentifier,
                    sendKeyVerified: ghosttySendKeyOutcome.verified,
                    systemEventsBulkVerified: ghosttyFocusedSystemEventsOutcome.verified
                        || ghosttyBulkSystemEventsOutcome.verified,
                    systemEventsBulkSafeToContinue: ghosttyFocusedSystemEventsOutcome.safeToContinue
                        && ghosttyBulkSystemEventsOutcome.safeToContinue,
                    focusedActionTextVerified: ghosttyFocusedActionTextOutcome.verified,
                    focusedActionTextSafeToContinue: ghosttyFocusedActionTextOutcome.safeToContinue,
                    focusedActionTextNativeNoopClassified: ghosttyFocusedActionTextOutcome.nativeNoopClassified,
                    pasteActionVerified: ghosttyPasteActionOutcome.verified,
                    pasteActionSafeToContinue: ghosttyPasteActionOutcome.safeToContinue,
                    pasteActionNativeNoopClassified: ghosttyPasteActionOutcome.nativeNoopClassified,
                    pasteboardVerified: ghosttyPasteboardOutcome.verified,
                    pasteboardSafeToContinue: ghosttyPasteboardOutcome.safeToContinue,
                    bundledGhosttyInputTextHelperVerified: ghosttyBundledInputTextHelperOutcome.verified,
                    bundledGhosttyInputTextHelperSafeToContinue: ghosttyBundledInputTextHelperOutcome.safeToContinue,
                    inProcessInputTextVerified: ghosttyInProcessInputTextOutcome.verified,
                    inProcessInputTextSafeToContinue: ghosttyInProcessInputTextOutcome.safeToContinue,
                    frontWindowInputTextVerified: ghosttyFrontWindowInputTextOutcome.verified,
                    frontWindowInputTextSafeToContinue: ghosttyFrontWindowInputTextOutcome.safeToContinue,
                    frontWindowInputTextNativeNoopClassified: ghosttyFrontWindowInputTextOutcome.nativeNoopClassified,
                    promptStayedUnchanged: promptStayedUnchangedAfterInitialNoopCluster,
                    runsExtendedProbes: runsExtendedGhosttyInsertionProbes
                )
                if GhosttyInsertionNoopPolicy().shouldFailFastAfterInitialNoopCluster(initialNoopCluster) {
                    return recordGhosttyFastFailClosed(
                        reason: GhosttyInsertionNoopPolicy.initialNoopClusterReason
                    )
                }
            }

            guard shouldContinueGhosttyFastInsertion(before: "ghosttyLoginShellFrontWindowInputText") else {
                return recordGhosttyFastFailClosed(reason: "ghostty-fast-insertion-budget-exceeded")
            }
            let ghosttyLoginShellFrontWindowInputTextOutcome = insertGhosttyTerminalHostProofFrontWindowInputText(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile,
                launchThroughShell: true
            )
            if ghosttyLoginShellFrontWindowInputTextOutcome.verified {
                return true
            }
            guard ghosttyLoginShellFrontWindowInputTextOutcome.safeToContinue else {
                return false
            }

            guard shouldContinueGhosttyFastInsertion(before: "ghosttyPerformActionText") else {
                return recordGhosttyFastFailClosed(reason: "ghostty-fast-insertion-budget-exceeded")
            }
            let ghosttyActionTextOutcome = insertGhosttyTerminalHostProofActionText(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile
            )
            if ghosttyActionTextOutcome.verified {
                return true
            }
            guard ghosttyActionTextOutcome.safeToContinue else {
                return false
            }

            guard shouldContinueGhosttyFastInsertion(before: "ghosttyInputText") else {
                return recordGhosttyFastFailClosed(reason: "ghostty-fast-insertion-budget-exceeded")
            }
            let ghosttyInputTextOutcome = insertGhosttyTerminalHostProofAppleScriptText(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile
            )
            if ghosttyInputTextOutcome.verified {
                return true
            }
            guard ghosttyInputTextOutcome.safeToContinue else {
                return false
            }

            guard shouldContinueGhosttyFastInsertion(before: "ghosttyLoginShellInputText") else {
                return recordGhosttyFastFailClosed(reason: "ghostty-fast-insertion-budget-exceeded")
            }
            let ghosttyLoginShellInputTextOutcome = insertGhosttyTerminalHostProofAppleScriptText(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile,
                launchThroughShell: true
            )
            if ghosttyLoginShellInputTextOutcome.verified {
                return true
            }
            guard ghosttyLoginShellInputTextOutcome.safeToContinue else {
                return false
            }

            guard shouldContinueGhosttyFastInsertion(before: "ghosttySystemEventsKeystroke") else {
                return recordGhosttyFastFailClosed(reason: "ghostty-fast-insertion-budget-exceeded")
            }
            let ghosttySystemEventsOutcome = insertGhosttyTerminalHostProofSystemEventsKeystroke(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile,
                delayMilliseconds: 0
            )
            if ghosttySystemEventsOutcome.verified {
                return true
            }
            guard ghosttySystemEventsOutcome.safeToContinue else {
                return false
            }

            guard shouldContinueGhosttyFastInsertion(before: "cgHardwareKeyEventsToPid") else {
                return recordGhosttyFastFailClosed(reason: "ghostty-fast-insertion-budget-exceeded")
            }
            let ghosttyTargetedHardwareOutcome = insertClaudeCodeTerminalHostProofHardwareKeyEvents(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile,
                processIdentifier: frontmostApp.processIdentifier,
                source: "cgHardwareKeyEventsToPid",
                baselineSource: "cgHardwareKeyEventsToPidBaseline",
                mutatedInputReason: "hardware-to-pid-unverified-mutated-input"
            )
            if ghosttyTargetedHardwareOutcome.verified {
                return true
            }
            guard ghosttyTargetedHardwareOutcome.safeToContinue else {
                return false
            }

            guard shouldContinueGhosttyFastInsertion(before: "cgHardwareKeyEventsGlobal") else {
                return recordGhosttyFastFailClosed(reason: "ghostty-fast-insertion-budget-exceeded")
            }
            keyboardEventTap?.suppressPassthroughObservation(for: 0.5)
            let ghosttyGlobalHardwareOutcome = insertClaudeCodeTerminalHostProofHardwareKeyEvents(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile,
                processIdentifier: nil,
                source: "cgHardwareKeyEventsGlobal",
                baselineSource: "cgHardwareKeyEventsGlobalBaseline",
                mutatedInputReason: "hardware-global-unverified-mutated-input"
            )
            if ghosttyGlobalHardwareOutcome.verified {
                return true
            }
            guard ghosttyGlobalHardwareOutcome.safeToContinue else {
                return false
            }

            guard shouldContinueGhosttyFastInsertion(before: "bundledCGEventTextHelperHID") else {
                return recordGhosttyFastFailClosed(reason: "ghostty-fast-insertion-budget-exceeded")
            }
            let bundledHelperOutcome = insertClaudeCodeTerminalHostProofBundledTextEventHelper(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile,
                tapName: "hid"
            )
            if bundledHelperOutcome.verified {
                return true
            }
            guard bundledHelperOutcome.safeToContinue else {
                return false
            }

            guard shouldContinueGhosttyFastInsertion(before: "bundledCGEventTextHelperSession") else {
                return recordGhosttyFastFailClosed(reason: "ghostty-fast-insertion-budget-exceeded")
            }
            let bundledSessionHelperOutcome = insertClaudeCodeTerminalHostProofBundledTextEventHelper(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile,
                tapName: "session"
            )
            if bundledSessionHelperOutcome.verified {
                return true
            }
            guard bundledSessionHelperOutcome.safeToContinue else {
                return false
            }

            guard shouldContinueGhosttyFastInsertion(before: "ghosttySystemEventsLoginShellBulkKeystroke") else {
                return recordGhosttyFastFailClosed(reason: "ghostty-fast-insertion-budget-exceeded")
            }
            let ghosttyShellBulkSystemEventsOutcome =
                insertGhosttyTerminalHostProofSystemEventsKeystroke(
                    acceptedText,
                    expectedProofInputText: expectedProofInputText,
                    originalProofInputText: originalProofInputText,
                    frontmostApp: frontmostApp,
                    profile: currentProfile,
                    delayMilliseconds: 0,
                    bulkKeystroke: true,
                    launchThroughShell: true
                )
            if ghosttyShellBulkSystemEventsOutcome.verified {
                return true
            }
            guard ghosttyShellBulkSystemEventsOutcome.safeToContinue else {
                return false
            }

            guard shouldContinueGhosttyFastInsertion(before: "cgUnicodeKeyEventsPerCharacterGlobal") else {
                return recordGhosttyFastFailClosed(reason: "ghostty-fast-insertion-budget-exceeded")
            }
            keyboardEventTap?.suppressPassthroughObservation(for: 0.5)
            if Self.postUnicodeTextKeyEventsPerCharacter(acceptedText) {
                let verified = verifyClaudeCodeTerminalHostProofInsertion(
                    expectedProofInputText: expectedProofInputText,
                    frontmostApp: frontmostApp,
                    profile: currentProfile,
                    attempts: 24
                )
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "true",
                        "source": "cgUnicodeKeyEventsPerCharacterGlobal",
                        "verified": String(verified)
                    ]
                )
                if verified {
                    return true
                }

                let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
                    expectedProofInputText: originalProofInputText,
                    frontmostApp: frontmostApp,
                    profile: currentProfile,
                    attempts: 4
                )
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "source": "cgUnicodeKeyEventsPerCharacterGlobalBaseline",
                        "verified": String(promptStayedUnchanged)
                    ]
                )
                guard promptStayedUnchanged else {
                    DiagnosticsLog.shared.record(
                        "claude-code-terminal-host-proof-insert",
                        metadata: [
                            "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                            "posted": "false",
                            "reason": "unicode-per-character-global-unverified-mutated-input",
                            "source": "cgUnicodeKeyEventsPerCharacterGlobalBaseline"
                        ]
                    )
                    return false
                }
            }

            return recordGhosttyFastFailClosed(reason: "ghostty-fast-verified-insertion-failed")
        }

        if frontmostApp.bundleIdentifier == "com.mitchellh.ghostty",
           !prefersFastGhosttyPasteboardInsertion {
            let ghosttyActionOutcome = insertGhosttyTerminalHostProofActionText(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile
            )
            if ghosttyActionOutcome.verified {
                return true
            }
            guard ghosttyActionOutcome.safeToContinue else {
                return false
            }

            let ghosttyInputOutcome = insertGhosttyTerminalHostProofAppleScriptText(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile
            )
            if ghosttyInputOutcome.verified {
                return true
            }
            guard ghosttyInputOutcome.safeToContinue else {
                return false
            }

            let ghosttyPasteActionOutcome = insertGhosttyTerminalHostProofPasteAction(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile
            )
            if ghosttyPasteActionOutcome.verified {
                return true
            }
            guard ghosttyPasteActionOutcome.safeToContinue else {
                return false
            }

            let ghosttySendKeyOutcome = insertGhosttyTerminalHostProofSendKey(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile
            )
            if ghosttySendKeyOutcome.verified {
                return true
            }
            guard ghosttySendKeyOutcome.safeToContinue else {
                return false
            }

            let ghosttyBulkSystemEventsOutcome = insertGhosttyTerminalHostProofSystemEventsKeystroke(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile,
                bulkKeystroke: true
            )
            if ghosttyBulkSystemEventsOutcome.verified {
                return true
            }
            guard ghosttyBulkSystemEventsOutcome.safeToContinue else {
                return false
            }

            let ghosttySystemEventsOutcome = insertGhosttyTerminalHostProofSystemEventsKeystroke(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile
            )
            if ghosttySystemEventsOutcome.verified {
                return true
            }
            guard ghosttySystemEventsOutcome.safeToContinue else {
                return false
            }
        }

        if Self.postHardwareTextKeyEvents(
            acceptedText,
            processIdentifier: frontmostApp.processIdentifier
        ) {
            let verified = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: expectedProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile,
                attempts: 24
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "true",
                    "source": "cgHardwareKeyEvents",
                    "verified": String(verified)
                ]
            )
            if verified {
                return true
            }

            let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile,
                attempts: 4
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "source": "cgHardwareKeyEventsBaseline",
                    "verified": String(promptStayedUnchanged)
                ]
            )
            guard promptStayedUnchanged else {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": "hardware-unverified-mutated-input",
                        "source": "cgHardwareKeyEventsBaseline"
                    ]
                )
                return false
            }
        }

        keyboardEventTap?.suppressPassthroughObservation(for: 0.5)
        if Self.postHardwareTextKeyEvents(acceptedText) {
            let verified = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: expectedProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile,
                attempts: 24
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "true",
                    "source": "cgHardwareKeyEventsGlobal",
                    "verified": String(verified)
                ]
            )
            if verified {
                return true
            }

            let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile,
                attempts: 4
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "source": "cgHardwareKeyEventsGlobalBaseline",
                    "verified": String(promptStayedUnchanged)
                ]
            )
            guard promptStayedUnchanged else {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": "hardware-global-unverified-mutated-input",
                        "source": "cgHardwareKeyEventsGlobalBaseline"
                    ]
                )
                return false
            }
        }

        if Self.postUnicodeTextKeyEvents(
            acceptedText,
            processIdentifier: frontmostApp.processIdentifier
        ) {
            let verified = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: expectedProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile,
                attempts: 24
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "true",
                    "source": "cgUnicodeKeyEvents",
                    "verified": String(verified)
                ]
            )
            if verified {
                return true
            }

            let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile,
                attempts: 4
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "source": "cgUnicodeKeyEventsBaseline",
                    "verified": String(promptStayedUnchanged)
                ]
            )
            guard promptStayedUnchanged else {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": "unicode-unverified-mutated-input",
                        "source": "cgUnicodeKeyEventsBaseline"
                    ]
                )
                return false
            }
        }

        keyboardEventTap?.suppressPassthroughObservation(for: 0.5)
        if Self.postUnicodeTextKeyEvents(acceptedText) {
            let verified = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: expectedProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile,
                attempts: 24
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "true",
                    "source": "cgUnicodeKeyEventsGlobal",
                    "verified": String(verified)
                ]
            )
            if verified {
                return true
            }

            let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile,
                attempts: 4
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "source": "cgUnicodeKeyEventsGlobalBaseline",
                    "verified": String(promptStayedUnchanged)
                ]
            )
            guard promptStayedUnchanged else {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": "unicode-global-unverified-mutated-input",
                        "source": "cgUnicodeKeyEventsGlobalBaseline"
                    ]
                )
                return false
            }
        }

        let pasteboardOutcome = prefersFastGhosttyPasteboardInsertion
            ? (verified: false, safeToContinue: true)
            : insertClaudeCodeTerminalHostProofPasteboardText(
                acceptedText,
                expectedProofInputText: expectedProofInputText,
                originalProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: currentProfile
            )
        if pasteboardOutcome.verified {
            return true
        }
        guard pasteboardOutcome.safeToContinue else {
            return false
        }

        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "posted": "false",
                "reason": "terminal-verified-insertion-failed",
                "source": "failClosed"
            ]
        )
        return false
    }

    private func insertClaudeCodeTerminalHostProofHardwareKeyEvents(
        _ acceptedText: String,
        expectedProofInputText: String,
        originalProofInputText: String,
        frontmostApp: RunningApplicationInfo,
        profile: CompatibilityProfile?,
        processIdentifier: pid_t?,
        source: String,
        baselineSource: String,
        mutatedInputReason: String
    ) -> (verified: Bool, safeToContinue: Bool) {
        if frontmostApp.bundleIdentifier == "com.mitchellh.ghostty",
           !reassertGhosttyTerminalHostProofFrontmostProcess(
               frontmostApp: frontmostApp,
               source: "\(source)FrontmostPidReassertion"
           ) {
            return (false, true)
        }
        keyboardEventTap?.suppressPassthroughObservation(for: 0.5)

        guard Self.postHardwareTextKeyEvents(
            acceptedText,
            processIdentifier: processIdentifier
        ) else {
            return (false, true)
        }

        let verified = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: expectedProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 24
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "posted": "true",
                "source": source,
                "verified": String(verified)
            ]
        )
        if verified {
            return (true, false)
        }

        let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: originalProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 4
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "source": baselineSource,
                "verified": String(promptStayedUnchanged)
            ]
        )
        guard promptStayedUnchanged else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": mutatedInputReason,
                    "source": baselineSource
                ]
            )
            return (false, false)
        }
        return (false, true)
    }

    private func insertClaudeCodeTerminalHostProofBundledTextEventHelper(
        _ acceptedText: String,
        expectedProofInputText: String,
        originalProofInputText: String,
        frontmostApp: RunningApplicationInfo,
        profile: CompatibilityProfile?,
        tapName: String
    ) -> (verified: Bool, safeToContinue: Bool) {
        let safeTapName = tapName == "session" ? "session" : "hid"
        let source = safeTapName == "session"
            ? "bundledCGEventTextHelperSession"
            : "bundledCGEventTextHelperHID"
        let baselineSource = "\(source)Baseline"
        guard !acceptedText.isEmpty,
              !acceptedText.contains(where: \.isNewline) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "bundled-helper-text-not-one-line",
                    "source": source
                ]
            )
            return (false, false)
        }
        guard let helperURL = Self.bundledTextEventHelperURL() else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "bundled-helper-missing",
                    "source": source
                ]
            )
            return (false, true)
        }

        let process = Process()
        process.executableURL = helperURL
        process.arguments = [
            "--tap", safeTapName,
            "--frontmost-bundle", frontmostApp.bundleIdentifier,
            "--pid", String(frontmostApp.processIdentifier)
        ]
        let inputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardInput = inputPipe
        process.standardError = errorPipe
        keyboardEventTap?.suppressPassthroughObservation(for: 0.5)
        if frontmostApp.bundleIdentifier == "com.mitchellh.ghostty",
           !reassertGhosttyTerminalHostProofFrontmostProcess(
               frontmostApp: frontmostApp,
               source: "\(source)FrontmostPidReassertion"
           ) {
            let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: profile,
                attempts: 4
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "source": "\(source)FrontmostPidReassertionBaseline",
                    "verified": String(promptStayedUnchanged)
                ]
            )
            return (false, promptStayedUnchanged)
        }

        do {
            try process.run()
            inputPipe.fileHandleForWriting.write(Data(acceptedText.utf8))
            try? inputPipe.fileHandleForWriting.close()
            process.waitUntilExit()
        } catch {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "bundled-helper-launch-failed",
                    "source": source
                ]
            )
            return (false, true)
        }

        let helperErrorText = String(
            data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderr = String(helperErrorText.prefix(120))
        let helperExitedSuccessfully = process.terminationStatus == 0
        if helperExitedSuccessfully {
            let verified = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: expectedProofInputText,
                frontmostApp: frontmostApp,
                profile: profile,
                attempts: 24
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "true",
                    "source": source,
                    "verified": String(verified)
                ]
            )
            if verified {
                return (true, true)
            }
        } else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "exitStatus": String(process.terminationStatus),
                    "helperError": String(stderr),
                    "posted": "false",
                    "reason": "bundled-helper-exited-nonzero",
                    "source": source
                ]
            )
        }

        let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: originalProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 4
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "source": baselineSource,
                "verified": String(promptStayedUnchanged)
            ]
        )
        guard promptStayedUnchanged else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "bundled-helper-unverified-mutated-input",
                    "source": baselineSource
                ]
            )
            return (false, false)
        }
        return (false, true)
    }

    private func insertClaudeCodeTerminalHostProofBundledGhosttyInputTextHelper(
        _ acceptedText: String,
        expectedProofInputText: String,
        originalProofInputText: String,
        frontmostApp: RunningApplicationInfo,
        profile: CompatibilityProfile?
    ) -> (verified: Bool, safeToContinue: Bool) {
        let source = "bundledGhosttyInputTextHelper"
        let baselineSource = "bundledGhosttyInputTextHelperBaseline"
        guard frontmostApp.bundleIdentifier == "com.mitchellh.ghostty" else {
            return (false, true)
        }
        guard !acceptedText.isEmpty,
              !acceptedText.contains(where: \.isNewline) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "bundled-ghostty-input-helper-text-not-one-line",
                    "source": source
                ]
            )
            return (false, false)
        }
        guard let helperURL = Self.bundledTextEventHelperURL() else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "bundled-ghostty-input-helper-missing",
                    "source": source
                ]
            )
            return (false, true)
        }

        keyboardEventTap?.suppressPassthroughObservation(for: 0.5)
        guard reassertGhosttyTerminalHostProofFrontmostProcess(
            frontmostApp: frontmostApp,
            source: "\(source)FrontmostPidReassertion"
        ) else {
            let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: profile,
                attempts: 4
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "source": "\(source)FrontmostPidReassertionBaseline",
                    "verified": String(promptStayedUnchanged)
                ]
            )
            return (false, promptStayedUnchanged)
        }

        let process = Process()
        process.executableURL = helperURL
        process.arguments = [
            "--ghostty-input-text",
            "--frontmost-bundle", frontmostApp.bundleIdentifier,
            "--pid", String(frontmostApp.processIdentifier),
            "--proof-marker", ClaudeCodeTerminalHostProofPolicy.proofMarker,
            "--compact-proof-marker", ClaudeCodeTerminalHostProofPolicy.compactProofMarker
        ]
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            inputPipe.fileHandleForWriting.write(Data(acceptedText.utf8))
            try? inputPipe.fileHandleForWriting.close()
        } catch {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "bundled-ghostty-input-helper-launch-failed",
                    "source": source,
                    "errorMessage": String(String(describing: error).prefix(160))
                ]
            )
            return (false, true)
        }

        guard Self.waitForProcessExit(
            process,
            timeoutSeconds: 1.4,
            pollIntervalSeconds: 0.02
        ) else {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.05)
            if process.isRunning {
                process.interrupt()
            }
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "bundled-ghostty-input-helper-timeout",
                    "source": source
                ]
            )
            let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: profile,
                attempts: 4
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "source": "\(source)TimeoutBaseline",
                    "verified": String(promptStayedUnchanged)
                ]
            )
            return (false, promptStayedUnchanged)
        }

        _ = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let helperErrorText = String(
            data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderr = String(helperErrorText.prefix(160))
        if process.terminationStatus == 0 {
            let verified = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: expectedProofInputText,
                frontmostApp: frontmostApp,
                profile: profile,
                attempts: 24
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "helperMode": "ghosttyInputText",
                    "posted": "true",
                    "source": source,
                    "verified": String(verified)
                ]
            )
            if verified {
                return (true, false)
            }
        } else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "exitStatus": String(process.terminationStatus),
                    "helperError": stderr,
                    "helperMode": "ghosttyInputText",
                    "posted": "false",
                    "reason": "bundled-ghostty-input-helper-exited-nonzero",
                    "source": source
                ]
            )
        }

        let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: originalProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 4
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "source": baselineSource,
                "verified": String(promptStayedUnchanged)
            ]
        )
        guard promptStayedUnchanged else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "bundled-ghostty-input-helper-unverified-mutated-input",
                    "source": baselineSource
                ]
            )
            return (false, false)
        }
        return (false, true)
    }

    private func insertGhosttyTerminalHostProofNativePrefixFinalKeyText(
        _ acceptedText: String,
        prefixExpectedProofInputText: String,
        expectedProofInputText: String,
        originalProofInputText: String,
        frontmostApp: RunningApplicationInfo,
        profile: CompatibilityProfile?
    ) -> (verified: Bool, safeToContinue: Bool) {
        let source = "ghosttyNativePrefixFinalKeyText"
        let baselineSource = "ghosttyNativePrefixFinalKeyTextBaseline"
        func verifyOriginalPromptStillUnchanged(reason: String) -> Bool {
            let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: profile,
                attempts: 4
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "source": baselineSource,
                    "verified": String(promptStayedUnchanged)
                ]
            )
            guard promptStayedUnchanged else {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": reason,
                        "source": baselineSource
                    ]
                )
                return false
            }
            return true
        }

        guard acceptedText.count > 1,
              !acceptedText.contains(where: \.isNewline) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-native-prefix-final-key-text-not-eligible",
                    "source": source
                ]
            )
            return (false, true)
        }

        let prefixText = String(acceptedText.dropLast())
        let finalText = String(acceptedText.suffix(1))
        let osascriptPath = "/usr/bin/osascript"
        guard FileManager.default.isExecutableFile(atPath: osascriptPath) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-native-prefix-final-key-osascript-missing",
                    "source": source
                ]
            )
            return (false, false)
        }

        let scriptSource = """
        set acceptedPrefixText to system attribute "AUTOCOMPLETE_LAB_GHOSTTY_ACCEPTED_PREFIX_TEXT"
        tell application id "com.mitchellh.ghostty"
            set targetWindow to front window
            activate window targetWindow
            set targetTab to selected tab of targetWindow
            set targetTerminal to focused terminal of targetTab
            focus targetTerminal
            input text acceptedPrefixText to targetTerminal
            activate
            return true
        end tell
        """

        let standardOutput = Pipe()
        let standardError = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: osascriptPath)
        process.arguments = ["-e", scriptSource]
        var environment = ProcessInfo.processInfo.environment
        environment["AUTOCOMPLETE_LAB_GHOSTTY_ACCEPTED_PREFIX_TEXT"] = prefixText
        process.environment = environment
        process.standardOutput = standardOutput
        process.standardError = standardError

        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "acceptedChars": String(acceptedText.count),
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "prefixChars": String(prefixText.count),
                "source": source,
                "stage": "start"
            ]
        )
        do {
            try process.run()
        } catch {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-native-prefix-final-key-launch-failed",
                    "source": source,
                    "errorMessage": String(String(describing: error).prefix(160))
                ]
            )
            return (false, true)
        }

        guard Self.waitForProcessExit(
            process,
            timeoutSeconds: 1.2,
            pollIntervalSeconds: 0.02
        ) else {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.05)
            if process.isRunning {
                process.interrupt()
            }
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-native-prefix-final-key-prefix-timeout",
                    "source": source
                ]
            )
            return (
                false,
                verifyOriginalPromptStillUnchanged(
                    reason: "ghostty-native-prefix-final-key-prefix-timeout-mutated-input"
                )
            )
        }

        let stdoutText = String(
            data: standardOutput.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderrText = String(
            data: standardError.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0, stdoutText != "false" else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": process.terminationStatus == 0
                        ? "ghostty-native-prefix-final-key-prefix-returned-false"
                        : "ghostty-native-prefix-final-key-prefix-failed",
                    "source": source,
                    "exitStatus": String(process.terminationStatus),
                    "errorMessage": String(stderrText.prefix(160))
                ]
            )
            return (
                false,
                verifyOriginalPromptStillUnchanged(
                    reason: "ghostty-native-prefix-final-key-prefix-unverified-mutated-input"
                )
            )
        }

        let drainSeconds = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_GHOSTTY_NATIVE_PREFIX_FINAL_KEY_DRAIN_SECONDS"]
            .flatMap { TimeInterval($0) }
            .map { min(max($0, 0.0), 10.0) } ?? 8.0
        if drainSeconds > 0 {
            Thread.sleep(forTimeInterval: drainSeconds)
        }
        let prefixVerified = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: prefixExpectedProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 24,
            delaySeconds: 0.1
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "drainMilliseconds": String(Int(drainSeconds * 1000)),
                "source": source,
                "stage": "prefix-verified",
                "verified": String(prefixVerified)
            ]
        )
        guard prefixVerified else {
            return (
                false,
                verifyOriginalPromptStillUnchanged(
                    reason: "ghostty-native-prefix-final-key-prefix-unverified-noop"
                )
            )
        }

        guard reassertGhosttyTerminalHostProofFrontmostProcess(
            frontmostApp: frontmostApp,
            source: "ghosttyNativePrefixFinalKeyFrontmostPidReassertion"
        ) else {
            return (
                false,
                verifyOriginalPromptStillUnchanged(
                    reason: "ghostty-native-prefix-final-key-frontmost-reassertion-mutated-input"
                )
            )
        }

        keyboardEventTap?.suppressPassthroughObservation(for: 0.5)
        guard Self.postUnicodeTextKeyEventsPerCharacter(finalText) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-native-prefix-final-key-final-event-not-posted",
                    "source": source
                ]
            )
            return (
                false,
                verifyOriginalPromptStillUnchanged(
                    reason: "ghostty-native-prefix-final-key-final-event-unverified-mutated-input"
                )
            )
        }

        let verified = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: expectedProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 24
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "posted": "true",
                "source": source,
                "verified": String(verified)
            ]
        )
        if verified {
            return (true, false)
        }

        return (
            false,
            verifyOriginalPromptStillUnchanged(
                reason: "ghostty-native-prefix-final-key-unverified-mutated-input"
            )
        )
    }

    private func insertGhosttyTerminalHostProofInProcessInputText(
        _ acceptedText: String,
        expectedProofInputText: String,
        originalProofInputText: String,
        frontmostApp: RunningApplicationInfo,
        profile: CompatibilityProfile?
    ) -> (verified: Bool, safeToContinue: Bool) {
        let source = "ghosttyInProcessInputText"
        let baselineSource = "ghosttyInProcessInputTextBaseline"
        guard !acceptedText.isEmpty,
              !acceptedText.contains(where: \.isNewline) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-in-process-input-text-not-one-line",
                    "source": source
                ]
            )
            return (false, false)
        }

        let scriptSource = """
        set acceptedText to \(Self.appleScriptStringLiteral(acceptedText))
        set proofMarker to \(Self.appleScriptStringLiteral(ClaudeCodeTerminalHostProofPolicy.proofMarker))
        set compactProofMarker to \(Self.appleScriptStringLiteral(ClaudeCodeTerminalHostProofPolicy.compactProofMarker))
        set targetProcessId to \(frontmostApp.processIdentifier) as integer
        set targetWindow to missing value
        set targetWindowName to ""
        set targetWindowNameIsProof to false
        tell application "System Events"
            set ghosttyProcess to first application process whose unix id is targetProcessId
            if bundle identifier of ghosttyProcess is not "com.mitchellh.ghostty" then error "Target Ghostty process bundle mismatch."
            set frontmost of ghosttyProcess to true
            delay 0.04
            if frontmost of ghosttyProcess is false then error "Target Ghostty process is not frontmost."
            try
                set targetWindowName to name of front window of ghosttyProcess as text
                if targetWindowName contains proofMarker or targetWindowName contains compactProofMarker then set targetWindowNameIsProof to true
            end try
        end tell
        tell application id "com.mitchellh.ghostty"
            repeat with candidateWindow in windows
                set windowName to name of candidateWindow as text
                if targetWindowNameIsProof and targetWindowName is not "" and windowName is targetWindowName then
                    set targetWindow to candidateWindow
                    exit repeat
                end if
            end repeat
            if targetWindow is missing value then
                repeat with candidateWindow in windows
                    set windowName to name of candidateWindow as text
                    if windowName contains proofMarker or windowName contains compactProofMarker then
                        set targetWindow to candidateWindow
                        exit repeat
                    end if
                end repeat
            end if
            if targetWindow is missing value then return false
            set targetTab to selected tab of targetWindow
            set targetTerminal to focused terminal of targetTab
            activate window targetWindow
            select tab targetTab
            focus targetTerminal
            activate
        end tell
        delay 0.02
        tell application "System Events"
            set ghosttyProcess to first application process whose unix id is targetProcessId
            if bundle identifier of ghosttyProcess is not "com.mitchellh.ghostty" then error "Target Ghostty process bundle mismatch."
            set frontmost of ghosttyProcess to true
            delay 0.04
            if frontmost of ghosttyProcess is false then error "Target Ghostty process is not frontmost."
        end tell
        tell application id "com.mitchellh.ghostty"
            input text acceptedText to targetTerminal
            return true
        end tell
        """

        guard let script = NSAppleScript(source: scriptSource) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-in-process-input-script-create-failed",
                    "source": source
                ]
            )
            return (false, true)
        }

        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "acceptedChars": String(acceptedText.count),
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "source": source,
                "stage": "start"
            ]
        )
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-in-process-input-script-failed",
                    "source": source,
                    "errorNumber": (errorInfo["NSAppleScriptErrorNumber"] as? NSNumber)?.stringValue ?? "",
                    "errorMessage": String((errorInfo["NSAppleScriptErrorMessage"] as? String ?? "").prefix(160))
                ]
            )
            return (false, true)
        }

        guard result.booleanValue else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-in-process-input-proof-window-missing",
                    "source": source
                ]
            )
            return (false, true)
        }

        let verified = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: expectedProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 24
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "posted": "true",
                "source": source,
                "verified": String(verified)
            ]
        )
        if verified {
            return (true, false)
        }

        let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: originalProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 4
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "source": baselineSource,
                "verified": String(promptStayedUnchanged)
            ]
        )
        guard promptStayedUnchanged else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-in-process-input-unverified-mutated-input",
                    "source": baselineSource
                ]
            )
            return (false, false)
        }
        return (false, true)
    }

    private func insertGhosttyTerminalHostProofFrontWindowInputText(
        _ acceptedText: String,
        expectedProofInputText: String,
        originalProofInputText: String,
        frontmostApp: RunningApplicationInfo,
        profile: CompatibilityProfile?,
        launchThroughShell: Bool = false
    ) -> (verified: Bool, safeToContinue: Bool, nativeNoopClassified: Bool) {
        let source = launchThroughShell
            ? "ghosttyLoginShellFrontWindowInputText"
            : "ghosttyFrontWindowInputText"
        let baselineSource = launchThroughShell
            ? "ghosttyLoginShellFrontWindowInputTextBaseline"
            : "ghosttyFrontWindowInputTextBaseline"
        guard !acceptedText.isEmpty,
              !acceptedText.contains(where: \.isNewline) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-front-window-input-text-not-one-line",
                    "source": source
                ]
            )
            return (false, false, false)
        }

        let osascriptPath = "/usr/bin/osascript"
        guard FileManager.default.isExecutableFile(atPath: osascriptPath) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-front-window-input-osascript-missing",
                    "source": source
                ]
            )
            return (false, false, false)
        }

        let shellPath = "/bin/zsh"
        if launchThroughShell,
           !FileManager.default.isExecutableFile(atPath: shellPath) {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-front-window-input-shell-missing",
                    "source": source
                ]
            )
            return (false, true, false)
        }

        let usesArgumentText = !launchThroughShell
        let scriptSource = usesArgumentText
            ? """
            on run argv
                set acceptedText to item 1 of argv
                tell application id "com.mitchellh.ghostty"
                    set targetWindow to front window
                    activate window targetWindow
                    set targetTab to selected tab of targetWindow
                    set targetTerminal to focused terminal of targetTab
                    focus targetTerminal
                    input text acceptedText to targetTerminal
                    activate
                    return true
                end tell
            end run
            """
            : """
            set acceptedText to system attribute "AUTOCOMPLETE_LAB_GHOSTTY_ACCEPTED_TEXT"
            tell application id "com.mitchellh.ghostty"
                set targetWindow to front window
                activate window targetWindow
                set targetTab to selected tab of targetWindow
                set targetTerminal to focused terminal of targetTab
                focus targetTerminal
                input text acceptedText to targetTerminal
                activate
                return true
            end tell
            """

        let standardOutput = Pipe()
        let standardError = Pipe()
        let standardInput = Pipe()
        let process = Process()
        if launchThroughShell {
            process.executableURL = URL(fileURLWithPath: shellPath)
            process.arguments = ["-lc", "exec /usr/bin/osascript"]
            process.standardInput = standardInput
        } else if usesArgumentText {
            process.executableURL = URL(fileURLWithPath: osascriptPath)
            process.arguments = ["-", acceptedText]
            process.standardInput = standardInput
        } else {
            process.executableURL = URL(fileURLWithPath: osascriptPath)
            process.arguments = ["-e", scriptSource]
        }
        var environment = ProcessInfo.processInfo.environment
        environment["AUTOCOMPLETE_LAB_GHOSTTY_ACCEPTED_TEXT"] = acceptedText
        process.environment = environment
        process.standardOutput = standardOutput
        process.standardError = standardError

        do {
            try process.run()
            if launchThroughShell || usesArgumentText {
                standardInput.fileHandleForWriting.write(Data(scriptSource.utf8))
                try? standardInput.fileHandleForWriting.close()
            }
        } catch {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-front-window-input-launch-failed",
                    "source": source,
                    "errorMessage": String(String(describing: error).prefix(160))
                ]
            )
            return (false, true, false)
        }

        guard Self.waitForProcessExit(
            process,
            timeoutSeconds: 1.2,
            pollIntervalSeconds: 0.02
        ) else {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.05)
            if process.isRunning {
                process.interrupt()
            }
            guard Self.waitForProcessExit(
                process,
                timeoutSeconds: 0.25,
                pollIntervalSeconds: 0.02
            ) else {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": "ghostty-front-window-input-timeout-still-running",
                        "source": source
                    ]
                )
                return (false, false, false)
            }
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-front-window-input-timeout",
                    "source": source
                ]
            )
            let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: profile,
                attempts: 4
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "source": "ghosttyFrontWindowInputTextTimeoutBaseline",
                    "verified": String(promptStayedUnchanged)
                ]
            )
            return (false, promptStayedUnchanged, false)
        }

        let stdoutText = String(
            data: standardOutput.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderrText = String(
            data: standardError.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0 else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-front-window-input-failed",
                    "source": source,
                    "exitStatus": String(process.terminationStatus),
                    "errorMessage": String(stderrText.prefix(160))
                ]
            )
            return (false, true, false)
        }

        guard stdoutText != "false" else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-front-window-input-returned-false",
                    "source": source
                ]
            )
            return (false, true, false)
        }

        let verified = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: expectedProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 24
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "posted": "true",
                "source": source,
                "verified": String(verified),
                "launchMode": launchThroughShell ? "shell" : "direct",
                "textTransport": usesArgumentText ? "argv" : "environment"
            ]
        )
        if verified {
            return (true, false, true)
        }

        let screenCopyOutcome = verifyGhosttyTerminalHostProofWithNativeScreenCopy(
            source: launchThroughShell
                ? "ghosttyLoginShellFrontWindowInputTextScreenCopy"
                : "ghosttyFrontWindowInputTextScreenCopy",
            expectedProofInputText: expectedProofInputText,
            originalProofInputText: originalProofInputText,
            frontmostApp: frontmostApp
        )
        if screenCopyOutcome.verified {
            return (true, false, true)
        }
        guard screenCopyOutcome.safeToContinue else {
            return (false, false, false)
        }

        let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: originalProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 4
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "source": baselineSource,
                "verified": String(promptStayedUnchanged)
            ]
        )
        guard promptStayedUnchanged else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-front-window-input-unverified-mutated-input",
                    "source": baselineSource
                ]
            )
            return (false, false, false)
        }
        return (
            false,
            true,
            screenCopyOutcome.nativeNoopClassified || screenCopyOutcome.promptStayedUnchanged == true
        )
    }

    private func focusGhosttyTerminalHostProofPromptByClickIfAvailable(source: String) -> Bool {
        guard let caretBounds = currentSuggestionState.acceptanceSnapshot?.targetFingerprint.caretBounds else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-prompt-focus-click-missing-caret",
                    "source": source
                ]
            )
            return false
        }

        let point = CGPoint(
            x: CGFloat(caretBounds.x + max(1, caretBounds.width)),
            y: CGFloat(caretBounds.y + max(1, caretBounds.height / 2))
        )
        guard point.x.isFinite, point.y.isFinite,
              let eventSource = CGEventSource(stateID: .hidSystemState),
              let mouseMove = CGEvent(
                mouseEventSource: eventSource,
                mouseType: .mouseMoved,
                mouseCursorPosition: point,
                mouseButton: .left
              ),
              let mouseDown = CGEvent(
                mouseEventSource: eventSource,
                mouseType: .leftMouseDown,
                mouseCursorPosition: point,
                mouseButton: .left
              ),
              let mouseUp = CGEvent(
                mouseEventSource: eventSource,
                mouseType: .leftMouseUp,
                mouseCursorPosition: point,
                mouseButton: .left
              ) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-prompt-focus-click-event-create-failed",
                    "source": source
                ]
            )
            return false
        }

        mouseMove.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.02)
        mouseDown.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.035)
        mouseUp.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.08)
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "posted": "true",
                "source": source,
                "x": String(Int(point.x.rounded())),
                "y": String(Int(point.y.rounded()))
            ]
        )
        return true
    }

    private func prepareGhosttyTerminalHostProofInsertionTarget(
        frontmostApp: RunningApplicationInfo,
        originalProofInputText: String,
        profile: CompatibilityProfile?
    ) -> Bool {
        guard frontmostApp.bundleIdentifier == "com.mitchellh.ghostty" else {
            return true
        }

        let activated = NSRunningApplication(processIdentifier: frontmostApp.processIdentifier)?
            .activate(options: [.activateAllWindows]) ?? false
        let pidReasserted = reassertGhosttyTerminalHostProofFrontmostProcess(
            frontmostApp: frontmostApp,
            source: "ghosttyFocusPidReassertion"
        )
        Thread.sleep(forTimeInterval: 0.04)
        let proofPromptVerified = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: originalProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 6,
            delaySeconds: 0.03
        )
        let verified = proofPromptVerified && (pidReasserted || activated)
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "source": "ghosttyFocusReassertion",
                "activated": String(activated),
                "pidReasserted": String(pidReasserted),
                "proofPromptVerified": String(proofPromptVerified),
                "verificationTrust": pidReasserted
                    ? "pidReasserted"
                    : (activated ? "activatedVerifiedPrompt" : "none"),
                "verified": String(verified)
            ]
        )
        return verified
    }

    private func reassertGhosttyTerminalHostProofFrontmostProcess(
        frontmostApp: RunningApplicationInfo,
        source: String
    ) -> Bool {
        guard frontmostApp.bundleIdentifier == "com.mitchellh.ghostty" else {
            return true
        }

        let osascriptPath = "/usr/bin/osascript"
        guard FileManager.default.isExecutableFile(atPath: osascriptPath) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-frontmost-pid-reassertion-osascript-missing",
                    "source": source
                ]
            )
            return false
        }

        let scriptSource = """
        set targetProcessId to (system attribute "AUTOCOMPLETE_LAB_GHOSTTY_TARGET_PID") as integer
        tell application "System Events"
            set ghosttyProcess to first application process whose unix id is targetProcessId
            if bundle identifier of ghosttyProcess is not "com.mitchellh.ghostty" then error "Target Ghostty process bundle mismatch."
            set frontmost of ghosttyProcess to true
            delay 0.04
            if frontmost of ghosttyProcess then
                return "true"
            end if
        end tell
        return "false"
        """

        let standardOutput = Pipe()
        let standardError = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: osascriptPath)
        process.arguments = ["-e", scriptSource]
        process.standardOutput = standardOutput
        process.standardError = standardError
        var environment = ProcessInfo.processInfo.environment
        environment["AUTOCOMPLETE_LAB_GHOSTTY_TARGET_PID"] = String(frontmostApp.processIdentifier)
        process.environment = environment

        do {
            try process.run()
        } catch {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "pid": String(frontmostApp.processIdentifier),
                    "posted": "false",
                    "reason": "ghostty-frontmost-pid-reassertion-launch-failed",
                    "source": source,
                    "errorMessage": String(String(describing: error).prefix(160))
                ]
            )
            return false
        }

        guard Self.waitForProcessExit(
            process,
            timeoutSeconds: 1.0,
            pollIntervalSeconds: 0.02
        ) else {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.05)
            if process.isRunning {
                process.interrupt()
            }
            let exitedAfterTerminate = Self.waitForProcessExit(
                process,
                timeoutSeconds: 0.25,
                pollIntervalSeconds: 0.02
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "pid": String(frontmostApp.processIdentifier),
                    "posted": "false",
                    "reason": exitedAfterTerminate
                        ? "ghostty-frontmost-pid-reassertion-timeout"
                        : "ghostty-frontmost-pid-reassertion-timeout-still-running",
                    "source": source,
                    "timeoutMilliseconds": "1000"
                ]
            )
            return false
        }

        let stdoutText = String(
            data: standardOutput.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderrText = String(
            data: standardError.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let verified = process.terminationStatus == 0 && stdoutText == "true"
        var metadata: [String: String] = [
            "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
            "exitStatus": String(process.terminationStatus),
            "pid": String(frontmostApp.processIdentifier),
            "source": source,
            "verified": String(verified)
        ]
        if !verified {
            metadata["posted"] = "false"
            metadata["reason"] = process.terminationStatus == 0
                ? "ghostty-frontmost-pid-reassertion-not-frontmost"
                : "ghostty-frontmost-pid-reassertion-script-failed"
            metadata["scriptOutput"] = String(stdoutText.prefix(80))
        }
        if !stderrText.isEmpty {
            metadata["errorMessage"] = String(stderrText.prefix(160))
        }
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: metadata
        )
        return verified
    }

    private func insertClaudeCodeTerminalHostProofPasteboardText(
        _ acceptedText: String,
        expectedProofInputText: String,
        originalProofInputText: String,
        frontmostApp: RunningApplicationInfo,
        profile: CompatibilityProfile?
    ) -> (verified: Bool, safeToContinue: Bool) {
        guard !acceptedText.isEmpty,
              !acceptedText.contains(where: \.isNewline) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "pasteboard-text-not-one-line",
                    "source": "pasteboardCommandV"
                ]
            )
            return (false, false)
        }

        let pasteboard = NSPasteboard.general
        let originalItems = Self.clonePasteboardItems(pasteboard.pasteboardItems)
        func restoreOriginalPasteboard() {
            pasteboard.clearContents()
            if !originalItems.isEmpty {
                pasteboard.writeObjects(originalItems)
            }
        }

        func setPasteboardString(for source: String) -> Int? {
            pasteboard.clearContents()
            guard pasteboard.setString(acceptedText, forType: .string) else {
                restoreOriginalPasteboard()
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": "pasteboard-set-failed",
                        "source": source
                    ]
                )
                return nil
            }
            return pasteboard.changeCount
        }

        func tryPasteboardCommandV(
            source: String,
            baselineSource: String,
            failedReason: String,
            mutatedInputReason: String,
            processIdentifier: pid_t?,
            tapLocation: CGEventTapLocation = .cghidEventTap,
            restoreSynchronouslyOnMiss: Bool,
            deferPasteboardRestoreOnMiss: Bool = true
        ) -> (verified: Bool, safeToContinue: Bool) {
            if frontmostApp.bundleIdentifier == "com.mitchellh.ghostty",
               !reassertGhosttyTerminalHostProofFrontmostProcess(
                   frontmostApp: frontmostApp,
                   source: "\(source)FrontmostPidReassertion"
               ) {
                return (false, true)
            }
            guard let fallbackChangeCount = setPasteboardString(for: source) else {
                return (false, false)
            }

            let postedCommandV = tapLocation == .cghidEventTap
                ? Self.postCommandVKey(processIdentifier: processIdentifier)
                : Self.postCommandVKey(processIdentifier: processIdentifier, tapLocation: tapLocation)
            guard postedCommandV else {
                if restoreSynchronouslyOnMiss {
                    restoreOriginalPasteboard()
                } else if deferPasteboardRestoreOnMiss {
                    schedulePasteboardRestore(
                        insertedText: acceptedText,
                        fallbackChangeCount: fallbackChangeCount,
                        originalItems: originalItems,
                        delaySeconds: 0.05
                    )
                } else {
                    DiagnosticsLog.shared.record(
                        "claude-code-terminal-host-proof-insert",
                        metadata: [
                            "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                            "source": "\(source)RestoreDeferredToNextAttempt",
                            "verified": "false"
                        ]
                    )
                }
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": failedReason,
                        "source": source
                    ]
                )
                return (false, true)
            }

            let verified = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: expectedProofInputText,
                frontmostApp: frontmostApp,
                profile: profile,
                attempts: 24
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "true",
                    "source": source,
                    "verified": String(verified)
                ]
            )
            if verified {
                schedulePasteboardRestore(
                    insertedText: acceptedText,
                    fallbackChangeCount: fallbackChangeCount,
                    originalItems: originalItems,
                    delaySeconds: 0.35
                )
                return (true, false)
            }

            let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: profile,
                attempts: 4
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "source": baselineSource,
                    "verified": String(promptStayedUnchanged)
                ]
            )
            if restoreSynchronouslyOnMiss {
                restoreOriginalPasteboard()
            } else if deferPasteboardRestoreOnMiss {
                schedulePasteboardRestore(
                    insertedText: acceptedText,
                    fallbackChangeCount: fallbackChangeCount,
                    originalItems: originalItems,
                    delaySeconds: 0.05
                )
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "source": "\(source)RestoreScheduled",
                        "verified": String(promptStayedUnchanged)
                    ]
                )
            } else {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "source": "\(source)RestoreDeferredToNextAttempt",
                        "verified": String(promptStayedUnchanged)
                    ]
                )
            }
            if !promptStayedUnchanged {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": mutatedInputReason,
                        "source": baselineSource
                    ]
                )
            }
            return (false, promptStayedUnchanged)
        }

        let targetedPasteOutcome = tryPasteboardCommandV(
            source: "pasteboardCommandVToPid",
            baselineSource: "pasteboardCommandVToPidBaseline",
            failedReason: "pasteboard-command-v-to-pid-failed",
            mutatedInputReason: "pasteboard-to-pid-unverified-mutated-input",
            processIdentifier: frontmostApp.processIdentifier,
            restoreSynchronouslyOnMiss: true
        )
        if targetedPasteOutcome.verified {
            return (true, false)
        }
        guard targetedPasteOutcome.safeToContinue else {
            return (false, false)
        }

        let shouldRunSessionTapPasteProbe =
            ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_GHOSTTY_SESSION_TAP_PASTE_PROBE"] == "1"
        if shouldRunSessionTapPasteProbe {
            let sessionPasteOutcome = tryPasteboardCommandV(
                source: "pasteboardCommandVSession",
                baselineSource: "pasteboardCommandVSessionBaseline",
                failedReason: "pasteboard-command-v-session-failed",
                mutatedInputReason: "pasteboard-session-unverified-mutated-input",
                processIdentifier: nil,
                tapLocation: .cgSessionEventTap,
                restoreSynchronouslyOnMiss: false,
                deferPasteboardRestoreOnMiss: false
            )
            if sessionPasteOutcome.verified {
                return (true, false)
            }
            guard sessionPasteOutcome.safeToContinue else {
                return (false, false)
            }
        } else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "session-tap-probe-disabled",
                    "source": "pasteboardCommandVSession"
                ]
            )
        }

        let globalPasteOutcome = tryPasteboardCommandV(
            source: "pasteboardCommandV",
            baselineSource: "pasteboardCommandVBaseline",
            failedReason: "pasteboard-command-v-failed",
            mutatedInputReason: "pasteboard-unverified-mutated-input",
            processIdentifier: nil,
            restoreSynchronouslyOnMiss: false
        )
        if globalPasteOutcome.verified {
            return (true, false)
        }
        return (false, globalPasteOutcome.safeToContinue)
    }

    private func insertGhosttyTerminalHostProofPasteAction(
        _ acceptedText: String,
        expectedProofInputText: String,
        originalProofInputText: String,
        frontmostApp: RunningApplicationInfo,
        profile: CompatibilityProfile?
    ) -> (verified: Bool, safeToContinue: Bool, nativeNoopClassified: Bool) {
        let source = "ghosttyPerformActionPasteFromClipboard"
        let baselineSource = "ghosttyPerformActionPasteFromClipboardBaseline"
        guard !acceptedText.isEmpty,
              !acceptedText.contains(where: \.isNewline) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-paste-action-text-not-one-line",
                    "source": source
                ]
            )
            return (false, false, false)
        }

        let osascriptPath = "/usr/bin/osascript"
        guard FileManager.default.isExecutableFile(atPath: osascriptPath) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-paste-action-osascript-missing",
                    "source": source
                ]
            )
            return (false, false, false)
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
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-paste-action-pasteboard-set-failed",
                    "source": source
                ]
            )
            return (false, false, false)
        }
        let fallbackChangeCount = pasteboard.changeCount

        let scriptSource = """
        set proofMarker to system attribute "AUTOCOMPLETE_LAB_GHOSTTY_PROOF_MARKER"
        set compactProofMarker to system attribute "AUTOCOMPLETE_LAB_GHOSTTY_COMPACT_PROOF_MARKER"
        set targetProcessId to (system attribute "AUTOCOMPLETE_LAB_GHOSTTY_TARGET_PID") as integer
        set targetWindow to missing value
        set targetWindowName to ""
        set targetWindowNameIsProof to false
        tell application "System Events"
            set ghosttyProcess to first application process whose unix id is targetProcessId
            if bundle identifier of ghosttyProcess is not "com.mitchellh.ghostty" then error "Target Ghostty process bundle mismatch."
            set frontmost of ghosttyProcess to true
            delay 0.04
            if frontmost of ghosttyProcess is false then error "Target Ghostty process is not frontmost."
            try
                set targetWindowName to name of front window of ghosttyProcess as text
                if targetWindowName contains proofMarker or targetWindowName contains compactProofMarker then set targetWindowNameIsProof to true
            end try
        end tell
        tell application id "com.mitchellh.ghostty"
            repeat with candidateWindow in windows
                set windowName to name of candidateWindow as text
                if targetWindowNameIsProof and targetWindowName is not "" and windowName is targetWindowName then
                    set targetWindow to candidateWindow
                    exit repeat
                end if
            end repeat
            if targetWindow is missing value then
                repeat with candidateWindow in windows
                    set windowName to name of candidateWindow as text
                    if windowName contains proofMarker or windowName contains compactProofMarker then
                        set targetWindow to candidateWindow
                        exit repeat
                    end if
                end repeat
            end if
            if targetWindow is missing value then return false
            set targetTab to selected tab of targetWindow
            set targetTerminal to focused terminal of targetTab
            activate window targetWindow
            select tab targetTab
            focus targetTerminal
            activate
        end tell
        delay 0.02
        tell application "System Events"
            set ghosttyProcess to first application process whose unix id is targetProcessId
            if bundle identifier of ghosttyProcess is not "com.mitchellh.ghostty" then error "Target Ghostty process bundle mismatch."
            set frontmost of ghosttyProcess to true
            delay 0.04
            if frontmost of ghosttyProcess is false then error "Target Ghostty process is not frontmost."
        end tell
        tell application id "com.mitchellh.ghostty"
            set actionPerformed to perform action "paste_from_clipboard" on targetTerminal
            return actionPerformed
        end tell
        """

        let standardOutput = Pipe()
        let standardError = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: osascriptPath)
        process.arguments = ["-e", scriptSource]
        var environment = ProcessInfo.processInfo.environment
        environment["AUTOCOMPLETE_LAB_GHOSTTY_PROOF_MARKER"] =
            ClaudeCodeTerminalHostProofPolicy.proofMarker
        environment["AUTOCOMPLETE_LAB_GHOSTTY_COMPACT_PROOF_MARKER"] =
            ClaudeCodeTerminalHostProofPolicy.compactProofMarker
        environment["AUTOCOMPLETE_LAB_GHOSTTY_TARGET_PID"] = String(frontmostApp.processIdentifier)
        process.environment = environment
        process.standardOutput = standardOutput
        process.standardError = standardError

        do {
            try process.run()
        } catch {
            restoreOriginalPasteboard()
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-paste-action-script-launch-failed",
                    "source": source,
                    "errorMessage": String(String(describing: error).prefix(160))
                ]
            )
            return (false, true, false)
        }

        guard Self.waitForProcessExit(
            process,
            timeoutSeconds: 1.2,
            pollIntervalSeconds: 0.02
        ) else {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.05)
            if process.isRunning {
                process.interrupt()
            }
            let exitedAfterTerminate = Self.waitForProcessExit(
                process,
                timeoutSeconds: 0.25,
                pollIntervalSeconds: 0.02
            )
            restoreOriginalPasteboard()
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": exitedAfterTerminate
                        ? "ghostty-paste-action-script-timeout"
                        : "ghostty-paste-action-script-timeout-still-running",
                    "source": source
                ]
            )
            guard exitedAfterTerminate else {
                return (false, false, false)
            }
            let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: profile,
                attempts: 4
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "source": "ghosttyPerformActionPasteFromClipboardTimeoutBaseline",
                    "verified": String(promptStayedUnchanged)
                ]
            )
            guard promptStayedUnchanged else {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": "ghostty-paste-action-timeout-mutated-input",
                        "source": "ghosttyPerformActionPasteFromClipboardTimeoutBaseline"
                    ]
                )
                return (false, false, false)
            }
            return (false, true, false)
        }

        let stdoutText = String(
            data: standardOutput.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderrText = String(
            data: standardError.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0 else {
            restoreOriginalPasteboard()
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-paste-action-script-failed",
                    "source": source,
                    "exitStatus": String(process.terminationStatus),
                    "errorMessage": String(stderrText.prefix(160))
                ]
            )
            return (false, true, false)
        }

        guard stdoutText != "false" else {
            restoreOriginalPasteboard()
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-paste-action-proof-window-missing",
                    "source": source
                ]
            )
            return (false, true, false)
        }

        let verified = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: expectedProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 24
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "posted": "true",
                "source": source,
                "verified": String(verified),
                "actionPerformed": "true",
                "exitStatus": String(process.terminationStatus),
                "errorMessage": String(stderrText.prefix(160))
            ]
        )
        if verified {
            schedulePasteboardRestore(
                insertedText: acceptedText,
                fallbackChangeCount: fallbackChangeCount,
                originalItems: originalItems,
                delaySeconds: 0.35
            )
            return (true, false, true)
        }

        restoreOriginalPasteboard()
        let screenCopyOutcome = verifyGhosttyTerminalHostProofWithNativeScreenCopy(
            source: "ghosttyPerformActionPasteFromClipboardScreenCopy",
            expectedProofInputText: expectedProofInputText,
            originalProofInputText: originalProofInputText,
            frontmostApp: frontmostApp
        )
        if screenCopyOutcome.verified {
            return (true, false, true)
        }
        guard screenCopyOutcome.safeToContinue else {
            return (false, false, false)
        }

        let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: originalProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 4
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "source": baselineSource,
                "verified": String(promptStayedUnchanged)
            ]
        )
        guard promptStayedUnchanged else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-paste-action-unverified-mutated-input",
                    "source": baselineSource
                ]
            )
            return (false, false, false)
        }
        return (
            false,
            true,
            screenCopyOutcome.nativeNoopClassified || screenCopyOutcome.promptStayedUnchanged == true
        )
    }

    private func insertGhosttyTerminalHostProofBundleSystemEventsRawKeystroke(
        _ acceptedText: String,
        expectedProofInputText: String,
        originalProofInputText: String,
        frontmostApp: RunningApplicationInfo,
        profile: CompatibilityProfile?,
        source: String = "ghosttyBundleSystemEventsRawKeystroke",
        baselineSource: String = "ghosttyBundleSystemEventsRawKeystrokeBaseline",
        stopReason: String? = "ghostty-bundle-system-events-raw-insertion"
    ) -> (verified: Bool, safeToContinue: Bool) {
        guard !acceptedText.isEmpty,
              !acceptedText.contains(where: \.isNewline) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-bundle-system-events-raw-text-not-one-line",
                    "source": source
                ]
            )
            return (false, false)
        }

        let osascriptPath = "/usr/bin/osascript"
        guard FileManager.default.isExecutableFile(atPath: osascriptPath) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-bundle-system-events-raw-osascript-missing",
                    "source": source
                ]
            )
            return (false, false)
        }

        let scriptSource = """
        set acceptedText to system attribute "AUTOCOMPLETE_LAB_GHOSTTY_ACCEPTED_TEXT"
        set hostBundle to system attribute "AUTOCOMPLETE_LAB_GHOSTTY_HOST_BUNDLE"
        tell application "System Events"
            set hostIsFrontmost to false
            repeat with frontApp in (application processes whose frontmost is true)
                try
                    if bundle identifier of frontApp is hostBundle then set hostIsFrontmost to true
                end try
            end repeat
            if hostIsFrontmost is false then error "Ghostty host is not frontmost for raw proof typing."
            keystroke acceptedText
        end tell
        return true
        """

        let standardOutput = Pipe()
        let standardError = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: osascriptPath)
        process.arguments = ["-e", scriptSource]
        process.standardOutput = standardOutput
        process.standardError = standardError
        var environment = ProcessInfo.processInfo.environment
        environment["AUTOCOMPLETE_LAB_GHOSTTY_ACCEPTED_TEXT"] = acceptedText
        environment["AUTOCOMPLETE_LAB_GHOSTTY_HOST_BUNDLE"] = frontmostApp.bundleIdentifier
        process.environment = environment

        let stoppedKeyboardTap = stopReason != nil
        if let stopReason {
            stopKeyboardEventTapNow(reason: stopReason)
        }

        do {
            try process.run()
        } catch {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-bundle-system-events-raw-launch-failed",
                    "source": source,
                    "errorMessage": String(String(describing: error).prefix(160))
                ]
            )
            return (false, true)
        }

        guard Self.waitForProcessExit(
            process,
            timeoutSeconds: 1.5,
            pollIntervalSeconds: 0.02
        ) else {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.05)
            if process.isRunning {
                process.interrupt()
            }
            guard Self.waitForProcessExit(
                process,
                timeoutSeconds: 0.25,
                pollIntervalSeconds: 0.02
            ) else {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": "ghostty-bundle-system-events-raw-timeout-still-running",
                        "source": source
                    ]
                )
                return (false, false)
            }
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-bundle-system-events-raw-timeout",
                    "source": source
                ]
            )
            let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: profile,
                attempts: 4
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "source": baselineSource,
                    "verified": String(promptStayedUnchanged)
                ]
            )
            return (false, promptStayedUnchanged)
        }

        let stdoutText = String(
            data: standardOutput.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderrText = String(
            data: standardError.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0 else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-bundle-system-events-raw-failed",
                    "source": source,
                    "exitStatus": String(process.terminationStatus),
                    "errorMessage": String(stderrText.prefix(160))
                ]
            )
            return (false, true)
        }
        guard stdoutText != "false" else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-bundle-system-events-raw-returned-false",
                    "source": source
                ]
            )
            return (false, true)
        }

        let verified = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: expectedProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 24
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "posted": "true",
                "source": source,
                "verified": String(verified),
                "focusMode": "frontmostBundleOnly",
                "keystrokeMode": "bulk",
                "launchMode": "direct",
                "textTransport": "environment",
                "keyboardTapStopped": String(stoppedKeyboardTap),
                "exitStatus": String(process.terminationStatus),
                "errorMessage": String(stderrText.prefix(160))
            ]
        )
        if verified {
            return (true, false)
        }

        let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: originalProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 4
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "source": baselineSource,
                "verified": String(promptStayedUnchanged)
            ]
        )
        guard promptStayedUnchanged else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-bundle-system-events-raw-unverified-mutated-input",
                    "source": baselineSource
                ]
            )
            return (false, false)
        }
        return (false, true)
    }

    private func insertGhosttyTerminalHostProofFocusedSystemEventsBulkKeystroke(
        _ acceptedText: String,
        expectedProofInputText: String,
        originalProofInputText: String,
        frontmostApp: RunningApplicationInfo,
        profile: CompatibilityProfile?
    ) -> (verified: Bool, safeToContinue: Bool) {
        let source = "ghosttyFocusedSystemEventsBulkKeystroke"
        let baselineSource = "ghosttyFocusedSystemEventsBulkKeystrokeBaseline"
        guard !acceptedText.isEmpty,
              !acceptedText.contains(where: \.isNewline) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-focused-system-events-text-not-one-line",
                    "source": source
                ]
            )
            return (false, false)
        }

        let osascriptPath = "/usr/bin/osascript"
        guard FileManager.default.isExecutableFile(atPath: osascriptPath) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-focused-system-events-osascript-missing",
                    "source": source
                ]
            )
            return (false, false)
        }

        let scriptSource = """
        set acceptedText to system attribute "AUTOCOMPLETE_LAB_GHOSTTY_ACCEPTED_TEXT"
        set targetProcessId to (system attribute "AUTOCOMPLETE_LAB_GHOSTTY_TARGET_PID") as integer
        tell application "System Events"
            set ghosttyProcess to first application process whose unix id is targetProcessId
            if bundle identifier of ghosttyProcess is not "com.mitchellh.ghostty" then error "Target Ghostty process bundle mismatch."
            set frontmost of ghosttyProcess to true
            delay 0.06
            if frontmost of ghosttyProcess is false then error "Target Ghostty process is not frontmost."
            keystroke acceptedText
        end tell
        return true
        """

        let standardOutput = Pipe()
        let standardError = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: osascriptPath)
        process.arguments = ["-e", scriptSource]
        process.standardOutput = standardOutput
        process.standardError = standardError
        var environment = ProcessInfo.processInfo.environment
        environment["AUTOCOMPLETE_LAB_GHOSTTY_ACCEPTED_TEXT"] = acceptedText
        environment["AUTOCOMPLETE_LAB_GHOSTTY_TARGET_PID"] = String(frontmostApp.processIdentifier)
        process.environment = environment

        stopKeyboardEventTapNow(reason: "ghostty-focused-system-events-bulk-insertion")

        do {
            try process.run()
        } catch {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-focused-system-events-launch-failed",
                    "source": source,
                    "errorMessage": String(String(describing: error).prefix(160))
                ]
            )
            return (false, true)
        }

        guard Self.waitForProcessExit(
            process,
            timeoutSeconds: 1.5,
            pollIntervalSeconds: 0.02
        ) else {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.05)
            if process.isRunning {
                process.interrupt()
            }
            guard Self.waitForProcessExit(
                process,
                timeoutSeconds: 0.25,
                pollIntervalSeconds: 0.02
            ) else {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": "ghostty-focused-system-events-timeout-still-running",
                        "source": source
                    ]
                )
                return (false, false)
            }
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-focused-system-events-timeout",
                    "source": source
                ]
            )
            let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: profile,
                attempts: 4
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "source": baselineSource,
                    "verified": String(promptStayedUnchanged)
                ]
            )
            return (false, promptStayedUnchanged)
        }

        let stdoutText = String(
            data: standardOutput.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderrText = String(
            data: standardError.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0 else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-focused-system-events-failed",
                    "source": source,
                    "exitStatus": String(process.terminationStatus),
                    "errorMessage": String(stderrText.prefix(160))
                ]
            )
            return (false, true)
        }
        guard stdoutText != "false" else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-focused-system-events-returned-false",
                    "source": source
                ]
            )
            return (false, true)
        }

        let verified = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: expectedProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 24
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "posted": "true",
                "source": source,
                "verified": String(verified),
                "focusMode": "frontmostProcessOnly",
                "keystrokeMode": "bulk",
                "launchMode": "direct",
                "textTransport": "environment",
                "exitStatus": String(process.terminationStatus),
                "errorMessage": String(stderrText.prefix(160))
            ]
        )
        if verified {
            return (true, false)
        }

        let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: originalProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 4
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "source": baselineSource,
                "verified": String(promptStayedUnchanged)
            ]
        )
        guard promptStayedUnchanged else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-focused-system-events-unverified-mutated-input",
                    "source": baselineSource
                ]
            )
            return (false, false)
        }
        return (false, true)
    }

    private func insertGhosttyTerminalHostProofSystemEventsKeystroke(
        _ acceptedText: String,
        expectedProofInputText: String,
        originalProofInputText: String,
        frontmostApp: RunningApplicationInfo,
        profile: CompatibilityProfile?,
        delayMilliseconds: Int = 80,
        keyDelayMilliseconds: Int = 18,
        bulkKeystroke: Bool = false,
        launchThroughShell: Bool = false
    ) -> (verified: Bool, safeToContinue: Bool) {
        let source: String
        let baselineSource: String
        if launchThroughShell && bulkKeystroke {
            source = "ghosttySystemEventsLoginShellBulkKeystroke"
            baselineSource = "ghosttySystemEventsLoginShellBulkKeystrokeBaseline"
        } else if bulkKeystroke {
            source = "ghosttySystemEventsBulkKeystrokeShell"
            baselineSource = "ghosttySystemEventsBulkKeystrokeShellBaseline"
        } else {
            source = "ghosttySystemEventsKeystrokeShell"
            baselineSource = "ghosttySystemEventsKeystrokeShellBaseline"
        }
        let keystrokeMode = bulkKeystroke ? "bulk" : "perCharacter"
        let mutatedInputReason = bulkKeystroke
            ? "ghostty-system-events-bulk-unverified-mutated-input"
            : "ghostty-system-events-unverified-mutated-input"
        guard !acceptedText.isEmpty,
              !acceptedText.contains(where: \.isNewline) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-system-events-text-not-one-line",
                    "source": source
                ]
            )
            return (false, false)
        }

        let osascriptPath = "/usr/bin/osascript"
        guard FileManager.default.isExecutableFile(atPath: osascriptPath) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-system-events-osascript-missing",
                    "source": source
                ]
            )
            return (false, false)
        }

        let shellPath = "/bin/zsh"
        if launchThroughShell,
           !FileManager.default.isExecutableFile(atPath: shellPath) {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-system-events-shell-missing",
                    "source": source
                ]
            )
            return (false, true)
        }

        let proofMarker = ClaudeCodeTerminalHostProofPolicy.proofMarker
        let compactProofMarker = ClaudeCodeTerminalHostProofPolicy.compactProofMarker
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "stage": "delayed-start",
                "source": source,
                "delayMilliseconds": String(delayMilliseconds)
            ]
        )
        Thread.sleep(forTimeInterval: TimeInterval(delayMilliseconds) / 1_000)
        let scriptSource = """
        set acceptedText to system attribute "AUTOCOMPLETE_LAB_GHOSTTY_ACCEPTED_TEXT"
        set proofMarker to system attribute "AUTOCOMPLETE_LAB_GHOSTTY_PROOF_MARKER"
        set compactProofMarker to system attribute "AUTOCOMPLETE_LAB_GHOSTTY_COMPACT_PROOF_MARKER"
        set targetProcessId to (system attribute "AUTOCOMPLETE_LAB_GHOSTTY_TARGET_PID") as integer
        set keyDelay to (system attribute "AUTOCOMPLETE_LAB_GHOSTTY_KEY_DELAY_SECONDS") as real
        set keystrokeMode to system attribute "AUTOCOMPLETE_LAB_GHOSTTY_KEYSTROKE_MODE"
        set targetWindow to missing value
        set targetWindowName to ""
        set targetWindowNameIsProof to false
        tell application "System Events"
            set ghosttyProcess to first application process whose unix id is targetProcessId
            if bundle identifier of ghosttyProcess is not "com.mitchellh.ghostty" then error "Target Ghostty process bundle mismatch."
            set frontmost of ghosttyProcess to true
            delay 0.04
            if frontmost of ghosttyProcess is false then error "Target Ghostty process is not frontmost."
            try
                set targetWindowName to name of front window of ghosttyProcess as text
                if targetWindowName contains proofMarker or targetWindowName contains compactProofMarker then set targetWindowNameIsProof to true
            end try
        end tell
        tell application id "com.mitchellh.ghostty"
            repeat with candidateWindow in windows
                set windowName to name of candidateWindow as text
                if targetWindowNameIsProof and targetWindowName is not "" and windowName is targetWindowName then
                    set targetWindow to candidateWindow
                    exit repeat
                end if
            end repeat
            if targetWindow is missing value then
                repeat with candidateWindow in windows
                    set windowName to name of candidateWindow as text
                    if windowName contains proofMarker or windowName contains compactProofMarker then
                        set targetWindow to candidateWindow
                        exit repeat
                    end if
                end repeat
            end if
            if targetWindow is missing value then return false
            activate window targetWindow
            set targetTab to selected tab of targetWindow
            set targetTerminal to focused terminal of targetTab
            select tab targetTab
            focus targetTerminal
            activate
        end tell
        delay 0.02
        tell application "System Events"
            set ghosttyProcess to first application process whose unix id is targetProcessId
            if bundle identifier of ghosttyProcess is not "com.mitchellh.ghostty" then error "Target Ghostty process bundle mismatch."
            set frontmost of ghosttyProcess to true
            delay 0.04
            if frontmost of ghosttyProcess is false then error "Target Ghostty process is not frontmost."
            if keystrokeMode is "bulk" then
                keystroke acceptedText
            else
                repeat with characterIndex from 1 to count characters of acceptedText
                    keystroke character characterIndex of acceptedText
                    delay keyDelay
                end repeat
            end if
        end tell
        return true
        """
        let standardOutput = Pipe()
        let standardError = Pipe()
        let standardInput = Pipe()
        let process = Process()
        if launchThroughShell {
            process.executableURL = URL(fileURLWithPath: shellPath)
            process.arguments = ["-lc", "exec /usr/bin/osascript"]
            process.standardInput = standardInput
        } else {
            process.executableURL = URL(fileURLWithPath: osascriptPath)
            process.arguments = ["-e", scriptSource]
        }
        var environment = ProcessInfo.processInfo.environment
        environment["AUTOCOMPLETE_LAB_GHOSTTY_ACCEPTED_TEXT"] = acceptedText
        environment["AUTOCOMPLETE_LAB_GHOSTTY_PROOF_MARKER"] = proofMarker
        environment["AUTOCOMPLETE_LAB_GHOSTTY_COMPACT_PROOF_MARKER"] = compactProofMarker
        environment["AUTOCOMPLETE_LAB_GHOSTTY_TARGET_PID"] = String(frontmostApp.processIdentifier)
        environment["AUTOCOMPLETE_LAB_GHOSTTY_KEY_DELAY_SECONDS"] =
            String(format: "%.3f", Double(max(keyDelayMilliseconds, 0)) / 1_000)
        environment["AUTOCOMPLETE_LAB_GHOSTTY_KEYSTROKE_MODE"] = keystrokeMode
        process.environment = environment
        process.standardOutput = standardOutput
        process.standardError = standardError

        stopKeyboardEventTapNow(
            reason: bulkKeystroke
                ? "ghostty-system-events-bulk-insertion"
                : "ghostty-system-events-insertion"
        )

        let keyDelaySeconds = Double(max(keyDelayMilliseconds, 0)) / 1_000
        let scriptTimeoutSeconds = max(
            1.5,
            0.75 + TimeInterval(acceptedText.count) * (bulkKeystroke ? 0.02 : keyDelaySeconds + 0.05)
        )

        do {
            try process.run()
            if launchThroughShell {
                standardInput.fileHandleForWriting.write(Data(scriptSource.utf8))
                try? standardInput.fileHandleForWriting.close()
            }
        } catch {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-system-events-osascript-launch-failed",
                    "source": source,
                    "errorMessage": String(String(describing: error).prefix(160))
                ]
            )
            return (false, true)
        }

        guard Self.waitForProcessExit(
            process,
            timeoutSeconds: scriptTimeoutSeconds,
            pollIntervalSeconds: 0.02
        ) else {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.05)
            if process.isRunning {
                process.interrupt()
            }
            guard Self.waitForProcessExit(
                process,
                timeoutSeconds: 0.25,
                pollIntervalSeconds: 0.02
            ) else {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": "ghostty-system-events-osascript-timeout-still-running",
                        "source": source
                    ]
                )
                return (false, false)
            }
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-system-events-osascript-timeout",
                    "source": source,
                    "timeoutMilliseconds": String(Int(scriptTimeoutSeconds * 1000))
                ]
            )
            let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: profile,
                attempts: 4
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "source": baselineSource,
                    "verified": String(promptStayedUnchanged)
                ]
            )
            guard promptStayedUnchanged else {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": "ghostty-system-events-timeout-mutated-input",
                        "source": baselineSource
                    ]
                )
                return (false, false)
            }
            return (false, true)
        }

        let stdoutText = String(
            data: standardOutput.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
        let errorMessage = String(data: errorData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0 else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-system-events-osascript-failed",
                    "source": source,
                    "exitStatus": String(process.terminationStatus),
                    "errorMessage": String(errorMessage.prefix(160))
                ]
            )
            return (false, true)
        }
        guard stdoutText != "false" else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-system-events-proof-window-missing",
                    "source": source
                ]
            )
            return (false, true)
        }

        let verified = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: expectedProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 24
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "posted": "true",
                "source": source,
                "verified": String(verified),
                "frontWindowCheck": "skipped",
                "keystrokeMode": keystrokeMode,
                "launchMode": launchThroughShell ? "shell" : "direct",
                "keyDelayMilliseconds": String(keyDelayMilliseconds),
                "exitStatus": String(process.terminationStatus),
                "errorMessage": String(errorMessage.prefix(160))
            ]
        )
        if verified {
            return (true, false)
        }

        let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: originalProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 4
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "source": baselineSource,
                "verified": String(promptStayedUnchanged)
            ]
        )
        guard promptStayedUnchanged else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": mutatedInputReason,
                    "source": baselineSource
                ]
            )
            return (false, false)
        }
        return (false, true)
    }

    private func insertGhosttyTerminalHostProofFocusedActionText(
        _ acceptedText: String,
        expectedProofInputText: String,
        originalProofInputText: String,
        frontmostApp: RunningApplicationInfo,
        profile: CompatibilityProfile?
    ) -> (verified: Bool, safeToContinue: Bool, nativeNoopClassified: Bool) {
        let source = "ghosttyFocusedActionText"
        let baselineSource = "ghosttyFocusedActionTextBaseline"
        guard !acceptedText.isEmpty,
              !acceptedText.contains(where: \.isNewline) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-focused-action-text-not-one-line",
                    "source": source
                ]
            )
            return (false, false, false)
        }

        let osascriptPath = "/usr/bin/osascript"
        guard FileManager.default.isExecutableFile(atPath: osascriptPath) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-focused-action-osascript-missing",
                    "source": source
                ]
            )
            return (false, false, false)
        }

        let scriptSource = """
        set actionText to system attribute "AUTOCOMPLETE_LAB_GHOSTTY_ACTION_TEXT"
        set targetProcessId to (system attribute "AUTOCOMPLETE_LAB_GHOSTTY_TARGET_PID") as integer
        tell application "System Events"
            set ghosttyProcess to first application process whose unix id is targetProcessId
            if bundle identifier of ghosttyProcess is not "com.mitchellh.ghostty" then error "Target Ghostty process bundle mismatch."
            set frontmost of ghosttyProcess to true
            delay 0.04
            if frontmost of ghosttyProcess is false then error "Target Ghostty process is not frontmost."
        end tell
        tell application id "com.mitchellh.ghostty"
            set targetWindow to front window
            activate window targetWindow
            set targetTab to selected tab of targetWindow
            set targetTerminal to focused terminal of targetTab
            select tab targetTab
            focus targetTerminal
            activate
        end tell
        delay 0.02
        tell application "System Events"
            set ghosttyProcess to first application process whose unix id is targetProcessId
            if bundle identifier of ghosttyProcess is not "com.mitchellh.ghostty" then error "Target Ghostty process bundle mismatch."
            set frontmost of ghosttyProcess to true
            delay 0.04
            if frontmost of ghosttyProcess is false then error "Target Ghostty process is not frontmost."
        end tell
        tell application id "com.mitchellh.ghostty"
            set actionPerformed to perform action actionText on targetTerminal
            return actionPerformed
        end tell
        """

        let standardOutput = Pipe()
        let standardError = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: osascriptPath)
        process.arguments = ["-e", scriptSource]
        process.standardOutput = standardOutput
        process.standardError = standardError
        var environment = ProcessInfo.processInfo.environment
        environment["AUTOCOMPLETE_LAB_GHOSTTY_ACTION_TEXT"] = Self.ghosttyTextAction(acceptedText)
        environment["AUTOCOMPLETE_LAB_GHOSTTY_TARGET_PID"] = String(frontmostApp.processIdentifier)
        process.environment = environment

        do {
            try process.run()
        } catch {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-focused-action-launch-failed",
                    "source": source,
                    "errorMessage": String(String(describing: error).prefix(160))
                ]
            )
            return (false, true, false)
        }

        guard Self.waitForProcessExit(
            process,
            timeoutSeconds: 1.5,
            pollIntervalSeconds: 0.02
        ) else {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.05)
            if process.isRunning {
                process.interrupt()
            }
            guard Self.waitForProcessExit(
                process,
                timeoutSeconds: 0.25,
                pollIntervalSeconds: 0.02
            ) else {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": "ghostty-focused-action-timeout-still-running",
                        "source": source
                    ]
                )
                return (false, false, false)
            }
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-focused-action-timeout",
                    "source": source
                ]
            )
            let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: profile,
                attempts: 4
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "source": baselineSource,
                    "verified": String(promptStayedUnchanged)
                ]
            )
            guard promptStayedUnchanged else {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": "ghostty-focused-action-timeout-mutated-input",
                        "source": baselineSource
                    ]
                )
                return (false, false, false)
            }
            return (false, promptStayedUnchanged, false)
        }

        let stdoutText = String(
            data: standardOutput.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderrText = String(
            data: standardError.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0 else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-focused-action-failed",
                    "source": source,
                    "exitStatus": String(process.terminationStatus),
                    "errorMessage": String(stderrText.prefix(160))
                ]
            )
            return (false, true, false)
        }
        guard stdoutText != "false" else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-focused-action-returned-false",
                    "source": source
                ]
            )
            return (false, true, false)
        }

        let verified = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: expectedProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 24
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "posted": "true",
                "source": source,
                "verified": String(verified),
                "actionPerformed": "true",
                "focusMode": "frontmostTerminalOnly",
                "launchMode": "direct",
                "textTransport": "environment",
                "exitStatus": String(process.terminationStatus),
                "errorMessage": String(stderrText.prefix(160))
            ]
        )
        if verified {
            return (true, false, true)
        }

        let screenCopyOutcome = verifyGhosttyTerminalHostProofWithNativeScreenCopy(
            source: "ghosttyFocusedActionTextScreenCopy",
            expectedProofInputText: expectedProofInputText,
            originalProofInputText: originalProofInputText,
            frontmostApp: frontmostApp
        )
        if screenCopyOutcome.verified {
            return (true, false, true)
        }
        guard screenCopyOutcome.safeToContinue else {
            return (false, false, false)
        }

        let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: originalProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 4
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "source": baselineSource,
                "verified": String(promptStayedUnchanged)
            ]
        )
        guard promptStayedUnchanged else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-focused-action-unverified-mutated-input",
                    "source": baselineSource
                ]
            )
            return (false, false, false)
        }
        return (
            false,
            true,
            screenCopyOutcome.nativeNoopClassified || screenCopyOutcome.promptStayedUnchanged == true
        )
    }

    private func verifyGhosttyTerminalHostProofWithNativeScreenCopy(
        source: String,
        expectedProofInputText: String,
        originalProofInputText: String,
        frontmostApp: RunningApplicationInfo
    ) -> (
        verified: Bool,
        promptStayedUnchanged: Bool?,
        safeToContinue: Bool,
        nativeNoopClassified: Bool
    ) {
        let osascriptPath = "/usr/bin/osascript"
        guard FileManager.default.isExecutableFile(atPath: osascriptPath) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-screen-copy-osascript-missing",
                    "source": source
                ]
            )
            return (false, nil, true, false)
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
        let clearedChangeCount = pasteboard.changeCount
        defer {
            restoreOriginalPasteboard()
        }

        let scriptSource = """
        set targetProcessId to (system attribute "AUTOCOMPLETE_LAB_GHOSTTY_TARGET_PID") as integer
        set proofMarker to system attribute "AUTOCOMPLETE_LAB_GHOSTTY_PROOF_MARKER"
        set compactProofMarker to system attribute "AUTOCOMPLETE_LAB_GHOSTTY_COMPACT_PROOF_MARKER"
        set targetWindow to missing value
        set targetWindowName to ""
        set targetWindowNameIsProof to false
        set targetSelectionMode to "missing"
        set ghosttyWindowCount to 0
        tell application "System Events"
            set ghosttyProcess to first application process whose unix id is targetProcessId
            if bundle identifier of ghosttyProcess is not "com.mitchellh.ghostty" then error "Target Ghostty process bundle mismatch."
            set frontmost of ghosttyProcess to true
            delay 0.04
            if frontmost of ghosttyProcess is false then error "Target Ghostty process is not frontmost."
            try
                set targetWindowName to name of front window of ghosttyProcess as text
                if targetWindowName contains proofMarker or targetWindowName contains compactProofMarker then set targetWindowNameIsProof to true
            end try
        end tell
        tell application id "com.mitchellh.ghostty"
            set ghosttyWindowCount to count of windows
            repeat with candidateWindow in windows
                set windowName to name of candidateWindow as text
                if targetWindowNameIsProof and targetWindowName is not "" and windowName is targetWindowName then
                    set targetWindow to candidateWindow
                    set targetSelectionMode to "frontProofTitle"
                    exit repeat
                end if
            end repeat
            if targetWindow is missing value then
                repeat with candidateWindow in windows
                    set windowName to name of candidateWindow as text
                    if windowName contains proofMarker or windowName contains compactProofMarker then
                        set targetWindow to candidateWindow
                        set targetSelectionMode to "markerTitleScan"
                        exit repeat
                    end if
                end repeat
            end if
            if targetWindow is missing value then return "false|targetSelection:" & targetSelectionMode & "|frontWindowProofMatch:" & (targetWindowNameIsProof as text) & "|windowCount:" & (ghosttyWindowCount as text)
            activate window targetWindow
            set targetTab to selected tab of targetWindow
            set targetTerminal to focused terminal of targetTab
            select tab targetTab
            focus targetTerminal
            activate
        end tell
        delay 0.02
        tell application "System Events"
            set ghosttyProcess to first application process whose unix id is targetProcessId
            if bundle identifier of ghosttyProcess is not "com.mitchellh.ghostty" then error "Target Ghostty process bundle mismatch."
            set frontmost of ghosttyProcess to true
            delay 0.04
            if frontmost of ghosttyProcess is false then error "Target Ghostty process is not frontmost."
        end tell
        tell application id "com.mitchellh.ghostty"
            set actionPerformed to perform action "write_screen_file:copy,plain" on targetTerminal
            if actionPerformed is false then return "false|targetSelection:" & targetSelectionMode & "|frontWindowProofMatch:" & (targetWindowNameIsProof as text) & "|windowCount:" & (ghosttyWindowCount as text)
            return "true|targetSelection:" & targetSelectionMode & "|frontWindowProofMatch:" & (targetWindowNameIsProof as text) & "|windowCount:" & (ghosttyWindowCount as text)
        end tell
        """

        let standardOutput = Pipe()
        let standardError = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: osascriptPath)
        process.arguments = ["-e", scriptSource]
        var environment = ProcessInfo.processInfo.environment
        environment["AUTOCOMPLETE_LAB_GHOSTTY_TARGET_PID"] = String(frontmostApp.processIdentifier)
        environment["AUTOCOMPLETE_LAB_GHOSTTY_PROOF_MARKER"] =
            ClaudeCodeTerminalHostProofPolicy.proofMarker
        environment["AUTOCOMPLETE_LAB_GHOSTTY_COMPACT_PROOF_MARKER"] =
            ClaudeCodeTerminalHostProofPolicy.compactProofMarker
        process.environment = environment
        process.standardOutput = standardOutput
        process.standardError = standardError

        do {
            try process.run()
        } catch {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-screen-copy-launch-failed",
                    "source": source,
                    "errorMessage": String(String(describing: error).prefix(160))
                ]
            )
            return (false, nil, true, false)
        }

        guard Self.waitForProcessExit(
            process,
            timeoutSeconds: 1.5,
            pollIntervalSeconds: 0.02
        ) else {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.05)
            if process.isRunning {
                process.interrupt()
            }
            let exitedAfterTerminate = Self.waitForProcessExit(
                process,
                timeoutSeconds: 0.25,
                pollIntervalSeconds: 0.02
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": exitedAfterTerminate
                        ? "ghostty-screen-copy-timeout"
                        : "ghostty-screen-copy-timeout-still-running",
                    "source": source
                ]
            )
            return (false, nil, exitedAfterTerminate, false)
        }

        let stdoutText = String(
            data: standardOutput.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let screenCopyScriptMetadata = Self.ghosttyScreenCopyScriptMetadata(stdoutText)
        let stderrText = String(
            data: standardError.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0 else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-screen-copy-failed",
                    "source": source,
                    "exitStatus": String(process.terminationStatus),
                    "errorMessage": String(stderrText.prefix(160))
                ]
            )
            return (false, nil, true, false)
        }
        guard stdoutText != "false",
              !stdoutText.hasPrefix("false|") else {
            var metadata = [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "posted": "false",
                "reason": "ghostty-screen-copy-returned-false",
                "source": source
            ]
            metadata.merge(screenCopyScriptMetadata) { current, _ in current }
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: metadata
            )
            return (false, nil, true, false)
        }

        let deadline = Date().addingTimeInterval(1.0)
        var rawScreenCopyText = pasteboard.string(forType: .string) ?? ""
        while rawScreenCopyText.isEmpty,
              Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
            rawScreenCopyText = pasteboard.string(forType: .string) ?? ""
        }
        let screenCopyText = Self.ghosttyScreenCopyPlainText(from: rawScreenCopyText)
        let screenText = screenCopyText.text
        guard !screenText.isEmpty else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-screen-copy-empty",
                    "source": source,
                    "pasteboardChanged": String(pasteboard.changeCount != clearedChangeCount)
                ]
            )
            return (false, nil, true, false)
        }

        let compactScreenText = screenText
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
        let containsProofMarker = screenText.contains(ClaudeCodeTerminalHostProofPolicy.proofMarker)
            || compactScreenText.contains(ClaudeCodeTerminalHostProofPolicy.proofMarker)
        let containsCompactProofMarker = screenText.contains(ClaudeCodeTerminalHostProofPolicy.compactProofMarker)
            || compactScreenText.contains(ClaudeCodeTerminalHostProofPolicy.compactProofMarker)
        let containsExpected = screenText.contains(expectedProofInputText)
            || compactScreenText.contains(expectedProofInputText)
        let containsOriginal = screenText.contains(originalProofInputText)
            || compactScreenText.contains(originalProofInputText)
        let highConfidenceNoProofContextNoop =
            !containsProofMarker
            && !containsCompactProofMarker
            && !containsExpected
            && !containsOriginal
            && screenCopyScriptMetadata["targetSelection"] == "frontProofTitle"
            && screenCopyScriptMetadata["frontWindowProofMatch"] == "true"
            && screenCopyScriptMetadata["windowCount"] == "1"
        let nativeNoopClassified =
            (!containsExpected && containsOriginal) || highConfidenceNoProofContextNoop
        var verificationMetadata = [
            "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
            "containsCompactProofMarker": String(containsCompactProofMarker),
            "containsExpected": String(containsExpected),
            "containsOriginal": String(containsOriginal),
            "containsProofMarker": String(containsProofMarker),
            "compactScreenChars": String(compactScreenText.count),
            "expectedChars": String(expectedProofInputText.count),
            "exitStatus": String(process.terminationStatus),
            "nativeNoopClassified": String(nativeNoopClassified),
            "originalChars": String(originalProofInputText.count),
            "pasteboardChanged": String(pasteboard.changeCount != clearedChangeCount),
            "posted": "true",
            "actionPerformed": "true",
            "screenChars": String(screenText.count),
            "screenCopyTransport": screenCopyText.transport,
            "source": source,
            "verified": String(containsExpected),
            "verificationSource": "ghosttyScreenCopy"
        ]
        verificationMetadata.merge(screenCopyScriptMetadata) { current, _ in current }
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: verificationMetadata
        )
        guard containsExpected || containsOriginal else {
            let hasProofContext = containsProofMarker || containsCompactProofMarker
            var metadata = [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "posted": "false",
                "reason": hasProofContext
                    ? "ghostty-screen-copy-proof-context-mismatch"
                    : "ghostty-screen-copy-no-proof-context",
                "nativeNoopClassified": String(highConfidenceNoProofContextNoop),
                "source": source
            ]
            metadata.merge(screenCopyScriptMetadata) { current, _ in current }
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: metadata
            )
            return hasProofContext
                ? (false, false, false, false)
                : (false, nil, true, highConfidenceNoProofContextNoop)
        }
        return (containsExpected, containsOriginal, true, nativeNoopClassified)
    }

    struct GhosttyScreenCopyText: Equatable {
        let text: String
        let transport: String
    }

    nonisolated static func ghosttyScreenCopyPlainText(
        from pasteboardText: String,
        fileManager: FileManager = .default
    ) -> GhosttyScreenCopyText {
        let trimmed = pasteboardText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains("\n"),
              trimmed.hasPrefix("/") else {
            return GhosttyScreenCopyText(text: pasteboardText, transport: "pasteboardText")
        }

        let url = URL(fileURLWithPath: trimmed).standardizedFileURL
        guard ghosttyScreenCopyFilePathAllowed(url.path) else {
            return GhosttyScreenCopyText(text: pasteboardText, transport: "filePathRejected")
        }

        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let type = attributes[.type] as? FileAttributeType,
              type == .typeRegular else {
            return GhosttyScreenCopyText(text: pasteboardText, transport: "filePathUnreadable")
        }

        let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
        guard fileSize >= 0,
              fileSize <= 1_000_000 else {
            return GhosttyScreenCopyText(text: pasteboardText, transport: "filePathTooLarge")
        }

        guard let fileText = try? String(contentsOf: url, encoding: .utf8) else {
            return GhosttyScreenCopyText(text: pasteboardText, transport: "filePathUnreadable")
        }
        return GhosttyScreenCopyText(text: fileText, transport: "screenFile")
    }

    nonisolated private static func ghosttyScreenCopyFilePathAllowed(_ path: String) -> Bool {
        path.hasPrefix("/var/folders/")
            || path.hasPrefix("/private/var/folders/")
            || path.hasPrefix("/tmp/")
            || path.hasPrefix("/private/tmp/")
    }

    nonisolated private static func ghosttyScreenCopyScriptMetadata(_ stdoutText: String) -> [String: String] {
        let allowedSelectionModes = Set(["frontProofTitle", "markerTitleScan", "missing"])
        var metadata: [String: String] = [:]
        let parts = stdoutText.split(separator: "|", omittingEmptySubsequences: true)
        for part in parts.dropFirst() {
            let keyValue = part.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard keyValue.count == 2 else {
                continue
            }
            let key = String(keyValue[0])
            let value = String(keyValue[1])
            switch key {
            case "targetSelection":
                metadata["targetSelection"] = allowedSelectionModes.contains(value) ? value : "unknown"
            case "frontWindowProofMatch":
                metadata["frontWindowProofMatch"] = value == "true" ? "true" : "false"
            case "windowCount":
                metadata["windowCount"] = value.allSatisfy(\.isNumber) ? value : "unknown"
            default:
                continue
            }
        }
        return metadata
    }

    private func insertGhosttyTerminalHostProofActionText(
        _ acceptedText: String,
        expectedProofInputText: String,
        originalProofInputText: String,
        frontmostApp: RunningApplicationInfo,
        profile: CompatibilityProfile?
    ) -> (verified: Bool, safeToContinue: Bool) {
        let source = "ghosttyPerformActionText"
        let baselineSource = "ghosttyPerformActionTextBaseline"
        guard !acceptedText.isEmpty,
              !acceptedText.contains(where: \.isNewline) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-action-text-not-one-line",
                    "source": source
                ]
            )
            return (false, false)
        }

        let osascriptPath = "/usr/bin/osascript"
        guard FileManager.default.isExecutableFile(atPath: osascriptPath) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-action-osascript-missing",
                    "source": source
                ]
            )
            return (false, false)
        }

        let scriptSource = """
        set actionText to system attribute "AUTOCOMPLETE_LAB_GHOSTTY_ACTION_TEXT"
        set proofMarker to system attribute "AUTOCOMPLETE_LAB_GHOSTTY_PROOF_MARKER"
        set compactProofMarker to system attribute "AUTOCOMPLETE_LAB_GHOSTTY_COMPACT_PROOF_MARKER"
        set targetProcessId to (system attribute "AUTOCOMPLETE_LAB_GHOSTTY_TARGET_PID") as integer
        set targetWindow to missing value
        set targetWindowName to ""
        set targetWindowNameIsProof to false
        tell application "System Events"
            set ghosttyProcess to first application process whose unix id is targetProcessId
            if bundle identifier of ghosttyProcess is not "com.mitchellh.ghostty" then error "Target Ghostty process bundle mismatch."
            set frontmost of ghosttyProcess to true
            delay 0.04
            if frontmost of ghosttyProcess is false then error "Target Ghostty process is not frontmost."
            try
                set targetWindowName to name of front window of ghosttyProcess as text
                if targetWindowName contains proofMarker or targetWindowName contains compactProofMarker then set targetWindowNameIsProof to true
            end try
        end tell
        tell application id "com.mitchellh.ghostty"
            repeat with candidateWindow in windows
                set windowName to name of candidateWindow as text
                if targetWindowNameIsProof and targetWindowName is not "" and windowName is targetWindowName then
                    set targetWindow to candidateWindow
                    exit repeat
                end if
            end repeat
            if targetWindow is missing value then
                repeat with candidateWindow in windows
                    set windowName to name of candidateWindow as text
                    if windowName contains proofMarker or windowName contains compactProofMarker then
                        set targetWindow to candidateWindow
                        exit repeat
                    end if
                end repeat
            end if
            if targetWindow is missing value then return false
            set targetTab to selected tab of targetWindow
            set targetTerminal to focused terminal of targetTab
            activate window targetWindow
            select tab targetTab
            focus targetTerminal
            activate
        end tell
        delay 0.02
        tell application "System Events"
            set ghosttyProcess to first application process whose unix id is targetProcessId
            if bundle identifier of ghosttyProcess is not "com.mitchellh.ghostty" then error "Target Ghostty process bundle mismatch."
            set frontmost of ghosttyProcess to true
            delay 0.04
            if frontmost of ghosttyProcess is false then error "Target Ghostty process is not frontmost."
        end tell
        tell application id "com.mitchellh.ghostty"
            set actionPerformed to perform action actionText on targetTerminal
            return actionPerformed
        end tell
        """

        let standardOutput = Pipe()
        let standardError = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: osascriptPath)
        process.arguments = ["-e", scriptSource]
        var environment = ProcessInfo.processInfo.environment
        environment["AUTOCOMPLETE_LAB_GHOSTTY_ACTION_TEXT"] = Self.ghosttyTextAction(acceptedText)
        environment["AUTOCOMPLETE_LAB_GHOSTTY_PROOF_MARKER"] =
            ClaudeCodeTerminalHostProofPolicy.proofMarker
        environment["AUTOCOMPLETE_LAB_GHOSTTY_COMPACT_PROOF_MARKER"] =
            ClaudeCodeTerminalHostProofPolicy.compactProofMarker
        environment["AUTOCOMPLETE_LAB_GHOSTTY_TARGET_PID"] = String(frontmostApp.processIdentifier)
        process.environment = environment
        process.standardOutput = standardOutput
        process.standardError = standardError

        do {
            try process.run()
        } catch {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-action-script-launch-failed",
                    "source": source,
                    "errorMessage": String(String(describing: error).prefix(160))
                ]
            )
            return (false, true)
        }

        guard Self.waitForProcessExit(
            process,
            timeoutSeconds: 1.2,
            pollIntervalSeconds: 0.02
        ) else {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.05)
            if process.isRunning {
                process.interrupt()
            }
            guard Self.waitForProcessExit(
                process,
                timeoutSeconds: 0.25,
                pollIntervalSeconds: 0.02
            ) else {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": "ghostty-action-script-timeout-still-running",
                        "source": source
                    ]
                )
                return (false, false)
            }
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-action-script-timeout",
                    "source": source
                ]
            )
            let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: profile,
                attempts: 4
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "source": "ghosttyPerformActionTextTimeoutBaseline",
                    "verified": String(promptStayedUnchanged)
                ]
            )
            guard promptStayedUnchanged else {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": "ghostty-action-script-timeout-mutated-input",
                        "source": "ghosttyPerformActionTextTimeoutBaseline"
                    ].merging(claudeCodeTerminalHostProofMutationShapeMetadata(
                        expectedProofInputText: expectedProofInputText,
                        originalProofInputText: originalProofInputText,
                        frontmostApp: frontmostApp,
                        profile: profile
                    )) { current, _ in current }
                )
                return (false, false)
            }
            return (false, true)
        }

        let stdoutText = String(
            data: standardOutput.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderrText = String(
            data: standardError.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0 else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-action-script-failed",
                    "source": source,
                    "exitStatus": String(process.terminationStatus),
                    "errorMessage": String(stderrText.prefix(160))
                ]
            )
            return (false, true)
        }

        guard stdoutText != "false" else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-action-script-returned-false",
                    "source": source
                ]
            )
            return (false, true)
        }

        let verified = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: expectedProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 24
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "posted": "true",
                "source": source,
                "actionPerformed": "true",
                "verified": String(verified)
            ]
        )
        if verified {
            return (true, false)
        }

        let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: originalProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 4
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "source": baselineSource,
                "verified": String(promptStayedUnchanged)
            ]
        )
        guard promptStayedUnchanged else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": "ghostty-action-unverified-mutated-input",
                        "source": baselineSource
                    ].merging(claudeCodeTerminalHostProofMutationShapeMetadata(
                        expectedProofInputText: expectedProofInputText,
                        originalProofInputText: originalProofInputText,
                        frontmostApp: frontmostApp,
                        profile: profile
                    )) { current, _ in current }
                )
            return (false, false)
        }
        return (false, true)
    }

    private func insertGhosttyTerminalHostProofAppleScriptText(
        _ acceptedText: String,
        expectedProofInputText: String,
        originalProofInputText: String,
        frontmostApp: RunningApplicationInfo,
        profile: CompatibilityProfile?,
        launchThroughShell: Bool = false
    ) -> (verified: Bool, safeToContinue: Bool) {
        let source = launchThroughShell
            ? "ghosttyAppleScriptLoginShellInputText"
            : "ghosttyAppleScriptInputText"
        let baselineSource = launchThroughShell
            ? "ghosttyAppleScriptLoginShellInputTextBaseline"
            : "ghosttyAppleScriptInputTextBaseline"
        guard !acceptedText.isEmpty,
              !acceptedText.contains(where: \.isNewline) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-apple-script-text-not-one-line",
                    "source": source
                ]
            )
            return (false, false)
        }

        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "acceptedChars": String(acceptedText.count),
                "source": source,
                "stage": "start"
            ]
        )

        let osascriptPath = "/usr/bin/osascript"
        guard FileManager.default.isExecutableFile(atPath: osascriptPath) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-apple-script-osascript-missing",
                    "source": source
                ]
            )
            return (false, false)
        }

        let shellPath = "/bin/zsh"
        if launchThroughShell,
           !FileManager.default.isExecutableFile(atPath: shellPath) {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-apple-script-shell-missing",
                    "source": source
                ]
            )
            return (false, true)
        }

        let scriptSource = """
        set acceptedText to system attribute "AUTOCOMPLETE_LAB_GHOSTTY_ACCEPTED_TEXT"
        set proofMarker to system attribute "AUTOCOMPLETE_LAB_GHOSTTY_PROOF_MARKER"
        set compactProofMarker to system attribute "AUTOCOMPLETE_LAB_GHOSTTY_COMPACT_PROOF_MARKER"
        set targetProcessId to (system attribute "AUTOCOMPLETE_LAB_GHOSTTY_TARGET_PID") as integer
        set targetWindow to missing value
        set targetWindowName to ""
        set targetWindowNameIsProof to false
        tell application "System Events"
            set ghosttyProcess to first application process whose unix id is targetProcessId
            if bundle identifier of ghosttyProcess is not "com.mitchellh.ghostty" then error "Target Ghostty process bundle mismatch."
            set frontmost of ghosttyProcess to true
            delay 0.04
            if frontmost of ghosttyProcess is false then error "Target Ghostty process is not frontmost."
            try
                set targetWindowName to name of front window of ghosttyProcess as text
                if targetWindowName contains proofMarker or targetWindowName contains compactProofMarker then set targetWindowNameIsProof to true
            end try
        end tell
        tell application id "com.mitchellh.ghostty"
            repeat with candidateWindow in windows
                set windowName to name of candidateWindow as text
                if targetWindowNameIsProof and targetWindowName is not "" and windowName is targetWindowName then
                    set targetWindow to candidateWindow
                    exit repeat
                end if
            end repeat
            if targetWindow is missing value then
                repeat with candidateWindow in windows
                    set windowName to name of candidateWindow as text
                    if windowName contains proofMarker or windowName contains compactProofMarker then
                        set targetWindow to candidateWindow
                        exit repeat
                    end if
                end repeat
            end if
            if targetWindow is missing value then return false
            set targetTab to selected tab of targetWindow
            set targetTerminal to focused terminal of targetTab
            activate window targetWindow
            select tab targetTab
            focus targetTerminal
            activate
        end tell
        delay 0.02
        tell application "System Events"
            set ghosttyProcess to first application process whose unix id is targetProcessId
            if bundle identifier of ghosttyProcess is not "com.mitchellh.ghostty" then error "Target Ghostty process bundle mismatch."
            set frontmost of ghosttyProcess to true
            delay 0.04
            if frontmost of ghosttyProcess is false then error "Target Ghostty process is not frontmost."
        end tell
        tell application id "com.mitchellh.ghostty"
            input text acceptedText to targetTerminal
            return true
        end tell
        """

        let standardOutput = Pipe()
        let standardError = Pipe()
        let standardInput = Pipe()
        let process = Process()
        if launchThroughShell {
            process.executableURL = URL(fileURLWithPath: shellPath)
            process.arguments = ["-lc", "exec /usr/bin/osascript"]
            process.standardInput = standardInput
        } else {
            process.executableURL = URL(fileURLWithPath: osascriptPath)
            process.arguments = ["-e", scriptSource]
        }
        var environment = ProcessInfo.processInfo.environment
        environment["AUTOCOMPLETE_LAB_GHOSTTY_ACCEPTED_TEXT"] = acceptedText
        environment["AUTOCOMPLETE_LAB_GHOSTTY_PROOF_MARKER"] = ClaudeCodeTerminalHostProofPolicy.proofMarker
        environment["AUTOCOMPLETE_LAB_GHOSTTY_COMPACT_PROOF_MARKER"] =
            ClaudeCodeTerminalHostProofPolicy.compactProofMarker
        environment["AUTOCOMPLETE_LAB_GHOSTTY_TARGET_PID"] = String(frontmostApp.processIdentifier)
        process.environment = environment
        process.standardOutput = standardOutput
        process.standardError = standardError

        do {
            try process.run()
            if launchThroughShell {
                standardInput.fileHandleForWriting.write(Data(scriptSource.utf8))
                try? standardInput.fileHandleForWriting.close()
            }
        } catch {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-apple-script-launch-failed",
                    "source": source,
                    "errorMessage": String(String(describing: error).prefix(160))
                ]
            )
            return (false, true)
        }

        guard Self.waitForProcessExit(
            process,
            timeoutSeconds: 1.2,
            pollIntervalSeconds: 0.02
        ) else {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.05)
            if process.isRunning {
                process.interrupt()
            }
            guard Self.waitForProcessExit(
                process,
                timeoutSeconds: 0.25,
                pollIntervalSeconds: 0.02
            ) else {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": "ghostty-apple-script-timeout-still-running",
                        "source": source
                    ]
                )
                return (false, false)
            }
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-apple-script-timeout",
                    "source": source
                ]
            )
            let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: profile,
                attempts: 4
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "source": "ghosttyAppleScriptInputTextTimeoutBaseline",
                    "verified": String(promptStayedUnchanged)
                ]
            )
            guard promptStayedUnchanged else {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": "ghostty-apple-script-timeout-mutated-input",
                        "source": "ghosttyAppleScriptInputTextTimeoutBaseline"
                    ].merging(claudeCodeTerminalHostProofMutationShapeMetadata(
                        expectedProofInputText: expectedProofInputText,
                        originalProofInputText: originalProofInputText,
                        frontmostApp: frontmostApp,
                        profile: profile
                    )) { current, _ in current }
                )
                return (false, false)
            }
            return (false, true)
        }

        let stdoutText = String(
            data: standardOutput.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderrText = String(
            data: standardError.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0 else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-apple-script-failed",
                    "source": source,
                    "exitStatus": String(process.terminationStatus),
                    "errorMessage": String(stderrText.prefix(160))
                ]
            )
            return (false, true)
        }

        guard stdoutText != "false" else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-apple-script-returned-false",
                    "source": source
                ]
            )
            return (false, true)
        }

        let verified = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: expectedProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 24
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "posted": "true",
                "source": source,
                "verified": String(verified),
                "launchMode": launchThroughShell ? "shell" : "direct"
            ]
        )
        if verified {
            return (true, false)
        }

        let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: originalProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 4
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "source": baselineSource,
                "verified": String(promptStayedUnchanged)
            ]
        )
        guard promptStayedUnchanged else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-apple-script-unverified-mutated-input",
                    "source": baselineSource
                ].merging(claudeCodeTerminalHostProofMutationShapeMetadata(
                    expectedProofInputText: expectedProofInputText,
                    originalProofInputText: originalProofInputText,
                    frontmostApp: frontmostApp,
                    profile: profile
                )) { current, _ in current }
            )
            return (false, false)
        }
        return (false, true)
    }

    private func claudeCodeTerminalHostProofMutationShapeMetadata(
        expectedProofInputText: String,
        originalProofInputText: String,
        frontmostApp: RunningApplicationInfo,
        profile: CompatibilityProfile?
    ) -> [String: String] {
        guard let profile,
              let currentContext = accessibilityClient.focusedTextContext(
                for: frontmostApp,
                allowDescendantTextFallback: profile.allowsDescendantTextFallback
              ) else {
            return [
                "actualInputAvailable": "false",
                "expectedChars": String(expectedProofInputText.count),
                "originalChars": String(originalProofInputText.count)
            ]
        }

        let verificationInput = claudeCodeTerminalHostProofVerificationInputText(
            app: frontmostApp,
            context: currentContext,
            profile: profile
        )
        guard let actualProofInputText = verificationInput.inputText else {
            return [
                "actualInputAvailable": "false",
                "actualInputSource": verificationInput.source,
                "expectedChars": String(expectedProofInputText.count),
                "originalChars": String(originalProofInputText.count)
            ]
        }

        return [
            "actualInputAvailable": "true",
            "actualInputSource": verificationInput.source,
            "actualChars": String(actualProofInputText.count),
            "expectedChars": String(expectedProofInputText.count),
            "originalChars": String(originalProofInputText.count),
            "actualDeltaFromExpected": String(actualProofInputText.count - expectedProofInputText.count),
            "actualDeltaFromOriginal": String(actualProofInputText.count - originalProofInputText.count),
            "actualEqualsOriginal": String(actualProofInputText == originalProofInputText),
            "actualHasExpectedPrefix": String(actualProofInputText.hasPrefix(expectedProofInputText)),
            "expectedHasActualPrefix": String(expectedProofInputText.hasPrefix(actualProofInputText)),
            "actualContainsExpected": String(actualProofInputText.contains(expectedProofInputText)),
            "actualContainsOriginal": String(actualProofInputText.contains(originalProofInputText)),
            "actualLineCount": String(actualProofInputText.components(separatedBy: .newlines).count),
            "expectedLineCount": String(expectedProofInputText.components(separatedBy: .newlines).count)
        ]
    }

    nonisolated private static func waitForProcessExit(
        _ process: Process,
        timeoutSeconds: TimeInterval,
        pollIntervalSeconds: TimeInterval
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: pollIntervalSeconds)
        }
        if process.isRunning {
            return false
        }
        process.waitUntilExit()
        return true
    }

    private func insertGhosttyTerminalHostProofSendKey(
        _ acceptedText: String,
        expectedProofInputText: String,
        originalProofInputText: String,
        frontmostApp: RunningApplicationInfo,
        profile: CompatibilityProfile?
    ) -> (verified: Bool, safeToContinue: Bool) {
        let source = "ghosttySendKey"
        let baselineSource = "ghosttySendKeyBaseline"
        guard !acceptedText.isEmpty,
              !acceptedText.contains(where: \.isNewline) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-send-key-text-not-one-line",
                    "source": source
                ]
            )
            return (false, false)
        }
        guard let keySteps = Self.ghosttySendKeySteps(acceptedText) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "acceptedChars": String(acceptedText.count),
                    "posted": "false",
                    "reason": "ghostty-send-key-text-unsupported",
                    "unsupportedScalar": Self.firstUnsupportedGhosttySendKeyScalarDescription(acceptedText) ?? "",
                    "source": source
                ]
            )
            return (false, true)
        }

        let proofMarker = ClaudeCodeTerminalHostProofPolicy.proofMarker
        let compactProofMarker = ClaudeCodeTerminalHostProofPolicy.compactProofMarker
        let keyScriptLines = Self.ghosttySendKeyScriptLines(for: keySteps)
        let scriptSource = """
        set targetProcessId to \(frontmostApp.processIdentifier) as integer
        set targetWindow to missing value
        set targetWindowName to ""
        set targetWindowNameIsProof to false
        tell application "System Events"
            set ghosttyProcess to first application process whose unix id is targetProcessId
            if bundle identifier of ghosttyProcess is not "com.mitchellh.ghostty" then error "Target Ghostty process bundle mismatch."
            set frontmost of ghosttyProcess to true
            delay 0.04
            if frontmost of ghosttyProcess is false then error "Target Ghostty process is not frontmost."
            try
                set targetWindowName to name of front window of ghosttyProcess as text
                if targetWindowName contains \(Self.appleScriptStringLiteral(proofMarker)) or targetWindowName contains \(Self.appleScriptStringLiteral(compactProofMarker)) then set targetWindowNameIsProof to true
            end try
        end tell
        tell application id "com.mitchellh.ghostty"
            repeat with candidateWindow in windows
                set windowName to name of candidateWindow as text
                if targetWindowNameIsProof and targetWindowName is not "" and windowName is targetWindowName then
                    set targetWindow to candidateWindow
                    exit repeat
                end if
            end repeat
            if targetWindow is missing value then
                repeat with candidateWindow in windows
                    set windowName to name of candidateWindow as text
                    if windowName contains \(Self.appleScriptStringLiteral(proofMarker)) or windowName contains \(Self.appleScriptStringLiteral(compactProofMarker)) then
                        set targetWindow to candidateWindow
                        exit repeat
                    end if
                end repeat
            end if
            if targetWindow is missing value then return false
            set targetTab to selected tab of targetWindow
            set targetTerminal to focused terminal of targetTab
            activate window targetWindow
            select tab targetTab
            focus targetTerminal
            activate
        end tell
        delay 0.02
        tell application "System Events"
            set ghosttyProcess to first application process whose unix id is targetProcessId
            if bundle identifier of ghosttyProcess is not "com.mitchellh.ghostty" then error "Target Ghostty process bundle mismatch."
            set frontmost of ghosttyProcess to true
            delay 0.04
            if frontmost of ghosttyProcess is false then error "Target Ghostty process is not frontmost."
        end tell
        tell application id "com.mitchellh.ghostty"
            \(keyScriptLines)
            return true
        end tell
        """

        let osascriptPath = "/usr/bin/osascript"
        guard FileManager.default.isExecutableFile(atPath: osascriptPath) else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-send-key-osascript-missing",
                    "source": source
                ]
            )
            return (false, true)
        }

        let standardOutput = Pipe()
        let standardError = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: osascriptPath)
        process.arguments = ["-e", scriptSource]
        process.standardOutput = standardOutput
        process.standardError = standardError

        stopKeyboardEventTapNow(reason: "ghostty-send-key-insertion")

        do {
            try process.run()
        } catch {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-send-key-script-launch-failed",
                    "source": source,
                    "errorMessage": String(String(describing: error).prefix(160))
                ]
            )
            return (false, true)
        }

        guard Self.waitForProcessExit(
            process,
            timeoutSeconds: 1.2,
            pollIntervalSeconds: 0.02
        ) else {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.05)
            if process.isRunning {
                process.interrupt()
            }
            guard Self.waitForProcessExit(
                process,
                timeoutSeconds: 0.25,
                pollIntervalSeconds: 0.02
            ) else {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": "ghostty-send-key-script-timeout-still-running",
                        "source": source
                    ]
                )
                return (false, false)
            }
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-send-key-script-timeout",
                    "source": source
                ]
            )
            let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
                expectedProofInputText: originalProofInputText,
                frontmostApp: frontmostApp,
                profile: profile,
                attempts: 4
            )
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "source": "ghosttySendKeyTimeoutBaseline",
                    "verified": String(promptStayedUnchanged)
                ]
            )
            guard promptStayedUnchanged else {
                DiagnosticsLog.shared.record(
                    "claude-code-terminal-host-proof-insert",
                    metadata: [
                        "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                        "posted": "false",
                        "reason": "ghostty-send-key-timeout-mutated-input",
                        "source": "ghosttySendKeyTimeoutBaseline"
                    ].merging(claudeCodeTerminalHostProofMutationShapeMetadata(
                        expectedProofInputText: expectedProofInputText,
                        originalProofInputText: originalProofInputText,
                        frontmostApp: frontmostApp,
                        profile: profile
                    )) { current, _ in current }
                )
                return (false, false)
            }
            return (false, true)
        }

        let stdoutText = String(
            data: standardOutput.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderrText = String(
            data: standardError.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0 else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-send-key-script-failed",
                    "source": source,
                    "exitStatus": String(process.terminationStatus),
                    "errorMessage": String(stderrText.prefix(160))
                ]
            )
            return (false, true)
        }

        guard stdoutText != "false" else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-send-key-script-returned-false",
                    "source": source
                ]
            )
            return (false, true)
        }

        let verified = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: expectedProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 24
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "posted": "true",
                "source": source,
                "verified": String(verified)
            ]
        )
        if verified {
            return (true, false)
        }

        let promptStayedUnchanged = verifyClaudeCodeTerminalHostProofInsertion(
            expectedProofInputText: originalProofInputText,
            frontmostApp: frontmostApp,
            profile: profile,
            attempts: 4
        )
        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-insert",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "source": baselineSource,
                "verified": String(promptStayedUnchanged)
            ]
        )
        guard promptStayedUnchanged else {
            DiagnosticsLog.shared.record(
                "claude-code-terminal-host-proof-insert",
                metadata: [
                    "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                    "posted": "false",
                    "reason": "ghostty-send-key-unverified-mutated-input",
                    "source": baselineSource
                ]
            )
            return (false, false)
        }
        return (false, true)
    }

    nonisolated private static func ghosttyTextAction(_ text: String) -> String {
        let encoded = text.utf8.map { byte -> String in
            switch byte {
            case 48...57, 65...90, 97...122:
                return String(UnicodeScalar(byte))
            default:
                return String(format: "\\x%02x", byte)
            }
        }.joined()
        return "text:\(encoded)"
    }

    private struct GhosttySendKeyStep {
        let keyName: String
        let modifiers: String?
    }

    nonisolated private static func ghosttySendKeyStep(for scalar: Unicode.Scalar) -> GhosttySendKeyStep? {
        switch scalar.value {
        case 32:
            return GhosttySendKeyStep(keyName: "space", modifiers: nil)
        case 39:
            return GhosttySendKeyStep(keyName: "apostrophe", modifiers: nil)
        case 48...57, 97...122:
            return GhosttySendKeyStep(keyName: String(scalar), modifiers: nil)
        case 65...90:
            guard let lowercase = UnicodeScalar(scalar.value + 32) else {
                return nil
            }
            return GhosttySendKeyStep(keyName: String(lowercase), modifiers: "shift")
        default:
            return nil
        }
    }

    nonisolated private static func ghosttySendKeySteps(_ text: String) -> [GhosttySendKeyStep]? {
        var steps: [GhosttySendKeyStep] = []
        for scalar in text.unicodeScalars {
            guard let step = ghosttySendKeyStep(for: scalar) else {
                return nil
            }
            steps.append(step)
        }
        return steps.isEmpty ? nil : steps
    }

    nonisolated private static func firstUnsupportedGhosttySendKeyScalarDescription(_ text: String) -> String? {
        for scalar in text.unicodeScalars where ghosttySendKeyStep(for: scalar) == nil {
            return String(format: "U+%04X", scalar.value)
        }
        return nil
    }

    nonisolated private static func ghosttySendKeyScriptLines(for steps: [GhosttySendKeyStep]) -> String {
        steps.map { step in
            let modifiers = step.modifiers.map {
                " modifiers \(appleScriptStringLiteral($0))"
            } ?? ""
            let key = appleScriptStringLiteral(step.keyName)
            return """
            send key \(key) action press\(modifiers) to targetTerminal
            send key \(key) action release\(modifiers) to targetTerminal
"""
        }.joined(separator: "\n")
    }

    nonisolated private static func appleScriptStringLiteral(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func claudeCodeTerminalHostProofVerificationInputText(
        app: RunningApplicationInfo,
        context: FocusedTextContext,
        profile: CompatibilityProfile
    ) -> (inputText: String?, source: String) {
        let focusedInputText = claudeCodeTerminalHostProofInputText(
            app: app,
            context: context,
            profile: profile
        )
        guard app.bundleIdentifier == "com.mitchellh.ghostty",
              let terminalScreenText = accessibilityClient.focusedWindowText(for: app),
              !terminalScreenText.isEmpty else {
            return (focusedInputText, "focusedContext")
        }

        let proofContext = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: app.bundleIdentifier,
            windowTitle: context.fingerprint.windowTitle ?? "",
            focusedText: ClaudeCodeTerminalHostProofPolicy.focusedInputLine(
                textBeforeCursor: context.textBeforeCursor,
                textAfterCursor: context.textAfterCursor
            ),
            rawTextBeforeCursor: context.textBeforeCursor,
            rawTextAfterCursor: context.textAfterCursor,
            terminalScreenText: terminalScreenText,
            proofModeEnabled: activeAppProofBundleIdentifiers.contains(
                ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier
            )
        )
        guard let screenFirstInputText =
            ClaudeCodeTerminalHostProofPolicy.proofInputTextPreferringTerminalScreen(
                for: proofContext
            ) else {
            return (focusedInputText, "focusedContext")
        }

        if screenFirstInputText != focusedInputText {
            return (screenFirstInputText, "terminalScreen")
        }
        return (screenFirstInputText, "focusedContext")
    }

    private func verifyClaudeCodeTerminalHostProofInsertion(
        expectedProofInputText: String,
        frontmostApp: RunningApplicationInfo,
        profile: CompatibilityProfile?,
        attempts: Int = 8,
        delaySeconds: TimeInterval = 0.05
    ) -> Bool {
        guard let profile else {
            return false
        }

        for attempt in 0..<attempts {
            if attempt > 0 {
                Thread.sleep(forTimeInterval: delaySeconds)
            }

            guard let currentContext = accessibilityClient.focusedTextContext(
                for: frontmostApp,
                allowDescendantTextFallback: profile.allowsDescendantTextFallback
            ) else {
                continue
            }

            let verificationInput = claudeCodeTerminalHostProofVerificationInputText(
                app: frontmostApp,
                context: currentContext,
                profile: profile
            )
            if verificationInput.inputText == expectedProofInputText {
                if verificationInput.source == "terminalScreen" {
                    DiagnosticsLog.shared.record(
                        "claude-code-terminal-host-proof-verification",
                        metadata: [
                            "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                            "host": frontmostApp.bundleIdentifier,
                            "source": verificationInput.source,
                            "expectedChars": String(expectedProofInputText.count)
                        ]
                    )
                }
                return true
            }
            if attempt == attempts - 1, let currentProofInputText = verificationInput.inputText {
                recordClaudeCodeTerminalHostProofVerificationMismatch(
                    expectedProofInputText: expectedProofInputText,
                    currentProofInputText: currentProofInputText,
                    source: verificationInput.source,
                    frontmostApp: frontmostApp,
                    attempt: attempt + 1,
                    attempts: attempts
                )
            }
        }

        return false
    }

    private func recordClaudeCodeTerminalHostProofVerificationMismatch(
        expectedProofInputText: String,
        currentProofInputText: String,
        source: String,
        frontmostApp: RunningApplicationInfo,
        attempt: Int,
        attempts: Int
    ) {
        guard frontmostApp.bundleIdentifier == "com.mitchellh.ghostty" else {
            return
        }

        DiagnosticsLog.shared.record(
            "claude-code-terminal-host-proof-verification-mismatch",
            metadata: [
                "app": ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier,
                "host": frontmostApp.bundleIdentifier,
                "source": source,
                "attempt": String(attempt),
                "attempts": String(attempts),
                "expectedChars": String(expectedProofInputText.count),
                "currentChars": String(currentProofInputText.count),
                "lengthDelta": String(currentProofInputText.count - expectedProofInputText.count),
                "commonPrefixChars": String(
                    Self.commonPrefixCharacterCount(expectedProofInputText, currentProofInputText)
                ),
                "commonSuffixChars": String(
                    Self.commonSuffixCharacterCount(expectedProofInputText, currentProofInputText)
                ),
                "currentHasExpectedPrefix": String(currentProofInputText.hasPrefix(expectedProofInputText)),
                "currentHasExpectedSuffix": String(currentProofInputText.hasSuffix(expectedProofInputText)),
                "expectedHasCurrentPrefix": String(expectedProofInputText.hasPrefix(currentProofInputText)),
                "expectedHasCurrentSuffix": String(expectedProofInputText.hasSuffix(currentProofInputText))
            ]
        )
    }

    nonisolated private static func commonPrefixCharacterCount(_ lhs: String, _ rhs: String) -> Int {
        var count = 0
        var lhsIndex = lhs.startIndex
        var rhsIndex = rhs.startIndex
        while lhsIndex < lhs.endIndex,
              rhsIndex < rhs.endIndex,
              lhs[lhsIndex] == rhs[rhsIndex] {
            count += 1
            lhs.formIndex(after: &lhsIndex)
            rhs.formIndex(after: &rhsIndex)
        }
        return count
    }

    nonisolated private static func commonSuffixCharacterCount(_ lhs: String, _ rhs: String) -> Int {
        var count = 0
        var lhsIndex = lhs.endIndex
        var rhsIndex = rhs.endIndex
        while lhsIndex > lhs.startIndex,
              rhsIndex > rhs.startIndex {
            lhs.formIndex(before: &lhsIndex)
            rhs.formIndex(before: &rhsIndex)
            guard lhs[lhsIndex] == rhs[rhsIndex] else {
                break
            }
            count += 1
        }
        return count
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
        acceptanceProof: SuggestionAcceptanceProof
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

    private func suggestionAcceptanceProof(
        action: KeyboardAction,
        acceptedText: String
    ) -> SuggestionAcceptanceProof? {
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
            if let suggestionID = currentSuggestionState.id {
                RawAutocompleteTraceLog.shared.record(
                    type: .suggestionSuppressed,
                    suggestionID: suggestionID,
                    appBundleIdentifier: currentSuggestionState.appBundleIdentifier ?? currentProfile?.bundleIdentifier ?? "",
                    fieldIdentity: currentSuggestionState.fieldIdentity?.traceDescription
                        ?? currentFieldIdentity?.traceDescription
                        ?? "",
                    requestMode: currentSuggestionState.requestMode?.rawValue ?? "",
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
            suggestionChromeHost.showSuggestion(
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
            textAfterCursor: context.textAfterCursor,
            promptProofModeEnabled: activeAppProofBundleIdentifiers.contains(CodexProofFocusedTargetPolicy.bundleIdentifier),
            promptProofBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            promptProofMarker: CodexProofFocusedTargetPolicy.marker
        )
    }

    private func geometryPreservationReason(
        context: FocusedTextContext,
        profile: CompatibilityProfile
    ) -> String {
        if profile.bundleIdentifier == "md.obsidian" {
            return "obsidian-document-start-geometry-teleport"
        }

        if profile.bundleIdentifier == CodexProofFocusedTargetPolicy.bundleIdentifier,
           activeAppProofBundleIdentifiers.contains(CodexProofFocusedTargetPolicy.bundleIdentifier) {
            return "codex-proof-target-geometry-churn"
        }

        if currentSuggestionState.textBeforeCursor.map({ context.textBeforeCursor + context.textAfterCursor == $0 }) == true {
            return "transient-same-text-geometry-split"
        }

        return "transient-geometry-change"
    }

    private func recordAcceptedText(_ acceptedText: String) {
        rememberAcceptedWords(
            in: acceptedText,
            appBundleIdentifier: currentSuggestionState.appBundleIdentifier ?? currentProfile?.bundleIdentifier
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
        recordPersonalCaptureSuggestionEpisodeAction(
            suggestionID: suggestionID,
            appBundleIdentifier: profile.bundleIdentifier,
            outcome: .typedPast,
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
            let learningMetadata = recordTypeThroughConfidenceCreditIfNeeded(
                survival,
                appBundleIdentifier: profile.bundleIdentifier
            )
            let survivalMetadata = survival.traceMetadata
                .merging(learningMetadata) { current, _ in current }
            lastTextSnapshot = snapshot
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
            recordPersonalCaptureSuggestionEpisodeAction(
                suggestionID: currentSuggestionState.id ?? "",
                appBundleIdentifier: profile.bundleIdentifier,
                outcome: .shown,
                reason: "survived_typethrough",
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

            suggestionOrchestrator.recordRepetitionMiss(
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
            let outcome = suggestionHiddenOutcome(for: reason)
            let displayedText = currentSuggestionState.displayedText ?? suggestionSession.visibleSuggestion?.visibleText ?? ""
            let lifetimeMilliseconds = currentSuggestionLifetimeMilliseconds()
            var metadata = currentSuggestionLifetimeMetadata(lifetimeMilliseconds: lifetimeMilliseconds)

            if outcome == "ignored" {
                let missRecord = suggestionOrchestrator.recordIgnoredRepetition(
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
            let episodeOutcome = personalCaptureEpisodeOutcome(hiddenOutcome: outcome, reason: reason)
            if episodeOutcome != .unknown {
                recordPersonalCaptureSuggestionEpisodeAction(
                    suggestionID: suggestionID,
                    appBundleIdentifier: appBundleIdentifier,
                    outcome: episodeOutcome,
                    reason: reason,
                    metadata: metadata
                )
            }
            setSuggestionDecision("Hidden: \(reason)")
        }

        if currentSuggestionState.invalidatedByUserKeyDown
            || reason == "typed-over"
            || reason == "stale-after-keydown"
            || reason.hasPrefix("keyboard-event-tap-") {
            proofOnlyAcceptRecentSuggestion = nil
        }

        suggestionSession.dismiss()
        currentSuggestionState.id = nil
        currentSuggestionState.appBundleIdentifier = nil
        currentSuggestionState.fieldIdentity = nil
        currentSuggestionState.requestMode = nil
        currentSuggestionState.textBeforeCursor = nil
        currentSuggestionState.acceptanceSnapshot = nil
        currentSuggestionState.displayedText = nil
        currentSuggestionState.optimisticOriginalDisplayedText = nil
        currentSuggestionState.optimisticTypedPrefix = ""
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
        suggestionChromeHost.hideSuggestion()
        updateKeyboardEventTapSnapshot()
        scheduleKeyboardEventTapStopIfIdle()
    }

    private func showFieldStatusIndicator(
        _ state: FieldStatusIndicatorState,
        context: FocusedTextContext
    ) {
        suggestionChromeHost.showFieldStatusIndicator(state, context: context)
    }

    private func updateStatusMenu(
        app: RunningApplicationInfo?,
        profile: CompatibilityProfile?,
        appEnabled: Bool
    ) {
        if let app,
           app.bundleIdentifier != Bundle.main.bundleIdentifier {
            appTargetStateHost.noteObservedSettingsApp(app)
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
        statusMenuHost.update(
            statusLine: statusLine,
            statusToolTip: lastSuggestionDecision,
            pauseSuggestionsTitle: pauseSuggestionsTitle,
            silenceFieldTitle: fieldControlState.buttonTitle,
            silenceFieldEnabled: fieldControlState.canSilence,
            silenceFieldToolTip: fieldControlState.detailText,
            toggleAppTitle: appControlState?.menuToggleTitle ?? "Pause Current App",
            toggleAppEnabled: appControlState?.canToggle ?? false,
            toggleAppToolTip: appControlState?.fallbackText ?? ""
        )
        if settingsWindow.isShowing {
            settingsWindow.refresh(
                isTrusted: accessibilityClient.isTrusted,
                suggestionsPaused: suggestionsPaused,
                suggestionsPausedUntil: suggestionsPausedUntil,
                runtimeReport: runtimeReadinessReport,
                runtimeTargetSummary: runtimeTargetSummary,
                modelDirectoryPath: modelDirectoryPath,
                modelInstallStatusText: runtimeStatusHost.modelInstallStatus,
                isModelInstallInProgress: modelInstallLifecycleHost.isInstalling,
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
        if proofSuppressesAnnoyanceLearning() {
            DiagnosticsLog.shared.record(
                "proof-annoyance-learning-suppressed",
                metadata: [
                    "layer": "prefix-family-cooldown",
                    "reason": reason.rawValue,
                    "app": input.appBundleIdentifier
                ]
            )
            return [:]
        }

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
        let reason = cooldown.reason.rawValue
        prefixCooldownRetryHost.schedule(until: cooldown.until) { [weak self, snapshot, reason] in
            guard let self,
                  self.lastTextSnapshot == snapshot,
                  !self.suggestionSession.hasVisibleSuggestion else {
                return
            }

            self.lastTextSnapshot = nil
            self.codexPromptTargetContinuityHost.reset()
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

    private func cancelPrefixCooldownRetry() {
        prefixCooldownRetryHost.cancel()
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

        if proofSuppressesAnnoyanceLearning() {
            DiagnosticsLog.shared.record(
                "proof-annoyance-learning-suppressed",
                metadata: [
                    "layer": "annoyance-signal",
                    "signal": signal.rawValue,
                    "reason": reason,
                    "app": context.appBundleIdentifier
                ]
            )
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
        codexPromptTargetContinuityHost.reset()
        lastFocusedTextChangeAt = nil
        lastRequestedTextBeforeCursor = nil
        typingBurstState.reset()
        suggestionIdleRetryState.cancel()
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
        codexPromptTargetContinuityHost.reset()
        lastFocusedTextChangeAt = nil
        lastRequestedTextBeforeCursor = nil
        typingBurstState.reset()
        suggestionIdleRetryState.cancel()
        suggestionChromeHost.hideFieldStatusIndicator()
        if resetBlockLogGate {
            suggestionBlockLogGate.reset()
        }
    }

    @discardableResult
    private func invalidatePendingSuggestionRequest() -> Bool {
        let cancelledPendingRequest = cancelPendingSuggestionTask(reason: "invalidate")
        suggestionOrchestrator.clearStreamingPresentations()
        suggestionOrchestrator.invalidate()
        return cancelledPendingRequest
    }

    @discardableResult
    private func cancelPendingSuggestionTask(reason: String) -> Bool {
        codexPromptTargetContinuityHost.clearCooldownPreservation()
        let cancelledPresentationRefreshRetry = codexPromptPresentationRetryHost.hasScheduledRetry
        codexPromptPresentationRetryHost.cancel()
        if cancelledPresentationRefreshRetry {
            DiagnosticsLog.shared.record(
                "codex-prompt-target-refresh-retry-cancelled",
                metadata: ["reason": reason]
            )
        }

        let cancelledPendingRequest = suggestionRequestScheduler.cancelPendingRequest()
        guard cancelledPendingRequest else {
            return cancelledPresentationRefreshRetry
        }

        suggestionOrchestrator.clearStreamingPresentations()
        DiagnosticsLog.shared.record(
            "suggestion-request-cancelled",
            metadata: [
                "reason": reason
            ]
        )
        return true
    }

    @objc
    private func requestAccessibilityPermission() {
        let isTrusted = accessibilityPermissionHost.requestPermission()
        settingsWindow.refresh(
            isTrusted: isTrusted,
            suggestionsPaused: suggestionsPaused,
            suggestionsPausedUntil: suggestionsPausedUntil,
            runtimeReport: runtimeReadinessReport,
            runtimeTargetSummary: runtimeTargetSummary,
            modelDirectoryPath: modelDirectoryPath,
            modelInstallStatusText: runtimeStatusHost.modelInstallStatus,
            isModelInstallInProgress: modelInstallLifecycleHost.isInstalling,
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

        manualSuggestionRequestHost.request()
        lastRequestedTextBeforeCursor = nil
        suggestionPipeline.resetPollingPause()
        setSuggestionDecision("Queued: asked once")
        DiagnosticsLog.shared.record(
            "suggestion-summon-requested",
            metadata: [
                "source": source,
                "shortcut": suggestionSummonHotKeyHost.descriptor.diagnosticName
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
            manualSuggestionRequestHost.clearPendingRequest()
            suggestionPipeline.finishPoll(startedAt: startedAt)
        }
    }

    private func scheduleManualSuggestionRetry() {
        manualSuggestionRequestHost.scheduleRetry { [weak self] in
            self?.pollFocusedTextForManualSuggestion()
        }
    }

    @objc
    private func openAccessibilitySettings() {
        if accessibilityPermissionHost.openAccessibilitySettings() {
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
            modelInstallStatusText: runtimeStatusHost.modelInstallStatus,
            isModelInstallInProgress: modelInstallLifecycleHost.isInstalling,
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
        modelInstallLifecycleHost.start()
    }

    func reloadModelRuntimeAfterInstall() {
        let previousRuntime = modelRuntime
        modelRuntimeWarmHost.cancel()
        invalidatePendingSuggestionRequest()
        previousRuntime.cancel()
        modelRuntimeBundle = AppModelRuntimeFactory.makeRuntime()
        engine = RuntimeBackedCompletionEngine(runtime: modelRuntime)
        suggestionOrchestrator.updateEngine(engine)
        runtimeStatusHost.markRuntimeUnavailable(reason: "model install completed")
        DiagnosticsLog.shared.record("runtime-bootstrap", metadata: modelRuntimeBundle.diagnosticsMetadata)
        refreshRuntimeChrome()
        warmModelRuntime()
    }

    private func cancelModelInstall() {
        modelInstallLifecycleHost.cancel()
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

        diagnosticsWindowHost.show(DiagnosticsWindowPresentation(
            bundleIdentifier: bundleIdentifier,
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
            personalCaptureScorecard: appSettings.personalCaptureEnabled
                ? personalCaptureEpisodes.currentScorecard()
                : nil,
            recentTraceEvents: RawAutocompleteTraceLog.shared.recentEvents(limit: 48),
            tracePath: RawAutocompleteTraceLog.shared.path,
            tracingPaused: RawAutocompleteTraceLog.shared.isPaused,
            screenshotTracingEnabled: RawAutocompleteTraceLog.shared.screenshotTracingEnabled
                || compatibilityLearningStore.profile(for: bundleIdentifier)?.screenshotTracingEnabled == true,
            compatibilityLearningPath: compatibilityLearningStore.path,
            compatibilityLearningProfile: compatibilityLearningStore.profile(for: bundleIdentifier)
        ))
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

    private func toggleVisiblePageContext() {
        visiblePageContextEnabled.toggle()
        if !visiblePageContextEnabled {
            visiblePageContextProvider.clear()
        }
        appPreferencePersistenceHost.persistVisiblePageContextEnabled()
        lastRequestedTextBeforeCursor = nil
        invalidatePendingSuggestionRequest()
        if suggestionSession.hasVisibleSuggestion {
            hideSuggestion(reason: "visible-page-context-changed")
        }
        setSuggestionDecision("Ready: page context \(visiblePageContextEnabled ? "on" : "off")")
        DiagnosticsLog.shared.record(
            "visible-page-context-control",
            metadata: [
                "surface": "settings",
                "enabled": String(visiblePageContextEnabled),
                "screenCaptureAccess": String(CGPreflightScreenCaptureAccess())
            ]
        )
        refreshRuntimeChrome()
    }

    private func togglePersonalCapture() {
        appSettings.togglePersonalCapture()
        if !appSettings.personalCaptureEnabled {
            personalCaptureLastSnapshot = nil
        }
        personalizationCoordinator.refreshIndexing(isEnabled: appSettings.personalCaptureEnabled)
        DiagnosticsLog.shared.record(
            "personal-capture-control",
            metadata: [
                "surface": "settings",
                "enabled": String(appSettings.personalCaptureEnabled)
            ]
        )
        refreshRuntimeChrome()
    }

    @objc
    private func revealPersonalCaptureFolder() {
        do {
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: personalCaptureJournal.folderPath),
                withIntermediateDirectories: true
            )
            NSWorkspace.shared.activateFileViewerSelecting([
                URL(fileURLWithPath: personalCaptureJournal.folderPath)
            ])
        } catch {
            DiagnosticsLog.shared.record(
                "personal-capture-folder-open-failed",
                metadata: ["reason": DiagnosticValueRedactor.stringSummary(length: String(describing: error).count)]
            )
        }
    }

    private func deletePersonalCapture() {
        appSettings.personalCaptureEnabled = false
        personalCaptureLastSnapshot = nil
        personalCaptureJournal.deleteAll()
        personalCaptureEpisodes.deleteAll()
        personalizationCoordinator.deleteAll()
        DiagnosticsLog.shared.record(
            "personal-capture-deleted",
            metadata: ["surface": "settings"]
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
        acceptedAndKeptLearning = AcceptedAndKeptLearningStore()
        acceptedTextStyleMemory = AcceptedTextStyleMemoryStore()
        recentWordMemory = ScopedRecentWordMemory()
        suggestionOrchestrator.resetSuggestionAnnoyanceBackoffPolicy(
            makeSuggestionAnnoyanceBackoffPolicy()
        )
        appPreferencePersistenceHost.clearLearningData()
        DiagnosticsLog.shared.record(
            "learning-data-cleared",
            metadata: ["surface": "settings"]
        )
        refreshRuntimeChrome()
    }

    private func cycleAcceptAllShortcut() {
        setAcceptAllShortcut(keyboardShortcutConfiguration.acceptAllShortcut.next)
    }

    private func makeSuggestionAnnoyanceBackoffPolicy() -> SuggestionAnnoyanceBackoffPolicy {
        SuggestionAnnoyanceBackoffPolicy(
            prefixFamilyCooldownPolicy: PrefixFamilyCooldownPolicy(
                traceFingerprintSecret: tracePrivacySecretStore.secret()
            )
        )
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

    private func proofAdjustedActivationDecision(
        _ decision: CompletionActivationDecision,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        fieldKind: AXFieldKind
    ) -> CompletionActivationDecision {
        guard runtimeProofOptions.disablesPhraseContinuation(
            appBundleIdentifier: profile.bundleIdentifier,
            activeProofBundleIdentifiers: activeAppProofBundleIdentifiers
        ) else {
            return decision
        }

        let wordFallbackDecision = CompletionActivationPolicy(
            minimumContextCharacters: 1,
            minimumContextWords: 1,
            minimumPhraseContinuationWords: suggestionTuning.phraseStartWords,
            minimumWordCompletionCharacters: suggestionTuning.wordStartCharacters,
            maximumWordCompletionCharacters: 18,
            allowsTerminalSentenceBoundary: false,
            allowsUnfinishedWordPhraseContinuation: false,
            prefersPhraseContinuationForWordFragments: false
        ).decision(
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            isSecure: context.isSecure,
            selectedTextLength: context.selectedTextLength,
            isFieldSuppressed: suppressedFieldIdentities.contains(fieldIdentity),
            fieldKind: fieldKind,
            allowsUnknownFieldKind: profile.allowsUnknownFieldKind
        )

        return proofActivationModePolicy.adjustedDecision(
            original: decision,
            wordFallback: wordFallbackDecision,
            disablesPhraseContinuation: true,
            disablesWordCompletion: runtimeProofOptions.disablesWordCompletion(
                appBundleIdentifier: profile.bundleIdentifier,
                activeProofBundleIdentifiers: activeAppProofBundleIdentifiers
            )
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

    private func shouldAskModelForWordCompletionFallback(
        visiblePageContext: VisiblePageContext?
    ) -> Bool {
        suggestionTuning.allowsModelWordCompletionFallback(
            visiblePageContextAvailable: visiblePageContext != nil
        )
    }

    private func shouldUsePredictiveWordFallback(
        profile: CompatibilityProfile,
        visiblePageContext: VisiblePageContext?
    ) -> Bool {
        suggestionTuning.allowsPredictiveWordFallback(
            appBundleIdentifier: profile.bundleIdentifier,
            visiblePageContextAvailable: visiblePageContext != nil
        )
    }

    private func shouldUsePredictivePhraseFallback(
        profile: CompatibilityProfile,
        behaviorProfileID: AutocompleteBehaviorProfileID?,
        visiblePageContext: VisiblePageContext?
    ) -> Bool {
        suggestionTuning.allowsPredictivePhraseFallback(
            appBundleIdentifier: profile.bundleIdentifier,
            behaviorProfileID: behaviorProfileID,
            visiblePageContextAvailable: visiblePageContext != nil
        )
    }

    private func setAcceptAllShortcut(_ shortcut: AcceptAllShortcut) {
        keyboardShortcutConfiguration.acceptAllShortcut = shortcut
        appPreferencePersistenceHost.persistKeyboardShortcutConfiguration()
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
        appPreferencePersistenceHost.persistSuggestionTuning()
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
        codexPromptTargetContinuityHost.reset()
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
        appProofModeCoordinator.begin(for: bundleIdentifier)
    }

    private func endAppProofMode(for bundleIdentifier: String, reason: String) {
        appProofModeCoordinator.end(for: bundleIdentifier, reason: reason)
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
        let transition = suggestionPauseStateHost.toggle()

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
        suggestionPauseStateHost.applyScheduledPause(state)
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
    static var proofModeBundleIDsEnvironmentKey: String {
        "AUTOCOMPLETE_LAB_PROOF_MODE_BUNDLE_IDS"
    }

    static var proofSuppressAnnoyanceLearningEnvironmentKey: String {
        "AUTOCOMPLETE_LAB_PROOF_SUPPRESS_ANNOYANCE_LEARNING"
    }

    static func environmentFlagEnabled(_ value: String?) -> Bool {
        guard let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }
        return ["1", "true", "yes", "on"].contains(normalized)
    }

    func proofSuppressesAnnoyanceLearning() -> Bool {
        Self.environmentFlagEnabled(
            ProcessInfo.processInfo.environment[Self.proofSuppressAnnoyanceLearningEnvironmentKey]
        )
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

    func loadDisabledApps() {
        appEnablementHost.load()
    }

    func loadProofModeOverrides() {
        appProofModeCoordinator.loadEnvironmentOverrides()
    }

    func persistDisabledApps() {
        appEnablementHost.persist()
    }

    func markAppEnablementSetupCompleted() {
        appEnablementHost.markSetupCompleted()
    }

}

struct InsertionVerificationBaseline: Equatable {
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
    var retryCount: Int
}

enum FocusedInsertionVerificationContext {
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
    case nativeProofOnly

    var traceMechanism: InsertionUndoRecoverabilityLevel {
        switch self {
        case .appRollback:
            .appRollback
        case .nativeProofOnly:
            .nativeSingleEdit
        }
    }

    static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> AcceptedInsertionUndoRecoveryMode {
        switch environment["AUTOCOMPLETE_LAB_ACCEPTED_INSERTION_UNDO_RECOVERY"]?.lowercased() {
        case "native", "nativeonly", "native-proof", "nativeproofonly", "native-pass-through":
            .nativeProofOnly
        default:
            .appRollback
        }
    }
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

// MARK: - Application lifecycle wiring

extension AppDelegate: AppLifecycleHandling {
    func prepareForLaunch() {
        prepareForAppLaunch()
    }

    func startStatusMenu() {
        statusMenuHost.start(pauseSuggestionsTitle: pauseSuggestionsTitle)
    }

    func recordLaunchDiagnostics() {
        recordAppLaunchDiagnostics()
    }

    func requestAccessibilityPermissionIfNeeded() {
        requestAccessibilityPermissionIfNeededAtLaunch()
    }

    func showSettingsIfNeeded() {
        showSettingsIfNeededAtLaunch()
    }

    func startWorkspaceObserver() {
        workspaceObserverHost.start()
    }

    func startSuggestionPipeline() {
        suggestionPipeline.startPolling()
    }

    func startResourceDiagnostics() {
        resourceDiagnosticsHost.start()
    }

    func stopForTermination() {
        stopForAppTermination()
    }
}

// MARK: - Settings window wiring

extension AppDelegate: SettingsWindowActionHandling {
    func handleSettingsWindowAction(_ action: SettingsWindowAction) {
        switch action {
        case .requestPermission:
            requestAccessibilityPermission()
        case .openAccessibilitySettings:
            openAccessibilitySettings()
        case .toggleSuggestionsPaused:
            togglePauseSuggestions()
        case .pauseSuggestionsFor15Minutes:
            pauseSuggestionsFor15Minutes()
        case .pauseSuggestionsFor1Hour:
            pauseSuggestionsFor1Hour()
        case .pauseSuggestionsUntilTomorrow:
            pauseSuggestionsUntilTomorrowFromControl()
        case .silenceCurrentField:
            silenceCurrentField()
        case let .performRuntimeAction(action):
            performRuntimeAction(action)
        case .toggleCurrentApp:
            toggleCurrentApp()
        case .toggleCurrentAppMirrorMode:
            toggleCurrentAppMirrorMode()
        case .startCurrentAppProof:
            startCurrentAppProof()
        case .startTextEditPractice:
            startTextEditPractice()
        case .enableAllApps:
            enableAllDisabledApps()
        case .toggleTracingPaused:
            toggleSettingsTracingPaused()
        case .toggleRawContentTracing:
            toggleRawContentTracing()
        case .toggleScreenshotTracing:
            toggleGlobalScreenshotTracing()
        case .toggleVisiblePageContext:
            toggleVisiblePageContext()
        case .togglePersonalCapture:
            togglePersonalCapture()
        case .revealPersonalCaptureFolder:
            revealPersonalCaptureFolder()
        case .deletePersonalCapture:
            deletePersonalCapture()
        case .deleteLocalLogs:
            deleteLocalPrivacyLogs()
        case .clearLearningData:
            clearLearningData()
        case .exportPrivacyBundle:
            exportTraceReport()
        case .cycleAcceptAllShortcut:
            cycleAcceptAllShortcut()
        case let .setAcceptAllShortcut(shortcut):
            setAcceptAllShortcut(shortcut)
        case let .setSuggestionAggressivenessLevel(level):
            setSuggestionAggressivenessLevel(level)
        case let .setSuggestionMaxVisibleWords(words):
            setSuggestionMaxVisibleWords(words)
        case let .setSuggestionWordStartCharacters(characters):
            setSuggestionWordStartCharacters(characters)
        case let .setSuggestionPhraseStartWords(words):
            setSuggestionPhraseStartWords(words)
        case let .setSuggestionResponseSpeedLevel(level):
            setSuggestionResponseSpeedLevel(level)
        case let .setSuggestionConfidenceLevel(level):
            setSuggestionConfidenceLevel(level)
        case let .setSuggestionLearningRestraintLevel(level):
            setSuggestionLearningRestraintLevel(level)
        case .resetSuggestionTuning:
            resetSuggestionTuning()
        }
    }
}

// MARK: - Status menu wiring

extension AppDelegate: StatusMenuActionHandling {
    func handleStatusMenuAction(_ action: StatusMenuAction) {
        switch action {
        case .suggestNow:
            requestSuggestionNow(source: "menu")
        case .togglePauseSuggestions:
            togglePauseSuggestions()
        case .pauseSuggestionsFor15Minutes:
            pauseSuggestionsFor15Minutes()
        case .pauseSuggestionsFor1Hour:
            pauseSuggestionsFor1Hour()
        case .pauseSuggestionsUntilTomorrow:
            pauseSuggestionsUntilTomorrowFromControl()
        case .toggleCurrentApp:
            toggleCurrentApp()
        case .silenceCurrentField:
            silenceCurrentField()
        case .showSettings:
            showSettings()
        case .openFeedbackForm:
            openFeedbackForm()
        case .showDiagnostics:
            showDiagnostics()
        case .revealModelFolder:
            revealModelFolder()
        case .revealPersonalCaptureFolder:
            revealPersonalCaptureFolder()
        case .nudgeSuggestionUp:
            nudgeCurrentAppSuggestionUp()
        case .nudgeSuggestionDown:
            nudgeCurrentAppSuggestionDown()
        case .nudgeSuggestionLeft:
            nudgeCurrentAppSuggestionLeft()
        case .nudgeSuggestionRight:
            nudgeCurrentAppSuggestionRight()
        case .resetCurrentAppLearning:
            resetCurrentAppLearning()
        case .quit:
            quit()
        }
    }
}

// MARK: - Model install lifecycle wiring

extension AppDelegate: RuntimeStatusHandling {
    var modelRuntimeBundleForStatus: AppModelRuntimeBundle {
        modelRuntimeBundle
    }

    var isModelInstallInProgressForStatus: Bool {
        modelInstallLifecycleHost.isInstalling
    }

    var completionLengthDisplaySummaryForStatus: String {
        completionLengthConfiguration.displaySummary
    }

    func refreshRuntimeStatusChrome() {
        refreshRuntimeChrome()
    }

    func rearmFocusedTextAfterRuntimeReadyForStatus() {
        rearmFocusedTextAfterRuntimeReady()
    }

    func showRuntimeSettings() {
        showSettings()
    }
}

extension AppDelegate: ModelInstallLifecycleHandling {
    var modelRuntimeBundleForInstall: AppModelRuntimeBundle {
        modelRuntimeBundle
    }

    func setModelInstallStatus(_ statusText: String?) {
        runtimeStatusHost.setModelInstallStatus(statusText)
    }

    func refreshModelInstallUI() {
        refreshRuntimeChrome()
    }

    func showModelInstallSettings() {
        showSettings()
    }
}

// MARK: - Diagnostics window wiring

extension AppDelegate: DiagnosticsWindowActionHandling {
    func refreshDiagnostics() {
        showDiagnostics()
    }

    func toggleDiagnosticsTracing() {
        toggleTracing()
    }

    func toggleDiagnosticsScreenshotTracing(for bundleIdentifier: String) {
        toggleScreenshotTracing(for: bundleIdentifier)
    }

    func openDiagnosticsTraceFolder() {
        openTraceFolder()
    }

    func exportDiagnosticsTraceReport() {
        exportTraceReport()
    }

    func deleteDiagnosticsTraces() {
        deleteLocalPrivacyLogs(refreshSettings: false)
        showDiagnostics()
    }
}

// MARK: - Insertion verification host

extension AppDelegate: InsertionVerificationHandling {
    func insertionVerificationContext(
        for baseline: InsertionVerificationBaseline,
        acceptedText: String
    ) -> FocusedInsertionVerificationContext {
        focusedInsertionVerificationContext(for: baseline, acceptedText: acceptedText)
    }

    func retryAcceptedInsertion(
        _ acceptedText: String,
        skippingInsertionModes: Set<InsertionMode>,
        action: KeyboardAction?
    ) -> Bool {
        insertAcceptedText(
            acceptedText,
            skippingInsertionModes: skippingInsertionModes,
            action: action
        )
    }

    func handleInsertionVerificationFailure(
        acceptedText: String,
        baseline: InsertionVerificationBaseline,
        context: FocusedTextContext,
        result: InsertionVerificationResult
    ) {
        let resultDescription = String(describing: result)
        DiagnosticsLog.shared.record(
            "insert-verification-final-failure",
            metadata: [
                "app": baseline.profile.bundleIdentifier,
                "result": resultDescription,
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
            outcome: resultDescription,
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
        recordPersonalCaptureSuggestionEpisodeInsertionFailed(
            baseline: baseline,
            outcome: resultDescription,
            reason: "insert-verification-failed"
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
                "insertionResult": resultDescription
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
    }

    func handleInsertionVerificationSuccess(
        acceptedText: String,
        baseline: InsertionVerificationBaseline
    ) {
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
        recordPersonalCaptureSuggestionEpisodeAction(
            suggestionID: baseline.suggestionID ?? "",
            appBundleIdentifier: baseline.profile.bundleIdentifier,
            outcome: .accepted,
            reason: "insertion-verified",
            acceptedText: acceptedText,
            metadata: [
                "acceptanceID": baseline.acceptanceID,
                "acceptMode": baseline.acceptMode,
                "fieldKind": baseline.fieldKind.rawValue,
                "fieldKindReason": baseline.fieldKindReason,
                "behaviorProfile": baseline.behaviorProfileID.rawValue
            ]
        )
        recordPersonalCaptureAcceptedSuggestion(
            acceptedText: acceptedText,
            baseline: baseline
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

// MARK: - Workspace observer wiring

extension AppDelegate: WorkspaceObserverEventHandling {
    func handleWorkspaceObserverEvent(_ event: WorkspaceObserverEvent) {
        switch event {
        case let .workspaceFocusChanged(reason, kind, bundleIdentifier):
            handleWorkspaceFocusChange(
                reason: reason,
                kind: kind,
                bundleIdentifier: bundleIdentifier
            )
        case let .suggestionInterruption(kind):
            handleSuggestionInterruption(kind)
        case .screenGeometryChanged:
            handleScreenGeometryChange()
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
            hasPersonalCapture: appSettings.personalCaptureEnabled,
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
