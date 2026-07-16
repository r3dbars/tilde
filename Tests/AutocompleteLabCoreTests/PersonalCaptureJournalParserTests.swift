import Testing
@testable import AutocompleteLabCore

@Suite("Personal capture journal parser")
struct PersonalCaptureJournalParserTests {
    private let parser = PersonalCaptureJournalParser()

    @Test("Parses typed and replaced entries with writer metadata")
    func parsesTypedAndReplaced() throws {
        let entries = parser.entries(inDailyMarkdown: """
        # SteadyType Personal Capture - 2026-07-15

        ## 09:10:11 - Notes

        typed or replaced:

        ```text
        ship the focused proof today
        ```

        - App: `com.apple.Notes`
        - Field: `field-1`
        - Kind: `multilineCompose` (`role`)
        - Deleted chars: 4
        - Source: `poll`
        """, dayString: "2026-07-15")

        let entry = try #require(entries.first)
        #expect(entry.kind == .typed)
        #expect(entry.text == "ship the focused proof today")
        #expect(entry.appBundleIdentifier == "com.apple.Notes")
        #expect(entry.fieldKind == .multilineCompose)
        #expect(entry.deletedCharacterCount == 4)
    }

    @Test("Matches variable fence length around backticks in content")
    func matchesVariableFenceLength() throws {
        let entries = parser.entries(inDailyMarkdown: """
        ## 10:11:12 - Notes

        typed:

        `````text
        explain the ```code``` block clearly
        `````

        - App: `com.apple.Notes`
        - Kind: `multilineCompose`
        - Deleted chars: 0
        """, dayString: "2026-07-15")

        #expect(try #require(entries.first).text == "explain the ```code``` block clearly")
    }

    @Test("Parses accepted survival and observed sections")
    func parsesOtherKinds() {
        let markdown = """
        ## 11:00:00 - SteadyType accepted

        Accepted suggestion:

        ```text
        keep the change small
        ```

        - App: `com.apple.Notes`
        - Kind: `multilineCompose`

        ## 11:01:00 - SteadyType survival signal

        Accepted text:

        ```text
        keep the change small
        ```

        - App: `com.apple.Notes`
        - Kind: `multilineCompose`

        ## 11:02:00 - Notes

        Field observed for personal capture. New writing will be logged after this point.

        - App: `com.apple.Notes`
        - Kind: `multilineCompose`
        """
        let entries = parser.entries(inDailyMarkdown: markdown, dayString: "2026-07-15")

        #expect(entries.map(\.kind) == [.accepted, .survival, .fieldObserved])
        #expect(entries.last?.text == "")
    }

    @Test("Skips malformed sections without losing valid neighbors")
    func skipsMalformedSections() {
        let markdown = """
        ## nope - Broken
        typed:
        ```text
        ignored malformed section
        ```

        ## 12:00:00 - Notes
        typed:
        ```text
        valid writing remains here
        ```
        - App: `com.apple.Notes`
        - Kind: `multilineCompose`
        """
        let entries = parser.entries(inDailyMarkdown: markdown, dayString: "2026-07-15")
        #expect(entries.count == 1)
        #expect(entries.first?.text == "valid writing remains here")
    }
}
