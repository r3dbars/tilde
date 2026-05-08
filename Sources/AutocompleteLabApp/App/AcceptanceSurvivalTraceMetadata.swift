import Foundation
import AutocompleteLabCore

enum AcceptanceSurvivalTraceMetadata {
    static func measurementMetadata(
        tracker: AcceptanceSurvivalTracker,
        measurement: AcceptanceSurvivalMeasurement,
        secret: Data
    ) -> [String: String] {
        baseMetadata(tracker: tracker, secret: secret)
            .merging(measurement.traceMetadata) { current, _ in current }
    }

    static func retentionClearedMetadata(
        tracker: AcceptanceSurvivalTracker,
        reason: String,
        secret: Data
    ) -> [String: String] {
        baseMetadata(tracker: tracker, secret: secret)
            .merging([
                "retentionCleared": "true",
                "retentionClearedReason": reason
            ]) { current, _ in current }
    }

    private static func baseMetadata(
        tracker: AcceptanceSurvivalTracker,
        secret: Data
    ) -> [String: String] {
        [
            "acceptanceID": tracker.acceptanceID,
            "acceptedTextChars": String(tracker.acceptedText.count),
            "fieldKind": tracker.fieldKind.rawValue,
            "fieldKindReason": tracker.fieldKindReason,
            "supportLevel": tracker.profile.supportLevel.rawValue,
            "insertionMode": tracker.profile.insertionMode.rawValue,
            "traceRetention": "ram-only"
        ].merging(
            TracePrivacyFingerprint.metadata(for: tracker.acceptedText, secret: secret)
        ) { current, _ in current }
    }
}
