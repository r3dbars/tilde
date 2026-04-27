import Foundation

public struct SuggestionRepetitionSuppressor: Equatable, Sendable {
    public let missThreshold: Int
    private var missCounts: [String: Int] = [:]

    public init(missThreshold: Int = 2) {
        self.missThreshold = max(1, missThreshold)
    }

    public func shouldSuppress(_ text: String, mode: CompletionRequestMode) -> Bool {
        guard mode == .phraseContinuation else {
            return false
        }

        let key = normalizedKey(for: text)
        guard !key.isEmpty else {
            return false
        }

        return (missCounts[key] ?? 0) >= missThreshold
    }

    public mutating func recordMiss(_ text: String, mode: CompletionRequestMode?) {
        guard mode == .phraseContinuation else {
            return
        }

        let key = normalizedKey(for: text)
        guard !key.isEmpty else {
            return
        }

        missCounts[key, default: 0] += 1
    }

    public mutating func recordAcceptance(_ text: String, mode: CompletionRequestMode?) {
        guard mode == .phraseContinuation else {
            return
        }

        let key = normalizedKey(for: text)
        guard !key.isEmpty else {
            return
        }

        missCounts[key] = nil
    }

    public mutating func reset() {
        missCounts.removeAll()
    }

    private func normalizedKey(for text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
    }
}
