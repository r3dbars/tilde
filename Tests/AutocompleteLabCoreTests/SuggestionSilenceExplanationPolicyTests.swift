import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion silence explanation policy")
struct SuggestionSilenceExplanationPolicyTests {
    private let policy = SuggestionSilenceExplanationPolicy()

    @Test("Explains blocked field kinds in plain user language")
    func explainsBlockedFieldKindsInPlainUserLanguage() {
        let cases: [(AXFieldKind, String)] = [
            (.search, "search fields stay quiet"),
            (.url, "URL and address fields stay quiet"),
            (.form, "forms stay quiet"),
            (.secure, "secure field"),
            (.unprovenSurface, "surface needs proof first"),
            (.unknown, "unknown field needs proof first")
        ]

        for (fieldKind, expected) in cases {
            #expect(policy.activationBlockReason(.blockedFieldKind, fieldKind: fieldKind) == expected)
        }
    }

    @Test("Keeps timing and authorship blocks calm")
    func keepsTimingAndAuthorshipBlocksCalm() {
        #expect(policy.activationBlockReason(.tooLittleContext, fieldKind: .multilineCompose) == "waiting for more context")
        #expect(policy.activationBlockReason(.unfinishedWord, fieldKind: .multilineCompose) == "word still forming")
        #expect(policy.activationBlockReason(.middleOfLine, fieldKind: .multilineCompose) == "middle of line stays quiet")
        #expect(policy.activationBlockReason(.selectedText, fieldKind: .multilineCompose) == "selected text stays quiet")
    }

    @Test("Separates secure and missing editable context")
    func separatesSecureAndMissingEditableContext() {
        #expect(policy.focusedTextUnavailable(isSecure: true) == "secure field")
        #expect(policy.focusedTextUnavailable(isSecure: false) == "no editable text field")
    }
}
