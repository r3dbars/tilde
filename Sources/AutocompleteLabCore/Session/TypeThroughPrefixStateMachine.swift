import Foundation

public enum TypeThroughCompositionState: Equatable, Sendable {
    case inactive
    case activeSupported
    case activeUnsupported
}

public enum TypeThroughPrefixInvalidationReason: String, Equatable, Sendable {
    case missingVisibleSuggestion
    case staleField
    case textAfterCursorChanged
    case baselineChanged
    case mismatch
}

public enum TypeThroughPrefixSuppressionReason: String, Equatable, Sendable {
    case unsupportedComposition
}

public struct TypeThroughPrefixInput: Equatable, Sendable {
    public let baselineSnapshot: FocusedTextSnapshot
    public let currentSnapshot: FocusedTextSnapshot
    public let compositionState: TypeThroughCompositionState

    public init(
        baselineSnapshot: FocusedTextSnapshot,
        currentSnapshot: FocusedTextSnapshot,
        compositionState: TypeThroughCompositionState = .inactive
    ) {
        self.baselineSnapshot = baselineSnapshot
        self.currentSnapshot = currentSnapshot
        self.compositionState = compositionState
    }
}

public struct TypeThroughPrefixSurvival: Equatable, Sendable {
    public static let confidenceCreditCharacterThreshold = 3

    public let typedCharacterCount: Int
    public let remainingVisibleCharacterCount: Int
    public let consumedFullSuggestion: Bool

    public init(
        typedCharacterCount: Int,
        remainingVisibleCharacterCount: Int,
        consumedFullSuggestion: Bool
    ) {
        self.typedCharacterCount = max(0, typedCharacterCount)
        self.remainingVisibleCharacterCount = max(0, remainingVisibleCharacterCount)
        self.consumedFullSuggestion = consumedFullSuggestion
    }

    public var traceMetadata: [String: String] {
        [
            "reason": "survived_typethrough",
            "typeThroughSurvival": "true",
            "typedThroughChars": String(typedCharacterCount),
            "remainingVisibleChars": String(remainingVisibleCharacterCount),
            "typeThroughConsumedFullSuggestion": String(consumedFullSuggestion),
            "typeThroughConfidenceCredit": String(qualifiesForConfidenceCredit)
        ]
    }

    public var qualifiesForConfidenceCredit: Bool {
        typedCharacterCount >= Self.confidenceCreditCharacterThreshold
    }
}

public enum TypeThroughPrefixTransition: Equatable, Sendable {
    case unchanged
    case survived(TypeThroughPrefixSurvival)
    case invalidated(TypeThroughPrefixInvalidationReason)
    case suppressed(TypeThroughPrefixSuppressionReason)

    public var traceMetadata: [String: String] {
        switch self {
        case .unchanged:
            [
                "typeThroughSurvival": "false",
                "typeThroughDecision": "unchanged"
            ]
        case let .survived(survival):
            survival.traceMetadata.merging([
                "typeThroughDecision": "survived"
            ]) { current, _ in current }
        case let .invalidated(reason):
            [
                "reason": reason.rawValue,
                "typeThroughSurvival": "false",
                "typeThroughDecision": "invalidated",
                "typeThroughInvalidationReason": reason.rawValue
            ]
        case let .suppressed(reason):
            [
                "reason": reason.rawValue,
                "typeThroughSurvival": "false",
                "typeThroughDecision": "suppressed",
                "typeThroughSuppressionReason": reason.rawValue
            ]
        }
    }
}

public struct TypeThroughPrefixStateMachine: Equatable, Sendable {
    public init() {}

    public func transition(
        session: SuggestionSession,
        input: TypeThroughPrefixInput
    ) -> TypeThroughPrefixTransition {
        guard input.compositionState != .activeUnsupported else {
            return .suppressed(.unsupportedComposition)
        }

        guard let suggestion = session.visibleSuggestion else {
            return .invalidated(.missingVisibleSuggestion)
        }

        guard input.currentSnapshot.fieldIdentity == input.baselineSnapshot.fieldIdentity else {
            return .invalidated(.staleField)
        }

        guard input.currentSnapshot.textAfterCursor == input.baselineSnapshot.textAfterCursor else {
            return .invalidated(.textAfterCursorChanged)
        }

        guard input.currentSnapshot.textBeforeCursor.hasPrefix(input.baselineSnapshot.textBeforeCursor) else {
            return .invalidated(.baselineChanged)
        }

        let typedSuffix = String(input.currentSnapshot.textBeforeCursor.dropFirst(
            input.baselineSnapshot.textBeforeCursor.count
        ))
        guard !typedSuffix.isEmpty else {
            return .unchanged
        }

        guard let remaining = suggestion.remainingTextAfterTypeThroughPrefix(typedSuffix) else {
            return .invalidated(.mismatch)
        }

        let remainingSuggestion = CompletionSuggestion(
            text: String(remaining),
            maxVisibleWords: suggestion.maxVisibleWords,
            maxVisibleCharacters: suggestion.maxVisibleCharacters
        )
        return .survived(TypeThroughPrefixSurvival(
            typedCharacterCount: typedSuffix.count,
            remainingVisibleCharacterCount: remaining.isEmpty ? 0 : remainingSuggestion.visibleText.count,
            consumedFullSuggestion: remaining.isEmpty
        ))
    }

    @discardableResult
    public func apply(
        to session: inout SuggestionSession,
        input: TypeThroughPrefixInput
    ) -> TypeThroughPrefixTransition {
        let transition = transition(session: session, input: input)
        guard case .survived = transition else {
            return transition
        }

        let typedSuffix = String(input.currentSnapshot.textBeforeCursor.dropFirst(
            input.baselineSnapshot.textBeforeCursor.count
        ))
        _ = session.commitTypedVisiblePrefix(typedSuffix)
        return transition
    }
}

enum TypeThroughPrefixMatcher {
    static func remainingText(
        afterMatching typedPrefix: String,
        in suggestionText: String
    ) -> Substring? {
        guard let endIndex = matchedPrefixEndIndex(
            typedPrefix: typedPrefix,
            suggestionText: suggestionText
        ) else {
            return nil
        }

        return suggestionText[endIndex...]
    }

    static func matchedPrefixEndIndex(
        typedPrefix: String,
        suggestionText: String
    ) -> String.Index? {
        guard !typedPrefix.isEmpty else {
            return suggestionText.startIndex
        }

        var suggestionIndex = suggestionText.startIndex
        var typedIndex = typedPrefix.startIndex
        while typedIndex < typedPrefix.endIndex {
            let typedCharacter = typedPrefix[typedIndex]

            if typedCharacter.isWhitespace {
                let nextTypedIndex = typedPrefix.index(after: typedIndex)
                if suggestionIndex == suggestionText.endIndex {
                    typedIndex = consumeWhitespace(in: typedPrefix, from: nextTypedIndex)
                    guard typedIndex == typedPrefix.endIndex else {
                        return nil
                    }
                    return suggestionText.endIndex
                }

                guard suggestionText[suggestionIndex].isWhitespace else {
                    return nil
                }

                typedIndex = consumeWhitespace(in: typedPrefix, from: nextTypedIndex)
                suggestionIndex = consumeWhitespace(
                    in: suggestionText,
                    from: suggestionText.index(after: suggestionIndex)
                )
                continue
            }

            guard suggestionIndex < suggestionText.endIndex else {
                return nil
            }

            guard normalized(String(typedCharacter)) == normalized(String(suggestionText[suggestionIndex])) else {
                return nil
            }

            suggestionIndex = suggestionText.index(after: suggestionIndex)
            typedIndex = typedPrefix.index(after: typedIndex)
        }

        return suggestionIndex
    }

    private static func consumeWhitespace(
        in value: String,
        from startIndex: String.Index
    ) -> String.Index {
        var index = startIndex
        while index < value.endIndex, value[index].isWhitespace {
            index = value.index(after: index)
        }
        return index
    }

    private static func normalized(_ value: String) -> String {
        value.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
    }
}

extension CompletionSuggestion {
    func remainingTextAfterTypeThroughPrefix(_ typedPrefix: String) -> Substring? {
        TypeThroughPrefixMatcher.remainingText(
            afterMatching: typedPrefix,
            in: text
        )
    }
}
