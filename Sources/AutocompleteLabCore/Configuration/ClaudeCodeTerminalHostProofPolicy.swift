import Foundation

public struct ClaudeCodeTerminalHostProofContext: Equatable, Sendable {
    public let hostBundleIdentifier: String
    public let windowTitle: String
    public let focusedText: String
    public let rawTextBeforeCursor: String
    public let rawTextAfterCursor: String
    public let proofModeEnabled: Bool

    public init(
        hostBundleIdentifier: String,
        windowTitle: String,
        focusedText: String,
        rawTextBeforeCursor: String = "",
        rawTextAfterCursor: String = "",
        proofModeEnabled: Bool
    ) {
        self.hostBundleIdentifier = hostBundleIdentifier
        self.windowTitle = windowTitle
        self.focusedText = focusedText
        self.rawTextBeforeCursor = rawTextBeforeCursor
        self.rawTextAfterCursor = rawTextAfterCursor
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
    case shellCommandDetected
    case multilineCommandDetected
    case activeAgentOutputDetected
}

public struct ClaudeCodeTerminalHostVariant: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let bundleIdentifier: String

    public init(id: String, displayName: String, bundleIdentifier: String) {
        self.id = id
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
    }

    public var proofLabel: String {
        "claude-code-\(id)"
    }
}

public enum ClaudeCodeTerminalHostProofPolicy {
    public static let virtualBundleIdentifier = "com.anthropic.claude-code"

    public static let supportedHostVariants: [ClaudeCodeTerminalHostVariant] = [
        ClaudeCodeTerminalHostVariant(
            id: "terminal",
            displayName: "Terminal",
            bundleIdentifier: "com.apple.Terminal"
        ),
        ClaudeCodeTerminalHostVariant(
            id: "iterm2",
            displayName: "iTerm2",
            bundleIdentifier: "com.googlecode.iterm2"
        ),
        ClaudeCodeTerminalHostVariant(
            id: "warp",
            displayName: "Warp",
            bundleIdentifier: "dev.warp.Warp"
        ),
        ClaudeCodeTerminalHostVariant(
            id: "ghostty",
            displayName: "Ghostty",
            bundleIdentifier: "com.mitchellh.ghostty"
        ),
        ClaudeCodeTerminalHostVariant(
            id: "kitty",
            displayName: "kitty",
            bundleIdentifier: "net.kovidgoyal.kitty"
        ),
        ClaudeCodeTerminalHostVariant(
            id: "alacritty",
            displayName: "Alacritty",
            bundleIdentifier: "org.alacritty"
        ),
        ClaudeCodeTerminalHostVariant(
            id: "wezterm",
            displayName: "WezTerm",
            bundleIdentifier: "com.github.wez.wezterm"
        )
    ]

    public static let supportedTerminalHosts: Set<String> = Set(
        supportedHostVariants.map(\.bundleIdentifier)
    )

    public static let proofMarker = "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF"

    public static func hostVariant(for bundleIdentifier: String) -> ClaudeCodeTerminalHostVariant? {
        supportedHostVariants.first { $0.bundleIdentifier == bundleIdentifier }
    }

    public static var proofProfile: CompatibilityProfile {
        CompatibilityProfile(
            bundleIdentifier: virtualBundleIdentifier,
            displayName: "Claude Code",
            appFamily: .customCanvas,
            supportLevel: .yellow,
            supportReason: "Claude Code can be proofed only through an explicit terminal-host proof lane.",
            renderMode: .inlineAdjacent,
            insertionMode: .clipboardFallbackOptIn,
            fallbackRenderMode: .floatingMirror,
            fallbackInsertionMode: nil,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.caret],
            knownFailureModes: [
                "terminal-hosted CLI input can submit shell commands",
                "terminal accessibility text can include scrollback instead of only the prompt line",
                "terminal hosts often ignore synthetic Unicode key events"
            ],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsOneWordAcceptance: true,
            supportsFullAcceptance: false,
            requiresNoSubmitAcceptanceProof: true,
            suppressesAfterInsertionFailure: true,
            allowsDetachedSuggestions: false,
            allowsSyntheticCaretPlacement: true,
            promptAppSafetyMode: .wordOnly,
            notes: "Proof-only virtual Claude Code profile. It may be used only when a supported terminal host is frontmost, Claude Code proof mode is active, the proof marker is present, and the current input line is not shell or agent output. It uses clipboard paste insertion through the terminal host's own Paste menu so one-word completion text can be accepted without submitting the prompt."
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

        let focusedTextHasProofMarker = context.focusedText.localizedCaseInsensitiveContains(proofMarker)

        if !focusedTextHasProofMarker,
           looksLikeMarkedMultilineBuffer(
               textBeforeCursor: context.rawTextBeforeCursor,
               textAfterCursor: context.rawTextAfterCursor
           ) {
            return .blocked(.multilineCommandDetected)
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

        if let line = nonEmptyLines.last,
           looksLikeActiveAgentOutput(line) {
            return .blocked(.activeAgentOutputDetected)
        }

        if let line = nonEmptyLines.last,
           looksLikeShellCommandInput(line) {
            return .blocked(.shellCommandDetected)
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

    private static func looksLikeShellCommandInput(_ line: String) -> Bool {
        guard let input = sanitizedProofInputLine(line) else {
            return false
        }

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
        guard !normalized.isEmpty else {
            return false
        }

        if ["./", "../", "~/", "/", "$(", "`"].contains(where: { normalized.hasPrefix($0) }) {
            return true
        }

        if [
            " && ",
            " || ",
            " | ",
            ";",
            " >",
            " <",
            "$(",
            "${"
        ].contains(where: { normalized.contains($0) }) {
            return true
        }

        let commandPrefixes = [
            "awk",
            "bash",
            "brew",
            "bun",
            "cat",
            "cd",
            "chmod",
            "chown",
            "cmake",
            "command",
            "cp",
            "curl",
            "docker",
            "env",
            "exec",
            "find",
            "gh",
            "git",
            "grep",
            "kubectl",
            "make",
            "mkdir",
            "mv",
            "node",
            "npm",
            "open",
            "osascript",
            "pnpm",
            "python",
            "python3",
            "rm",
            "rg",
            "rsync",
            "ruby",
            "scp",
            "sed",
            "ssh",
            "sudo",
            "swift",
            "time",
            "touch",
            "wget",
            "xcodebuild",
            "yarn"
        ]

        return commandPrefixes.contains { command in
            normalized == command || normalized.hasPrefix("\(command) ")
        }
    }

    private static func looksLikeActiveAgentOutput(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        let outputPrefixes = [
            "●",
            "⎿",
            "╭",
            "╰",
            "│",
            "┌",
            "└",
            "├",
            "─",
            "✻",
            "✽",
            "✶",
            "✢",
            "⏺"
        ]
        if outputPrefixes.contains(where: { trimmed.hasPrefix($0) }) {
            return true
        }

        if trimmed.localizedCaseInsensitiveContains(proofMarker) {
            return false
        }

        let lowered = trimmed.lowercased()
        if [
            "esc to interrupt",
            "ctrl-c",
            "ctrl+c",
            "interrupt",
            "thinking",
            "running",
            "tool use",
            "tokens",
            "context left"
        ].contains(where: { lowered.contains($0) }) {
            return true
        }

        let toolPrefixes = [
            "bash(",
            "edit(",
            "grep(",
            "glob(",
            "ls(",
            "read(",
            "todowrite(",
            "update("
        ]
        return toolPrefixes.contains { lowered.hasPrefix($0) }
    }

    private static func looksLikeMarkedMultilineBuffer(
        textBeforeCursor: String,
        textAfterCursor: String
    ) -> Bool {
        guard let markerRange = textBeforeCursor.range(
            of: proofMarker,
            options: [.caseInsensitive, .backwards]
        ) else {
            return false
        }

        return textBeforeCursor[markerRange.upperBound...].contains(where: \.isNewline)
            || textAfterCursor.contains(where: \.isNewline)
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
