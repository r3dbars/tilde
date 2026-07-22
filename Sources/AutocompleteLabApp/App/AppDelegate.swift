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

    let accessibilityClient = AccessibilityClient()
    private lazy var accessibilityPermissionHost = AccessibilityPermissionHost(client: accessibilityClient)
    private let startupOnboardingPolicy = StartupOnboardingPolicy()
    let appSettings = AppSettings()
    private let profileStore = CompatibilityProfileStore.mvp
    private let promptEditorPolicy = PromptEditorFingerprintPolicy()
    private let promptProofFieldIdentityRefreshPolicy = PromptProofFieldIdentityRefreshPolicy()
    private let browserHostedSurfacePolicy = BrowserHostedSurfacePolicy()
    private let suggestionSilenceExplanationPolicy = SuggestionSilenceExplanationPolicy()
    private let personalCapturePolicy = PersonalCapturePolicy()
    private let personalizationCoordinator = PersonalizationCoordinator()
    private lazy var personalCaptureHost = PersonalCaptureHost(
        dependencies: PersonalCaptureHostDependencies(
            isEnabled: { [weak self] in self?.appSettings.personalCaptureEnabled ?? false },
            runtimeDiagnosticsMetadata: { [weak self] in self?.modelRuntimeBundle.diagnosticsMetadata ?? [:] },
            fingerprintSecret: { [weak self] in self?.tracePrivacySecretStore.secret() },
            compactRect: { [weak self] rect in
                guard let rect else { return "none" }
                return self?.compactRectDescription(rect) ?? "none"
            }
        )
    )
    private let suggestionSessionBehaviors = SuggestionSessionBehaviors()
    private let suggestionPauseSchedulePolicy = SuggestionPauseSchedulePolicy()
    private let suggestionAggressivenessPolicy = SuggestionAggressivenessPolicy()
    private let visiblePageContextProvider = VisiblePageContextProvider()
    private let fieldClassifier = AXFieldClassifier()
    private let textContextRepairPolicy = TextContextRepairPolicy()
    private let obsidianTrustedEndOfDocumentSnapshotPolicy = ObsidianTrustedEndOfDocumentSnapshotPolicy()
    private let tracePrivacySecretStore = TracePrivacySecretStore()
    private let suggestionCadenceResetPolicy = SuggestionCadenceResetPolicy()
    var modelRuntimeBundle = AppModelRuntimeFactory.makeRuntime()
    private let modelRuntimeWarmHost = ModelRuntimeWarmHost()
    lazy var runtimeStatusHost = RuntimeStatusHost(handler: self)
    lazy var modelInstallLifecycleHost = ModelInstallLifecycleHost(handler: self)
    private let runtimeProofOptions = RuntimeProofOptions.fromProcessEnvironment()
    private lazy var appEnablementHost = AppEnablementHost(profileStore: profileStore)
    private lazy var appTargetStateHost = AppTargetStateHost(profileStore: profileStore)
    private lazy var suggestionPauseStateHost = SuggestionPauseStateHost(
        controlPolicy: suggestionSessionBehaviors.control,
        schedulePolicy: suggestionPauseSchedulePolicy,
        onTimedPauseEnded: { [weak self] in
            self?.setSuggestionDecision("Ready: timed pause ended")
            self?.refreshRuntimeChrome()
        }
    )
    var completionLengthConfiguration: CompletionLengthConfiguration {
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
    private let focusedTextAXHealthHost = FocusedTextAXHealthHost()
    private let focusedTextContextDiagnosticsHost = FocusedTextContextDiagnosticsHost()
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
    lazy var suggestionPipeline = SuggestionPipelineController(host: self)
    private lazy var diagnosticsWindowHost = DiagnosticsWindowHost(handler: self)
    private let appProofCommandCoordinator = AppProofCommandCoordinator()
    private lazy var appPreferencePersistenceHost = AppPreferencePersistenceHost()
    private lazy var suggestionTuningHost = SuggestionTuningHost(
        currentTuning: { [weak self] in
            self?.appPreferencePersistenceHost.suggestionTuning ?? SuggestionTuning()
        },
        updateTuning: { [weak self] tuning in
            self?.appPreferencePersistenceHost.suggestionTuning = tuning
        },
        persistTuning: { [weak self] in
            self?.appPreferencePersistenceHost.persistSuggestionTuning()
        },
        clearPendingRequest: { [weak self] in
            self?.lastRequestedTextBeforeCursor = nil
            _ = self?.invalidatePendingSuggestionRequest()
        },
        hasVisibleSuggestion: { [weak self] in
            self?.suggestionSession.hasVisibleSuggestion == true
        },
        hideSuggestion: { [weak self] reason in
            self?.hideSuggestion(reason: reason)
        },
        setSuggestionDecision: { [weak self] decision in
            self?.setSuggestionDecision(decision)
        },
        refreshRuntimeChrome: { [weak self] in
            self?.refreshRuntimeChrome()
        }
    )
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
    private lazy var settingsStateHost = SettingsStateHost(
        dependencies: SettingsStateHostDependencies(
            appForSettingsState: { [weak self] in self?.appForSettingsState },
            currentFieldIdentity: { [weak self] in self?.currentFieldIdentity },
            profileSupportStatus: { [weak self] bundleIdentifier in
                self?.profileStore.supportStatus(for: bundleIdentifier) ?? .unsupported
            },
            disabledBundleIdentifiers: { [weak self] in self?.disabledBundleIdentifiers ?? [] },
            renderModeOverride: { [weak self] bundleIdentifier in
                self?.compatibilityLearningStore.profile(for: bundleIdentifier)?.renderModeOverride
            },
            fieldControlTarget: { [weak self] in
                guard let self else { return nil }
                return self.appTargetStateHost.fieldControlTarget(currentFieldIdentity: self.currentFieldIdentity)
            },
            isFieldSilenced: { [weak self] fieldIdentity in
                self?.suppressedFieldIdentities.contains(fieldIdentity) == true
            },
            isTrusted: { [weak self] in self?.accessibilityClient.isTrusted ?? false },
            suggestionsPaused: { [weak self] in self?.suggestionsPaused ?? false },
            suggestionsPausedUntil: { [weak self] in self?.suggestionsPausedUntil },
            runtimeReadinessReport: { [weak self] in
                self?.runtimeReadinessReport ?? RuntimeReadinessReport(
                    stage: .runtimeUnavailable,
                    summary: "runtime unavailable",
                    action: .retry
                )
            },
            modelDirectoryPath: { [weak self] in self?.modelDirectoryPath ?? "" },
            modelInstallStatusText: { [weak self] in self?.runtimeStatusHost.modelInstallStatus ?? "" },
            modelInstallInProgress: { [weak self] in self?.modelInstallLifecycleHost.isInstalling ?? false },
            isTextEditEnabled: { [weak self] in
                guard let self else { return false }
                return !self.disabledBundleIdentifiers.contains(Self.textEditPracticeBundleIdentifier)
            },
            acceptAllShortcut: { [weak self] in
                self?.keyboardShortcutConfiguration.acceptAllShortcut ?? .disabled
            },
            tracingPaused: { RawAutocompleteTraceLog.shared.isPaused },
            rawContentTracingEnabled: { RawAutocompleteTraceLog.shared.rawContentTracingEnabled },
            rawContentTracingExpiresAt: { RawAutocompleteTraceLog.shared.rawContentTracingExpiresAt },
            screenshotTracingEnabled: { RawAutocompleteTraceLog.shared.screenshotTracingEnabled },
            screenshotTracingExpiresAt: { RawAutocompleteTraceLog.shared.screenshotTracingExpiresAt },
            visiblePageContextEnabled: { [weak self] in self?.visiblePageContextEnabled ?? false },
            personalCaptureEnabled: { [weak self] in self?.appSettings.personalCaptureEnabled ?? false },
            diagnosticsPath: { DiagnosticsLog.shared.path },
            tracePath: { RawAutocompleteTraceLog.shared.path },
            personalCapturePath: { PersonalCaptureJournalWriter.shared.folderPath },
            suggestionTuning: { [weak self] in self?.suggestionTuning ?? SuggestionTuning() },
            modelName: { [weak self] in
                self?.modelRuntimeBundle.bootstrapPlan.preferredAsset.model.rawValue ?? "unknown"
            },
            completionLengthSummary: { [weak self] in self?.completionLengthConfiguration.displaySummary ?? "default" }
        )
    )
    lazy var statusMenuHost = StatusMenuHost(
        handler: self,
        developerMenuEnabled: developerMenuEnabled
    )
    private lazy var statusChromeHost = StatusChromeHost(
        statusMenuHost: statusMenuHost,
        settingsWindow: { [weak self] in self?.settingsWindow }
    )
    lazy var workspaceObserverHost = WorkspaceObserverHost(handler: self)
    let resourceDiagnosticsHost = ResourceDiagnosticsHost()
    private lazy var appLifecycleHost = AppLifecycleHost(handler: self)

    private lazy var suggestionSummonHotKey = SuggestionSummonHotKey { [weak self] in
        self?.requestSuggestionNow(source: "hotkey")
    }
    private let prefixCooldownRetryHost = PrefixCooldownRetryHost()
    let suggestionSession = SuggestionSessionHost()
    private let focusedTextSessionStateHost = FocusedTextSessionStateHost()
    private var lastCaretRect: CGRect?
    private var lastTextLineRect: CGRect?
    private var lastClippingRect: CGRect?
    private var lastTextStyle: FocusedTextStyle?
    private var lastRenderMode: SuggestionRenderMode?
    private var lastCompatibilityLearningTrustContext: CompatibilityLearningVisualTrustContext?
    private var lastVisibleSuggestionGeometrySnapshot: SuggestionGeometrySnapshot?
    private var currentFieldIdentity: FocusedFieldIdentity? {
        get { focusedTextSessionStateHost.currentFieldIdentity }
        set { focusedTextSessionStateHost.currentFieldIdentity = newValue }
    }
    private var currentProfile: CompatibilityProfile? {
        get { focusedTextSessionStateHost.currentProfile }
        set { focusedTextSessionStateHost.currentProfile = newValue }
    }
    private var lastTextSnapshot: FocusedTextSnapshot? {
        get { focusedTextSessionStateHost.lastTextSnapshot }
        set { focusedTextSessionStateHost.lastTextSnapshot = newValue }
    }
    private var lastTrustedObsidianEndOfDocumentSnapshot: FocusedTextSnapshot? {
        get { focusedTextSessionStateHost.lastTrustedObsidianEndOfDocumentSnapshot }
        set { focusedTextSessionStateHost.lastTrustedObsidianEndOfDocumentSnapshot = newValue }
    }
    var lastFocusedTextChangeAt: Date? {
        get { focusedTextSessionStateHost.lastFocusedTextChangeAt }
        set { focusedTextSessionStateHost.lastFocusedTextChangeAt = newValue }
    }
    private var lastRequestedTextBeforeCursor: String? {
        get { focusedTextSessionStateHost.lastRequestedTextBeforeCursor }
        set { focusedTextSessionStateHost.lastRequestedTextBeforeCursor = newValue }
    }
    private let manualSuggestionRequestHost = ManualSuggestionRequestHost()
    private var suppressedFieldIdentities: Set<FocusedFieldIdentity> = []
    private var disabledBundleIdentifiers: Set<String> {
        get { appEnablementHost.disabledBundleIdentifiers }
        set { appEnablementHost.disabledBundleIdentifiers = newValue }
    }
    private let suggestionRequestScheduler = SuggestionRequestScheduler()
    private lazy var insertionVerificationHost = InsertionVerificationHost(handler: self)
    private let acceptanceSurvivalChecker = AcceptanceSurvivalChecker()
    private let acceptanceSurvivalTaskHost = AcceptanceSurvivalTaskHost()
    private lazy var suggestionRequestCancellationHost = SuggestionRequestCancellationHost(
        dependencies: SuggestionRequestCancellationHostDependencies(
            cancelPendingRequest: { [weak self] in
                self?.suggestionRequestScheduler.cancelPendingRequest() ?? false
            },
            clearStreamingPresentations: { [weak self] in
                self?.suggestionOrchestrator.clearStreamingPresentations()
            },
            invalidateRequest: { [weak self] in
                self?.suggestionOrchestrator.invalidate()
            }
        )
    )
    private lazy var suggestionRequestPreparationHost = SuggestionRequestPreparationHost(
        dependencies: SuggestionRequestPreparationHostDependencies(
            suggestionOrchestrator: suggestionOrchestrator,
            acceptedTextStyleSketch: { [weak self] key in
                self?.acceptedTextStyleMemory.sketch(for: key)
            },
            personalizationCoordinator: personalizationCoordinator,
            isPersonalCaptureEnabled: { [weak self] in
                self?.appSettings.personalCaptureEnabled ?? false
            },
            suggestionTuning: { [weak self] in
                self?.suggestionTuning ?? SuggestionTuning()
            },
            requestSchedulingPolicy: suggestionSessionBehaviors.requestSchedulingPolicy
        )
    )
    private lazy var suggestionStreamingPartialHost = SuggestionStreamingPartialHost(
        dependencies: SuggestionStreamingPartialHostDependencies(
            suggestionOrchestrator: suggestionOrchestrator,
            currentFieldIdentity: { [weak self] in self?.currentFieldIdentity },
            presentSuggestion: { [weak self] suggestion, presentation in
                self?.presentSuggestion(
                    suggestion,
                    suggestionID: presentation.suggestionID,
                    request: presentation.request,
                    context: presentation.context,
                    profile: presentation.profile,
                    fieldIdentity: presentation.fieldIdentity,
                    renderMode: presentation.renderMode,
                    latencyMilliseconds: presentation.latencyMilliseconds,
                    triggerReason: "model-stream",
                    requestTicket: presentation.requestTicket,
                    candidateSelectionMetadata: presentation.candidateSelectionMetadata
                )
            }
        )
    )
    private lazy var suggestionContinuationFailureHost = SuggestionContinuationFailureHost(
        dependencies: SuggestionContinuationFailureHostDependencies(
            suggestionOrchestrator: suggestionOrchestrator,
            currentSuggestionID: { [weak self] in self?.currentSuggestionState.id },
            currentFieldIdentity: { [weak self] in self?.currentFieldIdentity },
            hasVisibleSuggestion: { [weak self] in self?.suggestionSession.hasVisibleSuggestion == true },
            setSuggestionDecision: { [weak self] decision in self?.setSuggestionDecision(decision) },
            repositionVisibleSuggestion: { [weak self] context, profile in
                self?.repositionVisibleSuggestion(context: context, profile: profile)
            },
            updateKeyboardEventTapSnapshot: { [weak self] in self?.updateKeyboardEventTapSnapshot() },
            hideSuggestion: { [weak self] reason in self?.hideSuggestion(reason: reason) }
        )
    )
    private lazy var suggestionModelResultHost = SuggestionModelResultHost(
        dependencies: SuggestionModelResultHostDependencies(
            suggestionOrchestrator: suggestionOrchestrator,
            requestSchedulingPolicy: suggestionSessionBehaviors.requestSchedulingPolicy,
            currentSuggestionID: { [weak self] in self?.currentSuggestionState.id },
            currentFieldIdentity: { [weak self] in self?.currentFieldIdentity },
            hasVisibleSuggestion: { [weak self] in self?.suggestionSession.hasVisibleSuggestion == true },
            recordSuggestionEvent: { [weak self] event, context, profile, metadata in
                self?.recordSuggestionEvent(event, context: context, profile: profile, metadata: metadata)
            },
            setSuggestionDecision: { [weak self] decision in self?.setSuggestionDecision(decision) },
            repositionVisibleSuggestion: { [weak self] context, profile in
                self?.repositionVisibleSuggestion(context: context, profile: profile)
            },
            hideSuggestion: { [weak self] reason in
                if let reason {
                    self?.hideSuggestion(reason: reason)
                } else {
                    self?.hideSuggestion()
                }
            },
            annoyanceContext: { [weak self] appBundleIdentifier, fieldIdentity, requestMode, fieldKind in
                self?.annoyanceContext(
                    appBundleIdentifier: appBundleIdentifier,
                    fieldIdentity: fieldIdentity,
                    requestMode: requestMode,
                    fieldKind: fieldKind
                )
            },
            recordAnnoyanceSignal: { [weak self] signal, context, suggestionID, reason in
                self?.recordAnnoyanceSignal(signal, context: context, suggestionID: suggestionID, reason: reason)
            },
            presentSuggestion: { [weak self] suggestion, presentation in
                self?.presentSuggestion(
                    suggestion,
                    suggestionID: presentation.suggestionID,
                    request: presentation.request,
                    context: presentation.context,
                    profile: presentation.profile,
                    fieldIdentity: presentation.fieldIdentity,
                    renderMode: presentation.renderMode,
                    latencyMilliseconds: presentation.latencyMilliseconds,
                    triggerReason: "model-result",
                    requestTicket: presentation.requestTicket,
                    candidateSelectionMetadata: presentation.candidateSelectionMetadata,
                    scheduledDelayMilliseconds: presentation.scheduledDelayMilliseconds
                )
            }
        )
    )
    private lazy var suggestionTypingBurstSuppressionHost = SuggestionTypingBurstSuppressionHost(
        dependencies: SuggestionTypingBurstSuppressionHostDependencies(
            cancelIdleRetry: { [weak self] in self?.suggestionIdleRetryState.cancel() },
            setSuggestionDecision: { [weak self] decision in self?.setSuggestionDecision(decision) },
            showFieldStatusIndicator: { [weak self] state, context in
                self?.showFieldStatusIndicator(state, context: context)
            },
            recordSuggestionEvent: { [weak self] event, context, profile, metadata in
                self?.recordSuggestionEvent(event, context: context, profile: profile, metadata: metadata)
            },
            recordBlockedSuggestionEvent: { [weak self] event, context, profile, fieldIdentity, metadata in
                self?.recordBlockedSuggestionEvent(
                    event,
                    context: context,
                    profile: profile,
                    fieldIdentity: fieldIdentity,
                    metadata: metadata
                )
            },
            repositionVisibleSuggestion: { [weak self] context, profile in
                self?.repositionVisibleSuggestion(context: context, profile: profile)
            },
            updateKeyboardEventTapSnapshot: { [weak self] in self?.updateKeyboardEventTapSnapshot() },
            noteTypingBurstSuppression: { [weak self] snapshot, nowMilliseconds, settleDelayMilliseconds in
                self?.suggestionIdleRetryState.noteTypingBurstSuppression(
                    snapshot: snapshot,
                    nowMilliseconds: nowMilliseconds,
                    settleDelayMilliseconds: settleDelayMilliseconds
                )
            },
            hideSuggestion: { [weak self] reason, metadata in
                self?.hideSuggestion(reason: reason, metadata: metadata)
            }
        )
    )
    private lazy var suggestionRequestExecutionHost = SuggestionRequestExecutionHost(
        dependencies: SuggestionRequestExecutionHostDependencies(
            scheduler: suggestionRequestScheduler,
            suggestionOrchestrator: suggestionOrchestrator,
            handlePartial: { [weak self] partialSuggestion, input in
                self?.suggestionStreamingPartialHost.handle(
                    partialSuggestion: partialSuggestion,
                    suggestionID: input.suggestionID,
                    request: input.request,
                    context: input.context,
                    profile: input.profile,
                    appBundleIdentifier: input.appBundleIdentifier,
                    fieldIdentity: input.fieldIdentity,
                    renderMode: input.renderMode,
                    requestTicket: input.requestTicket,
                    requestStartedAt: input.requestStartedAt
                )
            },
            handleFinal: { [weak self] suggestion, input in
                self?.suggestionModelResultHost.handle(suggestion: suggestion, input: input)
            },
            handleFailure: { [weak self] input in
                self?.suggestionContinuationFailureHost.handle(
                    suggestionID: input.suggestionID,
                    requestTicket: input.requestTicket,
                    fieldIdentity: input.fieldIdentity,
                    context: input.context,
                    profile: input.profile
                )
            }
        )
    )
    private lazy var suggestionPresentationRefreshHost = SuggestionPresentationRefreshHost(
        dependencies: SuggestionPresentationRefreshHostDependencies(
            frontmostApplication: { [weak self] in self?.accessibilityClient.frontmostApplication() },
            focusedTextContext: { [weak self] app, profile in
                self?.accessibilityClient.focusedTextContext(
                    for: app,
                    allowDescendantTextFallback: profile.allowsDescendantTextFallback,
                    options: FocusedTextReadOptionsPolicy.options(for: app, profile: profile)
                )
            },
            frontmostAppMatchesSuggestion: { [weak self] app, expectedBundleIdentifier, profile in
                self?.frontmostAppMatchesSuggestion(
                    app,
                    expectedBundleIdentifier: expectedBundleIdentifier,
                    profile: profile
                ) ?? false
            },
            promptTextAreaMatch: { [weak self] bundleIdentifier, context in
                guard let self else {
                    return SuggestionPresentationPromptMatch(canSuggest: false, reason: "missing-app")
                }
                let match = self.promptTextAreaMatch(for: bundleIdentifier, context: context)
                return SuggestionPresentationPromptMatch(canSuggest: match.canSuggest, reason: match.reason)
            },
            lastTextSnapshot: { [weak self] in self?.lastTextSnapshot },
            presentationAdjustedContext: { [weak self] context, app, profile, previousSnapshot in
                self?.presentationAdjustedContext(
                    context,
                    app: app,
                    profile: profile,
                    previousSnapshot: previousSnapshot
                )
            },
            fieldIdentity: { [weak self] app, context, profile in
                self?.fieldIdentity(app: app, context: context, profile: profile)
            },
            canTrustPromptProofFieldIdentityRefresh: { [weak self] requestFieldIdentity, refreshedFieldIdentity, profile in
                self?.canTrustPromptProofFieldIdentityRefresh(
                    requestFieldIdentity: requestFieldIdentity,
                    refreshedFieldIdentity: refreshedFieldIdentity,
                    profile: profile
                ) ?? false
            },
            recordDiagnostic: { name, metadata in
                DiagnosticsLog.shared.record(name, metadata: metadata)
            }
        )
    )
    private lazy var suggestionPresentationCommitHost = SuggestionPresentationCommitHost(
        dependencies: SuggestionPresentationCommitHostDependencies(
            suggestionSession: suggestionSession,
            currentSuggestionState: currentSuggestionState,
            targetFingerprint: { [weak self] context in
                self?.targetFingerprint(context: context)
            },
            setSuggestionDecision: { [weak self] decision in self?.setSuggestionDecision(decision) },
            activateKeyboardCapture: { [weak self] in
                guard let self else { return false }
                return self.keyboardEventCaptureHost.activateForSuggestionPresentation(
                    isTrustedForAccessibility: self.accessibilityClient.isTrusted,
                    hasVisibleSuggestion: self.suggestionSession.hasVisibleSuggestion,
                    controlState: self.suggestionControlState,
                    snapshot: self.keyboardEventTapSnapshot()
                )
            },
            handleKeyboardCaptureUnavailable: { [weak self] in
                self?.setSuggestionDecision("Blocked: keyboard capture unavailable")
                self?.hideSuggestion(reason: "keyboard-capture-unavailable")
            },
            recordGeometry: { [weak self] input in
                self?.lastCaretRect = input.deliveredPlacement.anchorRect
                self?.lastTextLineRect = input.deliveredPlacement.textLineRect
                self?.lastClippingRect = input.deliveredPlacement.clippingRect
                self?.lastTextStyle = input.context.textStyle
                self?.lastRenderMode = input.deliveredPlacement.renderMode
                self?.lastVisibleSuggestionGeometrySnapshot = self?.visibleGeometrySnapshot(
                    context: input.context,
                    fieldIdentity: input.fieldIdentity,
                    placement: input.deliveredPlacement
                )
            },
            screenshotCapture: traceScreenshotCaptureCoordinator,
            compatibilityLearningStore: compatibilityLearningStore,
            presentationDelivery: suggestionChromeHost.presentationDelivery,
            recordPersonalCaptureEpisodePresented: { [weak self] input, screenshotCapture, payload in
                self?.recordPersonalCaptureSuggestionEpisodePresented(
                    suggestionID: input.suggestionID,
                    request: input.request,
                    context: input.context,
                    profile: input.profile,
                    fieldIdentity: input.fieldIdentity,
                    fieldClassification: input.rawDisplayFieldClassification,
                    suggestion: input.suggestion,
                    latencyMilliseconds: input.latencyMilliseconds,
                    triggerReason: input.triggerReason,
                    placement: input.deliveredPlacement,
                    panelRect: input.panelRect,
                    screenshotPath: screenshotCapture.path,
                    metadata: payload.rawTraceMetadata
                )
            },
            recordSuggestionEvent: { [weak self] input, payload in
                self?.recordSuggestionEvent(
                    "suggestion-presented",
                    context: input.context,
                    profile: input.profile,
                    metadata: payload.diagnosticsMetadata
                )
            },
            updateKeyboardEventTapSnapshot: { [weak self] in self?.updateKeyboardEventTapSnapshot() }
        )
    )
    private lazy var suggestionPresentationSuppressionTraceHost = SuggestionPresentationSuppressionTraceHost(
        dependencies: SuggestionPresentationSuppressionTraceHostDependencies(
            recordSuggestionEvent: { [weak self] event, context, profile, metadata in
                self?.recordSuggestionEvent(
                    event,
                    context: context,
                    profile: profile,
                    metadata: metadata
                )
            }
        )
    )
    private lazy var suggestionPresentationDeliveryHost = SuggestionPresentationDeliveryHost(
        dependencies: SuggestionPresentationDeliveryHostDependencies(
            presentationDelivery: suggestionChromeHost.presentationDelivery,
            suppressionTraceHost: suggestionPresentationSuppressionTraceHost,
            setSuggestionDecision: { [weak self] decision in self?.setSuggestionDecision(decision) },
            hideSuggestion: { [weak self] reason in self?.hideSuggestion(reason: reason) }
        )
    )
    private lazy var suggestionPresentationPreparationHost = SuggestionPresentationPreparationHost(
        dependencies: SuggestionPresentationPreparationHostDependencies(
            compatibilityLearningStore: compatibilityLearningStore,
            visualTrustContext: { [weak self] context, bundleIdentifier in
                self?.compatibilityLearningVisualTrustContext(
                    for: context,
                    bundleIdentifier: bundleIdentifier
                ) ?? CompatibilityLearningVisualTrustContext()
            },
            placementHealthPlan: { [weak self] context, profile, adjustment, screenshotTracingEnabled in
                guard let self else {
                    return .suppress(
                        PlacementHealthSuppression(
                            requestedRenderMode: adjustment.effectiveRenderMode,
                            reason: .disabled
                        )
                    )
                }
                return self.suggestionOrchestrator.placementHealthPlan(
                    context: context,
                    profile: profile,
                    learningAdjustment: adjustment,
                    screenshotTracingEnabled: screenshotTracingEnabled
                )
            }
        )
    )
    private lazy var suggestionPresentationPlacementHost = SuggestionPresentationPlacementHost(
        dependencies: SuggestionPresentationPlacementHostDependencies(
            suppressionTraceHost: suggestionPresentationSuppressionTraceHost,
            recordPlacementUncertainty: { [weak self] input, reason, metadata in
                self?.recordPlacementUncertainty(
                    suggestionID: input.suggestionID,
                    appBundleIdentifier: input.request.appBundleIdentifier ?? input.profile.bundleIdentifier,
                    fieldIdentity: input.fieldIdentity,
                    requestMode: input.request.mode,
                    context: input.context,
                    reason: reason,
                    metadata: metadata
                )
            },
            setSuggestionDecision: { [weak self] decision in self?.setSuggestionDecision(decision) },
            hideSuggestion: { [weak self] reason in self?.hideSuggestion(reason: reason) }
        )
    )
    private lazy var suggestionTriggerTimingHost = SuggestionTriggerTimingHost(
        dependencies: SuggestionTriggerTimingHostDependencies(
            triggerPolicy: { [weak self] profile in
                self?.triggerPolicy(for: profile) ?? SuggestionTriggerPolicy()
            },
            consumeManualSuggestionRequest: { [weak self] in
                self?.manualSuggestionRequestHost.consumePendingRequest() == true
            },
            hasVisibleSuggestion: { [weak self] in self?.suggestionSession.hasVisibleSuggestion == true },
            setSuggestionDecision: { [weak self] decision in self?.setSuggestionDecision(decision) },
            showFieldStatusIndicator: { [weak self] state, context in
                self?.showFieldStatusIndicator(state, context: context)
            },
            repositionVisibleSuggestion: { [weak self] context, profile in
                self?.repositionVisibleSuggestion(context: context, profile: profile)
            },
            recordSuggestionEvent: { [weak self] event, context, profile, metadata in
                self?.recordSuggestionEvent(
                    event,
                    context: context,
                    profile: profile,
                    metadata: metadata
                )
            },
            hideSuggestion: { [weak self] in self?.hideSuggestion() },
            scheduleSuggestion: { [weak self] schedule in
                self?.scheduleSuggestion(
                    context: schedule.context,
                    profile: schedule.profile,
                    appBundleIdentifier: schedule.suggestionAppBundleIdentifier,
                    fieldIdentity: schedule.fieldIdentity,
                    fieldClassification: schedule.fieldClassification,
                    renderMode: schedule.renderMode,
                    delayMilliseconds: schedule.delayMilliseconds,
                    timingLane: schedule.timingLane,
                    requestMode: schedule.requestMode,
                    typingBurstDecision: schedule.typingBurstDecision,
                    visiblePageContext: schedule.visiblePageContext,
                    triggerReason: schedule.triggerReason
                )
            }
        )
    )
    private lazy var suggestionSchedulingHost = SuggestionSchedulingHost(
        dependencies: SuggestionSchedulingHostDependencies(
            cancelPrefixCooldownRetry: { [weak self] in self?.cancelPrefixCooldownRetry() },
            cancelPendingSuggestionTask: { [weak self] reason in
                self?.cancelPendingSuggestionTask(reason: reason)
            },
            setLastRequestedTextBeforeCursor: { [weak self] text in
                self?.lastRequestedTextBeforeCursor = text
            },
            suggestionRequestPreparationHost: suggestionRequestPreparationHost,
            suggestionOrchestrator: suggestionOrchestrator,
            runtimeProofOptions: runtimeProofOptions,
            activeAppProofBundleIdentifiers: activeAppProofBundleIdentifiers,
            recentWordMemoryWords: { [weak self] scope in
                self?.recentWordMemory.words(for: scope) ?? []
            },
            suggestionSession: suggestionSession,
            currentSuggestionID: { [weak self] in self?.currentSuggestionState.id },
            acceptedAndKeptSignal: { [unowned self] request, fieldClassification, profile in
                self.acceptedAndKeptSignal(
                    request: request,
                    fieldClassification: fieldClassification,
                    profile: profile
                )
            },
            acceptedAndKeptLearning: { [weak self] in
                self?.acceptedAndKeptLearning ?? AcceptedAndKeptLearningStore()
            },
            shouldAskModelForWordCompletionFallback: { [unowned self] visiblePageContext in
                self.shouldAskModelForWordCompletionFallback(visiblePageContext: visiblePageContext)
            },
            shouldUsePredictiveWordFallback: { [unowned self] profile, visiblePageContext in
                self.shouldUsePredictiveWordFallback(
                    profile: profile,
                    visiblePageContext: visiblePageContext
                )
            },
            shouldUsePredictivePhraseFallback: { [unowned self] profile, behaviorProfileID, visiblePageContext in
                self.shouldUsePredictivePhraseFallback(
                    profile: profile,
                    behaviorProfileID: behaviorProfileID,
                    visiblePageContext: visiblePageContext
                )
            },
            triggerPolicy: { [unowned self] profile in self.triggerPolicy(for: profile) },
            suggestionTypingBurstSuppressionHost: suggestionTypingBurstSuppressionHost,
            suggestionRequestExecutionHost: suggestionRequestExecutionHost,
            suggestionIdleRetryState: suggestionIdleRetryState,
            recordSuggestionEvent: { [weak self] event, context, profile, metadata in
                self?.recordSuggestionEvent(
                    event,
                    context: context,
                    profile: profile,
                    metadata: metadata
                )
            },
            recordAnnoyanceSignal: { [weak self] signal, context, suggestionID, reason, metadata in
                self?.recordAnnoyanceSignal(
                    signal,
                    context: context,
                    suggestionID: suggestionID,
                    reason: reason,
                    metadata: metadata
                )
            },
            annoyanceContext: { [unowned self] appBundleIdentifier, fieldIdentity, requestMode, fieldKind in
                self.annoyanceContext(
                    appBundleIdentifier: appBundleIdentifier,
                    fieldIdentity: fieldIdentity,
                    requestMode: requestMode,
                    fieldKind: fieldKind
                )
            },
            setSuggestionDecision: { [weak self] decision in self?.setSuggestionDecision(decision) },
            repositionVisibleSuggestion: { [weak self] context, profile in
                self?.repositionVisibleSuggestion(context: context, profile: profile)
            },
            hideSuggestion: { [weak self] in self?.hideSuggestion() },
            presentSuggestion: { [weak self] suggestion, suggestionID, request, context, profile, fieldIdentity, renderMode, latencyMilliseconds, triggerReason, requestTicket, candidateSelectionMetadata, refreshBeforePresenting in
                self?.presentSuggestion(
                    suggestion,
                    suggestionID: suggestionID,
                    request: request,
                    context: context,
                    profile: profile,
                    fieldIdentity: fieldIdentity,
                    renderMode: renderMode,
                    latencyMilliseconds: latencyMilliseconds,
                    triggerReason: triggerReason,
                    requestTicket: requestTicket,
                    candidateSelectionMetadata: candidateSelectionMetadata,
                    refreshBeforePresenting: refreshBeforePresenting
                )
            }
        )
    )
    private lazy var suggestionPresentationOrchestrationHost = SuggestionPresentationOrchestrationHost(
        dependencies: SuggestionPresentationOrchestrationHostDependencies(
            suggestionOrchestrator: suggestionOrchestrator,
            suggestionSession: suggestionSession,
            currentSuggestionState: currentSuggestionState,
            currentFieldIdentity: { [weak self] in self?.currentFieldIdentity },
            lastTextSnapshot: { [weak self] in self?.lastTextSnapshot },
            displayScorePolicy: displayScorePolicy,
            suggestionTuning: { [unowned self] in self.suggestionTuning },
            suggestionReplacementVisibilityPolicy: suggestionReplacementVisibilityPolicy,
            maximumPreservedSuggestionDisplaySuppressionAgeMilliseconds: maximumPreservedSuggestionDisplaySuppressionAgeMilliseconds,
            suggestionPresentationPreparationHost: suggestionPresentationPreparationHost,
            suggestionPresentationSuppressionTraceHost: suggestionPresentationSuppressionTraceHost,
            suggestionPresentationPlacementHost: suggestionPresentationPlacementHost,
            suggestionPresentationDeliveryHost: suggestionPresentationDeliveryHost,
            suggestionPresentationCommitHost: suggestionPresentationCommitHost,
            refreshedPresentationContext: { [unowned self] request, requestContext, profile, fieldIdentity in
                self.refreshedPresentationContext(
                    for: request,
                    requestContext: requestContext,
                    profile: profile,
                    fieldIdentity: fieldIdentity
                )
            },
            traceGeometryMetadata: { [unowned self] context, renderMode in
                self.traceGeometryMetadata(context: context, renderMode: renderMode)
            },
            traceRequestMetadata: { [unowned self] request, context in
                self.traceRequestMetadata(request: request, context: context)
            },
            traceRequestMetadataForField: { [unowned self] request, fieldClassification in
                self.traceRequestMetadata(
                    request: request,
                    fieldClassification: fieldClassification
                )
            },
            fieldClassification: { [unowned self] context in self.fieldClassification(for: context) },
            effectiveSuggestionFieldClassification: { [unowned self] context, profile, raw in
                self.effectiveSuggestionFieldClassificationForCurrentFrontmost(
                    context: context,
                    profile: profile,
                    raw: raw
                )
            },
            acceptedAndKeptSignal: { [unowned self] request, fieldClassification, profile in
                self.acceptedAndKeptSignal(
                    request: request,
                    fieldClassification: fieldClassification,
                    profile: profile
                )
            },
            currentSuggestionAgeMilliseconds: { [unowned self] in self.currentSuggestionAgeMilliseconds() },
            setSuggestionDecision: { [weak self] decision in self?.setSuggestionDecision(decision) },
            hideSuggestion: { [weak self] reason, metadata in
                self?.hideSuggestion(reason: reason, metadata: metadata)
            },
            showFieldStatusIndicator: { [weak self] state, context in
                self?.showFieldStatusIndicator(state, context: context)
            },
            repositionVisibleSuggestion: { [weak self] context, profile in
                self?.repositionVisibleSuggestion(context: context, profile: profile)
            },
            updateKeyboardEventTapSnapshot: { [weak self] in self?.updateKeyboardEventTapSnapshot() },
            setLastCompatibilityLearningTrustContext: { [weak self] context in
                self?.lastCompatibilityLearningTrustContext = context
            },
            cancelKeyboardEventTapIdleStop: { [weak self] in self?.cancelKeyboardEventTapIdleStop() }
        )
    )
    private(set) lazy var suggestionInsertionHost = SuggestionInsertionHost(
        dependencies: SuggestionInsertionHostDependencies(
            currentProfile: { [unowned self] in self.currentProfile },
            currentSuggestionState: currentSuggestionState,
            currentFieldIdentity: { [unowned self] in self.currentFieldIdentity },
            acceptedTextSafetyPolicy: acceptedTextSafetyPolicy,
            setSuggestionDecision: { [unowned self] decision in self.setSuggestionDecision(decision) },
            hideSuggestion: { [unowned self] reason in self.hideSuggestion(reason: reason) },
            suppressPassthroughObservation: { [weak self] until in
                self?.keyboardEventTap?.suppressPassthroughObservation(until: until)
            },
            shouldUseClaudeDesktopProofDirectInsertion: { [unowned self] profile in
                self.shouldUseClaudeDesktopProofDirectInsertion(profile: profile)
            },
            shouldUseObsidianDirectValueInsertion: { [unowned self] profile, action in
                self.shouldUseObsidianDirectValueInsertion(profile: profile, action: action)
            },
            insertClaudeDesktopProofText: { [unowned self] acceptedText in
                self.insertClaudeDesktopProofText(acceptedText)
            },
            insertObsidianDirectValueText: { [unowned self] acceptedText, profile in
                self.insertObsidianDirectValueText(acceptedText, profile: profile)
            },
            repairObsidianFullAcceptCaret: { [unowned self] profile, action in
                self.repairObsidianFullAcceptCaretIfNeeded(profile: profile, action: action)
            },
            defaultInsertion: { [unowned self] acceptedText, profile, expectedFieldIdentity, skippedModes in
                return self.insertionEngine.insert(
                    acceptedText,
                    profile: profile,
                    expectedFieldIdentity: expectedFieldIdentity,
                    skipping: skippedModes
                )
            },
            pausePolling: { [unowned self] durationMilliseconds in
                self.suggestionPipeline.pausePolling(now: Date(), durationMilliseconds: durationMilliseconds)
            },
            postInsertionPollPauseMilliseconds: postInsertionPollPauseMilliseconds
        )
    )
    private lazy var insertionVerificationBaselineHost = InsertionVerificationBaselineHost(
        dependencies: InsertionVerificationBaselineHostDependencies(
            currentFieldIdentity: { [unowned self] in self.currentFieldIdentity },
            lastTextSnapshot: { [unowned self] in self.lastTextSnapshot },
            currentSuggestionState: currentSuggestionState,
            currentProfile: { [unowned self] in self.currentProfile },
            currentBehaviorProfileID: { [unowned self] in
                self.suggestionOrchestrator.currentRequest?.behaviorProfile.id
            }
        )
    )
    private lazy var suggestionAcceptanceHost = SuggestionAcceptanceHost(
        dependencies: SuggestionAcceptanceHostDependencies(
            keyboardShortcutConfiguration: { [unowned self] in self.keyboardShortcutConfiguration },
            suggestionSession: suggestionSession,
            currentSuggestionState: currentSuggestionState,
            currentProfile: { [weak self] in self?.currentProfile },
            keyboardCaptureSafetyPolicy: keyboardCaptureSafetyPolicy,
            suggestionOrchestrator: suggestionOrchestrator,
            requestSuggestionNow: { [weak self] source in self?.requestSuggestionNow(source: source) },
            undoAcceptedInsertion: { [weak self] in self?.undoAcceptedInsertion() == true },
            acceptedInsertionUndoIsActive: { [weak self] in self?.acceptedInsertionUndoIsActive() == true },
            clearPendingAcceptedInsertionUndo: { [weak self] reason in
                self?.clearPendingAcceptedInsertionUndo(reason: reason)
            },
            suppressKey: { [weak self] key in self?.suppressKey(key) },
            clearKeySuppression: { [weak self] key in self?.suppressKeyUntil[key] = nil },
            setPreservesResidualSuggestionAfterNextWordAccept: { [weak self] value in
                self?.preservesResidualSuggestionAfterNextWordAccept = value
            },
            shouldSuppressKey: { [unowned self] key, isAutorepeat in
                self.shouldSuppressKey(key, isAutorepeat: isAutorepeat)
            },
            focusedFieldMatchesCurrentSuggestion: { [unowned self] obsidianFastPath in
                self.focusedFieldMatchesCurrentSuggestion(
                    allowObsidianSnapshotFastPath: obsidianFastPath
                )
            },
            setSuggestionDecision: { [weak self] decision in self?.setSuggestionDecision(decision) },
            hideSuggestion: { [weak self] reason, metadata in
                self?.hideSuggestion(reason: reason, metadata: metadata)
            },
            recordKeyboardAction: { [unowned self] key, action, handled, reason in
                self.recordKeyboardAction(key: key, action: action, handled: handled, reason: reason)
            },
            currentSuggestionAcceptanceDecision: { [unowned self] obsidianFastPath in
                self.currentSuggestionAcceptanceDecision(
                    allowObsidianSnapshotFastPath: obsidianFastPath
                )
            },
            recordAcceptanceGuardBlock: { [unowned self] reason in self.recordAcceptanceGuardBlock(reason: reason) },
            insertionVerificationBaseline: { [unowned self] acceptanceID, acceptedAt, action, acceptMode in
                self.insertionVerificationBaselineHost.baseline(
                    acceptanceID: acceptanceID,
                    acceptedAt: acceptedAt,
                    action: action,
                    acceptMode: acceptMode
                )
            },
            acceptedTextForCurrentAcceptance: { [unowned self] acceptedText, action in
                self.acceptedTextForCurrentAcceptance(acceptedText, action: action)
            },
            suggestionAcceptanceProof: { [unowned self] action, acceptedText in
                self.suggestionAcceptanceProof(action: action, acceptedText: acceptedText)
            },
            insertAcceptedText: { [weak self] acceptedText, action in
                self?.suggestionInsertionHost.insertAcceptedText(acceptedText, action: action) ?? false
            },
            suppressCurrentFieldAfterInsertionFailure: { [weak self] reason in
                self?.suppressCurrentFieldAfterInsertionFailure(reason: reason)
            },
            completeNextWordAcceptance: { [unowned self] input in
                self.completeNextWordAcceptance(
                    acceptedText: input.acceptedText,
                    acceptanceID: input.acceptanceID,
                    acceptedAt: input.acceptedAt,
                    action: input.action,
                    acceptanceProof: input.acceptanceProof,
                    verificationBaseline: input.verificationBaseline
                )
            },
            armAcceptedInsertionUndo: { [unowned self] acceptedText, acceptanceID, acceptedAt, acceptMode in
                self.armAcceptedInsertionUndo(
                    acceptedText: acceptedText,
                    acceptanceID: acceptanceID,
                    acceptedAt: acceptedAt,
                    acceptMode: acceptMode
                )
            },
            recordAcceptedText: { [unowned self] acceptedText in self.recordAcceptedText(acceptedText) },
            armObsidianPostAcceptanceSuppressionIfNeeded: { [unowned self] in
                self.armObsidianPostAcceptanceSuppressionIfNeeded()
            },
            recordRawAcceptance: { [unowned self] action, acceptedText, acceptanceID, acceptanceProof in
                self.recordRawAcceptance(
                    action: action,
                    acceptedText: acceptedText,
                    acceptanceID: acceptanceID,
                    acceptanceProof: acceptanceProof
                )
            },
            currentAnnoyanceContext: { [weak self] in self?.currentAnnoyanceContext() },
            recordAnnoyanceSignal: { [unowned self] signal, context, suggestionID, reason, metadata in
                self.recordAnnoyanceSignal(
                    signal,
                    context: context,
                    suggestionID: suggestionID,
                    reason: reason,
                    metadata: metadata
                )
            },
            scheduleInsertionVerification: { [unowned self] acceptedText, baseline in
                self.scheduleInsertionVerification(acceptedText: acceptedText, baseline: baseline)
            },
            currentSuggestionLifetimeMetadata: { [unowned self] in self.currentSuggestionLifetimeMetadata() },
            currentPrefixFamilyCooldownInput: { [unowned self] in self.currentPrefixFamilyCooldownInput() },
            recordPrefixFamilyCooldown: { [unowned self] reason, input in
                self.recordPrefixFamilyCooldown(reason, input: input)
            },
            suppressCurrentField: { [unowned self] reason in self.suppressCurrentField(reason: reason) }
        )
    )
    private let focusedFieldIdentityPolicy = FocusedFieldIdentityPolicy()
    private let insertionFailureSuppressionPolicy = InsertionFailureSuppressionPolicy()
    private var suggestionBlockLogGate = SuggestionBlockLogGate()
    private let typingBurstStateHost = TypingBurstStateHost()
    private let suggestionIdleRetryState = SuggestionIdleRetryStateHost()
    private let currentSuggestionState = CurrentSuggestionStateHost()
    private var typeThroughConfidenceCreditedSuggestionIDs: Set<String> = []
    private var preservesResidualSuggestionAfterNextWordAccept = false
    private var obsidianPostAcceptanceSuppression: ObsidianPostAcceptanceSuppression?
    private var recentWordMemory = ScopedRecentWordMemory()
    private var suppressKeyUntil: [AutocompleteKey: Date] = [:]
    private var pendingAcceptedInsertionUndo: AcceptedInsertionUndo?
    private let acceptedInsertionUndoExpirationHost = AcceptedInsertionUndoExpirationHost()
    private let acceptedInsertionUndoRecoveryMode = AcceptedInsertionUndoRecoveryMode.fromEnvironment()
    private var lastSuggestionDecision = "Starting"
    private var lastSyntheticCaretDiagnosticSignature: String?
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

    func prepareForAppLaunch() {
        suggestionPauseStateHost.load()
        loadDisabledApps()
        appPreferencePersistenceHost.load()
        personalizationCoordinator.refreshIndexing(isEnabled: appSettings.personalCaptureEnabled)
        loadProofModeOverrides()
    }

    func recordAppLaunchDiagnostics() {
        DiagnosticsLog.shared.record("launch", metadata: launchDiagnosticsMetadata())
        DiagnosticsLog.shared.record("runtime-bootstrap", metadata: modelRuntimeBundle.diagnosticsMetadata)
    }

    func requestAccessibilityPermissionIfNeededAtLaunch() {
        if startupOnboardingPolicy.shouldRequestAccessibilityPromptOnLaunch(
            isTrusted: accessibilityPermissionHost.isTrusted
        ) {
            accessibilityPermissionHost.requestPermissionIfNeeded()
        }
    }

    func showSettingsIfNeededAtLaunch() {
        if shouldShowSettingsForCurrentReadiness {
            showSettings()
        }
    }

    func stopForAppTermination() {
        DiagnosticsLog.shared.record("terminate")
        cancelPendingSuggestionTask(reason: "terminate")
        suggestionPauseStateHost.stop()
        keyboardEventCaptureHost.cancelIdleStop()
        insertionVerificationHost.cancel()
        acceptedInsertionUndoExpirationHost.cancel()
        modelRuntimeWarmHost.cancel()
        invalidatePendingSuggestionRequest()
        modelRuntime.cancel()
        suggestionPipeline.stopPolling()
        resourceDiagnosticsHost.stop()
        personalizationCoordinator.stop()
        suggestionSummonHotKey.stop()
        manualSuggestionRequestHost.cancelRetry()
        workspaceObserverHost.stop()
        stopKeyboardEventTapNow(reason: "terminate")
        suggestionChromeHost.hideFieldStatusIndicator()
    }







    func handleScreenGeometryChange() {
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

    func handleSuggestionInterruption(_ kind: SuggestionInterruptionKind) {
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

    func handleWorkspaceFocusChange(
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
        let didStart = suggestionSummonHotKey.start()
        DiagnosticsLog.shared.record(
            didStart ? "suggestion-summon-hotkey-started" : "suggestion-summon-hotkey-start-failed",
            metadata: [
                "shortcut": suggestionSummonHotKey.descriptor.diagnosticName,
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

    func rearmFocusedTextAfterRuntimeReady() {
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

    func refreshRuntimeChrome() {
        settingsStateHost.refreshIfShowing(
            settingsWindow: settingsWindow,
            lastSuggestionDecision: lastSuggestionDecision
        )
    }

    private var runtimeReadinessReport: RuntimeReadinessReport {
        runtimeStatusHost.runtimeReadinessReport
    }

    private var modelDirectoryPath: String {
        modelRuntimeBundle.modelDirectoryURL.path
    }

    private var settingsCurrentAppState: SettingsCurrentAppState {
        settingsStateHost.currentAppState
    }

    private var settingsFieldControlState: SettingsFieldControlState {
        settingsStateHost.fieldControlState
    }

    private var settingsPracticeState: SettingsPracticeState {
        settingsStateHost.practiceState
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
        settingsStateHost.privacyState
    }

    private var settingsKeyboardShortcutState: SettingsKeyboardShortcutState {
        settingsStateHost.keyboardShortcutState
    }

    private var settingsSuggestionAggressivenessState: SettingsSuggestionAggressivenessState {
        settingsStateHost.suggestionAggressivenessState
    }

    private var runtimeTargetSummary: String {
        settingsStateHost.runtimeTargetSummary
    }

    private var shouldShowSettingsForCurrentReadiness: Bool {
        startupOnboardingPolicy.shouldShowSettingsOnLaunch(
            isTrusted: accessibilityClient.isTrusted,
            runtimeStage: runtimeReadinessReport.stage,
            appEnablementSetupCompleted: appEnablementSetupCompleted
        )
    }

    var pauseSuggestionsTitle: String {
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

    func effectiveProfile(for app: RunningApplicationInfo) -> CompatibilityProfile? {
        profileStore.profile(for: app.bundleIdentifier)
    }




    func isSuggestionEnabled(
        for app: RunningApplicationInfo,
        profile: CompatibilityProfile
    ) -> Bool {
        guard appProofModeCoordinator.allows(
            appBundleIdentifier: app.bundleIdentifier,
            suggestionBundleIdentifier: profile.bundleIdentifier
        ) else {
            return false
        }

        return ProofModeAppEnablementPolicy(
            disabledBundleIdentifiers: disabledBundleIdentifiers,
            activeProofBundleIdentifiers: activeAppProofBundleIdentifiers
        ).isEnabled(
            appBundleIdentifier: app.bundleIdentifier,
            suggestionBundleIdentifier: profile.bundleIdentifier
        )
    }



    func pollFocusedText(startedAt: UInt64, completesAsync: inout Bool) {
        if case let .blocked(reason) = suggestionSessionBehaviors.control.suggestionAvailability(for: suggestionControlState) {
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
            focusedTextContextDiagnosticsHost.recordMissingContext(
                app: result.app,
                diagnostics: accessibilityClient.focusedTextDiagnostics(
                    for: result.app,
                    allowDescendantTextFallback: profile.allowsDescendantTextFallback
                )
            )
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
            personalCaptureHost.resetSnapshot()
            return
        }

        guard let context = result.context, !context.isSecure else {
            personalCaptureHost.resetSnapshot()
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
            typingBurstStateHost.reset()
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

        let rawActivationDecision = activationPolicy(for: profile).decision(
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            isSecure: context.isSecure,
            selectedTextLength: context.selectedTextLength,
            isFieldSuppressed: suppressedFieldIdentities.contains(fieldIdentity),
            fieldKind: suggestionFieldClassification.kind,
            allowsUnknownFieldKind: profile.allowsUnknownFieldKind,
            allowsTrustedProofSensitiveContent: false
        )
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

        let suggestionAppBundleIdentifier = suggestionBundleIdentifier(for: frontmostApp, profile: profile)
        suggestionTriggerTimingHost.handle(
            input: SuggestionTriggerTimingHostInput(
                context: context,
                profile: profile,
                suggestionAppBundleIdentifier: suggestionAppBundleIdentifier,
                fieldIdentity: fieldIdentity,
                fieldClassification: suggestionFieldClassification,
                renderMode: renderMode,
                requestMode: requestMode,
                previousTextBeforeCursor: lastRequestedTextBeforeCursor,
                idleRetryReason: idleRetryReason,
                typingBurstDecision: typingBurstDecision,
                visiblePageContext: cachedVisiblePageContext(
                    context: context,
                    appBundleIdentifier: frontmostApp.bundleIdentifier
                )
            )
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






    private func effectiveSuggestionFieldClassification(
        app: RunningApplicationInfo,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
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
        app.bundleIdentifier
    }

    private func allowFocusedTextAXRead(for app: RunningApplicationInfo) -> Bool {
        switch focusedTextAXHealthHost.pollDecision(
            for: app.bundleIdentifier,
            now: Date()
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
        let observation = focusedTextAXHealthHost.recordRead(
            bundleIdentifier: result.app.bundleIdentifier,
            queueDelayMilliseconds: result.queueDelayMilliseconds,
            readDurationMilliseconds: result.readDurationMilliseconds,
            hasContext: result.context != nil,
            now: Date()
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
            currentSuggestionHostBundleIdentifier: nil,
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
    func applyFocusedTextPollingThrottleIfNeeded(
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
                currentSuggestionHostBundleIdentifier: nil,
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
                "pauseMilliseconds": String(recommendation.pauseMilliseconds)
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
        PromptEditorFingerprintPolicy.dogfoodBundleIdentifiers.contains(app.bundleIdentifier)
            || app.bundleIdentifier == "md.obsidian"
            || app.bundleIdentifier == "com.google.Chrome"
    }

    private func syntheticTextAreaCaretBundleIdentifier(
        for app: RunningApplicationInfo,
        profile: CompatibilityProfile
    ) -> String {
        app.bundleIdentifier
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
        keyboardEventCaptureHost.startIfPossible(
            isTrustedForAccessibility: accessibilityClient.isTrusted,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion,
            controlState: suggestionControlState,
            snapshot: keyboardEventTapSnapshot()
        )
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



    private func handleAutocompleteKey(
        _ key: AutocompleteKey,
        isAutorepeat: Bool = false,
        didObservePassthroughKeyDown: Bool = false
    ) -> KeyboardEventTapHandlingResult {
        suggestionAcceptanceHost.handleAutocompleteKey(
            key,
            isAutorepeat: isAutorepeat,
            didObservePassthroughKeyDown: didObservePassthroughKeyDown
        )
    }
    private func acceptedTextForCurrentAcceptance(
        _ acceptedText: String,
        action: KeyboardAction
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

        return suggestionSessionBehaviors.acceptanceGuard.decision(
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
        acceptedInsertionUndoExpirationHost.schedule(expiresAt: expiresAt) { [weak self] in
            guard let self,
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

        acceptedInsertionUndoExpirationHost.cancel()
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

    func focusedInsertionVerificationContext(
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


    func startAcceptanceSurvivalTracking(_ tracker: AcceptanceSurvivalTracker) {
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

    func insertionFailureRecoverabilityMetadata(
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
        suggestionSchedulingHost.scheduleSuggestion(
            context: context,
            profile: profile,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentity,
            fieldClassification: fieldClassification,
            renderMode: renderMode,
            delayMilliseconds: delayMilliseconds,
            timingLane: timingLane,
            requestMode: requestMode,
            typingBurstDecision: typingBurstDecision,
            visiblePageContext: visiblePageContext,
            triggerReason: triggerReason
        )
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
        suggestionPresentationOrchestrationHost.presentSuggestion(
            suggestion,
            suggestionID: suggestionID,
            request: request,
            context: context,
            profile: profile,
            fieldIdentity: fieldIdentity,
            renderMode: renderMode,
            latencyMilliseconds: latencyMilliseconds,
            triggerReason: triggerReason,
            requestTicket: requestTicket,
            candidateSelectionMetadata: candidateSelectionMetadata,
            refreshBeforePresenting: refreshBeforePresenting,
            scheduledDelayMilliseconds: scheduledDelayMilliseconds
        )
    }



    private func refreshedPresentationContext(
        for request: CompletionRequest,
        requestContext: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity
    ) -> (context: FocusedTextContext?, reason: String?) {
        suggestionPresentationRefreshHost.refresh(
            for: request,
            requestContext: requestContext,
            profile: profile,
            fieldIdentity: fieldIdentity
        )
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
            allowsFullAcceptNoSubmitProofProfile: false
        )
    }

    private func frontmostAppMatchesSuggestion(
        _ frontmostApp: RunningApplicationInfo,
        expectedBundleIdentifier: String,
        profile: CompatibilityProfile
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
        personalCaptureHost.recordSnapshot(
            context: context,
            app: app,
            fieldIdentity: fieldIdentity,
            fieldClassification: fieldClassification,
            snapshot: snapshot,
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
        personalCaptureHost.recordSuggestionEpisodePresented(
            suggestionID: suggestionID,
            request: request,
            context: context,
            profile: profile,
            fieldIdentity: fieldIdentity,
            fieldClassification: fieldClassification,
            suggestion: suggestion,
            latencyMilliseconds: latencyMilliseconds,
            triggerReason: triggerReason,
            placement: placement,
            panelRect: panelRect,
            screenshotPath: screenshotPath,
            metadata: metadata
        )
    }

    func recordPersonalCaptureSuggestionEpisodeAction(
        suggestionID: String,
        appBundleIdentifier: String,
        outcome: SuggestionEpisodeOutcome,
        reason: String,
        acceptedText: String = "",
        metadata: [String: String] = [:]
    ) {
        personalCaptureHost.recordEpisodeAction(
            suggestionID: suggestionID,
            appBundleIdentifier: appBundleIdentifier,
            outcome: outcome,
            reason: reason,
            acceptedText: acceptedText,
            metadata: metadata
        )
    }

    func recordPersonalCaptureSuggestionEpisodeInsertionFailed(
        baseline: InsertionVerificationBaseline,
        outcome: String,
        reason: String
    ) {
        personalCaptureHost.recordEpisodeInsertionFailed(
            baseline: baseline,
            outcome: outcome,
            reason: reason
        )
    }

    private func recordPersonalCaptureSuggestionEpisodeSurvival(
        _ result: AcceptanceSurvivalCheckResult,
        metadata: [String: String]
    ) {
        personalCaptureHost.recordEpisodeSurvival(result, metadata: metadata)
    }

    private func personalCaptureEpisodeOutcome(
        hiddenOutcome outcome: String,
        reason: String
    ) -> SuggestionEpisodeOutcome {
        personalCaptureHost.episodeOutcome(hiddenOutcome: outcome, reason: reason)
    }

    func recordPersonalCaptureAcceptedSuggestion(
        acceptedText: String,
        baseline: InsertionVerificationBaseline
    ) {
        personalCaptureHost.recordAcceptedSuggestion(
            acceptedText: acceptedText,
            baseline: baseline
        )
    }

    private func recordPersonalCaptureAcceptanceSurvival(_ result: AcceptanceSurvivalCheckResult) {
        personalCaptureHost.recordAcceptanceSurvival(result)
    }

    private func observeTypingBurst(
        previousSnapshot: FocusedTextSnapshot?,
        currentSnapshot: FocusedTextSnapshot
    ) -> TypingBurstDecision {
        guard let previousSnapshot,
              previousSnapshot.fieldIdentity == currentSnapshot.fieldIdentity else {
            typingBurstStateHost.reset()
            return .idle
        }

        return typingBurstStateHost.observe(
            previousTextBeforeCursor: previousSnapshot.textBeforeCursor,
            currentTextBeforeCursor: currentSnapshot.textBeforeCursor,
            nowMilliseconds: Int(Date().timeIntervalSince1970 * 1_000)
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
        let verificationBaseline = insertionVerificationBaselineHost.baseline(
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








    nonisolated private static func appleScriptStringLiteral(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
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
            promptProofModeEnabled: false,
            promptProofBundleIdentifier: "",
            promptProofMarker: ""
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
        let transition = suggestionSession.applyTypeThrough(
            using: typeThroughPrefixStateMachine,
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

    func hideSuggestion(
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

        statusChromeHost.update(
            StatusChromeUpdate(
                statusLine: statusLine,
                statusSignature: statusSignature,
                lastSuggestionDecision: lastSuggestionDecision,
                pauseSuggestionsTitle: pauseSuggestionsTitle,
                silenceFieldTitle: fieldControlState.buttonTitle,
                silenceFieldEnabled: fieldControlState.canSilence,
                silenceFieldToolTip: fieldControlState.detailText,
                toggleAppTitle: appControlState?.menuToggleTitle ?? "Pause Current App",
                toggleAppEnabled: appControlState?.canToggle ?? false,
                toggleAppToolTip: appControlState?.fallbackText ?? "",
                settings: StatusChromeSettingsState(
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
                ),
                diagnosticsMetadata: [
                    "accessibility": permission,
                    "control": control,
                    "app": appName,
                    "profile": profileName,
                    "enabled": enabled,
                    "paused": String(suggestionsPaused),
                    "decision": lastSuggestionDecision
                ]
            )
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

    func suppressField(
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

    func annoyanceContext(
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

    func recordAnnoyanceSignal(
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
        lastFocusedTextChangeAt = nil
        lastRequestedTextBeforeCursor = nil
        typingBurstStateHost.reset()
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
        lastFocusedTextChangeAt = nil
        lastRequestedTextBeforeCursor = nil
        typingBurstStateHost.reset()
        suggestionIdleRetryState.cancel()
        suggestionChromeHost.hideFieldStatusIndicator()
        if resetBlockLogGate {
            suggestionBlockLogGate.reset()
        }
    }

    @discardableResult
    private func invalidatePendingSuggestionRequest() -> Bool {
        suggestionRequestCancellationHost.invalidatePendingRequest()
    }

    @discardableResult
    private func cancelPendingSuggestionTask(reason: String) -> Bool {
        suggestionRequestCancellationHost.cancelPendingRequest(reason: reason)
    }

    @objc
    func requestAccessibilityPermission() {
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

    func requestSuggestionNow(source: String) {
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
    func openAccessibilitySettings() {
        if accessibilityPermissionHost.openAccessibilitySettings() {
            DiagnosticsLog.shared.record("open-accessibility-settings")
        } else {
            DiagnosticsLog.shared.record("open-accessibility-settings-failed")
        }
    }

    func startTextEditPractice() {
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
    func showSettings() {
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
    func openFeedbackForm() {
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
    func revealModelFolder() {
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

    func performRuntimeAction(_ action: RuntimeReadinessAction) {
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
    func showDiagnostics() {
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
                ? personalCaptureHost.currentScorecard()
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

    func toggleTracing() {
        let nextPaused = !RawAutocompleteTraceLog.shared.isPaused
        RawAutocompleteTraceLog.shared.setPaused(nextPaused)
        DiagnosticsLog.shared.record(
            "trace-control",
            metadata: ["paused": String(nextPaused)]
        )
        showDiagnostics()
    }

    func toggleSettingsTracingPaused() {
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

    func toggleRawContentTracing() {
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

    func toggleGlobalScreenshotTracing() {
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

    func toggleVisiblePageContext() {
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

    func togglePersonalCapture() {
        appSettings.togglePersonalCapture()
        if !appSettings.personalCaptureEnabled {
            personalCaptureHost.resetSnapshot()
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
    func revealPersonalCaptureFolder() {
        do {
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: personalCaptureHost.folderPath),
                withIntermediateDirectories: true
            )
            NSWorkspace.shared.activateFileViewerSelecting([
                URL(fileURLWithPath: personalCaptureHost.folderPath)
            ])
        } catch {
            DiagnosticsLog.shared.record(
                "personal-capture-folder-open-failed",
                metadata: ["reason": DiagnosticValueRedactor.stringSummary(length: String(describing: error).count)]
            )
        }
    }

    func deletePersonalCapture() {
        appSettings.personalCaptureEnabled = false
        personalCaptureHost.resetSnapshot()
        personalCaptureHost.deleteAll()
        personalizationCoordinator.deleteAll()
        DiagnosticsLog.shared.record(
            "personal-capture-deleted",
            metadata: ["surface": "settings"]
        )
        refreshRuntimeChrome()
    }

    func deleteLocalPrivacyLogs(refreshSettings: Bool = true) {
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

    func clearLearningData() {
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

    func cycleAcceptAllShortcut() {
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

        return suggestionSessionBehaviors.safetyActivation.adjustedProofDecision(
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

    func setAcceptAllShortcut(_ shortcut: AcceptAllShortcut) {
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

    func setSuggestionAggressivenessLevel(_ level: Int) {
        suggestionTuningHost.setAggressivenessLevel(level)
    }

    func setSuggestionMaxVisibleWords(_ words: Int) {
        suggestionTuningHost.setMaxVisibleWords(words)
    }

    func setSuggestionWordStartCharacters(_ characters: Int) {
        suggestionTuningHost.setWordStartCharacters(characters)
    }

    func setSuggestionPhraseStartWords(_ words: Int) {
        suggestionTuningHost.setPhraseStartWords(words)
    }

    func setSuggestionResponseSpeedLevel(_ level: Int) {
        suggestionTuningHost.setResponseSpeedLevel(level)
    }

    func setSuggestionConfidenceLevel(_ level: Int) {
        suggestionTuningHost.setConfidenceLevel(level)
    }

    func setSuggestionLearningRestraintLevel(_ level: Int) {
        suggestionTuningHost.setLearningRestraintLevel(level)
    }

    func resetSuggestionTuning() {
        suggestionTuningHost.reset()
    }

    func toggleScreenshotTracing(for bundleIdentifier: String) {
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
    func nudgeCurrentAppSuggestionUp() {
        nudgeCurrentAppSuggestion(dx: 0, dy: -2)
    }

    @objc
    func nudgeCurrentAppSuggestionDown() {
        nudgeCurrentAppSuggestion(dx: 0, dy: 2)
    }

    @objc
    func nudgeCurrentAppSuggestionLeft() {
        nudgeCurrentAppSuggestion(dx: -2, dy: 0)
    }

    @objc
    func nudgeCurrentAppSuggestionRight() {
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
    func resetCurrentAppLearning() {
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

    func openTraceFolder() {
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

    func exportTraceReport() {
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
    func toggleCurrentApp() {
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
    func toggleCurrentAppMirrorMode() {
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

    @objc
    func startCurrentAppProof() {
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

    func enableAllDisabledApps() {
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
    func silenceCurrentField() {
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
    func togglePauseSuggestions() {
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
    func pauseSuggestionsFor15Minutes() {
        pauseSuggestions(for: 15 * 60, label: "15 minutes")
    }

    @objc
    func pauseSuggestionsFor1Hour() {
        pauseSuggestions(for: 60 * 60, label: "1 hour")
    }

    @objc
    func pauseSuggestionsUntilTomorrowFromControl() {
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
    func quit() {
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
