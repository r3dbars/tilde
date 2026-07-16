import Foundation

public struct PersonalSnippetSafetyFilter: Equatable, Sendable {
    public init() {}

    public func allows(_ text: String) -> Bool {
        let tokens = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !tokens.contains(where: { $0.contains("@") }),
              text.range(of: #"\d{6,}"#, options: .regularExpression) == nil else {
            return false
        }
        return !tokens.contains(where: isHighEntropyToken)
    }

    private func isHighEntropyToken(_ token: String) -> Bool {
        let stripped = token.trimmingCharacters(in: .punctuationCharacters)
        guard stripped.count >= 16 else { return false }
        let hasLetter = stripped.contains(where: \Character.isLetter)
        let hasNumber = stripped.contains(where: \Character.isNumber)
        let uniqueRatio = Double(Set(stripped.lowercased()).count) / Double(max(1, stripped.count))
        return (hasLetter && hasNumber && uniqueRatio >= 0.45) || uniqueRatio >= 0.70
    }
}

public struct PersonalWritingMemoryBuilder: Equatable, Sendable {
    public let maximumNGramKeys: Int
    public let maximumSnippets: Int
    public let halfLifeSeconds: TimeInterval
    public let safetyFilter: PersonalSnippetSafetyFilter

    public init(
        maximumNGramKeys: Int = 30_000,
        maximumSnippets: Int = 500,
        halfLifeSeconds: TimeInterval = 14 * 24 * 60 * 60,
        safetyFilter: PersonalSnippetSafetyFilter = PersonalSnippetSafetyFilter()
    ) {
        self.maximumNGramKeys = max(1, maximumNGramKeys)
        self.maximumSnippets = max(1, maximumSnippets)
        self.halfLifeSeconds = max(60, halfLifeSeconds)
        self.safetyFilter = safetyFilter
    }

    public func build(entries: [PersonalCaptureJournalEntry], now: Date = Date()) -> PersonalWritingMemory {
        let usable = entries.enumerated().filter {
            $0.element.kind != .fieldObserved
                && PersonalWritingMemory.normalizedWords(in: $0.element.text).count >= 3
                && safetyFilter.allows($0.element.text)
        }.sorted {
            if $0.element.dayString != $1.element.dayString { return $0.element.dayString < $1.element.dayString }
            if $0.element.timeString != $1.element.timeString { return $0.element.timeString < $1.element.timeString }
            return $0.offset < $1.offset
        }.map(\.element)
        var buckets: [String: [String: WeightedContinuation]] = [:]
        var snippets: [PersonalSnippet] = []
        var wordCount = 0
        var terminalCount = 0
        var lowercaseCount = 0

        for entry in usable {
            let words = PersonalWritingMemory.normalizedWords(in: entry.text)
            let displayWords = displayWords(in: entry.text)
            guard words.count == displayWords.count else { continue }
            let weight = decayWeight(dayString: entry.dayString, now: now)
            wordCount += words.count
            terminalCount += entry.text.trimmingCharacters(in: .whitespacesAndNewlines).last.map { ".!?".contains($0) } == true ? 1 : 0
            lowercaseCount += entry.text.trimmingCharacters(in: .whitespacesAndNewlines).first.map {
                String($0).rangeOfCharacter(from: .lowercaseLetters) != nil
            } == true ? 1 : 0

            if let snippetText = sentenceBoundedSnippet(from: entry.text), safetyFilter.allows(snippetText) {
                snippets.append(PersonalSnippet(
                    text: snippetText,
                    tokens: Set(PersonalWritingMemory.normalizedWords(in: snippetText)),
                    appBundleIdentifier: entry.appBundleIdentifier,
                    dayString: entry.dayString
                ))
            }

            for order in 2...4 where words.count > order {
                for start in 0..<(words.count - order) {
                    let key = words[start..<(start + order)].joined(separator: " ")
                    let end = min(displayWords.count, start + order + 8)
                    let continuation = displayWords[(start + order)..<end].joined(separator: " ")
                    guard safetyFilter.allows(continuation) else { continue }
                    var existing = buckets[key]?[continuation] ?? WeightedContinuation()
                    existing.weight += weight
                    existing.lastSeenDay = max(existing.lastSeenDay, entry.dayString)
                    buckets[key, default: [:]][continuation] = existing
                }
            }
        }

        let trimmedKeys = buckets.map { key, values -> (String, [PersonalNGramContinuation], Double) in
            let continuations = values.map { display, value in
                PersonalNGramContinuation(display: display, weight: value.weight, lastSeenDay: value.lastSeenDay)
            }.sorted {
                if abs($0.weight - $1.weight) > 0.000_001 { return $0.weight > $1.weight }
                if $0.lastSeenDay != $1.lastSeenDay { return $0.lastSeenDay > $1.lastSeenDay }
                return $0.display < $1.display
            }.prefix(3)
            return (key, Array(continuations), continuations.first?.weight ?? 0)
        }.sorted {
            if abs($0.2 - $1.2) > 0.000_001 { return $0.2 > $1.2 }
            return $0.0 < $1.0
        }.prefix(maximumNGramKeys)

        let boundedSnippets = Array(snippets.suffix(maximumSnippets))
        var documentFrequency: [String: Int] = [:]
        for snippet in boundedSnippets {
            for token in snippet.tokens { documentFrequency[token, default: 0] += 1 }
        }
        let sampleCount = usable.count
        let profile = PersonalWritingProfile(
            sampleCount: sampleCount,
            averageWordsPerEntry: sampleCount == 0 ? 0 : Double(wordCount) / Double(sampleCount),
            terminalPunctuationRate: sampleCount == 0 ? 0 : Double(terminalCount) / Double(sampleCount),
            lowercaseStartRate: sampleCount == 0 ? 0 : Double(lowercaseCount) / Double(sampleCount),
            promptGuidance: profileGuidance(sampleCount: sampleCount, wordCount: wordCount, terminalCount: terminalCount, lowercaseCount: lowercaseCount)
        )
        return PersonalWritingMemory(
            ngramContinuations: Dictionary(uniqueKeysWithValues: trimmedKeys.map { ($0.0, $0.1) }),
            snippets: boundedSnippets,
            profile: profile,
            tokenDocumentFrequency: documentFrequency,
            builtAtDay: Self.dayString(from: now)
        )
    }

    private func decayWeight(dayString: String, now: Date) -> Double {
        guard let date = Self.date(fromDayString: dayString) else { return 1 }
        return pow(0.5, max(0, now.timeIntervalSince(date)) / halfLifeSeconds)
    }

    private func sentenceBoundedSnippet(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let bounded = String(trimmed.prefix(200))
        if trimmed.count <= 200 { return bounded }
        if let boundary = bounded.lastIndex(where: { ".!?\n".contains($0) }) {
            let sentence = String(bounded[...boundary]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { return sentence }
        }
        if let space = bounded.lastIndex(where: \Character.isWhitespace) {
            return String(bounded[..<space])
        }
        return bounded
    }

    private func displayWords(in text: String) -> [String] {
        text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    private func profileGuidance(sampleCount: Int, wordCount: Int, terminalCount: Int, lowercaseCount: Int) -> String? {
        guard sampleCount > 0 else { return nil }
        let average = Double(wordCount) / Double(sampleCount)
        let punctuation = Double(terminalCount) / Double(sampleCount) >= 0.5 ? "usually ends entries with punctuation" : "often leaves short continuations unpunctuated"
        let casing = Double(lowercaseCount) / Double(sampleCount) >= 0.5 ? "often starts continuations lowercase" : "usually starts entries with capitals"
        return String("Personal writing profile: averages \(String(format: "%.1f", average)) words per captured entry; \(punctuation); \(casing). Match phrasing lightly without copying unrelated content.".prefix(300))
    }

    private static func date(fromDayString string: String) -> Date? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    private static func dayString(from date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

private struct WeightedContinuation {
    var weight: Double = 0
    var lastSeenDay = ""
}
