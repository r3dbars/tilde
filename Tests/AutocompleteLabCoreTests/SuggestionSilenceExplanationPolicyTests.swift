import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion silence explanation policy")
struct SuggestionSilenceExplanationPolicyTests {
    private let policy = SuggestionSilenceExplanationPolicy()

    @Test("Explains blocked field kinds in plain user language")
    func explainsBlockedFieldKinds() {
        let cases: [(AXFieldKind, String)] = [
            (.search, "search fields stay quiet"),
            (.url, "URL and address fields stay quiet"),
            (.form, "forms stay quiet"),
            (.secure, "secure field"),
            (.unprovenSurface, "surface needs proof first"),
            (.unknown, "unknown field needs proof first")
        ]

        for (kind, expectedReason) in cases {
            let decision = CompletionActivationDecision.block(.blockedFieldKind)
            let classification = AXFieldClassification(kind: kind, reason: "test")

            #expect(policy.activationBlockReason(
                for: decision,
                fieldClassification: classification
            ) == expectedReason)
        }
    }

    @Test("Keeps timing and authorship blocks calm")
    func explainsTimingAndAuthorshipBlocks() {
        let classification = AXFieldClassification(kind: .multilineCompose, reason: "test")

        #expect(policy.activationBlockReason(
            .tooLittleContext,
            fieldClassification: classification
        ) == "waiting for more context")
        #expect(policy.activationBlockReason(
            .unfinishedWord,
            fieldClassification: classification
        ) == "word still forming")
        #expect(policy.activationBlockReason(
            .middleOfLine,
            fieldClassification: classification
        ) == "middle of line")
        #expect(policy.activationBlockReason(
            .selectedText,
            fieldClassification: classification
        ) == "selected text active")
    }

    @Test("Separates sensitive and code silence reasons")
    func separatesSensitiveAndCodeReasons() {
        let classification = AXFieldClassification(kind: .multilineCompose, reason: "test")

        #expect(policy.activationBlockReason(
            .secureField,
            fieldClassification: classification
        ) == "secure field")
        #expect(policy.activationBlockReason(
            .sensitiveContent,
            fieldClassification: classification
        ) == "sensitive text detected")
        #expect(policy.activationBlockReason(
            .markdownCodeContext,
            fieldClassification: classification
        ) == "code context")
    }
}
