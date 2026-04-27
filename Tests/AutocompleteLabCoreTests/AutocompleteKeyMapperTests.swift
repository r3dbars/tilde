import Testing
@testable import AutocompleteLabCore

@Suite("Autocomplete key mapper")
struct AutocompleteKeyMapperTests {
    @Test("Plain Tab maps to autocomplete Tab")
    func plainTabMapsToTab() {
        let mapper = AutocompleteKeyMapper()

        #expect(mapper.key(physicalKey: .tab, modifiers: []) == .tab)
    }

    @Test("Option Tab is recognized but routed separately")
    func optionTabMapsToOptionTab() {
        let mapper = AutocompleteKeyMapper()

        #expect(mapper.key(physicalKey: .tab, modifiers: [.option]) == .optionTab)
    }

    @Test("System Tab shortcuts pass through")
    func systemTabShortcutsPassThrough() {
        let mapper = AutocompleteKeyMapper()

        #expect(mapper.key(physicalKey: .tab, modifiers: [.command]) == .other)
        #expect(mapper.key(physicalKey: .tab, modifiers: [.control]) == .other)
        #expect(mapper.key(physicalKey: .tab, modifiers: [.shift]) == .other)
        #expect(mapper.key(physicalKey: .tab, modifiers: [.option, .shift]) == .other)
    }

    @Test("Backtick and tilde accept all visible text")
    func backtickAndTildeMapToBacktick() {
        let mapper = AutocompleteKeyMapper()

        #expect(mapper.key(physicalKey: .backtick, modifiers: []) == .backtick)
        #expect(mapper.key(physicalKey: .backtick, modifiers: [.shift]) == .backtick)
    }

    @Test("Window switching shortcuts pass through")
    func windowSwitchingShortcutsPassThrough() {
        let mapper = AutocompleteKeyMapper()

        #expect(mapper.key(physicalKey: .backtick, modifiers: [.command]) == .other)
        #expect(mapper.key(physicalKey: .backtick, modifiers: [.command, .shift]) == .other)
    }

    @Test("Only plain Escape dismisses")
    func onlyPlainEscapeDismisses() {
        let mapper = AutocompleteKeyMapper()

        #expect(mapper.key(physicalKey: .escape, modifiers: []) == .escape)
        #expect(mapper.key(physicalKey: .escape, modifiers: [.command]) == .other)
    }
}
