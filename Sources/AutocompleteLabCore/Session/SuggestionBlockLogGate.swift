import Foundation

public struct SuggestionBlockLogGate: Equatable, Sendable {
    private var lastSignature: String?

    public init() {}

    public mutating func shouldRecord(signature: String) -> Bool {
        guard !signature.isEmpty else {
            return true
        }

        if lastSignature == signature {
            return false
        }

        lastSignature = signature
        return true
    }

    public mutating func reset() {
        lastSignature = nil
    }
}
