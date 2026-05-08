import Foundation

public struct ClaudeCodeTerminalHostProofContext: Equatable, Sendable {
    public let hostBundleIdentifier: String
    public let windowTitle: String
    public let focusedText: String
    public let proofModeEnabled: Bool

    public init(
        hostBundleIdentifier: String,
        windowTitle: String,
        focusedText: String,
        proofModeEnabled: Bool
    ) {
        self.hostBundleIdentifier = hostBundleIdentifier
        self.windowTitle = windowTitle
        self.focusedText = focusedText
        self.proofModeEnabled = proofModeEnabled
    }
}

public enum ClaudeCodeTerminalHostProofDecision: Equatable, Sendable {
    case eligible
    case blocked(ClaudeCodeTerminalHostProofBlockReason)
}

public enum ClaudeCodeTerminalHostProofBlockReason: String, Equatable, Sendable {
    case unsupportedTerminalHost
    case proofModeRequired
    case missingProofMarker
    case shellPromptDetected
    case multilineCommandDetected
}

public enum ClaudeCodeTerminalHostProofPolicy {
    public static let supportedTerminalHosts: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp",
        "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty",
        "org.alacritty"
    ]

    public static let proofMarker = "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF"

    public static func evaluate(
        _ context: ClaudeCodeTerminalHostProofContext
    ) -> ClaudeCodeTerminalHostProofDecision {
        guard supportedTerminalHosts.contains(context.hostBundleIdentifier) else {
            return .blocked(.unsupportedTerminalHost)
        }

        guard context.proofModeEnabled else {
            return .blocked(.proofModeRequired)
        }

        let searchableText = [
            context.windowTitle,
            context.focusedText
        ].joined(separator: "\n")

        guard searchableText.localizedCaseInsensitiveContains(proofMarker) else {
            return .blocked(.missingProofMarker)
        }

        let nonEmptyLines = context.focusedText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if nonEmptyLines.count > 1 {
            return .blocked(.multilineCommandDetected)
        }

        if let line = nonEmptyLines.last, looksLikeShellPrompt(line) {
            return .blocked(.shellPromptDetected)
        }

        return .eligible
    }

    private static func looksLikeShellPrompt(_ line: String) -> Bool {
        let shellPrefixes = ["$", "%", "#", "❯", "➜"]
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        for prefix in shellPrefixes where trimmed.hasPrefix(prefix) {
            let remainder = trimmed.dropFirst(prefix.count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !remainder.isEmpty {
                return true
            }
        }

        return false
    }
}
