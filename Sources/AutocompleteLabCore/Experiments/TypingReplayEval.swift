import Foundation

public struct TypingReplayCase: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let contextBefore: String
    public let contextAfter: String
    public let actualContinuation: String
    public let appBundleIdentifier: String
    public let fieldKind: String
    public let dayString: String

    public init(
        id: String,
        contextBefore: String,
        contextAfter: String = "",
        actualContinuation: String,
        appBundleIdentifier: String,
        fieldKind: String,
        dayString: String
    ) {
        self.id = id
        self.contextBefore = contextBefore
        self.contextAfter = contextAfter
        self.actualContinuation = actualContinuation
        self.appBundleIdentifier = appBundleIdentifier
        self.fieldKind = fieldKind
        self.dayString = dayString
    }

    private enum CodingKeys: String, CodingKey {
        case id, contextBefore, contextAfter, actualContinuation
        case appBundleIdentifier, fieldKind, dayString
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        contextBefore = try values.decode(String.self, forKey: .contextBefore)
        contextAfter = try values.decodeIfPresent(String.self, forKey: .contextAfter) ?? ""
        actualContinuation = try values.decode(String.self, forKey: .actualContinuation)
        appBundleIdentifier = try values.decode(String.self, forKey: .appBundleIdentifier)
        fieldKind = try values.decode(String.self, forKey: .fieldKind)
        dayString = try values.decode(String.self, forKey: .dayString)
    }
}

public struct TypingReplayCaseExtractor: Equatable, Sendable {
    public init() {}

    /// Builds replay cases without looking at any text written after a case's day.
    /// Entries are expected in journal order; the parser/indexer owns chronological ordering.
    public func cases(
        from entries: [PersonalCaptureJournalEntry],
        seed: UInt64 = 0,
        maxCases: Int = 150
    ) -> [TypingReplayCase] {
        guard maxCases > 0 else { return [] }

        struct StreamKey: Hashable {
            let appBundleIdentifier: String
            let fieldKind: String
        }
        struct Stream {
            let key: StreamKey
            var dayString: String
            var words: [String]
        }

        var streams: [Stream] = []
        for entry in entries where entry.kind == .typed {
            let words = Self.words(in: entry.text)
            guard !words.isEmpty else { continue }
            let key = StreamKey(
                appBundleIdentifier: entry.appBundleIdentifier,
                fieldKind: entry.fieldKind.rawValue
            )
            if let index = streams.indices.last,
               streams[index].key == key,
               streams[index].dayString == entry.dayString {
                streams[index].words.append(contentsOf: words)
            } else {
                streams.append(Stream(key: key, dayString: entry.dayString, words: words))
            }
        }

        var candidates: [TypingReplayCase] = []
        for (streamIndex, stream) in streams.enumerated() where stream.words.count >= 7 {
            let lastSplit = stream.words.count - 1
            for split in 6...lastSplit {
                let continuationEnd = min(stream.words.count, split + 12)
                let context = stream.words[..<split].joined(separator: " ")
                let continuation = stream.words[split..<continuationEnd].joined(separator: " ")
                let id = "\(stream.dayString)-\(streamIndex)-\(split)"
                candidates.append(TypingReplayCase(
                    id: id,
                    contextBefore: context,
                    actualContinuation: continuation,
                    appBundleIdentifier: stream.key.appBundleIdentifier,
                    fieldKind: stream.key.fieldKind,
                    dayString: stream.dayString
                ))
            }
        }

        guard candidates.count > maxCases else { return candidates }
        let offset = Int(seed % UInt64(candidates.count))
        let stride = Self.coprimeStride(count: candidates.count, seed: seed)
        var sampled: [TypingReplayCase] = []
        sampled.reserveCapacity(maxCases)
        var index = offset
        for _ in 0..<maxCases {
            sampled.append(candidates[index])
            index = (index + stride) % candidates.count
        }
        return sampled
    }

    private static func words(in text: String) -> [String] {
        text.split(whereSeparator: \Character.isWhitespace).map(String.init)
    }

    private static func coprimeStride(count: Int, seed: UInt64) -> Int {
        guard count > 1 else { return 1 }
        var value = Int((seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407) % UInt64(count))
        value = max(1, value)
        while greatestCommonDivisor(value, count) != 1 {
            value += 1
            if value >= count { value = 1 }
        }
        return value
    }

    private static func greatestCommonDivisor(_ lhs: Int, _ rhs: Int) -> Int {
        var a = lhs
        var b = rhs
        while b != 0 {
            (a, b) = (b, a % b)
        }
        return a
    }
}

public struct TypingReplayCaseScore: Codable, Equatable, Sendable {
    public let caseID: String
    public let keystrokesSaved: Int
    public let shownKeystrokesSaved: Int
    public let exactWordPrefixes: [Bool]
    public let madeSuggestion: Bool
    public let wrongFirstWord: Bool
    public let missedMagic: Bool

    public init(
        caseID: String,
        keystrokesSaved: Int,
        shownKeystrokesSaved: Int,
        exactWordPrefixes: [Bool],
        madeSuggestion: Bool,
        wrongFirstWord: Bool,
        missedMagic: Bool
    ) {
        self.caseID = caseID
        self.keystrokesSaved = keystrokesSaved
        self.shownKeystrokesSaved = shownKeystrokesSaved
        self.exactWordPrefixes = exactWordPrefixes
        self.madeSuggestion = madeSuggestion
        self.wrongFirstWord = wrongFirstWord
        self.missedMagic = missedMagic
    }

    public func exactWordPrefix(n: Int) -> Bool {
        guard (1...exactWordPrefixes.count).contains(n) else { return false }
        return exactWordPrefixes[n - 1]
    }
}

public struct TypingReplayScorer: Equatable, Sendable {
    public init() {}

    public func score(suggestionText: String?, for replayCase: TypingReplayCase) -> TypingReplayCaseScore {
        score(rawSuggestionText: suggestionText, gatedSuggestionText: suggestionText, for: replayCase)
    }

    public func score(
        rawSuggestionText: String?,
        gatedSuggestionText: String?,
        for replayCase: TypingReplayCase
    ) -> TypingReplayCaseScore {
        let raw = match(suggestionText: rawSuggestionText, actualContinuation: replayCase.actualContinuation)
        let gated = match(suggestionText: gatedSuggestionText, actualContinuation: replayCase.actualContinuation)
        return TypingReplayCaseScore(
            caseID: replayCase.id,
            keystrokesSaved: raw.keystrokesSaved,
            shownKeystrokesSaved: gated.keystrokesSaved,
            exactWordPrefixes: raw.exactWordPrefixes,
            madeSuggestion: raw.madeSuggestion,
            wrongFirstWord: raw.wrongFirstWord,
            missedMagic: raw.keystrokesSaved > 0 && gated.keystrokesSaved == 0
        )
    }

    private func match(
        suggestionText: String?,
        actualContinuation: String
    ) -> (keystrokesSaved: Int, exactWordPrefixes: [Bool], madeSuggestion: Bool, wrongFirstWord: Bool) {
        let suggestion = suggestionText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let actual = actualContinuation.trimmingCharacters(in: .whitespacesAndNewlines)
        let suggestedWords = suggestion.split(whereSeparator: \Character.isWhitespace).map(String.init)
        let actualWords = actual.split(whereSeparator: \Character.isWhitespace).map(String.init)
        let madeSuggestion = !suggestedWords.isEmpty

        var matchedWords = 0
        while matchedWords < min(suggestedWords.count, actualWords.count),
              suggestedWords[matchedWords] == actualWords[matchedWords] {
            matchedWords += 1
        }

        let saved: Int
        if matchedWords == 0 {
            saved = 0
        } else {
            saved = actualWords.prefix(matchedWords).joined(separator: " ").count
        }

        return (
            saved,
            (1...4).map { count in
                suggestedWords.count >= count
                    && actualWords.count >= count
                    && Array(suggestedWords.prefix(count)) == Array(actualWords.prefix(count))
            },
            madeSuggestion,
            madeSuggestion && (actualWords.first == nil || suggestedWords.first != actualWords.first)
        )
    }
}

public struct TypingReplayGateEvaluator: Equatable, Sendable {
    public let confidencePolicy: CompletionConfidencePolicy
    public let displayScorePolicy: DisplayScorePolicy

    public init(
        confidencePolicy: CompletionConfidencePolicy = CompletionConfidencePolicy(),
        displayScorePolicy: DisplayScorePolicy = DisplayScorePolicy()
    ) {
        self.confidencePolicy = confidencePolicy
        self.displayScorePolicy = displayScorePolicy
    }

    public func shouldDisplay(
        suggestionText: String,
        replayCase: TypingReplayCase,
        latencyMilliseconds: Int = 0
    ) -> Bool {
        let suggestion = CompletionSuggestion(
            text: suggestionText,
            maxVisibleWords: CompletionModelPolicy.mvp.maxVisibleWords
        )
        guard SuggestionPresentationGate().shouldPresent(
            suggestion,
            mode: .phraseContinuation,
            phase: .final
        ) else { return false }
        let confidence = confidencePolicy.decision(
            suggestion: suggestion,
            mode: .phraseContinuation,
            textBeforeCursor: replayCase.contextBefore,
            latencyMilliseconds: latencyMilliseconds,
            supportLevel: .green
        )
        guard confidence.canDisplay else { return false }
        let words = suggestion.visibleWordCount
        let utility = words >= 3 ? 0.74 : (words == 2 ? 0.52 : 0.38)
        let score = DisplayScore(
            utility: utility,
            styleFit: 0.65,
            contextFit: 0.70,
            userAffinity: 0.50,
            risk: 0.05,
            repetition: 0.05,
            instability: latencyMilliseconds > 750 ? 0.90 : 0.05
        )
        return displayScorePolicy.decision(
            for: score,
            mode: .phraseContinuation,
            behaviorProfileID: .docsProse
        ).shouldDisplay
    }
}

public struct TypingReplayScorecard: Codable, Equatable, Sendable {
    public let caseCount: Int
    public let totalKeystrokesSaved: Int
    public let keystrokesSavedPerCase: Double
    public let shownKeystrokesSavedPerCase: Double
    public let missedMagicRate: Double
    public let top1WordAccuracy: Double
    public let wordPrefixAccuracy2: Double
    public let wordPrefixAccuracy3: Double
    public let wordPrefixAccuracy4: Double
    public let suggestionRate: Double
    public let wrongFirstWordRate: Double

    public init(scores: [TypingReplayCaseScore]) {
        caseCount = scores.count
        totalKeystrokesSaved = scores.reduce(0) { $0 + $1.keystrokesSaved }
        keystrokesSavedPerCase = Self.rate(totalKeystrokesSaved, over: caseCount)
        shownKeystrokesSavedPerCase = Self.rate(scores.reduce(0) { $0 + $1.shownKeystrokesSaved }, over: caseCount)
        missedMagicRate = Self.rate(scores.filter(\.missedMagic).count, over: caseCount)
        top1WordAccuracy = Self.rate(scores.filter { $0.exactWordPrefix(n: 1) }.count, over: caseCount)
        wordPrefixAccuracy2 = Self.rate(scores.filter { $0.exactWordPrefix(n: 2) }.count, over: caseCount)
        wordPrefixAccuracy3 = Self.rate(scores.filter { $0.exactWordPrefix(n: 3) }.count, over: caseCount)
        wordPrefixAccuracy4 = Self.rate(scores.filter { $0.exactWordPrefix(n: 4) }.count, over: caseCount)
        let suggestions = scores.filter(\.madeSuggestion)
        suggestionRate = Self.rate(suggestions.count, over: caseCount)
        wrongFirstWordRate = Self.rate(suggestions.filter(\.wrongFirstWord).count, over: suggestions.count)
    }

    public var markdown: String {
        """
        # Typing Replay Scorecard

        - Cases: \(caseCount)
        - Keystrokes saved: \(totalKeystrokesSaved) (\(Self.decimal(keystrokesSavedPerCase))/case)
        - Shown keystrokes saved: \(Self.decimal(shownKeystrokesSavedPerCase))/case
        - Missed magic: \(Self.percent(missedMagicRate))
        - Top-1 word accuracy: \(Self.percent(top1WordAccuracy))
        - Exact 2/3/4-word prefix: \(Self.percent(wordPrefixAccuracy2)) / \(Self.percent(wordPrefixAccuracy3)) / \(Self.percent(wordPrefixAccuracy4))
        - Suggestion rate: \(Self.percent(suggestionRate))
        - Wrong first word among suggestions: \(Self.percent(wrongFirstWordRate))
        """
    }

    public func trendRow(
        dateISO: String,
        gitSHA: String,
        engine: String,
        model: String,
        promptFormat: String,
        variant: String,
        corpusKind: String,
        promptContextCharacters: Int? = nil,
        suffixEnabled: Bool? = nil,
        fewShotSource: String? = nil,
        decodingVariant: String? = nil,
        endToEndP95LatencyMs: Double? = nil
    ) -> TypingReplayTrendRow {
        TypingReplayTrendRow(
            dateISO: dateISO,
            gitSHA: gitSHA,
            engine: engine,
            model: model,
            promptFormat: promptFormat,
            variant: variant,
            corpusKind: corpusKind,
            promptContextCharacters: promptContextCharacters,
            suffixEnabled: suffixEnabled,
            fewShotSource: fewShotSource,
            decodingVariant: decodingVariant,
            caseCount: caseCount,
            keystrokesSavedPerCase: keystrokesSavedPerCase,
            shownKeystrokesSavedPerCase: shownKeystrokesSavedPerCase,
            missedMagicRate: missedMagicRate,
            top1WordAccuracy: top1WordAccuracy,
            wordPrefixAccuracy2: wordPrefixAccuracy2,
            wordPrefixAccuracy3: wordPrefixAccuracy3,
            wordPrefixAccuracy4: wordPrefixAccuracy4,
            suggestionRate: suggestionRate,
            wrongFirstWordRate: wrongFirstWordRate,
            endToEndP95LatencyMs: endToEndP95LatencyMs
        )
    }

    private static func rate(_ numerator: Int, over denominator: Int) -> Double {
        denominator == 0 ? 0 : Double(numerator) / Double(denominator)
    }

    private static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private static func decimal(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

/// Aggregate-only storage shape. It deliberately has no corpus, prompt, suggestion, or continuation text.
public struct TypingReplayTrendRow: Codable, Equatable, Sendable {
    public let dateISO: String
    public let gitSHA: String
    public let engine: String
    public let model: String
    public let promptFormat: String
    public let variant: String
    public let corpusKind: String
    public let promptContextCharacters: Int?
    public let suffixEnabled: Bool?
    public let fewShotSource: String?
    public let decodingVariant: String?
    public let caseCount: Int
    public let keystrokesSavedPerCase: Double
    public let shownKeystrokesSavedPerCase: Double
    public let missedMagicRate: Double
    public let top1WordAccuracy: Double
    public let wordPrefixAccuracy2: Double
    public let wordPrefixAccuracy3: Double
    public let wordPrefixAccuracy4: Double
    public let suggestionRate: Double
    public let wrongFirstWordRate: Double
    public let endToEndP95LatencyMs: Double?
    public let acceptedAndKeptRate: Double?
    public let acceptRate: Double?

    public init(
        dateISO: String,
        gitSHA: String,
        engine: String,
        model: String,
        promptFormat: String,
        variant: String,
        corpusKind: String,
        promptContextCharacters: Int? = nil,
        suffixEnabled: Bool? = nil,
        fewShotSource: String? = nil,
        decodingVariant: String? = nil,
        caseCount: Int,
        keystrokesSavedPerCase: Double,
        shownKeystrokesSavedPerCase: Double,
        missedMagicRate: Double,
        top1WordAccuracy: Double,
        wordPrefixAccuracy2: Double,
        wordPrefixAccuracy3: Double,
        wordPrefixAccuracy4: Double,
        suggestionRate: Double,
        wrongFirstWordRate: Double,
        endToEndP95LatencyMs: Double? = nil,
        acceptedAndKeptRate: Double? = nil,
        acceptRate: Double? = nil
    ) {
        self.dateISO = dateISO
        self.gitSHA = gitSHA
        self.engine = engine
        self.model = model
        self.promptFormat = promptFormat
        self.variant = variant
        self.corpusKind = corpusKind
        self.promptContextCharacters = promptContextCharacters
        self.suffixEnabled = suffixEnabled
        self.fewShotSource = fewShotSource
        self.decodingVariant = decodingVariant
        self.caseCount = caseCount
        self.keystrokesSavedPerCase = keystrokesSavedPerCase
        self.shownKeystrokesSavedPerCase = shownKeystrokesSavedPerCase
        self.missedMagicRate = missedMagicRate
        self.top1WordAccuracy = top1WordAccuracy
        self.wordPrefixAccuracy2 = wordPrefixAccuracy2
        self.wordPrefixAccuracy3 = wordPrefixAccuracy3
        self.wordPrefixAccuracy4 = wordPrefixAccuracy4
        self.suggestionRate = suggestionRate
        self.wrongFirstWordRate = wrongFirstWordRate
        self.endToEndP95LatencyMs = endToEndP95LatencyMs
        self.acceptedAndKeptRate = acceptedAndKeptRate
        self.acceptRate = acceptRate
    }

    public static func live(
        dateISO: String,
        gitSHA: String,
        model: String,
        corpusKind: String,
        scorecard: SuggestionEpisodeScorecard
    ) -> TypingReplayTrendRow {
        TypingReplayTrendRow(
            dateISO: dateISO,
            gitSHA: gitSHA,
            engine: "live",
            model: model,
            promptFormat: "live",
            variant: "live",
            corpusKind: corpusKind,
            caseCount: scorecard.total,
            keystrokesSavedPerCase: 0,
            shownKeystrokesSavedPerCase: 0,
            missedMagicRate: 0,
            top1WordAccuracy: 0,
            wordPrefixAccuracy2: 0,
            wordPrefixAccuracy3: 0,
            wordPrefixAccuracy4: 0,
            suggestionRate: scorecard.total == 0 ? 0 : Double(scorecard.shown) / Double(scorecard.total),
            wrongFirstWordRate: 0,
            acceptedAndKeptRate: scorecard.accepted == 0 ? 0 : Double(scorecard.kept) / Double(scorecard.accepted),
            acceptRate: scorecard.shown == 0 ? 0 : Double(scorecard.accepted) / Double(scorecard.shown)
        )
    }
}
