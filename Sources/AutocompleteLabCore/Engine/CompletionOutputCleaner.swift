import Foundation

public enum CompletionCleanRejectionReason: String, Sendable {
    case unsafeHiddenOrControlCharacter
    case emptyOutput
    case noSuggestionSentinel
    case promptInstructionEcho
    case emptyAfterPrefixTrimming
    case replaysContext
    case repeatsItself
}

public enum CompletionCleanResult: Sendable {
    case accepted(CompletionSuggestion)
    case rejected(CompletionCleanRejectionReason)

    public var suggestion: CompletionSuggestion? {
        guard case let .accepted(suggestion) = self else { return nil }
        return suggestion
    }

    public var rejectionReason: CompletionCleanRejectionReason? {
        guard case let .rejected(reason) = self else { return nil }
        return reason
    }
}

public struct CompletionOutputCleaner: Sendable {
    private static let noSuggestion = "<no_suggestion>"
    private static let wrappers = CharacterSet(charactersIn: "\"'`")
    private static let unsafeScalars: Set<Unicode.Scalar> = [
        "\u{200B}", "\u{200C}", "\u{200D}", "\u{2060}", "\u{FEFF}",
    ]
    private static let instructionPrefixes = [
        "the following are real chat messages being written by their authors",
        "the following are real emails being written by their authors",
        "the following are real documents being written by their authors",
        "system:", "assistant:",
        "thinking process", "analyze the request", "okay, let's see", "okay, the user",
    ]
    private static let refusalMarkers = [
        "i cannot assist", "i can't assist", "cannot help with that",
    ]

    private let maxVisibleWords: Int

    public init(maxVisibleWords: Int = CompletionSuggestion.defaultMaxVisibleWords) {
        self.maxVisibleWords = CompletionSuggestion.clampedVisibleWords(maxVisibleWords)
    }

    public func cleanWithReason(
        _ rawOutput: String,
        after textBeforeCursor: String?
    ) -> CompletionCleanResult {
        guard !containsUnsafeCharacter(rawOutput) else {
            return .rejected(.unsafeHiddenOrControlCharacter)
        }

        var candidate = rawOutput
            .replacingOccurrences(of: #"(?is)<think>.*?</think>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)</?think>"#, with: "", options: .regularExpression)
            .components(separatedBy: .newlines)[0]
        candidate = unwrapped(candidate)

        guard !candidate.isEmpty else { return .rejected(.emptyOutput) }
        guard !isNoSuggestion(candidate) else { return .rejected(.noSuggestionSentinel) }

        candidate = unwrapped(strippingAnswerLabel(from: candidate))
        guard !candidate.isEmpty else { return .rejected(.emptyOutput) }
        guard !isNoSuggestion(candidate) else { return .rejected(.noSuggestionSentinel) }
        guard !isInstructionLeak(candidate) else { return .rejected(.promptInstructionEcho) }

        var continuation = candidate.first?.isWhitespace == true ? candidate : " " + candidate
        if let textBeforeCursor {
            continuation = trimTypedPrefix(continuation, after: textBeforeCursor)
        }
        guard !continuation.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .rejected(.emptyAfterPrefixTrimming)
        }
        if let textBeforeCursor, replaysContext(continuation, context: textBeforeCursor) {
            return .rejected(.replaysContext)
        }

        let deduped = trimmingSelfRepetition(continuation)
        if deduped != continuation {
            guard deduped.contains(where: { $0.isLetter || $0.isNumber }) else {
                return .rejected(.repeatsItself)
            }
            continuation = deduped
        }

        return .accepted(CompletionSuggestion(text: continuation, maxVisibleWords: maxVisibleWords))
    }

    private func unwrapped(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: Self.wrappers)
    }

    private func isNoSuggestion(_ text: String) -> Bool {
        unwrapped(text).lowercased() == Self.noSuggestion
    }

    private func strippingAnswerLabel(from text: String) -> String {
        text.replacingOccurrences(
            of: #"^(?:candidate\s+\d+\s*[\).:-]\s*|(?:next words?|continuation|completion|suggestion|suffix)\s*:\s*)"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    private func isInstructionLeak(_ text: String) -> Bool {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.range(
            of: #"^(?:(?:i(?:['’]m| am) sorry,\s*(?:but\s+)?)as (?:an ai(?: assistant| chatbot| language model)?|a language model)\b|as (?:an ai(?: assistant| chatbot| language model)?|a language model)\b[,\s]+(?:i|my)\b|i(?:['’]m| am) (?:an ai(?: assistant| chatbot| language model)?|a language model)\b)"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        if normalized.range(
            of: #"^(?:candidate\s+\d+|next(?:\s+\d+-\d+)? words?|continuation|completion|suggestion|suffix)\s*:?(?:,\s*or\s*<no_suggestion>)?$"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        return Self.instructionPrefixes.contains(where: normalized.hasPrefix)
            || Self.refusalMarkers.contains(where: normalized.contains)
    }

    private func containsUnsafeCharacter(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            Self.unsafeScalars.contains(scalar)
                || (scalar != "\n" && scalar != "\r" && CharacterSet.controlCharacters.contains(scalar))
        }
    }

    private func trimTypedPrefix(_ suggestion: String, after context: String) -> String {
        if context.last?.isWhitespace == true {
            let dropped = String(suggestion.drop(while: \.isWhitespace))
            // The word-boundary-only echo guard: when the cursor sits right
            // after whitespace, the last typed word is complete, so unlike
            // the branch below there is no partial-word case to consider —
            // only "does the suggestion open by re-typing the tail of what's
            // already on screen." Screen-context prompts (Conversation/
            // Reference blocks ahead of `Text:`) make this common: a model
            // echoing its own just-read context back is exactly the
            // observed live bug (typed "Sure, I will " -> ghost "I will try
            // to get back to you", a 2-word echo `replaysContext` never sees
            // because that check only fires on 3+-word overlaps). Any
            // leading run of fully-repeated words — down to a single word —
            // gets stripped here, before `replaysContext`'s coarser check
            // ever runs.
            return stripLeadingWordEcho(dropped, typedContext: context)
        }
        // A punctuation-only trailing token has no fragment. Treating its
        // normalized empty string as a prefix used to drop the first character.
        guard context.last?.isLetter == true else { return suggestion }

        let contextWords = normalizedWords(in: context)
        let suggestionRanges = wordRanges(in: suggestion)
        let suggestionWords = suggestionRanges.map { normalized(String(suggestion[$0])) }
        guard !contextWords.isEmpty, !suggestionWords.isEmpty else { return suggestion }

        for count in stride(from: min(contextWords.count, suggestionWords.count), through: 1, by: -1) {
            let typed = Array(contextWords.suffix(count))
            let offered = Array(suggestionWords.prefix(count))
            if typed == offered {
                guard count < suggestionRanges.count else { return "" }
                return " " + suggestion[suggestionRanges[count].lowerBound...]
            }

            guard typed.dropLast() == offered.dropLast(),
                  let typedLast = typed.last,
                  let offeredLast = offered.last,
                  !typedLast.isEmpty,
                  offeredLast.hasPrefix(typedLast),
                  typedLast.count < offeredLast.count else { continue }
            let range = suggestionRanges[count - 1]
            guard let start = suggestion.index(
                range.lowerBound,
                offsetBy: typedLast.count,
                limitedBy: range.upperBound
            ) else { continue }
            return String(suggestion[start...])
        }
        return suggestion
    }

    /// Strips a leading run of whole words in `suggestion` that exactly
    /// repeats the tail of `typedContext`, longest match first (so "I will"
    /// trims as one unit rather than leaving a dangling "will"). Only exact,
    /// case/punctuation-normalized whole-word matches count — this runs only
    /// when `typedContext` ends in whitespace, so there is no partial last
    /// word to reason about the way `trimTypedPrefix`'s other branch does.
    private func stripLeadingWordEcho(_ suggestion: String, typedContext: String) -> String {
        let contextWords = normalizedWords(in: typedContext)
        let suggestionRanges = wordRanges(in: suggestion)
        let suggestionWords = suggestionRanges.map { normalized(String(suggestion[$0])) }
        guard !contextWords.isEmpty, !suggestionWords.isEmpty else { return suggestion }

        for count in stride(from: min(contextWords.count, suggestionWords.count), through: 1, by: -1) {
            let typed = Array(contextWords.suffix(count))
            let offered = Array(suggestionWords.prefix(count))
            guard typed == offered else { continue }
            guard count < suggestionRanges.count else { return "" }
            return String(suggestion[suggestionRanges[count].lowerBound...])
        }
        return suggestion
    }

    private func replaysContext(_ suggestion: String, context: String) -> Bool {
        let offered = normalizedWords(in: suggestion)
        let typed = normalizedWords(in: context)
        guard offered.count >= 3, typed.count >= 3 else { return false }

        for size in stride(from: min(4, offered.count), through: 3, by: -1) {
            if contains(Array(offered.prefix(size)), in: typed) { return true }
        }
        guard offered.count >= 4 else { return false }
        return offered.indices.dropLast(3).contains { index in
            contains(Array(offered[index..<offered.index(index, offsetBy: 4)]), in: typed)
        }
    }

    /// Live dogfood regression (build 2705, rapid-fire chat): typed
    /// "Hey I am", ghost offered " here, I am here." — the suggestion's own
    /// tail re-states its opening clause. `replaysContext` only compares
    /// against the TYPED context, so a model looping on its own words sails
    /// through. This trims the suggestion at the point where it starts
    /// repeating itself: a 3-word run repeated back-to-back ("let me know
    /// let me know"), a clause identical to an earlier clause ("sounds
    /// good, sounds good"), or a final clause that ENDS by re-stating a
    /// whole earlier clause (the observed "here, … here." loop). Two
    /// deliberate false-positive guards, both from independent review:
    /// the run rule requires ADJACENT repetition, so parallel rhetoric
    /// ("the more you practice, the more you improve") survives; and the
    /// end-anchored rule stands down when the echo sits behind a negator
    /// the earlier clause didn't have ("done. It is not done"), where
    /// trimming would ship the OPPOSITE of what the model said.
    private func trimmingSelfRepetition(_ suggestion: String) -> String {
        let clauseBreaks: Set<Character> = [",", ".", ";", ":", "!", "?"]
        var wordStarts: [String.Index] = []
        var words: [String] = []
        var endsClause: [Bool] = []
        for range in wordRanges(in: suggestion) {
            let token = String(suggestion[range])
            let word = normalized(token)
            let breaksHere = token.last.map(clauseBreaks.contains) ?? false
            if !word.isEmpty {
                wordStarts.append(range.lowerBound)
                words.append(word)
                endsClause.append(breaksHere)
            } else if breaksHere, !endsClause.isEmpty {
                // A detached punctuation token still closes the clause of
                // the word before it.
                endsClause[endsClause.count - 1] = true
            }
        }
        guard words.count >= 2 else { return suggestion }

        var cut = words.count

        if words.count >= 6 {
            for start in 3...(words.count - 3) where Array(words[start - 3..<start]) == Array(words[start..<start + 3]) {
                cut = start
                break
            }
        }

        var clauses: [[Int]] = [[]]
        for index in words.indices {
            clauses[clauses.count - 1].append(index)
            if endsClause[index], index < words.count - 1 {
                clauses.append([])
            }
        }
        for j in 1..<clauses.count {
            let clause = clauses[j].map { words[$0] }
            let earlier = clauses[0..<j].map { indices in indices.map { words[$0] } }
            let exactRepeat = earlier.contains { $0 == clause }
            let finalClauseEndsOnEarlierClause = j == clauses.count - 1 && earlier.contains { earlierClause in
                guard clause.count > earlierClause.count,
                      Array(clause.suffix(earlierClause.count)) == earlierClause else { return false }
                let beforeEcho = clause.prefix(clause.count - earlierClause.count)
                return !beforeEcho.contains(where: isNegator) || earlierClause.contains(where: isNegator)
            }
            guard exactRepeat || finalClauseEndsOnEarlierClause else { continue }
            cut = min(cut, clauses[j][0])
            break
        }

        guard cut < words.count else { return suggestion }
        var trimmed = String(suggestion[..<wordStarts[cut]])
        while let last = trimmed.last, last.isWhitespace || last == "," || last == ";" || last == ":" {
            trimmed.removeLast()
        }
        return trimmed
    }

    private static let negators: Set<String> = ["not", "no", "never", "none", "cannot", "nor"]

    private func isNegator(_ word: String) -> Bool {
        Self.negators.contains(word) || word.hasSuffix("n't") || word.hasSuffix("n\u{2019}t")
    }

    private func contains(_ needle: [String], in words: [String]) -> Bool {
        guard words.count >= needle.count else { return false }
        return words.indices.dropLast(needle.count - 1).contains { index in
            Array(words[index..<words.index(index, offsetBy: needle.count)]) == needle
        }
    }

    private func normalizedWords(in text: String) -> [String] {
        wordRanges(in: text).map { normalized(String(text[$0])) }.filter { !$0.isEmpty }
    }

    private func wordRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var start: String.Index?
        for index in text.indices {
            if text[index].isWhitespace {
                if let start { ranges.append(start..<index) }
                start = nil
            } else if start == nil {
                start = index
            }
        }
        if let start { ranges.append(start..<text.endIndex) }
        return ranges
    }

    private func normalized(_ word: String) -> String {
        word.trimmingCharacters(in: .punctuationCharacters).lowercased()
    }
}
