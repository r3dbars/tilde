import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion silence explanation policy")
struct SuggestionSilenceExplanationPolicyTests {
    @Test("Explains blocked field kinds with user-facing safety reasons")
    func explainsBlockedFieldKinds() {
        let policy = SuggestionSilenceExplanationPolicy()

        #expect(policy.explanation(for: .blockedFieldKind, fieldKind: .search) == "search fields stay quiet")
        #expect(policy.explanation(for: .blockedFieldKind, fieldKind: .url) == "URL and address fields stay quiet")
        #expect(policy.explanation(for: .blockedFieldKind, fieldKind: .form) == "forms stay quiet")
        #expect(policy.explanation(for: .blockedFieldKind, fieldKind: .unprovenSurface) == "surface needs proof first")
        #expect(policy.explanation(for: .blockedFieldKind, fieldKind: .unknown) == "unknown field needs proof first")
    }

    @Test("Explains sensitive and manual suppression without raw text")
    func explainsSensitiveAndManualSuppression() {
        let policy = SuggestionSilenceExplanationPolicy()

        #expect(policy.explanation(for: .secureField, fieldKind: .secure) == "secure fields stay quiet")
        #expect(policy.explanation(for: .sensitiveContent, fieldKind: .multilineCompose) == "sensitive text detected")
        #expect(policy.explanation(for: .suppressedField, fieldKind: .multilineCompose) == "silenced until focus changes")
        #expect(policy.explanation(for: .selectedText, fieldKind: .multilineCompose) == "selected text is protected")
    }

    @Test("Explains timing blocks separately from safety blocks")
    func explainsTimingBlocks() {
        let policy = SuggestionSilenceExplanationPolicy()

        #expect(policy.explanation(for: .tooLittleContext, fieldKind: .multilineCompose) == "waiting for more context")
        #expect(policy.explanation(for: .unfinishedWord, fieldKind: .multilineCompose) == "word still forming")
        #expect(policy.explanation(for: .terminalSentenceBoundary, fieldKind: .multilineCompose) == "waiting for a new thought")
        #expect(policy.explanation(for: .middleOfLine, fieldKind: .multilineCompose) == "cursor is in existing text")
    }

    @Test("Only blocked activation decisions get an explanation")
    func onlyBlockedDecisionsGetExplanation() {
        let policy = SuggestionSilenceExplanationPolicy()

        #expect(policy.explanation(for: .allow(.phraseContinuation), fieldKind: .multilineCompose) == nil)
        #expect(
            policy.explanation(for: .block(.blockedFieldKind), fieldKind: .search)
                == "search fields stay quiet"
        )
    }
}
