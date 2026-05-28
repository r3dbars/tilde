import Testing
import ApplicationServices
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

    @Test("Pure modifier key downs do not count as typing before Option Tab")
    func modifierOnlyKeyDownsDoNotCountAsTyping() {
        #expect(isModifierOnlyMacVirtualKeyCode(58))
        #expect(isModifierOnlyMacVirtualKeyCode(61))
        #expect(isModifierOnlyMacVirtualKeyCode(55))
        #expect(!isModifierOnlyMacVirtualKeyCode(48))
        #expect(!isModifierOnlyMacVirtualKeyCode(6))
    }

    @Test("Stale passthrough observations only block genuinely invalidated suggestions")
    func stalePassthroughObservationsOnlyBlockInvalidatedSuggestions() {
        #expect(!shouldPassThroughAutocompleteKeyAfterPassthroughObservation(
            snapshot: KeyboardEventTapSnapshot(
                hasVisibleSuggestion: true,
                supportsOneWordAcceptance: true,
                supportsFullAcceptance: true,
                isInvalidatedByUserTyping: false,
                acceptAllShortcut: .optionTab
            )
        ))

        #expect(shouldPassThroughAutocompleteKeyAfterPassthroughObservation(
            snapshot: KeyboardEventTapSnapshot(
                hasVisibleSuggestion: true,
                supportsOneWordAcceptance: true,
                supportsFullAcceptance: true,
                isInvalidatedByUserTyping: true,
                acceptAllShortcut: .optionTab
            )
        ))

        #expect(!shouldPassThroughAutocompleteKeyAfterPassthroughObservation(
            snapshot: KeyboardEventTapSnapshot(
                hasVisibleSuggestion: true,
                supportsOneWordAcceptance: true,
                supportsFullAcceptance: true,
                isInvalidatedByUserTyping: true,
                allowsAutocompleteKeyAfterPassthroughObservation: true,
                acceptAllShortcut: .optionTab
            )
        ))

        #expect(!shouldPassThroughAutocompleteKeyAfterPassthroughObservation(
            snapshot: KeyboardEventTapSnapshot(
                hasVisibleSuggestion: true,
                supportsOneWordAcceptance: true,
                supportsFullAcceptance: true,
                isInvalidatedByUserTyping: true,
                acceptAllShortcut: .optionTab
            ),
            passthroughObservationAllowsAutocompleteKey: true
        ))
    }

    @Test("Shortcut chords do not count as text typing passthrough")
    func shortcutChordsDoNotCountAsTextTypingPassthrough() {
        #expect(!shouldTreatOtherKeyAsTypingPassthrough(
            physicalKey: .tab,
            modifiers: [.option]
        ))
        #expect(!shouldTreatOtherKeyAsTypingPassthrough(
            physicalKey: .tab,
            modifiers: [.option, .function]
        ))
        #expect(!shouldTreatOtherKeyAsTypingPassthrough(
            physicalKey: .tab,
            modifiers: [.option, .shift]
        ))
        #expect(!shouldTreatOtherKeyAsTypingPassthrough(
            physicalKey: .z,
            modifiers: [.command, .shift]
        ))
        #expect(shouldTreatOtherKeyAsTypingPassthrough(
            physicalKey: .other,
            modifiers: []
        ))
        #expect(shouldTreatOtherKeyAsTypingPassthrough(
            physicalKey: .other,
            modifiers: [.shift]
        ))
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

    @Test("Control Backtick can route suggest now while the key tap is active")
    func controlBacktickCanRouteSuggestNowWhileKeyTapIsActive() {
        let physicalKey = autocompletePhysicalKey(forMacVirtualKeyCode: 50)
        let mappedKey = AutocompleteKeyMapper().key(
            physicalKey: physicalKey,
            modifiers: [.control]
        )

        let action = KeyboardActionRouter().action(
            for: mappedKey,
            hasVisibleSuggestion: true
        )

        #expect(mappedKey == .controlBacktick)
        #expect(action == .requestSuggestionNow)
    }

    @Test("Event tap diagnostics include source and target process ids")
    func eventTapDiagnosticsIncludeProcessIDs() throws {
        let event = try #require(CGEvent(
            keyboardEventSource: nil,
            virtualKey: 48,
            keyDown: true
        ))
        event.setIntegerValueField(.eventSourceUnixProcessID, value: 1234)
        event.setIntegerValueField(.eventTargetUnixProcessID, value: 5678)

        let metadata = keyboardEventTapDiagnosticMetadata(event: event)

        #expect(metadata["eventSourcePID"] == "1234")
        #expect(metadata["eventTargetPID"] == "5678")
    }
}
