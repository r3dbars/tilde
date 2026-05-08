import AutocompleteLabCore

struct SuggestionPresentationRefreshInput: Sendable {
    let request: CompletionRequest
    let expectedFieldIdentity: FocusedFieldIdentity
    let frontmostAppMatchesExpected: Bool
    let rawContext: FocusedTextContext?
    let terminalHostBlockReason: String?
    let promptCanSuggest: Bool
    let browserHostedSurfaceDecision: BrowserHostedSurfaceDecision
    let adjustedContext: FocusedTextContext?
    let adjustedFieldIdentity: FocusedFieldIdentity?
}

enum SuggestionPresentationRefreshDecision: Equatable, Sendable {
    case allow(FocusedTextContext)
    case block(reason: String)

    var context: FocusedTextContext? {
        guard case let .allow(context) = self else {
            return nil
        }
        return context
    }

    var reason: String? {
        guard case let .block(reason) = self else {
            return nil
        }
        return reason
    }
}

struct SuggestionPresentationRefreshPolicy: Sendable {
    func decision(for input: SuggestionPresentationRefreshInput) -> SuggestionPresentationRefreshDecision {
        guard input.frontmostAppMatchesExpected else {
            return .block(reason: "stale-app")
        }

        guard let rawContext = input.rawContext,
              !rawContext.isSecure,
              rawContext.selectedTextLength == 0 else {
            return .block(reason: "stale-focused-context")
        }

        guard !rawContext.capabilities.hasMarkedText else {
            return .block(reason: "composition-active")
        }

        guard input.terminalHostBlockReason == nil else {
            return .block(reason: "stale-terminal-host-proof")
        }

        guard input.promptCanSuggest else {
            return .block(reason: "stale-prompt-target")
        }

        if case let .blocked(block) = input.browserHostedSurfaceDecision {
            return .block(reason: block.traceReason)
        }

        guard let adjustedContext = input.adjustedContext,
              input.adjustedFieldIdentity == input.expectedFieldIdentity else {
            return .block(reason: "stale-field")
        }

        guard adjustedContext.textBeforeCursor == input.request.textBeforeCursor,
              adjustedContext.textAfterCursor == input.request.textAfterCursor else {
            return .block(reason: "stale-text")
        }

        return .allow(adjustedContext)
    }
}
