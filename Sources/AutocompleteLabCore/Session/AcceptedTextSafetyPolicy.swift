import Foundation

public enum AcceptedTextSafetyDecision: Equatable, Sendable {
    case allowed
    case blocked(reason: String)

    public var canInsert: Bool {
        self == .allowed
    }

    public var blockReason: String? {
        guard case let .blocked(reason) = self else {
            return nil
        }

        return reason
    }
}

public struct AcceptedTextSafetyPolicy: Equatable, Sendable {
    public init() {}

    public func decision(
        acceptedText: String,
        profile: CompatibilityProfile
    ) -> AcceptedTextSafetyDecision {
        let trimmedAcceptedText = acceptedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !acceptedText.isEmpty, !trimmedAcceptedText.isEmpty else {
            return .blocked(reason: "accepted-text-empty")
        }

        guard profile.insertionMode != .disabled else {
            return .blocked(reason: "profile-insertion-disabled")
        }

        guard profile.supportsOneWordAcceptance || profile.supportsFullAcceptance else {
            return .blocked(reason: "profile-acceptance-disabled")
        }

        if acceptedText.unicodeScalars.contains(where: { CharacterSet.newlines.contains($0) }) {
            return .blocked(reason: "accepted-text-line-break")
        }

        if acceptedText.unicodeScalars.contains(where: { $0 == "\t" }) {
            return .blocked(reason: "accepted-text-tab")
        }

        if containsHiddenPromptControlCharacter(acceptedText) {
            return .blocked(reason: "accepted-text-hidden-control-character")
        }

        if acceptedText.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
            return .blocked(reason: "accepted-text-control-character")
        }

        if !profile.supportsFullAcceptance,
           Self.wordCount(in: acceptedText) > 1 {
            return .blocked(reason: "accepted-text-multiword-full-disabled")
        }

        if profile.promptAppSafetyMode.isPromptSurface,
           let reason = promptAppBlockReason(trimmedAcceptedText) {
            return .blocked(reason: reason)
        }

        return .allowed
    }

    private func promptAppBlockReason(_ text: String) -> String? {
        let normalized = text.lowercased()

        if Self.promptCommandPrefixes.contains(where: { normalized.hasPrefix($0) }) {
            return "accepted-text-prompt-command-prefix"
        }

        if normalized.hasPrefix("```") || normalized.hasPrefix("$ ") || normalized.hasPrefix("> ") {
            return "accepted-text-prompt-command-prefix"
        }

        if normalized.unicodeScalars.contains(where: isPromptShellMetacharacter) {
            return "accepted-text-prompt-shell-metacharacter"
        }

        if !normalized.unicodeScalars.allSatisfy(isPromptSafeWordScalar) {
            return "accepted-text-prompt-unsafe-token"
        }

        if Self.promptActionWords.contains(normalized) {
            return "accepted-text-prompt-action-word"
        }

        return nil
    }

    private func containsHiddenPromptControlCharacter(_ text: String) -> Bool {
        text.unicodeScalars.contains(where: Self.hiddenPromptControlScalars.contains)
    }

    private func isPromptShellMetacharacter(_ scalar: Unicode.Scalar) -> Bool {
        Self.promptShellMetacharacters.contains(scalar)
    }

    private func isPromptSafeWordScalar(_ scalar: Unicode.Scalar) -> Bool {
        CharacterSet.alphanumerics.contains(scalar)
            || scalar == "'"
            || scalar == "’"
    }

    private static func wordCount(in text: String) -> Int {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .count
    }

    private static let hiddenPromptControlScalars: Set<Unicode.Scalar> = [
        "\u{200B}", // zero-width space
        "\u{200C}", // zero-width non-joiner
        "\u{200D}", // zero-width joiner
        "\u{2060}", // word joiner
        "\u{FEFF}" // zero-width no-break space
    ]

    private static let promptCommandPrefixes = [
        "/", "!", "@", "-", "--", ":", ".", "`", "\""
    ]

    private static let promptShellMetacharacters: Set<Unicode.Scalar> = [
        "|", "&", ";", "<", ">", "$", "\\", "(", ")", "{", "}", "[", "]", "*", "?"
    ]

    private static let promptActionWords: Set<String> = [
        "allow",
        "approve",
        "bash",
        "click",
        "curl",
        "delete",
        "deploy",
        "enter",
        "execute",
        "merge",
        "return",
        "run",
        "send",
        "ship",
        "submit",
        "sudo"
    ]
}
