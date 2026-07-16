import Foundation

public struct PersonalNGramContinuation: Codable, Equatable, Sendable {
    public let display: String
    public let weight: Double
    public let lastSeenDay: String

    public init(display: String, weight: Double, lastSeenDay: String) {
        self.display = display
        self.weight = max(0, weight)
        self.lastSeenDay = lastSeenDay
    }
}

public struct PersonalSnippet: Codable, Equatable, Sendable {
    public let text: String
    public let tokens: Set<String>
    public let appBundleIdentifier: String
    public let dayString: String

    public init(text: String, tokens: Set<String>, appBundleIdentifier: String, dayString: String) {
        self.text = String(text.prefix(200))
        self.tokens = tokens
        self.appBundleIdentifier = appBundleIdentifier
        self.dayString = dayString
    }
}

public struct PersonalWritingProfile: Codable, Equatable, Sendable {
    public let sampleCount: Int
    public let averageWordsPerEntry: Double
    public let terminalPunctuationRate: Double
    public let lowercaseStartRate: Double
    public let promptGuidance: String?

    public init(
        sampleCount: Int = 0,
        averageWordsPerEntry: Double = 0,
        terminalPunctuationRate: Double = 0,
        lowercaseStartRate: Double = 0,
        promptGuidance: String? = nil
    ) {
        self.sampleCount = max(0, sampleCount)
        self.averageWordsPerEntry = max(0, averageWordsPerEntry)
        self.terminalPunctuationRate = min(max(terminalPunctuationRate, 0), 1)
        self.lowercaseStartRate = min(max(lowercaseStartRate, 0), 1)
        self.promptGuidance = promptGuidance.map { String($0.prefix(300)) }
    }
}

public struct PersonalContextQuery: Equatable, Sendable {
    public let textBeforeCursor: String
    public let appBundleIdentifier: String?
    public let maximumSnippets: Int

    public init(textBeforeCursor: String, appBundleIdentifier: String? = nil, maximumSnippets: Int = 3) {
        self.textBeforeCursor = textBeforeCursor
        self.appBundleIdentifier = appBundleIdentifier
        self.maximumSnippets = min(max(maximumSnippets, 0), 3)
    }
}

public struct PersonalContext: Equatable, Sendable {
    public let snippets: [String]
    public let profileGuidance: String?
    public let traceMetadata: [String: String]

    public init(snippets: [String], profileGuidance: String? = nil) {
        var remaining = 400
        let safeSnippets = snippets.prefix(3).compactMap { snippet -> String? in
            guard remaining > 0 else { return nil }
            let bounded = String(Self.promptSafeLine(snippet).prefix(min(200, remaining)))
            remaining -= bounded.count
            return bounded.isEmpty ? nil : bounded
        }
        // Keep the whole prompt addition near the latency budget even when all
        // three snippets are full. The persisted profile remains capped at 300;
        // its prompt projection yields space to the more relevant snippets.
        let snippetCharacters = safeSnippets.reduce(0) { $0 + $1.count }
        let guidanceAllowance = max(0, min(300, 700 - snippetCharacters - 190))
        let safeGuidance = profileGuidance.flatMap { guidance -> String? in
            guard guidanceAllowance > 0 else { return nil }
            let bounded = String(Self.promptSafeLine(guidance).prefix(guidanceAllowance))
            return bounded.isEmpty ? nil : bounded
        }
        self.snippets = safeSnippets
        self.profileGuidance = safeGuidance
        self.traceMetadata = [
            "personalContextSnippetCount": String(safeSnippets.count),
            "personalContextCharacters": String(safeSnippets.reduce(0) { $0 + $1.count }),
            "personalContextProfilePresent": String(safeGuidance != nil)
        ]
    }

    private static func promptSafeLine(_ text: String) -> String {
        text.unicodeScalars
            .map { scalar in
                CharacterSet.controlCharacters.contains(scalar) || CharacterSet.newlines.contains(scalar)
                    ? " "
                    : String(scalar)
            }
            .joined()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}

public struct PersonalWritingMemory: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let ngramContinuations: [String: [PersonalNGramContinuation]]
    public let snippets: [PersonalSnippet]
    public let profile: PersonalWritingProfile
    public let tokenDocumentFrequency: [String: Int]
    public let builtAtDay: String
    public let schemaVersion: Int

    public init(
        ngramContinuations: [String: [PersonalNGramContinuation]] = [:],
        snippets: [PersonalSnippet] = [],
        profile: PersonalWritingProfile = PersonalWritingProfile(),
        tokenDocumentFrequency: [String: Int] = [:],
        builtAtDay: String,
        schemaVersion: Int = PersonalWritingMemory.currentSchemaVersion
    ) {
        self.ngramContinuations = ngramContinuations
        self.snippets = Array(snippets.prefix(500))
        self.profile = profile
        self.tokenDocumentFrequency = tokenDocumentFrequency
        self.builtAtDay = builtAtDay
        self.schemaVersion = schemaVersion
    }

    public func personalContext(for query: PersonalContextQuery) -> PersonalContext? {
        let queryTokens = Array(Self.normalizedWords(in: query.textBeforeCursor).suffix(30))
        let querySet = Set(queryTokens)
        let ranked = snippets.enumerated().compactMap { index, snippet -> (PersonalSnippet, Double, Int)? in
            let overlap = snippet.tokens.intersection(querySet)
            guard !overlap.isEmpty else { return nil }
            let overlapScore = overlap.reduce(0.0) { score, token in
                let frequency = max(1, tokenDocumentFrequency[token] ?? 1)
                return score + 1.0 / log2(Double(frequency) + 1.5)
            }
            let sameAppBonus = query.appBundleIdentifier == snippet.appBundleIdentifier ? 0.75 : 0
            return (snippet, overlapScore + sameAppBonus, index)
        }.sorted {
            if abs($0.1 - $1.1) > 0.000_001 { return $0.1 > $1.1 }
            if $0.0.dayString != $1.0.dayString { return $0.0.dayString > $1.0.dayString }
            return $0.2 < $1.2
        }

        var selected: [String] = []
        var characters = 0
        for item in ranked.prefix(query.maximumSnippets) {
            let separatorCount = selected.isEmpty ? 0 : 1
            let allowance = 400 - characters - separatorCount
            guard allowance > 0 else { break }
            let text = String(item.0.text.prefix(min(200, allowance)))
            guard !text.isEmpty else { continue }
            selected.append(text)
            characters += separatorCount + text.count
        }

        let guidance = profile.promptGuidance
        guard !selected.isEmpty || guidance != nil else { return nil }
        return PersonalContext(
            snippets: selected,
            profileGuidance: guidance
        )
    }

    public static func normalizedWords(in text: String) -> [String] {
        var words: [String] = []
        var current = ""
        func flush() {
            guard !current.isEmpty else { return }
            let latin = current.applyingTransform(.toLatin, reverse: false) ?? current
            let normalized = latin
                .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
                .lowercased()
            if !normalized.isEmpty { words.append(normalized) }
            current = ""
        }
        for character in text {
            if character.isLetter || character.isNumber { current.append(character) } else { flush() }
        }
        flush()
        return words
    }
}
