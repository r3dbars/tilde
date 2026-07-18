import Testing
@testable import AutocompleteLabApp

@Suite("Menu bar status item")
@MainActor
struct MenuBarStatusItemTests {
    @Test("Uses a template-friendly symbol with text fallback")
    func usesTemplateFriendlySymbolWithTextFallback() {
        let configuration = MenuBarStatusItemConfiguration.autocompleteLab

        #expect(configuration.symbolName == "text.cursor")
        #expect(configuration.fallbackTitle == "SteadyType")
        #expect(configuration.accessibilityLabel == "SteadyType")
    }

    @Test("Suggestion summon shortcut is separate from Tab")
    func suggestionSummonShortcutIsSeparateFromTab() {
        let descriptor = SuggestionSummonHotKeyDescriptor.controlBacktick

        #expect(descriptor.displayName == "Control-Backtick")
        #expect(descriptor.diagnosticName == "control-backtick")
        #expect(descriptor.keyCode != 48)
    }

    @Test("Native summon hotkey owns its descriptor and lifecycle")
    func nativeSuggestionSummonHotKeyOwnsLifecycle() {
        let hotKey = SuggestionSummonHotKey {
        }

        #expect(hotKey.descriptor == .controlBacktick)
        hotKey.stop()
    }
}
