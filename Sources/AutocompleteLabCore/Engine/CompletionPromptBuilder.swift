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
    public let maxVisibleWords: Int

    public init(
        maxContextCharacters: Int = 900,
        maxVisibleWords: Int = CompletionModelPolicy.mvp.maxVisibleWords
    ) {
        self.maxContextCharacters = max(120, maxContextCharacters)
        self.maxVisibleWords = max(1, maxVisibleWords)
    }

    public func prompt(for request: CompletionRequest) -> CompletionPrompt {
        let context = String(request.textBeforeCursor.suffix(maxContextCharacters))

        return CompletionPrompt(
            system: """
            You are an inline autocomplete engine, not a chat assistant.
            Continue only the exact writing before the cursor.
            Return only the next \(maxVisibleWords) words or fewer.
            Do not answer, explain, summarize, greet, restart the sentence, or mention the user.
            No explanation.
            No quotes. No reasoning.
            """,
            user: "Text before cursor:\n\(context)\n\nAutocomplete continuation:"
        )
    }
}
