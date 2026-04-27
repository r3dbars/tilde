import Foundation

public final class MockCompletionEngine: CompletionEngine, @unchecked Sendable {
    public init() {}

    public func suggestion(for request: CompletionRequest) async throws -> CompletionSuggestion? {
        let trimmed = request.textBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= 3 else {
            return nil
        }

        let lowercased = trimmed.lowercased()
        let text: String

        if request.mode == .wordCompletion, lowercased.hasSuffix("dic") {
            text = "dictation"
        } else if request.mode == .wordCompletion, lowercased.hasSuffix("ar") {
            text = "are"
        } else if lowercased.hasSuffix("i think") {
            text = " we should ship this"
        } else if lowercased.hasSuffix("can we") {
            text = " make this feel instant"
        } else if lowercased.hasSuffix("the plan") {
            text = " is to keep it small"
        } else {
            text = " and keep moving"
        }

        return CompletionSuggestion(
            text: CompletionPrefixTrimmer.trim(text, after: trimmed),
            maxVisibleWords: request.maxVisibleWords
        )
    }
}
