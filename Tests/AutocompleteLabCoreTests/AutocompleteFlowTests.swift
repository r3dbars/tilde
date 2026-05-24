import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Autocomplete flow")
struct AutocompleteFlowTests {
    @Test("Mock engine suggestion can be accepted word by word")
    func mockSuggestionCanBeAcceptedWordByWord() async throws {
        let engine = MockCompletionEngine()
        let suggestion = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "I think", maxVisibleWords: 8)
        )

        var session = SuggestionSession(visibleSuggestion: suggestion)

        let nextWord = session.nextWordAcceptance()
        #expect(nextWord == " we ")
        #expect(session.visibleSuggestion?.visibleText == " we should ship this")
        session.commitNextWordAcceptance(nextWord ?? "")

        let remaining = session.allVisibleAcceptance()
        #expect(remaining == "should ship this")
        session.commitAllVisibleAcceptance(remaining ?? "")
        #expect(!session.hasVisibleSuggestion)
    }

    @Test("Raw model output is cleaned before showing")
    func rawModelOutputIsCleanedBeforeShowing() {
        let cleaner = CompletionOutputCleaner(maxVisibleWords: 4)
        let suggestion = cleaner.clean("<think>long reasoning</think>make it feel instant")

        var session = SuggestionSession(visibleSuggestion: suggestion)

        #expect(session.acceptAllVisible() == " make it feel instant")
        #expect(!session.hasVisibleSuggestion)
    }

    @Test("Mock engine avoids repeating the word the user just typed")
    func mockSuggestionAvoidsRepeatingLastTypedWord() async throws {
        let engine = MockCompletionEngine()
        let suggestion = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "Hey and", maxVisibleWords: 8)
        )

        #expect(suggestion?.visibleText == " keep moving")
    }

    @Test("Mock engine completes only the missing part of a typed word")
    func mockSuggestionCompletesMissingWordSuffix() async throws {
        let engine = MockCompletionEngine()
        let suggestion = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "Hey a", maxVisibleWords: 8)
        )

        #expect(suggestion?.visibleText == "nd keep moving")
    }

    @Test("Word completion mode completes only the current word")
    func wordCompletionModeCompletesOnlyCurrentWord() async throws {
        let engine = MockCompletionEngine()
        let suggestion = try await engine.suggestion(
            for: CompletionRequest(textBeforeCursor: "dic", maxVisibleWords: 8, mode: .wordCompletion)
        )

        #expect(suggestion?.visibleText == "tation")
    }

    @Test("Typed-over rejection starts a same-prefix cooldown")
    func typedOverRejectionStartsSamePrefixCooldown() {
        let originalText = "Can we make this feel "
        let displayedText = "native"
        let newText = "Can we make this feel rough"
        let progress = SuggestionTypingProgressPolicy().progress(
            originalTextBeforeCursor: originalText,
            displayedText: displayedText,
            newTextBeforeCursor: newText
        )

        guard case let .typedOver(typedSuffix) = progress else {
            Issue.record("Expected typed-over progress, got \(progress)")
            return
        }
        #expect(typedSuffix == "rough")

        let now = Date(timeIntervalSince1970: 1_000)
        let input = PrefixFamilyCooldownInput(
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentifier: "field:body",
            requestMode: .phraseContinuation,
            textBeforeCursor: originalText
        )
        var cooldownPolicy = PrefixFamilyCooldownPolicy()
        let cooldown = cooldownPolicy.record(.typedOver, input: input, now: now)

        #expect(cooldown?.reason == .typedOver)
        #expect(cooldown?.durationMilliseconds == 2_500)
        #expect(cooldownPolicy.decision(for: input, now: now.addingTimeInterval(0.5)).canRequest == false)
        #expect(cooldownPolicy.decision(for: input, now: now.addingTimeInterval(2.4)).canRequest == false)
        #expect(cooldownPolicy.decision(for: input, now: now.addingTimeInterval(2.6)).canRequest == true)

        let differentField = PrefixFamilyCooldownInput(
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentifier: "field:title",
            requestMode: .phraseContinuation,
            textBeforeCursor: originalText
        )
        #expect(cooldownPolicy.decision(for: differentField, now: now.addingTimeInterval(0.5)).canRequest)
    }
}
