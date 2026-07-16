import Testing
@testable import AutocompleteLabCore

@Suite("Personal writing memory retrieval")
struct PersonalWritingMemoryRetrievalTests {
    @Test("Ranks rare overlap and same app without tracing text")
    func ranksRelevantSnippets() throws {
        let memory = PersonalWritingMemory(
            snippets: [
                snippet("The launch checklist needs a focused owner", app: "com.apple.Notes"),
                snippet("The launch checklist needs a broad review", app: "other.app"),
                snippet("Dinner plans can wait until tomorrow", app: "com.apple.Notes")
            ],
            profile: PersonalWritingProfile(sampleCount: 3, promptGuidance: "Keep the phrasing direct."),
            tokenDocumentFrequency: ["launch": 2, "checklist": 2, "focused": 1],
            builtAtDay: "2026-07-15"
        )
        let context = try #require(memory.personalContext(for: PersonalContextQuery(
            textBeforeCursor: "The focused launch checklist",
            appBundleIdentifier: "com.apple.Notes"
        )))

        #expect(context.snippets.first == "The launch checklist needs a focused owner")
        #expect(context.snippets.count == 2)
        #expect(context.traceMetadata["personalContextSnippetCount"] == "2")
        #expect(!context.traceMetadata.description.contains("launch checklist"))
    }

    @Test("Caps snippets and joint characters")
    func capsContext() throws {
        let long = String(repeating: "relevant ", count: 40)
        let memory = PersonalWritingMemory(
            snippets: (0..<6).map { snippet("\(long)\($0)", app: "app") },
            builtAtDay: "2026-07-15"
        )
        let context = try #require(memory.personalContext(for: PersonalContextQuery(textBeforeCursor: "relevant", maximumSnippets: 3)))
        #expect(context.snippets.count <= 3)
        #expect(context.snippets.reduce(0) { $0 + $1.count } <= 400)
    }

    @Test("Empty memory returns nil")
    func emptyReturnsNil() {
        let memory = PersonalWritingMemory(builtAtDay: "2026-07-15")
        #expect(memory.personalContext(for: PersonalContextQuery(textBeforeCursor: "anything")) == nil)
    }

    private func snippet(_ text: String, app: String) -> PersonalSnippet {
        PersonalSnippet(
            text: text,
            tokens: Set(PersonalWritingMemory.normalizedWords(in: text)),
            appBundleIdentifier: app,
            dayString: "2026-07-15"
        )
    }
}
