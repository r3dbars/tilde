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

        if let partialWordCompletion = Self.partialWordCompletion(after: trimmed) {
            text = partialWordCompletion
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
        ).nonEmpty
    }

    private static func partialWordCompletion(after text: String) -> String? {
        guard text.last?.isWhitespace != true,
              let fragment = text.split(whereSeparator: { $0.isWhitespace }).last?.lowercased(),
              fragment.count >= 2 else {
            return nil
        }

        let candidates = [
            "hello",
            "this project",
            "that sounds good",
            "sounds good",
            "thanks for asking",
            "there is a better way",
            "would be great",
            "works well",
            "instant",
            "project",
            "because"
        ]

        return candidates.first { candidate in
            candidate.hasPrefix(fragment)
        }.map { " " + $0 }
    }
}
