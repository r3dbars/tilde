import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Focused field identity policy")
struct FocusedFieldIdentityPolicyTests {
    private let policy = FocusedFieldIdentityPolicy()

    @Test("Accessibility element mode keeps the AX element identifier")
    func accessibilityElementModeKeepsElementIdentifier() {
        let identity = policy.identity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            mode: .accessibilityElement,
            input: input(elementIdentifier: 99)
        )

        #expect(identity.bundleIdentifier == "com.apple.TextEdit")
        #expect(identity.processIdentifier == 42)
        #expect(identity.elementIdentifier == 99)
        #expect(identity.traceDescription == "com.apple.TextEdit|pid:42|element:99")
    }

    @Test("Stable bounds mode ignores transient AX element churn")
    func stableBoundsModeIgnoresTransientElementChurn() {
        let first = policy.identity(
            bundleIdentifier: "md.obsidian",
            processIdentifier: 7,
            mode: .stableBounds,
            input: input(elementIdentifier: 100)
        )
        let second = policy.identity(
            bundleIdentifier: "md.obsidian",
            processIdentifier: 7,
            mode: .stableBounds,
            input: input(elementIdentifier: 200)
        )

        #expect(first == second)
    }

    @Test("Stable bounds mode changes when field geometry changes")
    func stableBoundsModeChangesWithFieldGeometry() {
        let first = policy.identity(
            bundleIdentifier: "com.openai.codex",
            processIdentifier: 12,
            mode: .stableBounds,
            input: input(elementRect: CGRect(x: 80, y: 640, width: 600, height: 56))
        )
        let second = policy.identity(
            bundleIdentifier: "com.openai.codex",
            processIdentifier: 12,
            mode: .stableBounds,
            input: input(elementRect: CGRect(x: 80, y: 520, width: 600, height: 56))
        )

        #expect(first != second)
    }

    @Test("Stable bounds mode normalizes fingerprint text")
    func stableBoundsModeNormalizesFingerprintText() {
        let first = policy.identity(
            bundleIdentifier: "com.openai.codex",
            processIdentifier: 12,
            mode: .stableBounds,
            input: input(
                fingerprint: FocusedElementFingerprint(
                    identifier: " Prompt ",
                    title: "Ask Codex"
                )
            )
        )
        let second = policy.identity(
            bundleIdentifier: "com.openai.codex",
            processIdentifier: 12,
            mode: .stableBounds,
            input: input(
                fingerprint: FocusedElementFingerprint(
                    identifier: "prompt",
                    title: "ask codex"
                )
            )
        )

        #expect(first == second)
    }

    @Test("Focused text snapshots compare by field and surrounding text")
    func snapshotsCompareByFieldAndText() {
        let identity = FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            elementIdentifier: 9
        )

        let first = FocusedTextSnapshot(
            fieldIdentity: identity,
            textBeforeCursor: "hello",
            textAfterCursor: ""
        )
        let second = FocusedTextSnapshot(
            fieldIdentity: identity,
            textBeforeCursor: "hello",
            textAfterCursor: ""
        )
        let third = FocusedTextSnapshot(
            fieldIdentity: identity,
            textBeforeCursor: "hello!",
            textAfterCursor: ""
        )

        #expect(first == second)
        #expect(first != third)
    }

    private func input(
        elementIdentifier: Int = 1,
        role: String? = "AXTextArea",
        subrole: String? = nil,
        fingerprint: FocusedElementFingerprint = FocusedElementFingerprint(
            identifier: "editor",
            title: "Draft",
            description: nil,
            help: nil,
            placeholder: "Message",
            windowTitle: "Window"
        ),
        elementRect: CGRect? = CGRect(x: 100.4, y: 620.4, width: 700.2, height: 84.2),
        windowRect: CGRect? = CGRect(x: 0, y: 0, width: 900, height: 720)
    ) -> FocusedFieldIdentityInput {
        FocusedFieldIdentityInput(
            elementIdentifier: elementIdentifier,
            role: role,
            subrole: subrole,
            fingerprint: fingerprint,
            elementRect: elementRect,
            windowRect: windowRect
        )
    }
}
