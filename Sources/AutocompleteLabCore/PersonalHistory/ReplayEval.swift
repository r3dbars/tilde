import Foundation

/// One scoreable point recovered from retained Personal History: `context` is
/// the text the user had actually typed right before a fresh word, and
/// `golden` is the words they actually typed next. A replay run asks the
/// production suggestion engine what it would have suggested at `context` and
/// grades the answer against `golden`.
///
/// Boundary extraction mirrors the fresh-word eligibility notion used by the
/// live paired shadow (`PersonalNextWordShadow`): the first word of a stream,
/// and the first word after any accepted-suggestion event, is never itself a
/// golden target — only used as context. `golden` never crosses into text
/// that followed an accepted suggestion, so replay truth is always the user's
/// own keystrokes.
public struct PersonalReplayBoundary: Equatable, Sendable {
    public let context: String
    public let appBundleIdentifier: String
    public let golden: String
}

public struct PersonalReplayEvalExtraction: Equatable, Sendable {
    public let boundaries: [PersonalReplayBoundary]
    /// Every uninterrupted run of typed words observed, whether or not it
    /// produced a scoreable boundary (a one-word segment contributes zero).
    public let totalSegments: Int
    /// Every eligible boundary observed before `limit` selected the most
    /// recent ones. Lets a caller report how much signal was available.
    public let totalEligibleBoundaries: Int
}

/// Pure, deterministic replay-eval logic: no I/O, no process/network/socket
/// work, and no randomness — the same events always produce the same
/// boundaries in the same order.
public enum PersonalReplayEval {
    public static let defaultLimit = 500
    /// Matches `RawContinuationPrompt`'s default production context bound.
    public static let maximumContextCharacters = 3_000
    public static let maximumGoldenWords = 24
    static let maximumTokenCharacters = 30
    static let streamGapMilliseconds: Int64 = 30 * 60 * 1_000

    private struct StreamKey: Hashable {
        let history, consent, session, app: String
    }

    private struct WordSpan {
        let word: String
        let contextBefore: String
    }

    private struct Accumulator {
        let appBundleIdentifier: String
        var contextText = ""
        var pendingToken = ""
        var tokenTooLong = false
        var discardNextWord = false
        var contextBeforeToken = ""
        var segmentWords: [WordSpan] = []
        var lastTimestampMilliseconds: Int64?
        var segments = 0

        /// Returns boundaries newly finalized by this event (i.e. when this
        /// event closes a prior segment). The event's own effect on the
        /// still-open segment is reflected only in later calls.
        mutating func consume(_ event: PersonalHistoryEvent) -> [PersonalReplayBoundary] {
            var emitted: [PersonalReplayBoundary] = []
            if let last = lastTimestampMilliseconds,
               event.timestampMilliseconds < last
                || event.timestampMilliseconds - last > PersonalReplayEval.streamGapMilliseconds {
                emitted.append(contentsOf: finishSegment())
                // A gap or reorder starts a fresh segment in a fresh document
                // context — unlike an accepted suggestion, prior text does not
                // carry forward as real, contiguous context.
                contextText = ""
            }
            lastTimestampMilliseconds = event.timestampMilliseconds

            if event.source == .acceptedSuggestion {
                emitted.append(contentsOf: finishSegment())
                let endsInLetter = event.text.precomposedStringWithCanonicalMapping
                    .unicodeScalars.last.map(PersonalReplayEval.isLetter) ?? false
                discardNextWord = endsInLetter
                appendRaw(event.text)
                return emitted
            }

            for scalar in event.text.precomposedStringWithCanonicalMapping.unicodeScalars {
                consumeScalar(scalar)
            }
            return emitted
        }

        /// Call once after the last event of this stream to flush its final
        /// still-open segment.
        mutating func finish() -> [PersonalReplayBoundary] { finishSegment() }

        private mutating func appendRaw(_ text: String) {
            contextText += text
            let cap = PersonalReplayEval.maximumContextCharacters * 2
            if contextText.count > cap {
                contextText = String(contextText.suffix(PersonalReplayEval.maximumContextCharacters))
            }
        }

        private mutating func consumeScalar(_ scalar: Unicode.Scalar) {
            let letter = PersonalReplayEval.isLetter(scalar)
            if letter, pendingToken.isEmpty, !tokenTooLong {
                contextBeforeToken = String(contextText.suffix(PersonalReplayEval.maximumContextCharacters))
            }
            let character = Character(scalar)
            appendRaw(String(character))

            if letter {
                guard !tokenTooLong else { return }
                pendingToken.append(character)
                if pendingToken.unicodeScalars.count > PersonalReplayEval.maximumTokenCharacters {
                    pendingToken = ""
                    tokenTooLong = true
                }
                return
            }
            if PersonalReplayEval.isMark(scalar), !tokenTooLong, !pendingToken.isEmpty {
                let combined = pendingToken + String(character)
                if combined.unicodeScalars.allSatisfy(PersonalReplayEval.isLetter) {
                    pendingToken = combined
                    return
                }
            }
            finishToken()
        }

        private mutating func finishToken() {
            defer {
                pendingToken = ""
                tokenTooLong = false
            }
            guard !tokenTooLong, !pendingToken.isEmpty,
                  (1...PersonalReplayEval.maximumTokenCharacters)
                    .contains(pendingToken.unicodeScalars.count) else { return }
            defer { discardNextWord = false }
            guard !discardNextWord else { return }
            segmentWords.append(WordSpan(word: pendingToken, contextBefore: contextBeforeToken))
        }

        private mutating func finishSegment() -> [PersonalReplayBoundary] {
            defer {
                segmentWords.removeAll(keepingCapacity: true)
                pendingToken = ""
                tokenTooLong = false
                contextBeforeToken = ""
            }
            guard !segmentWords.isEmpty else { return [] }
            segments += 1
            guard segmentWords.count > 1 else { return [] }
            var boundaries: [PersonalReplayBoundary] = []
            for index in 1..<segmentWords.count {
                let context = String(
                    segmentWords[index].contextBefore.suffix(PersonalReplayEval.maximumContextCharacters)
                )
                // Production only ever requests a phrase suggestion when the
                // caret sits right after whitespace (`GhostInputController`);
                // a context ending in punctuation such as `'` or `-` (e.g.
                // mid-"don't", mid-"follow-up") is a case production never
                // sends, so it would only skew the metrics.
                guard context.last?.isWhitespace == true else { continue }
                let goldenWords = segmentWords[index...].prefix(PersonalReplayEval.maximumGoldenWords)
                boundaries.append(PersonalReplayBoundary(
                    context: context,
                    appBundleIdentifier: appBundleIdentifier,
                    golden: goldenWords.map(\.word).joined(separator: " ")
                ))
            }
            return boundaries
        }
    }

    /// Walks retained events in the order given (assumed chronological, the
    /// order the store appends and replays them) and extracts every eligible
    /// fresh-word boundary, then keeps the most recent `limit`.
    public static func extract(
        from events: [PersonalHistoryEvent],
        limit: Int = defaultLimit
    ) -> PersonalReplayEvalExtraction {
        guard limit > 0 else { return PersonalReplayEvalExtraction(
            boundaries: [], totalSegments: 0, totalEligibleBoundaries: 0
        ) }
        var perStream: [StreamKey: Accumulator] = [:]
        var order: [StreamKey] = []
        // Only the most recent `limit` boundaries are ever returned, so
        // retaining every eligible boundary seen across a mature, multi-
        // megabyte history (each carrying up to `maximumContextCharacters`
        // of context) would scale memory with total history size instead of
        // with `limit`. Keep a tail bounded to a small multiple of `limit`
        // instead, trimming as we go.
        var tail: [PersonalReplayBoundary] = []
        var totalEligibleBoundaries = 0
        // Keep the arithmetic safe for a direct caller or CLI user passing
        // an unusually large positive limit. The history input is bounded by
        // the caller, so no useful trimming threshold is lost in this case.
        let trimThreshold = limit <= Int.max / 4 ? limit * 4 : Int.max

        func absorb(_ boundaries: [PersonalReplayBoundary]) {
            guard !boundaries.isEmpty else { return }
            totalEligibleBoundaries += boundaries.count
            tail.append(contentsOf: boundaries)
            if tail.count > trimThreshold {
                tail.removeFirst(tail.count - limit)
            }
        }

        for event in events {
            let key = StreamKey(
                history: event.historyIdentifier, consent: event.consentIdentifier,
                session: event.sessionIdentifier, app: event.appBundleIdentifier
            )
            if perStream[key] == nil {
                perStream[key] = Accumulator(appBundleIdentifier: event.appBundleIdentifier)
                order.append(key)
            }
            absorb(perStream[key]!.consume(event))
        }
        var totalSegments = 0
        // Flush each stream's still-open final segment in the chronological
        // order its last event actually occurred, not first-seen-stream
        // order — otherwise, with several interleaved streams, the tail cut
        // below could keep an older boundary from one stream over a newer
        // one from another.
        let finishOrder = order.sorted {
            (perStream[$0]!.lastTimestampMilliseconds ?? 0) < (perStream[$1]!.lastTimestampMilliseconds ?? 0)
        }
        for key in finishOrder {
            absorb(perStream[key]!.finish())
            totalSegments += perStream[key]!.segments
        }
        if tail.count > limit {
            tail.removeFirst(tail.count - limit)
        }
        return PersonalReplayEvalExtraction(
            boundaries: tail,
            totalSegments: totalSegments,
            totalEligibleBoundaries: totalEligibleBoundaries
        )
    }

    // MARK: - Scoring (parity with script/golden_eval.py)

    public static func normalizeWord(_ word: some StringProtocol) -> String {
        let strip = CharacterSet(charactersIn: ".,!?;:\"'()[]{}")
        return word.lowercased().trimmingCharacters(in: strip)
    }

    private static func words(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    public static func exactMatchAtOne(suggestion: String, golden: String) -> Bool {
        guard let suggestedFirst = words(suggestion).first,
              let goldenFirst = words(golden).first else { return false }
        return normalizeWord(suggestedFirst) == normalizeWord(goldenFirst)
    }

    /// Characters of `golden` that a leading run of matching words in
    /// `suggestion` would have saved the user from typing, including the
    /// separating spaces between matched words.
    public static func keystrokesSaved(suggestion: String, golden: String) -> Int {
        var matched: [String] = []
        for (suggested, expected) in zip(words(suggestion), words(golden)) {
            guard normalizeWord(suggested) == normalizeWord(expected) else { break }
            matched.append(suggested)
        }
        return matched.reduce(0) { $0 + $1.count } + max(0, matched.count - 1)
    }

    // MARK: - Tokenization (mirrors PersonalNextWordShadow's letter/mark rules)

    static func isLetter(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter:
            true
        default: false
        }
    }

    static func isMark(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark: true
        default: false
        }
    }
}
