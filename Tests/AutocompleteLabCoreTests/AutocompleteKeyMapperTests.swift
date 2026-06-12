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
        #expect(mapper.key(physicalKey: .tab, modifiers: [.option, .function]) == .optionTab)
        #expect(mapper.key(physicalKey: .tab, modifiers: [.option, .control]) == .other)
        #expect(AcceptAllShortcut.optionTab.autocompleteKey == .optionTab)
    }

    @Test("Shift Tab is recognized as the default full accept shortcut")
    func shiftTabMapsToShiftTab() {
        let mapper = AutocompleteKeyMapper()

        #expect(mapper.key(physicalKey: .tab, modifiers: [.shift]) == .shiftTab)
        #expect(mapper.key(physicalKey: .tab, modifiers: [.shift, .function]) == .shiftTab)
        #expect(mapper.key(physicalKey: .tab, modifiers: [.shift, .control]) == .other)
        #expect(AcceptAllShortcut.shiftTab.autocompleteKey == .shiftTab)
    }

    @Test("System Tab shortcuts pass through")
    func systemTabShortcutsPassThrough() {
        let mapper = AutocompleteKeyMapper()

        #expect(mapper.key(physicalKey: .tab, modifiers: [.command]) == .other)
        #expect(mapper.key(physicalKey: .tab, modifiers: [.control]) == .other)
        #expect(mapper.key(physicalKey: .tab, modifiers: [.option, .shift]) == .other)
    }

    @Test("Backtick and tilde remain printable passthrough keys")
    func backtickAndTildeMapToBacktick() {
        let mapper = AutocompleteKeyMapper()

        #expect(mapper.key(physicalKey: .backtick, modifiers: []) == .backtick)
        #expect(mapper.key(physicalKey: .backtick, modifiers: [.shift]) == .backtick)
        #expect(mapper.key(physicalKey: .backtick, modifiers: [.function]) == .backtick)
        #expect(mapper.key(physicalKey: .backtick, modifiers: [.shift, .function]) == .backtick)
    }

    @Test("Window switching shortcuts pass through")
    func windowSwitchingShortcutsPassThrough() {
        let mapper = AutocompleteKeyMapper()

        #expect(mapper.key(physicalKey: .backtick, modifiers: [.command]) == .other)
        #expect(mapper.key(physicalKey: .backtick, modifiers: [.command, .shift]) == .other)
    }

    @Test("Control Backtick maps to suggest now")
    func controlBacktickMapsToSuggestNow() {
        let mapper = AutocompleteKeyMapper()

        #expect(mapper.key(physicalKey: .backtick, modifiers: [.control]) == .controlBacktick)
    }

    @Test("IME and dead-key modifier chords pass through")
    func imeAndDeadKeyModifierChordsPassThrough() {
        let mapper = AutocompleteKeyMapper()

        #expect(mapper.key(physicalKey: .backtick, modifiers: [.option]) == .other)
        #expect(mapper.key(physicalKey: .backtick, modifiers: [.option, .shift]) == .other)
        #expect(mapper.key(physicalKey: .z, modifiers: [.option]) == .other)
        #expect(mapper.key(physicalKey: .other, modifiers: [.option]) == .other)
        #expect(mapper.key(physicalKey: .other, modifiers: [.option, .shift]) == .other)
    }

    @Test("Command Z maps to accepted insertion undo")
    func commandZMapsToAcceptedInsertionUndo() {
        let mapper = AutocompleteKeyMapper()

        #expect(mapper.key(physicalKey: .z, modifiers: [.command]) == .commandZ)
        #expect(mapper.key(physicalKey: .z, modifiers: []) == .other)
        #expect(mapper.key(physicalKey: .z, modifiers: [.command, .shift]) == .other)
    }

    @Test("Only plain Escape dismisses")
    func onlyPlainEscapeDismisses() {
        let mapper = AutocompleteKeyMapper()

        #expect(mapper.key(physicalKey: .escape, modifiers: []) == .escape)
        #expect(mapper.key(physicalKey: .escape, modifiers: [.command]) == .other)
    }

    @Test("Shortcut configuration falls back to Shift Tab")
    func shortcutConfigurationFallsBackToShiftTab() {
        #expect(KeyboardShortcutConfiguration.default.acceptAllShortcut == .shiftTab)
        #expect(KeyboardShortcutConfiguration(persistedAcceptAllShortcutRawValue: "shiftTab").acceptAllShortcut == .shiftTab)
        #expect(KeyboardShortcutConfiguration(persistedAcceptAllShortcutRawValue: "optionTab").acceptAllShortcut == .optionTab)
        #expect(KeyboardShortcutConfiguration(persistedAcceptAllShortcutRawValue: "disabled").acceptAllShortcut == .disabled)
        #expect(KeyboardShortcutConfiguration(persistedAcceptAllShortcutRawValue: "backtick").acceptAllShortcut == .shiftTab)
        #expect(KeyboardShortcutConfiguration(persistedAcceptAllShortcutRawValue: "unknown").acceptAllShortcut == .shiftTab)
        #expect(AcceptAllShortcut.disabled.autocompleteKey == .other)
        #expect(AcceptAllShortcut.shiftTab.next == .optionTab)
        #expect(AcceptAllShortcut.optionTab.next == .disabled)
        #expect(AcceptAllShortcut.disabled.next == .shiftTab)
    }

    @Test("Shortcut conflict policy reflects per-app full accept profiles")
    func shortcutConflictPolicyReflectsPerAppFullAcceptProfiles() {
        let policy = KeyboardShortcutConflictPolicy()
        let textEdit = KeyboardShortcutConflictContext(
            appDisplayName: "TextEdit",
            isAppEnabled: true,
            canPresentSuggestions: true,
            supportsFullAcceptance: true
        )
        let codex = KeyboardShortcutConflictContext(
            appDisplayName: "Codex",
            isAppEnabled: true,
            canPresentSuggestions: true,
            supportsFullAcceptance: true
        )

        let safe = policy.evaluation(acceptAllShortcut: .shiftTab, context: textEdit)
        #expect(safe.level == .none)
        #expect(safe.statusText == "Conflict check: no known conflict in TextEdit")
        #expect(safe.perAppProfileText == "Per-app profile: TextEdit allows Tab one-word accept and whole-suggestion accept.")

        let codexAllowed = policy.evaluation(acceptAllShortcut: .shiftTab, context: codex)
        #expect(codexAllowed.level == .none)
        #expect(codexAllowed.statusText == "Conflict check: no known conflict in Codex")
        #expect(codexAllowed.perAppProfileText == "Per-app profile: Codex allows Tab one-word accept and whole-suggestion accept.")

        let warning = policy.evaluation(acceptAllShortcut: .optionTab, context: textEdit)
        #expect(warning.level == .warning)
        #expect(warning.statusText == "Conflict check: Option-Tab may overlap app shortcuts")
    }
}
