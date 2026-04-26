import Testing
@testable import AutocompleteLabCore

@Suite("Keyboard action router")
struct KeyboardActionRouterTests {
    @Test("Tab accepts the next word when a suggestion is visible")
    func tabAcceptsNextWord() {
        let router = KeyboardActionRouter()

        #expect(router.action(for: .tab, hasVisibleSuggestion: true) == .acceptNextWord)
    }

    @Test("Option Tab passes through even when a suggestion is visible")
    func optionTabPassesThrough() {
        let router = KeyboardActionRouter()

        #expect(router.action(for: .optionTab, hasVisibleSuggestion: true) == .passThrough)
    }

    @Test("Backtick accepts all visible text when a suggestion is visible")
    func backtickAcceptsAllVisibleText() {
        let router = KeyboardActionRouter()

        #expect(router.action(for: .backtick, hasVisibleSuggestion: true) == .acceptAllVisible)
    }

    @Test("Keyboard diagnostics use stable names")
    func keyboardDiagnosticsUseStableNames() {
        #expect(AutocompleteKey.tab.diagnosticName == "tab")
        #expect(AutocompleteKey.backtick.diagnosticName == "backtick")
        #expect(KeyboardAction.acceptNextWord.diagnosticName == "acceptNextWord")
        #expect(KeyboardAction.acceptAllVisible.diagnosticName == "acceptAllVisible")
    }

    @Test("Keys pass through when no suggestion is visible")
    func keysPassThroughWithoutVisibleSuggestion() {
        let router = KeyboardActionRouter()

        #expect(router.action(for: .tab, hasVisibleSuggestion: false) == .passThrough)
        #expect(router.action(for: .optionTab, hasVisibleSuggestion: false) == .passThrough)
        #expect(router.action(for: .backtick, hasVisibleSuggestion: false) == .passThrough)
        #expect(router.action(for: .escape, hasVisibleSuggestion: false) == .passThrough)
    }
}
