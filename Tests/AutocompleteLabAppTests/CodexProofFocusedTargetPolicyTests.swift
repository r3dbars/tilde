import AppKit
import AutocompleteLabCore
import Testing
@testable import AutocompleteLabApp
@testable import AutocompleteLabResearch

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

    @Test("Allows phrase continuation suggestions for one-word Codex proof accept")
    func allowsPhraseContinuationForOneWordCodexProofAccept() throws {
        let profile = try codexProfile()
        let app = codexApp()
        let fieldIdentity = identity()
        let snapshot = proofSnapshot(fieldIdentity: fieldIdentity)
        let context = focusedContext(textBeforeCursor: snapshot.textBeforeCursor)

        #expect(policy.matches(
            app: app,
            profile: profile,
            suggestionBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            requestMode: .phraseContinuation,
            expectedFieldIdentity: fieldIdentity,
            snapshot: snapshot,
            focusedContext: context,
            focusedFieldIdentity: fieldIdentity,
            proofModeEnabled: true
        ))
    }

    @Test("Allows proof-only full accept profile for matching Codex prompt")
    func allowsProofOnlyFullAcceptProfileForMatchingCodexPrompt() throws {
        let profile = try codexProfile().replacingAcceptanceProofMode(
            supportsFullAcceptance: true,
            requiresNoSubmitAcceptanceProof: false
        )
        let app = codexApp()
        let fieldIdentity = identity()
        let snapshot = proofSnapshot(fieldIdentity: fieldIdentity)
        let context = focusedContext(textBeforeCursor: snapshot.textBeforeCursor)

        #expect(policy.matches(
            app: app,
            profile: profile,
            suggestionBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            requestMode: .phraseContinuation,
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

    @Test("Allows exact proof text when Codex AX identity churns but target geometry matches")
    func allowsExactProofTextWhenAXIdentityChurnsWithMatchingTargetGeometry() throws {
        let profile = try codexProfile()
        let app = codexApp()
        let fieldIdentity = identity()
        let churnedFieldIdentity = identity(elementIdentifier: 99)
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
            focusedFieldIdentity: churnedFieldIdentity,
            proofModeEnabled: true,
            shownTargetFingerprint: targetFingerprint(for: context)
        ))
    }

    @Test("Allows exact proof text when Codex fills missing AX metadata before accept")
    func allowsExactProofTextWhenMissingAXMetadataBecomesAvailable() throws {
        let profile = try codexProfile()
        let app = codexApp()
        let fieldIdentity = identity()
        let churnedFieldIdentity = identity(elementIdentifier: 99)
        let snapshot = proofSnapshot(fieldIdentity: fieldIdentity)
        let context = focusedContext(textBeforeCursor: snapshot.textBeforeCursor)
        let sparseShownTarget = FocusedTargetFingerprint(
            role: context.role,
            subrole: context.subrole,
            elementFingerprint: FocusedElementFingerprint(),
            windowIdentifier: nil,
            elementRect: context.elementRect,
            windowRect: nil,
            caretRect: context.caretRect,
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor
        )

        #expect(policy.matches(
            app: app,
            profile: profile,
            suggestionBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            requestMode: .wordCompletion,
            expectedFieldIdentity: fieldIdentity,
            snapshot: snapshot,
            focusedContext: context,
            focusedFieldIdentity: churnedFieldIdentity,
            proofModeEnabled: true,
            shownTargetFingerprint: sparseShownTarget
        ))
    }

    @Test("Blocks Codex AX identity churn when the proof target geometry moved")
    func blocksAXIdentityChurnWhenTargetGeometryMoved() throws {
        let profile = try codexProfile()
        let app = codexApp()
        let fieldIdentity = identity()
        let churnedFieldIdentity = identity(elementIdentifier: 99)
        let snapshot = proofSnapshot(fieldIdentity: fieldIdentity)
        let shownContext = focusedContext(textBeforeCursor: snapshot.textBeforeCursor)
        let movedContext = focusedContext(
            textBeforeCursor: snapshot.textBeforeCursor,
            elementRect: CGRect(x: 36, y: 10, width: 700, height: 80)
        )

        #expect(!policy.matches(
            app: app,
            profile: profile,
            suggestionBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            requestMode: .wordCompletion,
            expectedFieldIdentity: fieldIdentity,
            snapshot: snapshot,
            focusedContext: movedContext,
            focusedFieldIdentity: churnedFieldIdentity,
            proofModeEnabled: true,
            shownTargetFingerprint: targetFingerprint(for: shownContext)
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

    private func codexApp() -> ProofRunningApplicationInfo {
        ProofRunningApplicationInfo(
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

    private func focusedContext(
        textBeforeCursor: String,
        elementRect: CGRect? = CGRect(x: 10, y: 10, width: 700, height: 80)
    ) -> ProofFocusedTextContext {
        ProofFocusedTextContext(
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
            elementRect: elementRect,
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 700),
            windowIdentifier: 1,
            isSecure: false
        )
    }

    private func targetFingerprint(for context: ProofFocusedTextContext) -> FocusedTargetFingerprint {
        FocusedTargetFingerprint(
            role: context.role,
            subrole: context.subrole,
            elementFingerprint: context.fingerprint,
            windowIdentifier: context.windowIdentifier,
            elementRect: context.elementRect,
            windowRect: context.windowRect,
            caretRect: context.caretRect,
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor
        )
    }
}
