import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Command context panel state")
struct CommandContextPanelStateTests {
    @Test("Unsupported apps use copy fallback without enabling inline")
    func unsupportedAppsUseCopyFallbackWithoutEnablingInline() {
        let state = CommandContextPanelState(
            appDisplayName: "Atlas",
            bundleIdentifier: "com.openai.atlas",
            supportStatus: .unsupported,
            isAppEnabled: false,
            runtimeReport: readyRuntime,
            context: editableContext,
            suggestionText: " next step",
            isLoading: false,
            statusMessage: ""
        )

        #expect(state.pathText == "Path: copy fallback only; inline stays off")
        #expect(state.contextText.contains("current field, 24 chars before cursor"))
        #expect(state.canRequestSuggestion)
        #expect(state.canCopySuggestion)
        #expect(state.normalTypingText == "Normal typing: untouched; this opens only from the menu or Settings.")
        #expect(state.statusText == "Ready: press Suggest. Copy writes to clipboard only.")
    }

    @Test("Denylisted apps cannot request context suggestions")
    func denylistedAppsCannotRequestContextSuggestions() {
        let state = CommandContextPanelState(
            appDisplayName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            supportStatus: .denylisted,
            isAppEnabled: false,
            runtimeReport: readyRuntime,
            context: nil,
            suggestionText: nil,
            isLoading: false,
            statusMessage: ""
        )

        #expect(state.pathText == "Path: off for blocked app")
        #expect(!state.canRequestSuggestion)
        #expect(!state.canCopySuggestion)
        #expect(state.requestUnavailableReason == "This app stays off because it can expose secrets or shell input.")
    }

    @Test("Secure fields and missing model block requests")
    func secureFieldsAndMissingModelBlockRequests() {
        let secure = CommandContextPanelState(
            appDisplayName: "TextEdit",
            bundleIdentifier: "com.apple.TextEdit",
            supportStatus: CompatibilityProfileStore.mvp.supportStatus(for: "com.apple.TextEdit"),
            isAppEnabled: true,
            runtimeReport: readyRuntime,
            context: CommandContextSnapshot(
                textBeforeCursorLength: 0,
                textAfterCursorLength: 0,
                selectedTextLength: 0,
                isSecure: true,
                fieldKind: .secure,
                canInsertWithAccessibility: false,
                hasCaretBounds: false,
                hasFieldBounds: true
            ),
            suggestionText: nil,
            isLoading: false,
            statusMessage: ""
        )

        #expect(!secure.canRequestSuggestion)
        #expect(secure.contextText == "Context: secure field, not read")
        #expect(secure.requestUnavailableReason == "Secure fields stay off.")

        let missingModel = CommandContextPanelState(
            appDisplayName: "TextEdit",
            bundleIdentifier: "com.apple.TextEdit",
            supportStatus: CompatibilityProfileStore.mvp.supportStatus(for: "com.apple.TextEdit"),
            isAppEnabled: true,
            runtimeReport: RuntimeReadinessReport(
                stage: .downloadNeeded,
                summary: "download needed",
                action: .revealModelFolder
            ),
            context: editableContext,
            suggestionText: nil,
            isLoading: false,
            statusMessage: ""
        )

        #expect(!missingModel.canRequestSuggestion)
        #expect(missingModel.requestUnavailableReason == "Local model is download needed.")
    }

    @Test("Selected text is treated as panel context")
    func selectedTextIsTreatedAsPanelContext() {
        let selected = CommandContextSnapshot(
            textBeforeCursorLength: 4,
            textAfterCursorLength: 8,
            selectedTextLength: 17,
            isSecure: false,
            fieldKind: .multilineCompose,
            canInsertWithAccessibility: true,
            hasCaretBounds: true,
            hasFieldBounds: true
        )

        #expect(selected.hasRequestText)
        #expect(selected.sourceName == "selected text")
        #expect(selected.summaryText.contains("selected text, 17 chars"))
    }

    @Test("Loading state disables duplicate requests and copy")
    func loadingStateDisablesDuplicateRequestsAndCopy() {
        let state = CommandContextPanelState(
            appDisplayName: "TextEdit",
            bundleIdentifier: "com.apple.TextEdit",
            supportStatus: CompatibilityProfileStore.mvp.supportStatus(for: "com.apple.TextEdit"),
            isAppEnabled: true,
            runtimeReport: readyRuntime,
            context: editableContext,
            suggestionText: " next step",
            isLoading: true,
            statusMessage: ""
        )

        #expect(state.requestButtonTitle == "Thinking...")
        #expect(!state.canRequestSuggestion)
        #expect(!state.canCopySuggestion)
        #expect(state.suggestionDisplayText == "Thinking locally...")
    }
}

private let readyRuntime = RuntimeReadinessReport(
    stage: .ready,
    summary: "ready",
    action: .none,
    isReady: true
)

private let editableContext = CommandContextSnapshot(
    textBeforeCursorLength: 24,
    textAfterCursorLength: 0,
    selectedTextLength: 0,
    isSecure: false,
    fieldKind: .multilineCompose,
    canInsertWithAccessibility: true,
    hasCaretBounds: true,
    hasFieldBounds: true
)
