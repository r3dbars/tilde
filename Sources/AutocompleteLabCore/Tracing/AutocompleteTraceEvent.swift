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
}

