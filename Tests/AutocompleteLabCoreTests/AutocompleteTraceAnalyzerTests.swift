import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Autocomplete trace analyzer")
struct AutocompleteTraceAnalyzerTests {
    @Test("summarizes acceptance, typed-over misses, and latency")
    func summarizesTraceEvents() {
        let events = [
            event(.suggestionPresented, suggestionID: "one", displayedText: "tation", latency: 12),
            event(.suggestionAccepted, suggestionID: "one", acceptedText: "tation"),
            event(.suggestionPresented, suggestionID: "two", displayedText: "best option available", latency: 80),
            event(.suggestionTypedOver, suggestionID: "two", displayedText: "best option available"),
            event(.insertionFailed, suggestionID: "three", reason: "insert-verification-failed")
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.totalEvents == 5)
        #expect(summary.presentedCount == 2)
        #expect(summary.acceptedCount == 1)
        #expect(summary.typedOverCount == 1)
        #expect(summary.insertionFailureCount == 1)
        #expect(summary.acceptRate == 0.5)
        #expect(summary.p50LatencyMilliseconds == 80)
        #expect(summary.topMisses.count == 2)
        #expect(summary.topMisses.contains { $0.fixCategory == "word-completion issue" })
        #expect(summary.topMisses.contains { $0.fixCategory == "insertion bug" })
    }

    @Test("flags thinking text and word completion phrases")
    func flagsCleanerMisses() {
        let events = [
            event(
                .modelResult,
                suggestionID: "one",
                requestMode: "wordCompletion",
                rawOutput: "<think>hmm</think> best option",
                cleanedVisibleText: "best option"
            )
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.topMisses.contains { $0.title == "Word mode returned phrase" })
        #expect(summary.topMisses.contains { $0.title == "Model leaked thinking text" })
    }

    private func event(
        _ type: AutocompleteTraceEventType,
        suggestionID: String,
        requestMode: String = "wordCompletion",
        rawOutput: String = "",
        cleanedVisibleText: String = "",
        displayedText: String = "",
        acceptedText: String = "",
        latency: Int? = nil,
        reason: String = ""
    ) -> AutocompleteTraceEvent {
        AutocompleteTraceEvent(
            timestamp: "2026-04-26T00:00:00Z",
            sessionID: "session",
            suggestionID: suggestionID,
            type: type,
            appBundleIdentifier: "com.apple.TextEdit",
            requestMode: requestMode,
            rawOutput: rawOutput,
            cleanedVisibleText: cleanedVisibleText,
            displayedText: displayedText,
            acceptedText: acceptedText,
            latencyMilliseconds: latency,
            reason: reason
        )
    }
}

