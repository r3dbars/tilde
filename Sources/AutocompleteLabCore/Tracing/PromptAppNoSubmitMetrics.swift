import Foundation

public struct PromptAppNoSubmitMetrics: Equatable, Sendable {
    public let accidentalSubmitCount: Int
    public let sendKeyCollisionCount: Int
    public let promptMutationWithoutUserIntentCount: Int
    public let wrongContextInsertionCount: Int
    public let suggestionContentViolationCount: Int

    public init(
        accidentalSubmitCount: Int = 0,
        sendKeyCollisionCount: Int = 0,
        promptMutationWithoutUserIntentCount: Int = 0,
        wrongContextInsertionCount: Int = 0,
        suggestionContentViolationCount: Int = 0
    ) {
        self.accidentalSubmitCount = accidentalSubmitCount
        self.sendKeyCollisionCount = sendKeyCollisionCount
        self.promptMutationWithoutUserIntentCount = promptMutationWithoutUserIntentCount
        self.wrongContextInsertionCount = wrongContextInsertionCount
        self.suggestionContentViolationCount = suggestionContentViolationCount
    }

    public var passesReleaseGate: Bool {
        accidentalSubmitCount == 0
            && sendKeyCollisionCount == 0
            && promptMutationWithoutUserIntentCount == 0
            && wrongContextInsertionCount == 0
            && suggestionContentViolationCount == 0
    }
}

public struct PromptAppNoSubmitMetricsAnalyzer: Equatable, Sendable {
    public let promptAppBundleIdentifiers: Set<String>

    public init(
        promptAppBundleIdentifiers: Set<String> = Self.defaultPromptAppBundleIdentifiers
    ) {
        self.promptAppBundleIdentifiers = promptAppBundleIdentifiers
    }

    public func metrics(from events: [AutocompleteTraceEvent]) -> PromptAppNoSubmitMetrics {
        let promptEvents = events.filter(isPromptEvent)

        return PromptAppNoSubmitMetrics(
            accidentalSubmitCount: promptEvents.filter(isAccidentalSubmit).count,
            sendKeyCollisionCount: promptEvents.filter(isSendKeyCollision).count,
            promptMutationWithoutUserIntentCount: promptEvents.filter(isPromptMutationWithoutUserIntent).count,
            wrongContextInsertionCount: promptEvents.filter(isWrongContextInsertion).count,
            suggestionContentViolationCount: promptEvents.filter(isSuggestionContentViolation).count
        )
    }

    private func isPromptEvent(_ event: AutocompleteTraceEvent) -> Bool {
        promptAppBundleIdentifiers.contains(event.appBundleIdentifier)
            || event.metadata["promptSafetyMode"] != nil
            || event.metadata["behaviorProfile"] == AutocompleteBehaviorProfileID.aiChat.rawValue
    }

    private func isAccidentalSubmit(_ event: AutocompleteTraceEvent) -> Bool {
        event.metadata["accidentalSubmit"] == "true"
            || event.metadata["checkpoint"] == "fieldSend"
            || event.reason.contains("field-send")
            || event.outcome.contains("field-send")
            || event.reason.contains("accidental-submit")
    }

    private func isSendKeyCollision(_ event: AutocompleteTraceEvent) -> Bool {
        event.metadata["sendKeyCollision"] == "true"
            || event.metadata["keyCollision"] == "true"
            || event.reason.contains("send-key-collision")
            || event.reason.contains("tab-conflict")
            || event.outcome.contains("send-key-collision")
    }

    private func isPromptMutationWithoutUserIntent(_ event: AutocompleteTraceEvent) -> Bool {
        event.metadata["promptMutationWithoutUserIntent"] == "true"
            || event.reason.contains("prompt-mutation")
            || event.reason.contains("mutation-outside-accepted-span")
    }

    private func isWrongContextInsertion(_ event: AutocompleteTraceEvent) -> Bool {
        event.reason == "wrong-app-or-field-before-accept"
            || event.reason.contains("wrong-context")
            || event.metadata["acceptanceGuardReason"] != nil
    }

    private func isSuggestionContentViolation(_ event: AutocompleteTraceEvent) -> Bool {
        event.metadata["contentPolicyViolation"] == "true"
            || event.reason.contains("suggestion-content-violation")
            || event.reason.contains("accepted-text-prompt-")
    }

    public static let defaultPromptAppBundleIdentifiers: Set<String> = [
        "com.openai.codex",
        "com.anthropic.claude-code",
        "com.anthropic.claudefordesktop",
        "com.openai.chat",
        "com.openai.ChatGPT",
        "com.openai.atlas",
        "com.tinyspeck.slackmacgap",
        "ru.keepcoder.Telegram"
    ]
}
