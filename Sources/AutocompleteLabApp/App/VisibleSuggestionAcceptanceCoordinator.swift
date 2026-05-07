import AutocompleteLabCore

enum VisibleSuggestionAcceptanceKind: Equatable {
    case nextWord
    case allVisible

    var action: KeyboardAction {
        switch self {
        case .nextWord:
            .acceptNextWord
        case .allVisible:
            .acceptAllVisible
        }
    }

    var decisionText: String {
        switch self {
        case .nextWord:
            "Accepted: next word"
        case .allVisible:
            "Accepted: full suggestion"
        }
    }

    var finalHideReason: String {
        switch self {
        case .nextWord:
            "accepted-next-word-final"
        case .allVisible:
            "accepted-all"
        }
    }
}

struct VisibleSuggestionAcceptanceContext: Equatable {
    var currentFieldIdentity: FocusedFieldIdentity?
    var lastTextSnapshot: FocusedTextSnapshot?
    var fallbackBundleIdentifier: String?
}

struct VisibleSuggestionAcceptanceResult: Equatable {
    var action: KeyboardAction
    var acceptedText: String
    var appBundleIdentifier: String?
    var requestMode: CompletionRequestMode?
    var repetitionScope: String
    var decisionText: String
    var shouldRefreshVisibleSuggestion: Bool
    var hideReason: String
    var updatedLastTextSnapshot: FocusedTextSnapshot?
}

struct VisibleSuggestionAcceptanceCoordinator: Equatable {
    func commit(
        _ kind: VisibleSuggestionAcceptanceKind,
        acceptedText: String,
        state: inout VisibleSuggestionState,
        context: VisibleSuggestionAcceptanceContext
    ) -> VisibleSuggestionAcceptanceResult {
        let updatedSnapshot = updatedSnapshot(
            acceptedText: acceptedText,
            currentFieldIdentity: context.currentFieldIdentity,
            lastTextSnapshot: context.lastTextSnapshot
        )

        switch kind {
        case .nextWord:
            state.commitNextWordAcceptance(acceptedText)
            state.advanceBaseline(
                afterAccepting: acceptedText,
                snapshotTextBeforeCursor: updatedSnapshot?.textBeforeCursor
            )
        case .allVisible:
            state.commitAllVisibleAcceptance(acceptedText)
        }

        let appBundleIdentifier = state.appBundleIdentifier ?? context.fallbackBundleIdentifier
        return VisibleSuggestionAcceptanceResult(
            action: kind.action,
            acceptedText: acceptedText,
            appBundleIdentifier: appBundleIdentifier,
            requestMode: state.requestMode,
            repetitionScope: appBundleIdentifier ?? "",
            decisionText: kind.decisionText,
            shouldRefreshVisibleSuggestion: kind == .nextWord && state.hasVisibleSuggestion,
            hideReason: kind.finalHideReason,
            updatedLastTextSnapshot: updatedSnapshot
        )
    }

    private func updatedSnapshot(
        acceptedText: String,
        currentFieldIdentity: FocusedFieldIdentity?,
        lastTextSnapshot: FocusedTextSnapshot?
    ) -> FocusedTextSnapshot? {
        guard let currentFieldIdentity,
              let lastTextSnapshot,
              lastTextSnapshot.fieldIdentity == currentFieldIdentity else {
            return nil
        }

        return FocusedTextSnapshot(
            fieldIdentity: currentFieldIdentity,
            textBeforeCursor: lastTextSnapshot.textBeforeCursor + acceptedText,
            textAfterCursor: lastTextSnapshot.textAfterCursor
        )
    }
}
