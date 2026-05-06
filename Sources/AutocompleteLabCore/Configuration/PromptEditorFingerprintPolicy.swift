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
        "com.anthropic.claude-code"
    ]

    public init() {}

    public func decision(
        bundleIdentifier: String,
        role: String?,
        fingerprintText: String,
        elementRect: CGRect?,
        windowRect: CGRect?
    ) -> PromptEditorFingerprintDecision {
        guard Self.dogfoodBundleIdentifiers.contains(bundleIdentifier) else {
            return PromptEditorFingerprintDecision(canSuggest: true, reason: "non-dogfood-profile")
        }

        guard role == "AXTextArea" else {
            return PromptEditorFingerprintDecision(canSuggest: false, reason: "non-prompt-role")
        }

        let searchable = fingerprintText.lowercased()
        if Self.promptTerms.contains(where: { searchable.contains($0) }) {
            return PromptEditorFingerprintDecision(canSuggest: true, reason: "prompt-fingerprint")
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
        let distanceToTop = abs(elementRect.minY - windowRect.minY)
        let distanceToBottom = abs(windowRect.maxY - elementRect.maxY)
        let isNearVerticalEdge = min(distanceToTop, distanceToBottom) <= windowRect.height * 0.28

        return isComposerSized && isWideEnough && isNearVerticalEdge
    }

    private static let promptTerms: Set<String> = [
        "ask",
        "chat",
        "claude",
        "codex",
        "composer",
        "input",
        "message",
        "prompt",
        "text area",
        "textarea"
    ]
}
