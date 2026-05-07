import Testing
@testable import AutocompleteLabCore

@Suite("Completion request")
struct CompletionRequestTests {
    @Test("Behavior profile metadata includes request field kind")
    func behaviorProfileMetadataIncludesRequestFieldKind() {
        let request = CompletionRequest(
            textBeforeCursor: "Search",
            appBundleIdentifier: "com.apple.Notes",
            fieldKind: .search
        )

        #expect(request.behaviorProfile.id == .search)
        #expect(request.behaviorProfileTraceMetadata["behaviorProfile"] == "search")
        #expect(request.behaviorProfileTraceMetadata["behaviorProfileMaxVisibleWords"] == "1")
        #expect(request.behaviorProfileTraceMetadata["behaviorProfileSuppressedByDefault"] == "true")
        #expect(request.behaviorProfileTraceMetadata["requestFieldKind"] == "search")
    }

    @Test("Explicit behavior profile overrides app and field defaults")
    func explicitBehaviorProfileOverridesAppAndFieldDefaults() {
        let request = CompletionRequest(
            textBeforeCursor: "I wanted to",
            appBundleIdentifier: "com.apple.Notes",
            fieldKind: .multilineCompose,
            behaviorProfileID: .aiChat
        )

        #expect(request.behaviorProfile.id == .aiChat)
        #expect(request.behaviorProfileTraceMetadata["behaviorProfile"] == "ai_chat")
        #expect(request.behaviorProfileTraceMetadata["requestFieldKind"] == "multilineCompose")
    }
}
