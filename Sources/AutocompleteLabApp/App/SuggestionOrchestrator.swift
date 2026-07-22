import Foundation
import AutocompleteLabCore

struct FastPhraseFallbackLearningDecision: Equatable, Sendable {
    let shouldSuppress: Bool
    let reason: String?
    let metadata: [String: String]
}

@MainActor
final class SuggestionOrchestrator {
    private static let maximumFinalModelDisplayLatencyMilliseconds = 2_000
    /// Ceiling applied when a model result would be the *first* thing the user sees
    /// (no instant local phrase or streamed partial already on screen). Staleness is
    /// separately guarded by presentationSuppressionReason (any typing after the
    /// request cancels the paint), so this only needs to drop pathologically late
    /// results — a local model regularly needs more than a second for its first
    /// good completion, and dropping those made the app feel dead.
    private static let maximumFirstVisibleModelDisplayLatencyMilliseconds = 1_200
    private static let maximumDocLocalFields = 24
    private static let maximumDocLocalSnapshotsPerField = 4
    private static let maximumDocLocalSnapshotCharacters = 12_000

    private let engineBox: CompletionEngineBox
    private let wordCompletionRanker: WordCompletionCandidateRanker
    private let docLocalPhrasePredictor: DocLocalNGramPhrasePredictor
    private let commonPhrasePredictor: CommonPhraseContinuationPredictor
    private let failureVisibilityPolicy = CompletionFailureVisibilityPolicy()
    private let goodAndFastEnoughPolicy: GoodAndFastEnoughPolicy
    private let suggestionPresentationGate: SuggestionPresentationGate
    private let suggestionReplacementPolicy: SuggestionReplacementPolicy
    private var requestGate = SuggestionRequestGate()
    private var currentRequestStorage: CompletionRequest?
    private var suggestionAnnoyanceBackoffPolicy: SuggestionAnnoyanceBackoffPolicy
    private var streamingPresentationStates: [String: StreamingPresentationState] = [:]
    private var docLocalCorpusByField: [FocusedFieldIdentity: DocLocalNGramFieldCorpus] = [:]

    init(
        engine: any CompletionEngine,
        wordCompletionRanker: WordCompletionCandidateRanker = WordCompletionCandidateRanker(),
        docLocalPhrasePredictor: DocLocalNGramPhrasePredictor = DocLocalNGramPhrasePredictor(),
        commonPhrasePredictor: CommonPhraseContinuationPredictor = CommonPhraseContinuationPredictor(),
        goodAndFastEnoughPolicy: GoodAndFastEnoughPolicy = GoodAndFastEnoughPolicy(),
        suggestionPresentationGate: SuggestionPresentationGate = SuggestionPresentationGate(),
        suggestionReplacementPolicy: SuggestionReplacementPolicy = SuggestionReplacementPolicy(),
        suggestionAnnoyanceBackoffPolicy: SuggestionAnnoyanceBackoffPolicy = SuggestionAnnoyanceBackoffPolicy()
    ) {
        self.engineBox = CompletionEngineBox(engine: engine)
        self.wordCompletionRanker = wordCompletionRanker
        self.docLocalPhrasePredictor = docLocalPhrasePredictor
        self.commonPhrasePredictor = commonPhrasePredictor
        self.goodAndFastEnoughPolicy = goodAndFastEnoughPolicy
        self.suggestionPresentationGate = suggestionPresentationGate
        self.suggestionReplacementPolicy = suggestionReplacementPolicy
        self.suggestionAnnoyanceBackoffPolicy = suggestionAnnoyanceBackoffPolicy
    }

    var currentRequest: CompletionRequest? {
        currentRequestStorage
    }

    func beginRequest(
        textBeforeCursor: String,
        textAfterCursor: String,
        appBundleIdentifier: String,
        maxVisibleWords: Int,
        requestMode: CompletionRequestMode
    ) -> SuggestionOrchestration {
        let suggestionID = UUID().uuidString
        let request = CompletionRequest(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor,
            appBundleIdentifier: appBundleIdentifier,
            maxVisibleWords: maxVisibleWords,
            mode: requestMode,
            suggestionID: suggestionID
        )
        return beginRequest(request)
    }

    func acceptedTextStyleKey(
        appBundleIdentifier: String,
        fieldKind: AXFieldKind,
        textBeforeCursor: String
    ) -> AcceptedTextStyleMemoryKey {
        AcceptedTextStyleMemoryKey(
            appBundleIdentifier: appBundleIdentifier,
            fieldKind: fieldKind,
            behaviorProfileID: behaviorProfileID(
                appBundleIdentifier: appBundleIdentifier,
                fieldKind: fieldKind,
                textBeforeCursor: textBeforeCursor
            )
        )
    }

    func beginRequest(_ input: SuggestionRequestInput) -> SuggestionOrchestration {
        let suggestionID = UUID().uuidString
        let behaviorProfileID = behaviorProfileID(
            appBundleIdentifier: input.appBundleIdentifier,
            fieldKind: input.fieldClassification.kind,
            textBeforeCursor: input.context.textBeforeCursor
        )
        let docLocalContextTexts = docLocalContextTexts(
            for: input.fieldIdentity,
            context: input.context,
            fieldClassification: input.fieldClassification,
            behaviorProfileID: behaviorProfileID
        )
        let fieldIdentityDescription = input.fieldIdentity.traceDescription
        let request = CompletionRequest(
            textBeforeCursor: input.context.textBeforeCursor,
            textAfterCursor: input.context.textAfterCursor,
            appBundleIdentifier: input.appBundleIdentifier,
            fieldIdentityDescription: fieldIdentityDescription,
            fieldKind: input.fieldClassification.kind,
            behaviorProfileID: behaviorProfileID,
            acceptedTextStyleSketch: input.acceptedTextStyleSketch,
            documentTitleShape: DocumentTitleShape.from(windowTitle: input.context.fingerprint.windowTitle),
            visiblePageContext: input.visiblePageContext,
            maxVisibleWords: input.maxVisibleWords,
            mode: input.requestMode,
            suggestionID: suggestionID
        )
        return beginRequest(
            request,
            fieldClassification: input.fieldClassification,
            suggestionTuning: input.suggestionTuning,
            docLocalContextTexts: docLocalContextTexts
        )
    }

    func beginRequest(_ request: CompletionRequest) -> SuggestionOrchestration {
        beginRequest(
            request,
            fieldClassification: nil,
            suggestionTuning: nil
        )
    }

    private func beginRequest(
        _ request: CompletionRequest,
        fieldClassification: AXFieldClassification?,
        suggestionTuning: SuggestionTuning?,
        docLocalContextTexts: [String] = []
    ) -> SuggestionOrchestration {
        clearStreamingPresentations()
        let runtimeSessionCacheDecision = RuntimeSessionCachePolicy().decision(
            previous: currentRequestStorage,
            current: request
        )
        var requestMetadata = request.behaviorProfileTraceMetadata
            .merging(runtimeSessionCacheDecision.traceMetadata) { current, _ in current }
        if let fieldClassification {
            requestMetadata.merge(fieldClassification.traceMetadata) { current, _ in current }
        }
        if let suggestionTuning {
            requestMetadata.merge(suggestionTuning.traceMetadata) { current, _ in current }
        }

        currentRequestStorage = request
        return SuggestionOrchestration(
            suggestionID: request.suggestionID,
            request: request,
            ticket: requestGate.issue(request: request),
            startedAt: Date(),
            fieldIdentityDescription: request.fieldIdentityDescription ?? "",
            requestMetadata: requestMetadata,
            runtimeSessionCacheDecision: runtimeSessionCacheDecision,
            docLocalContextTexts: docLocalContextTexts
        )
    }

    private func docLocalContextTexts(
        for fieldIdentity: FocusedFieldIdentity,
        context: FocusedTextContext,
        fieldClassification: AXFieldClassification,
        behaviorProfileID: AutocompleteBehaviorProfileID
    ) -> [String] {
        guard !context.isSecure,
              !fieldClassification.suppressesSuggestionsByDefault,
              Self.allowsDocLocalCorpus(for: behaviorProfileID) else {
            docLocalCorpusByField[fieldIdentity] = nil
            return []
        }

        let existingTexts = docLocalCorpusByField[fieldIdentity]?.texts ?? []
        rememberDocLocalContext(
            context.textBeforeCursor + context.textAfterCursor,
            for: fieldIdentity
        )
        return existingTexts
    }

    private func rememberDocLocalContext(
        _ rawText: String,
        for fieldIdentity: FocusedFieldIdentity
    ) {
        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        var corpus = docLocalCorpusByField[fieldIdentity] ?? DocLocalNGramFieldCorpus()
        corpus.append(
            rawText,
            maxSnapshots: Self.maximumDocLocalSnapshotsPerField,
            maxCharactersPerSnapshot: Self.maximumDocLocalSnapshotCharacters
        )
        docLocalCorpusByField[fieldIdentity] = corpus

        if docLocalCorpusByField.count > Self.maximumDocLocalFields,
           let firstKey = docLocalCorpusByField.keys.first {
            docLocalCorpusByField[firstKey] = nil
        }
    }

    nonisolated static func allowsDocLocalCorpus(
        for behaviorProfileID: AutocompleteBehaviorProfileID
    ) -> Bool {
        switch behaviorProfileID {
        // aiChat is included so the prompt-app prediction path actually has a corpus to read.
        // `DocLocalNGramPhrasePredictor.allowsPrediction` is willing to predict for aiChat (gated
        // behind `allowsPromptAppPrediction`), but the corpus was never remembered here — so that
        // path could never fire. Remembering the corpus does not surface any new suggestion unless
        // prompt-app prediction is active; it only stops the two gates from silently disagreeing.
        case .docsProse, .notes, .bullets, .aiChat:
            return true
        case .casualChat, .email, .coding, .forms, .search:
            return false
        }
    }

    private func behaviorProfileID(
        appBundleIdentifier: String,
        fieldKind: AXFieldKind,
        textBeforeCursor: String
    ) -> AutocompleteBehaviorProfileID {
        AutocompleteBehaviorProfileResolver().profile(for: AutocompleteBehaviorProfileInput(
            appBundleIdentifier: appBundleIdentifier,
            fieldKind: fieldKind,
            currentLineStructure: CurrentLineStructure.from(textBeforeCursor: textBeforeCursor)
        )).id
    }

    func allows(_ ticket: SuggestionRequestTicket) -> Bool {
        requestGate.allows(ticket, currentRequest: currentRequestStorage)
    }

    func allows(
        _ ticket: SuggestionRequestTicket,
        fieldIdentity: FocusedFieldIdentity,
        currentFieldIdentity: FocusedFieldIdentity?
    ) -> Bool {
        allows(ticket) && currentFieldIdentity == fieldIdentity
    }

    func shouldHideVisibleSuggestionAfterFailure(
        ticket: SuggestionRequestTicket,
        failedRequestFieldIdentity: FocusedFieldIdentity,
        currentFieldIdentity: FocusedFieldIdentity?
    ) -> Bool {
        failureVisibilityPolicy.shouldHideVisibleSuggestion(
            requestGate: requestGate,
            ticket: ticket,
            currentRequest: currentRequestStorage,
            failedRequestFieldIdentity: failedRequestFieldIdentity,
            currentFieldIdentity: currentFieldIdentity
        )
    }

    func shouldKeepVisibleStreamingSuggestionAfterEmptyFinal(
        suggestionID: String,
        currentSuggestionID: String?,
        ticket: SuggestionRequestTicket,
        fieldIdentity: FocusedFieldIdentity,
        currentFieldIdentity: FocusedFieldIdentity?,
        hasVisibleSuggestion: Bool
    ) -> Bool {
        shouldKeepVisibleSuggestionForSameLiveRequest(
            suggestionID: suggestionID,
            currentSuggestionID: currentSuggestionID,
            ticket: ticket,
            fieldIdentity: fieldIdentity,
            currentFieldIdentity: currentFieldIdentity,
            hasVisibleSuggestion: hasVisibleSuggestion
        )
    }

    func shouldKeepVisibleSuggestionAfterModelContinuationFailure(
        suggestionID: String,
        currentSuggestionID: String?,
        ticket: SuggestionRequestTicket,
        fieldIdentity: FocusedFieldIdentity,
        currentFieldIdentity: FocusedFieldIdentity?,
        hasVisibleSuggestion: Bool
    ) -> Bool {
        shouldKeepVisibleSuggestionForSameLiveRequest(
            suggestionID: suggestionID,
            currentSuggestionID: currentSuggestionID,
            ticket: ticket,
            fieldIdentity: fieldIdentity,
            currentFieldIdentity: currentFieldIdentity,
            hasVisibleSuggestion: hasVisibleSuggestion
        )
    }

    private func shouldKeepVisibleSuggestionForSameLiveRequest(
        suggestionID: String,
        currentSuggestionID: String?,
        ticket: SuggestionRequestTicket,
        fieldIdentity: FocusedFieldIdentity,
        currentFieldIdentity: FocusedFieldIdentity?,
        hasVisibleSuggestion: Bool
    ) -> Bool {
        hasVisibleSuggestion
            && currentSuggestionID == suggestionID
            && allows(ticket, fieldIdentity: fieldIdentity, currentFieldIdentity: currentFieldIdentity)
    }

    func presentationSuppressionReason(
        requestTicket: SuggestionRequestTicket?,
        request: CompletionRequest,
        fieldIdentity: FocusedFieldIdentity,
        currentFieldIdentity: FocusedFieldIdentity?,
        currentSnapshot: FocusedTextSnapshot?,
        invalidatedByUserTyping: Bool
    ) -> SuggestionPresentationSuppressionReason? {
        if let requestTicket,
           !allows(requestTicket) {
            return .staleRequest
        }

        guard currentFieldIdentity == fieldIdentity else {
            return .staleField
        }

        guard let currentSnapshot else {
            return invalidatedByUserTyping ? .staleAfterKeydown : nil
        }

        guard currentSnapshot.fieldIdentity == fieldIdentity else {
            return .staleField
        }

        guard currentSnapshot.textBeforeCursor.hasPrefix(request.textBeforeCursor),
              currentSnapshot.textAfterCursor == request.textAfterCursor else {
            return .staleText
        }

        return nil
    }

    func invalidate() {
        currentRequestStorage = nil
        requestGate.invalidate()
    }

    func updateEngine(_ engine: any CompletionEngine) {
        engineBox.update(engine)
    }

    func prefixCooldownDecision(
        for input: PrefixFamilyCooldownInput,
        now: Date = Date()
    ) -> PrefixFamilyCooldownDecision {
        suggestionAnnoyanceBackoffPolicy.prefixCooldownDecision(for: input, now: now)
    }

    func recordPrefixFamilyCooldown(
        _ reason: PrefixFamilyCooldownReason,
        input: PrefixFamilyCooldownInput,
        now: Date = Date()
    ) -> PrefixFamilyCooldown? {
        suggestionAnnoyanceBackoffPolicy.recordPrefixCooldown(reason, input: input, now: now)
    }

    func shouldSuppressRepetition(
        _ text: String,
        mode: CompletionRequestMode,
        scope: String = "",
        now: Date = Date()
    ) -> Bool {
        suggestionAnnoyanceBackoffPolicy.shouldSuppressRepetition(
            text,
            mode: mode,
            scope: scope,
            now: now
        )
    }

    @discardableResult
    func recordRepetitionMiss(
        _ text: String,
        mode: CompletionRequestMode?,
        scope: String = "",
        now: Date = Date()
    ) -> SuggestionRepetitionMissRecord? {
        suggestionAnnoyanceBackoffPolicy.recordRepetitionMiss(
            text,
            mode: mode,
            scope: scope,
            now: now
        )
    }

    @discardableResult
    func recordIgnoredRepetition(
        _ text: String,
        mode: CompletionRequestMode?,
        scope: String = "",
        lifetimeMilliseconds: Int? = nil,
        now: Date = Date()
    ) -> SuggestionRepetitionMissRecord? {
        suggestionAnnoyanceBackoffPolicy.recordIgnoredRepetition(
            text,
            mode: mode,
            scope: scope,
            lifetimeMilliseconds: lifetimeMilliseconds,
            now: now
        )
    }

    func recordRepetitionAcceptance(
        _ text: String,
        mode: CompletionRequestMode?,
        scope: String = ""
    ) {
        suggestionAnnoyanceBackoffPolicy.recordRepetitionAcceptance(
            text,
            mode: mode,
            scope: scope
        )
    }

    func resetSuggestionAnnoyanceBackoffPolicy(_ policy: SuggestionAnnoyanceBackoffPolicy) {
        suggestionAnnoyanceBackoffPolicy = policy
    }

    func startStreamingPresentation(suggestionID: String) {
        streamingPresentationStates[suggestionID] = StreamingPresentationState()
    }

    func shouldPresentStreamingPartial(
        _ suggestion: CompletionSuggestion,
        suggestionID: String,
        mode: CompletionRequestMode,
        nowMilliseconds: Int,
        latencyMilliseconds: Int = 0
    ) -> Bool {
        guard var state = streamingPresentationStates[suggestionID] else {
            return false
        }
        guard suggestionPresentationGate.shouldPresentStreamingPartial(
            suggestion,
            mode: mode,
            state: &state,
            nowMilliseconds: nowMilliseconds,
            latencyMilliseconds: latencyMilliseconds
        ) else {
            return false
        }

        streamingPresentationStates[suggestionID] = state
        return true
    }

    func streamingPresentationMetadata(suggestionID: String) -> [String: String] {
        guard let state = streamingPresentationStates[suggestionID],
              state.presentedCount > 0 else {
            return [:]
        }

        var metadata = [
            "streamingPartialIndex": String(state.presentedCount),
            "streamingPartialVisibleCharacters": String(state.lastVisibleText.count)
        ]
        if let firstPartialLatencyMilliseconds = state.firstPartialLatencyMilliseconds {
            metadata["streamingFirstPartialLatencyMilliseconds"] = String(firstPartialLatencyMilliseconds)
        }
        if let lastPartialLatencyMilliseconds = state.lastPartialLatencyMilliseconds {
            metadata["streamingLastPartialLatencyMilliseconds"] = String(lastPartialLatencyMilliseconds)
        }
        return metadata
    }

    func finishStreamingPresentation(suggestionID: String) {
        streamingPresentationStates[suggestionID] = nil
    }

    func clearStreamingPresentations() {
        streamingPresentationStates.removeAll(keepingCapacity: true)
    }

    nonisolated func placementHealthPlan(
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        learningAdjustment: CompatibilityLearningAdjustment,
        screenshotTracingEnabled: Bool
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
            trustPolicy: placementTrustPolicy(
                profile: profile,
                context: context,
                learningAdjustment: learningAdjustment,
                screenshotTracingEnabled: screenshotTracingEnabled
            )
        )
    }

    nonisolated func placementSuppressionResolution(
        for placementPlan: PlacementHealthPlan,
        requestedRenderMode: SuggestionRenderMode,
        profile: CompatibilityProfile,
        fieldKind: AXFieldKind
    ) -> PlacementSuppressionResolution {
        let suppression: PlacementHealthSuppression
        if case let .suppress(value) = placementPlan {
            suppression = value
        } else {
            suppression = PlacementHealthSuppression(
                requestedRenderMode: requestedRenderMode,
                reason: .missingAnchor
            )
        }
        let commandFallbackDecision = goodAndFastEnoughPolicy.fallbackDecision(
            supportStatus: .supported(profile),
            isEnabled: true,
            fieldKind: fieldKind,
            allowsLowConfidencePlacement: suppression.reason == .lowConfidencePlacement ? false : nil
        )
        let commandFallbackMetadata = [
            "commandFallback": commandFallbackDecision.availability.rawValue,
            "commandFallbackReason": commandFallbackDecision.reason.rawValue
        ]

        return PlacementSuppressionResolution(
            suppression: suppression,
            commandFallbackDecision: commandFallbackDecision,
            metadata: commandFallbackMetadata,
            fallbackSuffix: commandFallbackDecision.canCopyOnly ? "; copy-only fallback available" : ""
        )
    }

    nonisolated private func placementTrustPolicy(
        profile: CompatibilityProfile,
        context: FocusedTextContext,
        learningAdjustment: CompatibilityLearningAdjustment,
        screenshotTracingEnabled: Bool
    ) -> PlacementTrustPolicy {
        let shouldCaptureScreenshot = learningAdjustment.shouldCaptureScreenshot
        return profile.placementTrustPolicy(
            input: CompatibilityPlacementTrustInput(
                hasTrustedVisualAdjustment: learningAdjustment.profile?.hasTrustedVisualAdjustment == true,
                hasProofedSyntheticCaret: hasProofedSyntheticCaretPlacement(
                    profile: profile,
                    context: context,
                    screenshotTracingEnabled: screenshotTracingEnabled,
                    shouldCaptureScreenshot: shouldCaptureScreenshot
                ),
                screenshotTracingEnabled: screenshotTracingEnabled,
                shouldCaptureScreenshot: shouldCaptureScreenshot
            )
        )
    }

    nonisolated private func hasProofedSyntheticCaretPlacement(
        profile: CompatibilityProfile,
        context: FocusedTextContext,
        screenshotTracingEnabled: Bool,
        shouldCaptureScreenshot: Bool
    ) -> Bool {
        guard profile.bundleIdentifier == "com.google.Chrome",
              context.role == "AXTextArea",
              context.caretIsSynthetic,
              context.capabilities.canReadValue,
              context.capabilities.canReadSelectedTextRange,
              screenshotTracingEnabled || shouldCaptureScreenshot else {
            return false
        }

        let searchable = context.fingerprint.searchableText
        return searchable.contains("monaco") || searchable.contains("prosemirror")
    }

    func replacementDecision(
        currentVisibleText: String?,
        proposedVisibleText: String,
        currentSuggestionID: String?,
        proposedSuggestionID: String,
        currentPresentedAt: Date?,
        currentScore: Double?,
        proposedScore: Double,
        currentSuggestionInvalidatedByUserTyping: Bool = false,
        now: Date = Date()
    ) -> SuggestionReplacementDecision {
        let currentAgeMilliseconds = currentPresentedAt.map {
            max(0, Int(now.timeIntervalSince($0) * 1_000))
        }
        return suggestionReplacementPolicy.decision(
            currentVisibleText: currentVisibleText,
            proposedVisibleText: proposedVisibleText,
            currentSuggestionID: currentSuggestionID,
            proposedSuggestionID: proposedSuggestionID,
            currentAgeMilliseconds: currentAgeMilliseconds,
            currentScore: currentScore,
            proposedScore: proposedScore,
            currentSuggestionInvalidatedByUserTyping: currentSuggestionInvalidatedByUserTyping
        )
    }

    nonisolated func fastWordSuggestion(
        for textBeforeCursor: String,
        recentWords: [String],
        allowPredictiveFallback: Bool = false
    ) -> CompletionSuggestion? {
        fastWordSelection(
            for: textBeforeCursor,
            recentWords: recentWords,
            allowPredictiveFallback: allowPredictiveFallback
        ).suggestion
    }

    nonisolated func fastWordSelection(
        for textBeforeCursor: String,
        recentWords: [String],
        allowPredictiveFallback: Bool = false
    ) -> WordCompletionCandidateSelection {
        wordCompletionRanker.selection(
            for: textBeforeCursor,
            recentWords: recentWords,
            allowPredictiveFallback: allowPredictiveFallback
        )
    }

    nonisolated func fastPhraseSelection(
        for textBeforeCursor: String,
        docLocalContextTexts: [String] = [],
        behaviorProfileID: AutocompleteBehaviorProfileID?,
        maxVisibleWords: Int,
        allowPredictiveFallback: Bool = false,
        allowPromptAppPrediction: Bool = false
    ) -> CommonPhraseContinuationSelection {
        guard allowPredictiveFallback else {
            return CommonPhraseContinuationSelection(
                suggestion: nil,
                matchedContextSuffix: nil,
                score: nil,
                suppressionReason: "disabled"
            )
        }

        let docLocalSelection = docLocalPhrasePredictor.selection(
            for: textBeforeCursor,
            localContextTexts: docLocalContextTexts,
            behaviorProfileID: behaviorProfileID,
            maxVisibleWords: maxVisibleWords,
            allowsPromptAppPrediction: allowPromptAppPrediction
        )
        if docLocalSelection.suggestion != nil {
            return docLocalSelection
        }

        return commonPhrasePredictor.selection(
            for: textBeforeCursor,
            behaviorProfileID: behaviorProfileID,
            maxVisibleWords: maxVisibleWords,
            allowsPromptAppPrediction: allowPromptAppPrediction
        )
    }

    nonisolated func fastPhraseFallbackLearningDecision(
        acceptedAndKeptSignal: AcceptedAndKeptLearningSignal,
        probabilityThreshold: Double,
        minimumSamples: Int = 6,
        minimumLearningRestraint: Double = 0.35
    ) -> FastPhraseFallbackLearningDecision {
        let boundedMinimumSamples = max(0, minimumSamples)
        let boundedMinimumLearningRestraint = max(0, minimumLearningRestraint)
        let shouldSuppress = acceptedAndKeptSignal.sampleCount >= boundedMinimumSamples
            && acceptedAndKeptSignal.probability < probabilityThreshold
            && acceptedAndKeptSignal.learningRestraint >= boundedMinimumLearningRestraint
        let reason = shouldSuppress ? "fast-phrase-learning-restraint" : nil
        var metadata = acceptedAndKeptSignal.traceMetadata
        metadata["fastPhraseFallbackLearningThreshold"] = Self.traceDecimal(probabilityThreshold)
        metadata["fastPhraseFallbackLearningMinimumSamples"] = String(boundedMinimumSamples)
        metadata["fastPhraseFallbackLearningMinimumRestraint"] = Self.traceDecimal(boundedMinimumLearningRestraint)
        metadata["fastPhraseFallbackLearningSuppressed"] = String(shouldSuppress)
        if let reason {
            metadata["fastPhraseFallbackLearningReason"] = reason
        }
        return FastPhraseFallbackLearningDecision(
            shouldSuppress: shouldSuppress,
            reason: reason,
            metadata: metadata
        )
    }

    nonisolated func appModelResultCandidateSelectionMetadata(
        for suggestion: CompletionSuggestion
    ) -> [String: String] {
        [
            "candidateSelectionSource": "app-model-result",
            "cleanedCandidateCount": "1",
            "candidateTopScore": "1.000",
            "candidateScoreMargin": "none",
            "candidateSuppressionReason": "none",
            "cleanedWordCount": String(suggestion.visibleWordCount)
        ]
    }

    nonisolated func displayScore(
        suggestion: CompletionSuggestion,
        request: CompletionRequest,
        context: FocusedTextContext,
        fieldClassification: AXFieldClassification,
        profile: CompatibilityProfile,
        triggerReason: String,
        latencyMilliseconds: Int,
        acceptedAndKeptSignal: AcceptedAndKeptLearningSignal,
        isRepeatedMiss: Bool
    ) -> DisplayScore {
        let requestFieldKind = request.fieldKind == .unknown ? fieldClassification.kind : request.fieldKind
        let behaviorProfile = request.behaviorProfile
        return DisplayScore(
            utility: Self.displayUtility(
                mode: request.mode,
                visibleWordCount: suggestion.visibleWordCount,
                visibleCharacterCount: suggestion.visibleText.count,
                acceptedAndKeptSignal: acceptedAndKeptSignal
            ),
            styleFit: Self.displayStyleFit(
                fieldKind: requestFieldKind,
                profile: profile,
                behaviorProfile: behaviorProfile
            ),
            contextFit: Self.displayContextFit(request: request, context: context),
            userAffinity: Self.displayUserAffinity(
                mode: request.mode,
                triggerReason: triggerReason,
                acceptedAndKeptSignal: acceptedAndKeptSignal
            ),
            risk: Self.displayRisk(
                fieldKind: requestFieldKind,
                profile: profile,
                behaviorProfile: behaviorProfile,
                context: context
            ),
            repetition: isRepeatedMiss ? 0.90 : 0.05,
            instability: Self.displayInstability(
                context: context,
                triggerReason: triggerReason,
                latencyMilliseconds: latencyMilliseconds
            ),
            learningRestraint: acceptedAndKeptSignal.learningRestraint,
            acceptedAndKeptProbability: acceptedAndKeptSignal.probability,
            acceptedAndKeptSampleCount: acceptedAndKeptSignal.sampleCount,
            acceptedAndKeptUtilityAdjustment: acceptedAndKeptSignal.utilityAdjustment,
            typeThroughSurvivalCount: acceptedAndKeptSignal.typeThroughSurvivalCount,
            typeThroughConfidenceCredit: acceptedAndKeptSignal.typeThroughConfidenceCredit
        )
    }

    func displayScoreDecision(
        suggestion: CompletionSuggestion,
        request: CompletionRequest,
        context: FocusedTextContext,
        fieldClassification: AXFieldClassification,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        triggerReason: String,
        latencyMilliseconds: Int,
        acceptedAndKeptSignal: AcceptedAndKeptLearningSignal,
        isRepeatedMiss: Bool,
        displayScorePolicy: DisplayScorePolicy,
        suggestionTuning: SuggestionTuning? = nil,
        modelIsFirstVisibleSuggestion: Bool = false,
        scheduledDelayMilliseconds: Int = 0,
        now: Date = Date()
    ) -> SuggestionDisplayScoreDecision {
        _ = suggestionTuning
        let prefixEagernessAdjustment = suggestionAnnoyanceBackoffPolicy.prefixEagernessAdjustment(
            for: PrefixFamilyCooldownInput(
                appBundleIdentifier: request.appBundleIdentifier ?? profile.bundleIdentifier,
                fieldIdentifier: fieldIdentity.traceDescription,
                requestMode: request.mode,
                textBeforeCursor: request.textBeforeCursor
            ),
            now: now
        )
        let score = displayScore(
            suggestion: suggestion,
            request: request,
            context: context,
            fieldClassification: fieldClassification,
            profile: profile,
            triggerReason: triggerReason,
            latencyMilliseconds: latencyMilliseconds,
            acceptedAndKeptSignal: acceptedAndKeptSignal,
            isRepeatedMiss: isRepeatedMiss
        )
        let adjustedPolicy = displayScorePolicy
            .adjustingThresholds(by: prefixEagernessAdjustment.thresholdAdjustment)
        let modelDisplayLatencyBudgetMilliseconds = Self.maximumFinalModelDisplayLatencyMilliseconds(
            for: request,
            suggestion: suggestion,
            firstVisible: modelIsFirstVisibleSuggestion
        )
        // The first-visible ceiling bounds the model's contribution to first paint, so remove
        // the deliberate pre-model scheduling pause before comparing it. Refinement keeps its
        // existing delay-inclusive basis.
        let modelLatencyForBudget = modelIsFirstVisibleSuggestion
            ? max(0, latencyMilliseconds - max(0, scheduledDelayMilliseconds))
            : latencyMilliseconds
        let unifiedDecision = goodAndFastEnoughPolicy.decision(
            suggestion: suggestion,
            mode: request.mode,
            textBeforeCursor: request.textBeforeCursor,
            supportLevel: profile.supportLevel,
            score: score,
            displayScorePolicy: adjustedPolicy,
            latencyMilliseconds: latencyMilliseconds,
            latencyBudgetMilliseconds: modelDisplayLatencyBudgetMilliseconds,
            latencyForBudgetMilliseconds: modelLatencyForBudget,
            enforceLatencyCeiling: triggerReason != "model-stream",
            allowLatencyBypass: false,
            behaviorProfileID: request.behaviorProfile.id
        )
        var confidenceMetadata = unifiedDecision.metadata
        confidenceMetadata["modelIsFirstVisibleSuggestion"] = String(modelIsFirstVisibleSuggestion)

        return SuggestionDisplayScoreDecision(
            decision: unifiedDecision.decision,
            metadata: unifiedDecision.metadata
                .merging(prefixEagernessAdjustment.metadata) { current, _ in current }
                .merging(confidenceMetadata) { current, _ in current }
        )
    }

    nonisolated private static func displayUtility(
        mode: CompletionRequestMode,
        visibleWordCount: Int,
        visibleCharacterCount: Int,
        acceptedAndKeptSignal: AcceptedAndKeptLearningSignal
    ) -> Double {
        let base: Double
        switch mode {
        case .wordCompletion:
            if visibleCharacterCount <= 12 {
                base = 0.85
            } else {
                base = 0.65
            }
        case .sentenceContinuation:
            switch visibleWordCount {
            case 3...8:
                base = 0.64
            case 2:
                base = 0.52
            default:
                base = 0.38
            }
        case .phraseContinuation:
            switch visibleWordCount {
            case 3...8:
                base = 0.74
            case 2:
                base = 0.58
            case 1:
                base = 0.40
            default:
                base = 0.34
            }
        }

        return displayComponent(base + acceptedAndKeptSignal.utilityAdjustment)
    }

    nonisolated private static func traceDecimal(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    nonisolated private static func displayStyleFit(
        fieldKind: AXFieldKind,
        profile: CompatibilityProfile,
        behaviorProfile: AutocompleteBehaviorProfile
    ) -> Double {
        if fieldKind.suppressesSuggestionsByDefault
            || profile.isSensitive
            || behaviorProfile.suppressionDefaults.suppressesSuggestionsByDefault {
            return 0.05
        }

        switch fieldKind {
        case .multilineCompose:
            return 0.48
        case .singlelineCompose:
            return 0.40
        case .unknown:
            return 0.32
        case .search, .form, .secure, .url, .unprovenSurface:
            return 0.05
        }
    }

    nonisolated private static func displayContextFit(
        request: CompletionRequest,
        context: FocusedTextContext
    ) -> Double {
        var score = request.textBeforeCursor == context.textBeforeCursor ? 0.50 : 0.30
        if !context.textAfterCursor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            score -= 0.15
        }
        if context.selectedTextLength > 0 {
            score -= 0.35
        }
        return displayComponent(score)
    }

    nonisolated private static func displayUserAffinity(
        mode: CompletionRequestMode,
        triggerReason: String,
        acceptedAndKeptSignal: AcceptedAndKeptLearningSignal
    ) -> Double {
        let base: Double
        if triggerReason == "fast-word-completion" {
            base = 0.25
        } else {
            switch mode {
            case .wordCompletion:
                base = 0.20
            case .sentenceContinuation:
                base = 0.10
            case .phraseContinuation:
                base = 0.15
            }
        }

        return displayComponent(base + acceptedAndKeptSignal.userAffinityAdjustment)
    }

    nonisolated private static func displayRisk(
        fieldKind: AXFieldKind,
        profile: CompatibilityProfile,
        behaviorProfile: AutocompleteBehaviorProfile,
        context: FocusedTextContext
    ) -> Double {
        if context.isSecure
            || profile.isSensitive
            || fieldKind.suppressesSuggestionsByDefault
            || behaviorProfile.suppressionDefaults.suppressesSuggestionsByDefault {
            return 0.95
        }

        switch profile.supportLevel {
        case .green:
            return fieldKind == .unknown ? 0.18 : 0.05
        case .yellow:
            return fieldKind == .unknown ? 0.25 : 0.12
        case .diagnosticsOnly:
            return 0.85
        case .unsupported:
            return 0.95
        }
    }

    nonisolated private static func displayInstability(
        context: FocusedTextContext,
        triggerReason: String,
        latencyMilliseconds: Int
    ) -> Double {
        var score = 0.05
        if triggerReason == "model-stream" {
            score += 0.15
        }
        if context.caretIsSynthetic {
            score += 0.12
        }
        // Latency stays observable, but live context validity decides freshness.
        // Keep only a small instability signal for extreme delays.
        if latencyMilliseconds >= 1_500 {
            score += 0.05
        }
        return displayComponent(score)
    }

    private static func maximumFinalModelDisplayLatencyMilliseconds(
        for request: CompletionRequest,
        suggestion: CompletionSuggestion,
        firstVisible: Bool
    ) -> Int {
        if firstVisible {
            return maximumFirstVisibleModelDisplayLatencyMilliseconds
        }

        guard request.mode == .phraseContinuation,
              suggestion.maxVisibleWords >= 8,
              suggestion.visibleWordCount >= CompletionModelPolicy.preferredMinimumVisibleWords(
                  forVisibleWords: suggestion.maxVisibleWords
              )
        else {
            return maximumFinalModelDisplayLatencyMilliseconds
        }

        return 1_000
    }

    nonisolated private static func displayComponent(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    nonisolated func suggestion(
        for request: CompletionRequest,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion) -> Void
    ) async throws -> CompletionSuggestion? {
        let engine = engineBox.current()
        return try await engine.suggestion(
            for: request,
            onPartialSuggestion: onPartialSuggestion
        )
    }
}

private final class CompletionEngineBox: @unchecked Sendable {
    private let lock = NSLock()
    private var engine: any CompletionEngine

    init(engine: any CompletionEngine) {
        self.engine = engine
    }

    func current() -> any CompletionEngine {
        lock.withLock {
            engine
        }
    }

    func update(_ engine: any CompletionEngine) {
        lock.withLock {
            self.engine = engine
        }
    }
}

struct SuggestionOrchestration: Sendable {
    let suggestionID: String
    let request: CompletionRequest
    let ticket: SuggestionRequestTicket
    let startedAt: Date
    let fieldIdentityDescription: String
    let requestMetadata: [String: String]
    let runtimeSessionCacheDecision: RuntimeSessionCacheDecision
    let docLocalContextTexts: [String]
}

private struct DocLocalNGramFieldCorpus: Sendable {
    private(set) var texts: [String] = []

    mutating func append(
        _ rawText: String,
        maxSnapshots: Int,
        maxCharactersPerSnapshot: Int
    ) {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        let bounded = String(trimmed.suffix(max(1, maxCharactersPerSnapshot)))
        if texts.last == bounded {
            return
        }

        texts.append(bounded)
        let overflow = texts.count - max(1, maxSnapshots)
        if overflow > 0 {
            texts.removeFirst(overflow)
        }
    }
}

struct SuggestionDisplayScoreDecision: Sendable {
    let decision: DisplayScoreDecision
    let metadata: [String: String]
}

enum SuggestionPresentationSuppressionReason: String, Sendable {
    case staleRequest = "stale-request"
    case staleField = "stale-field"
    case staleText = "stale-text"
    case staleAfterKeydown = "stale-after-keydown"
}

struct PlacementSuppressionResolution {
    let suppression: PlacementHealthSuppression
    let commandFallbackDecision: CommandFallbackDecision
    let metadata: [String: String]
    let fallbackSuffix: String
}

struct SuggestionRequestInput: Sendable {
    let context: FocusedTextContext
    let appBundleIdentifier: String
    let fieldIdentity: FocusedFieldIdentity
    let fieldClassification: AXFieldClassification
    let acceptedTextStyleSketch: AcceptedTextStyleSketch?
    let visiblePageContext: VisiblePageContext?
    let maxVisibleWords: Int
    let requestMode: CompletionRequestMode
    let suggestionTuning: SuggestionTuning

    init(
        context: FocusedTextContext,
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity,
        fieldClassification: AXFieldClassification,
        acceptedTextStyleSketch: AcceptedTextStyleSketch?,
        visiblePageContext: VisiblePageContext?,
        maxVisibleWords: Int,
        requestMode: CompletionRequestMode,
        suggestionTuning: SuggestionTuning
    ) {
        self.context = context
        self.appBundleIdentifier = appBundleIdentifier
        self.fieldIdentity = fieldIdentity
        self.fieldClassification = fieldClassification
        self.acceptedTextStyleSketch = acceptedTextStyleSketch
        self.visiblePageContext = visiblePageContext
        self.maxVisibleWords = maxVisibleWords
        self.requestMode = requestMode
        self.suggestionTuning = suggestionTuning
    }
}
