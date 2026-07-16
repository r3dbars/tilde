import Foundation
import AutocompleteLabCore

public struct AcceptedTextStyleMemoryKey: Codable, Equatable, Hashable, Sendable {
    public let appBundleIdentifier: String
    public let fieldKind: String
    public let behaviorProfile: String

    public init(
        appBundleIdentifier: String,
        fieldKind: AXFieldKind,
        behaviorProfileID: AutocompleteBehaviorProfileID
    ) {
        self.appBundleIdentifier = appBundleIdentifier.isEmpty ? "unknown" : appBundleIdentifier
        self.fieldKind = fieldKind.rawValue
        self.behaviorProfile = behaviorProfileID.rawValue
    }
}

public struct AcceptedTextStyleSketch: Codable, Equatable, Sendable {
    public let sampleCount: Int
    public let averageWordCount: Double
    public let terminalPunctuationRate: Double
    public let lowercaseStartRate: Double
    public let questionEndingRate: Double
    public let shortSuffixRate: Double?
    public let averageFinalTokenLength: Double?
    public let decayFactor: Double

    public init(
        sampleCount: Int,
        averageWordCount: Double,
        terminalPunctuationRate: Double,
        lowercaseStartRate: Double,
        questionEndingRate: Double,
        shortSuffixRate: Double? = nil,
        averageFinalTokenLength: Double? = nil,
        decayFactor: Double = 1
    ) {
        self.sampleCount = max(0, sampleCount)
        self.averageWordCount = max(0, averageWordCount)
        self.terminalPunctuationRate = Self.rate(terminalPunctuationRate)
        self.lowercaseStartRate = Self.rate(lowercaseStartRate)
        self.questionEndingRate = Self.rate(questionEndingRate)
        self.shortSuffixRate = shortSuffixRate.map(Self.rate)
        self.averageFinalTokenLength = averageFinalTokenLength.map { max(0, $0) }
        self.decayFactor = Self.rate(decayFactor)
    }

    public var promptGuidance: String? {
        guard sampleCount >= 2 else {
            return nil
        }

        var pieces = [
            "Recent kept style sketch: avg \(Self.format(averageWordCount)) words",
            frequencyPhrase(rate: terminalPunctuationRate, label: "terminal punctuation"),
            frequencyPhrase(rate: lowercaseStartRate, label: "lowercase starts"),
            frequencyPhrase(rate: questionEndingRate, label: "question endings")
        ]
        if let shortSuffixRate {
            pieces.append(frequencyPhrase(rate: shortSuffixRate, label: "short kept suffixes"))
        }
        if let averageFinalTokenLength {
            pieces.append("avg final token \(Self.format(averageFinalTokenLength)) chars")
        }
        return pieces.joined(separator: "; ") + "."
    }

    public var traceMetadata: [String: String] {
        var metadata = [
            "styleSketchSamples": String(sampleCount),
            "styleSketchAverageWords": Self.format(averageWordCount),
            "styleSketchTerminalPunctuationRate": Self.format(terminalPunctuationRate),
            "styleSketchLowercaseStartRate": Self.format(lowercaseStartRate),
            "styleSketchQuestionEndingRate": Self.format(questionEndingRate),
            "styleSketchDecayFactor": Self.format(decayFactor)
        ]
        if let shortSuffixRate {
            metadata["styleSketchShortSuffixRate"] = Self.format(shortSuffixRate)
        }
        if let averageFinalTokenLength {
            metadata["styleSketchAverageFinalTokenLength"] = Self.format(averageFinalTokenLength)
        }
        return metadata
    }

    private func frequencyPhrase(rate: Double, label: String) -> String {
        let frequency: String
        switch rate {
        case 0.67...:
            frequency = "usually"
        case 0.34..<0.67:
            frequency = "sometimes"
        default:
            frequency = "rarely"
        }

        return "\(frequency) \(label)"
    }

    private static func rate(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

public struct AcceptedTextStyleMemoryStore: Codable, Equatable, Sendable {
    public let maximumBuckets: Int
    public let halfLifeSeconds: TimeInterval
    private var buckets: [AcceptedTextStyleMemoryKey: AcceptedTextStyleBucket] = [:]

    public init(
        maximumBuckets: Int = 512,
        halfLifeSeconds: TimeInterval = 14 * 24 * 60 * 60
    ) {
        self.maximumBuckets = max(1, maximumBuckets)
        self.halfLifeSeconds = max(60, halfLifeSeconds)
    }

    public init?(jsonData: Data) {
        guard let decoded = try? JSONDecoder().decode(Self.self, from: jsonData) else {
            return nil
        }
        self = decoded
    }

    public func jsonData() -> Data? {
        try? JSONEncoder().encode(self)
    }

    @discardableResult
    public mutating func recordKeptText(
        _ acceptedText: String,
        key: AcceptedTextStyleMemoryKey,
        now: Date = Date()
    ) -> AcceptedTextStyleSketch? {
        guard let features = AcceptedTextStyleFeatures(text: acceptedText) else {
            return sketch(for: key, now: now)
        }

        var bucket = buckets[key] ?? AcceptedTextStyleBucket()
        bucket.decay(now: now, halfLifeSeconds: halfLifeSeconds)
        bucket.add(features)
        bucket.lastUpdatedSequence = nextSequence()
        bucket.lastUpdatedAt = now
        buckets[key] = bucket
        trimIfNeeded()
        return sketch(for: key, now: now)
    }

    public func sketch(
        for key: AcceptedTextStyleMemoryKey,
        now: Date = Date()
    ) -> AcceptedTextStyleSketch? {
        guard var bucket = buckets[key] else {
            return nil
        }

        bucket.decay(now: now, halfLifeSeconds: halfLifeSeconds)
        return bucket.sketch
    }

    private mutating func trimIfNeeded() {
        guard buckets.count > maximumBuckets else {
            return
        }

        let trimCount = buckets.count - maximumBuckets
        let keysToRemove = buckets
            .sorted { $0.value.lastUpdatedSequence < $1.value.lastUpdatedSequence }
            .prefix(trimCount)
            .map(\.key)

        for key in keysToRemove {
            buckets[key] = nil
        }
    }

    private mutating func nextSequence() -> UInt64 {
        let currentMax = buckets.values.map(\.lastUpdatedSequence).max() ?? 0
        return currentMax + 1
    }
}

private struct AcceptedTextStyleFeatures: Equatable, Sendable {
    let wordCount: Int
    let finalTokenLength: Int
    let hasTerminalPunctuation: Bool
    let startsLowercase: Bool
    let endsWithQuestion: Bool
    let isShortSuffix: Bool

    init?(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = AcceptanceSurvivalClassifier.looseTokens(in: trimmed)
        guard !trimmed.isEmpty, !words.isEmpty else {
            return nil
        }

        self.wordCount = words.count
        self.finalTokenLength = words.last?.count ?? 0
        self.hasTerminalPunctuation = trimmed.last.map(Self.isTerminalPunctuation) ?? false
        self.startsLowercase = trimmed.first.map(Self.isLowercaseLetter) ?? false
        self.endsWithQuestion = trimmed.hasSuffix("?")
        self.isShortSuffix = words.count <= 2
    }

    private static func isTerminalPunctuation(_ character: Character) -> Bool {
        [".", "!", "?", ",", ":", ";"].contains(character)
    }

    private static func isLowercaseLetter(_ character: Character) -> Bool {
        String(character).rangeOfCharacter(from: .lowercaseLetters) != nil
    }
}

private struct AcceptedTextStyleBucket: Codable, Equatable, Sendable {
    var sampleWeight: Double = 0
    var wordCountWeight: Double = 0
    var terminalPunctuationWeight: Double = 0
    var lowercaseStartWeight: Double = 0
    var questionEndingWeight: Double = 0
    var shortSuffixWeight: Double?
    var finalTokenLengthWeight: Double?
    var lastDecayFactor: Double = 1
    var lastUpdatedSequence: UInt64 = 0
    var lastUpdatedAt: Date = Date(timeIntervalSince1970: 0)

    mutating func add(_ features: AcceptedTextStyleFeatures) {
        sampleWeight += 1
        wordCountWeight += Double(features.wordCount)
        terminalPunctuationWeight += features.hasTerminalPunctuation ? 1 : 0
        lowercaseStartWeight += features.startsLowercase ? 1 : 0
        questionEndingWeight += features.endsWithQuestion ? 1 : 0
        shortSuffixWeight = (shortSuffixWeight ?? 0) + (features.isShortSuffix ? 1 : 0)
        finalTokenLengthWeight = (finalTokenLengthWeight ?? 0) + Double(features.finalTokenLength)
    }

    mutating func decay(now: Date, halfLifeSeconds: TimeInterval) {
        guard sampleWeight > 0 else {
            lastDecayFactor = 1
            return
        }

        let elapsed = max(0, now.timeIntervalSince(lastUpdatedAt))
        guard elapsed >= 1 else {
            lastDecayFactor = 1
            return
        }

        let factor = pow(0.5, elapsed / halfLifeSeconds)
        guard factor < 1 else {
            lastDecayFactor = 1
            return
        }

        sampleWeight *= factor
        wordCountWeight *= factor
        terminalPunctuationWeight *= factor
        lowercaseStartWeight *= factor
        questionEndingWeight *= factor
        shortSuffixWeight = shortSuffixWeight.map { $0 * factor }
        finalTokenLengthWeight = finalTokenLengthWeight.map { $0 * factor }
        lastUpdatedAt = now
        lastDecayFactor = factor
    }

    var sketch: AcceptedTextStyleSketch? {
        guard sampleWeight >= 2 else {
            return nil
        }

        return AcceptedTextStyleSketch(
            sampleCount: Int(sampleWeight.rounded()),
            averageWordCount: wordCountWeight / sampleWeight,
            terminalPunctuationRate: terminalPunctuationWeight / sampleWeight,
            lowercaseStartRate: lowercaseStartWeight / sampleWeight,
            questionEndingRate: questionEndingWeight / sampleWeight,
            shortSuffixRate: shortSuffixWeight.map { $0 / sampleWeight },
            averageFinalTokenLength: finalTokenLengthWeight.map { $0 / sampleWeight },
            decayFactor: lastDecayFactor
        )
    }
}
