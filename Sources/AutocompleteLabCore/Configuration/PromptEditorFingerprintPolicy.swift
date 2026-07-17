import CoreGraphics
import Foundation

public struct PromptEditorFingerprintDecision: Equatable, Sendable {
    public let canSuggest: Bool
    public let reason: String

    public init(canSuggest: Bool, reason: String) {
        self.canSuggest = canSuggest
        self.reason = reason
    }
}

public struct PromptEditorFingerprintPolicy: Equatable, Sendable {
    public static let dogfoodBundleIdentifiers: Set<String> = [
        "com.openai.codex",
        "com.anthropic.claude-code",
        "com.anthropic.claudefordesktop"
    ]

    public init() {}

    public func decision(
        bundleIdentifier: String,
        role: String?,
        fingerprintText: String,
        elementRect: CGRect?,
        windowRect: CGRect?,
        proofModeEnabled: Bool = false,
        textBeforeCursor: String = "",
        textAfterCursor: String = "",
        selectedTextLength: Int = 0,
        codexProofMarker: String = "AUTOCOMPLETE_LAB_CODEX_PROOF"
    ) -> PromptEditorFingerprintDecision {
        guard Self.dogfoodBundleIdentifiers.contains(bundleIdentifier) else {
            return PromptEditorFingerprintDecision(canSuggest: true, reason: "non-dogfood-profile")
        }

        guard Self.promptCompatibleRoles.contains(role ?? "") else {
            return PromptEditorFingerprintDecision(canSuggest: false, reason: "non-prompt-role")
        }

        if bundleIdentifier == "com.openai.codex",
           proofModeEnabled,
           role == "AXTextArea",
           selectedTextLength == 0,
           textAfterCursor.isEmpty,
           !codexProofMarker.isEmpty,
           textBeforeCursor.contains(codexProofMarker) {
            return PromptEditorFingerprintDecision(canSuggest: true, reason: "codex-proof-marker")
        }

        guard bundleIdentifier == "com.openai.codex" || proofModeEnabled else {
            return PromptEditorFingerprintDecision(canSuggest: false, reason: "prompt-proof-mode-required")
        }

        if bundleIdentifier == "com.openai.codex",
           role == "AXTextArea",
           selectedTextLength == 0,
           elementRect != nil {
            return PromptEditorFingerprintDecision(canSuggest: true, reason: "codex-text-area")
        }

        let searchable = fingerprintText.lowercased()
        if Self.strongPromptTerms.contains(where: { searchable.contains($0) }) {
            guard !Self.promptTextInputRoles.contains(role ?? "") else {
                return PromptEditorFingerprintDecision(canSuggest: true, reason: "prompt-fingerprint")
            }

            guard let elementRect,
                  let windowRect,
                  windowRect.width > 0,
                  windowRect.height > 0 else {
                return PromptEditorFingerprintDecision(canSuggest: false, reason: "missing-prompt-bounds")
            }

            guard isPromptLikeGeometry(elementRect: elementRect, windowRect: windowRect) else {
                return PromptEditorFingerprintDecision(canSuggest: false, reason: "prompt-fingerprint-not-composer")
            }

            return PromptEditorFingerprintDecision(canSuggest: true, reason: "prompt-fingerprint-geometry")
        }

        if searchable.contains("composer") {
            guard let elementRect,
                  let windowRect,
                  windowRect.width > 0,
                  windowRect.height > 0 else {
                return PromptEditorFingerprintDecision(canSuggest: false, reason: "missing-prompt-bounds")
            }

            guard isPromptLikeGeometry(elementRect: elementRect, windowRect: windowRect) else {
                return PromptEditorFingerprintDecision(canSuggest: false, reason: "generic-prompt-not-composer")
            }

            return PromptEditorFingerprintDecision(canSuggest: true, reason: "prompt-fingerprint")
        }

        let hasGenericPromptTerm = Self.genericPromptTerms.contains(where: { searchable.contains($0) })
        if hasGenericPromptTerm {
            guard let elementRect,
                  let windowRect,
                  windowRect.width > 0,
                  windowRect.height > 0 else {
                return PromptEditorFingerprintDecision(canSuggest: false, reason: "missing-prompt-bounds")
            }

            guard isPromptLikeGeometry(elementRect: elementRect, windowRect: windowRect) else {
                return PromptEditorFingerprintDecision(canSuggest: false, reason: "generic-prompt-not-composer")
            }

            return PromptEditorFingerprintDecision(canSuggest: true, reason: "generic-prompt-geometry")
        }

        guard Self.promptTextInputRoles.contains(role ?? "") else {
            return PromptEditorFingerprintDecision(canSuggest: false, reason: "missing-prompt-fingerprint")
        }

        guard let elementRect,
              let windowRect,
              windowRect.width > 0,
              windowRect.height > 0 else {
            return PromptEditorFingerprintDecision(canSuggest: false, reason: "missing-prompt-bounds")
        }

        guard isPromptLikeGeometry(elementRect: elementRect, windowRect: windowRect) else {
            return PromptEditorFingerprintDecision(canSuggest: false, reason: "not-prompt-like")
        }

        return PromptEditorFingerprintDecision(canSuggest: true, reason: "prompt-geometry")
    }

    private func isPromptLikeGeometry(elementRect: CGRect, windowRect: CGRect) -> Bool {
        let maxComposerHeight = min(220, windowRect.height * 0.35)
        let isComposerSized = elementRect.height >= 20 && elementRect.height <= maxComposerHeight
        let isWideEnough = elementRect.width >= min(260, windowRect.width * 0.35)
        let distanceToBottom = abs(windowRect.maxY - elementRect.maxY)
        let isNearBottomComposerEdge = distanceToBottom <= windowRect.height * 0.18

        return isComposerSized && isWideEnough && isNearBottomComposerEdge
    }

    private static let strongPromptTerms: Set<String> = [
        "ask codex",
        "ask claude",
        "claude message composer",
        "codex message composer",
        "compose a message",
        "describe a task or ask a question",
        "message composer",
        "prompt editor",
        "prompt input"
    ]

    private static let genericPromptTerms: Set<String> = [
        "ask",
        "chat",
        "claude",
        "codex",
        "input",
        "message",
        "prompt",
        "text area",
        "textarea"
    ]

    private static let promptCompatibleRoles: Set<String> = [
        "AXTextArea",
        "AXTextField",
        "AXGroup",
        "AXWebArea"
    ]

    private static let promptTextInputRoles: Set<String> = [
        "AXTextArea",
        "AXTextField"
    ]
}
