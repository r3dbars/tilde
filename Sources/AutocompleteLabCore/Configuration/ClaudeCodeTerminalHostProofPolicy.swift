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

    public var manualProofCommand: String {
        "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-code --host \(id) --manual-gate"
    }
}

public enum ClaudeCodeTerminalHostProofPolicy {
    public static let virtualBundleIdentifier = "com.anthropic.claude-code"
    public static let proofFieldClassification = AXFieldClassification(
        kind: .multilineCompose,
        reason: "claude-code-terminal-host-proof"
    )

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
    private static let naturalLanguageCommandPhrases = [
        "make a",
        "make an",
        "make it",
        "make me",
        "make my",
        "make our",
        "make sure",
        "make the",
        "make this",
        "make transition",
        "make your"
    ]
    private static let naturalLanguageCommandGlueTolerantPhrases = [
        "make this",
        "make transition"
    ]

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
            notes: "Proof-only virtual Claude Code profile. It may be used only when a supported terminal host is frontmost, Claude Code proof mode is active, the proof marker is present, and the current input line is not shell or agent output. It prefers verified AX selected-text insertion, then verified Unicode key-event insertion, then verified hardware key-event insertion for typeable accepted text, so one-word completion text can be accepted without submitting the prompt."
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
            if recoveredMarkedTerminalScreenInputText(for: context) != nil {
                return .eligible
            }
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
        if containsProofMarker(beforeLine),
           shouldIgnoreTextAfterCursorForMarkedPromptLine(afterLine) {
            if looksLikeShellCommandInput(beforeLine),
               let currentMarkedSegment = currentMarkedPromptSegmentLine(
                textBeforeCursor: textBeforeCursor,
                textAfterCursor: textAfterCursor
               ) {
                return currentMarkedSegment
            }
            return beforeLine
        }

        let physicalLine = beforeLine + afterLine
        if !containsProofMarker(physicalLine),
           let wrappedLine = wrappedMarkedPromptInputLine(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor
           ) {
            return wrappedLine
        }

        if (!containsProofMarker(physicalLine) || looksLikeShellCommandInput(physicalLine)),
           let currentMarkedSegment = currentMarkedPromptSegmentLine(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor
           ) {
            return currentMarkedSegment
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
            if looksLikeShellCommandInput(beforeLine),
               let currentMarkedSegment = currentMarkedPromptSegmentLine(
                textBeforeCursor: textBeforeCursor,
                textAfterCursor: textAfterCursor
               ) {
                return sanitizedProofInputLine(currentMarkedSegment)
            }
            return sanitizedProofInputLine(beforeLine)
        }

        if let wrappedLine = wrappedMarkedPromptInputLine(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor
        ) {
            return sanitizedProofInputLine(wrappedLine)
        }

        let physicalLine = beforeLine + (lineFragments(textAfterCursor).first ?? "")
        if (!containsProofMarker(physicalLine) || looksLikeShellCommandInput(physicalLine)),
           let currentMarkedSegment = currentMarkedPromptSegmentLine(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor
           ) {
            return sanitizedProofInputLine(currentMarkedSegment)
        }

        return sanitizedProofInputLine(beforeLine)
    }

    public static func proofInputText(
        for context: ClaudeCodeTerminalHostProofContext
    ) -> String? {
        guard evaluate(context) == .eligible else {
            return nil
        }

        if let recoveredInput = recoveredMarkedTerminalScreenInputText(for: context) {
            return recoveredInput
        }

        if let beforeCursorInput = proofInputTextBeforeCursorOnly(
            textBeforeCursor: context.rawTextBeforeCursor,
            textAfterCursor: context.rawTextAfterCursor
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

    public static func effectiveFieldClassification(
        raw classification: AXFieldClassification,
        for context: ClaudeCodeTerminalHostProofContext
    ) -> AXFieldClassification {
        guard evaluate(context) == .eligible,
              proofInputText(for: context) != nil else {
            return classification
        }

        return proofFieldClassification
    }

    public static func diagnosticMetadata(
        for context: ClaudeCodeTerminalHostProofContext
    ) -> [String: String] {
        let focusedLine = effectiveFocusedInputLine(
            focusedText: context.focusedText,
            rawTextBeforeCursor: context.rawTextBeforeCursor,
            rawTextAfterCursor: context.rawTextAfterCursor
        )
        let beforeLine = lineFragments(context.rawTextBeforeCursor).last ?? ""
        let afterLine = lineFragments(context.rawTextAfterCursor).first ?? ""
        let recovery = recoveredMarkedTerminalScreenInputAnalysis(for: context)
        let recoveredInput = recovery.inputText
        let markerTailFragments = lastProofMarkerRange(in: context.rawTextBeforeCursor).map { markerRange in
            lineFragments(String(context.rawTextBeforeCursor[markerRange.lowerBound...]))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        } ?? []
        let recoveredPartialWordShape = recoveredInput.flatMap(PartialWordShape.from(textBeforeCursor:))

        return [
            "terminalProofFocusedLineChars": String(focusedLine.count),
            "terminalProofFocusedLineHasMarker": String(containsProofMarker(focusedLine)),
            "terminalProofFocusedLineKind": diagnosticLineKind(focusedLine, windowTitle: context.windowTitle),
            "terminalProofRawBeforeChars": String(context.rawTextBeforeCursor.count),
            "terminalProofRawBeforeHasMarker": String(containsProofMarker(context.rawTextBeforeCursor)),
            "terminalProofRawBeforeLastLineChars": String(beforeLine.count),
            "terminalProofRawBeforeLastLineHasMarker": String(containsProofMarker(beforeLine)),
            "terminalProofRawBeforeLastLineKind": diagnosticLineKind(beforeLine, windowTitle: context.windowTitle),
            "terminalProofRawAfterChars": String(context.rawTextAfterCursor.count),
            "terminalProofAfterFirstLineChars": String(afterLine.count),
            "terminalProofAfterFirstLineKind": diagnosticLineKind(afterLine, windowTitle: context.windowTitle),
            "terminalProofCanIgnoreAfterCursor": String(canIgnoreTerminalScreenTextAfterCursor(context.rawTextAfterCursor)),
            "terminalProofWindowTitleHasMarker": String(titleHasScopedProofMarker(context.windowTitle)),
            "terminalProofMarkerTailFragmentCount": String(markerTailFragments.count),
            "terminalProofMarkerTailFragmentsSafe": String(
                !markerTailFragments.isEmpty && markerTailFragments.allSatisfy(isSafeWrappedPromptFragment)
            ),
            "terminalProofRecoverableInput": String(recoveredInput != nil),
            "terminalProofRecoveryRejectionReason": recovery.rejectionReason,
            "terminalProofRecoveredBeforeChars": String(recoveredInput?.count ?? 0),
            "terminalProofRecoveredWordCount": String(recoveredInput?.split(whereSeparator: \.isWhitespace).count ?? 0),
            "terminalProofRecoveredPartialWordCharacters": String(recoveredPartialWordShape?.characterCount ?? 0),
            "terminalProofRecoveredPartialWordCasing": recoveredPartialWordShape?.casing.rawValue ?? PartialWordCasing.none.rawValue
        ]
    }

    private static func proofInputTextBeforeCursorOnly(
        textBeforeCursor: String,
        textAfterCursor: String
    ) -> String? {
        let beforeLine = lineFragments(textBeforeCursor).last ?? ""
        if containsProofMarker(beforeLine),
           looksLikeShellCommandInput(beforeLine),
           let currentMarkedSegment = currentMarkedPromptSegmentLine(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor
           ),
           let inputText = sanitizedProofInputLine(currentMarkedSegment) {
            return inputText
        }

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

        if looksLikeNaturalLanguageCommandPhrase(normalized) {
            return false
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

    private static func looksLikeNaturalLanguageCommandPhrase(_ normalized: String) -> Bool {
        if naturalLanguageCommandGlueTolerantPhrases.contains(where: { normalized.hasPrefix($0) }) {
            return true
        }

        return naturalLanguageCommandPhrases.contains { phrase in
            normalized == phrase || normalized.hasPrefix("\(phrase) ")
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

    private static func currentMarkedPromptSegmentLine(
        textBeforeCursor: String,
        textAfterCursor: String
    ) -> String? {
        guard safePromptTextAfterCursor(textAfterCursor),
              let markerRange = lastProofMarkerRange(in: textBeforeCursor) else {
            return nil
        }

        let markedSegment = String(textBeforeCursor[markerRange.lowerBound...])
        let fragments = lineFragments(markedSegment)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !fragments.isEmpty,
              fragments.contains(where: containsProofMarker),
              fragments.allSatisfy(isSafeWrappedPromptFragment) else {
            return nil
        }

        var line = fragments.joined(separator: " ")
        guard let inputText = sanitizedProofInputLine(line),
              !looksLikeShellCommandInput(inputText),
              !looksLikeTerminalShellCommandLine(inputText),
              !looksLikeActiveAgentOutput(inputText) else {
            return nil
        }

        let firstAfterLine = lineFragments(textAfterCursor).first ?? ""
        if firstAfterLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           firstAfterLine.contains(where: \.isWhitespace) {
            line += " "
        }
        return line
    }

    private static func recoveredMarkedTerminalScreenInputText(
        for context: ClaudeCodeTerminalHostProofContext
    ) -> String? {
        recoveredMarkedTerminalScreenInputAnalysis(for: context).inputText
    }

    private static func recoveredMarkedTerminalScreenInputAnalysis(
        for context: ClaudeCodeTerminalHostProofContext
    ) -> (inputText: String?, rejectionReason: String) {
        guard supportedTerminalHosts.contains(context.hostBundleIdentifier),
              context.proofModeEnabled else {
            return (nil, "unsupportedOrProofModeOff")
        }

        guard titleHasScopedProofMarker(context.windowTitle)
            || containsProofMarker(context.rawTextBeforeCursor) else {
            return (nil, "missingScopedMarker")
        }

        guard canIgnoreTerminalScreenTextAfterCursor(context.rawTextAfterCursor) else {
            return (nil, "afterCursorText")
        }

        guard let markerRange = lastProofMarkerRange(in: context.rawTextBeforeCursor) else {
            return (nil, "missingRawMarker")
        }

        let markedSegment = String(context.rawTextBeforeCursor[markerRange.lowerBound...])
        let fragments = lineFragments(markedSegment)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !fragments.isEmpty else {
            return (nil, "emptyMarkerTail")
        }

        guard fragments.contains(where: containsProofMarker) else {
            return (nil, "missingMarkerTail")
        }

        guard fragments.allSatisfy(isSafeWrappedPromptFragment) else {
            return (nil, "unsafeMarkerTail")
        }

        let line = fragments.joined(separator: " ")
        guard let inputText = sanitizedProofInputLine(line) else {
            return (nil, "emptySanitizedInput")
        }

        if let naturalInput = naturalLanguageProofInput(from: inputText) {
            return (naturalInput, "none")
        }

        if looksLikeShellCommandInput(inputText) {
            return (nil, "shellCommandInput")
        }

        if looksLikeTerminalShellCommandLine(inputText) {
            return (nil, "terminalShellCommandLine")
        }

        if looksLikeActiveAgentOutput(inputText) {
            return (nil, "activeAgentOutput")
        }

        return (inputText, "none")
    }

    private static func naturalLanguageProofInput(from inputText: String) -> String? {
        let stripped = inputText.strippingLeadingPromptResidue()
        let repairedStripped = repairingKnownDroppedProofSpaces(in: stripped)
        let normalized = repairedStripped.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if looksLikeNaturalLanguageCommandPhrase(normalized) {
            return repairedStripped
        }

        for phrase in naturalLanguageCommandPhrases {
            guard let range = inputText.range(of: phrase, options: [.caseInsensitive]) else {
                continue
            }

            let prefix = inputText[..<range.lowerBound]
            guard prefix.allSatisfy({ !$0.isLetter && !$0.isNumber && !$0.isNewline }) else {
                continue
            }

            let candidate = repairingKnownDroppedProofSpaces(in: String(inputText[range.lowerBound...]))
            let normalizedCandidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard looksLikeNaturalLanguageCommandPhrase(normalizedCandidate) else {
                continue
            }
            return candidate
        }

        return nil
    }

    private static func repairingKnownDroppedProofSpaces(in text: String) -> String {
        text
            .replacingOccurrences(of: "Make thissetting", with: "Make this setting")
            .replacingOccurrences(of: "make thissetting", with: "make this setting")
            .replacingOccurrences(of: "Make transitiontransi", with: "Make transition transi")
            .replacingOccurrences(of: "make transitiontransi", with: "make transition transi")
    }

    private static func canIgnoreTerminalScreenTextAfterCursor(_ textAfterCursor: String) -> Bool {
        if safePromptTextAfterCursor(textAfterCursor) {
            return true
        }

        guard textAfterCursor.contains(where: \.isNewline) else {
            return false
        }

        let firstFragment = lineFragments(textAfterCursor)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !firstFragment.isEmpty else {
            return true
        }

        return looksLikeClaudePromptChromeLine(firstFragment)
            || looksLikeActiveAgentOutput(firstFragment)
    }

    private static func safePromptTextAfterCursor(_ textAfterCursor: String) -> Bool {
        let firstFragment = lineFragments(textAfterCursor)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return firstFragment.isEmpty
            || isAllowedTrailingClaudePromptHint(firstFragment)
            || looksLikeClaudePromptChromeLine(firstFragment)
    }

    private static func shouldIgnoreTextAfterCursorForMarkedPromptLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        return isAllowedTrailingClaudePromptHint(trimmed)
            || looksLikeClaudePromptChromeLine(trimmed)
    }

    private static func looksLikeClaudePromptChromeLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        if ["╭", "╰", "│", "┌", "└", "├", "─"].contains(where: { trimmed.hasPrefix($0) }) {
            return true
        }

        let lowered = trimmed.lowercased()
        return lowered.contains("shortcuts")
            || lowered.contains("shift+tab")
    }

    private static func diagnosticLineKind(_ line: String, windowTitle: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "empty"
        }

        if looksLikeClaudePromptChromeLine(trimmed) {
            return "chrome"
        }

        if looksLikeActiveAgentOutput(trimmed) {
            return "agentOutput"
        }

        if containsProofMarker(trimmed) {
            return "marked"
        }

        if looksLikeShellPrompt(trimmed, windowTitle: windowTitle) {
            return "shellPrompt"
        }

        if looksLikeShellCommandInput(trimmed)
            || looksLikeTerminalShellCommandLine(trimmed) {
            return "shellCommand"
        }

        return "text"
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

    func strippingLeadingPromptResidue() -> String {
        var text = trimmingLeadingWhitespace()
        while let first = text.first,
              ["❯", ">", "%", "$", "#"].contains(String(first)) {
            text.removeFirst()
            text = text.trimmingLeadingWhitespace()
        }
        return text
    }
}
