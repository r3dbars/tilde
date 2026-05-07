import Foundation

enum VisibleSuggestionOutcome: String, Equatable {
    case accepted
    case typedThrough = "typed-through"
    case typedOver = "typed-over"
    case ignored

    var recordsRepeatedMiss: Bool {
        self == .ignored
    }
}

struct VisibleSuggestionOutcomePolicy: Equatable {
    func outcome(forHideReason reason: String) -> VisibleSuggestionOutcome {
        if reason.hasPrefix("accepted") {
            return .accepted
        }

        if reason == "typed-through-visible-prefix" {
            return .typedThrough
        }

        if reason == "typed-over" {
            return .typedOver
        }

        return .ignored
    }
}
