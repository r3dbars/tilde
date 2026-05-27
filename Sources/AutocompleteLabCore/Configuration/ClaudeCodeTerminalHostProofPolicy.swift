import Foundation

public struct ClaudeCodeTerminalHostProofContext: Equatable, Sendable {
    public let hostBundleIdentifier: String
    public let windowTitle: String
    public let focusedText: String
    public let rawTextBeforeCursor: String
    public let rawTextAfterCursor: String
    public let terminalScreenText: String
    public let proofModeEnabled: Bool

    public init(
        hostBundleIdentifier: String,
        windowTitle: String,
        focusedText: String,
        rawTextBeforeCursor: String = "",
        rawTextAfterCursor: String = "",
        terminalScreenText: String = "",
        proofModeEnabled: Bool
    ) {
        self.hostBundleIdentifier = hostBundleIdentifier
        self.windowTitle = windowTitle
        self.focusedText = focusedText
        self.rawTextBeforeCursor = rawTextBeforeCursor
        self.rawTextAfterCursor = rawTextAfterCursor
        self.terminalScreenText = terminalScreenText
        self.proofModeEnabled = proofModeEnabled
    }
}

public struct ClaudeCodeTerminalScreenPromptAnchor: Equatable, Sendable {
    public let inputText: String
    public let promptLineInputText: String
    public let lineIndex: Int
    public let lineCount: Int

    public init(
        inputText: String,
        promptLineInputText: String,
        lineIndex: Int,
        lineCount: Int
    ) {
        self.inputText = inputText
        self.promptLineInputText = promptLineInputText
        self.lineIndex = lineIndex
        self.lineCount = lineCount
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

    public static func shouldPreserveVisibleSuggestionAfterPassthroughKeyDown(
        currentSuggestionBundleIdentifier: String?,
        profileBundleIdentifier: String?,
        fieldClassification: AXFieldClassification?,
        hasVisibleSuggestion: Bool
    ) -> Bool {
        _ = profileBundleIdentifier
        return hasVisibleSuggestion
            && currentSuggestionBundleIdentifier == virtualBundleIdentifier
            && fieldClassification == proofFieldClassification
    }

    public static func shouldBridgePassthroughAfterVolatileSnapshot(
        currentSuggestionBundleIdentifier: String?,
        profileBundleIdentifier: String?,
        fieldClassification: AXFieldClassification?,
        hasVisibleSuggestion: Bool,
        supportsOneWordAcceptance: Bool,
        supportsFullAcceptance: Bool,
        requiresNoSubmitAcceptanceProof: Bool,
        insertionMode: InsertionMode?
    ) -> Bool {
        shouldPreserveVisibleSuggestionAfterPassthroughKeyDown(
            currentSuggestionBundleIdentifier: currentSuggestionBundleIdentifier,
            profileBundleIdentifier: profileBundleIdentifier,
            fieldClassification: fieldClassification,
            hasVisibleSuggestion: hasVisibleSuggestion
        )
            && profileBundleIdentifier == virtualBundleIdentifier
            && supportsOneWordAcceptance
            && !supportsFullAcceptance
            && requiresNoSubmitAcceptanceProof
            && insertionMode == .clipboardFallbackOptIn
    }

    public static func shouldPreferFastPasteboardInsertion(
        hostBundleIdentifier: String?,
        insertionMode: InsertionMode?,
        requiresNoSubmitAcceptanceProof: Bool
    ) -> Bool {
        hostBundleIdentifier == "com.mitchellh.ghostty"
            && insertionMode == .clipboardFallbackOptIn
            && requiresNoSubmitAcceptanceProof
    }

    public static func requiresTerminalScreenPromptCaret(
        hostBundleIdentifier: String?
    ) -> Bool {
        hostBundleIdentifier == "com.mitchellh.ghostty"
    }

    public static func shouldPreservePendingRequestDuringFocusedTextPollingThrottle(
        pendingRequestAppBundleIdentifier: String?,
        pendingRequestTextBeforeCursor: String?,
        pendingRequestTextAfterCursor: String?,
        pendingRequestFieldKind: AXFieldKind?,
        pendingRequestMode: CompletionRequestMode?,
        currentProfileBundleIdentifier: String?,
        currentTextBeforeCursor: String?,
        currentTextAfterCursor: String?
    ) -> Bool {
        guard pendingRequestAppBundleIdentifier == virtualBundleIdentifier,
              currentProfileBundleIdentifier == virtualBundleIdentifier,
              pendingRequestFieldKind == proofFieldClassification.kind,
              pendingRequestMode == .phraseContinuation,
              let pendingRequestTextBeforeCursor,
              let pendingRequestTextAfterCursor,
              let currentTextBeforeCursor,
              let currentTextAfterCursor,
              pendingRequestTextBeforeCursor == currentTextBeforeCursor,
              pendingRequestTextAfterCursor == currentTextAfterCursor,
              pendingRequestTextAfterCursor.isEmpty else {
            return false
        }

        return allowsPreviouslyVerifiedSensitiveActivationBypass(
            proofInputText: pendingRequestTextBeforeCursor
        )
    }

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
            rawTextAfterCursor: context.rawTextAfterCursor,
            terminalScreenText: context.terminalScreenText
        )
        let focusedTextHasProofMarker = containsProofMarker(focusedLine)
        let titleHasProofMarker = titleHasScopedProofMarker(context.windowTitle)

        if (focusedTextHasProofMarker || containsProofMarker(context.rawTextBeforeCursor)),
           hasUnsafeTerminalRowsAfterCursor(context.rawTextAfterCursor) {
            return .blocked(.multilineCommandDetected)
        }

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
            context.focusedText,
            context.terminalScreenText
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
            if recoveredMarkedTerminalScreenInputText(for: context) != nil {
                return .eligible
            }
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

        if shouldIgnoreTextAfterCursorForMarkedPromptLine(afterLine),
           !beforeLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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

        if shouldIgnoreTextAfterCursorForMarkedPromptLine(lineFragments(textAfterCursor).first ?? ""),
           let inputText = sanitizedProofInputLine(beforeLine),
           !looksLikeShellCommandInput(inputText),
           !looksLikeTerminalShellCommandLine(inputText),
           !looksLikeActiveAgentOutput(inputText) {
            return inputText
        }

        if containsProofMarker(textBeforeCursor),
           !containsProofMarker(beforeLine) {
            return nil
        }

        return sanitizedProofInputLine(beforeLine)
    }

    public static func proofInputText(
        for context: ClaudeCodeTerminalHostProofContext
    ) -> String? {
        guard evaluate(context) == .eligible else {
            return nil
        }

        let directInputText = [
            context.focusedText,
            context.rawTextBeforeCursor,
            context.rawTextAfterCursor
        ].joined(separator: "\n")
        if !containsProofMarker(directInputText),
           let screenInputText = titleScopedTerminalScreenInputText(for: context) {
            return screenInputText
        }

        if !containsProofMarker(directInputText),
           let screenPromptAnchor = terminalScreenPromptAnchor(for: context) {
            return screenPromptAnchor.inputText
        }

        if let recoveredInput = recoveredMarkedTerminalScreenInputText(for: context) {
            return recoveredInput
        }

        if !containsProofMarker(directInputText) {
            if titleHasScopedProofMarker(context.windowTitle) {
                guard titleScopedInputLooksCompleteEnough(for: context) else {
                    return nil
                }
            } else if containsProofMarker(context.terminalScreenText) {
                return nil
            }
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
            rawTextAfterCursor: context.rawTextAfterCursor,
            terminalScreenText: context.terminalScreenText
        )
        if let focusedInputText = sanitizedProofInputLine(focusedLine) {
            return focusedInputText
        }

        return proofInputText(
            textBeforeCursor: context.rawTextBeforeCursor,
            textAfterCursor: context.rawTextAfterCursor
        )
    }

    private static func titleScopedInputLooksCompleteEnough(
        for context: ClaudeCodeTerminalHostProofContext
    ) -> Bool {
        [
            proofInputTextBeforeCursorOnly(
                textBeforeCursor: context.rawTextBeforeCursor,
                textAfterCursor: context.rawTextAfterCursor
            ),
            sanitizedProofInputLine(context.focusedText)
        ]
        .compactMap { $0 }
        .contains { inputText in
            let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            return safeTitleScopedPromptInputLine(trimmed) != nil
                && !looksLikeTitleScopedTerminalChromeOrStaleHeader(trimmed)
        }
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

    public static func allowsSensitiveActivationBypass(
        for context: ClaudeCodeTerminalHostProofContext,
        proofInputText currentProofInputText: String
    ) -> Bool {
        guard evaluate(context) == .eligible,
              let proofInputText = proofInputText(for: context) else {
            return false
        }

        let normalizedProofInput = normalizedComparableProofInput(proofInputText)
        let normalizedCurrentInput = normalizedComparableProofInput(currentProofInputText)
        guard !normalizedProofInput.isEmpty,
              normalizedProofInput == normalizedCurrentInput else {
            return false
        }

        return allowsPreviouslyVerifiedSensitiveActivationBypass(
            proofInputText: currentProofInputText
        )
    }

    public static func allowsPreviouslyVerifiedSensitiveActivationBypass(
        proofInputText currentProofInputText: String
    ) -> Bool {
        let normalizedCurrentInput = normalizedComparableProofInput(currentProofInputText)
        guard !normalizedCurrentInput.isEmpty,
              normalizedCurrentInput.split(whereSeparator: \.isWhitespace).count >= 3,
              !containsIncompleteProofMarkerFragment(currentProofInputText),
              !looksLikeShellCommandInput(currentProofInputText),
              !looksLikeTerminalShellCommandLine(currentProofInputText),
              !looksLikeActiveAgentOutput(currentProofInputText) else {
            return false
        }

        return looksLikeNaturalLanguageCommandPhrase(normalizedCurrentInput)
            || safeTitleScopedPromptInputLine(currentProofInputText) != nil
    }

    public static func diagnosticMetadata(
        for context: ClaudeCodeTerminalHostProofContext
    ) -> [String: String] {
        let focusedLine = effectiveFocusedInputLine(
            focusedText: context.focusedText,
            rawTextBeforeCursor: context.rawTextBeforeCursor,
            rawTextAfterCursor: context.rawTextAfterCursor,
            terminalScreenText: context.terminalScreenText
        )
        let beforeLine = lineFragments(context.rawTextBeforeCursor).last ?? ""
        let afterLine = lineFragments(context.rawTextAfterCursor).first ?? ""
        let recovery = recoveredMarkedTerminalScreenInputAnalysis(for: context)
        let recoveredInput = recovery.inputText
        let titleScopedScreenInput = titleScopedTerminalScreenInputText(for: context)
        let screenPromptAnchor = terminalScreenPromptAnchor(for: context)
        let screenRecoveryShape = terminalScreenRecoveryDiagnosticShape(for: context)
        let markerTailFragments = lastProofMarkerRange(in: context.rawTextBeforeCursor).map { markerRange in
            lineFragments(String(context.rawTextBeforeCursor[markerRange.lowerBound...]))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        } ?? []
        let recoveredPartialWordShape = recoveredInput.flatMap(PartialWordShape.from(textBeforeCursor:))

        var metadata: [String: String] = [
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
            "terminalProofScreenChars": String(context.terminalScreenText.count),
            "terminalProofScreenHasMarker": String(containsProofMarker(context.terminalScreenText)),
            "terminalProofCanIgnoreAfterCursor": String(canIgnoreTerminalScreenTextAfterCursor(context.rawTextAfterCursor)),
            "terminalProofWindowTitleHasMarker": String(titleHasScopedProofMarker(context.windowTitle)),
            "terminalProofMarkerTailFragmentCount": String(markerTailFragments.count),
            "terminalProofMarkerTailFragmentsSafe": String(
                !markerTailFragments.isEmpty && markerTailFragments.allSatisfy(isSafeWrappedPromptFragment)
            ),
            "terminalProofRecoverableInput": String(recoveredInput != nil),
            "terminalProofRecoveryRejectionReason": recovery.rejectionReason,
            "terminalProofTitleScopedScreenRecoverable": String(titleScopedScreenInput != nil),
            "terminalProofTitleScopedScreenBeforeChars": String(titleScopedScreenInput?.count ?? 0),
            "terminalProofTitleScopedScreenCurrentContextMatched": String(
                screenRecoveryShape.headerScopedMarker && titleScopedScreenInput != nil
            ),
            "terminalProofHeaderScopedCurrentMatch": String(
                screenRecoveryShape.headerScopedMarker && titleScopedScreenInput != nil
            ),
            "terminalProofScreenPromptAnchorRecoverable": String(screenPromptAnchor != nil),
            "terminalProofScreenPromptAnchorInputChars": String(screenPromptAnchor?.inputText.count ?? 0),
            "terminalProofScreenPromptAnchorLineInputChars": String(screenPromptAnchor?.promptLineInputText.count ?? 0),
            "terminalProofScreenPromptAnchorLineIndex": String(screenPromptAnchor?.lineIndex ?? -1),
            "terminalProofScreenPromptAnchorLineCount": String(screenPromptAnchor?.lineCount ?? 0),
            "terminalProofRecoveredBeforeChars": String(recoveredInput?.count ?? 0),
            "terminalProofRecoveredWordCount": String(recoveredInput?.split(whereSeparator: \.isWhitespace).count ?? 0),
            "terminalProofRecoveredPartialWordCharacters": String(recoveredPartialWordShape?.characterCount ?? 0),
            "terminalProofRecoveredPartialWordCasing": recoveredPartialWordShape?.casing.rawValue ?? PartialWordCasing.none.rawValue
        ]
        metadata.merge(screenRecoveryShape.metadata) { _, newValue in newValue }
        return metadata
    }

    private struct TerminalScreenRecoveryDiagnosticShape {
        let currentSuffixCandidateCount: Int
        let currentSuffixMaxWordCount: Int
        let currentSuffixHasShellCommand: Bool
        let headerScopedMarker: Bool
        let promptSegmentPresent: Bool
        let recoveryTriedCandidates: Int
        let recoveryWouldRecover: Bool
        let recoveryMatchedCandidateIndex: Int
        let mismatchCount: Int
        let tooShortCount: Int
        let missingScopedMarkerCount: Int
        let afterCursorCount: Int
        let unsafeTailCount: Int
        let otherCount: Int

        var metadata: [String: String] {
            [
                "terminalProofScreenCurrentSuffixCandidateCount": String(currentSuffixCandidateCount),
                "terminalProofScreenCurrentSuffixMaxWords": String(currentSuffixMaxWordCount),
                "terminalProofScreenCurrentSuffixHasShellCommand": String(currentSuffixHasShellCommand),
                "terminalProofScreenHeaderScopedMarker": String(headerScopedMarker),
                "terminalProofScreenPromptSegmentPresent": String(promptSegmentPresent),
                "terminalProofScreenSegmentPresent": String(promptSegmentPresent),
                "terminalProofScreenRecoveryTriedCandidates": String(recoveryTriedCandidates),
                "terminalProofScreenRecoveryWouldRecover": String(recoveryWouldRecover),
                "terminalProofScreenRecoveryMatchedCandidateIndex": String(recoveryMatchedCandidateIndex),
                "terminalProofScreenRecoveryMismatchCount": String(mismatchCount),
                "terminalProofScreenRecoveryTooShortCount": String(tooShortCount),
                "terminalProofScreenRecoveryMissingScopedMarkerCount": String(missingScopedMarkerCount),
                "terminalProofScreenRecoveryAfterCursorCount": String(afterCursorCount),
                "terminalProofScreenRecoveryUnsafeTailCount": String(unsafeTailCount),
                "terminalProofScreenRecoveryOtherCount": String(otherCount)
            ]
        }
    }

    private static func terminalScreenRecoveryDiagnosticShape(
        for context: ClaudeCodeTerminalHostProofContext
    ) -> TerminalScreenRecoveryDiagnosticShape {
        let candidates = terminalScreenCurrentInputSuffixCandidates(for: context)
        var triedCandidates = 0
        var wouldRecover = false
        var matchedCandidateIndex = -1
        var mismatchCount = 0
        var tooShortCount = 0
        var missingScopedMarkerCount = 0
        var afterCursorCount = 0
        var unsafeTailCount = 0
        var otherCount = 0

        for (index, candidate) in candidates.enumerated() {
            triedCandidates += 1
            let analysis = recoveredMarkedTerminalScreenInputAnalysis(
                hostBundleIdentifier: context.hostBundleIdentifier,
                proofModeEnabled: context.proofModeEnabled,
                windowTitle: context.windowTitle,
                textBeforeCursor: context.terminalScreenText,
                textAfterCursor: "",
                currentInputSuffix: candidate
            )
            if analysis.inputText != nil {
                wouldRecover = true
                matchedCandidateIndex = index
                break
            }

            switch analysis.rejectionReason {
            case "screenCurrentInputMismatch":
                mismatchCount += 1
            case "screenRecoveredInputTooShort":
                tooShortCount += 1
            case "missingScopedMarker", "missingRawMarker", "missingMarkerTail":
                missingScopedMarkerCount += 1
            case "afterCursorText":
                afterCursorCount += 1
            case "unsafeMarkerTail":
                unsafeTailCount += 1
            default:
                otherCount += 1
            }
        }

        return TerminalScreenRecoveryDiagnosticShape(
            currentSuffixCandidateCount: candidates.count,
            currentSuffixMaxWordCount: candidates
                .map { $0.split(whereSeparator: \.isWhitespace).count }
                .max() ?? 0,
            currentSuffixHasShellCommand: candidates.contains { candidate in
                looksLikeShellCommandInput(candidate)
                    || looksLikeTerminalShellCommandLine(candidate)
            },
            headerScopedMarker: terminalScreenHasScopedProofHeaderMarker(context.terminalScreenText),
            promptSegmentPresent: recoveredMarkedTerminalScreenPromptSegment(in: context.terminalScreenText) != nil,
            recoveryTriedCandidates: triedCandidates,
            recoveryWouldRecover: wouldRecover,
            recoveryMatchedCandidateIndex: matchedCandidateIndex,
            mismatchCount: mismatchCount,
            tooShortCount: tooShortCount,
            missingScopedMarkerCount: missingScopedMarkerCount,
            afterCursorCount: afterCursorCount,
            unsafeTailCount: unsafeTailCount,
            otherCount: otherCount
        )
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

        if containsProofMarker(textBeforeCursor),
           !containsProofMarker(beforeLine) {
            return nil
        }

        return sanitizedProofInputLine(beforeLine)
    }

    private static func normalizedComparableProofInput(_ text: String) -> String {
        var normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        while normalized.contains("  ") {
            normalized = normalized.replacingOccurrences(of: "  ", with: " ")
        }
        return normalized
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
        rawTextAfterCursor: String,
        terminalScreenText: String = ""
    ) -> String {
        var candidates: [String] = []
        if !rawTextBeforeCursor.isEmpty || !rawTextAfterCursor.isEmpty {
            candidates.append(focusedInputLine(
                textBeforeCursor: rawTextBeforeCursor,
                textAfterCursor: rawTextAfterCursor
            ))
        }

        let focusedFragments = lineFragments(focusedText)
        if let markedFocusedLine = lastMarkedPromptLine(in: focusedText) {
            candidates.append(markedFocusedLine)
        }
        candidates.append(focusedText)

        if let markedCandidate = candidates.first(where: containsProofMarker) {
            return markedCandidate
        }

        if !terminalScreenText.isEmpty,
           let markedScreenLine = recoveredMarkedTerminalScreenInputLine(
            terminalScreenText: terminalScreenText,
            currentInputSuffix: rawTextBeforeCursor
           ) {
            return markedScreenLine
        }

        if focusedFragments.count <= 1 {
            return candidates.first ?? focusedText
        }

        return candidates.last ?? focusedText
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
            if trailingLines.allSatisfy(isAllowedTrailingClaudePromptTrailer) {
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

    private static func isAllowedTrailingClaudePromptTrailer(_ line: String) -> Bool {
        isAllowedTrailingClaudePromptHint(line)
            || looksLikeClaudePromptChromeLine(line)
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

    public static func terminalScreenPromptAnchor(
        for context: ClaudeCodeTerminalHostProofContext
    ) -> ClaudeCodeTerminalScreenPromptAnchor? {
        guard context.hostBundleIdentifier == "com.mitchellh.ghostty",
              context.proofModeEnabled else {
            return nil
        }

        if !context.terminalScreenText.isEmpty,
           containsProofMarker(context.terminalScreenText),
           let promptSegment = recoveredMarkedTerminalScreenPromptSegmentLocation(
            in: context.terminalScreenText
           ) {
            let recovery = recoveredMarkedTerminalPromptInputAnalysis(from: promptSegment.text)
            if let inputText = recovery.inputText {
                let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedInput.split(whereSeparator: \.isWhitespace).count >= 3,
                   !hasUnscopedStaleHeaderDirectText(for: context),
                   !hasConflictingDirectCurrentPromptCandidate(inputText, for: context) {
                    let lineInputText = sanitizedProofInputLine(promptSegment.markedLine) ?? inputText
                    return ClaudeCodeTerminalScreenPromptAnchor(
                        inputText: inputText,
                        promptLineInputText: lineInputText,
                        lineIndex: promptSegment.lineIndex,
                        lineCount: promptSegment.lineCount
                    )
                }
            }
        }

        return titleScopedTerminalScreenPromptAnchor(for: context)
            ?? titleScopedDirectPromptAnchor(for: context)
    }

    private static func hasUnscopedStaleHeaderDirectText(
        for context: ClaudeCodeTerminalHostProofContext
    ) -> Bool {
        guard !titleHasScopedProofMarker(context.windowTitle),
              !terminalScreenHasScopedProofHeaderMarker(context.terminalScreenText) else {
            return false
        }

        let firstAfterLine = lineFragments(context.rawTextAfterCursor).first ?? ""
        return [
            firstAfterLine,
            context.focusedText
        ].contains { line in
            looksLikeTitleScopedTerminalChromeOrStaleHeader(
                line.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    private static func hasConflictingDirectCurrentPromptCandidate(
        _ inputText: String,
        for context: ClaudeCodeTerminalHostProofContext
    ) -> Bool {
        let firstAfterLine = lineFragments(context.rawTextAfterCursor).first ?? ""
        if !context.rawTextBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let beforeCursorCandidate = sanitizedCurrentInputSuffix(context.rawTextBeforeCursor),
           !terminalScreenInput(inputText, matchesCurrentSuffix: beforeCursorCandidate) {
            return true
        }

        let directCandidates = [
            sanitizedCurrentInputSuffix(firstAfterLine),
            sanitizedCurrentInputSuffix(context.focusedText)
        ].compactMap { $0 }

        return directCandidates.contains { candidate in
            !terminalScreenInput(inputText, matchesCurrentSuffix: candidate)
                && isPlausibleDirectCurrentPromptCandidate(candidate)
        }
    }

    private static func isPlausibleDirectCurrentPromptCandidate(_ candidate: String) -> Bool {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = trimmed.split(whereSeparator: \.isWhitespace).count
        let letterCount = trimmed.filter(\.isLetter).count
        return wordCount >= 2 && letterCount >= 6
    }

    private static func recoveredMarkedTerminalScreenInputAnalysis(
        for context: ClaudeCodeTerminalHostProofContext
    ) -> (inputText: String?, rejectionReason: String) {
        let rawAnalysis = recoveredMarkedTerminalScreenInputAnalysis(
            hostBundleIdentifier: context.hostBundleIdentifier,
            proofModeEnabled: context.proofModeEnabled,
            windowTitle: context.windowTitle,
            textBeforeCursor: context.rawTextBeforeCursor,
            textAfterCursor: context.rawTextAfterCursor,
            currentInputSuffix: nil
        )
        if rawAnalysis.inputText != nil || context.terminalScreenText.isEmpty {
            return rawAnalysis
        }

        var screenRejectionReasons: [String] = []
        for currentInputSuffix in terminalScreenCurrentInputSuffixCandidates(for: context) {
            let screenAnalysis = recoveredMarkedTerminalScreenInputAnalysis(
                hostBundleIdentifier: context.hostBundleIdentifier,
                proofModeEnabled: context.proofModeEnabled,
                windowTitle: context.windowTitle,
                textBeforeCursor: context.terminalScreenText,
                textAfterCursor: "",
                currentInputSuffix: currentInputSuffix
            )
            if screenAnalysis.inputText != nil {
                return screenAnalysis
            }
            screenRejectionReasons.append(screenAnalysis.rejectionReason)
        }

        return (
            nil,
            "\(rawAnalysis.rejectionReason);screen:\(screenRejectionReasons.joined(separator: ","))"
        )
    }

    private static func terminalScreenCurrentInputSuffixCandidates(
        for context: ClaudeCodeTerminalHostProofContext
    ) -> [String] {
        terminalScreenCurrentInputSuffixCandidates(
            focusedText: context.focusedText,
            rawTextBeforeCursor: context.rawTextBeforeCursor,
            rawTextAfterCursor: context.rawTextAfterCursor,
            includeRawAfterFragments: true
        )
    }

    private static func terminalScreenCurrentInputSuffixCandidates(
        focusedText: String,
        rawTextBeforeCursor: String,
        rawTextAfterCursor: String,
        includeRawAfterFragments: Bool = false
    ) -> [String] {
        var candidates: [String] = []

        appendSanitizedCurrentInputSuffix(rawTextBeforeCursor, to: &candidates)
        if rawTextBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let rawAfterFragments = includeRawAfterFragments
                ? lineFragments(rawTextAfterCursor)
                : [lineFragments(rawTextAfterCursor).first ?? ""]
            for fragment in rawAfterFragments {
                appendSanitizedCurrentInputSuffix(fragment, to: &candidates)
            }
        }
        appendSanitizedCurrentInputSuffix(focusedText, to: &candidates)

        return candidates
    }

    private static func appendSanitizedCurrentInputSuffix(
        _ candidate: String,
        to candidates: inout [String]
    ) {
        guard let sanitized = sanitizedCurrentInputSuffix(candidate),
              !candidates.contains(sanitized) else {
            return
        }
        candidates.append(sanitized)
    }

    private static func sanitizedCurrentInputSuffix(_ candidate: String) -> String? {
        let fragment = lineFragments(candidate).first ?? ""
        let stripped = fragment.strippingLeadingPromptResidue()
        guard let sanitized = sanitizedProofInputLine(stripped) else {
            return nil
        }

        let trimmed = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !containsIncompleteProofMarkerFragment(trimmed),
              !looksLikeClaudePromptChromeLine(trimmed),
              !looksLikeActiveAgentOutput(trimmed),
              !looksLikeTitleScopedTerminalChromeOrStaleHeader(trimmed) else {
            return nil
        }

        return sanitized
    }

    private static func recoveredMarkedTerminalScreenInputLine(
        terminalScreenText: String,
        currentInputSuffix: String
    ) -> String? {
        let analysis = recoveredMarkedTerminalScreenInputAnalysis(
            hostBundleIdentifier: supportedHostVariants.first?.bundleIdentifier ?? "",
            proofModeEnabled: true,
            windowTitle: "",
            textBeforeCursor: terminalScreenText,
            textAfterCursor: "",
            currentInputSuffix: currentInputSuffix
        )
        guard analysis.inputText != nil,
              let markerRange = lastProofMarkerRange(in: terminalScreenText) else {
            return nil
        }

        return lineFragments(String(terminalScreenText[markerRange.lowerBound...]))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func recoveredMarkedTerminalScreenInputAnalysis(
        hostBundleIdentifier: String,
        proofModeEnabled: Bool,
        windowTitle: String,
        textBeforeCursor: String,
        textAfterCursor: String,
        currentInputSuffix: String?
    ) -> (inputText: String?, rejectionReason: String) {
        guard supportedTerminalHosts.contains(hostBundleIdentifier),
              proofModeEnabled else {
            return (nil, "unsupportedOrProofModeOff")
        }

        guard titleHasScopedProofMarker(windowTitle)
            || containsProofMarker(textBeforeCursor) else {
            return (nil, "missingScopedMarker")
        }

        guard canIgnoreTerminalScreenTextAfterCursor(textAfterCursor) else {
            return (nil, "afterCursorText")
        }

        guard let markerRange = lastProofMarkerRange(in: textBeforeCursor) else {
            return (nil, "missingRawMarker")
        }

        let markedSegment: String
        if currentInputSuffix != nil,
           let markedScreenLine = recoveredMarkedTerminalScreenPromptSegment(in: textBeforeCursor) {
            markedSegment = markedScreenLine
        } else {
            markedSegment = String(textBeforeCursor[markerRange.lowerBound...])
        }
        let recovery = recoveredMarkedTerminalPromptInputAnalysis(from: markedSegment)
        guard let recoveredInputText = recovery.inputText else {
            return recovery
        }

        if let currentInputSuffix {
            let trimmedSuffix = currentInputSuffix.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedSuffix.isEmpty else {
                return (nil, "screenCurrentInputMissing")
            }

            guard terminalScreenInput(recoveredInputText, matchesCurrentSuffix: trimmedSuffix) else {
                return (nil, "screenCurrentInputMismatch")
            }

            guard recoveredInputText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(whereSeparator: \.isWhitespace)
                .count >= 3 else {
                return (nil, "screenRecoveredInputTooShort")
            }
        }

        return (recoveredInputText, "none")
    }

    private static func recoveredMarkedTerminalPromptInputAnalysis(
        from markedSegment: String
    ) -> (inputText: String?, rejectionReason: String) {
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
            guard !containsIncompleteProofMarkerFragment(naturalInput) else {
                return (nil, "incompleteProofMarkerFragment")
            }
            return (naturalInput, "none")
        }

        guard !containsIncompleteProofMarkerFragment(inputText) else {
            return (nil, "incompleteProofMarkerFragment")
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

    private static func recoveredMarkedTerminalScreenPromptSegment(in text: String) -> String? {
        recoveredMarkedTerminalScreenPromptSegmentLocation(in: text)?.text
    }

    private struct RecoveredTerminalScreenPromptSegment {
        let text: String
        let markedLine: String
        let lineIndex: Int
        let lineCount: Int
    }

    private static func recoveredMarkedTerminalScreenPromptSegmentLocation(
        in text: String
    ) -> RecoveredTerminalScreenPromptSegment? {
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
            guard trailingLines.allSatisfy(isAllowedTrailingClaudePromptTrailer) else {
                continue
            }

            var promptFragments = [trimmed]
            if trimmed.strippingLeadingPromptResidue() == trimmed.trimmingLeadingWhitespace() {
                var previousIndex = index - 1
                var remainingPrefixFragments = 2
                while previousIndex >= fragments.startIndex, remainingPrefixFragments > 0 {
                    let previous = fragments[previousIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                    guard isSafeTerminalScreenPromptPrefixFragment(previous) else {
                        break
                    }
                    promptFragments.insert(previous, at: 0)
                    remainingPrefixFragments -= 1
                    if previousIndex == fragments.startIndex {
                        break
                    }
                    previousIndex = fragments.index(before: previousIndex)
                }
            }

            return RecoveredTerminalScreenPromptSegment(
                text: promptFragments.joined(separator: " "),
                markedLine: trimmed,
                lineIndex: index,
                lineCount: fragments.count
            )
        }
        return nil
    }

    private static func titleScopedTerminalScreenInputText(
        for context: ClaudeCodeTerminalHostProofContext
    ) -> String? {
        let hasTitleMarker = titleHasScopedProofMarker(context.windowTitle)
        let hasScreenHeaderMarker = terminalScreenHasScopedProofHeaderMarker(context.terminalScreenText)
        guard hasTitleMarker || hasScreenHeaderMarker,
              !context.terminalScreenText.isEmpty else {
            return nil
        }

        let fragments = lineFragments(context.terminalScreenText)
        guard !fragments.isEmpty else {
            return nil
        }

        var trailingRowsArePromptChromeOnly = true
        for offset in fragments.indices.reversed() {
            let trimmed = fragments[offset].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continue
            }

            if isAllowedTrailingClaudePromptHint(trimmed) || looksLikeClaudePromptChromeLine(trimmed) {
                continue
            }

            if trailingRowsArePromptChromeOnly,
               let currentLine = titleScopedTerminalScreenPromptLine(
                endingAt: offset,
                fragments: fragments
               ),
               let inputText = safeTitleScopedPromptInputLine(currentLine),
               hasTitleMarker || terminalScreenInputMatchesCurrentContext(inputText, for: context) {
                return inputText
            }

            trailingRowsArePromptChromeOnly = false
        }

        return nil
    }

    private static func titleScopedTerminalScreenPromptAnchor(
        for context: ClaudeCodeTerminalHostProofContext
    ) -> ClaudeCodeTerminalScreenPromptAnchor? {
        let hasTitleMarker = titleHasScopedProofMarker(context.windowTitle)
        let hasScreenHeaderMarker = terminalScreenHasScopedProofHeaderMarker(context.terminalScreenText)
        guard hasTitleMarker || hasScreenHeaderMarker,
              !context.terminalScreenText.isEmpty else {
            return nil
        }

        let fragments = lineFragments(context.terminalScreenText)
        guard !fragments.isEmpty else {
            return nil
        }

        var trailingRowsArePromptChromeOnly = true
        for offset in fragments.indices.reversed() {
            let trimmed = fragments[offset].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continue
            }

            if isAllowedTrailingClaudePromptHint(trimmed) || looksLikeClaudePromptChromeLine(trimmed) {
                continue
            }

            if trailingRowsArePromptChromeOnly,
               let currentLine = titleScopedTerminalScreenPromptLine(
                endingAt: offset,
                fragments: fragments
               ),
               let inputText = safeTitleScopedPromptInputLine(currentLine),
               terminalScreenInputMatchesCurrentContext(inputText, for: context),
               !hasUnscopedStaleHeaderDirectText(for: context),
               !hasConflictingDirectCurrentPromptCandidate(inputText, for: context) {
                let currentLineInputText = safeTitleScopedPromptInputLine(trimmed) ?? inputText
                return ClaudeCodeTerminalScreenPromptAnchor(
                    inputText: inputText,
                    promptLineInputText: currentLineInputText,
                    lineIndex: offset,
                    lineCount: fragments.count
                )
            }

            trailingRowsArePromptChromeOnly = false
        }

        return nil
    }

    private static func titleScopedDirectPromptAnchor(
        for context: ClaudeCodeTerminalHostProofContext
    ) -> ClaudeCodeTerminalScreenPromptAnchor? {
        let hasTitleMarker = titleHasScopedProofMarker(context.windowTitle)
        let hasScreenHeaderMarker = terminalScreenHasScopedProofHeaderMarker(context.terminalScreenText)
        guard hasTitleMarker || hasScreenHeaderMarker,
              !hasUnsafeTerminalRowsAfterCursor(context.rawTextAfterCursor),
              let inputText = titleScopedDirectPromptInputText(for: context),
              !hasUnscopedStaleHeaderDirectText(for: context),
              !hasConflictingDirectCurrentPromptCandidate(inputText, for: context) else {
            return nil
        }

        if let screenLineAnchor = titleScopedDirectPromptScreenLineAnchor(
            inputText: inputText,
            terminalScreenText: context.terminalScreenText
        ) {
            return screenLineAnchor
        }

        guard hasTitleMarker else {
            return nil
        }

        return ClaudeCodeTerminalScreenPromptAnchor(
            inputText: inputText,
            promptLineInputText: inputText,
            lineIndex: 0,
            lineCount: 4
        )
    }

    private static func titleScopedDirectPromptInputText(
        for context: ClaudeCodeTerminalHostProofContext
    ) -> String? {
        let focusedLine = effectiveFocusedInputLine(
            focusedText: context.focusedText,
            rawTextBeforeCursor: context.rawTextBeforeCursor,
            rawTextAfterCursor: context.rawTextAfterCursor,
            terminalScreenText: context.terminalScreenText
        )
        let candidates = [
            proofInputTextBeforeCursorOnly(
                textBeforeCursor: context.rawTextBeforeCursor,
                textAfterCursor: context.rawTextAfterCursor
            ),
            sanitizedProofInputLine(focusedLine),
            sanitizedProofInputLine(context.focusedText)
        ]
        return candidates.compactMap { $0 }.first { candidate in
            safeTitleScopedPromptInputLine(candidate) != nil
                && !looksLikeTitleScopedTerminalChromeOrStaleHeader(candidate)
        }
    }

    private static func titleScopedDirectPromptScreenLineAnchor(
        inputText: String,
        terminalScreenText: String
    ) -> ClaudeCodeTerminalScreenPromptAnchor? {
        let fragments = lineFragments(terminalScreenText)
        guard !fragments.isEmpty else {
            return nil
        }

        for offset in fragments.indices.reversed() {
            let trimmed = fragments[offset].trimmingCharacters(in: .whitespacesAndNewlines)
            guard let lineInputText = safeTitleScopedPromptInputLine(trimmed),
                  terminalScreenInput(inputText, matchesCurrentSuffix: lineInputText) else {
                continue
            }

            return ClaudeCodeTerminalScreenPromptAnchor(
                inputText: inputText,
                promptLineInputText: lineInputText,
                lineIndex: offset,
                lineCount: fragments.count
            )
        }

        return nil
    }

    private static func terminalScreenHasScopedProofHeaderMarker(_ terminalScreenText: String) -> Bool {
        lineFragments(terminalScreenText).contains { line in
            let lowered = line.lowercased()
            return lowered.contains("claude code")
                && containsProofMarker(line)
        }
    }

    private static func terminalScreenInputMatchesCurrentContext(
        _ inputText: String,
        for context: ClaudeCodeTerminalHostProofContext
    ) -> Bool {
        terminalScreenCurrentInputSuffixCandidates(for: context).contains { candidate in
            terminalScreenInput(inputText, matchesCurrentSuffix: candidate)
        }
    }

    private static func titleScopedTerminalScreenPromptLine(
        endingAt index: Int,
        fragments: [String]
    ) -> String? {
        let current = fragments[index].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !current.isEmpty,
              !containsProofMarker(current),
              !looksLikeClaudePromptChromeLine(current),
              !looksLikeActiveAgentOutput(current) else {
            return nil
        }

        let currentStartsWithPromptResidue = current.strippingLeadingPromptResidue() != current.trimmingLeadingWhitespace()
        guard !currentStartsWithPromptResidue else {
            return current
        }

        var promptFragments = [current]
        var previousIndex = index - 1
        var remainingPrefixFragments = 2
        while previousIndex >= fragments.startIndex, remainingPrefixFragments > 0 {
            let previous = fragments[previousIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard isSafeTitleScopedTerminalScreenPrefixFragment(previous) else {
                break
            }
            promptFragments.insert(previous, at: 0)
            remainingPrefixFragments -= 1
            previousIndex -= 1
        }

        return promptFragments.joined(separator: " ")
    }

    private static func isSafeTitleScopedTerminalScreenPrefixFragment(_ fragment: String) -> Bool {
        let trimmed = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !containsProofMarker(trimmed),
              !looksLikeClaudePromptChromeLine(trimmed),
              !looksLikeActiveAgentOutput(trimmed),
              let inputText = safeTitleScopedPromptInputLine(trimmed) else {
            return false
        }

        return inputText.split(whereSeparator: \.isWhitespace).count >= 2
    }

    private static func safeTitleScopedPromptInputLine(_ line: String) -> String? {
        guard !containsProofMarker(line),
              let inputText = sanitizedProofInputLine(line) else {
            return nil
        }

        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(whereSeparator: \.isWhitespace)
        let letterCount = trimmed.filter(\.isLetter).count
        let digitCount = trimmed.filter(\.isNumber).count
        guard words.count >= 3,
              letterCount >= 8,
              letterCount >= digitCount,
              !containsIncompleteProofMarkerFragment(trimmed),
              !looksLikeShellCommandInput(trimmed),
              !looksLikeTerminalShellCommandLine(trimmed),
              !looksLikeActiveAgentOutput(trimmed),
              !looksLikeClaudePromptChromeLine(trimmed) else {
            return nil
        }

        return inputText
    }

    private static func looksLikeTitleScopedTerminalChromeOrStaleHeader(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        let lowered = trimmed.lowercased()
        if lowered == "claude code" {
            return true
        }

        if lowered.hasPrefix("claude code "),
           containsVersionNumber(trimmed) || containsDateStamp(trimmed) {
            return true
        }

        if lowered.hasPrefix("build "),
           containsVersionNumber(trimmed) || containsDateStamp(trimmed) {
            return true
        }

        if lowered.contains("/.codex/")
            || lowered.contains("~/.codex")
            || lowered.contains("last login")
            || lowered.contains(" tty") {
            return true
        }

        if let partialWordShape = PartialWordShape.from(textBeforeCursor: trimmed),
           partialWordShape.characterCount >= 4,
           partialWordShape.digitCount >= 3,
           partialWordShape.letterCount <= 1,
           partialWordShape.digitCount > partialWordShape.letterCount {
            return true
        }

        return false
    }

    private static func containsDateStamp(_ text: String) -> Bool {
        text.range(
            of: #"\b\d{4}[-/]\d{2}[-/]\d{2}\b"#,
            options: .regularExpression
        ) != nil
    }

    private static func containsVersionNumber(_ text: String) -> Bool {
        text.range(
            of: #"\bv?\d+\.\d+(?:\.\d+)?\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func isSafeTerminalScreenPromptPrefixFragment(_ fragment: String) -> Bool {
        let trimmed = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !containsProofMarker(trimmed),
              !looksLikeClaudePromptChromeLine(trimmed),
              trimmed.lowercased() != "claude code",
              !looksLikeActiveAgentOutput(trimmed),
              let inputText = sanitizedProofInputLine(trimmed),
              inputText.split(whereSeparator: \.isWhitespace).count >= 2,
              !looksLikeShellCommandInput(inputText),
              !looksLikeTerminalShellCommandLine(inputText) else {
            return false
        }

        return true
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

    private static func terminalScreenInput(
        _ inputText: String,
        matchesCurrentSuffix currentInputSuffix: String
    ) -> Bool {
        let input = inputText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let suffix = currentInputSuffix
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !input.isEmpty, !suffix.isEmpty else {
            return false
        }

        if input.hasSuffix(suffix) {
            return true
        }

        let compactInput = input.filter { !$0.isWhitespace }
        let compactSuffix = suffix.filter { !$0.isWhitespace }
        return !compactInput.isEmpty
            && !compactSuffix.isEmpty
            && compactInput.hasSuffix(compactSuffix)
    }

    private static func repairingKnownDroppedProofSpaces(in text: String) -> String {
        text
            .replacingOccurrences(of: "Make thissetting", with: "Make this setting")
            .replacingOccurrences(of: "make thissetting", with: "make this setting")
            .replacingOccurrences(of: "Make transitiontransi", with: "Make transition transi")
            .replacingOccurrences(of: "make transitiontransi", with: "make transition transi")
    }

    private static func containsIncompleteProofMarkerFragment(_ text: String) -> Bool {
        if containsProofMarker(text) {
            return false
        }

        let compactUppercaseText = text
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
        guard compactUppercaseText.count >= 8 else {
            return false
        }

        for marker in proofMarkers {
            let compactMarker = marker
                .uppercased()
                .filter { $0.isLetter || $0.isNumber }
            guard compactMarker.count >= 8 else {
                continue
            }

            var prefixLength = min(compactMarker.count - 1, compactUppercaseText.count)
            while prefixLength >= 8 {
                let prefix = String(compactMarker.prefix(prefixLength))
                if compactUppercaseText.contains(prefix) {
                    return true
                }
                prefixLength -= 1
            }
        }

        return false
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

    private static func hasUnsafeTerminalRowsAfterCursor(_ textAfterCursor: String) -> Bool {
        let firstFragment = lineFragments(textAfterCursor)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if firstFragment.isEmpty
            || isAllowedTrailingClaudePromptHint(firstFragment)
            || looksLikeClaudePromptChromeLine(firstFragment)
            || looksLikeActiveAgentOutput(firstFragment) {
            return false
        }

        let trailingRows = lineFragments(textAfterCursor)
            .dropFirst()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !trailingRows.isEmpty else {
            return false
        }

        return trailingRows.contains { row in
            !isAllowedTrailingClaudePromptHint(row)
                && !looksLikeClaudePromptChromeLine(row)
        }
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

        if looksLikePlaceholderPrompt(trimmed) {
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
