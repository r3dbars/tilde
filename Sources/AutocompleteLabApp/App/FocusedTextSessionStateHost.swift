import Foundation
import AutocompleteLabCore

/// Owns mutable focused-text and per-app session state used by the suggestion pipeline.
@MainActor
final class FocusedTextSessionStateHost {
    var currentFieldIdentity: FocusedFieldIdentity?
    var currentProfile: CompatibilityProfile?
    var lastTextSnapshot: FocusedTextSnapshot?
    var lastTrustedObsidianEndOfDocumentSnapshot: FocusedTextSnapshot?
    var lastFocusedTextChangeAt: Date?
    var lastRequestedTextBeforeCursor: String?
}
