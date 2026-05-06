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

    @Test("Allows prompt-like dogfood wrappers")
    func allowsPromptLikeDogfoodWrappers() {
        let groupDecision = policy.decision(
            bundleIdentifier: "com.openai.codex",
            role: "AXGroup",
            fingerprintText: "Ask Codex prompt input",
            elementRect: CGRect(x: 100, y: 620, width: 700, height: 84),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 720)
        )
        let webAreaDecision = policy.decision(
            bundleIdentifier: "com.anthropic.claude-code",
            role: "AXWebArea",
            fingerprintText: "Claude message composer",
            elementRect: CGRect(x: 100, y: 620, width: 700, height: 84),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 720)
        )

        #expect(groupDecision.canSuggest)
        #expect(groupDecision.reason == "prompt-fingerprint")
        #expect(webAreaDecision.canSuggest)
        #expect(webAreaDecision.reason == "prompt-fingerprint")

        let desktopDecision = policy.decision(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            role: "AXTextArea",
            fingerprintText: "Describe a task or ask a question",
            elementRect: CGRect(x: 100, y: 620, width: 700, height: 84),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 720)
        )

        #expect(desktopDecision.canSuggest)
        #expect(desktopDecision.reason == "prompt-fingerprint")
    }

    @Test("Allows generic prompt fingerprints only with composer geometry")
    func genericPromptFingerprintRequiresComposerGeometry() {
        let goodDecision = policy.decision(
            bundleIdentifier: "com.openai.codex",
            role: "AXTextArea",
            fingerprintText: "chat input",
            elementRect: CGRect(x: 100, y: 620, width: 700, height: 84),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 720)
        )
        let centralDecision = policy.decision(
            bundleIdentifier: "com.openai.codex",
            role: "AXTextArea",
            fingerprintText: "chat input",
            elementRect: CGRect(x: 100, y: 180, width: 700, height: 340),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 720)
        )

        #expect(goodDecision.canSuggest)
        #expect(goodDecision.reason == "generic-prompt-geometry")
        #expect(!centralDecision.canSuggest)
        #expect(centralDecision.reason == "generic-prompt-not-composer")
    }

    @Test("Blocks generic prompt fingerprints without geometry")
    func blocksGenericPromptFingerprintWithoutGeometry() {
        let decision = policy.decision(
            bundleIdentifier: "com.openai.codex",
            role: "AXTextArea",
            fingerprintText: "input",
            elementRect: nil,
            windowRect: nil
        )

        #expect(!decision.canSuggest)
        #expect(decision.reason == "missing-prompt-bounds")
    }

    @Test("Blocks bare prompt fingerprints without composer geometry")
    func blocksBarePromptFingerprintWithoutGeometry() {
        let decision = policy.decision(
            bundleIdentifier: "com.openai.codex",
            role: "AXTextArea",
            fingerprintText: "prompt",
            elementRect: nil,
            windowRect: nil
        )

        #expect(!decision.canSuggest)
        #expect(decision.reason == "missing-prompt-bounds")
    }

    @Test("Blocks dogfood wrappers without prompt fingerprints")
    func blocksDogfoodWrappersWithoutPromptFingerprints() {
        let decision = policy.decision(
            bundleIdentifier: "com.openai.codex",
            role: "AXGroup",
            fingerprintText: "main content",
            elementRect: CGRect(x: 100, y: 620, width: 700, height: 84),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 720)
        )

        #expect(!decision.canSuggest)
        #expect(decision.reason == "missing-prompt-fingerprint")
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

    @Test("Blocks top-edge dogfood text areas")
    func blocksTopEdgeTextAreas() {
        let decision = policy.decision(
            bundleIdentifier: "com.openai.codex",
            role: "AXTextArea",
            fingerprintText: "",
            elementRect: CGRect(x: 100, y: 8, width: 700, height: 56),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 720)
        )

        #expect(!decision.canSuggest)
        #expect(decision.reason == "not-prompt-like")
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
