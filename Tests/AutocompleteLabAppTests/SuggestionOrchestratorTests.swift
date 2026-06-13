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
            visiblePageContext: VisiblePageContext(text: "Launch Plan\nKeep this local and fast."),
            maxVisibleWords: 7,
            requestMode: .phraseContinuation,
            suggestionTuning: SuggestionTuning(aggressiveness: .quiet)
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
        #expect(orchestration.request.visiblePageContext?.text.contains("Launch Plan") == true)
        #expect(orchestration.request.maxVisibleWords == 7)
        #expect(orchestration.request.mode == .phraseContinuation)
        #expect(orchestration.fieldIdentityDescription == field.traceDescription)
        #expect(orchestration.requestMetadata["behaviorProfile"] == "bullets")
        #expect(orchestration.requestMetadata["fieldKind"] == "multilineCompose")
        #expect(orchestration.requestMetadata["fieldKindReason"] == "test-compose")
        #expect(orchestration.requestMetadata["suggestionAggressiveness"] == "quiet")
        #expect(orchestration.requestMetadata["suggestionAggressivenessLevel"] == "1")
        #expect(orchestration.requestMetadata["suggestionMaxVisibleWords"] == "8")
        #expect(orchestration.requestMetadata["visiblePageContextSource"] == "screen_ocr")
        #expect(orchestration.requestMetadata["visiblePageContextCaptureScope"] == "visible_screen")
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
            visiblePageContext: nil,
            maxVisibleWords: 5,
            requestMode: .phraseContinuation,
            suggestionTuning: SuggestionTuning(aggressiveness: .normal)
        ))
        let second = orchestrator.beginRequest(SuggestionRequestInput(
            context: makeContext(textBeforeCursor: "The plan is", textAfterCursor: ""),
            appBundleIdentifier: "com.example.editor",
            fieldIdentity: field,
            fieldClassification: classification,
            acceptedTextStyleSketch: nil,
            visiblePageContext: nil,
            maxVisibleWords: 5,
            requestMode: .phraseContinuation,
            suggestionTuning: SuggestionTuning(aggressiveness: .normal)
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
    @Test("Final result display guard blocks stale field identity before display")
    func finalResultDisplayGuardBlocksStaleFieldIdentityBeforeDisplay() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let request = CompletionRequest(textBeforeCursor: "Can we", suggestionID: "final")
        let ticket = orchestrator.beginRequest(request).ticket
        let field = testFieldIdentity(elementIdentifier: 7)
        let otherField = testFieldIdentity(elementIdentifier: 8)

        let reason = orchestrator.presentationSuppressionReason(
            requestTicket: ticket,
            request: request,
            fieldIdentity: field,
            currentFieldIdentity: otherField,
            currentSnapshot: FocusedTextSnapshot(
                fieldIdentity: otherField,
                textBeforeCursor: request.textBeforeCursor,
                textAfterCursor: request.textAfterCursor
            ),
            invalidatedByUserTyping: false
        )

        #expect(reason == .staleField)
    }

    @MainActor
    @Test("Fast fallback display guard blocks stale text before display")
    func fastFallbackDisplayGuardBlocksStaleTextBeforeDisplay() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let request = CompletionRequest(textBeforeCursor: "Can we", suggestionID: "fast")
        let ticket = orchestrator.beginRequest(request).ticket
        let field = testFieldIdentity(elementIdentifier: 7)

        let reason = orchestrator.presentationSuppressionReason(
            requestTicket: ticket,
            request: request,
            fieldIdentity: field,
            currentFieldIdentity: field,
            currentSnapshot: FocusedTextSnapshot(
                fieldIdentity: field,
                textBeforeCursor: "Can we still",
                textAfterCursor: request.textAfterCursor
            ),
            invalidatedByUserTyping: false
        )

        #expect(reason == .staleText)
    }

    @MainActor
    @Test("Streaming partial display guard blocks user typing invalidation before display")
    func streamingPartialDisplayGuardBlocksUserTypingInvalidationBeforeDisplay() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let request = CompletionRequest(textBeforeCursor: "Can we", suggestionID: "stream")
        let ticket = orchestrator.beginRequest(request).ticket
        let field = testFieldIdentity(elementIdentifier: 7)

        let reason = orchestrator.presentationSuppressionReason(
            requestTicket: ticket,
            request: request,
            fieldIdentity: field,
            currentFieldIdentity: field,
            currentSnapshot: FocusedTextSnapshot(
                fieldIdentity: field,
                textBeforeCursor: request.textBeforeCursor,
                textAfterCursor: request.textAfterCursor
            ),
            invalidatedByUserTyping: true
        )

        #expect(reason == .staleAfterKeydown)
    }

    @MainActor
    @Test("Display guard allows current unchanged request")
    func displayGuardAllowsCurrentUnchangedRequest() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let request = CompletionRequest(textBeforeCursor: "Can we", suggestionID: "current")
        let ticket = orchestrator.beginRequest(request).ticket
        let field = testFieldIdentity(elementIdentifier: 7)

        let reason = orchestrator.presentationSuppressionReason(
            requestTicket: ticket,
            request: request,
            fieldIdentity: field,
            currentFieldIdentity: field,
            currentSnapshot: FocusedTextSnapshot(
                fieldIdentity: field,
                textBeforeCursor: request.textBeforeCursor,
                textAfterCursor: request.textAfterCursor
            ),
            invalidatedByUserTyping: false
        )

        #expect(reason == nil)
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
    @Test("Empty final preserves visible streaming suggestion for same request")
    func emptyFinalPreservesVisibleStreamingSuggestionForSameRequest() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let field = FocusedFieldIdentity(
            bundleIdentifier: "com.example.editor",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let ticket = orchestrator.beginRequest(
            CompletionRequest(textBeforeCursor: "Can we", suggestionID: "stream")
        ).ticket

        #expect(orchestrator.shouldKeepVisibleStreamingSuggestionAfterEmptyFinal(
            suggestionID: "stream",
            currentSuggestionID: "stream",
            ticket: ticket,
            fieldIdentity: field,
            currentFieldIdentity: field,
            hasVisibleSuggestion: true
        ))
        #expect(!orchestrator.shouldKeepVisibleStreamingSuggestionAfterEmptyFinal(
            suggestionID: "stream",
            currentSuggestionID: "other",
            ticket: ticket,
            fieldIdentity: field,
            currentFieldIdentity: field,
            hasVisibleSuggestion: true
        ))
        #expect(!orchestrator.shouldKeepVisibleStreamingSuggestionAfterEmptyFinal(
            suggestionID: "stream",
            currentSuggestionID: "stream",
            ticket: ticket,
            fieldIdentity: field,
            currentFieldIdentity: nil,
            hasVisibleSuggestion: true
        ))
        #expect(!orchestrator.shouldKeepVisibleStreamingSuggestionAfterEmptyFinal(
            suggestionID: "stream",
            currentSuggestionID: "stream",
            ticket: ticket,
            fieldIdentity: field,
            currentFieldIdentity: field,
            hasVisibleSuggestion: false
        ))
    }

    @MainActor
    @Test("Model failure preserves visible fast fallback for same request")
    func modelFailurePreservesVisibleFastFallbackForSameRequest() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let field = FocusedFieldIdentity(
            bundleIdentifier: "com.example.editor",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let ticket = orchestrator.beginRequest(
            CompletionRequest(textBeforeCursor: "I just wanted to", suggestionID: "fast")
        ).ticket

        #expect(orchestrator.shouldKeepVisibleSuggestionAfterModelContinuationFailure(
            suggestionID: "fast",
            currentSuggestionID: "fast",
            ticket: ticket,
            fieldIdentity: field,
            currentFieldIdentity: field,
            hasVisibleSuggestion: true
        ))
        #expect(!orchestrator.shouldKeepVisibleSuggestionAfterModelContinuationFailure(
            suggestionID: "fast",
            currentSuggestionID: "other",
            ticket: ticket,
            fieldIdentity: field,
            currentFieldIdentity: field,
            hasVisibleSuggestion: true
        ))
        #expect(!orchestrator.shouldKeepVisibleSuggestionAfterModelContinuationFailure(
            suggestionID: "fast",
            currentSuggestionID: "fast",
            ticket: ticket,
            fieldIdentity: field,
            currentFieldIdentity: nil,
            hasVisibleSuggestion: true
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
    @Test("Fast word selection can opt into predictive fallback")
    func fastWordSelectionPredictiveFallback() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())

        let quietSelection = orchestrator.fastWordSelection(
            for: "Smoke proof feels",
            recentWords: []
        )
        let proactiveSelection = orchestrator.fastWordSelection(
            for: "Smoke proof feels",
            recentWords: [],
            allowPredictiveFallback: true
        )

        #expect(quietSelection.suggestion == nil)
        #expect(proactiveSelection.suggestion?.visibleText == " instant")
        #expect(proactiveSelection.traceMetadata["candidateSelectionSource"] == "predictive-word-fallback")
    }

    @MainActor
    @Test("Fast phrase selection predicts common continuations when enabled")
    func fastPhraseSelectionPredictiveFallback() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())

        let disabledSelection = orchestrator.fastPhraseSelection(
            for: "Quick note: I just wanted to",
            behaviorProfileID: .docsProse,
            maxVisibleWords: 4
        )
        let enabledSelection = orchestrator.fastPhraseSelection(
            for: "Quick note: I just wanted to",
            behaviorProfileID: .docsProse,
            maxVisibleWords: 4,
            allowPredictiveFallback: true
        )

        #expect(disabledSelection.suggestion == nil)
        #expect(disabledSelection.suppressionReason == "disabled")
        #expect(enabledSelection.suggestion?.visibleText == " follow up")
        #expect(enabledSelection.traceMetadata["candidateSelectionSource"] == "canned-bridge")
        #expect(enabledSelection.traceMetadata["cannedBridgeMatch"] == "i just wanted to")
        #expect(enabledSelection.traceMetadata["predictivePhraseMatch"] == nil)
    }

    @MainActor
    @Test("Fast phrase selection wires doc-local corpus before canned bridges")
    func fastPhraseSelectionUsesDocLocalCorpusBeforeCannedBridges() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let field = testFieldIdentity(elementIdentifier: 7)
        let classification = AXFieldClassification(kind: .multilineCompose, reason: "test-compose")

        _ = orchestrator.beginRequest(SuggestionRequestInput(
            context: makeContext(
                textBeforeCursor: "The onboarding screen should make permission feel clear before setup",
                textAfterCursor: ""
            ),
            appBundleIdentifier: field.bundleIdentifier,
            fieldIdentity: field,
            fieldClassification: classification,
            acceptedTextStyleSketch: nil,
            visiblePageContext: nil,
            maxVisibleWords: 8,
            requestMode: .phraseContinuation,
            suggestionTuning: SuggestionTuning(aggressiveness: .eager)
        ))
        let orchestration = orchestrator.beginRequest(SuggestionRequestInput(
            context: makeContext(
                textBeforeCursor: "The onboarding screen should make",
                textAfterCursor: ""
            ),
            appBundleIdentifier: field.bundleIdentifier,
            fieldIdentity: field,
            fieldClassification: classification,
            acceptedTextStyleSketch: nil,
            visiblePageContext: nil,
            maxVisibleWords: 8,
            requestMode: .phraseContinuation,
            suggestionTuning: SuggestionTuning(aggressiveness: .eager)
        ))

        let selection = orchestrator.fastPhraseSelection(
            for: orchestration.request.textBeforeCursor,
            docLocalContextTexts: orchestration.docLocalContextTexts,
            behaviorProfileID: orchestration.request.behaviorProfileID,
            maxVisibleWords: orchestration.request.maxVisibleWords,
            allowPredictiveFallback: true
        )

        #expect(selection.suggestion?.visibleText == " permission feel clear before setup")
        #expect(selection.traceMetadata["candidateSelectionSource"] == "doc-local-ngram")
        #expect(selection.traceMetadata["docLocalNGramMatch"] == "order-5-local-context")
        #expect(SuggestionStatusText.shown(
            mode: orchestration.request.mode,
            triggerReason: "predictive-phrase-fallback",
            latencyMilliseconds: 0,
            metadata: selection.traceMetadata
        ) == "Shown: phrase doc local 0ms")
    }

    @MainActor
    @Test("Fast phrase selection can opt into prompt-app proof prediction")
    func fastPhraseSelectionPromptAppProofPrediction() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())

        let blockedSelection = orchestrator.fastPhraseSelection(
            for: "Please make this",
            behaviorProfileID: .aiChat,
            maxVisibleWords: 4,
            allowPredictiveFallback: true
        )
        let proofSelection = orchestrator.fastPhraseSelection(
            for: "Please make this",
            behaviorProfileID: .aiChat,
            maxVisibleWords: 4,
            allowPredictiveFallback: true,
            allowPromptAppPrediction: true
        )

        #expect(blockedSelection.suppressionReason == "unsupported-profile")
        #expect(proofSelection.suggestion?.visibleText == " clearer")
        #expect(proofSelection.traceMetadata["candidateSelectionSource"] == "canned-bridge")
        #expect(proofSelection.traceMetadata["cannedBridgeMatch"] == "please make this")
        #expect(proofSelection.traceMetadata["predictivePhraseMatch"] == nil)
    }

    @MainActor
    @Test("Fast phrase fallback uses accepted-kept learning restraint")
    func fastPhraseFallbackUsesAcceptedKeptLearningRestraint() throws {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let request = CompletionRequest(
            textBeforeCursor: "I think what matters is",
            textAfterCursor: "",
            appBundleIdentifier: profile.bundleIdentifier,
            fieldKind: .multilineCompose,
            behaviorProfileID: .docsProse,
            maxVisibleWords: 4,
            mode: .phraseContinuation,
            suggestionID: "fast-phrase-learning"
        )
        let key = acceptedAndKeptKey(
            request: request,
            fieldKind: .multilineCompose,
            profile: profile
        )

        var rejectedStore = AcceptedAndKeptLearningStore(priorWeight: 1)
        var rejectedSignal = rejectedStore.signal(for: key)
        for offset in 0..<6 {
            rejectedSignal = rejectedStore.record(
                .rejected,
                key: key,
                now: Date(timeIntervalSince1970: Double(offset))
            )
        }

        let rejectedDecision = orchestrator.fastPhraseFallbackLearningDecision(
            acceptedAndKeptSignal: rejectedSignal,
            probabilityThreshold: rejectedStore.probabilityThreshold(for: .phraseContinuation)
        )

        #expect(rejectedDecision.shouldSuppress)
        #expect(rejectedDecision.reason == "fast-phrase-learning-restraint")
        #expect(rejectedDecision.metadata["fastPhraseFallbackLearningSuppressed"] == "true")
        #expect(rejectedDecision.metadata["fastPhraseFallbackLearningThreshold"] == "0.300")
        #expect(rejectedDecision.metadata["acceptedAndKeptSamples"] == "6")
        #expect(rejectedDecision.metadata["acceptedAndKeptRejected"] == "6")

        var earlyStore = AcceptedAndKeptLearningStore(priorWeight: 1)
        var earlySignal = earlyStore.signal(for: key)
        for offset in 0..<5 {
            earlySignal = earlyStore.record(
                .rejected,
                key: key,
                now: Date(timeIntervalSince1970: Double(offset))
            )
        }

        let earlyDecision = orchestrator.fastPhraseFallbackLearningDecision(
            acceptedAndKeptSignal: earlySignal,
            probabilityThreshold: earlyStore.probabilityThreshold(for: .phraseContinuation)
        )

        #expect(!earlyDecision.shouldSuppress)
        #expect(earlyDecision.reason == nil)
        #expect(earlyDecision.metadata["fastPhraseFallbackLearningSuppressed"] == "false")

        var keptStore = AcceptedAndKeptLearningStore(priorWeight: 1)
        var keptSignal = keptStore.signal(for: key)
        for offset in 0..<6 {
            keptSignal = keptStore.record(
                .kept,
                key: key,
                now: Date(timeIntervalSince1970: Double(offset))
            )
        }

        let keptDecision = orchestrator.fastPhraseFallbackLearningDecision(
            acceptedAndKeptSignal: keptSignal,
            probabilityThreshold: keptStore.probabilityThreshold(for: .phraseContinuation)
        )

        #expect(!keptDecision.shouldSuppress)
        #expect(keptDecision.metadata["fastPhraseFallbackLearningSuppressed"] == "false")
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

        #expect(abs(score.utility - 0.74) < 0.001)
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
    @Test("Late final model results are suppressed before display")
    func lateFinalModelResultsAreSuppressedBeforeDisplay() throws {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let field = FocusedFieldIdentity(
            bundleIdentifier: profile.bundleIdentifier,
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let classification = AXFieldClassification(kind: .multilineCompose, reason: "test-compose")
        let request = CompletionRequest(
            textBeforeCursor: "Can you send the notes",
            appBundleIdentifier: profile.bundleIdentifier,
            fieldKind: classification.kind,
            behaviorProfileID: .docsProse,
            maxVisibleWords: 4,
            mode: .phraseContinuation,
            suggestionID: "late-final"
        )
        let signal = AcceptedAndKeptLearningStore().signal(
            for: acceptedAndKeptKey(
                request: request,
                fieldKind: classification.kind,
                profile: profile
            )
        )

        let display = orchestrator.displayScoreDecision(
            suggestion: CompletionSuggestion(text: " for the meeting", maxVisibleWords: 4),
            request: request,
            context: makeContext(textBeforeCursor: "Can you send the notes", textAfterCursor: ""),
            fieldClassification: classification,
            profile: profile,
            fieldIdentity: field,
            triggerReason: "model-result",
            latencyMilliseconds: 900,
            acceptedAndKeptSignal: signal,
            isRepeatedMiss: false,
            displayScorePolicy: DisplayScorePolicy()
        )

        #expect(!display.decision.shouldDisplay)
        #expect(display.metadata["displayScoreSuppressionReason"] == "too-slow-to-display")
    }

    @MainActor
    @Test("Max tuning still respects low-confidence thin-context suppression")
    func maxTuningStillRespectsLowConfidenceThinContextSuppression() throws {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let field = FocusedFieldIdentity(
            bundleIdentifier: profile.bundleIdentifier,
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let classification = AXFieldClassification(kind: .multilineCompose, reason: "test-compose")
        let request = CompletionRequest(
            textBeforeCursor: "Draft",
            appBundleIdentifier: profile.bundleIdentifier,
            fieldKind: classification.kind,
            behaviorProfileID: .docsProse,
            maxVisibleWords: 8,
            mode: .phraseContinuation,
            suggestionID: "max-thin-context"
        )
        let signal = AcceptedAndKeptLearningStore().signal(
            for: acceptedAndKeptKey(
                request: request,
                fieldKind: classification.kind,
                profile: profile
            )
        )

        let conservativeDisplay = orchestrator.displayScoreDecision(
            suggestion: CompletionSuggestion(text: " ship this today", maxVisibleWords: 8),
            request: request,
            context: makeContext(textBeforeCursor: request.textBeforeCursor, textAfterCursor: ""),
            fieldClassification: classification,
            profile: profile,
            fieldIdentity: field,
            triggerReason: "model-result",
            latencyMilliseconds: 400,
            acceptedAndKeptSignal: signal,
            isRepeatedMiss: false,
            displayScorePolicy: DisplayScorePolicy()
        )
        let maxDisplay = orchestrator.displayScoreDecision(
            suggestion: CompletionSuggestion(text: " ship this today", maxVisibleWords: 8),
            request: request,
            context: makeContext(textBeforeCursor: request.textBeforeCursor, textAfterCursor: ""),
            fieldClassification: classification,
            profile: profile,
            fieldIdentity: field,
            triggerReason: "model-result",
            latencyMilliseconds: 400,
            acceptedAndKeptSignal: signal,
            isRepeatedMiss: false,
            displayScorePolicy: SuggestionTuning(aggressivenessLevel: 5).displayScorePolicy,
            suggestionTuning: SuggestionTuning(aggressivenessLevel: 5)
        )

        #expect(!conservativeDisplay.decision.shouldDisplay)
        #expect(conservativeDisplay.metadata["displayScoreSuppressionReason"] == "low-confidence")
        #expect(!maxDisplay.decision.shouldDisplay)
        #expect(maxDisplay.metadata["displayScoreSuppressionReason"] == "low-confidence")
        #expect(maxDisplay.metadata["completionConfidenceBucket"] == "low")
        #expect(maxDisplay.metadata["completionConfidenceReasons"]?.contains("thin-context") == true)
        #expect(maxDisplay.metadata["displayScoreMaxAggressiveBypass"] == nil)
        #expect(maxDisplay.metadata["displayScoreMaxAggressiveLowConfidenceBypass"] == nil)
    }

    @MainActor
    @Test("Max tuning keeps over-budget Messages chat suggestions quiet")
    func maxTuningKeepsOverBudgetMessagesChatSuggestionsQuiet() throws {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.MobileSMS"))
        let field = FocusedFieldIdentity(
            bundleIdentifier: profile.bundleIdentifier,
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let classification = AXFieldClassification(kind: .singlelineCompose, reason: "singlelineComposeHint")
        let request = CompletionRequest(
            textBeforeCursor: "Yeah",
            appBundleIdentifier: profile.bundleIdentifier,
            fieldKind: classification.kind,
            behaviorProfileID: .casualChat,
            maxVisibleWords: 14,
            mode: .phraseContinuation,
            suggestionID: "messages-late-chat"
        )
        let signal = AcceptedAndKeptLearningStore().signal(
            for: acceptedAndKeptKey(
                request: request,
                fieldKind: classification.kind,
                profile: profile
            )
        )
        let suggestion = CompletionSuggestion(text: " that sounds good to me", maxVisibleWords: 14)

        let conservativeDisplay = orchestrator.displayScoreDecision(
            suggestion: suggestion,
            request: request,
            context: makeContext(textBeforeCursor: request.textBeforeCursor, textAfterCursor: ""),
            fieldClassification: classification,
            profile: profile,
            fieldIdentity: field,
            triggerReason: "model-result",
            latencyMilliseconds: 1_018,
            acceptedAndKeptSignal: signal,
            isRepeatedMiss: false,
            displayScorePolicy: DisplayScorePolicy()
        )
        let maxDisplay = orchestrator.displayScoreDecision(
            suggestion: suggestion,
            request: request,
            context: makeContext(textBeforeCursor: request.textBeforeCursor, textAfterCursor: ""),
            fieldClassification: classification,
            profile: profile,
            fieldIdentity: field,
            triggerReason: "model-result",
            latencyMilliseconds: 1_018,
            acceptedAndKeptSignal: signal,
            isRepeatedMiss: false,
            displayScorePolicy: SuggestionTuning(aggressivenessLevel: 5).displayScorePolicy,
            suggestionTuning: SuggestionTuning(aggressivenessLevel: 5)
        )

        #expect(!conservativeDisplay.decision.shouldDisplay)
        #expect(conservativeDisplay.metadata["displayScoreSuppressionReason"] == "too-slow-to-display")
        #expect(!maxDisplay.decision.shouldDisplay)
        #expect(maxDisplay.metadata["displayScoreSuppressionReason"] == "too-slow-to-display")
        #expect(maxDisplay.metadata["displayScoreMaxAggressiveBypass"] == nil)
        #expect(maxDisplay.metadata["displayScoreMaxAggressiveLatencyBudgetExceeded"] == nil)
    }

    @MainActor
    @Test("Codex no-submit proof candidates bypass final latency suppression")
    func codexNoSubmitProofCandidatesBypassFinalLatencySuppression() throws {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: CodexProofFocusedTargetPolicy.bundleIdentifier))
        let field = FocusedFieldIdentity(
            bundleIdentifier: profile.bundleIdentifier,
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let classification = AXFieldClassification(kind: .multilineCompose, reason: "test-compose")
        let request = CompletionRequest(
            textBeforeCursor: "\(CodexProofFocusedTargetPolicy.marker) Can we make this dicta",
            appBundleIdentifier: profile.bundleIdentifier,
            fieldKind: classification.kind,
            behaviorProfileID: .aiChat,
            maxVisibleWords: 8,
            mode: .phraseContinuation,
            suggestionID: "codex-proof-late-final"
        )
        let signal = AcceptedAndKeptLearningStore().signal(
            for: acceptedAndKeptKey(
                request: request,
                fieldKind: classification.kind,
                profile: profile
            )
        )

        let display = orchestrator.displayScoreDecision(
            suggestion: CompletionSuggestion(text: " should feel instant without getting in the way", maxVisibleWords: 8),
            request: request,
            context: makeContext(textBeforeCursor: request.textBeforeCursor, textAfterCursor: ""),
            fieldClassification: classification,
            profile: profile,
            fieldIdentity: field,
            triggerReason: "model-result",
            latencyMilliseconds: 1_100,
            acceptedAndKeptSignal: signal,
            isRepeatedMiss: false,
            displayScorePolicy: DisplayScorePolicy()
        )

        #expect(display.decision.shouldDisplay)
        #expect(display.metadata["displayScoreSuppressionReason"] != "too-slow-to-display")
        #expect(display.metadata["displayScoreLatencySuppressionBypassed"] == "codex-proof-no-submit")
    }

    @MainActor
    @Test("Codex full-accept no-submit proof candidates bypass final latency suppression")
    func codexFullAcceptNoSubmitProofCandidatesBypassFinalLatencySuppression() throws {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let profile = try #require(
            CompatibilityProfileStore.mvp.profile(for: CodexProofFocusedTargetPolicy.bundleIdentifier)?
                .replacingAcceptanceProofMode(
                    supportsFullAcceptance: true,
                    requiresNoSubmitAcceptanceProof: false
                )
        )
        let field = FocusedFieldIdentity(
            bundleIdentifier: profile.bundleIdentifier,
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let classification = AXFieldClassification(kind: .multilineCompose, reason: "test-compose")
        let request = CompletionRequest(
            textBeforeCursor: "\(CodexProofFocusedTargetPolicy.marker) I think the next step should",
            appBundleIdentifier: profile.bundleIdentifier,
            fieldKind: classification.kind,
            behaviorProfileID: .aiChat,
            maxVisibleWords: 8,
            mode: .phraseContinuation,
            suggestionID: "codex-full-accept-proof-late-final"
        )
        let signal = AcceptedAndKeptLearningStore().signal(
            for: acceptedAndKeptKey(
                request: request,
                fieldKind: classification.kind,
                profile: profile
            )
        )

        let display = orchestrator.displayScoreDecision(
            suggestion: CompletionSuggestion(text: " land the proof before broadening the surface", maxVisibleWords: 8),
            request: request,
            context: makeContext(textBeforeCursor: request.textBeforeCursor, textAfterCursor: ""),
            fieldClassification: classification,
            profile: profile,
            fieldIdentity: field,
            triggerReason: "model-result",
            latencyMilliseconds: 1_100,
            acceptedAndKeptSignal: signal,
            isRepeatedMiss: false,
            displayScorePolicy: DisplayScorePolicy()
        )

        #expect(display.decision.shouldDisplay)
        #expect(display.metadata["displayScoreSuppressionReason"] != "too-slow-to-display")
        #expect(display.metadata["displayScoreLatencySuppressionBypassed"] == "codex-proof-no-submit")
    }

    @MainActor
    @Test("Claude Code terminal host proof candidates bypass final latency suppression")
    func claudeCodeTerminalHostProofCandidatesBypassFinalLatencySuppression() throws {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let profile = ClaudeCodeTerminalHostProofPolicy.proofProfile
        let field = FocusedFieldIdentity(
            bundleIdentifier: profile.bundleIdentifier,
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let classification = ClaudeCodeTerminalHostProofPolicy.proofFieldClassification
        let request = CompletionRequest(
            textBeforeCursor: "Make this setting the feature configurable",
            appBundleIdentifier: profile.bundleIdentifier,
            fieldKind: classification.kind,
            behaviorProfileID: .aiChat,
            maxVisibleWords: 8,
            mode: .phraseContinuation,
            suggestionID: "claude-code-terminal-proof-late-final"
        )
        let signal = AcceptedAndKeptLearningStore().signal(
            for: acceptedAndKeptKey(
                request: request,
                fieldKind: classification.kind,
                profile: profile
            )
        )

        let display = orchestrator.displayScoreDecision(
            suggestion: CompletionSuggestion(text: " should feel instant without getting in the way", maxVisibleWords: 8),
            request: request,
            context: makeContext(textBeforeCursor: request.textBeforeCursor, textAfterCursor: ""),
            fieldClassification: classification,
            profile: profile,
            fieldIdentity: field,
            triggerReason: "model-result",
            latencyMilliseconds: 1_600,
            acceptedAndKeptSignal: signal,
            isRepeatedMiss: false,
            displayScorePolicy: DisplayScorePolicy()
        )

        #expect(display.decision.shouldDisplay)
        #expect(display.metadata["displayScoreSuppressionReason"] != "too-slow-to-display")
        #expect(display.metadata["completionConfidenceReasons"]?.contains("too-slow-to-display") == true)
        #expect(display.metadata["displayScoreLatencySuppressionBypassed"] == "claude-code-terminal-host-proof")
    }

    @MainActor
    @Test("Late streaming partials are not hard suppressed by the final latency cutoff")
    func lateStreamingPartialsAreNotHardSuppressedByFinalLatencyCutoff() throws {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let field = FocusedFieldIdentity(
            bundleIdentifier: profile.bundleIdentifier,
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let classification = AXFieldClassification(kind: .multilineCompose, reason: "test-compose")
        let request = CompletionRequest(
            textBeforeCursor: "Can you send the notes",
            appBundleIdentifier: profile.bundleIdentifier,
            fieldKind: classification.kind,
            behaviorProfileID: .docsProse,
            maxVisibleWords: 4,
            mode: .phraseContinuation,
            suggestionID: "late-stream"
        )
        let signal = AcceptedAndKeptLearningStore().signal(
            for: acceptedAndKeptKey(
                request: request,
                fieldKind: classification.kind,
                profile: profile
            )
        )

        let display = orchestrator.displayScoreDecision(
            suggestion: CompletionSuggestion(text: " for the meeting", maxVisibleWords: 4),
            request: request,
            context: makeContext(textBeforeCursor: "Can you send the notes", textAfterCursor: ""),
            fieldClassification: classification,
            profile: profile,
            fieldIdentity: field,
            triggerReason: "model-stream",
            latencyMilliseconds: 900,
            acceptedAndKeptSignal: signal,
            isRepeatedMiss: false,
            displayScorePolicy: DisplayScorePolicy()
        )

        #expect(display.metadata["displayScoreSuppressionReason"] != "too-slow-to-display")
    }

    @MainActor
    @Test("Daily driver phrase results can display under the subsecond repair budget")
    func dailyDriverPhraseResultsCanDisplayUnderSubsecondRepairBudget() throws {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "md.obsidian"))
        let field = FocusedFieldIdentity(
            bundleIdentifier: profile.bundleIdentifier,
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let classification = AXFieldClassification(kind: .multilineCompose, reason: "test-compose")
        let request = CompletionRequest(
            textBeforeCursor: "Daily note We should probably",
            appBundleIdentifier: profile.bundleIdentifier,
            fieldKind: classification.kind,
            behaviorProfileID: .docsProse,
            maxVisibleWords: 8,
            mode: .phraseContinuation,
            suggestionID: "daily-driver-repair"
        )
        let signal = AcceptedAndKeptLearningStore().signal(
            for: acceptedAndKeptKey(
                request: request,
                fieldKind: classification.kind,
                profile: profile
            )
        )

        let display = orchestrator.displayScoreDecision(
            suggestion: CompletionSuggestion(text: " instant without getting in the way today now", maxVisibleWords: 8),
            request: request,
            context: makeContext(textBeforeCursor: request.textBeforeCursor, textAfterCursor: ""),
            fieldClassification: classification,
            profile: profile,
            fieldIdentity: field,
            triggerReason: "model-result",
            latencyMilliseconds: 900,
            acceptedAndKeptSignal: signal,
            isRepeatedMiss: false,
            displayScorePolicy: DisplayScorePolicy()
        )

        #expect(display.decision.shouldDisplay)
        #expect(display.metadata["displayScoreSuppressionReason"] != "too-slow-to-display")
        #expect(display.metadata["completionConfidenceReasons"]?.contains("too-slow-to-display") != true)
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
            textBeforeCursor: "Can we make this safer today"
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
            textBeforeCursor: "Can we make this safer today",
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
            context: makeContext(textBeforeCursor: "Can we make this safer today", textAfterCursor: ""),
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
        #expect(display.metadata["displayScoreThreshold"] == "1.28")

        orchestrator.resetPrefixFamilyCooldownPolicy(
            PrefixFamilyCooldownPolicy(traceFingerprintSecret: Data("unit-test-secret".utf8))
        )
        #expect(orchestrator.prefixCooldownDecision(for: input, now: now).canRequest)
    }

    @MainActor
    @Test("Display decision suppresses too-slow model results")
    func displayDecisionSuppressesTooSlowModelResults() throws {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.Notes"))
        let classification = AXFieldClassification(kind: .multilineCompose, reason: "test-compose")
        let request = CompletionRequest(
            textBeforeCursor: "This is enough context for",
            textAfterCursor: "",
            appBundleIdentifier: profile.bundleIdentifier,
            fieldKind: classification.kind,
            behaviorProfileID: .notes,
            maxVisibleWords: 4,
            mode: .phraseContinuation,
            suggestionID: "late"
        )
        let field = FocusedFieldIdentity(
            bundleIdentifier: profile.bundleIdentifier,
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let signal = AcceptedAndKeptLearningStore().signal(
            for: acceptedAndKeptKey(
                request: request,
                fieldKind: classification.kind,
                profile: profile
            )
        )

        let display = orchestrator.displayScoreDecision(
            suggestion: CompletionSuggestion(text: " a calmer start", maxVisibleWords: 4),
            request: request,
            context: makeContext(textBeforeCursor: request.textBeforeCursor, textAfterCursor: ""),
            fieldClassification: classification,
            profile: profile,
            fieldIdentity: field,
            triggerReason: "model-result",
            latencyMilliseconds: 900,
            acceptedAndKeptSignal: signal,
            isRepeatedMiss: false,
            displayScorePolicy: DisplayScorePolicy()
        )

        #expect(!display.decision.shouldDisplay)
        #expect(display.metadata["displayScoreSuppressionReason"] == "too-slow-to-display")
        #expect(display.metadata["completionConfidenceReasons"]?.contains("too-slow-to-display") == true)
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

        let invalidated = orchestrator.replacementDecision(
            currentVisibleText: " make this easier",
            proposedVisibleText: " ship the follow up",
            currentSuggestionID: "current",
            proposedSuggestionID: "proposed",
            currentPresentedAt: currentPresentedAt,
            currentScore: 1.00,
            proposedScore: 0.80,
            currentSuggestionInvalidatedByUserTyping: true,
            now: now
        )
        #expect(invalidated.shouldPresent)
        #expect(invalidated.reason == nil)
    }

    @MainActor
    @Test("Streaming partial pacing requires an active suggestion stream")
    func streamingPartialPacingRequiresActiveSuggestionStream() {
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
        #expect(!orchestrator.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " make this", maxVisibleWords: 3),
            suggestionID: "stream",
            mode: .phraseContinuation,
            nowMilliseconds: 300
        ))

        orchestrator.startStreamingPresentation(suggestionID: "stream")
        #expect(orchestrator.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " make this", maxVisibleWords: 3),
            suggestionID: "stream",
            mode: .phraseContinuation,
            nowMilliseconds: 320
        ))

        orchestrator.clearStreamingPresentations()
        #expect(!orchestrator.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " make this better", maxVisibleWords: 3),
            suggestionID: "stream",
            mode: .phraseContinuation,
            nowMilliseconds: 360
        ))
    }

    @MainActor
    @Test("Streaming partial metadata exposes first useful display latency")
    func streamingPartialMetadataExposesFirstUsefulDisplayLatency() {
        let orchestrator = SuggestionOrchestrator(
            engine: EchoCompletionEngine(),
            suggestionPresentationGate: SuggestionPresentationGate(
                minimumStreamingPhraseWords: 2,
                minimumStreamingPhraseCharacterDelta: 4,
                minimumStreamingIntervalMilliseconds: 0,
                maximumStreamingPartialPresentations: 2
            )
        )
        orchestrator.startStreamingPresentation(suggestionID: "stream")

        #expect(orchestrator.streamingPresentationMetadata(suggestionID: "stream").isEmpty)
        #expect(orchestrator.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " make this", maxVisibleWords: 3),
            suggestionID: "stream",
            mode: .phraseContinuation,
            nowMilliseconds: 100,
            latencyMilliseconds: 135
        ))

        let firstMetadata = orchestrator.streamingPresentationMetadata(suggestionID: "stream")
        #expect(firstMetadata["streamingPartialIndex"] == "1")
        #expect(firstMetadata["streamingFirstPartialLatencyMilliseconds"] == "135")
        #expect(firstMetadata["streamingLastPartialLatencyMilliseconds"] == "135")

        #expect(orchestrator.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " make this useful", maxVisibleWords: 3),
            suggestionID: "stream",
            mode: .phraseContinuation,
            nowMilliseconds: 120,
            latencyMilliseconds: 210
        ))

        let secondMetadata = orchestrator.streamingPresentationMetadata(suggestionID: "stream")
        #expect(secondMetadata["streamingPartialIndex"] == "2")
        #expect(secondMetadata["streamingFirstPartialLatencyMilliseconds"] == "135")
        #expect(secondMetadata["streamingLastPartialLatencyMilliseconds"] == "210")
    }

    @MainActor
    @Test("Beginning a new request clears older streaming state")
    func beginningNewRequestClearsOlderStreamingState() {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        orchestrator.startStreamingPresentation(suggestionID: "old-stream")

        #expect(orchestrator.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " make this", maxVisibleWords: 3),
            suggestionID: "old-stream",
            mode: .phraseContinuation,
            nowMilliseconds: 100
        ))

        _ = orchestrator.beginRequest(
            CompletionRequest(textBeforeCursor: "Can we make", suggestionID: "new-stream")
        )

        #expect(!orchestrator.shouldPresentStreamingPartial(
            CompletionSuggestion(text: " make this better", maxVisibleWords: 3),
            suggestionID: "old-stream",
            mode: .phraseContinuation,
            nowMilliseconds: 200
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
            windowTitle: "SteadyType Chrome Real Monaco Smoke",
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
    @Test("Codex full-accept proof profile keeps strict visual synthetic caret inline")
    func codexFullAcceptProofProfileKeepsStrictVisualSyntheticCaretInline() throws {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let codex = try #require(CompatibilityProfileStore.mvp.profile(for: CodexProofFocusedTargetPolicy.bundleIdentifier))
        let profile = codex.replacingAcceptanceProofMode(
            supportsFullAcceptance: true,
            requiresNoSubmitAcceptanceProof: false,
            notes: "\(codex.notes) Proof-only Codex full-accept no-submit scenario is active."
        )
        let learningAdjustment = CompatibilityLearningAdjustment(
            profile: nil,
            effectiveRenderMode: .inlineAdjacent
        )
        let context = makeContext(
            textBeforeCursor: "\(CodexProofFocusedTargetPolicy.marker) I think the next step should",
            textAfterCursor: "",
            windowTitle: "Codex",
            caretIsSynthetic: true
        )

        let plan = orchestrator.placementHealthPlan(
            context: context,
            profile: profile,
            learningAdjustment: learningAdjustment,
            screenshotTracingEnabled: true
        )

        guard case let .present(presentation) = plan else {
            Issue.record("Expected proof-mode Codex synthetic caret to stay inline")
            return
        }
        #expect(presentation.renderMode == .inlineAdjacent)
        #expect(presentation.anchorSource == .syntheticCaret)
        #expect(presentation.reason == .healthy)
    }

    @MainActor
    @Test("Placement suppression exposes command fallback metadata")
    func placementSuppressionExposesCommandFallbackMetadata() throws {
        let orchestrator = SuggestionOrchestrator(engine: EchoCompletionEngine())
        let chrome = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))
        let plan = PlacementHealthPlan.suppress(PlacementHealthSuppression(
            requestedRenderMode: .inlineAdjacent,
            reason: .lowConfidencePlacement
        ))

        let resolution = orchestrator.placementSuppressionResolution(
            for: plan,
            requestedRenderMode: .inlineAdjacent,
            profile: chrome,
            fieldKind: .multilineCompose
        )

        #expect(resolution.suppression.reason == .lowConfidencePlacement)
        #expect(resolution.commandFallbackDecision.availability == .copyOnly)
        #expect(resolution.metadata["commandFallback"] == "copy-only")
        #expect(resolution.metadata["commandFallbackReason"] == "untrusted-placement")
        #expect(resolution.fallbackSuffix == "; copy-only fallback available")
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
    @Test("Suggestion preserves twenty-word request through app orchestration")
    func suggestionPreservesTwentyWordRequestThroughAppOrchestration() async throws {
        let orchestrator = SuggestionOrchestrator(engine: FixedCompletionEngine(
            text: " one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty extra"
        ))
        let request = CompletionRequest(textBeforeCursor: "Can we", maxVisibleWords: 20)

        let suggestion = try await orchestrator.suggestion(for: request) { _ in }

        #expect(suggestion?.visibleWordCount == 20)
        #expect(suggestion?.visibleText.hasSuffix("nineteen twenty") == true)
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

private func testFieldIdentity(elementIdentifier: Int) -> FocusedFieldIdentity {
    FocusedFieldIdentity(
        bundleIdentifier: "com.example.editor",
        processIdentifier: 42,
        elementIdentifier: elementIdentifier
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
        windowIdentifier: 42,
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
