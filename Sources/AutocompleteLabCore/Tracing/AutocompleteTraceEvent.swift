import Foundation

public enum AutocompleteTraceEventType: String, Codable, Equatable, Sendable {
    case suggestionRequested
    case modelResult
    case suggestionPresented
    case suggestionHidden
    case suggestionAccepted
    case suggestionTypedOver
    case suggestionSuppressed
    case insertionVerified
    case insertionFailed
}

public enum AutocompleteTracePrivacyMode: String, Codable, CaseIterable, Equatable, Sendable {
    case lab
    case dogfood
    case beta
    case customer

    public var allowsRawTextPersistence: Bool {
        switch self {
        case .lab, .dogfood:
            true
        case .beta, .customer:
            false
        }
    }

    public var allowsScreenshotTracing: Bool {
        switch self {
        case .lab, .dogfood:
            true
        case .beta, .customer:
            false
        }
    }
}

public struct AutocompleteTraceEvent: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let timestamp: String
    public let sessionID: String
    public let suggestionID: String
    public let type: AutocompleteTraceEventType
    public let appBundleIdentifier: String
    public let fieldIdentity: String
    public let requestMode: String
    public let triggerReason: String
    public let textBeforeCursor: String
    public let textAfterCursor: String
    public let systemPrompt: String
    public let userPrompt: String
    public let rawOutput: String
    public let cleanedVisibleText: String
    public let displayedText: String
    public let acceptedText: String
    public let remainingVisibleText: String
    public let latencyMilliseconds: Int?
    public let outcome: String
    public let reason: String
    public let screenshotPath: String
    public let metadata: [String: String]

    public init(
        id: String = UUID().uuidString,
        timestamp: String,
        sessionID: String,
        suggestionID: String,
        type: AutocompleteTraceEventType,
        appBundleIdentifier: String = "",
        fieldIdentity: String = "",
        requestMode: String = "",
        triggerReason: String = "",
        textBeforeCursor: String = "",
        textAfterCursor: String = "",
        systemPrompt: String = "",
        userPrompt: String = "",
        rawOutput: String = "",
        cleanedVisibleText: String = "",
        displayedText: String = "",
        acceptedText: String = "",
        remainingVisibleText: String = "",
        latencyMilliseconds: Int? = nil,
        outcome: String = "",
        reason: String = "",
        screenshotPath: String = "",
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionID = sessionID
        self.suggestionID = suggestionID
        self.type = type
        self.appBundleIdentifier = appBundleIdentifier
        self.fieldIdentity = fieldIdentity
        self.requestMode = requestMode
        self.triggerReason = triggerReason
        self.textBeforeCursor = textBeforeCursor
        self.textAfterCursor = textAfterCursor
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.rawOutput = rawOutput
        self.cleanedVisibleText = cleanedVisibleText
        self.displayedText = displayedText
        self.acceptedText = acceptedText
        self.remainingVisibleText = remainingVisibleText
        self.latencyMilliseconds = latencyMilliseconds
        self.outcome = outcome
        self.reason = reason
        self.screenshotPath = screenshotPath
        self.metadata = metadata
    }

    public func redacted(
        privacyMode: AutocompleteTracePrivacyMode
    ) -> RedactedAutocompleteTraceEvent {
        RedactedAutocompleteTraceEvent(event: self, privacyMode: privacyMode)
    }
}

public struct RedactedAutocompleteTraceEvent: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let timestamp: String
    public let sessionID: String
    public let suggestionID: String
    public let type: AutocompleteTraceEventType
    public let privacyMode: AutocompleteTracePrivacyMode
    public let appBundleIdentifier: String
    public let fieldIdentity: String
    public let requestMode: String
    public let triggerReason: String
    public let textBeforeCursorCharacterCount: Int
    public let textAfterCursorCharacterCount: Int
    public let systemPromptCharacterCount: Int
    public let userPromptCharacterCount: Int
    public let rawOutputCharacterCount: Int
    public let cleanedVisibleTextCharacterCount: Int
    public let displayedTextCharacterCount: Int
    public let acceptedTextCharacterCount: Int
    public let remainingVisibleTextCharacterCount: Int
    public let latencyMilliseconds: Int?
    public let outcome: String
    public let reason: String
    public let hasScreenshot: Bool
    public let metadata: [String: String]

    public init(
        id: String,
        timestamp: String,
        sessionID: String,
        suggestionID: String,
        type: AutocompleteTraceEventType,
        privacyMode: AutocompleteTracePrivacyMode,
        appBundleIdentifier: String,
        fieldIdentity: String,
        requestMode: String,
        triggerReason: String,
        textBeforeCursorCharacterCount: Int,
        textAfterCursorCharacterCount: Int,
        systemPromptCharacterCount: Int,
        userPromptCharacterCount: Int,
        rawOutputCharacterCount: Int,
        cleanedVisibleTextCharacterCount: Int,
        displayedTextCharacterCount: Int,
        acceptedTextCharacterCount: Int,
        remainingVisibleTextCharacterCount: Int,
        latencyMilliseconds: Int?,
        outcome: String,
        reason: String,
        hasScreenshot: Bool,
        metadata: [String: String]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionID = sessionID
        self.suggestionID = suggestionID
        self.type = type
        self.privacyMode = privacyMode
        self.appBundleIdentifier = appBundleIdentifier
        self.fieldIdentity = fieldIdentity
        self.requestMode = requestMode
        self.triggerReason = triggerReason
        self.textBeforeCursorCharacterCount = textBeforeCursorCharacterCount
        self.textAfterCursorCharacterCount = textAfterCursorCharacterCount
        self.systemPromptCharacterCount = systemPromptCharacterCount
        self.userPromptCharacterCount = userPromptCharacterCount
        self.rawOutputCharacterCount = rawOutputCharacterCount
        self.cleanedVisibleTextCharacterCount = cleanedVisibleTextCharacterCount
        self.displayedTextCharacterCount = displayedTextCharacterCount
        self.acceptedTextCharacterCount = acceptedTextCharacterCount
        self.remainingVisibleTextCharacterCount = remainingVisibleTextCharacterCount
        self.latencyMilliseconds = latencyMilliseconds
        self.outcome = outcome
        self.reason = reason
        self.hasScreenshot = hasScreenshot
        self.metadata = metadata
    }

    public init(
        event: AutocompleteTraceEvent,
        privacyMode: AutocompleteTracePrivacyMode
    ) {
        self.init(
            id: event.id,
            timestamp: event.timestamp,
            sessionID: event.sessionID,
            suggestionID: event.suggestionID,
            type: event.type,
            privacyMode: privacyMode,
            appBundleIdentifier: event.appBundleIdentifier,
            fieldIdentity: event.fieldIdentity,
            requestMode: event.requestMode,
            triggerReason: event.triggerReason,
            textBeforeCursorCharacterCount: event.textBeforeCursor.count,
            textAfterCursorCharacterCount: event.textAfterCursor.count,
            systemPromptCharacterCount: event.systemPrompt.count,
            userPromptCharacterCount: event.userPrompt.count,
            rawOutputCharacterCount: event.rawOutput.count,
            cleanedVisibleTextCharacterCount: event.cleanedVisibleText.count,
            displayedTextCharacterCount: event.displayedText.count,
            acceptedTextCharacterCount: event.acceptedText.count,
            remainingVisibleTextCharacterCount: event.remainingVisibleText.count,
            latencyMilliseconds: event.latencyMilliseconds,
            outcome: event.outcome,
            reason: event.reason,
            hasScreenshot: !event.screenshotPath.isEmpty,
            metadata: Dictionary(
                uniqueKeysWithValues: event.metadata.map { key, value in
                    (key, Self.redactedMetadataValue(forKey: key, value: value))
                }
            )
        )
    }

    private static func redactedMetadataValue(forKey key: String, value: String) -> String {
        guard isTraceSafeMetadataKey(key) || DiagnosticsMetadataRedactor.isSensitiveKey(key) else {
            return DiagnosticValueRedactor.stringSummary(length: value.count)
        }

        return DiagnosticsMetadataRedactor.logSafeValue(forKey: key, value: value)
    }

    private static func isTraceSafeMetadataKey(_ key: String) -> Bool {
        let normalized = key.lowercased()

        return normalized == "role"
            || normalized.hasSuffix("role")
            || normalized.hasPrefix("has")
            || normalized.hasSuffix("chars")
            || normalized.hasSuffix("count")
            || normalized.hasSuffix("length")
            || normalized.hasSuffix("milliseconds")
            || normalized.contains("anchor")
            || normalized.contains("frame")
            || normalized.contains("geometry")
            || normalized.contains("level")
            || normalized.contains("mode")
            || normalized.contains("outcome")
            || normalized.contains("quality")
            || normalized.contains("reason")
            || normalized.contains("rect")
            || normalized.contains("screen")
            || normalized.contains("source")
    }
}
