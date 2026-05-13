import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Command context panel state")
struct CommandContextPanelStateTests {
    @Test("Unsupported apps require selected-text copy fallback")
    func unsupportedAppsRequireSelectedTextCopyFallback() {
        let state = CommandContextPanelState(
            appDisplayName: "Unknown",
            bundleIdentifier: "com.example.UnknownEditor",
            supportStatus: .unsupported,
            isAppEnabled: false,
            runtimeReport: readyRuntime,
            context: editableContext,
            suggestionText: " next step",
            isLoading: false,
            statusMessage: ""
        )

        #expect(state.pathText == "Path: selected-text copy fallback only; inline stays off")
        #expect(state.contextText.contains("current field, 24 chars before cursor"))
        #expect(!state.canRequestSuggestion)
        #expect(state.canCopySuggestion)
        #expect(
            state.privacyText
                == "Privacy: unsupported apps require selected text, use the local model, and copy only when you press Copy."
        )
        #expect(state.normalTypingText == "Normal typing: untouched; this opens only from the menu or Settings.")
        #expect(
            state.requestUnavailableReason
                == "Select text first; unsupported apps do not read the whole field."
        )
        #expect(
            state.statusText
                == "Not ready: Select text first; unsupported apps do not read the whole field."
        )
    }

    @Test("Unsupported apps can suggest from selected text")
    func unsupportedAppsCanSuggestFromSelectedText() {
        let state = CommandContextPanelState(
            appDisplayName: "Unknown",
            bundleIdentifier: "com.example.UnknownEditor",
            supportStatus: .unsupported,
            isAppEnabled: false,
            runtimeReport: readyRuntime,
            context: selectedContext,
            suggestionText: " next step",
            isLoading: false,
            statusMessage: ""
        )

        #expect(state.canRequestSuggestion)
        #expect(state.contextText.contains("selected text, 18 chars"))
        #expect(state.statusText == "Ready: press Suggest. Copy writes to clipboard only.")
    }

    @Test("Sensitive diagnostics-only apps cannot request context suggestions")
    func sensitiveDiagnosticsOnlyAppsCannotRequestContextSuggestions() {
        let state = CommandContextPanelState(
            appDisplayName: "Atlas",
            bundleIdentifier: "com.openai.atlas",
            supportStatus: CompatibilityProfileStore.mvp.supportStatus(for: "com.openai.atlas"),
            isAppEnabled: false,
            runtimeReport: readyRuntime,
            context: nil,
            suggestionText: nil,
            isLoading: false,
            statusMessage: ""
        )

        #expect(state.appText == "App: Atlas | Diagnostics-only: ChatGPT Atlas")
        #expect(state.pathText == "Path: off for sensitive app")
        #expect(!state.canRequestSuggestion)
        #expect(!state.canCopySuggestion)
        #expect(state.requestUnavailableReason == "Sensitive apps stay off here.")
        #expect(state.statusText == "Not ready: Sensitive apps stay off here.")
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
                action: .installModel
            ),
            context: editableContext,
            suggestionText: nil,
            isLoading: false,
            statusMessage: ""
        )

        #expect(!missingModel.canRequestSuggestion)
        #expect(missingModel.requestUnavailableReason == "Local model needs setup: download needed.")
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

private let selectedContext = CommandContextSnapshot(
    textBeforeCursorLength: 24,
    textAfterCursorLength: 0,
    selectedTextLength: 18,
    isSecure: false,
    fieldKind: .multilineCompose,
    canInsertWithAccessibility: true,
    hasCaretBounds: true,
    hasFieldBounds: true
)
