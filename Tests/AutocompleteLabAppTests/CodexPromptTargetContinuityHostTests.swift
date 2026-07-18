import AutocompleteLabCore
import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Codex prompt target continuity host")
struct CodexPromptTargetContinuityHostTests {
    @Test("Host owns and clears the transient continuity state")
    @MainActor
    func ownsAndClearsTransientContinuityState() throws {
        let host = CodexPromptTargetContinuityHost()
        let identity = FocusedFieldIdentity(
            bundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let context = makeContext()
        let app = RunningApplicationInfo(
            bundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            localizedName: "Codex",
            processIdentifier: 42
        )

        host.rememberAnchor(
            appBundleIdentifier: app.bundleIdentifier,
            fieldIdentity: identity,
            context: context
        )
        #expect(host.trustedAnchor?.fieldIdentity == identity)
        #expect(host.axCooldownPreservation == nil)

        let snapshot = FocusedTextSnapshot(
            fieldIdentity: identity,
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor
        )
        #expect(host.beginAXCooldownPreservation(
            app: app,
            currentFieldIdentity: identity,
            currentSnapshot: snapshot,
            observedContext: context,
            hasActiveSuggestionWork: true,
            cooldownMilliseconds: 750
        ))
        #expect(host.axCooldownPreservation != nil)
        #expect(host.remainingAXCooldownMilliseconds() > 0)

        host.clearCooldownPreservation()
        #expect(host.axCooldownPreservation == nil)
        #expect(host.trustedAnchor != nil)

        host.reset()
        #expect(host.trustedAnchor == nil)
        #expect(host.axCooldownPreservation == nil)
    }

    private func makeContext() -> FocusedTextContext {
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
            textBeforeCursor: "synthetic prompt",
            textAfterCursor: "",
            selectedText: "",
            selectedTextLength: 0,
            caretRect: CGRect(x: 120, y: 650, width: 1, height: 20),
            elementRect: CGRect(x: 100, y: 620, width: 700, height: 80),
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
