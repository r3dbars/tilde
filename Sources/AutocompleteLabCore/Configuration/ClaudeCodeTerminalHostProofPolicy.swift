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
    public static let virtualBundleIdentifier = "com.anthropic.claude-code"

    public static let supportedTerminalHosts: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp",
        "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty",
        "org.alacritty"
    ]

    public static let proofMarker = "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF"

    public static var proofProfile: CompatibilityProfile {
        CompatibilityProfile(
            bundleIdentifier: virtualBundleIdentifier,
            displayName: "Claude Code",
            appFamily: .customCanvas,
            supportLevel: .yellow,
            supportReason: "Claude Code can be proofed only through an explicit terminal-host proof lane.",
            renderMode: .inlineAdjacent,
            insertionMode: .keyEvents,
            fallbackRenderMode: .floatingMirror,
            fallbackInsertionMode: nil,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.caret],
            knownFailureModes: [
                "terminal-hosted CLI input can submit shell commands",
                "terminal accessibility text can include scrollback instead of only the prompt line"
            ],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsOneWordAcceptance: true,
            supportsFullAcceptance: false,
            requiresNoSubmitAcceptanceProof: true,
            suppressesAfterInsertionFailure: true,
            allowsDetachedSuggestions: false,
            allowsSyntheticCaretPlacement: true,
            notes: "Proof-only virtual Claude Code profile. It may be used only when a supported terminal host is frontmost, Claude Code proof mode is active, the proof marker is present, and the current input line is not a shell command."
        )
    }

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

        if let line = nonEmptyLines.last,
           looksLikeShellPrompt(line, windowTitle: context.windowTitle) {
            return .blocked(.shellPromptDetected)
        }

        return .eligible
    }

    public static func focusedInputLine(
        textBeforeCursor: String,
        textAfterCursor: String
    ) -> String {
        let beforeLine = textBeforeCursor
            .split(separator: "\n", omittingEmptySubsequences: false)
            .last
            .map(String.init) ?? ""
        let afterLine = textAfterCursor
            .split(separator: "\n", omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? ""

        return beforeLine + afterLine
    }

    public static func proofInputText(
        textBeforeCursor: String,
        textAfterCursor _: String
    ) -> String? {
        let beforeLine = textBeforeCursor
            .split(separator: "\n", omittingEmptySubsequences: false)
            .last
            .map(String.init) ?? ""
        return sanitizedProofInputLine(beforeLine)
    }

    public static func sanitizedProofInputLine(_ line: String) -> String? {
        var text = line.trimmingCharacters(in: .newlines)
        text = text.trimmingLeadingWhitespace()

        if text.hasPrefix("❯") {
            text.removeFirst()
            text = text.trimmingLeadingWhitespace()
        }

        text = text
            .replacingOccurrences(of: proofMarker, with: "")
            .trimmingLeadingWhitespace()

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty,
              !looksLikePlaceholderPrompt(trimmedText) else {
            return nil
        }

        if text.last?.isWhitespace == true {
            return trimmedText + " "
        }

        return trimmedText
    }

    private static func looksLikeShellPrompt(_ line: String, windowTitle: String) -> Bool {
        let shellPrefixes = ["$", "%", "#", "❯", "➜"]
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("❯"),
           (trimmed.localizedCaseInsensitiveContains(proofMarker)
            || windowTitle.localizedCaseInsensitiveContains("Claude Code")
            && windowTitle.localizedCaseInsensitiveContains(proofMarker)) {
            return false
        }

        for prefix in shellPrefixes where trimmed.hasPrefix(prefix) {
            let remainder = trimmed.dropFirst(prefix.count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !remainder.isEmpty {
                return true
            }
        }

        return false
    }

    private static func looksLikePlaceholderPrompt(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("Try \"")
            || trimmed.hasPrefix("Try '")
    }
}

private extension String {
    func trimmingLeadingWhitespace() -> String {
        String(drop { $0.isWhitespace && !$0.isNewline })
    }
}
