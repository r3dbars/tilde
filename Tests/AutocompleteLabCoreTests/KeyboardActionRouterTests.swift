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

    @Test("Option Tab can accept all visible text when selected")
    func optionTabCanAcceptAllVisibleTextWhenSelected() {
        let router = KeyboardActionRouter(
            shortcutConfiguration: KeyboardShortcutConfiguration(acceptAllShortcut: .optionTab)
        )

        #expect(router.action(for: .optionTab, hasVisibleSuggestion: true) == .acceptAllVisible)
        #expect(router.action(for: .backtick, hasVisibleSuggestion: true) == .passThrough)
    }

    @Test("Other keys pass through even when a suggestion is visible")
    func otherKeysPassThrough() {
        let router = KeyboardActionRouter()

        #expect(router.action(for: .other, hasVisibleSuggestion: true) == .passThrough)
    }

    @Test("Backtick accepts all visible text when a suggestion is visible")
    func backtickAcceptsAllVisibleText() {
        let router = KeyboardActionRouter()

        #expect(router.action(for: .backtick, hasVisibleSuggestion: true) == .acceptAllVisible)
    }

    @Test("Full accept can be disabled")
    func fullAcceptCanBeDisabled() {
        let router = KeyboardActionRouter(
            shortcutConfiguration: KeyboardShortcutConfiguration(acceptAllShortcut: .disabled)
        )

        #expect(router.action(for: .tab, hasVisibleSuggestion: true) == .acceptNextWord)
        #expect(router.action(for: .backtick, hasVisibleSuggestion: true) == .passThrough)
        #expect(router.action(for: .optionTab, hasVisibleSuggestion: true) == .passThrough)
    }

    @Test("Escape dismisses only when a suggestion is visible")
    func escapeDismissesOnlyWhenSuggestionIsVisible() {
        let router = KeyboardActionRouter()

        #expect(router.action(for: .escape, hasVisibleSuggestion: true) == .dismiss)
        #expect(router.action(for: .escape, hasVisibleSuggestion: false) == .passThrough)
    }

    @Test("Keyboard diagnostics use stable names")
    func keyboardDiagnosticsUseStableNames() {
        #expect(AutocompleteKey.tab.diagnosticName == "tab")
        #expect(AutocompleteKey.backtick.diagnosticName == "backtick")
        #expect(AutocompleteKey.commandZ.diagnosticName == "commandZ")
        #expect(KeyboardAction.acceptNextWord.diagnosticName == "acceptNextWord")
        #expect(KeyboardAction.acceptAllVisible.diagnosticName == "acceptAllVisible")
        #expect(KeyboardAction.undoAcceptedInsertion.diagnosticName == "undoAcceptedInsertion")
    }

    @Test("Keys pass through when no suggestion is visible")
    func keysPassThroughWithoutVisibleSuggestion() {
        let router = KeyboardActionRouter()

        #expect(router.action(for: .tab, hasVisibleSuggestion: false) == .passThrough)
        #expect(router.action(for: .optionTab, hasVisibleSuggestion: false) == .passThrough)
        #expect(router.action(for: .backtick, hasVisibleSuggestion: false) == .passThrough)
        #expect(router.action(for: .escape, hasVisibleSuggestion: false) == .passThrough)
        #expect(router.action(for: .commandZ, hasVisibleSuggestion: false) == .passThrough)
    }

    @Test("Command Z undoes a pending accepted insertion")
    func commandZUndoesPendingAcceptedInsertion() {
        let router = KeyboardActionRouter()

        #expect(router.action(
            for: .commandZ,
            hasVisibleSuggestion: false,
            hasPendingAcceptedInsertionUndo: true
        ) == .undoAcceptedInsertion)
        #expect(router.action(
            for: .commandZ,
            hasVisibleSuggestion: true,
            hasPendingAcceptedInsertionUndo: true
        ) == .undoAcceptedInsertion)
    }
}
