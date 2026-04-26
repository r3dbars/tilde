import Foundation

public struct CompletionOutputCleaner: Equatable, Sendable {
    public let maxVisibleWords: Int

    public init(maxVisibleWords: Int = CompletionModelPolicy.mvp.maxVisibleWords) {
        self.maxVisibleWords = max(1, maxVisibleWords)
    }

    public func clean(_ rawOutput: String) -> CompletionSuggestion? {
        clean(rawOutput, after: nil)
    }

    public func clean(_ rawOutput: String, after textBeforeCursor: String?) -> CompletionSuggestion? {
        let withoutThinking = rawOutput
            .replacingOccurrences(
                of: #"<think>[\s\S]*?</think>"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"</?think>"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))

        guard !withoutThinking.isEmpty else {
            return nil
        }

        let singleLine = withoutThinking
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !singleLine.isEmpty else {
            return nil
        }

        guard !looksLikeAssistantMeta(singleLine) else {
            return nil
        }

        guard !looksLikeGenericChatFiller(singleLine) else {
            return nil
        }

        let normalizedSuggestion = ensureLeadingSpace(singleLine)
        let trimmedSuggestion: String
        if let textBeforeCursor {
            trimmedSuggestion = CompletionPrefixTrimmer.trim(normalizedSuggestion, after: textBeforeCursor)
        } else {
            trimmedSuggestion = normalizedSuggestion
        }

        guard !trimmedSuggestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return CompletionSuggestion(text: trimmedSuggestion, maxVisibleWords: maxVisibleWords)
    }

    private func looksLikeAssistantMeta(_ text: String) -> Bool {
        let normalized = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized.hasPrefix("okay, let's see")
            || normalized.hasPrefix("let's see")
            || normalized.hasPrefix("the user ")
            || normalized.hasPrefix("the user is ")
            || normalized.hasPrefix("user is ")
            || normalized.hasPrefix("assistant:")
            || normalized.hasPrefix("system:")
    }

    private func looksLikeGenericChatFiller(_ text: String) -> Bool {
        let normalized = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized.hasPrefix("that makes a lot of sense")
            || normalized.hasPrefix("i would like to")
            || normalized.hasPrefix("okay, i would")
            || normalized.hasPrefix("okay, would")
            || normalized.hasPrefix("sure,")
            || normalized.hasPrefix("certainly,")
    }

    private func ensureLeadingSpace(_ text: String) -> String {
        guard let first = text.first, !first.isWhitespace else {
            return text
        }

        return " " + text
    }
}
