import Testing
@testable import AutocompleteLabCore

@Suite("Dynamic few-shot source")
struct DynamicFewShotSourceTests {
    @Test("Builds bounded completion examples from personal snippets")
    func buildsExamplesFromPersonalSnippets() {
        let context = PersonalContext(snippets: [
            "Keep the release note short direct and easy to scan",
            "Too short",
            "Run the exact local proof before changing anything else today"
        ])

        let examples = DynamicFewShotSource(maximumExamples: 2).examples(from: context)

        #expect(examples == [
            #""Keep the release note short direct and" -> "easy to scan""#,
            #""Run the exact local proof before changing" -> "anything else today""#
        ])
    }

    @Test("Does not create examples without opted-in personal context")
    func requiresPersonalContext() {
        #expect(DynamicFewShotSource().examples(from: nil).isEmpty)
    }
}
