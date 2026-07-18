@testable import AutocompleteLabApp
import AutocompleteLabCore
import Foundation
import Testing

@Suite("Focused text session state host")
@MainActor
struct FocusedTextSessionStateHostTests {
    @Test("keeps focused field snapshots and request cadence state together")
    func keepsFocusedFieldSnapshotsAndRequestCadenceStateTogether() {
        let host = FocusedTextSessionStateHost()
        let field = FocusedFieldIdentity(
            bundleIdentifier: "com.example.editor",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let snapshot = FocusedTextSnapshot(
            fieldIdentity: field,
            textBeforeCursor: "This is ",
            textAfterCursor: ""
        )
        let changeDate = Date(timeIntervalSince1970: 42)

        host.currentFieldIdentity = field
        host.lastTextSnapshot = snapshot
        host.personalCaptureLastSnapshot = snapshot
        host.lastFocusedTextChangeAt = changeDate
        host.lastRequestedTextBeforeCursor = "This is "

        #expect(host.currentFieldIdentity == field)
        #expect(host.lastTextSnapshot == snapshot)
        #expect(host.personalCaptureLastSnapshot == snapshot)
        #expect(host.lastFocusedTextChangeAt == changeDate)
        #expect(host.lastRequestedTextBeforeCursor == "This is ")
    }

    @Test("does not share focused-text state between host instances")
    func doesNotShareFocusedTextStateBetweenHostInstances() {
        let first = FocusedTextSessionStateHost()
        let second = FocusedTextSessionStateHost()
        first.lastRequestedTextBeforeCursor = "private local state"

        #expect(second.lastRequestedTextBeforeCursor == nil)
    }
}
