import Foundation

public struct CompletionPrompt: Equatable, Sendable {
    public let system: String
    public let user: String

    public init(system: String, user: String) {
        self.system = system
        self.user = user
    }
}

public struct CompletionPromptBuilder: Equatable, Sendable {
    public let maxContextCharacters: Int
    public let maxCurrentParagraphCharacters: Int
    public let maxVisibleWords: Int

    public init(
        maxContextCharacters: Int = 360,
        maxCurrentParagraphCharacters: Int = 220,
        maxVisibleWords: Int = CompletionModelPolicy.mvp.maxVisibleWords
    ) {
        self.maxContextCharacters = max(80, maxContextCharacters)
        self.maxCurrentParagraphCharacters = max(80, maxCurrentParagraphCharacters)
        self.maxVisibleWords = max(1, maxVisibleWords)
    }

    public func prompt(for request: CompletionRequest) -> CompletionPrompt {
        let context = promptContext(from: request.textBeforeCursor)

        return CompletionPrompt(
            system: """
            You are an inline autocomplete engine, not a chat assistant.
            Continue only the current sentence or phrase before the cursor.
            Return only the next \(maxVisibleWords) words or fewer.
            Do not reuse old lines, answer, explain, summarize, greet, restart the sentence, or mention the user.
            No explanation.
            No quotes. No reasoning.
            """,
            user: "Text before cursor:\n\(context)\n\nAutocomplete continuation:"
        )
    }

    private func promptContext(from textBeforeCursor: String) -> String {
        let nearbyContext = String(textBeforeCursor.suffix(maxContextCharacters))
        let currentParagraph = nearbyContext
            .components(separatedBy: "\n\n")
            .last?
            .trimmingCharacters(in: .newlines) ?? nearbyContext

        return String(currentParagraph.suffix(maxCurrentParagraphCharacters))
    }
}
