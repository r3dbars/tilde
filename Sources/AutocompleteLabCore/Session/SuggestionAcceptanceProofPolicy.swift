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

public enum AcceptanceSafetyBlockReason: String, Equatable, Sendable {
    case profileDisallowsOneWordAcceptance
    case profileDisallowsFullAcceptance
    case noSubmitProfileDisallowsFullAcceptance
    case noSubmitProfileRequiresSingleWord
    case acceptedTextNotVisible
    case acceptedTextContainsNewline
    case acceptedTextContainsTab
    case acceptedTextContainsControlCharacter
    case unsupportedAction
}

public enum AcceptanceSafetyDecision: Equatable, Sendable {
    case allowed
    case blocked(AcceptanceSafetyBlockReason)
}

public struct AcceptanceSafetyPolicy: Equatable, Sendable {
    public init() {}

    public func decision(
        action: KeyboardAction,
        acceptedText: String,
        visibleText: String?,
        profile: CompatibilityProfile
    ) -> AcceptanceSafetyDecision {
        switch action {
        case .acceptNextWord:
            guard profile.supportsOneWordAcceptance else {
                return .blocked(.profileDisallowsOneWordAcceptance)
            }
        case .acceptAllVisible:
            guard !profile.requiresNoSubmitAcceptanceProof else {
                return .blocked(.noSubmitProfileDisallowsFullAcceptance)
            }
            guard profile.supportsFullAcceptance else {
                return .blocked(.profileDisallowsFullAcceptance)
            }
        case .dismiss, .passThrough, .undoAcceptedInsertion:
            return .blocked(.unsupportedAction)
        }

        guard let visibleText,
              !visibleText.isEmpty,
              !acceptedText.isEmpty,
              acceptedTextMatchesVisibleText(
                  acceptedText,
                  visibleText: visibleText,
                  action: action
              ) else {
            return .blocked(.acceptedTextNotVisible)
        }

        if let controlReason = controlCharacterReason(in: acceptedText) {
            return .blocked(controlReason)
        }

        if profile.requiresNoSubmitAcceptanceProof,
           nonEmptyWordCount(in: acceptedText) > 1 {
            return .blocked(.noSubmitProfileRequiresSingleWord)
        }

        return .allowed
    }

    private func controlCharacterReason(in text: String) -> AcceptanceSafetyBlockReason? {
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 9:
                return .acceptedTextContainsTab
            case 10, 13:
                return .acceptedTextContainsNewline
            default:
                if CharacterSet.controlCharacters.contains(scalar) {
                    return .acceptedTextContainsControlCharacter
                }
            }
        }

        return nil
    }

    private func nonEmptyWordCount(in text: String) -> Int {
        text
            .split(whereSeparator: \.isWhitespace)
            .count
    }

    private func acceptedTextMatchesVisibleText(
        _ acceptedText: String,
        visibleText: String,
        action: KeyboardAction
    ) -> Bool {
        if visibleText.hasPrefix(acceptedText) {
            return true
        }

        guard action == .acceptNextWord else {
            return false
        }

        return CompletionSuggestion.nextWordAcceptanceText(in: visibleText) == acceptedText
    }
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
            let expectedTextWithTrailingSpace = CompletionSuggestion.nextWordAcceptanceText(in: visibleText)
            let acceptedTextIsVisiblePrefix = visibleText.hasPrefix(acceptedText)
                || acceptedText == expectedTextWithTrailingSpace
            guard (acceptedText == expectedText || acceptedText == expectedTextWithTrailingSpace),
                  acceptedTextIsVisiblePrefix else {
                return .blocked(.nextWordMismatch)
            }

            return .allowed(SuggestionAcceptanceProof(
                scope: .nextWordPrefix,
                acceptedTextMatchesVisible: acceptedText == visibleText,
                acceptedTextIsVisiblePrefix: acceptedTextIsVisiblePrefix,
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
