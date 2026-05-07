import Foundation

public struct SuggestionRepetitionSuppressor: Equatable, Sendable {
    public let missThreshold: Int
    private var missCounts: [String: Int] = [:]

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

        return (missCounts[key] ?? 0) >= missThreshold
    }

    public mutating func recordMiss(
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

        missCounts[key, default: 0] += 1
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
        case .phraseContinuation:
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
}
