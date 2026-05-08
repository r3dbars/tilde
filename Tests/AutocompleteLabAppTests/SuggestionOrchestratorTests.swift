import Foundation
import CoreGraphics
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Suggestion orchestrator")
struct SuggestionOrchestratorTests {
    @MainActor
    @Test("Beginning a request stores rich request metadata and allows its ticket")
    func beginRequestStoresRequestAndAllowsTicket() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let request = CompletionRequest(
            textBeforeCursor: "Can we",
            textAfterCursor: "?",
            appBundleIdentifier: "com.example.editor",
            fieldIdentityDescription: "field:compose",
            fieldKind: .multilineCompose,
            behaviorProfileID: .docsProse,
            documentTitleShape: DocumentTitleShape.from(windowTitle: "Design notes"),
            maxVisibleWords: 7,
            mode: .sentenceContinuation,
            suggestionID: "suggestion-1"
        )

        let orchestration = orchestrator.beginRequest(request)

        #expect(orchestration.suggestionID == "suggestion-1")
        #expect(orchestration.request == request)
        #expect(orchestration.ticket.request == request)
        #expect(orchestrator.currentRequest == request)
        #expect(orchestrator.allows(orchestration.ticket))
    }

    @MainActor
    @Test("Rich input builds request profile metadata and style sketch")
    func richInputBuildsRequestProfileMetadataAndStyleSketch() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        var styleStore = AcceptedTextStyleMemoryStore()
        let field = FocusedFieldIdentity(
            bundleIdentifier: "com.example.editor",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let classification = AXFieldClassification(kind: .multilineCompose, reason: "test-compose")
        let context = makeContext(
            textBeforeCursor: "- Can we",
            textAfterCursor: "?",
            windowTitle: "Plan.md"
        )
        let styleKey = orchestrator.acceptedTextStyleKey(
            appBundleIdentifier: "com.example.editor",
            fieldKind: classification.kind,
            textBeforeCursor: context.textBeforeCursor
        )
        let sketch = styleStore.recordKeptText(" finish this.", key: styleKey)

        let orchestration = orchestrator.beginRequest(SuggestionRequestInput(
            context: context,
            appBundleIdentifier: "com.example.editor",
            fieldIdentity: field,
            fieldClassification: classification,
            acceptedTextStyleSketch: sketch,
            maxVisibleWords: 7,
            requestMode: .phraseContinuation,
            suggestionAggressiveness: .quiet
        ))

        #expect(styleKey.behaviorProfile == AutocompleteBehaviorProfileID.bullets.rawValue)
        #expect(orchestration.request.textBeforeCursor == "- Can we")
        #expect(orchestration.request.textAfterCursor == "?")
        #expect(orchestration.request.appBundleIdentifier == "com.example.editor")
        #expect(orchestration.request.fieldIdentityDescription == field.traceDescription)
        #expect(orchestration.request.fieldKind == .multilineCompose)
        #expect(orchestration.request.behaviorProfileID == .bullets)
        #expect(orchestration.request.acceptedTextStyleSketch == sketch)
        #expect(orchestration.request.documentTitleShape?.fileExtension == "md")
        #expect(orchestration.request.maxVisibleWords == 7)
        #expect(orchestration.request.mode == .phraseContinuation)
        #expect(orchestration.fieldIdentityDescription == field.traceDescription)
        #expect(orchestration.requestMetadata["behaviorProfile"] == "bullets")
        #expect(orchestration.requestMetadata["fieldKind"] == "multilineCompose")
        #expect(orchestration.requestMetadata["fieldKindReason"] == "test-compose")
        #expect(orchestration.requestMetadata["suggestionAggressiveness"] == "quiet")
        #expect(orchestration.requestMetadata["runtimeSessionCacheDecision"] == "reset")
        #expect(orchestration.requestMetadata["runtimeSessionCacheResetReason"] == "no-prior-request")
        #expect(orchestrator.allows(orchestration.ticket))
    }

    @MainActor
    @Test("Rich input records runtime session cache reuse metadata")
    func richInputRecordsRuntimeSessionCacheReuseMetadata() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let field = FocusedFieldIdentity(
            bundleIdentifier: "com.example.editor",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let classification = AXFieldClassification(kind: .multilineCompose, reason: "test-compose")

        _ = orchestrator.beginRequest(SuggestionRequestInput(
            context: makeContext(textBeforeCursor: "The plan", textAfterCursor: ""),
            appBundleIdentifier: "com.example.editor",
            fieldIdentity: field,
            fieldClassification: classification,
            acceptedTextStyleSketch: nil,
            maxVisibleWords: 5,
            requestMode: .phraseContinuation,
            suggestionAggressiveness: .normal
        ))
        let second = orchestrator.beginRequest(SuggestionRequestInput(
            context: makeContext(textBeforeCursor: "The plan is", textAfterCursor: ""),
            appBundleIdentifier: "com.example.editor",
            fieldIdentity: field,
            fieldClassification: classification,
            acceptedTextStyleSketch: nil,
            maxVisibleWords: 5,
            requestMode: .phraseContinuation,
            suggestionAggressiveness: .normal
        ))

        #expect(second.runtimeSessionCacheDecision.canReuse)
        #expect(second.requestMetadata["runtimeSessionCacheEligible"] == "true")
        #expect(second.requestMetadata["runtimeSessionCacheDecision"] == "reuse")
        #expect(second.requestMetadata["runtimeSessionCacheKey"]?.contains(field.traceDescription) == true)
    }

    @MainActor
    @Test("A newer request blocks an older request ticket")
    func newerRequestBlocksOlderTicket() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let first = CompletionRequest(textBeforeCursor: "Can we", suggestionID: "first")
        let second = CompletionRequest(textBeforeCursor: "Can we make", suggestionID: "second")

        let firstTicket = orchestrator.beginRequest(first).ticket
        let secondTicket = orchestrator.beginRequest(second).ticket

        #expect(!orchestrator.allows(firstTicket))
        #expect(orchestrator.allows(secondTicket))
        #expect(orchestrator.currentRequest == second)
    }

    @MainActor
    @Test("Field delivery guard blocks stale field results")
    func fieldDeliveryGuardBlocksStaleFieldResults() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let request = CompletionRequest(textBeforeCursor: "Can we", suggestionID: "field")
        let ticket = orchestrator.beginRequest(request).ticket
        let field = FocusedFieldIdentity(
            bundleIdentifier: "com.example.editor",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let otherField = FocusedFieldIdentity(
            bundleIdentifier: "com.example.editor",
            processIdentifier: 42,
            elementIdentifier: 8
        )

        #expect(orchestrator.allows(ticket, fieldIdentity: field, currentFieldIdentity: field))
        #expect(!orchestrator.allows(ticket, fieldIdentity: field, currentFieldIdentity: otherField))
        #expect(!orchestrator.allows(ticket, fieldIdentity: field, currentFieldIdentity: nil))
    }

    @MainActor
    @Test("Failure visibility uses current request and current field")
    func failureVisibilityUsesCurrentRequestAndCurrentField() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let field = FocusedFieldIdentity(
            bundleIdentifier: "com.example.editor",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let otherField = FocusedFieldIdentity(
            bundleIdentifier: "com.example.editor",
            processIdentifier: 42,
            elementIdentifier: 8
        )
        let staleTicket = orchestrator.beginRequest(
            CompletionRequest(textBeforeCursor: "Can we", suggestionID: "stale")
        ).ticket
        let currentTicket = orchestrator.beginRequest(
            CompletionRequest(textBeforeCursor: "Can we make", suggestionID: "current")
        ).ticket

        #expect(!orchestrator.shouldHideVisibleSuggestionAfterFailure(
            ticket: staleTicket,
            failedRequestFieldIdentity: field,
            currentFieldIdentity: field
        ))
        #expect(!orchestrator.shouldHideVisibleSuggestionAfterFailure(
            ticket: currentTicket,
            failedRequestFieldIdentity: field,
            currentFieldIdentity: otherField
        ))
        #expect(orchestrator.shouldHideVisibleSuggestionAfterFailure(
            ticket: currentTicket,
            failedRequestFieldIdentity: field,
            currentFieldIdentity: field
        ))
    }

    @MainActor
    @Test("Invalidating clears the current request and blocks stale tickets")
    func invalidateClearsCurrentRequestAndBlocksTickets() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let ticket = orchestrator.beginRequest(
            CompletionRequest(textBeforeCursor: "Can we", suggestionID: "stale")
        ).ticket

        orchestrator.invalidate()

        #expect(orchestrator.currentRequest == nil)
        #expect(!orchestrator.allows(ticket))
    }

    @MainActor
    @Test("Fast word selection exposes candidate metadata")
    func fastWordSelectionExposesMetadata() {
        let orchestrator = SuggestionOrchestrator(
            engine: EchoCompletionEngine(),
            wordCompletionRanker: WordCompletionCandidateRanker(staticWords: ["dictation"])
        )

        let selection = orchestrator.fastWordSelection(for: "dic", recentWords: [])

        #expect(selection.suggestion?.visibleText == "tation")
        #expect(selection.candidateCount == 1)
        #expect(selection.traceMetadata["candidateSelectionSource"] == "fast-word-completion")
        #expect(selection.traceMetadata["candidateSuppressionReason"] == "none")
    }

    @MainActor
    @Test("App model result metadata is trace safe")
    func appModelResultMetadataIsTraceSafe() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let metadata = orchestrator.appModelResultCandidateSelectionMetadata(
            for: CompletionSuggestion(text: " make this feel instant", maxVisibleWords: 3)
        )

        #expect(metadata["candidateSelectionSource"] == "app-model-result")
        #expect(metadata["cleanedCandidateCount"] == "1")
        #expect(metadata["candidateTopScore"] == "1.000")
        #expect(metadata["candidateScoreMargin"] == "none")
        #expect(metadata["candidateSuppressionReason"] == "none")
        #expect(metadata["cleanedWordCount"] == "3")
    }

    @MainActor
    @Test("Display score uses request context and profile")
    func displayScoreUsesRequestContextAndProfile() throws {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))
        let classification = AXFieldClassification(kind: .multilineCompose, reason: "test-compose")
        let request = CompletionRequest(
            textBeforeCursor: "Can we",
            textAfterCursor: "",
            appBundleIdentifier: profile.bundleIdentifier,
            fieldKind: classification.kind,
            behaviorProfileID: .docsProse,
            maxVisibleWords: 4,
            mode: .phraseContinuation,
            suggestionID: "score"
        )
        let signal = AcceptedAndKeptLearningStore().signal(
            for: acceptedAndKeptKey(
                request: request,
                fieldKind: classification.kind,
                profile: profile
            )
        )

        let score = orchestrator.displayScore(
            suggestion: CompletionSuggestion(text: " make this easier", maxVisibleWords: 4),
            request: request,
            context: makeContext(textBeforeCursor: "Can we", textAfterCursor: ""),
            fieldClassification: classification,
            profile: profile,
            triggerReason: "model-result",
            latencyMilliseconds: 400,
            acceptedAndKeptSignal: signal,
            isRepeatedMiss: false
        )

        #expect(abs(score.utility - 0.70) < 0.001)
        #expect(abs(score.styleFit - 0.48) < 0.001)
        #expect(abs(score.contextFit - 0.50) < 0.001)
        #expect(abs(score.userAffinity - 0.15) < 0.001)
        #expect(abs(score.risk - 0.12) < 0.001)
        #expect(abs(score.repetition - 0.05) < 0.001)
        #expect(abs(score.instability - 0.05) < 0.001)
        #expect(score.acceptedAndKeptSampleCount == 0)
    }

    @MainActor
    @Test("Display score includes learning repetition and streaming instability")
    func displayScoreIncludesLearningRepetitionAndStreamingInstability() throws {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))
        let classification = AXFieldClassification(kind: .multilineCompose, reason: "test-compose")
        let request = CompletionRequest(
            textBeforeCursor: "Can we",
            textAfterCursor: "",
            appBundleIdentifier: profile.bundleIdentifier,
            fieldKind: classification.kind,
            behaviorProfileID: .docsProse,
            maxVisibleWords: 4,
            mode: .phraseContinuation,
            suggestionID: "score-learning"
        )
        let key = acceptedAndKeptKey(
            request: request,
            fieldKind: classification.kind,
            profile: profile
        )
        var store = AcceptedAndKeptLearningStore(priorWeight: 1)
        var signal = store.signal(for: key)
        for offset in 0..<6 {
            signal = store.record(.kept, key: key, now: Date(timeIntervalSince1970: Double(offset)))
        }

        let score = orchestrator.displayScore(
            suggestion: CompletionSuggestion(text: " make this easier", maxVisibleWords: 4),
            request: request,
            context: makeContext(textBeforeCursor: "Can we", textAfterCursor: ""),
            fieldClassification: classification,
            profile: profile,
            triggerReason: "model-stream",
            latencyMilliseconds: 1_600,
            acceptedAndKeptSignal: signal,
            isRepeatedMiss: true
        )

        #expect(score.utility > 0.70)
        #expect(score.userAffinity > 0.15)
        #expect(abs(score.repetition - 0.90) < 0.001)
        #expect(abs(score.instability - 0.50) < 0.001)
        #expect(score.acceptedAndKeptSampleCount == 6)
    }

    @MainActor
    @Test("Prefix cooldown and display threshold adjustment are orchestrated")
    func prefixCooldownAndDisplayThresholdAdjustmentAreOrchestrated() throws {
        let now = Date(timeIntervalSince1970: 100)
        let orchestrator = SuggestionOrchestrator(
            engine: EchoCompletionEngine(),
            prefixFamilyCooldownPolicy: PrefixFamilyCooldownPolicy(
                typedOverCooldownMilliseconds: 1_000,
                repeatedTypedOverCooldownMilliseconds: 1_000,
                typedOverEagernessThreshold: 1,
                typedOverEagernessHalfLifeSeconds: 600,
                traceFingerprintSecret: Data("unit-test-secret".utf8)
            )
        )
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))
        let field = FocusedFieldIdentity(
            bundleIdentifier: profile.bundleIdentifier,
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let input = PrefixFamilyCooldownInput(
            appBundleIdentifier: profile.bundleIdentifier,
            fieldIdentifier: field.traceDescription,
            requestMode: .phraseContinuation,
            textBeforeCursor: "Can we"
        )

        #expect(orchestrator.prefixCooldownDecision(for: input, now: now).canRequest)
        let cooldown = try #require(orchestrator.recordPrefixFamilyCooldown(.typedOver, input: input, now: now))
        #expect(cooldown.reason == .typedOver)
        #expect(cooldown.durationMilliseconds == 1_000)

        guard case let .coolingDown(activeCooldown) = orchestrator.prefixCooldownDecision(for: input, now: now) else {
            Issue.record("Expected prefix family cooldown after recording typed-over")
            return
        }
        #expect(activeCooldown.reason == .typedOver)

        let classification = AXFieldClassification(kind: .multilineCompose, reason: "test-compose")
        let request = CompletionRequest(
            textBeforeCursor: "Can we",
            textAfterCursor: "",
            appBundleIdentifier: profile.bundleIdentifier,
            fieldKind: classification.kind,
            behaviorProfileID: .docsProse,
            maxVisibleWords: 4,
            mode: .phraseContinuation,
            suggestionID: "score-prefix"
        )
        let signal = AcceptedAndKeptLearningStore().signal(
            for: acceptedAndKeptKey(
                request: request,
                fieldKind: classification.kind,
                profile: profile
            )
        )

        let display = orchestrator.displayScoreDecision(
            suggestion: CompletionSuggestion(text: " make this easier", maxVisibleWords: 4),
            request: request,
            context: makeContext(textBeforeCursor: "Can we", textAfterCursor: ""),
            fieldClassification: classification,
            profile: profile,
            fieldIdentity: field,
            triggerReason: "model-result",
            latencyMilliseconds: 400,
            acceptedAndKeptSignal: signal,
            isRepeatedMiss: false,
            displayScorePolicy: DisplayScorePolicy(),
            now: now
        )

        #expect(display.decision.shouldDisplay)
        #expect(display.metadata["prefixEagernessApplied"] == "true")
        #expect(display.metadata["prefixEagernessThresholdAdjustment"] == "0.18")
        #expect(display.metadata["displayScoreThreshold"] == "1.18")

        orchestrator.resetPrefixFamilyCooldownPolicy(
            PrefixFamilyCooldownPolicy(traceFingerprintSecret: Data("unit-test-secret".utf8))
        )
        #expect(orchestrator.prefixCooldownDecision(for: input, now: now).canRequest)
    }

    @MainActor
    @Test("Replacement decision uses visible age and score margin")
    func replacementDecisionUsesVisibleAgeAndScoreMargin() {
        let now = Date(timeIntervalSince1970: 10)
        let currentPresentedAt = now.addingTimeInterval(-0.2)
        let orchestrator = SuggestionOrchestrator(
            engine: EchoCompletionEngine(),
            suggestionReplacementPolicy: SuggestionReplacementPolicy(
                minimumFreshLifetimeMilliseconds: 1_200,
                staleLifetimeMilliseconds: 2_000,
                minimumScoreMargin: 0.35
            )
        )

        let blocked = orchestrator.replacementDecision(
            currentVisibleText: " make this easier",
            proposedVisibleText: " make this quieter",
            currentSuggestionID: "current",
            proposedSuggestionID: "proposed",
            currentPresentedAt: currentPresentedAt,
            currentScore: 1.00,
            proposedScore: 1.10,
            now: now
        )
        #expect(!blocked.shouldPresent)
        #expect(blocked.reason == .freshVisibleSuggestion)
        #expect(blocked.currentAgeMilliseconds == 199 || blocked.currentAgeMilliseconds == 200)

        let allowed = orchestrator.replacementDecision(
            currentVisibleText: " make this easier",
            proposedVisibleText: " make this much better",
            currentSuggestionID: "current",
            proposedSuggestionID: "proposed",
            currentPresentedAt: currentPresentedAt,
            currentScore: 1.00,
            proposedScore: 1.50,
            now: now
        )
        #expect(allowed.shouldPresent)
        #expect(allowed.reason == nil)
        #expect(allowed.metadata["replacementScoreMargin"] == "0.50")
    }

    @MainActor
    @Test("Streaming partial pacing is scoped by suggestion")
    func streamingPartialPacingIsScopedBySuggestion() {
        let orchestrator = SuggestionOrchestrator(
            engine: EchoCompletionEngine(),
            suggestionPresentationGate: SuggestionPresentationGate(
                minimumStreamingPhraseWords: 2,
                minimumStreamingPhraseCharacterDelta: 4,
                minimumStreamingIntervalMilliseconds: 50,
                maximumStreamingPartialPresentations: 2
            )
        )
        orchestrator.startStreamingPresentation(suggestionID: "stream")

        #expect(orchestrator.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " make this", maxVisibleWords: 3),
            suggestionID: "stream",
            mode: .phraseContinuation,
            nowMilliseconds: 100
        ))
        #expect(!orchestrator.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " make this better", maxVisibleWords: 3),
            suggestionID: "stream",
            mode: .phraseContinuation,
            nowMilliseconds: 120
        ))
        #expect(orchestrator.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " make this better", maxVisibleWords: 3),
            suggestionID: "stream",
            mode: .phraseContinuation,
            nowMilliseconds: 160
        ))
        #expect(!orchestrator.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " make this better today", maxVisibleWords: 4),
            suggestionID: "stream",
            mode: .phraseContinuation,
            nowMilliseconds: 240
        ))

        orchestrator.finishStreamingPresentation(suggestionID: "stream")
        #expect(orchestrator.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " make this", maxVisibleWords: 3),
            suggestionID: "stream",
            mode: .phraseContinuation,
            nowMilliseconds: 300
        ))

        orchestrator.clearStreamingPresentations()
        #expect(orchestrator.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " make this", maxVisibleWords: 3),
            suggestionID: "stream",
            mode: .phraseContinuation,
            nowMilliseconds: 360
        ))
    }

    @MainActor
    @Test("Placement health plan applies Chrome synthetic caret proof gate")
    func placementHealthPlanAppliesChromeSyntheticCaretProofGate() throws {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let chrome = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))
        let learningAdjustment = CompatibilityLearningAdjustment(
            profile: nil,
            effectiveRenderMode: .inlineAdjacent
        )
        let context = makeContext(
            textBeforeCursor: "const value = mon",
            textAfterCursor: "",
            windowTitle: "Autocomplete Lab Chrome Real Monaco Smoke",
            caretIsSynthetic: true
        )

        let unproofed = orchestrator.placementHealthPlan(
            context: context,
            profile: chrome,
            learningAdjustment: learningAdjustment,
            screenshotTracingEnabled: false
        )
        guard case let .present(unproofedPresentation) = unproofed else {
            Issue.record("Expected unproofed synthetic caret to use Chrome fallback")
            return
        }
        #expect(unproofedPresentation.renderMode == .floatingMirror)
        #expect(unproofedPresentation.anchorSource == .element)
        #expect(unproofedPresentation.reason == .untrustedSyntheticCaret)

        let proofed = orchestrator.placementHealthPlan(
            context: context,
            profile: chrome,
            learningAdjustment: learningAdjustment,
            screenshotTracingEnabled: true
        )
        guard case let .present(proofedPresentation) = proofed else {
            Issue.record("Expected proofed synthetic caret to present inline")
            return
        }
        #expect(proofedPresentation.renderMode == .inlineAdjacent)
        #expect(proofedPresentation.anchorSource == .syntheticCaret)
        #expect(proofedPresentation.reason == .healthy)
    }

    @MainActor
    @Test("Suggestion calls delegate to the configured engine")
    func suggestionDelegatesToEngine() async throws {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let request = CompletionRequest(
            textBeforeCursor: "Can we",
            maxVisibleWords: 3,
            mode: .phraseContinuation
        )
        let partials = PartialRecorder()

        let suggestion = try await orchestrator.suggestion(for: request) { partial in
            partials.append(partial)
        }

        #expect(partials.visibleTexts == [" make"])
        #expect(suggestion?.visibleText == " make this feel")
    }

    @MainActor
    @Test("Updating the engine changes future suggestions")
    func updateEngineChangesFutureSuggestions() async throws {
        let orchestrator = SuggestionOrchestrator(engine: FixedCompletionEngine(text: " old path"))
        let request = CompletionRequest(textBeforeCursor: "Can we", maxVisibleWords: 3)

        let first = try await orchestrator.suggestion(for: request) { _ in }
        orchestrator.updateEngine(FixedCompletionEngine(text: " new path"))
        let second = try await orchestrator.suggestion(for: request) { _ in }

        #expect(first?.visibleText == " old path")
        #expect(second?.visibleText == " new path")
    }
}

private final class PartialRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var suggestions: [CompletionSuggestion] = []

    var visibleTexts: [String] {
        lock.withLock {
            suggestions.map(\.visibleText)
        }
    }

    func append(_ suggestion: CompletionSuggestion) {
        lock.withLock {
            suggestions.append(suggestion)
        }
    }
}

private struct EchoCompletionEngine: CompletionEngine {
    func suggestion(for request: CompletionRequest) async throws -> CompletionSuggestion? {
        CompletionSuggestion(text: " make this feel instant", maxVisibleWords: request.maxVisibleWords)
    }

    func suggestion(
        for request: CompletionRequest,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion) -> Void
    ) async throws -> CompletionSuggestion? {
        onPartialSuggestion(CompletionSuggestion(text: " make", maxVisibleWords: request.maxVisibleWords))
        return try await suggestion(for: request)
    }
}

private struct FixedCompletionEngine: CompletionEngine {
    let text: String

    func suggestion(for request: CompletionRequest) async throws -> CompletionSuggestion? {
        CompletionSuggestion(text: text, maxVisibleWords: request.maxVisibleWords)
    }
}

private func acceptedAndKeptKey(
    request: CompletionRequest,
    fieldKind: AXFieldKind,
    profile: CompatibilityProfile
) -> AcceptedAndKeptLearningKey {
    AcceptedAndKeptLearningKey(
        appBundleIdentifier: request.appBundleIdentifier ?? profile.bundleIdentifier,
        fieldKind: fieldKind,
        requestMode: request.mode,
        behaviorProfileID: request.behaviorProfile.id
    )
}

private func makeContext(
    textBeforeCursor: String,
    textAfterCursor: String,
    windowTitle: String? = nil,
    caretIsSynthetic: Bool = false
) -> FocusedTextContext {
    FocusedTextContext(
        elementIdentifier: 7,
        role: "AXTextArea",
        subrole: nil,
        fingerprint: FocusedElementFingerprint(windowTitle: windowTitle),
        textBeforeCursor: textBeforeCursor,
        textAfterCursor: textAfterCursor,
        selectedTextLength: 0,
        caretRect: CGRect(x: 10, y: 10, width: 1, height: 18),
        elementRect: CGRect(x: 0, y: 0, width: 400, height: 200),
        windowRect: CGRect(x: 0, y: 0, width: 500, height: 300),
        textLineRect: CGRect(x: 10, y: 10, width: 120, height: 18),
        textStyle: nil,
        isSecure: false,
        caretIsSynthetic: caretIsSynthetic,
        capabilities: FocusedTextCapabilities(
            canReadValue: true,
            canReadSelectedTextRange: true,
            canReadBoundsForRange: true,
            canReadAttributedText: false,
            canSetSelectedText: true
        )
    )
}
