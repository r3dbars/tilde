import Foundation

public struct RankedCompletionCandidate: Equatable, Sendable {
    public let suggestion: CompletionSuggestion
    public let score: Double

    public init(suggestion: CompletionSuggestion, score: Double) {
        self.suggestion = suggestion
        self.score = score
    }
}

public enum CompletionCandidateSuppressionReason: String, Equatable, Sendable {
    case noCandidates = "no-candidates"
    case lowTopScore = "low-top-score"
    case lowScoreMargin = "low-score-margin"
}

public struct CompletionCandidateSelection: Equatable, Sendable {
    public let rankedCandidates: [RankedCompletionCandidate]
    public let selectedCandidate: RankedCompletionCandidate?
    public let scoreMargin: Double?
    public let suppressionReason: CompletionCandidateSuppressionReason?

    public init(
        rankedCandidates: [RankedCompletionCandidate],
        selectedCandidate: RankedCompletionCandidate?,
        scoreMargin: Double?,
        suppressionReason: CompletionCandidateSuppressionReason?
    ) {
        self.rankedCandidates = rankedCandidates
        self.selectedCandidate = selectedCandidate
        self.scoreMargin = scoreMargin
        self.suppressionReason = suppressionReason
    }

    public var suggestion: CompletionSuggestion? {
        selectedCandidate?.suggestion
    }

    public var traceMetadata: [String: String] {
        [
            "candidateCount": String(rankedCandidates.count),
            "candidateTopScore": selectedCandidate.map { Self.format($0.score) }
                ?? rankedCandidates.first.map { Self.format($0.score) }
                ?? "0.00",
            "candidateScoreMargin": scoreMargin.map(Self.format) ?? "none",
            "candidateSuppressionReason": suppressionReason?.rawValue ?? "none"
        ]
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

public struct CompletionCandidateRanker: Equatable, Sendable {
    public let minimumScoreMargin: Double

    public init(minimumScoreMargin: Double = 0.05) {
        self.minimumScoreMargin = max(0, minimumScoreMargin)
    }

    public func ranked(
        _ suggestions: [CompletionSuggestion],
        mode: CompletionRequestMode,
        textBeforeCursor: String? = nil,
        behaviorProfileID: AutocompleteBehaviorProfileID? = nil
    ) -> [RankedCompletionCandidate] {
        suggestions
            .map { suggestion in
                RankedCompletionCandidate(
                    suggestion: suggestion,
                    score: score(
                        suggestion,
                        mode: mode,
                        textBeforeCursor: textBeforeCursor,
                        behaviorProfileID: behaviorProfileID
                    )
                )
            }
            .sorted {
                if abs($0.score - $1.score) > 0.0001 {
                    return $0.score > $1.score
                }

                return $0.suggestion.visibleText.count < $1.suggestion.visibleText.count
            }
    }

    public func best(
        _ suggestions: [CompletionSuggestion],
        mode: CompletionRequestMode,
        textBeforeCursor: String? = nil,
        behaviorProfileID: AutocompleteBehaviorProfileID? = nil
    ) -> CompletionSuggestion? {
        selection(
            suggestions,
            mode: mode,
            textBeforeCursor: textBeforeCursor,
            behaviorProfileID: behaviorProfileID
        ).suggestion
    }

    public func selection(
        _ suggestions: [CompletionSuggestion],
        mode: CompletionRequestMode,
        textBeforeCursor: String? = nil,
        behaviorProfileID: AutocompleteBehaviorProfileID? = nil
    ) -> CompletionCandidateSelection {
        let rankedCandidates = ranked(
            suggestions,
            mode: mode,
            textBeforeCursor: textBeforeCursor,
            behaviorProfileID: behaviorProfileID
        )

        guard let topCandidate = rankedCandidates.first else {
            return CompletionCandidateSelection(
                rankedCandidates: rankedCandidates,
                selectedCandidate: nil,
                scoreMargin: nil,
                suppressionReason: .noCandidates
            )
        }

        guard topCandidate.score >= minimumTopScore(for: mode) else {
            return CompletionCandidateSelection(
                rankedCandidates: rankedCandidates,
                selectedCandidate: nil,
                scoreMargin: nil,
                suppressionReason: .lowTopScore
            )
        }

        let scoreMargin = rankedCandidates.dropFirst().first.map { topCandidate.score - $0.score }
        if let scoreMargin, scoreMargin < minimumScoreMargin {
            return CompletionCandidateSelection(
                rankedCandidates: rankedCandidates,
                selectedCandidate: nil,
                scoreMargin: scoreMargin,
                suppressionReason: .lowScoreMargin
            )
        }

        return CompletionCandidateSelection(
            rankedCandidates: rankedCandidates,
            selectedCandidate: topCandidate,
            scoreMargin: scoreMargin,
            suppressionReason: nil
        )
    }

    private func score(
        _ suggestion: CompletionSuggestion,
        mode: CompletionRequestMode,
        textBeforeCursor: String?,
        behaviorProfileID: AutocompleteBehaviorProfileID?
    ) -> Double {
        let visibleText = suggestion.visibleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = suggestion.visibleWordCount
        var score = 0.5

        switch mode {
        case .wordCompletion:
            score += visibleText.count <= 12 ? 0.35 : 0.15
            score -= visibleText.contains(where: { !$0.isLetter }) ? 0.45 : 0
        case .phraseContinuation:
            score += phraseLengthScore(wordCount)
            score -= visibleText.hasSuffix("?") ? 0.55 : 0
            score -= longPhraseAnnoyancePenalty(wordCount)
        case .sentenceContinuation:
            score += sentenceLengthScore(wordCount)
            score -= visibleText.hasSuffix("?") ? 0.35 : 0
            score -= sentencePlanningDriftPenalty(visibleText)
        }

        if mode.isContinuation {
            score += commonPhrasePriorScore(
                visibleText,
                textBeforeCursor: textBeforeCursor,
                behaviorProfileID: behaviorProfileID
            )
            score += localContextAlignmentScore(visibleText, textBeforeCursor: textBeforeCursor)
            score -= unsupportedCommitmentPenalty(visibleText, textBeforeCursor: textBeforeCursor)
            score -= genericFillerPenalty(visibleText)
            score -= behaviorProfilePenalty(
                visibleText,
                behaviorProfileID: behaviorProfileID,
                textBeforeCursor: textBeforeCursor
            )
        }

        if visibleText.count <= CompletionSuggestion.defaultMaxVisibleCharacters {
            score += 0.10
        }

        return score
    }

    private func commonPhrasePriorScore(
        _ text: String,
        textBeforeCursor: String?,
        behaviorProfileID: AutocompleteBehaviorProfileID?
    ) -> Double {
        guard let textBeforeCursor,
              !textBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              allowsCommonPhrasePrior(for: behaviorProfileID)
        else {
            return 0
        }

        let context = normalizedPhrase(textBeforeCursor)
        let candidateWords = allWords(in: text)
        guard !candidateWords.isEmpty else {
            return 0
        }

        for prior in CommonPhraseContinuationPrior.defaultPriors where context.hasSuffix(prior.contextSuffix) {
            guard candidateWords.starts(with: prior.continuationWords) else {
                continue
            }

            return prior.score
        }

        return 0
    }

    private func allowsCommonPhrasePrior(for behaviorProfileID: AutocompleteBehaviorProfileID?) -> Bool {
        switch behaviorProfileID {
        case .some(.aiChat), .some(.coding), .some(.forms), .some(.search):
            return false
        case .some, .none:
            return true
        }
    }

    private func phraseLengthScore(_ wordCount: Int) -> Double {
        switch wordCount {
        case 3...5:
            return 0.35
        case 2:
            return 0.26
        default:
            return 0.08
        }
    }

    private func longPhraseAnnoyancePenalty(_ wordCount: Int) -> Double {
        switch wordCount {
        case 0...5:
            return 0
        case 6:
            return 0.12
        case 7:
            return 0.20
        default:
            return 0.28
        }
    }

    private func sentenceLengthScore(_ wordCount: Int) -> Double {
        switch wordCount {
        case 4...6:
            return 0.35
        case 3:
            return 0.26
        case 2:
            return 0.14
        default:
            return 0.08
        }
    }

    private func minimumTopScore(for mode: CompletionRequestMode) -> Double {
        switch mode {
        case .wordCompletion:
            return 0.80
        case .phraseContinuation:
            return 0.90
        case .sentenceContinuation:
            return 0.82
        }
    }

    private func localContextAlignmentScore(_ text: String, textBeforeCursor: String?) -> Double {
        guard let textBeforeCursor else {
            return 0
        }

        let localWords = Set(contentWords(in: textBeforeCursor.suffix(240)))
        guard !localWords.isEmpty else {
            return 0
        }

        let candidateWords = Set(contentWords(in: text))
        guard !candidateWords.isEmpty else {
            return 0
        }

        return localWords.isDisjoint(with: candidateWords) ? 0 : 0.06
    }

    private func unsupportedCommitmentPenalty(_ text: String, textBeforeCursor: String?) -> Double {
        guard let textBeforeCursor,
              !textBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return 0
        }

        let contextWords = Set(contentWords(in: textBeforeCursor))
        let unsupportedProperNouns = properNounTokens(in: text)
            .filter { !contextWords.contains($0.lowercased()) }
        let unsupportedDates = dateOrDeadlineWords(in: text)
            .filter { !contextWords.contains($0) }

        var penalty = min(0.30, Double(unsupportedProperNouns.count) * 0.15)
        if !unsupportedDates.isEmpty {
            penalty += 0.18
        }
        return penalty
    }

    private func genericFillerPenalty(_ text: String) -> Double {
        let words = Set(contentWords(in: text))
        let fillerWords: Set<String> = [
            "enhance", "enhanced", "enhancing",
            "leverage", "leveraging",
            "optimize", "optimized", "optimizing",
            "robust", "seamless", "seamlessly",
            "streamline", "streamlined", "unlock"
        ]

        return words.isDisjoint(with: fillerWords) ? 0 : 0.22
    }

    private func behaviorProfilePenalty(
        _ text: String,
        behaviorProfileID: AutocompleteBehaviorProfileID?,
        textBeforeCursor: String?
    ) -> Double {
        guard let behaviorProfileID else {
            return 0
        }

        switch behaviorProfileID {
        case .casualChat:
            return casualChatPenalty(text)
        case .email:
            return emailCommitmentPenalty(text, textBeforeCursor: textBeforeCursor)
        case .notes:
            return notesPenalty(text)
        case .coding:
            return codingSyntaxPenalty(text, textBeforeCursor: textBeforeCursor)
        case .docsProse:
            return docsProsePenalty(text)
        case .bullets:
            return bulletPenalty(text)
        case .aiChat:
            return promptAppActionPenalty(text)
        case .forms, .search:
            return formOrSearchPenalty(text)
        }
    }

    private func casualChatPenalty(_ text: String) -> Double {
        var penalty = text.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?") ? 0.30 : 0
        let words = Set(contentWords(in: text))
        let emotionalWords: Set<String> = [
            "amazing", "anxious", "excited", "hate", "love", "sorry",
            "terrible", "worried"
        ]
        if !words.isDisjoint(with: emotionalWords) {
            penalty += 0.22
        }
        return min(0.42, penalty)
    }

    private func emailCommitmentPenalty(_ text: String, textBeforeCursor: String?) -> Double {
        let words = Set(contentWords(in: text))
        let riskyWords: Set<String> = [
            "attachment", "attachments", "call", "deadline", "meeting",
            "proposal", "schedule", "scheduled", "tomorrow", "today"
        ]
        var penalty = words.isDisjoint(with: riskyWords) ? 0 : 0.28
        penalty += unsupportedCommitmentPenalty(text, textBeforeCursor: textBeforeCursor) * 0.5
        return min(0.45, penalty)
    }

    private func notesPenalty(_ text: String) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var penalty = 0.0
        if trimmed.contains(where: { [".", "!", "?"].contains($0) }) {
            penalty += 0.12
        }

        let words = Set(contentWords(in: text))
        let floweryWords: Set<String> = [
            "comprehensive", "delightful", "essentially", "impactful",
            "meaningful", "significant", "strategic", "transformative"
        ]
        if !words.isDisjoint(with: floweryWords) {
            penalty += 0.22
        }
        return min(0.34, penalty)
    }

    private func codingSyntaxPenalty(_ text: String, textBeforeCursor: String?) -> Double {
        let normalized = normalizedPhrase(text)
        let blockStarters = [
            "class ", "enum ", "func ", "function ", "import ", "let ",
            "struct ", "var "
        ]
        if blockStarters.contains(where: { normalized.hasPrefix($0) }) {
            return 0.35
        }

        if text.contains("\n") {
            return 0.30
        }

        let candidateIdentifiers = codeIdentifiers(in: text)
        let contextIdentifiers = Set(codeIdentifiers(in: textBeforeCursor ?? ""))
        let unsupportedIdentifiers = candidateIdentifiers.filter { identifier in
            !contextIdentifiers.contains(identifier) && identifier.count > 3
        }

        return unsupportedIdentifiers.isEmpty ? 0 : min(0.30, Double(unsupportedIdentifiers.count) * 0.10)
    }

    private func docsProsePenalty(_ text: String) -> Double {
        let normalized = normalizedPhrase(text)
        let newPointPrefixes = [
            "additionally", "another", "finally", "first", "in conclusion",
            "moreover", "next", "second", "the main point"
        ]
        if newPointPrefixes.contains(where: { normalized.hasPrefix($0) }) {
            return 0.28
        }

        return normalized.hasPrefix("#") || normalized.hasPrefix("- ") ? 0.24 : 0
    }

    private func bulletPenalty(_ text: String) -> Double {
        let normalized = normalizedPhrase(text)
        if normalized.hasPrefix("-")
            || normalized.hasPrefix("*")
            || normalized.hasPrefix("[ ]")
            || normalized.hasPrefix("[x]")
            || normalized.range(of: #"^\d+[\.\)]"#, options: .regularExpression) != nil {
            return 0.35
        }

        return 0
    }

    private func promptAppActionPenalty(_ text: String) -> Double {
        let normalized = normalizedPhrase(text)
        if Self.promptCommandPrefixes.contains(where: { normalized.hasPrefix($0) })
            || normalized.hasPrefix("```")
            || normalized.hasPrefix("$ ")
            || normalized.hasPrefix("> ") {
            return 0.75
        }

        if normalized.unicodeScalars.contains(where: Self.promptShellMetacharacters.contains)
            || normalized.unicodeScalars.contains(where: Self.promptHiddenScalars.contains) {
            return 0.75
        }

        let submitPhrases = [
            "press enter", "press return", "run the command", "send it",
            "submit it", "hit enter", "hit return", "click send",
            "approve it", "deploy it", "execute it", "ship it"
        ]
        if submitPhrases.contains(where: { normalized.contains($0) }) {
            return 0.60
        }

        let words = Set(contentWords(in: text))
        return words.isDisjoint(with: Self.promptActionWords) ? 0 : 0.35
    }

    private func formOrSearchPenalty(_ text: String) -> Double {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 0.60
    }

    private func sentencePlanningDriftPenalty(_ text: String) -> Double {
        let normalized = normalizedPhrase(text)
        let planningPrefixes = [
            "action item", "follow up", "let's", "lets", "make sure",
            "make sure to", "next,", "next action", "next step", "remember to",
            "schedule ", "set up", "the next step", "then we can", "we can",
            "we need to", "we should",
            "you can", "you should"
        ]
        if planningPrefixes.contains(where: { normalized.hasPrefix($0) }) {
            return 0.30
        }

        let planningWords: Set<String> = [
            "call", "calls", "deadline", "meeting", "meetings", "proposal",
            "roadmap", "schedule", "scheduled", "sprint", "task", "timeline",
            "today", "tomorrow"
        ]
        return Set(contentWords(in: text)).isDisjoint(with: planningWords) ? 0 : 0.18
    }

    private func properNounTokens(in text: String) -> [String] {
        let rawTokens = text
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
        return rawTokens.enumerated().compactMap { index, token in
            guard index > 0,
                  token.count > 1,
                  token.first?.isUppercase == true,
                  token.dropFirst().allSatisfy(\.isLowercase) else {
                return nil
            }
            return token
        }
    }

    private func dateOrDeadlineWords(in text: String) -> [String] {
        let words = contentWords(in: text)
        let deadlineWords: Set<String> = [
            "today", "tomorrow", "tonight",
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
            "january", "february", "march", "april", "may", "june",
            "july", "august", "september", "october", "november", "december"
        ]
        return words.filter { deadlineWords.contains($0) }
    }

    private func contentWords<S: StringProtocol>(in text: S) -> [String] {
        text
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !Self.stopWords.contains($0) && $0.count > 2 }
    }

    private func codeIdentifiers(in text: String) -> [String] {
        text
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "_" })
            .map(String.init)
            .filter { token in
                guard let first = token.first else {
                    return false
                }
                return first.isLetter || first == "_"
            }
    }

    private func normalizedPhrase(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private func allWords(in text: String) -> [String] {
        normalizedPhrase(text)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    private static let promptCommandPrefixes = [
        "/", "!", "@", "--", "sudo ", "curl ", "bash ", "sh ", "rm "
    ]

    private static let promptShellMetacharacters: Set<Unicode.Scalar> = [
        "|", "&", ";", "<", ">", "$", "\\", "(", ")", "{", "}", "[", "]", "*", "?"
    ]

    private static let promptHiddenScalars: Set<Unicode.Scalar> = [
        "\u{200B}",
        "\u{200C}",
        "\u{200D}",
        "\u{2060}",
        "\u{FEFF}"
    ]

    private static let promptActionWords: Set<String> = [
        "allow", "approve", "bash", "click", "curl", "delete", "deploy",
        "enter", "execute", "merge", "return", "run", "send", "ship",
        "submit", "sudo"
    ]

    private static let stopWords: Set<String> = [
        "and", "are", "but", "can", "for", "from", "had", "has", "have",
        "her", "his", "its", "not", "our", "out", "she", "that", "the",
        "their", "then", "this", "was", "with", "you", "your"
    ]
}
