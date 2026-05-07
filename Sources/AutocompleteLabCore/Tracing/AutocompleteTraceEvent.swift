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
    case acceptedTextEdited
    case appPaused
    case appDisabled
    case renderModeChanged
    case caretGeometryFailed
}

public struct AutocompleteTraceEvent: Codable, Equatable, Sendable, Identifiable {
    public static let currentSchemaVersion = 2
    public static let currentPrivacyVersion = 1

    public let id: String
    public let schemaVersion: Int
    public let privacyVersion: Int
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

    private enum CodingKeys: String, CodingKey {
        case id
        case schemaVersion
        case privacyVersion
        case timestamp
        case sessionID
        case suggestionID
        case type
        case appBundleIdentifier
        case fieldIdentity
        case requestMode
        case triggerReason
        case textBeforeCursor
        case textAfterCursor
        case systemPrompt
        case userPrompt
        case rawOutput
        case cleanedVisibleText
        case displayedText
        case acceptedText
        case remainingVisibleText
        case latencyMilliseconds
        case outcome
        case reason
        case screenshotPath
        case metadata
    }

    public init(
        id: String = UUID().uuidString,
        schemaVersion: Int = AutocompleteTraceEvent.currentSchemaVersion,
        privacyVersion: Int = AutocompleteTraceEvent.currentPrivacyVersion,
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
        self.schemaVersion = schemaVersion
        self.privacyVersion = privacyVersion
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        privacyVersion = try container.decodeIfPresent(Int.self, forKey: .privacyVersion) ?? 0
        timestamp = try container.decode(String.self, forKey: .timestamp)
        sessionID = try container.decodeIfPresent(String.self, forKey: .sessionID) ?? ""
        suggestionID = try container.decodeIfPresent(String.self, forKey: .suggestionID) ?? ""
        type = try container.decode(AutocompleteTraceEventType.self, forKey: .type)
        appBundleIdentifier = try container.decodeIfPresent(String.self, forKey: .appBundleIdentifier) ?? ""
        fieldIdentity = try container.decodeIfPresent(String.self, forKey: .fieldIdentity) ?? ""
        requestMode = try container.decodeIfPresent(String.self, forKey: .requestMode) ?? ""
        triggerReason = try container.decodeIfPresent(String.self, forKey: .triggerReason) ?? ""
        textBeforeCursor = try container.decodeIfPresent(String.self, forKey: .textBeforeCursor) ?? ""
        textAfterCursor = try container.decodeIfPresent(String.self, forKey: .textAfterCursor) ?? ""
        systemPrompt = try container.decodeIfPresent(String.self, forKey: .systemPrompt) ?? ""
        userPrompt = try container.decodeIfPresent(String.self, forKey: .userPrompt) ?? ""
        rawOutput = try container.decodeIfPresent(String.self, forKey: .rawOutput) ?? ""
        cleanedVisibleText = try container.decodeIfPresent(String.self, forKey: .cleanedVisibleText) ?? ""
        displayedText = try container.decodeIfPresent(String.self, forKey: .displayedText) ?? ""
        acceptedText = try container.decodeIfPresent(String.self, forKey: .acceptedText) ?? ""
        remainingVisibleText = try container.decodeIfPresent(String.self, forKey: .remainingVisibleText) ?? ""
        latencyMilliseconds = try container.decodeIfPresent(Int.self, forKey: .latencyMilliseconds)
        outcome = try container.decodeIfPresent(String.self, forKey: .outcome) ?? ""
        reason = try container.decodeIfPresent(String.self, forKey: .reason) ?? ""
        screenshotPath = try container.decodeIfPresent(String.self, forKey: .screenshotPath) ?? ""
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(privacyVersion, forKey: .privacyVersion)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(suggestionID, forKey: .suggestionID)
        try container.encode(type, forKey: .type)
        try container.encode(appBundleIdentifier, forKey: .appBundleIdentifier)
        try container.encode(fieldIdentity, forKey: .fieldIdentity)
        try container.encode(requestMode, forKey: .requestMode)
        try container.encode(triggerReason, forKey: .triggerReason)
        try container.encode(textBeforeCursor, forKey: .textBeforeCursor)
        try container.encode(textAfterCursor, forKey: .textAfterCursor)
        try container.encode(systemPrompt, forKey: .systemPrompt)
        try container.encode(userPrompt, forKey: .userPrompt)
        try container.encode(rawOutput, forKey: .rawOutput)
        try container.encode(cleanedVisibleText, forKey: .cleanedVisibleText)
        try container.encode(displayedText, forKey: .displayedText)
        try container.encode(acceptedText, forKey: .acceptedText)
        try container.encode(remainingVisibleText, forKey: .remainingVisibleText)
        try container.encodeIfPresent(latencyMilliseconds, forKey: .latencyMilliseconds)
        try container.encode(outcome, forKey: .outcome)
        try container.encode(reason, forKey: .reason)
        try container.encode(screenshotPath, forKey: .screenshotPath)
        try container.encode(metadata, forKey: .metadata)
    }
}
