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

    @Test("Maps no-show decisions to one trace-safe reason code")
    func mapsNoShowDecisionsToOneTraceSafeReasonCode() {
        let cases: [(String, [String: String], String, SuggestionSilenceReasonCode)] = [
            (
                "too-slow-to-display",
                ["displayScoreSuppressionReason": "too-slow-to-display"],
                "model-result",
                .latency
            ),
            (
                "low-confidence",
                ["displayScoreSuppressionReason": "low-confidence"],
                "model-result",
                .confidence
            ),
            (
                "below-threshold",
                ["displayScoreSuppressionReason": "below-threshold"],
                "model-result",
                .displayScore
            ),
            (
                "learned-restraint",
                ["displayScoreSuppressionReason": "learned-restraint"],
                "model-result",
                .learnedRestraint
            ),
            ("repeated-miss", [:], "model-result", .repetition),
            ("typedOver", ["prefixCooldownReason": "typedOver"], "prefix-family-cooldown", .prefixCooldown),
            ("quiet-mode-field", ["quietMode": "field"], "annoyance-quiet-mode", .quietMode),
            ("fast-phrase-learning-restraint", [:], "canned-bridge", .learnedRestraint),
            ("secureField", [:], "activation-policy", .safety)
        ]

        for (reason, metadata, triggerReason, expectedCode) in cases {
            let traceMetadata = policy.traceMetadata(
                forTraceReason: reason,
                metadata: metadata,
                triggerReason: triggerReason
            )

            #expect(policy.reasonCode(
                forTraceReason: reason,
                metadata: metadata,
                triggerReason: triggerReason
            ) == expectedCode)
            #expect(traceMetadata == [
                SuggestionSilenceExplanationPolicy.traceReasonCodeMetadataKey: expectedCode.rawValue
            ])
        }
    }

    @Test("Reason code copy stays plain")
    func reasonCodeCopyStaysPlain() {
        #expect(SuggestionSilenceReasonCode.latency.userFacingReason == "too slow")
        #expect(SuggestionSilenceReasonCode.prefixCooldown.userFacingReason == "recent prefix cooldown")
        #expect(SuggestionSilenceReasonCode.quietMode.userFacingReason == "quiet mode")
        #expect(SuggestionSilenceReasonCode.learnedRestraint.userFacingReason == "recent rejects")
        #expect(SuggestionSilenceReasonCode.safety.userFacingReason == "safety gate")
    }
}
