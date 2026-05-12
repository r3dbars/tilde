import AppKit
import AutocompleteLabCore
import Testing
@testable import AutocompleteLabApp

@Suite("Codex proof focused target policy")
struct CodexProofFocusedTargetPolicyTests {
    private let policy = CodexProofFocusedTargetPolicy()

    @Test("Allows only the matching focused Codex proof field")
    func allowsMatchingFocusedCodexProofField() throws {
        let profile = try codexProfile()
        let app = codexApp()
        let fieldIdentity = identity()
        let snapshot = proofSnapshot(fieldIdentity: fieldIdentity)
        let context = focusedContext(textBeforeCursor: snapshot.textBeforeCursor)

        #expect(policy.matches(
            app: app,
            profile: profile,
            suggestionBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            requestMode: .wordCompletion,
            expectedFieldIdentity: fieldIdentity,
            snapshot: snapshot,
            focusedContext: context,
            focusedFieldIdentity: fieldIdentity,
            proofModeEnabled: true
        ))
    }

    @Test("Blocks a matching marker when another Codex field is focused")
    func blocksMatchingMarkerInWrongFocusedField() throws {
        let profile = try codexProfile()
        let app = codexApp()
        let fieldIdentity = identity()
        let otherFieldIdentity = identity(elementIdentifier: 99)
        let snapshot = proofSnapshot(fieldIdentity: fieldIdentity)
        let context = focusedContext(textBeforeCursor: snapshot.textBeforeCursor)

        #expect(!policy.matches(
            app: app,
            profile: profile,
            suggestionBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            requestMode: .wordCompletion,
            expectedFieldIdentity: fieldIdentity,
            snapshot: snapshot,
            focusedContext: context,
            focusedFieldIdentity: otherFieldIdentity,
            proofModeEnabled: true
        ))
    }

    @Test("Blocks proof insertion outside active proof mode")
    func blocksOutsideProofMode() throws {
        let profile = try codexProfile()
        let app = codexApp()
        let fieldIdentity = identity()
        let snapshot = proofSnapshot(fieldIdentity: fieldIdentity)
        let context = focusedContext(textBeforeCursor: snapshot.textBeforeCursor)

        #expect(!policy.matches(
            app: app,
            profile: profile,
            suggestionBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            requestMode: .wordCompletion,
            expectedFieldIdentity: fieldIdentity,
            snapshot: snapshot,
            focusedContext: context,
            focusedFieldIdentity: fieldIdentity,
            proofModeEnabled: false
        ))
    }

    @Test("Blocks when the focused text is not the shown proof snapshot")
    func blocksFocusedTextMismatch() throws {
        let profile = try codexProfile()
        let app = codexApp()
        let fieldIdentity = identity()
        let snapshot = proofSnapshot(fieldIdentity: fieldIdentity)
        let context = focusedContext(
            textBeforeCursor: "\(CodexProofFocusedTargetPolicy.marker) different prompt"
        )

        #expect(!policy.matches(
            app: app,
            profile: profile,
            suggestionBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            requestMode: .wordCompletion,
            expectedFieldIdentity: fieldIdentity,
            snapshot: snapshot,
            focusedContext: context,
            focusedFieldIdentity: fieldIdentity,
            proofModeEnabled: true
        ))
    }

    private func codexProfile() throws -> CompatibilityProfile {
        try #require(CompatibilityProfileStore.mvp.profile(for: CodexProofFocusedTargetPolicy.bundleIdentifier))
    }

    private func codexApp() -> RunningApplicationInfo {
        RunningApplicationInfo(
            bundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            localizedName: "Codex",
            processIdentifier: 42
        )
    }

    private func identity(elementIdentifier: Int = 7) -> FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            elementIdentifier: elementIdentifier
        )
    }

    private func proofSnapshot(fieldIdentity: FocusedFieldIdentity) -> FocusedTextSnapshot {
        FocusedTextSnapshot(
            fieldIdentity: fieldIdentity,
            textBeforeCursor: "\(CodexProofFocusedTargetPolicy.marker) write a tiny test",
            textAfterCursor: ""
        )
    }

    private func focusedContext(textBeforeCursor: String) -> FocusedTextContext {
        FocusedTextContext(
            elementIdentifier: 7,
            role: "AXTextArea",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(
                identifier: "prompt",
                title: "Codex",
                placeholder: "Ask Codex",
                windowTitle: "Codex"
            ),
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: "",
            selectedTextLength: 0,
            caretRect: CGRect(x: 20, y: 20, width: 1, height: 20),
            elementRect: CGRect(x: 10, y: 10, width: 700, height: 80),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 700),
            windowIdentifier: 1,
            textLineRect: nil,
            textStyle: nil,
            isSecure: false,
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
