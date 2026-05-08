import Foundation

public enum SuggestionAcceptanceProofScope: String, Equatable, Sendable {
    case nextWordPrefix
    case fullVisible
}

public enum SuggestionAcceptanceProofBlockReason: String, Equatable, Sendable {
    case missingVisibleText
    case unsupportedAction
    case nextWordMismatch
    case fullVisibleMismatch
}

public struct SuggestionAcceptanceProof: Equatable, Sendable {
    public let scope: SuggestionAcceptanceProofScope
    public let acceptedTextMatchesVisible: Bool
    public let acceptedTextIsVisiblePrefix: Bool
    public let acceptedCharacterCount: Int
    public let visibleCharacterCount: Int

    public init(
        scope: SuggestionAcceptanceProofScope,
        acceptedTextMatchesVisible: Bool,
        acceptedTextIsVisiblePrefix: Bool,
        acceptedCharacterCount: Int,
        visibleCharacterCount: Int
    ) {
        self.scope = scope
        self.acceptedTextMatchesVisible = acceptedTextMatchesVisible
        self.acceptedTextIsVisiblePrefix = acceptedTextIsVisiblePrefix
        self.acceptedCharacterCount = acceptedCharacterCount
        self.visibleCharacterCount = visibleCharacterCount
    }

    public var traceMetadata: [String: String] {
        [
            "acceptanceProof": "passed",
            "acceptedVisibleScope": scope.rawValue,
            "acceptedTextMatchesVisible": String(acceptedTextMatchesVisible),
            "acceptedTextIsVisiblePrefix": String(acceptedTextIsVisiblePrefix),
            "acceptedChars": String(acceptedCharacterCount),
            "visibleChars": String(visibleCharacterCount)
        ]
    }
}

public enum SuggestionAcceptanceProofDecision: Equatable, Sendable {
    case allowed(SuggestionAcceptanceProof)
    case blocked(SuggestionAcceptanceProofBlockReason)
}

public struct SuggestionAcceptanceProofPolicy: Equatable, Sendable {
    public init() {}

    public func decision(
        action: KeyboardAction,
        acceptedText: String,
        visibleText: String?
    ) -> SuggestionAcceptanceProofDecision {
        guard let visibleText, !visibleText.isEmpty else {
            return .blocked(.missingVisibleText)
        }

        switch action {
        case .acceptNextWord:
            let expectedText = CompletionSuggestion.acceptedPrefix(in: visibleText, wordLimit: 1)
            guard acceptedText == expectedText,
                  visibleText.hasPrefix(acceptedText) else {
                return .blocked(.nextWordMismatch)
            }

            return .allowed(SuggestionAcceptanceProof(
                scope: .nextWordPrefix,
                acceptedTextMatchesVisible: acceptedText == visibleText,
                acceptedTextIsVisiblePrefix: true,
                acceptedCharacterCount: acceptedText.count,
                visibleCharacterCount: visibleText.count
            ))

        case .acceptAllVisible:
            guard acceptedText == visibleText else {
                return .blocked(.fullVisibleMismatch)
            }

            return .allowed(SuggestionAcceptanceProof(
                scope: .fullVisible,
                acceptedTextMatchesVisible: true,
                acceptedTextIsVisiblePrefix: true,
                acceptedCharacterCount: acceptedText.count,
                visibleCharacterCount: visibleText.count
            ))

        case .dismiss, .passThrough, .undoAcceptedInsertion:
            return .blocked(.unsupportedAction)
        }
    }
}
