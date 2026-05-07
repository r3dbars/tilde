import Foundation

public struct TracePrivacyPolicy: Equatable, Sendable {
    public let rawTextTracingEnabled: Bool
    public let screenshotTracingEnabled: Bool

    public init(
        rawTextTracingEnabled: Bool = false,
        screenshotTracingEnabled: Bool = false
    ) {
        self.rawTextTracingEnabled = rawTextTracingEnabled
        self.screenshotTracingEnabled = screenshotTracingEnabled
    }

    public static let `default` = TracePrivacyPolicy()

    public static func fromEnvironment(
        _ environment: [String: String],
        diagnosticsRawTextTracingEnabled: Bool = false,
        diagnosticsScreenshotTracingEnabled: Bool = false
    ) -> TracePrivacyPolicy {
        TracePrivacyPolicy(
            rawTextTracingEnabled: diagnosticsRawTextTracingEnabled
                || isEnabled(environment["AUTOCOMPLETE_LAB_RAW_TRACE"])
                || isEnabled(environment["AUTOCOMPLETE_LAB_TRACE_RAW"])
                || isRawTraceMode(environment["AUTOCOMPLETE_LAB_TRACE"]),
            screenshotTracingEnabled: diagnosticsScreenshotTracingEnabled
                || isEnabled(environment["AUTOCOMPLETE_LAB_SCREENSHOT_TRACE"])
        )
    }

    public func logSafeEvent(_ event: AutocompleteTraceEvent) -> AutocompleteTraceEvent {
        guard !rawTextTracingEnabled || !screenshotTracingEnabled else {
            return event
        }

        return AutocompleteTraceEvent(
            id: event.id,
            timestamp: event.timestamp,
            sessionID: event.sessionID,
            suggestionID: event.suggestionID,
            type: event.type,
            appBundleIdentifier: event.appBundleIdentifier,
            fieldIdentity: event.fieldIdentity,
            requestMode: event.requestMode,
            triggerReason: event.triggerReason,
            textBeforeCursor: rawTextTracingEnabled ? event.textBeforeCursor : "",
            textAfterCursor: rawTextTracingEnabled ? event.textAfterCursor : "",
            systemPrompt: rawTextTracingEnabled ? event.systemPrompt : "",
            userPrompt: rawTextTracingEnabled ? event.userPrompt : "",
            rawOutput: rawTextTracingEnabled ? event.rawOutput : "",
            cleanedVisibleText: rawTextTracingEnabled ? event.cleanedVisibleText : "",
            displayedText: rawTextTracingEnabled ? event.displayedText : "",
            acceptedText: rawTextTracingEnabled ? event.acceptedText : "",
            remainingVisibleText: rawTextTracingEnabled ? event.remainingVisibleText : "",
            latencyMilliseconds: event.latencyMilliseconds,
            outcome: event.outcome,
            reason: event.reason,
            screenshotPath: screenshotTracingEnabled ? event.screenshotPath : "",
            metadata: rawTextTracingEnabled
                ? event.metadata
                : logSafeMetadata(from: event)
        )
    }

    private func logSafeMetadata(from event: AutocompleteTraceEvent) -> [String: String] {
        var metadata: [String: String] = [:]

        for (key, value) in event.metadata {
            if Self.isRawTextMetadataKey(key) {
                if !value.isEmpty {
                    metadata["\(key)Chars"] = String(value.count)
                }
            } else {
                metadata[key] = DiagnosticsMetadataRedactor.logSafeValue(forKey: key, value: value)
            }
        }

        addCount("textBeforeCursorChars", event.textBeforeCursor.count, to: &metadata)
        addCount("textAfterCursorChars", event.textAfterCursor.count, to: &metadata)
        addCount("systemPromptChars", event.systemPrompt.count, to: &metadata)
        addCount("userPromptChars", event.userPrompt.count, to: &metadata)
        addCount("rawOutputChars", event.rawOutput.count, to: &metadata)
        addCount("cleanedVisibleTextChars", event.cleanedVisibleText.count, to: &metadata)
        addCount("displayedTextChars", event.displayedText.count, to: &metadata)
        addCount("acceptedTextChars", event.acceptedText.count, to: &metadata)
        addCount("remainingVisibleTextChars", event.remainingVisibleText.count, to: &metadata)

        return metadata
    }

    private func addCount(_ key: String, _ count: Int, to metadata: inout [String: String]) {
        guard count > 0 else {
            return
        }

        metadata[key] = String(count)
    }

    private static func isRawTextMetadataKey(_ key: String) -> Bool {
        let normalized = key.lowercased()
        return [
            "accepted",
            "completion",
            "output",
            "prompt",
            "raw",
            "selected",
            "suggestion",
            "text",
            "typed",
            "value"
        ].contains { normalized.contains($0) }
    }

    private static func isEnabled(_ value: String?) -> Bool {
        guard let value else {
            return false
        }

        return ["1", "true", "yes", "on"].contains(value.lowercased())
    }

    private static func isRawTraceMode(_ value: String?) -> Bool {
        guard let value else {
            return false
        }

        return ["raw", "full", "unsafe"].contains(value.lowercased())
    }
}
