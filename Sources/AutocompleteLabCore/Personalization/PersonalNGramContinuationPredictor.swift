import Foundation

public struct PersonalNGramContinuationPredictor: Equatable, Sendable {
    public let minimumMatchWords: Int
    public let maximumMatchWords: Int

    public init(minimumMatchWords: Int = 2, maximumMatchWords: Int = 4) {
        self.minimumMatchWords = max(2, minimumMatchWords)
        self.maximumMatchWords = min(4, max(self.minimumMatchWords, maximumMatchWords))
    }

    public func selection(
        for request: CompletionRequest,
        memory: PersonalWritingMemory,
        allowsPromptAppPrediction: Bool = false
    ) -> CommonPhraseContinuationSelection {
        selection(
            for: request.textBeforeCursor,
            memory: memory,
            behaviorProfileID: request.behaviorProfileID,
            maxVisibleWords: request.maxVisibleWords,
            allowsPromptAppPrediction: allowsPromptAppPrediction
        )
    }

    public func selection(
        for textBeforeCursor: String,
        memory: PersonalWritingMemory,
        behaviorProfileID: AutocompleteBehaviorProfileID?,
        maxVisibleWords: Int = 4,
        allowsPromptAppPrediction: Bool = false
    ) -> CommonPhraseContinuationSelection {
        guard allowsPrediction(for: behaviorProfileID, allowsPromptAppPrediction: allowsPromptAppPrediction) else {
            return noSuggestion("unsupported-profile")
        }
        guard let last = textBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines).last,
              last.isLetter || last.isNumber else {
            return noSuggestion("not-word-boundary")
        }
        let words = PersonalWritingMemory.normalizedWords(in: textBeforeCursor)
        guard words.count >= minimumMatchWords else { return noSuggestion("too-little-context") }
        let maxOrder = min(maximumMatchWords, words.count)
        for order in stride(from: maxOrder, through: minimumMatchWords, by: -1) {
            let key = words.suffix(order).joined(separator: " ")
            guard let best = memory.ngramContinuations[key]?
                .filter({ PersonalSnippetSafetyFilter().allows($0.display) })
                .sorted(by: {
                    if abs($0.weight - $1.weight) > 0.000_001 { return $0.weight > $1.weight }
                    if $0.lastSeenDay != $1.lastSeenDay { return $0.lastSeenDay > $1.lastSeenDay }
                    return $0.display < $1.display
                })
                .first else { continue }
            let visibleWords = best.display.split(whereSeparator: { $0.isWhitespace }).prefix(CompletionModelPolicy.clampedVisibleWords(maxVisibleWords))
            guard !visibleWords.isEmpty else { continue }
            return CommonPhraseContinuationSelection(
                suggestion: CompletionSuggestion(text: " " + visibleWords.joined(separator: " "), maxVisibleWords: maxVisibleWords),
                matchedContextSuffix: "order-\(order)",
                score: best.weight,
                suppressionReason: nil,
                candidateSelectionSource: "personal-ngram",
                matchMetadataKey: "personalNGramMatch"
            )
        }
        return noSuggestion("no-personal-match")
    }

    private func allowsPrediction(for profile: AutocompleteBehaviorProfileID?, allowsPromptAppPrediction: Bool) -> Bool {
        switch profile {
        case .some(.aiChat): return allowsPromptAppPrediction
        case .some(.docsProse), .some(.notes), .some(.bullets), .none: return true
        case .some: return false
        }
    }

    private func noSuggestion(_ reason: String) -> CommonPhraseContinuationSelection {
        CommonPhraseContinuationSelection(
            suggestion: nil,
            matchedContextSuffix: nil,
            score: nil,
            suppressionReason: reason,
            candidateSelectionSource: "personal-ngram",
            matchMetadataKey: "personalNGramMatch"
        )
    }
}
