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
            event(.suggestionAccepted, suggestionID: "one", acceptedText: " again"),
            event(.suggestionPresented, suggestionID: "two", displayedText: "best option available", latency: 80),
            event(.suggestionTypedOver, suggestionID: "two", displayedText: "best option available"),
            event(.insertionFailed, suggestionID: "three", reason: "insert-verification-failed")
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.totalEvents == 6)
        #expect(summary.presentedCount == 2)
        #expect(summary.acceptedCount == 2)
        #expect(summary.typedOverCount == 1)
        #expect(summary.insertionFailureCount == 1)
        #expect(summary.acceptRate == 0.5)
        #expect(summary.acceptRateByApp["com.apple.TextEdit"] == 0.5)
        #expect(summary.acceptRateByMode["wordCompletion"] == 0.5)
        #expect(summary.p50LatencyMilliseconds == 80)
        #expect(summary.topMisses.count == 2)
        #expect(summary.topMisses.contains { $0.fixCategory == "word-completion issue" })
        #expect(summary.topMisses.contains { $0.fixCategory == "insertion bug" })
    }

    @Test("typed-over hides do not count as ignored")
    func typedOverHidesDoNotCountAsIgnored() {
        let events = [
            event(.suggestionPresented, suggestionID: "one", displayedText: "s"),
            event(.suggestionTypedOver, suggestionID: "one", displayedText: "s", metadata: ["typedSuffix": "ng"]),
            event(.suggestionHidden, suggestionID: "one", displayedText: "s", outcome: "typed-over"),
            event(.suggestionPresented, suggestionID: "two", displayedText: "maybe"),
            event(.suggestionHidden, suggestionID: "two", displayedText: "maybe", outcome: "ignored")
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.typedOverCount == 1)
        #expect(summary.ignoredCount == 1)
        #expect(summary.topMisses.contains { miss in
            miss.title == "Typed over: s -> ng"
                && miss.suggestedCause.contains("ng")
        })
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
            ),
            event(
                .modelResult,
                suggestionID: "two",
                requestMode: "phraseContinuation",
                rawOutput: "I will do that now.",
                cleanedVisibleText: "I will do that now."
            ),
            event(
                .modelResult,
                suggestionID: "three",
                requestMode: "phraseContinuation",
                rawOutput: "Let me know when it's done.",
                cleanedVisibleText: "Let me know when it's done."
            )
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.topMisses.contains { $0.title == "Word mode returned phrase" })
        #expect(summary.topMisses.contains { $0.title == "Model leaked thinking text" })
        #expect(summary.topMisses.contains { $0.title == "Assistant-style completion" })
        #expect(summary.topMisses.contains { $0.fixCategory == "output cleaning issue" })
    }

    @Test("flags detached suggestion renderer misses")
    func flagsDetachedSuggestionMisses() {
        let events = [
            event(
                .suggestionSuppressed,
                suggestionID: "one",
                appBundleIdentifier: "md.obsidian",
                reason: "detached-suggestion-disabled"
            ),
            event(
                .suggestionPresented,
                suggestionID: "two",
                appBundleIdentifier: "md.obsidian",
                displayedText: "thanks for asking",
                metadata: [
                    "effectiveRenderMode": "floatingMirror",
                    "hasCaretRect": "false"
                ]
            )
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.topMisses.contains { $0.title == "Detached suggestions suppressed in md.obsidian" })
        #expect(summary.topMisses.contains { $0.title == "Detached suggestion shown in md.obsidian" })
        #expect(summary.topMisses.allSatisfy { $0.fixCategory == "renderer/caret bug" })
    }

    private func event(
        _ type: AutocompleteTraceEventType,
        suggestionID: String,
        appBundleIdentifier: String = "com.apple.TextEdit",
        requestMode: String = "wordCompletion",
        rawOutput: String = "",
        cleanedVisibleText: String = "",
        displayedText: String = "",
        acceptedText: String = "",
        latency: Int? = nil,
        outcome: String = "",
        reason: String = "",
        metadata: [String: String] = [:]
    ) -> AutocompleteTraceEvent {
        AutocompleteTraceEvent(
            timestamp: "2026-04-26T00:00:00Z",
            sessionID: "session",
            suggestionID: suggestionID,
            type: type,
            appBundleIdentifier: appBundleIdentifier,
            requestMode: requestMode,
            rawOutput: rawOutput,
            cleanedVisibleText: cleanedVisibleText,
            displayedText: displayedText,
            acceptedText: acceptedText,
            latencyMilliseconds: latency,
            outcome: outcome,
            reason: reason,
            metadata: metadata
        )
    }
}
