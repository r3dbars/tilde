import AutocompleteLabCore
import CoreGraphics
import Foundation
import Testing
@testable import AutocompleteLabApp

@MainActor
@Suite("Suggestion request preparation host")
struct SuggestionRequestPreparationHostTests {
    @Test("Assembles a request and keeps the instant-word latency contract")
    func assemblesInstantWordRequest() throws {
        let host = makeHost()
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let field = FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            elementIdentifier: 7
        )

        let preparation = host.prepare(
            context: makeContext(),
            profile: profile,
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: field,
            fieldClassification: AXFieldClassification(kind: .singlelineCompose, reason: "test"),
            renderMode: .inlineAdjacent,
            delayMilliseconds: 500,
            timingLane: .instantWord,
            requestMode: .wordCompletion,
            typingBurstDecision: .idle,
            visiblePageContext: nil,
            triggerReason: "test"
        )

        #expect(preparation.orchestration.request.mode == .wordCompletion)
        #expect(preparation.orchestration.request.appBundleIdentifier == "com.apple.TextEdit")
        #expect(preparation.orchestration.request.maxVisibleWords == 3)
        #expect(preparation.requestSchedule.scheduledDelayMilliseconds == 0)
        #expect(preparation.requestSchedule.resultLatencyBudgetMilliseconds == 1_200)
        #expect(preparation.requestMetadata["suggestionTimingLane"] == "instantWord")
    }

    @Test("Uses the floating presentation floor for delayed continuation requests")
    func assemblesFloatingContinuationRequest() throws {
        let host = makeHost()
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let field = FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            elementIdentifier: 7
        )

        let preparation = host.prepare(
            context: makeContext(),
            profile: profile,
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: field,
            fieldClassification: AXFieldClassification(kind: .multilineCompose, reason: "test"),
            renderMode: .floatingMirror,
            delayMilliseconds: 0,
            timingLane: .pausePhrase,
            requestMode: .phraseContinuation,
            typingBurstDecision: .burst(insertedCharacterCount: 2, eventCount: 2),
            visiblePageContext: nil,
            triggerReason: "test"
        )

        #expect(preparation.requestSchedule.scheduledDelayMilliseconds == 60)
        #expect(preparation.requestSchedule.resultLatencyBudgetMilliseconds == 2_000)
        #expect(preparation.requestMetadata["suggestionTimingLane"] == "pausePhrase")
    }

    @Test("AppDelegate delegates request preparation and retains only downstream setup")
    func appDelegateUsesPreparationHost() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let source = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )

        #expect(source.contains("private lazy var suggestionRequestPreparationHost"))
        #expect(source.contains("suggestionRequestPreparationHost.prepare("))
        #expect(!source.contains("let acceptedTextStyleKey = suggestionOrchestrator.acceptedTextStyleKey("))
    }

    private func makeHost() -> SuggestionRequestPreparationHost {
        let orchestrator = SuggestionOrchestrator(engine: PreparationTestCompletionEngine())
        return SuggestionRequestPreparationHost(
            dependencies: SuggestionRequestPreparationHostDependencies(
                suggestionOrchestrator: orchestrator,
                acceptedTextStyleSketch: { _ in nil },
                personalizationCoordinator: PersonalizationCoordinator(),
                isPersonalCaptureEnabled: { false },
                maxVisibleWords: { requestMode, _ in
                    requestMode == .wordCompletion ? 3 : 5
                },
                suggestionTuning: { SuggestionTuning() },
                triggerTiming: SuggestionTriggerTimingPolicy()
            )
        )
    }

    private func makeContext() -> FocusedTextContext {
        FocusedTextContext(
            elementIdentifier: 7,
            role: "AXTextArea",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(windowTitle: "Test"),
            textBeforeCursor: "draft",
            textAfterCursor: "",
            selectedTextLength: 0,
            caretRect: CGRect(x: 10, y: 10, width: 1, height: 18),
            elementRect: CGRect(x: 0, y: 0, width: 500, height: 300),
            windowRect: CGRect(x: 0, y: 0, width: 600, height: 400),
            windowIdentifier: 42,
            textLineRect: CGRect(x: 10, y: 10, width: 140, height: 18),
            textStyle: nil,
            isSecure: false,
            fieldClassification: AXFieldClassification(kind: .singlelineCompose, reason: "test"),
            caretIsSynthetic: false,
            capabilities: FocusedTextCapabilities(
                canReadValue: true,
                canReadSelectedTextRange: true,
                canReadBoundsForRange: true,
                canReadAttributedText: false,
                canSetSelectedText: true
            )
        )
    }
}

private struct PreparationTestCompletionEngine: CompletionEngine {
    func suggestion(for request: CompletionRequest) async throws -> CompletionSuggestion? {
        nil
    }
}
