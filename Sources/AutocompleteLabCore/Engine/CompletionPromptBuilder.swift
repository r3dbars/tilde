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
            system: "Complete the user's writing. Return only the next \(maxVisibleWords) words or fewer. No quotes. No explanation. No reasoning.",
            user: context
        )
    }
}
