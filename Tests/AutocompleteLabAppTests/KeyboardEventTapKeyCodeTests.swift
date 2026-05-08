import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Keyboard event tap key codes")
struct KeyboardEventTapKeyCodeTests {
    @Test("Mac virtual key codes map to autocomplete physical keys")
    func mapsMacVirtualKeyCodes() {
        #expect(autocompletePhysicalKey(forMacVirtualKeyCode: 6) == .z)
        #expect(autocompletePhysicalKey(forMacVirtualKeyCode: 48) == .tab)
        #expect(autocompletePhysicalKey(forMacVirtualKeyCode: 50) == .backtick)
        #expect(autocompletePhysicalKey(forMacVirtualKeyCode: 53) == .escape)
        #expect(autocompletePhysicalKey(forMacVirtualKeyCode: 999) == .other)
    }

    @Test("Command Z can reach accepted insertion undo routing")
    func commandZReachesUndoRouting() {
        let physicalKey = autocompletePhysicalKey(forMacVirtualKeyCode: 6)
        let mappedKey = AutocompleteKeyMapper().key(
            physicalKey: physicalKey,
            modifiers: [.command]
        )

        let action = KeyboardActionRouter().action(
            for: mappedKey,
            hasVisibleSuggestion: false,
            hasPendingAcceptedInsertionUndo: true
        )

        #expect(mappedKey == .commandZ)
        #expect(action == .undoAcceptedInsertion)
    }
}
