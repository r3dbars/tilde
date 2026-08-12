import Foundation

/// Aggregate-only result of the local personal-vocabulary experiment.
/// No words, prefixes, applications, sessions, or event identifiers escape
/// the in-memory learner through this value.
public struct PersonalVocabularyShadowSnapshot: Equatable, Sendable {
    public let opportunities: Int
    public let predictions: Int
    public let exactHits: Int
    public let learnedWords: Int

    public var coverage: Double {
        opportunities == 0 ? 0 : Double(predictions) / Double(opportunities)
    }

    public var precision: Double {
        predictions == 0 ? 0 : Double(exactHits) / Double(predictions)
    }

}

/// A bounded, deterministic, shadow-only personal word completer.
///
/// At three and then four typed letters it may freeze one candidate learned
/// only from earlier completed words. The candidate is scored when the word
/// closes and the actual word is learned afterward, preventing replay from
/// seeing its answer before predicting it.
public struct PersonalVocabularyShadow: Sendable {
    static let maximumLearnedWords = 4_096
    static let maximumActiveStreams = 64
    static let maximumRecentEventIDs = 2_048
    private static let maximumWordCharacters = 30
    private static let maximumSurfaceFormsPerWord = 4
    private static let streamGapMilliseconds: Int64 = 30 * 60 * 1_000

    private struct StreamKey: Hashable, Sendable {
        let history: String
        let consent: String
        let session: String
        let app: String
    }

    private struct StreamState: Sendable {
        var word = ""
        var invalid = false
        var censored = true
        var reachedCheckpoint = false
        var prediction: String?
        var lastTimestampMilliseconds: Int64?
    }

    private struct WordRecord: Sendable {
        var forms: [String: Int]
        var prefixes: Set<String>

        var dominantForm: String {
            forms.max {
                $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value
            }!.key
        }
    }

    private var words: [String: WordRecord] = [:]
    private var wordOrder: [String] = []
    private var nextWordEvictionIndex = 0
    private var prefixCounts: [String: [String: Int]] = [:]
    private var streams: [StreamKey: StreamState] = [:]
    private var recentEventIDs: [String] = []
    private var recentEventIDSet: Set<String> = []
    private var nextEventEvictionIndex = 0
    private var opportunities = 0
    private var predictions = 0
    private var exactHits = 0

    public init() {}

    public var snapshot: PersonalVocabularyShadowSnapshot {
        PersonalVocabularyShadowSnapshot(
            opportunities: opportunities,
            predictions: predictions,
            exactHits: exactHits,
            learnedWords: words.count
        )
    }

    public mutating func consume(_ events: [PersonalHistoryEvent]) {
        for event in events where remember(event) {
            let key = StreamKey(
                history: event.historyIdentifier,
                consent: event.consentIdentifier,
                session: event.sessionIdentifier,
                app: event.appBundleIdentifier
            )
            if streams[key] == nil {
                if streams.count >= Self.maximumActiveStreams { streams.removeAll() }
            }
            var state = streams.removeValue(forKey: key) ?? StreamState()
            if let last = state.lastTimestampMilliseconds,
               event.timestampMilliseconds < last
                || event.timestampMilliseconds - last > Self.streamGapMilliseconds {
                state = StreamState()
            }
            state.lastTimestampMilliseconds = event.timestampMilliseconds

            for character in event.text {
                consume(character, authoredByUser: event.source == .typed, state: &state)
            }
            streams[key] = state
        }
    }

    public mutating func reset() {
        self = Self()
    }

    private mutating func consume(
        _ character: Character,
        authoredByUser: Bool,
        state: inout StreamState
    ) {
        if character.isLetter {
            if authoredByUser {
                append(character, to: &state)
            } else {
                state.censored = true
                state.prediction = nil
            }
        } else if character.isNumber || Self.isApostrophe(character) {
            state.invalid = true
            if !authoredByUser {
                state.censored = true
                state.prediction = nil
            }
        } else {
            finishWord(&state)
        }
    }

    private mutating func append(_ character: Character, to state: inout StreamState) {
        guard !state.invalid, !state.censored else { return }
        state.word.append(character)
        guard state.word.count <= Self.maximumWordCharacters else {
            state.invalid = true
            return
        }
        if state.word.count == 3 { state.reachedCheckpoint = true }
        guard state.prediction == nil, state.word.count == 3 || state.word.count == 4 else {
            return
        }
        if let candidate = candidate(for: state.word) {
            state.prediction = candidate
        }
    }

    private mutating func finishWord(_ state: inout StreamState) {
        defer {
            state = StreamState(
                censored: false,
                lastTimestampMilliseconds: state.lastTimestampMilliseconds
            )
        }
        guard !state.censored, state.reachedCheckpoint else { return }
        opportunities += 1
        let rawWord = state.word
        let identity = Self.normalized(rawWord)
        let surface = Self.surface(rawWord)
        let learnable = !state.invalid
            && (5...Self.maximumWordCharacters).contains(rawWord.count)
            && rawWord.allSatisfy(\.isLetter)
        if let prediction = state.prediction {
            predictions += 1
            if learnable, prediction == surface { exactHits += 1 }
        }
        guard learnable else { return }
        learn(rawWord: rawWord, surface: surface, identity: identity)
    }

    private func candidate(for rawPrefix: String) -> String? {
        let prefix = Self.normalized(rawPrefix)
        guard let options = prefixCounts[prefix], !options.isEmpty else { return nil }
        var topIdentity = ""
        var topCount = 0
        var secondCount = 0
        var total = 0
        for (identity, count) in options {
            total += count
            if count > topCount {
                secondCount = topCount
                topIdentity = identity
                topCount = count
            } else if count > secondCount {
                secondCount = count
            }
        }
        guard topCount >= 2, topCount > secondCount,
              let topWord = words[topIdentity]?.dominantForm,
              Self.normalized(String(topWord.prefix(rawPrefix.count))) == prefix,
              topWord.count > rawPrefix.count else {
            return nil
        }
        guard Double(topCount) / Double(max(1, total)) >= 0.5 else { return nil }
        return Self.surface(rawPrefix) + String(topWord.dropFirst(rawPrefix.count))
    }

    private mutating func learn(rawWord: String, surface: String, identity: String) {
        if words[identity] == nil, words.count >= Self.maximumLearnedWords {
            let stale = wordOrder[nextWordEvictionIndex]
            removeLearnedWord(stale)
            wordOrder[nextWordEvictionIndex] = identity
            nextWordEvictionIndex = (nextWordEvictionIndex + 1) % Self.maximumLearnedWords
        } else if words[identity] == nil {
            wordOrder.append(identity)
        }
        var record = words[identity] ?? WordRecord(forms: [:], prefixes: [])
        if record.forms[surface] != nil || record.forms.count < Self.maximumSurfaceFormsPerWord {
            record.forms[surface, default: 0] += 1
        }
        for length in [3, 4] {
            let prefix = Self.normalized(String(rawWord.prefix(length)))
            record.prefixes.insert(prefix)
            prefixCounts[prefix, default: [:]][identity, default: 0] += 1
        }
        words[identity] = record
    }

    private mutating func removeLearnedWord(_ identity: String) {
        guard let record = words.removeValue(forKey: identity) else { return }
        for prefix in record.prefixes {
            prefixCounts[prefix]?.removeValue(forKey: identity)
            if prefixCounts[prefix]?.isEmpty == true { prefixCounts.removeValue(forKey: prefix) }
        }
    }

    private mutating func remember(_ event: PersonalHistoryEvent) -> Bool {
        let identity = event.historyIdentifier + "\u{0}" + event.id
        guard recentEventIDSet.insert(identity).inserted else { return false }
        if recentEventIDs.count < Self.maximumRecentEventIDs {
            recentEventIDs.append(identity)
        } else {
            recentEventIDSet.remove(recentEventIDs[nextEventEvictionIndex])
            recentEventIDs[nextEventEvictionIndex] = identity
            nextEventEvictionIndex = (nextEventEvictionIndex + 1)
                % Self.maximumRecentEventIDs
        }
        return true
    }

    private static func normalized(_ word: String) -> String {
        surface(word).folding(
            options: [.caseInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        ).precomposedStringWithCanonicalMapping
    }

    private static func surface(_ word: String) -> String {
        word.precomposedStringWithCanonicalMapping
    }

    private static func isApostrophe(_ character: Character) -> Bool {
        character == "'" || character == "’"
    }

}
