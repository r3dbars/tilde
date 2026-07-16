import CoreGraphics
import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Personalization coordinator")
struct PersonalizationCoordinatorTests {
    @MainActor
    @Test("Applies every gate and keeps retrieved context stable within a field")
    func gatesAndStabilizesFieldContext() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("PersonalizationCoordinatorTests-\(UUID().uuidString)")
        let indexURL = folder.appendingPathComponent("Index/personal-writing-memory.json")
        try FileManager.default.createDirectory(at: indexURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let memory = PersonalWritingMemory(
            snippets: [
                PersonalSnippet(text: "launch notes stay direct", tokens: ["launch", "notes", "stay", "direct"], appBundleIdentifier: "com.example.editor", dayString: "2026-07-01"),
                PersonalSnippet(text: "proof plans stay bounded", tokens: ["proof", "plans", "stay", "bounded"], appBundleIdentifier: "com.example.editor", dayString: "2026-07-01")
            ],
            profile: PersonalWritingProfile(promptGuidance: "Prefer direct phrasing."),
            tokenDocumentFrequency: ["launch": 1, "proof": 1],
            builtAtDay: "2026-07-15"
        )
        try JSONEncoder().encode(memory).write(to: indexURL)
        let indexer = PersonalWritingMemoryIndexer(personalCaptureFolderURL: folder)
        let coordinator = PersonalizationCoordinator(indexer: indexer)
        let classification = AXFieldClassification(kind: .multilineCompose, reason: "test")

        let first = coordinator.selection(
            isEnabled: true,
            context: context(text: "the launch", elementIdentifier: 7),
            appBundleIdentifier: "com.example.editor",
            fieldClassification: classification,
            requestMode: .phraseContinuation
        )
        let sameField = coordinator.selection(
            isEnabled: true,
            context: context(text: "the proof", elementIdentifier: 7),
            appBundleIdentifier: "com.example.editor",
            fieldClassification: classification,
            requestMode: .phraseContinuation
        )

        #expect(first.context?.snippets == ["launch notes stay direct"])
        #expect(sameField.context == first.context)

        try """
        # SteadyType Personal Capture

        ## 12:00:00 - Editor
        typed:
        ```text
        proof plans now refresh after indexing
        ```
        - App: `com.example.editor`
        - Kind: `multilineCompose`
        - Deleted chars: 0
        """.write(
            to: folder.appendingPathComponent("2026-07-14.md"),
            atomically: true,
            encoding: .utf8
        )
        indexer.rebuildAndWait()
        let refreshedSameField = coordinator.selection(
            isEnabled: true,
            context: context(text: "the proof", elementIdentifier: 7),
            appBundleIdentifier: "com.example.editor",
            fieldClassification: classification,
            requestMode: .phraseContinuation
        )
        #expect(refreshedSameField.context?.snippets == ["proof plans now refresh after indexing"])

        #expect(coordinator.selection(
            isEnabled: false,
            context: context(text: "the launch", elementIdentifier: 8),
            appBundleIdentifier: "com.example.editor",
            fieldClassification: classification,
            requestMode: .phraseContinuation
        ).context == nil)
        #expect(coordinator.selection(
            isEnabled: true,
            context: context(text: "the launch", elementIdentifier: 8),
            appBundleIdentifier: "com.example.editor",
            fieldClassification: classification,
            requestMode: .wordCompletion
        ).context == nil)
        #expect(coordinator.selection(
            isEnabled: true,
            context: context(text: "the launch", elementIdentifier: 8, isSecure: true),
            appBundleIdentifier: "com.example.editor",
            fieldClassification: classification,
            requestMode: .phraseContinuation
        ).context == nil)
    }

    private func context(text: String, elementIdentifier: Int, isSecure: Bool = false) -> FocusedTextContext {
        FocusedTextContext(
            elementIdentifier: elementIdentifier,
            role: "AXTextArea",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(),
            textBeforeCursor: text,
            textAfterCursor: "",
            selectedTextLength: 0,
            caretRect: CGRect(x: 10, y: 10, width: 1, height: 18),
            elementRect: CGRect(x: 0, y: 0, width: 400, height: 200),
            windowRect: CGRect(x: 0, y: 0, width: 500, height: 300),
            windowIdentifier: 42,
            textLineRect: CGRect(x: 10, y: 10, width: 120, height: 18),
            textStyle: nil,
            isSecure: isSecure,
            caretIsSynthetic: false,
            capabilities: FocusedTextCapabilities(
                canReadValue: true,
                canReadSelectedTextRange: true,
                canReadBoundsForRange: true,
                canReadAttributedText: false,
                canSetSelectedText: true
            )
        )
    }
}
