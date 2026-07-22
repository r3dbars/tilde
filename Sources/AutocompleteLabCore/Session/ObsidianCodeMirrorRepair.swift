import Foundation

/// All of the `md.obsidian`-guarded CodeMirror text-context repair heuristics,
/// consolidated behind one entry point (`repair(_:)`) called from
/// `TextContextRepairPolicy.repair(_:)`. Obsidian's virtualized CodeMirror
/// viewport produces a family of related symptoms — a trailing character AX
/// hasn't caught up on yet, hidden spacer lines, stale previous-line text,
/// document-tail growth at various snapshot sizes, drifted line starts — and
/// each function here guards on one observed symptom. The dispatch order
/// mirrors the original inline chain exactly: first match wins.
struct ObsidianCodeMirrorRepairPolicy: Equatable, Sendable {
    func repair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        if let obsidianRepair = obsidianCodeMirrorTrailingCharacterRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorTrailingScaffoldingRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorHiddenSpacerLineRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorLeadingWordDriftRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorDocumentCoordinateDriftRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorStalePreviousLineRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorEndOfDocumentGrowthRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorViewportEndOfDocumentRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorViewportTailLineRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorShortDocumentStructureTailRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorShortDocumentTailLineRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorLineStartTailRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorTextAfterTypingGrowthRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorTextAfterGrowthRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorTextAfterActiveLineRepair(input) {
            return obsidianRepair
        }
        if let obsidianRepair = obsidianCodeMirrorLineDriftRepair(input) {
            return obsidianRepair
        }

        return nil
    }

    private func obsidianCodeMirrorTrailingCharacterRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              let lastCharacterBeforeCursor = input.textBeforeCursor.last,
              lastCharacterBeforeCursor.isLetter else {
            return nil
        }

        let lineAfterCursor = firstLine(in: input.textAfterCursor)
        guard lineAfterCursor.count == 1,
              lineAfterCursor.allSatisfy(\.isLetter) else {
            return nil
        }

        let repairedTextBeforeCursor = input.textBeforeCursor + lineAfterCursor
        let repairedTextAfterCursor = String(input.textAfterCursor.dropFirst(lineAfterCursor.count))
        let repairedCurrentLine = currentLine(in: repairedTextBeforeCursor)
        guard isPlausibleActiveTypingLine(repairedCurrentLine) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: repairedTextBeforeCursor,
            textAfterCursor: repairedTextAfterCursor,
            reason: .obsidianCodeMirrorTrailingCharacter
        )
    }

    private func obsidianCodeMirrorTrailingScaffoldingRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              !input.textAfterCursor.isEmpty,
              input.textAfterCursor.count <= 12,
              input.textAfterCursor.containsCodeMirrorScaffolding,
              input.textAfterCursor.trimmingCodeMirrorScaffolding().isEmpty,
              isPlausibleActiveTypingLine(currentLine(in: input.textBeforeCursor)) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: input.textBeforeCursor,
            textAfterCursor: "",
            reason: .obsidianCodeMirrorTrailingScaffolding
        )
    }

    private func obsidianCodeMirrorHiddenSpacerLineRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              currentLine(in: input.textBeforeCursor).trimmingCodeMirrorScaffolding().isEmpty else {
            return nil
        }

        let skipped = leadingCodeMirrorSpacerPrefix(in: input.textAfterCursor)
        guard !skipped.prefix.isEmpty else {
            return nil
        }

        let activeLine = firstLine(in: skipped.remaining)
        guard activeLine.count <= 100,
              isPlausibleActiveTypingLine(activeLine) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: input.textBeforeCursor + activeLine,
            textAfterCursor: String(skipped.remaining.dropFirst(activeLine.count)),
            reason: .obsidianCodeMirrorHiddenSpacerLine
        )
    }

    private func obsidianCodeMirrorStalePreviousLineRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              let newlineIndex = input.textAfterCursor.firstIndex(where: \.isNewline) else {
            return nil
        }

        let staleLineSuffix = String(input.textAfterCursor[..<newlineIndex])
        guard !staleLineSuffix.isEmpty,
              staleLineSuffix.count <= 40,
              !staleLineSuffix.contains(where: \.isWhitespace) else {
            return nil
        }

        let activeLineStart = input.textAfterCursor.index(after: newlineIndex)
        let remainingAfterStaleLine = String(input.textAfterCursor[activeLineStart...])
        let activeLine = firstLine(in: remainingAfterStaleLine)
        guard activeLine.count <= 100,
              isPlausibleActiveTypingLine(activeLine) else {
            return nil
        }

        let repairedTextBeforeCursor = input.textBeforeCursor
            + staleLineSuffix
            + String(input.textAfterCursor[newlineIndex])
            + activeLine
        return TextContextRepairResult(
            textBeforeCursor: repairedTextBeforeCursor,
            textAfterCursor: String(remainingAfterStaleLine.dropFirst(activeLine.count)),
            reason: .obsidianCodeMirrorStalePreviousLine
        )
    }

    private func obsidianCodeMirrorTextAfterGrowthRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              let previousTextBeforeCursor = input.previousTextBeforeCursor,
              let previousTextAfterCursor = input.previousTextAfterCursor else {
            return nil
        }

        if !previousTextAfterCursor.isEmpty {
            guard previousTextBeforeCursor == input.textBeforeCursor,
                  input.textAfterCursor.hasPrefix(previousTextAfterCursor),
                  input.textAfterCursor.count > previousTextAfterCursor.count else {
                return nil
            }
        } else {
            guard !previousTextBeforeCursor.isEmpty,
                  input.textBeforeCursor.hasPrefix(previousTextBeforeCursor),
                  input.textBeforeCursor.count > previousTextBeforeCursor.count,
                  input.textBeforeCursor.count <= previousTextBeforeCursor.count + 8,
                  input.textAfterCursor.count >= 2 else {
                return nil
            }

            let driftPrefix = String(input.textBeforeCursor.dropFirst(previousTextBeforeCursor.count))
            guard driftPrefix.allSatisfy(\.isLetter) else {
                return nil
            }
        }

        let lineAfterCursor = firstLine(in: input.textAfterCursor)
        let repairedTextBeforeCursor = input.textBeforeCursor + lineAfterCursor
        let repairedTextAfterCursor = String(input.textAfterCursor.dropFirst(lineAfterCursor.count))
        let repairedCurrentLine = currentLine(in: repairedTextBeforeCursor)
        guard isPlausibleActiveTypingLine(repairedCurrentLine) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: repairedTextBeforeCursor,
            textAfterCursor: repairedTextAfterCursor,
            reason: .obsidianCodeMirrorTextAfterGrowth
        )
    }

    private func obsidianCodeMirrorEndOfDocumentGrowthRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              let previousTextBeforeCursor = input.previousTextBeforeCursor,
              let previousTextAfterCursor = input.previousTextAfterCursor,
              !previousTextBeforeCursor.isEmpty,
              previousTextAfterCursor.isEmpty,
              !input.textAfterCursor.isEmpty else {
            return nil
        }

        let currentText = input.textBeforeCursor + input.textAfterCursor
        if let cappedWindowRepair = obsidianCodeMirrorCappedEndOfDocumentGrowthRepair(
            input: input,
            previousTextBeforeCursor: previousTextBeforeCursor,
            currentText: currentText
        ) {
            return cappedWindowRepair
        }
        if let typingDriftRepair = obsidianCodeMirrorEndOfDocumentTypingDriftRepair(
            input: input,
            previousTextBeforeCursor: previousTextBeforeCursor,
            currentText: currentText
        ) {
            return typingDriftRepair
        }
        if let viewportStableRepair = obsidianCodeMirrorViewportEndOfDocumentStableRepair(
            input: input,
            previousTextBeforeCursor: previousTextBeforeCursor,
            currentText: currentText
        ) {
            return viewportStableRepair
        }
        if let viewportGrowthRepair = obsidianCodeMirrorViewportEndOfDocumentGrowthRepair(
            input: input,
            previousTextBeforeCursor: previousTextBeforeCursor,
            currentText: currentText
        ) {
            return viewportGrowthRepair
        }

        guard currentText.hasPrefix(previousTextBeforeCursor),
              currentText.count > previousTextBeforeCursor.count,
              currentText.count <= previousTextBeforeCursor.count + 160,
              input.textBeforeCursor.count < previousTextBeforeCursor.count else {
            return nil
        }

        guard isPlausibleActiveTypingLine(currentLine(in: currentText)) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: currentText,
            textAfterCursor: "",
            reason: .obsidianCodeMirrorEndOfDocumentGrowth
        )
    }

    private func obsidianCodeMirrorViewportEndOfDocumentStableRepair(
        input: TextContextRepairInput,
        previousTextBeforeCursor: String,
        currentText: String
    ) -> TextContextRepairResult? {
        guard input.textBeforeCursor.count >= 300,
              input.textBeforeCursor.count < previousTextBeforeCursor.count,
              input.textBeforeCursor.last?.isNewline != true,
              input.textAfterCursor.count <= 160,
              previousTextBeforeCursor.hasSuffix(currentText),
              isPlausibleActiveTypingLine(currentLine(in: previousTextBeforeCursor)) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: previousTextBeforeCursor,
            textAfterCursor: "",
            reason: .obsidianCodeMirrorViewportEndOfDocumentStable
        )
    }

    private func obsidianCodeMirrorViewportEndOfDocumentGrowthRepair(
        input: TextContextRepairInput,
        previousTextBeforeCursor: String,
        currentText: String
    ) -> TextContextRepairResult? {
        guard input.textBeforeCursor.count >= 300,
              input.textBeforeCursor.count < previousTextBeforeCursor.count,
              input.textAfterCursor.count <= 160,
              !previousTextBeforeCursor.hasSuffix(currentText) else {
            return nil
        }

        let minimumOverlap = min(500, max(120, input.textBeforeCursor.count / 2))
        guard let overlap = suffixPrefixOverlap(
            previousTextBeforeCursor,
            currentText,
            minimumLength: minimumOverlap
        ) else {
            return nil
        }

        let appendedText = String(currentText.dropFirst(overlap))
        guard !appendedText.isEmpty,
              appendedText.count <= 160,
              appendedText.contains(where: \.isLetter),
              isPlausibleActiveTypingLine(currentLine(in: currentText)) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: currentText,
            textAfterCursor: "",
            reason: .obsidianCodeMirrorViewportEndOfDocumentGrowth
        )
    }

    private func obsidianCodeMirrorEndOfDocumentTypingDriftRepair(
        input: TextContextRepairInput,
        previousTextBeforeCursor: String,
        currentText: String
    ) -> TextContextRepairResult? {
        guard currentText.hasPrefix(previousTextBeforeCursor),
              currentText.count > previousTextBeforeCursor.count,
              currentText.count <= previousTextBeforeCursor.count + 200,
              previousTextBeforeCursor.last?.isNewline == true,
              input.textBeforeCursor.count >= previousTextBeforeCursor.count,
              input.textBeforeCursor.count < currentText.count,
              input.textAfterCursor.count <= 80 else {
            return nil
        }

        let appendedText = String(currentText.dropFirst(previousTextBeforeCursor.count))
        guard !appendedText.isEmpty,
              appendedText.count <= 160,
              appendedText.contains(where: \.isLetter),
              isPlausibleActiveTypingLine(currentLine(in: currentText)) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: currentText,
            textAfterCursor: "",
            reason: .obsidianCodeMirrorEndOfDocumentTypingDrift
        )
    }

    private func obsidianCodeMirrorTextAfterTypingGrowthRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              let previousTextBeforeCursor = input.previousTextBeforeCursor,
              let previousTextAfterCursor = input.previousTextAfterCursor,
              !previousTextBeforeCursor.isEmpty,
              previousTextAfterCursor.isEmpty,
              previousTextBeforeCursor == input.textBeforeCursor,
              !input.textAfterCursor.isEmpty,
              input.textAfterCursor.count <= 160 else {
            return nil
        }

        let activeLine = firstLine(in: input.textAfterCursor)
        let remainingAfterLine = String(input.textAfterCursor.dropFirst(activeLine.count))
        let strippedRemaining = remainingAfterLine
            .trimmingCodeMirrorScaffolding()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard activeLine.count <= 120,
              strippedRemaining.isEmpty else {
            return nil
        }

        let currentLineBefore = currentLine(in: input.textBeforeCursor)
        let canJoinSameLine = currentLineBefore.count <= 24
            && contentWordCount(in: currentLineBefore) <= 3
            && (currentLineBefore.last?.isLetter == true
                || currentLineBefore.last?.isWhitespace == true)
        if canJoinSameLine,
           activeLine.first?.isWhitespace != false,
           isPlausibleActiveTypingLine(currentLineBefore + activeLine) {
            return TextContextRepairResult(
                textBeforeCursor: input.textBeforeCursor + activeLine,
                textAfterCursor: remainingAfterLine,
                reason: .obsidianCodeMirrorTextAfterTypingGrowth
            )
        }

        guard isPlausibleActiveTypingLine(activeLine),
              input.textBeforeCursor.contains(where: \.isNewline)
                || activeLine.first?.isWhitespace == false
                    && currentLineBefore.count >= 24
                    && contentWordCount(in: currentLineBefore) >= 3 else {
            return nil
        }

        let separator = input.textBeforeCursor.last?.isNewline == true ? "" : "\n"
        return TextContextRepairResult(
            textBeforeCursor: input.textBeforeCursor + separator + activeLine,
            textAfterCursor: remainingAfterLine,
            reason: .obsidianCodeMirrorTextAfterTypingGrowth
        )
    }

    private func obsidianCodeMirrorViewportEndOfDocumentRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              input.textBeforeCursor.count >= 500,
              !input.textAfterCursor.isEmpty,
              input.textAfterCursor.count <= 260 else {
            return nil
        }

        let currentLineBefore = currentLine(in: input.textBeforeCursor)
        let lineAfterCursor = firstLine(in: input.textAfterCursor)
        guard !currentLineBefore.isEmpty,
              !lineAfterCursor.isEmpty,
              currentLineBefore.count <= 48,
              lineAfterCursor.count <= 120 else {
            return nil
        }

        let stitchedViewportLine = currentLineBefore + lineAfterCursor
        guard stitchedViewportLine.contains(where: \.isNumber),
              contentWordCount(in: stitchedViewportLine) >= 4 else {
            return nil
        }

        let remainingAfterViewportLine = String(input.textAfterCursor.dropFirst(lineAfterCursor.count))
        guard remainingAfterViewportLine.first?.isNewline == true else {
            return nil
        }

        let remainingTailLines = remainingAfterViewportLine
            .split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)
            .map(String.init)
        guard !remainingTailLines.isEmpty,
              remainingTailLines.count <= 3,
              let activeLine = remainingTailLines.last,
              isPlausibleActiveTypingLine(activeLine) else {
            return nil
        }

        let currentText = input.textBeforeCursor + input.textAfterCursor
        guard currentLine(in: currentText) == activeLine else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: currentText,
            textAfterCursor: "",
            reason: .obsidianCodeMirrorViewportEndOfDocument
        )
    }

    private func obsidianCodeMirrorViewportTailLineRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              input.textBeforeCursor.count >= 300,
              !input.textAfterCursor.isEmpty,
              input.textAfterCursor.count <= 260 else {
            return nil
        }

        let lineAfterCursor = firstLine(in: input.textAfterCursor)
        let remainingAfterLine = String(input.textAfterCursor.dropFirst(lineAfterCursor.count))
        guard remainingAfterLine.first?.isNewline == true else {
            return nil
        }

        let staleAnchorLine = currentLine(in: input.textBeforeCursor) + lineAfterCursor
        guard staleAnchorLine.count >= 6,
              staleAnchorLine.count <= 120,
              contentWordCount(in: staleAnchorLine) >= 2 else {
            return nil
        }

        let tailLines = remainingAfterLine
            .split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)
            .map(String.init)
        guard tailLines.count == 1,
              let activeLine = tailLines.last,
              activeLine != staleAnchorLine,
              isPlausibleActiveTypingLine(activeLine) else {
            return nil
        }

        let currentText = input.textBeforeCursor + input.textAfterCursor
        guard currentLine(in: currentText.trimmingCodeMirrorScaffoldingRight()) == activeLine else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: currentText,
            textAfterCursor: "",
            reason: .obsidianCodeMirrorViewportTailLine
        )
    }

    private func obsidianCodeMirrorShortDocumentStructureTailRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              input.textBeforeCursor.count <= 240,
              !input.textAfterCursor.isEmpty,
              input.textAfterCursor.count <= 360,
              input.textAfterCursor.contains(where: \.isNewline) else {
            return nil
        }

        let staleLine = currentLine(in: input.textBeforeCursor)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard staleLine.count >= 18,
              staleLine.count <= 120,
              contentWordCount(in: staleLine) >= 3 else {
            return nil
        }

        let currentText = input.textBeforeCursor + input.textAfterCursor
        let repairedTextBeforeCursor = currentText.trimmingCodeMirrorScaffoldingRight()
        let tailLine = currentLine(in: repairedTextBeforeCursor)
            .removingCodeMirrorScaffoldingMarkers()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let meaningfulAfterLines = meaningfulLines(in: input.textAfterCursor)
        guard repairedTextBeforeCursor.count > input.textBeforeCursor.count,
              !meaningfulAfterLines.isEmpty,
              meaningfulAfterLines.last == tailLine,
              isBareMarkdownStructureLine(tailLine) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: repairedTextBeforeCursor,
            textAfterCursor: "",
            reason: .obsidianCodeMirrorShortDocumentStructureTail
        )
    }

    private func obsidianCodeMirrorShortDocumentTailLineRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              input.textBeforeCursor.count <= 240,
              !input.textAfterCursor.isEmpty,
              input.textAfterCursor.count <= 360,
              input.textAfterCursor.contains(where: \.isNewline) else {
            return nil
        }

        let staleLine = currentLine(in: input.textBeforeCursor)
        let trimmedStaleLine = staleLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedStaleLine.count >= 18,
              trimmedStaleLine.count <= 120,
              contentWordCount(in: trimmedStaleLine) >= 3 else {
            return nil
        }

        let currentText = input.textBeforeCursor + input.textAfterCursor
        let repairedTextBeforeCursor = currentText.trimmingCodeMirrorScaffoldingRight()
        let activeLine = currentLine(in: repairedTextBeforeCursor)
        let trimmedActiveLine = activeLine
            .removingCodeMirrorScaffoldingMarkers()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard repairedTextBeforeCursor.count > input.textBeforeCursor.count,
              trimmedActiveLine != trimmedStaleLine,
              trimmedActiveLine.count <= 260,
              isPlausibleActiveTypingLine(trimmedActiveLine) else {
            return nil
        }

        let previousAfterGrewAtTail = input.previousTextBeforeCursor == input.textBeforeCursor
            && !(input.previousTextAfterCursor ?? "").isEmpty
            && input.textAfterCursor.hasPrefix(input.previousTextAfterCursor ?? "")
            && input.textAfterCursor.count > (input.previousTextAfterCursor ?? "").count

        let meaningfulAfterLines = meaningfulLines(in: input.textAfterCursor)
        let hasMarkdownOrCodeMirrorScaffold = input.textAfterCursor.containsCodeMirrorInvisibleScaffolding
            || meaningfulAfterLines.dropLast().contains(where: isMarkdownStructureLine)
        let hasStructuredTailEvidence = meaningfulAfterLines.count >= 2
            && (previousAfterGrewAtTail || hasMarkdownOrCodeMirrorScaffold)
        let hasLongRunOnTailEvidence = meaningfulAfterLines.count == 1
            && input.textAfterCursor.hasPrefix("\n\n")
            && input.textBeforeCursor.count <= 80
            && trimmedActiveLine.count >= 120
            && contentWordCount(in: trimmedActiveLine) >= 16
            && !isMarkdownStructureLine(trimmedActiveLine)
        guard meaningfulAfterLines.last == trimmedActiveLine,
              hasStructuredTailEvidence || hasLongRunOnTailEvidence else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: repairedTextBeforeCursor,
            textAfterCursor: "",
            reason: .obsidianCodeMirrorShortDocumentTailLine
        )
    }

    private func obsidianCodeMirrorLineStartTailRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              input.textBeforeCursor.count >= 300,
              input.textBeforeCursor.last?.isNewline == true,
              !input.textAfterCursor.isEmpty,
              input.textAfterCursor.count <= 120,
              let previousTextBeforeCursor = input.previousTextBeforeCursor else {
            return nil
        }

        let activeLine = firstLine(in: input.textAfterCursor)
        let repairedTextBeforeCursor = input.textBeforeCursor + activeLine
        let remainingAfterLine = String(input.textAfterCursor.dropFirst(activeLine.count))
        let strippedRemaining = remainingAfterLine
            .trimmingCodeMirrorScaffolding()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let isNewTailGrowth = input.textBeforeCursor.count > previousTextBeforeCursor.count
        let isStableLineStartReread = previousTextBeforeCursor == repairedTextBeforeCursor
        guard activeLine.count <= 80,
              isPlausibleActiveTypingLine(activeLine),
              strippedRemaining.isEmpty,
              isNewTailGrowth || isStableLineStartReread else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: repairedTextBeforeCursor,
            textAfterCursor: remainingAfterLine,
            reason: .obsidianCodeMirrorLineStartTail
        )
    }

    private func obsidianCodeMirrorCappedEndOfDocumentGrowthRepair(
        input: TextContextRepairInput,
        previousTextBeforeCursor: String,
        currentText: String
    ) -> TextContextRepairResult? {
        guard currentText.count >= 120,
              currentText.count <= 640,
              !previousTextBeforeCursor.hasSuffix(currentText),
              input.textBeforeCursor.count <= 32,
              input.textBeforeCursor.count < previousTextBeforeCursor.count,
              currentText.count < previousTextBeforeCursor.count else {
            return nil
        }

        let minimumOverlap = 120
        guard let overlap = suffixPrefixOverlap(
            previousTextBeforeCursor,
            currentText,
            minimumLength: minimumOverlap
        ) else {
            return nil
        }

        let appendedText = String(currentText.dropFirst(overlap))
        guard !appendedText.isEmpty,
              appendedText.count <= 160,
              appendedText.contains(where: \.isLetter),
              isPlausibleActiveTypingLine(currentLine(in: currentText)) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: currentText,
            textAfterCursor: "",
            reason: .obsidianCodeMirrorEndOfDocumentGrowth
        )
    }

    private func obsidianCodeMirrorLineDriftRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0 else {
            return nil
        }

        let currentLineBefore = currentLine(in: input.textBeforeCursor)
        let lineAfterCursor = firstLine(in: input.textAfterCursor)
        let currentLineWordCount = contentWordCount(in: currentLineBefore)
        let isMarkdownListLine = isMarkdownListStructureLine(currentLineBefore)
        let trailingFragment = trailingWordFragment(in: currentLineBefore) ?? ""
        let standardLineDrift = currentLineBefore.count <= 24
            && currentLineWordCount <= 2
            && (lineAfterCursor.contains(where: \.isWhitespace) || trailingFragment.count <= 1)
        let leadingWhitespaceLineDrift = standardLineDrift
            && lineAfterCursor.first?.isWhitespace == true
            && contentWordCount(in: lineAfterCursor) >= 1
            && contentWordCount(in: lineAfterCursor) <= 8
            && obsidianCodeMirrorLooksLikeDocumentTailGrowth(input)
        let markdownListLineDrift = isMarkdownListLine
            && currentLineBefore.count <= 80
            && currentLineWordCount <= 8
            && lineAfterCursor.allSatisfy(\.isLetter)
        let shortTrailingWordSplit = currentLineBefore.count <= 80
            && input.textBeforeCursor.contains(where: \.isNewline)
            && currentLineWordCount <= 8
            && trailingFragment.count >= 1
            && trailingFragment.count <= 4
            && lineAfterCursor.count <= 8
            && lineAfterCursor.allSatisfy(\.isLetter)

        guard currentLineBefore.count >= 1,
              lineAfterCursor.count >= 2,
              lineAfterCursor.count <= 80,
              standardLineDrift || leadingWhitespaceLineDrift || markdownListLineDrift || shortTrailingWordSplit,
              let lastCharacterBeforeCursor = currentLineBefore.last,
              lastCharacterBeforeCursor.isLetter,
              obsidianCodeMirrorLineDriftAfterCursorStartsSafely(
                  lineAfterCursor,
                  allowsLeadingWhitespace: leadingWhitespaceLineDrift
              ) else {
            return nil
        }

        let repairedLine = currentLineBefore + lineAfterCursor
        guard isPlausibleActiveTypingLine(repairedLine) else {
            return nil
        }

        let remainingAfterLine = String(input.textAfterCursor.dropFirst(lineAfterCursor.count))
        let strippedRemainingAfterLine = remainingAfterLine
            .trimmingCodeMirrorScaffolding()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard strippedRemainingAfterLine.isEmpty else {
            return nil
        }
        let repairedTextAfterCursor = remainingAfterLine.trimmingCodeMirrorScaffolding().isEmpty
            ? ""
            : remainingAfterLine

        return TextContextRepairResult(
            textBeforeCursor: input.textBeforeCursor + lineAfterCursor,
            textAfterCursor: repairedTextAfterCursor,
            reason: .obsidianCodeMirrorLineDrift
        )
    }

    private func obsidianCodeMirrorLooksLikeDocumentTailGrowth(_ input: TextContextRepairInput) -> Bool {
        guard let previousTextBeforeCursor = input.previousTextBeforeCursor,
              let previousTextAfterCursor = input.previousTextAfterCursor,
              !previousTextBeforeCursor.isEmpty,
              previousTextAfterCursor.isEmpty else {
            return false
        }

        let currentText = input.textBeforeCursor + input.textAfterCursor
        return currentText.hasPrefix(previousTextBeforeCursor)
            && currentText.count > previousTextBeforeCursor.count
            && currentText.count <= previousTextBeforeCursor.count + 200
    }

    private func obsidianCodeMirrorLineDriftAfterCursorStartsSafely(
        _ lineAfterCursor: String,
        allowsLeadingWhitespace: Bool
    ) -> Bool {
        guard let firstCharacterAfterCursor = lineAfterCursor.first else {
            return false
        }
        if firstCharacterAfterCursor.isLetter {
            return true
        }
        guard allowsLeadingWhitespace,
              firstCharacterAfterCursor.isWhitespace else {
            return false
        }
        return lineAfterCursor
            .drop(while: \.isWhitespace)
            .first?
            .isLetter == true
    }

    private func obsidianCodeMirrorTextAfterActiveLineRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0,
              !input.textBeforeCursor.isEmpty,
              input.textAfterCursor.count <= 120 else {
            return nil
        }

        let currentLineBefore = currentLine(in: input.textBeforeCursor)
        guard currentLineBefore.count >= 24,
              currentLineBefore.count <= 100,
              contentWordCount(in: currentLineBefore) >= 3 else {
            return nil
        }

        let lineAfterCursor = firstLine(in: input.textAfterCursor)
        guard lineAfterCursor.first?.isWhitespace == false,
              isPlausibleActiveTypingLine(lineAfterCursor) else {
            return nil
        }

        let remainingAfterLine = String(input.textAfterCursor.dropFirst(lineAfterCursor.count))
        let strippedRemaining = remainingAfterLine
            .trimmingCodeMirrorScaffolding()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard strippedRemaining.isEmpty else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: input.textBeforeCursor
                + (input.textBeforeCursor.last?.isNewline == true ? "" : "\n")
                + lineAfterCursor,
            textAfterCursor: remainingAfterLine,
            reason: .obsidianCodeMirrorTextAfterActiveLine
        )
    }

    private func obsidianCodeMirrorLeadingWordDriftRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0 else {
            return nil
        }

        let currentLineBefore = currentLine(in: input.textBeforeCursor)
        guard currentLineBefore.count >= 6,
              currentLineBefore.count <= 80,
              contentWordCount(in: currentLineBefore) >= 2,
              contentWordCount(in: currentLineBefore) <= 8,
              currentLineBefore.last?.isLetter == true else {
            return nil
        }

        let lineAfterCursor = firstLine(in: input.textAfterCursor)
        guard let consumedAfterCursor = leadingWhitespaceWordDrift(in: lineAfterCursor) else {
            return nil
        }

        let repairedLine = currentLineBefore + consumedAfterCursor
        guard isPlausibleActiveTypingLine(repairedLine) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: input.textBeforeCursor + consumedAfterCursor,
            textAfterCursor: String(input.textAfterCursor.dropFirst(consumedAfterCursor.count)),
            reason: .obsidianCodeMirrorLeadingWordDrift
        )
    }

    private func obsidianCodeMirrorDocumentCoordinateDriftRepair(_ input: TextContextRepairInput) -> TextContextRepairResult? {
        guard input.bundleIdentifier == "md.obsidian",
              input.role == "AXTextArea",
              input.selectedTextLength == 0 else {
            return nil
        }

        let previousSupportsRepair: Bool
        if let previousTextBeforeCursor = input.previousTextBeforeCursor,
           let previousTextAfterCursor = input.previousTextAfterCursor {
            previousSupportsRepair = previousTextAfterCursor.trimmingCodeMirrorScaffolding()
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && input.textBeforeCursor.hasPrefix(previousTextBeforeCursor)
        } else {
            previousSupportsRepair = false
        }
        let hiddenDocumentPrefixSupportsRepair = !leadingCodeMirrorSpacerPrefix(in: input.textBeforeCursor).prefix.isEmpty
        guard previousSupportsRepair || hiddenDocumentPrefixSupportsRepair else {
            return nil
        }

        let currentLineBefore = currentLine(in: input.textBeforeCursor)
        guard currentLineBefore.last?.isWhitespace == true,
              contentWordCount(in: currentLineBefore) >= 2,
              contentWordCount(in: currentLineBefore) <= 8 else {
            return nil
        }

        let lineAfterCursor = firstLine(in: input.textAfterCursor)
        let remainingAfterLine = String(input.textAfterCursor.dropFirst(lineAfterCursor.count))
        guard !lineAfterCursor.isEmpty,
              lineAfterCursor.first?.isWhitespace == false,
              lineAfterCursor.count <= 24,
              contentWordCount(in: lineAfterCursor) >= 1,
              contentWordCount(in: lineAfterCursor) <= 3,
              !lineAfterCursor.containsCodeMirrorScaffolding,
              remainingAfterLine.trimmingCodeMirrorScaffolding()
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let repairedLine = currentLineBefore + lineAfterCursor
        guard isPlausibleActiveTypingLine(repairedLine) else {
            return nil
        }

        return TextContextRepairResult(
            textBeforeCursor: input.textBeforeCursor + lineAfterCursor,
            textAfterCursor: remainingAfterLine,
            reason: .obsidianCodeMirrorDocumentCoordinateDrift
        )
    }

    // MARK: - Obsidian-only helpers

    private func meaningfulLines(in text: String) -> [String] {
        text
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map { line in
                String(line)
                    .removingCodeMirrorScaffoldingMarkers()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
    }

    private func isMarkdownStructureLine(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedLine == "-"
            || trimmedLine == "*"
            || trimmedLine == "+"
            || trimmedLine.hasPrefix("- ")
            || trimmedLine.hasPrefix("* ")
            || trimmedLine.hasPrefix("+ ")
            || trimmedLine.hasPrefix("#")
            || trimmedLine.hasPrefix(">")
            || trimmedLine.hasPrefix("|")
            || trimmedLine.hasPrefix("```")
    }

    private func isMarkdownListStructureLine(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedLine.hasPrefix("- ")
            || trimmedLine.hasPrefix("* ")
            || trimmedLine.hasPrefix("+ ")
    }

    private func isBareMarkdownStructureLine(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedLine == "-"
            || trimmedLine == "*"
            || trimmedLine == "+"
    }

    private func leadingCodeMirrorSpacerPrefix(in text: String) -> (prefix: String, remaining: String) {
        var prefix = ""
        var remaining = text

        while let newlineIndex = remaining.firstIndex(where: \.isNewline) {
            let line = String(remaining[..<newlineIndex])
            guard line.trimmingCodeMirrorScaffolding().isEmpty else {
                break
            }

            let nextIndex = remaining.index(after: newlineIndex)
            prefix += String(remaining[..<nextIndex])
            remaining = String(remaining[nextIndex...])
        }

        return (prefix, remaining)
    }

    private func leadingWhitespaceWordDrift(in text: String) -> String? {
        var index = text.startIndex
        var consumed = ""

        while index < text.endIndex,
              text[index].isWhitespace,
              !text[index].isNewline {
            consumed.append(text[index])
            index = text.index(after: index)
        }

        guard !consumed.isEmpty else {
            return nil
        }

        var word = ""
        while index < text.endIndex,
              text[index].isLetter {
            word.append(text[index])
            index = text.index(after: index)
        }

        guard word.count >= 2,
              word.count <= 16 else {
            return nil
        }

        let sameLineRemainder = String(text[index...])
        let strippedRemainder = sameLineRemainder
            .trimmingCodeMirrorScaffolding()
            .trimmingCharacters(in: .whitespaces)
        guard strippedRemainder.isEmpty else {
            return nil
        }

        return consumed + word
    }

    private func suffixPrefixOverlap(
        _ previousText: String,
        _ currentText: String,
        minimumLength: Int
    ) -> Int? {
        let maximumLength = min(previousText.count, currentText.count - 1)
        guard maximumLength >= minimumLength else {
            return nil
        }

        for length in stride(from: maximumLength, through: minimumLength, by: -1) {
            if previousText.suffix(length) == currentText.prefix(length) {
                return length
            }
        }

        return nil
    }
}

private extension String {
    var containsCodeMirrorInvisibleScaffolding: Bool {
        unicodeScalars.contains(where: \.isCodeMirrorInvisibleScaffoldingMarker)
    }

    func trimmingCodeMirrorScaffoldingRight() -> String {
        var scalars = unicodeScalars
        while let last = scalars.last,
              last.isCodeMirrorScaffolding {
            scalars.removeLast()
        }
        return String(scalars)
    }

    func removingCodeMirrorScaffoldingMarkers() -> String {
        String(unicodeScalars.filter { scalar in
            !scalar.isCodeMirrorScaffoldingMarker
        })
    }
}

private extension Unicode.Scalar {
    var isCodeMirrorInvisibleScaffoldingMarker: Bool {
        switch value {
        case 0x0009, // tab
             0x200B, // zero-width space
             0x200C, // zero-width non-joiner
             0x200D, // zero-width joiner
             0x2060, // word joiner
             0xFEFF, // zero-width no-break space
             0xFFFC: // object replacement character
            return true
        default:
            return false
        }
    }
}

// MARK: - Small standalone Obsidian policies
//
// These were previously five separate files. They have no coupling to
// `ObsidianCodeMirrorRepairPolicy` above or to each other — each guards its
// own narrow "is this an Obsidian quirk we should special-case" question for a
// different call site (full-accept caret repair, insertion verification fast
// path, the proof-document insertion planner, trusted end-of-document snapshot
// memory, and Tab passthrough repair). Co-located here rather than merged,
// since merging unrelated decisions would just recreate the compounding-gates
// problem this refactor is trying to avoid.

public struct ObsidianFullAcceptCaretRepairPolicy: Equatable, Sendable {
    public init() {}

    public func shouldRepair(
        bundleIdentifier: String,
        action: KeyboardAction?,
        snapshot: FocusedTextSnapshot?,
        currentFieldIdentity: FocusedFieldIdentity?
    ) -> Bool {
        guard bundleIdentifier == "md.obsidian",
              action == .acceptAllVisible,
              let snapshot,
              !snapshot.textBeforeCursor.isEmpty,
              snapshot.textAfterCursor.isEmpty,
              snapshot.fieldIdentity == currentFieldIdentity else {
            return false
        }

        return true
    }
}

public struct ObsidianInsertionVerificationFastPathPolicy: Equatable, Sendable {
    public init() {}

    public func canVerifyLengthMatchedSuffix(
        appBundleIdentifier: String,
        previousTextBeforeCursor: String,
        acceptedText: String,
        currentTextBeforeCursor: String,
        previousTextAfterCursor: String,
        currentTextAfterCursor: String,
        verificationResult: InsertionVerificationResult
    ) -> Bool {
        guard appBundleIdentifier == "md.obsidian",
              verificationResult == .changedUnexpectedly,
              !acceptedText.isEmpty,
              acceptedText.utf16.count <= 24,
              previousTextBeforeCursor.utf16.count >= 120,
              previousTextAfterCursor.isEmpty,
              currentTextAfterCursor.isEmpty,
              currentTextBeforeCursor.utf16.count == previousTextBeforeCursor.utf16.count + acceptedText.utf16.count,
              currentTextBeforeCursor.hasSuffix(acceptedText) else {
            return false
        }

        return true
    }
}

public struct ObsidianProofDocumentInsertionPlan: Equatable, Sendable {
    public let replacementText: String
    public let cursorUTF16Offset: Int
    public let matchSource: String

    public init(replacementText: String, cursorUTF16Offset: Int, matchSource: String) {
        self.replacementText = replacementText
        self.cursorUTF16Offset = cursorUTF16Offset
        self.matchSource = matchSource
    }
}

public struct ObsidianProofDocumentInsertionPlanner: Equatable, Sendable {
    public init() {}

    public func plan(
        proofDocumentText: String,
        textBeforeCursor: String,
        textAfterCursor: String,
        acceptedText: String,
        marker: String = "Autocomplete Lab Obsidian proof"
    ) -> ObsidianProofDocumentInsertionPlan? {
        guard !proofDocumentText.isEmpty,
              !textBeforeCursor.isEmpty,
              !acceptedText.isEmpty,
              proofDocumentText.localizedCaseInsensitiveContains(marker) else {
            return nil
        }

        let previousText = textBeforeCursor + textAfterCursor
        let replacementSlice = textBeforeCursor + acceptedText + textAfterCursor
        if textAfterCursor.isEmpty,
           proofDocumentText.hasSuffix(textBeforeCursor) {
            return ObsidianProofDocumentInsertionPlan(
                replacementText: proofDocumentText + acceptedText,
                cursorUTF16Offset: proofDocumentText.utf16.count + acceptedText.utf16.count,
                matchSource: "proofDocumentVisibleTail"
            )
        }

        if let exactRange = proofDocumentText.range(of: previousText, options: .backwards) {
            let replacementText = proofDocumentText.replacingCharacters(
                in: exactRange,
                with: replacementSlice
            )
            let cursorUTF16Offset = proofDocumentText[..<exactRange.lowerBound].utf16.count
                + textBeforeCursor.utf16.count
                + acceptedText.utf16.count
            return ObsidianProofDocumentInsertionPlan(
                replacementText: replacementText,
                cursorUTF16Offset: cursorUTF16Offset,
                matchSource: "proofDocumentExact"
            )
        }
        return nil
    }
}

public struct ObsidianTrustedEndOfDocumentSnapshotPolicy: Sendable {
    public init() {}

    public func repairPreviousSnapshot(
        fieldIdentity: FocusedFieldIdentity,
        previousSnapshot: FocusedTextSnapshot?,
        trustedSnapshot: FocusedTextSnapshot?
    ) -> FocusedTextSnapshot? {
        guard fieldIdentity.bundleIdentifier == "md.obsidian" else {
            return previousSnapshot
        }

        if let previousSnapshot,
           previousSnapshot.fieldIdentity == fieldIdentity,
           previousSnapshot.textAfterCursor.isEmpty {
            return previousSnapshot
        }

        guard let trustedSnapshot,
              trustedSnapshot.fieldIdentity == fieldIdentity,
              shouldRemember(snapshot: trustedSnapshot) else {
            return previousSnapshot
        }

        return trustedSnapshot
    }

    public func shouldRemember(snapshot: FocusedTextSnapshot) -> Bool {
        snapshot.fieldIdentity.bundleIdentifier == "md.obsidian"
            && snapshot.textAfterCursor.isEmpty
            && snapshot.textBeforeCursor.count >= 300
            && snapshot.textBeforeCursor.last?.isNewline != true
    }
}

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
