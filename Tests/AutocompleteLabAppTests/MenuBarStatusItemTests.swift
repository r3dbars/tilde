import Testing
@testable import AutocompleteLabApp

@Suite("Menu bar status item")
struct MenuBarStatusItemTests {
    @Test("Uses a template-friendly symbol with text fallback")
    func usesTemplateFriendlySymbolWithTextFallback() {
        let configuration = MenuBarStatusItemConfiguration.autocompleteLab

        #expect(configuration.symbolName == "text.cursor")
        #expect(configuration.fallbackTitle == "Tilde")
        #expect(configuration.accessibilityLabel == "Tilde")
    }

    @Test("Suggestion summon shortcut is separate from Tab")
    func suggestionSummonShortcutIsSeparateFromTab() {
        let descriptor = SuggestionSummonHotKeyDescriptor.controlBacktick

        #expect(descriptor.displayName == "Control-Backtick")
        #expect(descriptor.diagnosticName == "control-backtick")
        #expect(descriptor.keyCode != 48)
    }
}
