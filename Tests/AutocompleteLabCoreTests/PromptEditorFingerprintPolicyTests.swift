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
            windowRect: nil,
            proofModeEnabled: true
        )

        #expect(decision.canSuggest)
        #expect(decision.reason == "prompt-fingerprint")
    }

    @Test("Allows native prompt text fields with prompt fingerprints")
    func allowsNativePromptTextFieldsWithPromptFingerprints() {
        let decision = policy.decision(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            role: "AXTextField",
            fingerprintText: "Ask Claude prompt input",
            elementRect: nil,
            windowRect: nil,
            proofModeEnabled: true
        )

        #expect(decision.canSuggest)
        #expect(decision.reason == "prompt-fingerprint")
    }

    @Test("Blocks Claude prompt apps outside explicit proof mode")
    func blocksClaudePromptAppsOutsideProofMode() {
        let decision = policy.decision(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            role: "AXTextArea",
            fingerprintText: "Ask Claude prompt input",
            elementRect: CGRect(x: 100, y: 620, width: 700, height: 84),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 720),
            proofModeEnabled: false
        )

        #expect(!decision.canSuggest)
        #expect(decision.reason == "prompt-proof-mode-required")
    }

    @Test("Allows prompt-like dogfood wrappers")
    func allowsPromptLikeDogfoodWrappers() {
        let groupDecision = policy.decision(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            role: "AXGroup",
            fingerprintText: "Ask Claude prompt input",
            elementRect: CGRect(x: 100, y: 620, width: 700, height: 84),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 720),
            proofModeEnabled: true
        )
        let webAreaDecision = policy.decision(
            bundleIdentifier: "com.anthropic.claude-code",
            role: "AXWebArea",
            fingerprintText: "Claude message composer",
            elementRect: CGRect(x: 100, y: 620, width: 700, height: 84),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 720),
            proofModeEnabled: true
        )

        #expect(groupDecision.canSuggest)
        #expect(groupDecision.reason == "prompt-fingerprint-geometry")
        #expect(webAreaDecision.canSuggest)
        #expect(webAreaDecision.reason == "prompt-fingerprint-geometry")

        let desktopDecision = policy.decision(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            role: "AXTextArea",
            fingerprintText: "Describe a task or ask a question",
            elementRect: CGRect(x: 100, y: 620, width: 700, height: 84),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 720),
            proofModeEnabled: true
        )

        #expect(desktopDecision.canSuggest)
        #expect(desktopDecision.reason == "prompt-fingerprint")
    }

    @Test("Blocks prompt wrapper fingerprints away from composer geometry")
    func blocksPromptWrapperFingerprintsAwayFromComposerGeometry() {
        let decision = policy.decision(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            role: "AXGroup",
            fingerprintText: "Ask Claude prompt input",
            elementRect: CGRect(x: 100, y: 180, width: 700, height: 340),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 720),
            proofModeEnabled: true
        )

        #expect(!decision.canSuggest)
        #expect(decision.reason == "prompt-fingerprint-not-composer")
    }

    @Test("Allows generic prompt fingerprints only with composer geometry")
    func genericPromptFingerprintRequiresComposerGeometry() {
        let goodDecision = policy.decision(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            role: "AXTextArea",
            fingerprintText: "chat input",
            elementRect: CGRect(x: 100, y: 620, width: 700, height: 84),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 720),
            proofModeEnabled: true
        )
        let centralDecision = policy.decision(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            role: "AXTextArea",
            fingerprintText: "chat input",
            elementRect: CGRect(x: 100, y: 180, width: 700, height: 340),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 720),
            proofModeEnabled: true
        )

        #expect(goodDecision.canSuggest)
        #expect(goodDecision.reason == "generic-prompt-geometry")
        #expect(!centralDecision.canSuggest)
        #expect(centralDecision.reason == "generic-prompt-not-composer")
    }

    @Test("Allows Codex proof marker text area away from bottom composer geometry")
    func allowsCodexProofMarkerTextAreaAwayFromBottomComposerGeometry() {
        let decision = policy.decision(
            bundleIdentifier: "com.openai.codex",
            role: "AXTextArea",
            fingerprintText: "chat input",
            elementRect: CGRect(x: 272, y: 373, width: 568, height: 45),
            windowRect: CGRect(x: 0, y: 30, width: 872, height: 762),
            proofModeEnabled: true,
            textBeforeCursor: "AUTOCOMPLETE_LAB_CODEX_PROOF Can we make this inst",
            textAfterCursor: "",
            selectedTextLength: 0
        )

        #expect(decision.canSuggest)
        #expect(decision.reason == "codex-proof-marker")
    }

    @Test("Allows Codex text areas when Codex omits window bounds")
    func allowsCodexTextAreasWhenCodexOmitsWindowBounds() {
        let decision = policy.decision(
            bundleIdentifier: "com.openai.codex",
            role: "AXTextArea",
            fingerprintText: "",
            elementRect: CGRect(x: 88, y: 96, width: 668, height: 149),
            windowRect: nil,
            proofModeEnabled: false,
            textBeforeCursor: "hey how are things going intell",
            textAfterCursor: "",
            selectedTextLength: 0
        )

        #expect(decision.canSuggest)
        #expect(decision.reason == "codex-text-area")
    }

    @Test("Blocks Codex text areas with selected text")
    func blocksCodexTextAreasWithSelectedText() {
        let decision = policy.decision(
            bundleIdentifier: "com.openai.codex",
            role: "AXTextArea",
            fingerprintText: "",
            elementRect: CGRect(x: 88, y: 96, width: 668, height: 149),
            windowRect: nil,
            proofModeEnabled: false,
            textBeforeCursor: "replace this",
            textAfterCursor: "",
            selectedTextLength: 1
        )

        #expect(!decision.canSuggest)
        #expect(decision.reason == "missing-prompt-bounds")
    }

    @Test("Allows Codex text areas without proof mode but blocks unsafe cursor state")
    func allowsCodexTextAreasWithoutProofModeButBlocksUnsafeCursorState() {
        let withoutProofMode = policy.decision(
            bundleIdentifier: "com.openai.codex",
            role: "AXTextArea",
            fingerprintText: "chat input",
            elementRect: CGRect(x: 272, y: 373, width: 568, height: 45),
            windowRect: CGRect(x: 0, y: 30, width: 872, height: 762),
            proofModeEnabled: false,
            textBeforeCursor: "AUTOCOMPLETE_LAB_CODEX_PROOF Can we make this inst",
            textAfterCursor: "",
            selectedTextLength: 0
        )
        let withSelection = policy.decision(
            bundleIdentifier: "com.openai.codex",
            role: "AXTextArea",
            fingerprintText: "chat input",
            elementRect: CGRect(x: 272, y: 373, width: 568, height: 45),
            windowRect: CGRect(x: 0, y: 30, width: 872, height: 762),
            proofModeEnabled: true,
            textBeforeCursor: "AUTOCOMPLETE_LAB_CODEX_PROOF Can we make this inst",
            textAfterCursor: "",
            selectedTextLength: 1
        )
        let withTextAfterCursor = policy.decision(
            bundleIdentifier: "com.openai.codex",
            role: "AXTextArea",
            fingerprintText: "chat input",
            elementRect: CGRect(x: 272, y: 373, width: 568, height: 45),
            windowRect: CGRect(x: 0, y: 30, width: 872, height: 762),
            proofModeEnabled: true,
            textBeforeCursor: "AUTOCOMPLETE_LAB_CODEX_PROOF Can we make this",
            textAfterCursor: " inst",
            selectedTextLength: 0
        )

        #expect(withoutProofMode.canSuggest)
        #expect(withoutProofMode.reason == "codex-text-area")
        #expect(!withSelection.canSuggest)
        #expect(withSelection.reason == "generic-prompt-not-composer")
        #expect(!withTextAfterCursor.canSuggest)
        #expect(withTextAfterCursor.reason == "generic-prompt-not-composer")
    }

    @Test("Allows Codex prompt geometry without proof marker")
    func allowsCodexPromptGeometryWithoutProofMarker() {
        let promptFingerprint = policy.decision(
            bundleIdentifier: "com.openai.codex",
            role: "AXTextArea",
            fingerprintText: "Ask Codex prompt input",
            elementRect: CGRect(x: 100, y: 620, width: 700, height: 84),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 720),
            proofModeEnabled: false,
            textBeforeCursor: "ordinary prompt"
        )
        let promptGeometry = policy.decision(
            bundleIdentifier: "com.openai.codex",
            role: "AXTextArea",
            fingerprintText: "",
            elementRect: CGRect(x: 100, y: 620, width: 700, height: 84),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 720),
            proofModeEnabled: true,
            textBeforeCursor: "ordinary prompt"
        )

        #expect(promptFingerprint.canSuggest)
        #expect(promptFingerprint.reason == "codex-text-area")
        #expect(promptGeometry.canSuggest)
        #expect(promptGeometry.reason == "codex-text-area")
    }

    @Test("Blocks generic prompt fingerprints without geometry")
    func blocksGenericPromptFingerprintWithoutGeometry() {
        let decision = policy.decision(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            role: "AXTextArea",
            fingerprintText: "input",
            elementRect: nil,
            windowRect: nil,
            proofModeEnabled: true
        )

        #expect(!decision.canSuggest)
        #expect(decision.reason == "missing-prompt-bounds")
    }

    @Test("Blocks bare prompt fingerprints without composer geometry")
    func blocksBarePromptFingerprintWithoutGeometry() {
        let decision = policy.decision(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            role: "AXTextArea",
            fingerprintText: "prompt",
            elementRect: nil,
            windowRect: nil,
            proofModeEnabled: true
        )

        #expect(!decision.canSuggest)
        #expect(decision.reason == "missing-prompt-bounds")
    }

    @Test("Blocks bare composer labels without geometry")
    func blocksBareComposerLabelsWithoutGeometry() {
        let decision = policy.decision(
            bundleIdentifier: "com.anthropic.claude-code",
            role: "AXTextArea",
            fingerprintText: "composer",
            elementRect: nil,
            windowRect: nil,
            proofModeEnabled: true
        )

        #expect(!decision.canSuggest)
        #expect(decision.reason == "missing-prompt-bounds")
    }

    @Test("Blocks dogfood wrappers without prompt fingerprints")
    func blocksDogfoodWrappersWithoutPromptFingerprints() {
        let decision = policy.decision(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            role: "AXGroup",
            fingerprintText: "main content",
            elementRect: CGRect(x: 100, y: 620, width: 700, height: 84),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 720),
            proofModeEnabled: true
        )

        #expect(!decision.canSuggest)
        #expect(decision.reason == "missing-prompt-fingerprint")
    }

    @Test("Allows prompt-like composer geometry near a window edge")
    func allowsPromptGeometry() {
        let decision = policy.decision(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            role: "AXTextArea",
            fingerprintText: "",
            elementRect: CGRect(x: 100, y: 620, width: 700, height: 84),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 720),
            proofModeEnabled: true
        )

        #expect(decision.canSuggest)
        #expect(decision.reason == "prompt-geometry")
    }

    @Test("Blocks top-edge dogfood text areas")
    func blocksTopEdgeTextAreas() {
        let decision = policy.decision(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            role: "AXTextArea",
            fingerprintText: "",
            elementRect: CGRect(x: 100, y: 8, width: 700, height: 56),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 720),
            proofModeEnabled: true
        )

        #expect(!decision.canSuggest)
        #expect(decision.reason == "not-prompt-like")
    }

    @Test("Blocks large central dogfood text areas")
    func blocksLargeCentralTextAreas() {
        let decision = policy.decision(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            role: "AXTextArea",
            fingerprintText: "",
            elementRect: CGRect(x: 120, y: 180, width: 680, height: 360),
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 720),
            proofModeEnabled: true
        )

        #expect(!decision.canSuggest)
        #expect(decision.reason == "not-prompt-like")
    }

    @Test("Blocks dogfood text areas without usable bounds")
    func blocksMissingPromptBounds() {
        let decision = policy.decision(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            role: "AXTextArea",
            fingerprintText: "",
            elementRect: nil,
            windowRect: nil,
            proofModeEnabled: true
        )

        #expect(!decision.canSuggest)
        #expect(decision.reason == "missing-prompt-bounds")
    }
}
