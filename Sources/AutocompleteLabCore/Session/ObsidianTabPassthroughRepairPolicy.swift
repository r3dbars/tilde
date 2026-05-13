public struct ObsidianTabPassthroughRepairDecision: Equatable, Sendable {
    public let shouldRepair: Bool
    public let reason: String

    public static let repair = ObsidianTabPassthroughRepairDecision(
        shouldRepair: true,
        reason: "leading-tab-indent"
    )

    public static func skip(_ reason: String) -> ObsidianTabPassthroughRepairDecision {
        ObsidianTabPassthroughRepairDecision(shouldRepair: false, reason: reason)
    }
}

public struct ObsidianTabPassthroughRepairPolicy: Equatable, Sendable {
    public init() {}

    public func decision(
        previousTextBeforeCursor: String,
        currentTextBeforeCursor: String,
        previousTextAfterCursor: String,
        currentTextAfterCursor: String,
        currentSelectedText: String = "",
        hasVisibleSuggestion: Bool,
        acceptedText: String?
    ) -> ObsidianTabPassthroughRepairDecision {
        guard hasVisibleSuggestion else {
            return .skip("no-visible-suggestion")
        }

        guard let acceptedText, !acceptedText.isEmpty else {
            return .skip("missing-accepted-text")
        }

        let currentFullText = currentTextBeforeCursor + currentTextAfterCursor
        let hasFullTextLeadingIndent = currentFullText == previousTextBeforeCursorWithCurrentLineIndented(previousTextBeforeCursor)
            + previousTextAfterCursor
        let hasFullTextCodeMirrorTabSpacer = currentTextBeforeCursorHasCodeMirrorTabSpacer(
            previousTextBeforeCursor: previousTextBeforeCursor,
            currentTextBeforeCursor: currentFullText
        )
        let afterCursorMatches = previousTextAfterCursor == currentTextAfterCursor
            || currentTextAfterCursor.isEmpty
            || hasFullTextLeadingIndent
            || hasFullTextCodeMirrorTabSpacer
        let hasCurrentLineSelectionIndent = currentTextBeforeCursorHasSelectedLineTabSpacer(
            previousTextBeforeCursor: previousTextBeforeCursor,
            currentTextBeforeCursor: currentTextBeforeCursor,
            currentTextAfterCursor: currentTextAfterCursor,
            currentSelectedText: currentSelectedText
        )
        guard afterCursorMatches || hasCurrentLineSelectionIndent else {
            return .skip("text-after-changed")
        }

        guard currentTextBeforeCursor == previousTextBeforeCursorWithCurrentLineIndented(previousTextBeforeCursor)
                || currentTextBeforeCursorHasCodeMirrorTabSpacer(
                    previousTextBeforeCursor: previousTextBeforeCursor,
                    currentTextBeforeCursor: currentTextBeforeCursor
                )
                || hasFullTextLeadingIndent
                || hasFullTextCodeMirrorTabSpacer
                || hasCurrentLineSelectionIndent else {
            return .skip("not-leading-tab-indent")
        }

        return .repair
    }

    private func previousTextBeforeCursorWithCurrentLineIndented(_ text: String) -> String {
        guard let lastNewline = text.lastIndex(of: "\n") else {
            return "\t" + text
        }

        let lineStart = text.index(after: lastNewline)
        return String(text[..<lineStart]) + "\t" + String(text[lineStart...])
    }

    private func currentTextBeforeCursorHasCodeMirrorTabSpacer(
        previousTextBeforeCursor: String,
        currentTextBeforeCursor: String
    ) -> Bool {
        let previousLine = currentLine(in: previousTextBeforeCursor)
        guard previousLine.count >= 2,
              currentTextBeforeCursor.hasSuffix(previousLine) else {
            return false
        }

        let textBeforePreviousLine = String(
            currentTextBeforeCursor.dropLast(previousLine.count)
        )
        let spacerSource = textBeforePreviousLine.last?.isNewline == true
            ? String(textBeforePreviousLine.dropLast())
            : textBeforePreviousLine
        let spacerLine = currentLine(in: spacerSource)
        return spacerLine.contains("\t")
            && spacerLine.trimmingCodeMirrorInvisibleScaffolding().isEmpty
    }

    private func currentTextBeforeCursorHasSelectedLineTabSpacer(
        previousTextBeforeCursor: String,
        currentTextBeforeCursor: String,
        currentTextAfterCursor: String,
        currentSelectedText: String
    ) -> Bool {
        let previousLine = currentLine(in: previousTextBeforeCursor)
        guard previousLine.count >= 2,
              currentSelectedText == previousLine || currentTextAfterCursor.hasPrefix(previousLine) else {
            return false
        }

        let previousPrefix = textBeforeCurrentLine(in: previousTextBeforeCursor)
        let spacerSource: String
        if previousPrefix.isEmpty {
            spacerSource = currentTextBeforeCursor
        } else if let prefixRange = currentTextBeforeCursor.range(of: previousPrefix, options: .backwards) {
            spacerSource = String(currentTextBeforeCursor[prefixRange.upperBound...])
        } else {
            return false
        }

        return spacerSource.contains("\t")
            && spacerSource.trimmingCodeMirrorInvisibleScaffoldingAndLineBreaks().isEmpty
    }

    private func textBeforeCurrentLine(in text: String) -> String {
        guard let lastNewline = text.lastIndex(of: "\n") else {
            return ""
        }

        return String(text[...lastNewline])
    }

    private func currentLine(in text: String) -> String {
        text.split(
            omittingEmptySubsequences: false,
            whereSeparator: \.isNewline
        ).last.map(String.init) ?? ""
    }
}

private extension String {
    func trimmingCodeMirrorInvisibleScaffolding() -> String {
        String(unicodeScalars.filter { scalar in
            switch scalar.value {
            case 0x0009, // tab
                 0x200B, // zero-width space
                 0x200C, // zero-width non-joiner
                 0x200D, // zero-width joiner
                 0x2060, // word joiner
                 0xFEFF, // zero-width no-break space
                 0xFFFC: // object replacement character
                return false
            default:
                return true
            }
        })
    }

    func trimmingCodeMirrorInvisibleScaffoldingAndLineBreaks() -> String {
        String(unicodeScalars.filter { scalar in
            switch scalar.value {
            case 0x0009, // tab
                 0x000A, // line feed
                 0x000D, // carriage return
                 0x200B, // zero-width space
                 0x200C, // zero-width non-joiner
                 0x200D, // zero-width joiner
                 0x2028, // line separator
                 0x2029, // paragraph separator
                 0x2060, // word joiner
                 0xFEFF, // zero-width no-break space
                 0xFFFC: // object replacement character
                return false
            default:
                return true
            }
        })
    }
}
