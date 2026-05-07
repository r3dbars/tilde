import Foundation

public enum AcceptedTextSafetyDecision: Equatable, Sendable {
    case allowed
    case blocked(reason: String)

    public var canInsert: Bool {
        self == .allowed
    }

    public var blockReason: String? {
        guard case let .blocked(reason) = self else {
            return nil
        }

        return reason
    }
}

public struct AcceptedTextSafetyPolicy: Equatable, Sendable {
    public init() {}

    public func decision(
        acceptedText: String,
        profile: CompatibilityProfile
    ) -> AcceptedTextSafetyDecision {
        guard !acceptedText.isEmpty else {
            return .blocked(reason: "accepted-text-empty")
        }

        if acceptedText.unicodeScalars.contains(where: { CharacterSet.newlines.contains($0) }) {
            return .blocked(reason: "accepted-text-line-break")
        }

        if acceptedText.unicodeScalars.contains(where: { $0 == "\t" }) {
            return .blocked(reason: "accepted-text-tab")
        }

        if acceptedText.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
            return .blocked(reason: "accepted-text-control-character")
        }

        return .allowed
    }
}
