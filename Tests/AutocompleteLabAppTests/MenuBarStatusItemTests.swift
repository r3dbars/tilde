import Testing
@testable import AutocompleteLabApp

@Suite("Menu bar status item")
struct MenuBarStatusItemTests {
    @Test("Uses a template-friendly symbol with text fallback")
    func usesTemplateFriendlySymbolWithTextFallback() {
        let configuration = MenuBarStatusItemConfiguration.autocompleteLab

        #expect(configuration.symbolName == "text.cursor")
        #expect(configuration.fallbackTitle == "Autocomplete")
        #expect(configuration.accessibilityLabel == "Autocomplete Lab")
    }
}
