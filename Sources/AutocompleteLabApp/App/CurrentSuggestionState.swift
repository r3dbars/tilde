import AppKit
import AutocompleteLabCore

/// Cohesive container for the live "current suggestion" state owned by
/// `AppDelegate`.
///
/// These fields together describe the suggestion that is currently presented
/// (or was most recently presented) to the user: its identity, the target app
/// and field it belongs to, the request that produced it, the text baseline it
/// was computed against, and presentation bookkeeping used by the acceptance,
/// visibility, and suppression stages.
///
/// This type is a pure value type that only gathers the previously scattered
/// `currentSuggestion*` stored properties behind a single seam. It intentionally
/// holds no behavior: when a suggestion is set, cleared, advanced, or read is
/// still decided entirely by `AppDelegate` and the core policies it drives, so
/// moving these fields here is behavior-neutral. The seam is the prerequisite
/// for later extracting the request-lifecycle and display/suppression stages.
struct CurrentSuggestionState {
    var id: String?
    var appBundleIdentifier: String?
    var fieldIdentity: FocusedFieldIdentity?
    var requestMode: CompletionRequestMode?
    var textBeforeCursor: String?
    var acceptanceSnapshot: SuggestionAcceptanceSnapshot?
    var displayedText: String?
    var fieldClassification: AXFieldClassification?
    var presentedAt: Date?
    var displayScoreFinal: Double?
    var invalidatedByUserKeyDown = false
}
