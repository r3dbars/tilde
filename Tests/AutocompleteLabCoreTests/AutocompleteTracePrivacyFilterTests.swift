import Testing
@testable import AutocompleteLabCore

@Suite("Autocomplete trace privacy filter")
struct AutocompleteTracePrivacyFilterTests {
    @Test("Redacts trace text unless raw content is enabled")
    func redactsTraceTextUnlessRawContentIsEnabled() {
        #expect(
            AutocompleteTracePrivacyFilter.textValue(
                "private draft text",
                rawContentEnabled: false
            ) == "String(18 chars)"
        )
        #expect(
            AutocompleteTracePrivacyFilter.textValue(
                "private draft text",
                rawContentEnabled: true
            ) == "private draft text"
        )
        #expect(
            AutocompleteTracePrivacyFilter.textValue(
                "",
                rawContentEnabled: false
            ) == ""
        )
    }

    @Test("Redacts sensitive trace metadata unless raw content is enabled")
    func redactsSensitiveTraceMetadataUnlessRawContentIsEnabled() {
        let metadata = [
            "typedSuffix": "private words",
            "visibleChars": "12",
            "hasCaretRect": "true",
            "traceProofVersion": AutocompleteTraceProofMetadata.traceProofVersion,
            "placementProofVersion": AutocompleteTraceProofMetadata.placementProofVersion
        ]

        #expect(AutocompleteTracePrivacyFilter.metadata(metadata, rawContentEnabled: false) == [
            "typedSuffix": "String(13 chars)",
            "visibleChars": "12",
            "hasCaretRect": "true",
            "traceProofVersion": AutocompleteTraceProofMetadata.traceProofVersion,
            "placementProofVersion": AutocompleteTraceProofMetadata.placementProofVersion
        ])
        #expect(AutocompleteTracePrivacyFilter.metadata(metadata, rawContentEnabled: true) == metadata)
    }

    @Test("Redacts freeform reason and outcome signals unless raw content is enabled")
    func redactsFreeformReasonAndOutcomeSignalsUnlessRawContentIsEnabled() {
        #expect(
            AutocompleteTracePrivacyFilter.traceSignalValue(
                "wrong-app-or-field-before-accept",
                rawContentEnabled: false
            ) == "wrong-app-or-field-before-accept"
        )
        #expect(
            AutocompleteTracePrivacyFilter.traceSignalValue(
                "private-draft-before",
                rawContentEnabled: false
            ) == DiagnosticValueRedactor.stringSummary(length: "private-draft-before".count)
        )
        #expect(
            AutocompleteTracePrivacyFilter.traceSignalValue(
                "private-draft-before",
                rawContentEnabled: true
            ) == "private-draft-before"
        )
    }

    @Test("Redacts freeform reason and outcome metadata by default")
    func redactsFreeformReasonAndOutcomeMetadataByDefault() {
        let metadata = [
            "fieldKindReason": "private-field-reason",
            "suppressionOutcome": "secret customer phrase",
            "finishReason": "thirty-second-finalized",
            "visibleChars": "12"
        ]

        let redacted = AutocompleteTracePrivacyFilter.metadata(metadata, rawContentEnabled: false)

        #expect(redacted["fieldKindReason"] == DiagnosticValueRedactor.stringSummary(length: "private-field-reason".count))
        #expect(redacted["suppressionOutcome"] == DiagnosticValueRedactor.stringSummary(length: "secret customer phrase".count))
        #expect(redacted["finishReason"] == "thirty-second-finalized")
        #expect(redacted["visibleChars"] == "12")
        #expect(AutocompleteTracePrivacyFilter.metadata(metadata, rawContentEnabled: true) == metadata)
    }
}
