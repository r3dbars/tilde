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

    @Test("Trace metadata includes partial word shape only")
    func traceMetadataIncludesPartialWordShapeOnly() {
        let request = CompletionRequest(textBeforeCursor: "Please open Transcrip")
        let metadata = request.behaviorProfileTraceMetadata

        #expect(metadata["partialWordCharacters"] == "9")
        #expect(metadata["partialWordLetters"] == "9")
        #expect(metadata["partialWordCasing"] == "titlecase")
        #expect(!metadata.values.joined(separator: " ").contains("Transcrip"))
    }

    @Test("Trace metadata includes current line structure only")
    func traceMetadataIncludesCurrentLineStructureOnly() {
        let request = CompletionRequest(textBeforeCursor: "Plan\n- [ ] Follow u")
        let metadata = request.behaviorProfileTraceMetadata

        #expect(request.behaviorProfile.id == .bullets)
        #expect(metadata["currentLineStructure"] == "checklist_unchecked")
        #expect(metadata["currentLineMarkerStyle"] == "dash")
        #expect(metadata["currentLineIndentationColumns"] == "0")
        #expect(metadata["currentLineContentWords"] == "2")
        #expect(!metadata.values.joined(separator: " ").contains("Follow"))
    }
}
