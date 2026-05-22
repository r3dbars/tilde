import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Autocomplete non-annoyance report")
struct AutocompleteNonAnnoyanceReportTests {
    @Test("Quiet redacted trace passes the non-annoyance gate")
    func quietTracePassesGate() {
        let events = [
            event(.suggestionPresented, at: 0, suggestionID: "s1"),
            event(.suggestionHidden, at: 20, suggestionID: "s1", reason: "escape-dismissed"),
            event(.suggestionPresented, at: 70, suggestionID: "s2"),
            event(.suggestionPresented, at: 120, suggestionID: "s3"),
            event(.suggestionHidden, at: 150, suggestionID: "s4", reason: "late-suggestion-hidden", latency: 950),
            event(.suggestionPresented, at: 180, suggestionID: "s5")
        ]

        let report = AutocompleteNonAnnoyanceReporter().report(for: events)

        #expect(report.gatePassed)
        #expect(report.shown == 4)
        #expect(report.dismissals == 1)
        #expect(report.lateSuggestionsHidden == 1)
        #expect(report.lateSuggestionsShown == 0)
        #expect(report.plainTextReport().contains("Shown/min: 1.33 (4 shown)"))
    }

    @Test("Noisy redacted trace fails with concrete annoyance rates")
    func noisyTraceFailsGate() {
        let events = [
            event(.suggestionPresented, at: 0, suggestionID: "s1"),
            event(.suggestionHidden, at: 1, suggestionID: "s1", reason: "escape-dismissed"),
            event(.suggestionPresented, at: 2, suggestionID: "s2"),
            event(.suggestionTypedOver, at: 2.5, suggestionID: "s2"),
            event(.suggestionPresented, at: 3, suggestionID: "s3"),
            acceptedThenDeleted(at: 4, suggestionID: "s3", acceptanceID: "a3"),
            event(.suggestionPresented, at: 5, suggestionID: "s4", latency: 900),
            event(.appDisabled, at: 6)
        ]

        let report = AutocompleteNonAnnoyanceReporter().report(for: events)

        #expect(!report.gatePassed)
        #expect(report.typedOverWithinOneSecond == 1)
        #expect(report.acceptedThenDeleted == 1)
        #expect(report.immediateResurfacing == 3)
        #expect(report.lateSuggestionsShown == 1)
        #expect(report.severeSignals == 1)
        #expect(report.severeSignalsSuppressed == 0)
    }

    @Test("Cooldown suppression covers typed-over fast word resurfacing")
    func cooldownSuppressionCoversTypedOverFastWordResurfacing() {
        let events = [
            event(.suggestionPresented, at: 0, suggestionID: "s1"),
            event(.suggestionTypedOver, at: 1, suggestionID: "s1", reason: "typed-against-visible-suggestion"),
            event(
                .suggestionSuppressed,
                at: 1.1,
                suggestionID: "s2",
                reason: PrefixFamilyCooldownReason.typedOver.rawValue,
                metadata: ["prefixCooldownReason": PrefixFamilyCooldownReason.typedOver.rawValue]
            ),
            event(.suggestionPresented, at: 2, suggestionID: "s3"),
            event(.suggestionPresented, at: 70, suggestionID: "s4"),
            event(.suggestionPresented, at: 120, suggestionID: "s5"),
            event(.suggestionPresented, at: 180, suggestionID: "s6"),
            event(.suggestionPresented, at: 240, suggestionID: "s7")
        ]

        let report = AutocompleteNonAnnoyanceReporter().report(for: events)

        #expect(report.immediateResurfacing == 0)
        #expect(report.typedOverWithinOneSecond == 1)
        #expect(report.gatePassed)
    }

    @Test("Accepted then deleted counts as covered when it starts prefix cooldown")
    func acceptedThenDeletedCooldownCoversSevereSignal() {
        let events = [
            event(.suggestionPresented, at: 0, suggestionID: "s1"),
            acceptedThenDeleted(
                at: 1,
                suggestionID: "s1",
                acceptanceID: "a1",
                metadata: ["prefixCooldownReason": "acceptedThenDeleted"]
            )
        ]

        let report = AutocompleteNonAnnoyanceReporter(
            thresholds: AutocompleteNonAnnoyanceThresholds(maxAcceptedThenDeletedRate: 1)
        ).report(for: events)

        #expect(report.severeSignals == 1)
        #expect(report.severeSignalsSuppressed == 1)
        #expect(report.severeSuppressionRate == 1)
        #expect(report.gatePassed)
    }

    @Test("Timed pause traces count as pause disable control signals")
    func timedPauseTracesCountAsPauseDisableControlSignals() {
        let events = [
            event(.suggestionPresented, at: 0, suggestionID: "s1"),
            event(.appPaused, at: 10, suggestionID: "s1", reason: "timed-pause"),
            event(.fieldPaused, at: 70, reason: "manual-field")
        ]

        let report = AutocompleteNonAnnoyanceReporter(
            thresholds: AutocompleteNonAnnoyanceThresholds(maxPauseDisablePerShown: 2)
        ).report(for: events)

        #expect(report.pauseDisableEvents == 2)
        #expect(report.pauseDisablePerShown == 2)
        #expect(report.gatePassed)
        #expect(report.plainTextReport().contains("Pause/disable events: 2"))
    }

    @Test("Plain text report does not include raw trace text")
    func plaintextReportDoesNotIncludeRawText() {
        let events = [
            event(
                .suggestionPresented,
                at: 0,
                suggestionID: "s1",
                textBeforeCursor: "secret customer phrase",
                displayedText: "secret completion"
            )
        ]

        let reportText = AutocompleteNonAnnoyanceReporter().report(for: events).plainTextReport()

        #expect(!reportText.contains("secret"))
        #expect(!reportText.contains("customer"))
        #expect(!reportText.contains("completion"))
    }

    private func acceptedThenDeleted(
        at offset: TimeInterval,
        suggestionID: String,
        acceptanceID: String,
        metadata: [String: String] = [:]
    ) -> AutocompleteTraceEvent {
        event(
            .acceptedTextEdited,
            at: offset,
            suggestionID: suggestionID,
            outcome: "rejectedAfterAccept",
            reason: "accepted-then-deleted",
            metadata: ["acceptanceID": acceptanceID].merging(metadata) { current, _ in current }
        )
    }

    private func event(
        _ type: AutocompleteTraceEventType,
        at offset: TimeInterval,
        suggestionID: String = "",
        outcome: String = "",
        reason: String = "",
        latency: Int? = nil,
        metadata: [String: String] = [:],
        textBeforeCursor: String = "",
        displayedText: String = ""
    ) -> AutocompleteTraceEvent {
        AutocompleteTraceEvent(
            timestamp: ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: offset)),
            sessionID: "session-one",
            suggestionID: suggestionID,
            type: type,
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: "field-one",
            requestMode: "wordCompletion",
            textBeforeCursor: textBeforeCursor,
            displayedText: displayedText,
            latencyMilliseconds: latency,
            outcome: outcome,
            reason: reason,
            metadata: metadata
        )
    }
}
