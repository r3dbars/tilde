import Testing
@testable import AutocompleteLabCore

@Suite("Fast word completion coordinator")
struct FastWordCompletionCoordinatorTests {
    @Test("Phrase requests bypass fast word completion")
    func phraseRequestsBypassFastWordCompletion() {
        let coordinator = FastWordCompletionCoordinator()
        let request = CompletionRequest(
            textBeforeCursor: "writ",
            mode: .phraseContinuation
        )

        let plan = coordinator.plan(
            request: request,
            recentWords: ["writing"],
            repetitionSuppressor: SuggestionRepetitionSuppressor(),
            scope: "com.example.Editor"
        )

        #expect(plan == .notWordCompletion)
    }

    @Test("Recent word candidate is presented")
    func recentWordCandidateIsPresented() throws {
        let coordinator = FastWordCompletionCoordinator()
        let request = CompletionRequest(
            textBeforeCursor: "I am writ",
            mode: .wordCompletion
        )

        let plan = coordinator.plan(
            request: request,
            recentWords: ["writing"],
            repetitionSuppressor: SuggestionRepetitionSuppressor(),
            scope: "com.example.Editor"
        )

        guard case let .present(suggestion) = plan else {
            Issue.record("Expected present plan")
            return
        }
        #expect(suggestion.visibleText == "ing")
    }

    @Test("Repeated miss suppresses the candidate")
    func repeatedMissSuppressesCandidate() throws {
        let coordinator = FastWordCompletionCoordinator()
        var suppressor = SuggestionRepetitionSuppressor(missThreshold: 1)
        suppressor.recordMiss("ing", mode: .wordCompletion, scope: "com.example.Editor")
        let request = CompletionRequest(
            textBeforeCursor: "I am writ",
            mode: .wordCompletion
        )

        let plan = coordinator.plan(
            request: request,
            recentWords: ["writing"],
            repetitionSuppressor: suppressor,
            scope: "com.example.Editor"
        )

        guard case let .suppress(suppression) = plan else {
            Issue.record("Expected suppression plan")
            return
        }
        #expect(suppression.reason == .repeatedMiss)
        #expect(suppression.suggestion?.visibleText == "ing")
    }

    @Test("Missing candidate suppresses with no candidate reason")
    func missingCandidateSuppressesWithNoCandidateReason() throws {
        let coordinator = FastWordCompletionCoordinator()
        let request = CompletionRequest(
            textBeforeCursor: "I am zz",
            mode: .wordCompletion
        )

        let plan = coordinator.plan(
            request: request,
            recentWords: [],
            repetitionSuppressor: SuggestionRepetitionSuppressor(),
            scope: "com.example.Editor"
        )

        guard case let .suppress(suppression) = plan else {
            Issue.record("Expected suppression plan")
            return
        }
        #expect(suppression.reason == .noFastWordCandidate)
        #expect(suppression.suggestion == nil)
    }
}
