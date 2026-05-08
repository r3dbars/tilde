import Foundation
import AutocompleteLabCore

enum TracePrivacyLane: String, Sendable {
    case redactedBetaTelemetry = "redacted-local-beta-telemetry"
    case rawDogfoodDiagnostics = "raw-dogfood-diagnostics"
}

actor RedactionLayer {
    static let shared = RedactionLayer()

    func redactedDefaultTrace(_ event: AutocompleteTraceEvent) -> AutocompleteTraceEvent {
        Self.redactedDefaultTrace(event)
    }

    func rawDogfoodDiagnosticsTrace(_ event: AutocompleteTraceEvent) -> AutocompleteTraceEvent {
        event.addingMetadata([
            "privacyLane": TracePrivacyLane.rawDogfoodDiagnostics.rawValue,
            "rawDogfoodDiagnostics": "true"
        ])
    }

    nonisolated static func redactedDefaultTrace(_ event: AutocompleteTraceEvent) -> AutocompleteTraceEvent {
        event.redactedForDefaultTrace().addingMetadata([
            "privacyLane": TracePrivacyLane.redactedBetaTelemetry.rawValue,
            "rawDogfoodDiagnostics": "false"
        ])
    }

    nonisolated static func logSafeValue(forKey key: String, value: String) -> String {
        DiagnosticsMetadataRedactor.logSafeValue(forKey: key, value: value)
    }
}

private extension AutocompleteTraceEvent {
    func addingMetadata(_ additionalMetadata: [String: String]) -> AutocompleteTraceEvent {
        var mergedMetadata = metadata
        for (key, value) in additionalMetadata {
            mergedMetadata[key] = value
        }

        return AutocompleteTraceEvent(
            id: id,
            schemaVersion: schemaVersion,
            privacyVersion: privacyVersion,
            experimentArm: experimentArm,
            timestamp: timestamp,
            sessionID: sessionID,
            suggestionID: suggestionID,
            type: type,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentity,
            requestMode: requestMode,
            triggerReason: triggerReason,
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            rawOutput: rawOutput,
            cleanedVisibleText: cleanedVisibleText,
            displayedText: displayedText,
            acceptedText: acceptedText,
            remainingVisibleText: remainingVisibleText,
            latencyMilliseconds: latencyMilliseconds,
            outcome: outcome,
            reason: reason,
            screenshotPath: screenshotPath,
            metadata: mergedMetadata
        )
    }
}
