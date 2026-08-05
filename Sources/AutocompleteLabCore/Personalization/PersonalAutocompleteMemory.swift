import Foundation

public struct PersonalWordCandidate: Codable, Equatable, Sendable {
    public let word: String
    public let support: Int
    public let totalPrefixSupport: Int

    public init(word: String, support: Int, totalPrefixSupport: Int) {
        self.word = word
        self.support = support
        self.totalPrefixSupport = totalPrefixSupport
    }
}

public struct PersonalWritingExample: Codable, Equatable, Hashable, Sendable {
    public let text: String
    public let continuation: String

    public init(text: String, continuation: String) {
        self.text = text
        self.continuation = continuation
    }
}

public struct PersonalPhraseBucket: Codable, Equatable, Sendable {
    public let support: Int
    public let dominantSupport: Int
    public let examples: [PersonalWritingExample]

    public init(support: Int, dominantSupport: Int, examples: [PersonalWritingExample]) {
        self.support = support
        self.dominantSupport = dominantSupport
        self.examples = examples
    }
}

/// A compact local snapshot consumed by both the menu-bar app and keyboard.
/// Creation is owner-opt-in because its values derive from personal writing.
public struct PersonalAutocompleteMemory: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public static let empty = PersonalAutocompleteMemory()

    public let version: Int
    public let wordPrefixes: [String: PersonalWordCandidate]
    public let phraseBuckets: [String: PersonalPhraseBucket]
    public let sourceObservations: Int

    public init(
        version: Int = currentVersion,
        wordPrefixes: [String: PersonalWordCandidate] = [:],
        phraseBuckets: [String: PersonalPhraseBucket] = [:],
        sourceObservations: Int = 0
    ) {
        self.version = version
        self.wordPrefixes = wordPrefixes
        self.phraseBuckets = phraseBuckets
        self.sourceObservations = sourceObservations
    }

    /// Returns the full learned word. The caller trims the typed prefix.
    public func wordCompletion(for prefix: String) -> String? {
        let normalized = Self.normalizedFragment(prefix)
        guard normalized.count >= 3 else { return nil }
        let key = String(normalized.prefix(min(4, normalized.count)))
        guard let candidate = wordPrefixes[key],
              candidate.word.lowercased().hasPrefix(normalized),
              candidate.word.count > prefix.count else {
            return nil
        }
        return candidate.word
    }

    /// Conservative retrieval: exact final two-word key and at most two
    /// already-qualified examples.
    public func examples(after text: String, limit: Int = 2) -> [PersonalWritingExample] {
        guard let key = Self.phraseKey(in: text) else { return [] }
        return Array((phraseBuckets[key]?.examples ?? []).prefix(max(0, limit)))
    }

    /// Higher-support history wins per key, so a small recent sample cannot
    /// displace a strong historical candidate.
    public func merging(_ newer: PersonalAutocompleteMemory) -> PersonalAutocompleteMemory {
        var words = wordPrefixes
        for (key, candidate) in newer.wordPrefixes {
            if let existing = words[key], existing.support > candidate.support { continue }
            words[key] = candidate
        }

        var phrases = phraseBuckets
        for (key, bucket) in newer.phraseBuckets {
            if let existing = phrases[key], existing.support > bucket.support { continue }
            phrases[key] = bucket
        }

        return PersonalAutocompleteMemory(
            wordPrefixes: words,
            phraseBuckets: phrases,
            sourceObservations: sourceObservations + newer.sourceObservations
        )
    }

    fileprivate static func wordPairs(in text: String) -> [(form: String, normalized: String)] {
        var pairs: [(String, String)] = []
        var token = ""

        func finishToken() {
            let form = token.trimmingCharacters(in: CharacterSet(charactersIn: "'’"))
            token = ""
            guard (5...30).contains(form.count), form.allSatisfy(\.isLetter) else { return }
            pairs.append((form, form.lowercased()))
        }

        for character in text {
            if character.isLetter || character == "'" || character == "’" {
                token.append(character)
            } else {
                finishToken()
            }
        }
        finishToken()
        return pairs
    }

    fileprivate static func phraseKey(in text: String) -> String? {
        let words = wordsForPhrases(in: text)
        guard words.count >= 2 else { return nil }
        return words.suffix(2).joined(separator: " ")
    }

    fileprivate static func wordsForPhrases(in text: String) -> [String] {
        var words: [String] = []
        var token = ""

        func finishToken() {
            let value = token.trimmingCharacters(in: CharacterSet(charactersIn: "'’"))
            token = ""
            guard !value.isEmpty, value.contains(where: \.isLetter) else { return }
            words.append(value.lowercased())
        }

        for character in text {
            if character.isLetter || character.isNumber || character == "'" || character == "’" {
                token.append(character)
            } else {
                finishToken()
            }
        }
        finishToken()
        return words
    }

    private static func normalizedFragment(_ value: String) -> String {
        String(value.filter(\.isLetter)).lowercased()
    }
}

/// Mutable construction stays outside the runtime lookup path. Defaults match
/// the paired holdout: word support 2 / dominance 0.50 and phrase support 3 /
/// dominance 0.50 with at most two examples.
public struct PersonalAutocompleteMemoryBuilder {
    private struct PhraseAccumulator {
        var support = 0
        var nextCounts: [String: Int] = [:]
        var examples: [(nextWord: String, example: PersonalWritingExample)] = []
    }

    private var wordCounts: [String: Int] = [:]
    private var wordForms: [String: [String: Int]] = [:]
    private var phrases: [String: PhraseAccumulator] = [:]
    private var seenOutcomes: Set<String> = []
    private var observations = 0

    public init() {}

    public mutating func observeVocabulary(_ text: String) {
        let pairs = PersonalAutocompleteMemory.wordPairs(in: text)
        guard !pairs.isEmpty else { return }
        observations += 1
        for pair in pairs {
            wordCounts[pair.normalized, default: 0] += 1
            wordForms[pair.normalized, default: [:]][pair.form, default: 0] += 1
        }
    }

    public mutating func observeOutcome(context: String, continuation: String) {
        let normalizedContext = Self.singleLine(context, limit: 220)
        let normalizedContinuation = Self.singleLine(continuation, limit: 140)
        guard !normalizedContext.isEmpty, !normalizedContinuation.isEmpty else { return }
        let identity = normalizedContext + "\u{0}" + normalizedContinuation
        guard seenOutcomes.insert(identity).inserted,
              let key = PersonalAutocompleteMemory.phraseKey(in: normalizedContext),
              let nextWord = PersonalAutocompleteMemory.wordsForPhrases(
                in: normalizedContinuation
              ).first else {
            return
        }

        observations += 1
        var bucket = phrases[key] ?? PhraseAccumulator()
        bucket.support += 1
        bucket.nextCounts[nextWord, default: 0] += 1
        bucket.examples.append((
            nextWord,
            PersonalWritingExample(
                text: Self.lastWords(normalizedContext, limit: 12),
                continuation: Self.firstWords(normalizedContinuation, limit: 8)
            )
        ))
        if bucket.examples.count > 20 {
            bucket.examples.removeFirst(bucket.examples.count - 20)
        }
        phrases[key] = bucket
        observeVocabulary(normalizedContinuation)
    }

    public func snapshot(
        wordMinimumSupport: Int = 2,
        phraseMinimumSupport: Int = 3,
        dominance: Double = 0.50,
        phraseExampleLimit: Int = 2
    ) -> PersonalAutocompleteMemory {
        var byPrefix: [String: [(word: String, count: Int)]] = [:]
        for (word, count) in wordCounts {
            for length in [3, 4] where word.count > length {
                byPrefix[String(word.prefix(length)), default: []].append((word, count))
            }
        }

        var qualifiedWords: [String: PersonalWordCandidate] = [:]
        for (prefix, options) in byPrefix {
            let ordered = options.sorted {
                $0.count == $1.count ? $0.word < $1.word : $0.count > $1.count
            }
            guard let top = ordered.first else { continue }
            let total = ordered.reduce(0) { $0 + $1.count }
            guard top.count >= wordMinimumSupport,
                  Double(top.count) / Double(max(1, total)) >= dominance else {
                continue
            }
            let form = wordForms[top.word]?
                .max { lhs, rhs in lhs.value == rhs.value ? lhs.key > rhs.key : lhs.value < rhs.value }?
                .key ?? top.word
            qualifiedWords[prefix] = PersonalWordCandidate(
                word: form,
                support: top.count,
                totalPrefixSupport: total
            )
        }

        var qualifiedPhrases: [String: PersonalPhraseBucket] = [:]
        for (key, bucket) in phrases {
            guard bucket.support >= phraseMinimumSupport,
                  let dominant = bucket.nextCounts.max(by: {
                    $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value
                  }),
                  Double(dominant.value) / Double(bucket.support) >= dominance else {
                continue
            }
            var unique: [PersonalWritingExample] = []
            var seen: Set<PersonalWritingExample> = []
            for row in bucket.examples.reversed() where row.nextWord == dominant.key {
                if seen.insert(row.example).inserted { unique.append(row.example) }
                if unique.count >= phraseExampleLimit { break }
            }
            guard !unique.isEmpty else { continue }
            qualifiedPhrases[key] = PersonalPhraseBucket(
                support: bucket.support,
                dominantSupport: dominant.value,
                examples: unique
            )
        }

        return PersonalAutocompleteMemory(
            wordPrefixes: qualifiedWords,
            phraseBuckets: qualifiedPhrases,
            sourceObservations: observations
        )
    }

    private static func singleLine(_ value: String, limit: Int) -> String {
        String(value.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(limit))
    }

    private static func firstWords(_ value: String, limit: Int) -> String {
        value.split(whereSeparator: \.isWhitespace).prefix(limit).joined(separator: " ")
    }

    private static func lastWords(_ value: String, limit: Int) -> String {
        value.split(whereSeparator: \.isWhitespace).suffix(limit).joined(separator: " ")
    }
}
