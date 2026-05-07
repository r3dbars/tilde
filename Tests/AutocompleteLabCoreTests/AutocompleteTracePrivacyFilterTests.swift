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
            "hasCaretRect": "true"
        ]

        #expect(AutocompleteTracePrivacyFilter.metadata(metadata, rawContentEnabled: false) == [
            "typedSuffix": "String(13 chars)",
            "visibleChars": "12",
            "hasCaretRect": "true"
        ])
        #expect(AutocompleteTracePrivacyFilter.metadata(metadata, rawContentEnabled: true) == metadata)
    }
}
