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
    case acceptedInsertionUndone
    case acceptedTextEdited
    case acceptanceRetentionCleared
    case appPaused
    case fieldPaused
    case appDisabled
    case renderModeChanged
    case caretGeometryFailed
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
    public static let currentSchemaVersion = 3
    public static let currentPrivacyVersion = 2

    public let id: String
    public let schemaVersion: Int
    public let privacyVersion: Int
    public let experimentArm: String
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
        case experimentArm
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
        experimentArm: String = AutocompleteExperimentArm.length3Word.rawValue,
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
        self.experimentArm = experimentArm
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
        experimentArm = try container.decodeIfPresent(String.self, forKey: .experimentArm)
            ?? AutocompleteExperimentArm.length3Word.rawValue
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
        try container.encode(experimentArm, forKey: .experimentArm)
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

    public func redactedForDefaultTrace() -> AutocompleteTraceEvent {
        var safeMetadata = metadata.reduce(into: [String: String]()) { result, item in
            result[item.key] = AutocompleteTracePrivacyFilter.metadataValue(
                forKey: item.key,
                value: item.value
            )
        }

        addLengthMetadata(value: textBeforeCursor, key: "textBeforeCursorChars", metadata: &safeMetadata)
        addLengthMetadata(value: textAfterCursor, key: "textAfterCursorChars", metadata: &safeMetadata)
        addLengthMetadata(value: systemPrompt, key: "systemPromptChars", metadata: &safeMetadata)
        addLengthMetadata(value: userPrompt, key: "userPromptChars", metadata: &safeMetadata)
        addLengthMetadata(value: rawOutput, key: "rawOutputChars", metadata: &safeMetadata)
        addLengthMetadata(value: cleanedVisibleText, key: "cleanedVisibleTextChars", metadata: &safeMetadata)
        addLengthMetadata(value: displayedText, key: "displayedTextChars", metadata: &safeMetadata)
        addLengthMetadata(value: acceptedText, key: "acceptedTextChars", metadata: &safeMetadata)
        addLengthMetadata(value: remainingVisibleText, key: "remainingVisibleTextChars", metadata: &safeMetadata)
        if !screenshotPath.isEmpty {
            safeMetadata["screenshotCaptured"] = "true"
        }

        return AutocompleteTraceEvent(
            id: id,
            schemaVersion: schemaVersion,
            privacyVersion: AutocompleteTraceEvent.currentPrivacyVersion,
            experimentArm: experimentArm,
            timestamp: timestamp,
            sessionID: sessionID,
            suggestionID: suggestionID,
            type: type,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentity,
            requestMode: requestMode,
            triggerReason: AutocompleteTracePrivacyFilter.traceSignalValue(
                triggerReason,
                rawContentEnabled: false
            ),
            latencyMilliseconds: latencyMilliseconds,
            outcome: AutocompleteTracePrivacyFilter.traceSignalValue(
                outcome,
                rawContentEnabled: false
            ),
            reason: AutocompleteTracePrivacyFilter.traceSignalValue(
                reason,
                rawContentEnabled: false
            ),
            metadata: safeMetadata
        )
    }
    public func redacted(
        privacyMode: AutocompleteTracePrivacyMode
    ) -> RedactedAutocompleteTraceEvent {
        RedactedAutocompleteTraceEvent(event: self, privacyMode: privacyMode)
    }

    private func addLengthMetadata(
        value: String,
        key: String,
        metadata: inout [String: String]
    ) {
        guard !value.isEmpty else {
            return
        }

        metadata[key] = String(value.count)
    }
}

extension AutocompleteTraceEvent {
    var acceptanceIdentifier: String {
        metadata["acceptanceID"] ?? suggestionID
    }

    var isAcceptedAndKeptSignal: Bool {
        if metadata["strongAcceptedAndKept"] == "true"
            || metadata["finalAcceptedAndKept"] == "true" {
            return true
        }

        guard let checkpointValue = metadata["checkpoint"],
              let checkpoint = AcceptanceSurvivalCheckpoint(rawValue: checkpointValue),
              checkpoint != .twoSeconds,
              let survivalClassValue = metadata["survivalClass"],
              let survivalClass = AcceptanceSurvivalClass(rawValue: survivalClassValue) else {
            return false
        }

        return survivalClass.countsAsKept
    }

    var isDuplicateInsertionSignal: Bool {
        metadata["duplicateDetected"] == "true"
            || reason.localizedCaseInsensitiveContains("duplicate")
            || outcome.localizedCaseInsensitiveContains("duplicate")
    }

    var isTabConflictSignal: Bool {
        metadata["tabConflict"] == "true"
            || traceTextSignalContains("tab-conflict")
            || traceTextSignalContains("tab conflict")
    }

    var isFocusStealSignal: Bool {
        metadata["focusStealing"] == "true"
            || metadata["focusSteal"] == "true"
            || traceTextSignalContains("focus-steal")
            || traceTextSignalContains("focus steal")
    }

    var isAcceptedThenDeletedWithinTwoSecondsSignal: Bool {
        guard type == .acceptedTextEdited,
              metadata["survivalClass"] == AcceptanceSurvivalClass.rejectedAfterAccept.rawValue else {
            return false
        }

        return (Int(metadata["firstEditDelayMs"] ?? "") ?? Int.max) <= 2_000
            || metadata["checkpoint"] == AcceptanceSurvivalCheckpoint.twoSeconds.rawValue
    }

    private func traceTextSignalContains(_ token: String) -> Bool {
        reason.localizedCaseInsensitiveContains(token)
            || outcome.localizedCaseInsensitiveContains(token)
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
            triggerReason: AutocompleteTracePrivacyFilter.traceSignalValue(
                event.triggerReason,
                rawContentEnabled: false
            ),
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
            outcome: AutocompleteTracePrivacyFilter.traceSignalValue(
                event.outcome,
                rawContentEnabled: false
            ),
            reason: AutocompleteTracePrivacyFilter.traceSignalValue(
                event.reason,
                rawContentEnabled: false
            ),
            hasScreenshot: !event.screenshotPath.isEmpty,
            metadata: Dictionary(
                uniqueKeysWithValues: event.metadata.map { key, value in
                    (key, Self.redactedMetadataValue(forKey: key, value: value))
                }
            )
        )
    }

    private static func redactedMetadataValue(forKey key: String, value: String) -> String {
        guard isTraceSafeMetadataKey(key)
            || AutocompleteTracePrivacyFilter.isTraceSignalMetadataKey(key)
            || DiagnosticsMetadataRedactor.isSensitiveKey(key) else {
            return DiagnosticValueRedactor.stringSummary(length: value.count)
        }

        return AutocompleteTracePrivacyFilter.metadataValue(forKey: key, value: value)
    }

    private static func isTraceSafeMetadataKey(_ key: String) -> Bool {
        let normalized = key.lowercased()

        return normalized == "role"
            || normalized == "doclocalngrammatch"
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
