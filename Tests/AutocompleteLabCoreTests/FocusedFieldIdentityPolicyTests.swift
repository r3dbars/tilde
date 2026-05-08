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

    @Test("Stable bounds mode uses a deterministic hash fixture")
    func stableBoundsModeUsesDeterministicHashFixture() {
        let identity = policy.identity(
            bundleIdentifier: "md.obsidian",
            processIdentifier: 7,
            mode: .stableBounds,
            input: input(elementIdentifier: 100)
        )

        #expect(identity.elementIdentifier == 8_002_093_380_379_354_256)
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

    @Test("Stable bounds mode uses a deterministic privacy-safe identifier")
    func stableBoundsModeUsesDeterministicIdentifier() {
        let identity = policy.identity(
            bundleIdentifier: "com.openai.codex",
            processIdentifier: 12,
            mode: .stableBounds,
            input: input()
        )

        #expect(identity.elementIdentifier == 8_002_093_380_379_354_256)
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

    @Test("Rounded target rects tolerate tiny AX float noise")
    func roundedTargetRectsTolerateTinyAXFloatNoise() {
        let first = RoundedFocusedRect(CGRect(x: 100.2, y: 620.2, width: 700.2, height: 84.2))
        let second = RoundedFocusedRect(CGRect(x: 100.4, y: 620.4, width: 700.4, height: 84.4))
        let changed = RoundedFocusedRect(CGRect(x: 101.0, y: 620.4, width: 700.4, height: 84.4))

        #expect(first == second)
        #expect(first != changed)
    }

    @Test("Target fingerprints include role geometry caret and text revision")
    func targetFingerprintsIncludeTargetAndTextRevision() {
        let base = targetFingerprint()
        let roleChanged = targetFingerprint(role: "AXGroup")
        let windowChanged = targetFingerprint(windowRect: CGRect(x: 40, y: 0, width: 900, height: 720))
        let windowIdentifierChanged = targetFingerprint(windowIdentifier: 43)
        let caretChanged = targetFingerprint(caretRect: CGRect(x: 160, y: 650, width: 1, height: 20))
        let textChanged = targetFingerprint(textBeforeCursor: "hello there")

        #expect(!base.matches(roleChanged))
        #expect(!base.matches(windowChanged))
        #expect(!base.matches(windowIdentifierChanged))
        #expect(!base.matches(caretChanged))
        #expect(!base.matches(textChanged))
    }

    @Test("Post insertion scope keeps target geometry but ignores natural caret and text movement")
    func postInsertionScopeIgnoresCaretAndTextMovement() {
        let before = targetFingerprint(
            caretRect: CGRect(x: 120, y: 650, width: 1, height: 20),
            textBeforeCursor: "hello"
        ).postInsertionScope
        let after = targetFingerprint(
            caretRect: CGRect(x: 180, y: 650, width: 1, height: 20),
            textBeforeCursor: "hello there"
        ).postInsertionScope
        let movedWindow = targetFingerprint(
            windowRect: CGRect(x: 40, y: 0, width: 900, height: 720),
            caretRect: CGRect(x: 180, y: 650, width: 1, height: 20),
            textBeforeCursor: "hello there"
        ).postInsertionScope

        #expect(before.matches(after))
        #expect(!before.matches(movedWindow))
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

    private func targetFingerprint(
        role: String? = "AXTextArea",
        subrole: String? = nil,
        windowIdentifier: Int? = 42,
        elementRect: CGRect? = CGRect(x: 100.4, y: 620.4, width: 700.2, height: 84.2),
        windowRect: CGRect? = CGRect(x: 0, y: 0, width: 900, height: 720),
        caretRect: CGRect? = CGRect(x: 120, y: 650, width: 1, height: 20),
        textBeforeCursor: String = "hello",
        textAfterCursor: String = ""
    ) -> FocusedTargetFingerprint {
        FocusedTargetFingerprint(
            role: role,
            subrole: subrole,
            elementFingerprint: FocusedElementFingerprint(
                identifier: "editor",
                title: "Draft",
                placeholder: "Message",
                windowTitle: "Window"
            ),
            windowIdentifier: windowIdentifier,
            elementRect: elementRect,
            windowRect: windowRect,
            caretRect: caretRect,
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor
        )
    }
}
