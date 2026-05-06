import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Prompt editor fingerprint policy")
struct PromptEditorFingerprintPolicyTests {
    private let policy = PromptEditorFingerprintPolicy()

    @Test("Allows normal MVP apps without prompt fingerprint checks")
    func allowsNormalApps() {
        let decision = policy.decision(
            bundleIdentifier: "com.apple.TextEdit",
            role: "AXTextField",
            fingerprintText: "",
            elementRect: nil,
            windowRect: nil
        )

        #expect(decision.canSuggest)
        #expect(decision.reason == "non-dogfood-profile")
    }

    @Test("Blocks dogfood apps when focus is not a text area")
    func blocksDogfoodNonTextAreas() {
        let decision = policy.decision(
            bundleIdentifier: "com.openai.codex",
            role: "AXButton",
            fingerprintText: "new chat",
            elementRect: CGRect(x: 0, y: 0, width: 200, height: 30),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 700)
        )

        #expect(!decision.canSuggest)
        #expect(decision.reason == "non-prompt-role")
    }

    @Test("Allows dogfood text areas with prompt-like fingerprints")
    func allowsPromptFingerprint() {
        let decision = policy.decision(
            bundleIdentifier: "com.anthropic.claude-code",
            role: "AXTextArea",
            fingerprintText: "Message composer prompt",
            elementRect: nil,
            windowRect: nil
        )

        #expect(decision.canSuggest)
        #expect(decision.reason == "prompt-fingerprint")
    }

    @Test("Allows prompt-like composer geometry near a window edge")
    func allowsPromptGeometry() {
        let decision = policy.decision(
            bundleIdentifier: "com.openai.codex",
            role: "AXTextArea",
            fingerprintText: "",
            elementRect: CGRect(x: 100, y: 620, width: 700, height: 84),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 720)
        )

        #expect(decision.canSuggest)
        #expect(decision.reason == "prompt-geometry")
    }

    @Test("Blocks large central dogfood text areas")
    func blocksLargeCentralTextAreas() {
        let decision = policy.decision(
            bundleIdentifier: "com.openai.codex",
            role: "AXTextArea",
            fingerprintText: "",
            elementRect: CGRect(x: 120, y: 180, width: 680, height: 360),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 720)
        )

        #expect(!decision.canSuggest)
        #expect(decision.reason == "not-prompt-like")
    }

    @Test("Blocks dogfood text areas without usable bounds")
    func blocksMissingPromptBounds() {
        let decision = policy.decision(
            bundleIdentifier: "com.openai.codex",
            role: "AXTextArea",
            fingerprintText: "",
            elementRect: nil,
            windowRect: nil
        )

        #expect(!decision.canSuggest)
        #expect(decision.reason == "missing-prompt-bounds")
    }
}
