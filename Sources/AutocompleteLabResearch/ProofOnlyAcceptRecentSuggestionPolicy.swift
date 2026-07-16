import AutocompleteLabCore
import Foundation

struct ProofOnlyAcceptRecentSuggestionPolicy: Equatable {
    static let recentSuggestionGraceEnvironmentKey =
        "AUTOCOMPLETE_LAB_PROOF_ONLY_ACCEPT_RECENT_SUGGESTION_GRACE_MS"
    static let defaultRecentSuggestionGraceMilliseconds = 5_000
    static let maximumRecentSuggestionGraceMilliseconds = 15_000

    struct RestoreInput: Equatable {
        let proofModeEnabled: Bool
        let hasVisibleSuggestion: Bool
        let suggestionBundleIdentifier: String?
        let currentProfileBundleIdentifier: String?
        let fieldClassification: AXFieldClassification?
        let ageMilliseconds: Int?
        let invalidatedByUserKeyDown: Bool
        let suggestionText: String
        let lastSnapshotMatchesShownText: Bool
    }

    enum RestoreDecision: Equatable {
        case allow
        case block(RestoreBlockReason)
    }

    enum RestoreBlockReason: String, Equatable {
        case alreadyVisible = "already-visible"
        case proofModeDisabled = "proof-mode-disabled"
        case wrongSuggestionApp = "wrong-suggestion-app"
        case wrongProfile = "wrong-profile"
        case wrongFieldClassification = "wrong-field-classification"
        case missingAge = "missing-age"
        case stale = "stale"
        case invalidatedByUserKeyDown = "invalidated-by-user-keydown"
        case focusedTextChanged = "focused-text-changed"
        case missingAcceptedText = "missing-accepted-text"
    }

    func decision(
        for input: RestoreInput,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> RestoreDecision {
        if input.hasVisibleSuggestion {
            return .block(.alreadyVisible)
        }
        guard input.proofModeEnabled else {
            return .block(.proofModeDisabled)
        }
        guard input.suggestionBundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier else {
            return .block(.wrongSuggestionApp)
        }
        guard input.currentProfileBundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier else {
            return .block(.wrongProfile)
        }
        guard input.fieldClassification == ClaudeCodeTerminalHostProofPolicy.proofFieldClassification else {
            return .block(.wrongFieldClassification)
        }
        guard let ageMilliseconds = input.ageMilliseconds else {
            return .block(.missingAge)
        }
        guard ageMilliseconds <= Self.recentSuggestionGraceMilliseconds(environment: environment) else {
            return .block(.stale)
        }
        guard !input.invalidatedByUserKeyDown else {
            return .block(.invalidatedByUserKeyDown)
        }
        guard input.lastSnapshotMatchesShownText else {
            return .block(.focusedTextChanged)
        }
        guard !CompletionSuggestion.nextWordAcceptanceText(in: input.suggestionText).isEmpty else {
            return .block(.missingAcceptedText)
        }

        return .allow
    }

    static func recentSuggestionGraceMilliseconds(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Int {
        guard let rawValue = environment[recentSuggestionGraceEnvironmentKey],
              let parsedValue = Int(rawValue) else {
            return defaultRecentSuggestionGraceMilliseconds
        }

        return min(
            maximumRecentSuggestionGraceMilliseconds,
            max(0, parsedValue)
        )
    }
}
