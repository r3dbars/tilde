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
    public static let compactProofMarker = "STEADYTYPECLAUDECODEPROOF"
    private static let proofMarkers = [proofMarker, compactProofMarker]

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

        let focusedLine = effectiveFocusedInputLine(
            focusedText: context.focusedText,
            rawTextBeforeCursor: context.rawTextBeforeCursor,
            rawTextAfterCursor: context.rawTextAfterCursor
        )
        let focusedTextHasProofMarker = containsProofMarker(focusedLine)
        let titleHasProofMarker = titleHasScopedProofMarker(context.windowTitle)

        if !focusedTextHasProofMarker,
           !titleHasProofMarker,
           looksLikeMarkedMultilineBuffer(
               textBeforeCursor: context.rawTextBeforeCursor,
               textAfterCursor: context.rawTextAfterCursor
           ) {
            return .blocked(.multilineCommandDetected)
        }

        let searchableText = [
            context.windowTitle,
            focusedLine,
            context.focusedText
        ].joined(separator: "\n")

        guard containsProofMarker(searchableText) else {
            return .blocked(.missingProofMarker)
        }

        let nonEmptyLines = focusedLine
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
        let beforeLine = lineFragments(textBeforeCursor).last ?? ""
        let afterLine = lineFragments(textAfterCursor).first ?? ""
        let physicalLine = beforeLine + afterLine
        if !containsProofMarker(physicalLine),
           let wrappedLine = wrappedMarkedPromptInputLine(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor
           ) {
            return wrappedLine
        }

        return physicalLine
    }

    public static func proofInputText(
        textBeforeCursor: String,
        textAfterCursor: String
    ) -> String? {
        guard safePromptTextAfterCursor(textAfterCursor) else {
            return nil
        }

        let beforeLine = lineFragments(textBeforeCursor).last ?? ""
        if containsProofMarker(beforeLine) {
            return sanitizedProofInputLine(beforeLine)
        }

        if let wrappedLine = wrappedMarkedPromptInputLine(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor
        ) {
            return sanitizedProofInputLine(wrappedLine)
        }

        return sanitizedProofInputLine(beforeLine)
    }

    public static func proofInputText(
        for context: ClaudeCodeTerminalHostProofContext
    ) -> String? {
        guard evaluate(context) == .eligible else {
            return nil
        }

        if let beforeCursorInput = proofInputTextBeforeCursorOnly(
            textBeforeCursor: context.rawTextBeforeCursor
        ) {
            return beforeCursorInput
        }

        let focusedLine = effectiveFocusedInputLine(
            focusedText: context.focusedText,
            rawTextBeforeCursor: context.rawTextBeforeCursor,
            rawTextAfterCursor: context.rawTextAfterCursor
        )
        if let focusedInputText = sanitizedProofInputLine(focusedLine) {
            return focusedInputText
        }

        return proofInputText(
            textBeforeCursor: context.rawTextBeforeCursor,
            textAfterCursor: context.rawTextAfterCursor
        )
    }

    private static func proofInputTextBeforeCursorOnly(
        textBeforeCursor: String
    ) -> String? {
        let beforeLine = lineFragments(textBeforeCursor).last ?? ""
        if containsProofMarker(beforeLine),
           let inputText = sanitizedProofInputLine(beforeLine) {
            return inputText
        }

        if let wrappedLine = wrappedMarkedPromptInputLine(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: ""
        ),
           let inputText = sanitizedProofInputLine(wrappedLine) {
            return inputText
        }

        return sanitizedProofInputLine(beforeLine)
    }

    public static func sanitizedProofInputLine(_ line: String) -> String? {
        var text = line.trimmingCharacters(in: .newlines)
        text = text.trimmingLeadingWhitespace()

        if text.hasPrefix("❯") {
            text.removeFirst()
            text = text.trimmingLeadingWhitespace()
        }

        text = removingProofMarkers(from: text)
            .trimmingLeadingWhitespace()
        text = removingLeadingNumberedPromptDecoration(from: text)
            .trimmingLeadingWhitespace()
        while text.contains("  ") {
            text = text.replacingOccurrences(of: "  ", with: " ")
        }

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

    private static func removingLeadingNumberedPromptDecoration(from text: String) -> String {
        var index = text.startIndex
        var digitCount = 0
        while index < text.endIndex,
              text[index].isNumber,
              digitCount < 2 {
            digitCount += 1
            index = text.index(after: index)
        }

        guard digitCount > 0,
              index < text.endIndex,
              text[index] == "." else {
            return text
        }

        let afterDot = text.index(after: index)
        guard afterDot < text.endIndex,
              text[afterDot].isWhitespace else {
            return text
        }

        return String(text[afterDot...]).trimmingLeadingWhitespace()
    }

    private static func looksLikeShellPrompt(_ line: String, windowTitle: String) -> Bool {
        let shellPrefixes = ["$", "%", "#", "❯", "➜"]
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("❯"),
           (containsProofMarker(trimmed)
            || windowTitle.localizedCaseInsensitiveContains("Claude Code")
            && containsProofMarker(windowTitle)) {
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

        if containsProofMarker(trimmed) {
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
        guard let markerRange = lastProofMarkerRange(in: textBeforeCursor) else {
            return false
        }

        return textBeforeCursor[markerRange.upperBound...].contains(where: \.isNewline)
            || textAfterCursor.contains(where: \.isNewline)
    }

    private static func looksLikePlaceholderPrompt(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        return trimmed.hasPrefix("Try \"")
            || trimmed.hasPrefix("Try '")
            || lowered == "for shortcuts"
            || lowered.hasSuffix(" for shortcuts")
    }

    private static func titleHasScopedProofMarker(_ title: String) -> Bool {
        title.localizedCaseInsensitiveContains("Claude Code")
            && containsProofMarker(title)
    }

    private static func effectiveFocusedInputLine(
        focusedText: String,
        rawTextBeforeCursor: String,
        rawTextAfterCursor: String
    ) -> String {
        let focusedFragments = lineFragments(focusedText)
        if focusedFragments.count <= 1 {
            return focusedText
        }

        if let markedFocusedLine = lastMarkedPromptLine(in: focusedText) {
            return markedFocusedLine
        }

        if !rawTextBeforeCursor.isEmpty || !rawTextAfterCursor.isEmpty {
            return focusedInputLine(
                textBeforeCursor: rawTextBeforeCursor,
                textAfterCursor: rawTextAfterCursor
            )
        }

        return focusedText
    }

    private static func lastMarkedPromptLine(in text: String) -> String? {
        let fragments = lineFragments(text)
        for index in fragments.indices.reversed() {
            let line = fragments[index]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  containsProofMarker(trimmed) else {
                continue
            }

            let trailingLines = fragments[(index + 1)...]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if trailingLines.allSatisfy(isAllowedTrailingClaudePromptHint) {
                return line
            }
        }
        return nil
    }

    private static func isAllowedTrailingClaudePromptHint(_ line: String) -> Bool {
        let lowered = line.lowercased()
        return lowered == "? for shortcuts"
            || lowered.hasSuffix(" for shortcuts")
            || lowered.contains("shortcuts")
            || lowered.contains("shift+tab")
    }

    private static func wrappedMarkedPromptInputLine(
        textBeforeCursor: String,
        textAfterCursor: String
    ) -> String? {
        guard safePromptTextAfterCursor(textAfterCursor),
              let markerRange = lastProofMarkerRange(in: textBeforeCursor) else {
            return nil
        }

        let textBeforeMarker = String(textBeforeCursor[..<markerRange.lowerBound])
        let promptPrefix = lineFragments(textBeforeMarker).last ?? ""
        let trimmedPromptPrefix = promptPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard promptPrefixAllowsProofMarker(trimmedPromptPrefix) else {
            return nil
        }

        let markedSegment = promptPrefix + String(textBeforeCursor[markerRange.lowerBound...])
        let fragments = lineFragments(markedSegment)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !fragments.isEmpty,
              fragments.contains(where: containsProofMarker),
              fragments.allSatisfy(isSafeWrappedPromptFragment) else {
            return nil
        }

        var line = fragments.joined(separator: " ")
        let firstAfterLine = lineFragments(textAfterCursor).first ?? ""
        if firstAfterLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           firstAfterLine.contains(where: \.isWhitespace) {
            line += " "
        }
        return line
    }

    private static func safePromptTextAfterCursor(_ textAfterCursor: String) -> Bool {
        let firstFragment = lineFragments(textAfterCursor)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return firstFragment.isEmpty
            || isAllowedTrailingClaudePromptHint(firstFragment)
    }

    private static func promptPrefixAllowsProofMarker(_ prefix: String) -> Bool {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "❯" {
            return true
        }

        if trimmed.hasPrefix("❯") {
            let remainder = trimmed.dropFirst()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return !remainder.isEmpty
                && !looksLikeShellCommandInput(String(remainder))
                && !looksLikeTerminalShellCommandLine(String(remainder))
                && !looksLikeActiveAgentOutput(String(remainder))
        }

        if trimmed.hasPrefix("$")
            || trimmed.hasPrefix("%")
            || trimmed.hasPrefix("#")
            || trimmed.hasPrefix("➜") {
            return false
        }

        if looksLikeActiveAgentOutput(trimmed)
            || looksLikeShellCommandInput(trimmed)
            || looksLikeTerminalShellCommandLine(trimmed) {
            return false
        }

        return true
    }

    private static func looksLikeTerminalShellCommandLine(_ line: String) -> Bool {
        let lowered = line.lowercased()
        for prompt in [" % ", " $ ", " # "] {
            guard let range = lowered.range(of: prompt) else {
                continue
            }

            let commandText = String(lowered[range.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if commandText.contains(";")
                || commandText.contains("printf")
                || looksLikeShellCommandInput(commandText) {
                return true
            }
        }

        return false
    }

    private static func isSafeWrappedPromptFragment(_ fragment: String) -> Bool {
        if looksLikeActiveAgentOutput(fragment) {
            return false
        }

        let trimmed = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return true
        }

        if trimmed.hasPrefix("$")
            || trimmed.hasPrefix("%")
            || trimmed.hasPrefix("#")
            || trimmed.hasPrefix("➜") {
            return false
        }

        if trimmed.hasPrefix("❯"),
           !containsProofMarker(trimmed) {
            return false
        }

        return true
    }

    public static func containsProofMarker(_ text: String) -> Bool {
        proofMarkers.contains { marker in
            text.localizedCaseInsensitiveContains(marker)
        }
    }

    private static func lastProofMarkerRange(in text: String) -> Range<String.Index>? {
        proofMarkers
            .compactMap { marker in
                text.range(of: marker, options: [.caseInsensitive, .backwards])
            }
            .max { lhs, rhs in lhs.lowerBound < rhs.lowerBound }
    }

    private static func removingProofMarkers(from text: String) -> String {
        proofMarkers.reduce(text) { partialText, marker in
            partialText.replacingOccurrences(
                of: marker,
                with: "",
                options: [.caseInsensitive]
            )
        }
    }

    private static func lineFragments(_ text: String) -> [String] {
        var fragments = [""]
        for character in text {
            if character.isNewline {
                fragments.append("")
            } else {
                fragments[fragments.count - 1].append(character)
            }
        }
        return fragments
    }
}

private extension String {
    func trimmingLeadingWhitespace() -> String {
        String(drop { $0.isWhitespace && !$0.isNewline })
    }
}
