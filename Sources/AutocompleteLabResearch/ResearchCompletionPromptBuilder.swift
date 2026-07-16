import AutocompleteLabCore

/// Keeps screen-context prompt experiments available to local evals without
/// adding screen-derived personalization inputs to the shipping request path.
public struct ResearchCompletionPromptBuilder: Equatable, Sendable {
    public let base: CompletionPromptBuilder

    public init(maxVisibleWords: Int = CompletionModelPolicy.mvp.maxVisibleWords) {
        self.base = CompletionPromptBuilder(maxVisibleWords: maxVisibleWords)
    }

    public func prompt(
        for request: CompletionRequest,
        visiblePageContext: VisiblePageContext
    ) -> CompletionPrompt {
        let basePrompt = base.prompt(for: request)
        return CompletionPrompt(
            system: basePrompt.system + "\n" + visiblePageContext.promptGuidance,
            user: """
            Visible page context:
            \(visiblePageContext.promptText)

            \(basePrompt.user)
            """
        )
    }
}
