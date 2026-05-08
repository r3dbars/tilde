import Foundation
import AutocompleteLabCore

@MainActor
final class SuggestionOrchestrator {
    private let engineBox: CompletionEngineBox
    private let wordCompletionRanker: WordCompletionCandidateRanker
    private let failureVisibilityPolicy = CompletionFailureVisibilityPolicy()
    private var requestGate = SuggestionRequestGate()
    private var currentRequestStorage: CompletionRequest?
    private var prefixFamilyCooldownPolicy: PrefixFamilyCooldownPolicy

    init(
        engine: any CompletionEngine,
        wordCompletionRanker: WordCompletionCandidateRanker = WordCompletionCandidateRanker(),
        prefixFamilyCooldownPolicy: PrefixFamilyCooldownPolicy = PrefixFamilyCooldownPolicy()
    ) {
        self.engineBox = CompletionEngineBox(engine: engine)
        self.wordCompletionRanker = wordCompletionRanker
        self.prefixFamilyCooldownPolicy = prefixFamilyCooldownPolicy
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
        let fieldIdentityDescription = input.fieldIdentity.traceDescription
        let request = CompletionRequest(
            textBeforeCursor: input.context.textBeforeCursor,
            textAfterCursor: input.context.textAfterCursor,
            appBundleIdentifier: input.appBundleIdentifier,
            fieldIdentityDescription: fieldIdentityDescription,
            fieldKind: input.fieldClassification.kind,
            behaviorProfileID: behaviorProfileID(
                appBundleIdentifier: input.appBundleIdentifier,
                fieldKind: input.fieldClassification.kind,
                textBeforeCursor: input.context.textBeforeCursor
            ),
            acceptedTextStyleSketch: input.acceptedTextStyleSketch,
            documentTitleShape: DocumentTitleShape.from(windowTitle: input.context.fingerprint.windowTitle),
            maxVisibleWords: input.maxVisibleWords,
            mode: input.requestMode,
            suggestionID: suggestionID
        )
        return beginRequest(
            request,
            fieldClassification: input.fieldClassification,
            suggestionAggressiveness: input.suggestionAggressiveness
        )
    }

    func beginRequest(_ request: CompletionRequest) -> SuggestionOrchestration {
        beginRequest(
            request,
            fieldClassification: nil,
            suggestionAggressiveness: nil
        )
    }

    private func beginRequest(
        _ request: CompletionRequest,
        fieldClassification: AXFieldClassification?,
        suggestionAggressiveness: SuggestionAggressiveness?
    ) -> SuggestionOrchestration {
        let runtimeSessionCacheDecision = RuntimeSessionCachePolicy().decision(
            previous: currentRequestStorage,
            current: request
        )
        var requestMetadata = request.behaviorProfileTraceMetadata
            .merging(runtimeSessionCacheDecision.traceMetadata) { current, _ in current }
        if let fieldClassification {
            requestMetadata.merge(fieldClassification.traceMetadata) { current, _ in current }
        }
        if let suggestionAggressiveness {
            requestMetadata.merge(suggestionAggressiveness.traceMetadata) { current, _ in current }
        }

        currentRequestStorage = request
        return SuggestionOrchestration(
            suggestionID: request.suggestionID,
            request: request,
            ticket: requestGate.issue(request: request),
            startedAt: Date(),
            fieldIdentityDescription: request.fieldIdentityDescription ?? "",
            requestMetadata: requestMetadata,
            runtimeSessionCacheDecision: runtimeSessionCacheDecision
        )
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
        prefixFamilyCooldownPolicy.decision(for: input, now: now)
    }

    func recordPrefixFamilyCooldown(
        _ reason: PrefixFamilyCooldownReason,
        input: PrefixFamilyCooldownInput,
        now: Date = Date()
    ) -> PrefixFamilyCooldown? {
        prefixFamilyCooldownPolicy.record(reason, input: input, now: now)
    }

    func resetPrefixFamilyCooldownPolicy(_ policy: PrefixFamilyCooldownPolicy) {
        prefixFamilyCooldownPolicy = policy
    }

    nonisolated func fastWordSuggestion(
        for textBeforeCursor: String,
        recentWords: [String]
    ) -> CompletionSuggestion? {
        fastWordSelection(
            for: textBeforeCursor,
            recentWords: recentWords
        ).suggestion
    }

    nonisolated func fastWordSelection(
        for textBeforeCursor: String,
        recentWords: [String]
    ) -> WordCompletionCandidateSelection {
        wordCompletionRanker.selection(
            for: textBeforeCursor,
            recentWords: recentWords
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
            acceptedAndKeptProbability: acceptedAndKeptSignal.probability,
            acceptedAndKeptSampleCount: acceptedAndKeptSignal.sampleCount,
            acceptedAndKeptUtilityAdjustment: acceptedAndKeptSignal.utilityAdjustment
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
        now: Date = Date()
    ) -> SuggestionDisplayScoreDecision {
        let prefixEagernessAdjustment = prefixFamilyCooldownPolicy.eagernessAdjustment(
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
        let decision = displayScorePolicy
            .adjustingThresholds(by: prefixEagernessAdjustment.thresholdAdjustment)
            .decision(
                for: score,
                mode: request.mode,
                behaviorProfileID: request.behaviorProfile.id
            )
        return SuggestionDisplayScoreDecision(
            decision: decision,
            metadata: decision.metadata
                .merging(prefixEagernessAdjustment.metadata) { current, _ in current }
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
            case 3...5:
                base = 0.64
            case 2, 6:
                base = 0.52
            default:
                base = 0.38
            }
        case .phraseContinuation:
            switch visibleWordCount {
            case 2...4:
                base = 0.70
            case 5...7:
                base = 0.58
            case 1:
                base = 0.48
            default:
                base = 0.40
            }
        }

        return displayComponent(base + acceptedAndKeptSignal.utilityAdjustment)
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
        case .search, .form, .secure, .url:
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
        if latencyMilliseconds >= 1_500 {
            score += 0.30
        } else if latencyMilliseconds >= 800 {
            score += 0.15
        }
        return displayComponent(score)
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
}

struct SuggestionDisplayScoreDecision: Sendable {
    let decision: DisplayScoreDecision
    let metadata: [String: String]
}

struct SuggestionRequestInput: Sendable {
    let context: FocusedTextContext
    let appBundleIdentifier: String
    let fieldIdentity: FocusedFieldIdentity
    let fieldClassification: AXFieldClassification
    let acceptedTextStyleSketch: AcceptedTextStyleSketch?
    let maxVisibleWords: Int
    let requestMode: CompletionRequestMode
    let suggestionAggressiveness: SuggestionAggressiveness
}
