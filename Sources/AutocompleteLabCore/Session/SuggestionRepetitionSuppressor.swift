import Foundation

public struct SuggestionRepetitionMissRecord: Equatable, Sendable {
    public let kind: String
    public let weight: Double
    public let total: Double
    public let threshold: Double
    public let suppressed: Bool
    public let lifetimeMilliseconds: Int?

    public init(
        kind: String,
        weight: Double,
        total: Double,
        threshold: Double,
        suppressed: Bool,
        lifetimeMilliseconds: Int? = nil
    ) {
        self.kind = kind
        self.weight = weight
        self.total = total
        self.threshold = threshold
        self.suppressed = suppressed
        self.lifetimeMilliseconds = lifetimeMilliseconds
    }

    public var traceMetadata: [String: String] {
        var metadata = [
            "repetitionMissKind": kind,
            "repetitionMissWeight": Self.format(weight),
            "repetitionMissTotal": Self.format(total),
            "repetitionMissThreshold": Self.format(threshold),
            "repetitionMissSuppressed": String(suppressed)
        ]
        if let lifetimeMilliseconds {
            metadata["repetitionMissLifetimeMs"] = String(lifetimeMilliseconds)
        }
        return metadata
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

public struct SuggestionRepetitionSuppressor: Equatable, Sendable {
    public let missThreshold: Int
    private var missCounts: [String: Double] = [:]

    public init(missThreshold: Int = 2) {
        self.missThreshold = max(1, missThreshold)
    }

    public func shouldSuppress(
        _ text: String,
        mode: CompletionRequestMode,
        scope: String = ""
    ) -> Bool {
        guard shouldTrackMisses(for: text, mode: mode) else {
            return false
        }

        let key = normalizedKey(for: text, mode: mode, scope: scope)
        guard !key.isEmpty else {
            return false
        }

        return (missCounts[key] ?? 0) >= Double(missThreshold)
    }

    @discardableResult
    public mutating func recordMiss(
        _ text: String,
        mode: CompletionRequestMode?,
        scope: String = ""
    ) -> SuggestionRepetitionMissRecord? {
        recordWeightedMiss(
            text,
            mode: mode,
            scope: scope,
            kind: "miss",
            weight: 1.0,
            lifetimeMilliseconds: nil
        )
    }

    @discardableResult
    public mutating func recordIgnored(
        _ text: String,
        mode: CompletionRequestMode?,
        scope: String = "",
        lifetimeMilliseconds: Int? = nil
    ) -> SuggestionRepetitionMissRecord? {
        recordWeightedMiss(
            text,
            mode: mode,
            scope: scope,
            kind: "ignored",
            weight: ignoredMissWeight(lifetimeMilliseconds: lifetimeMilliseconds),
            lifetimeMilliseconds: lifetimeMilliseconds
        )
    }

    public mutating func recordAcceptance(
        _ text: String,
        mode: CompletionRequestMode?,
        scope: String = ""
    ) {
        guard let mode,
              shouldTrackMisses(for: text, mode: mode) else {
            return
        }

        let key = normalizedKey(for: text, mode: mode, scope: scope)
        guard !key.isEmpty else {
            return
        }

        missCounts[key] = nil
    }

    public mutating func reset() {
        missCounts.removeAll()
    }

    private mutating func recordWeightedMiss(
        _ text: String,
        mode: CompletionRequestMode?,
        scope: String,
        kind: String,
        weight: Double,
        lifetimeMilliseconds: Int?
    ) -> SuggestionRepetitionMissRecord? {
        guard let mode,
              shouldTrackMisses(for: text, mode: mode) else {
            return nil
        }

        let key = normalizedKey(for: text, mode: mode, scope: scope)
        guard !key.isEmpty else {
            return nil
        }

        let safeWeight = max(0, weight)
        missCounts[key, default: 0] += safeWeight
        let total = missCounts[key] ?? 0
        return SuggestionRepetitionMissRecord(
            kind: kind,
            weight: safeWeight,
            total: total,
            threshold: Double(missThreshold),
            suppressed: total >= Double(missThreshold),
            lifetimeMilliseconds: lifetimeMilliseconds
        )
    }

    private func normalizedKey(
        for text: String,
        mode: CompletionRequestMode? = nil,
        scope: String = ""
    ) -> String {
        let normalizedText = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !normalizedText.isEmpty else {
            return ""
        }

        let normalizedScope = scope
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let mode else {
            return normalizedText
        }

        return "\(mode.rawValue)|\(normalizedScope)|\(normalizedText)"
    }

    private func shouldTrackMisses(for text: String, mode: CompletionRequestMode) -> Bool {
        switch mode {
        case .phraseContinuation, .sentenceContinuation:
            return true
        case .wordCompletion:
            return isWordSuffix(text)
        }
    }

    private func isWordSuffix(_ text: String) -> Bool {
        let normalized = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return !normalized.isEmpty
            && normalized.count <= 16
            && normalized.allSatisfy(\.isLetter)
    }

    private func ignoredMissWeight(lifetimeMilliseconds: Int?) -> Double {
        guard let lifetimeMilliseconds else {
            return 0.25
        }

        switch max(0, lifetimeMilliseconds) {
        case 0..<250:
            return 0.05
        case 250..<1_500:
            return 0.20
        case 1_500..<5_000:
            return 0.35
        default:
            return 0.50
        }
    }
}
