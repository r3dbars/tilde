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

        guard profile.insertionMode != .disabled else {
            return .blocked(reason: "profile-insertion-disabled")
        }

        guard profile.supportsOneWordAcceptance || profile.supportsFullAcceptance else {
            return .blocked(reason: "profile-acceptance-disabled")
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

        if !profile.supportsFullAcceptance,
           Self.wordCount(in: acceptedText) > 1 {
            return .blocked(reason: "accepted-text-multiword-full-disabled")
        }

        return .allowed
    }

    private static func wordCount(in text: String) -> Int {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .count
    }
}
