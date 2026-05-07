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
            event(.suggestionPresented, suggestionID: "three", displayedText: "ng", latency: 30),
            event(.suggestionHidden, suggestionID: "three", displayedText: "ng", outcome: "typed-through"),
            event(.insertionFailed, suggestionID: "four", reason: "insert-verification-failed"),
            event(.suggestionSuppressed, suggestionID: "five", reason: "repeated-miss"),
            event(.suggestionSuppressed, suggestionID: "six", reason: "repeated-miss"),
            event(.suggestionSuppressed, suggestionID: "seven", reason: "no-fast-word-candidate")
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.totalEvents == 11)
        #expect(summary.presentedCount == 3)
        #expect(summary.acceptedCount == 2)
        #expect(summary.typedThroughCount == 1)
        #expect(summary.typedOverCount == 1)
        #expect(summary.suppressedCount == 3)
        #expect(summary.actionableSuppressedCount == 2)
        #expect(summary.suppressedByReason["repeated-miss"] == 2)
        #expect(summary.suppressedByReason["no-fast-word-candidate"] == 1)
        #expect(summary.suppressedByApp["com.apple.TextEdit"] == 3)
        #expect(summary.suppressedByMode["wordCompletion"] == 3)
        #expect(summary.actionableSuppressedByApp["com.apple.TextEdit"] == 2)
        #expect(summary.actionableSuppressedByMode["wordCompletion"] == 2)
        #expect(summary.insertionFailureCount == 1)
        #expect(summary.acceptRate == 1.0 / 3.0)
        #expect(summary.usefulRate == 2.0 / 3.0)
        #expect(summary.acceptRateByApp["com.apple.TextEdit"] == 1.0 / 3.0)
        #expect(summary.acceptRateByMode["wordCompletion"] == 1.0 / 3.0)
        #expect(summary.usefulRateByApp["com.apple.TextEdit"] == 2.0 / 3.0)
        #expect(summary.usefulRateByMode["wordCompletion"] == 2.0 / 3.0)
        #expect(summary.p50LatencyMilliseconds == 30)
        #expect(summary.topMisses.count == 2)
        #expect(summary.topMisses.contains { $0.fixCategory == "word-completion issue" })
        #expect(summary.topMisses.contains { $0.fixCategory == "insertion bug" })
    }

    @Test("Streaming updates count as one shown suggestion")
    func streamingUpdatesCountAsOneShownSuggestion() {
        let events = [
            event(.suggestionPresented, suggestionID: "one", displayedText: "we", latency: 80),
            event(.suggestionPresented, suggestionID: "one", displayedText: "we should", latency: 120),
            event(.suggestionPresented, suggestionID: "one", displayedText: "we should keep going", latency: 180),
            event(.suggestionAccepted, suggestionID: "one", acceptedText: "we should"),
            event(.suggestionPresented, suggestionID: "two", displayedText: "maybe later", latency: 240),
            event(.suggestionHidden, suggestionID: "two", displayedText: "maybe later", outcome: "ignored")
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.totalEvents == 6)
        #expect(summary.presentedCount == 2)
        #expect(summary.acceptedCount == 1)
        #expect(summary.acceptRate == 0.5)
        #expect(summary.acceptRateByApp["com.apple.TextEdit"] == 0.5)
        #expect(summary.usefulRateByApp["com.apple.TextEdit"] == 0.5)
        #expect(summary.p50LatencyMilliseconds == 240)
        #expect(summary.p90LatencyMilliseconds == 240)
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
            ),
            event(
                .modelResult,
                suggestionID: "four",
                requestMode: "phraseContinuation",
                rawOutput: "The best way is to restart.",
                cleanedVisibleText: "The best way is to restart."
            ),
            event(
                .modelResult,
                suggestionID: "five",
                requestMode: "wordCompletion",
                rawOutput: "s",
                cleanedVisibleText: "s"
            )
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.topMisses.contains { $0.title == "Word mode returned phrase" })
        #expect(summary.topMisses.contains { $0.title == "Model leaked thinking text" })
        #expect(summary.topMisses.contains { $0.title == "Assistant-style completion" })
        #expect(summary.topMisses.contains { $0.title == "Too-short word completion" })
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

    @Test("flags slow suggestions as latency misses")
    func flagsSlowSuggestions() {
        let events = [
            event(
                .suggestionPresented,
                suggestionID: "one",
                requestMode: "phraseContinuation",
                displayedText: "wondering if it is",
                latency: 2_023
            ),
            event(
                .suggestionPresented,
                suggestionID: "two",
                requestMode: "wordCompletion",
                displayedText: "t",
                latency: 42
            )
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.topMisses.contains { miss in
            miss.title == "Slow suggestion: phraseContinuation"
                && miss.fixCategory == "model latency issue"
                && miss.suggestedCause.contains("2023")
        })
        #expect(!summary.topMisses.contains { $0.title == "Slow suggestion: wordCompletion" })
    }

    @Test("flags geometry and observer update misses from metadata and reason")
    func flagsGeometryAndObserverMisses() {
        let events = [
            event(
                .suggestionSuppressed,
                suggestionID: "caret-unavailable",
                appBundleIdentifier: "com.apple.Notes",
                reason: "missing-caret"
            ),
            event(
                .suggestionSuppressed,
                suggestionID: "caret-invalid",
                appBundleIdentifier: "com.google.Chrome",
                reason: "caret-invalid",
                metadata: ["geometryReason": "zeroHeight"]
            ),
            event(
                .suggestionPresented,
                suggestionID: "field-anchor",
                appBundleIdentifier: "md.obsidian",
                metadata: [
                    "anchorSource": "field",
                    "hasCaretRect": "false",
                    "hasElementRect": "true"
                ]
            ),
            event(
                .suggestionPresented,
                suggestionID: "window-anchor",
                appBundleIdentifier: "com.openai.codex",
                metadata: ["anchorSource": "window"]
            ),
            event(
                .suggestionPresented,
                suggestionID: "observer-missed",
                appBundleIdentifier: "com.apple.TextEdit",
                metadata: [
                    "expectedUpdateSource": "observer",
                    "updateSource": "watchPoll"
                ]
            ),
            event(
                .suggestionPresented,
                suggestionID: "poll-recovered",
                appBundleIdentifier: "com.apple.TextEdit",
                reason: "poll-recovered-update",
                metadata: ["pollRecoveredUpdate": "true"]
            )
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.topMisses.contains { miss in
            miss.title == "Caret unavailable in com.apple.Notes"
                && miss.fixCategory == "renderer/caret bug"
        })
        #expect(summary.topMisses.contains { miss in
            miss.title == "Caret invalid in com.google.Chrome"
                && miss.suggestedCause.contains("zeroheight")
        })
        #expect(summary.topMisses.contains { $0.title == "Field anchor used in md.obsidian" })
        #expect(summary.topMisses.contains { $0.title == "Window anchor used in com.openai.codex" })
        #expect(summary.topMisses.contains { miss in
            miss.title == "Observer missed update in com.apple.TextEdit"
                && miss.fixCategory == "observer/update bug"
        })
        #expect(summary.topMisses.contains { $0.title == "Poll recovered update in com.apple.TextEdit" })
    }

    @Test("summarizes diagnostic metadata by app")
    func summarizesDiagnosticMetadataByApp() {
        let events = [
            event(
                .suggestionPresented,
                suggestionID: "anchor",
                appBundleIdentifier: "com.apple.TextEdit",
                metadata: [
                    "anchorQuality": "trusted",
                    "profileInsertionMode": "axSelectedText",
                    "updateSource": "observer"
                ]
            ),
            event(
                .insertionFailed,
                suggestionID: "insert",
                appBundleIdentifier: "com.apple.TextEdit",
                metadata: ["actualInsertionMode": "keyEvents"]
            ),
            event(
                .suggestionSuppressed,
                suggestionID: "ax",
                appBundleIdentifier: "com.google.Chrome",
                metadata: [
                    "geometryReason": "zeroHeight",
                    "refreshSource": "watchPoll"
                ]
            )
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.anchorQualityByApp["com.apple.TextEdit"]?["trusted"] == 1)
        #expect(summary.insertionModeByApp["com.apple.TextEdit"]?["axSelectedText"] == 1)
        #expect(summary.insertionModeByApp["com.apple.TextEdit"]?["keyEvents"] == 1)
        #expect(summary.insertionFailuresByAppAndMode["com.apple.TextEdit"]?["keyEvents"] == 1)
        #expect(summary.updateSourceByApp["com.apple.TextEdit"]?["observer"] == 1)
        #expect(summary.updateSourceByApp["com.google.Chrome"]?["watchPoll"] == 1)
        #expect(summary.axFailureReasonByApp["com.google.Chrome"]?["zeroHeight"] == 1)
    }

    @Test("summarizes trust-critical suppressed reasons")
    func summarizesTrustCriticalSuppressedReasons() {
        let events = [
            event(.suggestionSuppressed, suggestionID: "secure", reason: "secureField"),
            event(.suggestionSuppressed, suggestionID: "sensitive", reason: "sensitiveContent"),
            event(.suggestionSuppressed, suggestionID: "diagnostics", reason: "profile-diagnostics-only"),
            event(.suggestionSuppressed, suggestionID: "paused", reason: "suppressedField"),
            event(.suggestionSuppressed, suggestionID: "fast", reason: "no-fast-word-candidate")
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.suppressedCount == 5)
        #expect(summary.actionableSuppressedCount == 4)
        #expect(summary.suppressedByReason["secureField"] == 1)
        #expect(summary.suppressedByReason["sensitiveContent"] == 1)
        #expect(summary.suppressedByReason["profile-diagnostics-only"] == 1)
        #expect(summary.suppressedByReason["suppressedField"] == 1)
        #expect(summary.suppressedByReason["no-fast-word-candidate"] == 1)
    }

    @Test("flags repeated unaccepted suggestions")
    func flagsRepeatedUnacceptedSuggestions() {
        let events = [
            event(.suggestionPresented, suggestionID: "one", requestMode: "phraseContinuation", displayedText: "I think so."),
            event(.suggestionPresented, suggestionID: "two", requestMode: "phraseContinuation", displayedText: " I   think so. "),
            event(.suggestionPresented, suggestionID: "three", requestMode: "phraseContinuation", displayedText: "i think so."),
            event(.suggestionPresented, suggestionID: "four", requestMode: "phraseContinuation", displayedText: "that sounds good"),
            event(.suggestionPresented, suggestionID: "five", requestMode: "phraseContinuation", displayedText: "that sounds good"),
            event(.suggestionPresented, suggestionID: "six", requestMode: "phraseContinuation", displayedText: "that sounds good"),
            event(.suggestionAccepted, suggestionID: "four", acceptedText: "that"),
            event(.suggestionAccepted, suggestionID: "five", acceptedText: "that"),
            event(.suggestionAccepted, suggestionID: "six", acceptedText: "that")
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.topMisses.contains { miss in
            miss.title == "Repeated unaccepted: i think so."
                && miss.count == 3
                && miss.appBundleIdentifier == "com.apple.TextEdit"
                && miss.requestMode == "phraseContinuation"
                && miss.fixCategory == "prompt issue"
                && miss.suggestedCause.contains("3 times")
                && miss.suggestedCause.contains("com.apple.TextEdit")
        })
        #expect(!summary.topMisses.contains { $0.title == "Repeated unaccepted: that sounds good" })
    }

    @Test("typed-through suggestions do not count as repeated misses")
    func typedThroughSuggestionsDoNotCountAsRepeatedMisses() {
        let events = [
            event(.suggestionPresented, suggestionID: "one", requestMode: "wordCompletion", displayedText: "ng"),
            event(.suggestionPresented, suggestionID: "two", requestMode: "wordCompletion", displayedText: "ng"),
            event(.suggestionPresented, suggestionID: "three", requestMode: "wordCompletion", displayedText: "ng"),
            event(.suggestionHidden, suggestionID: "one", requestMode: "wordCompletion", displayedText: "ng", outcome: "typed-through"),
            event(.suggestionHidden, suggestionID: "two", requestMode: "wordCompletion", displayedText: "ng", outcome: "typed-through"),
            event(.suggestionHidden, suggestionID: "three", requestMode: "wordCompletion", displayedText: "ng", outcome: "typed-through")
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(!summary.topMisses.contains { $0.title == "Repeated unaccepted: ng" })
    }

    @Test("flags repeated typed-over suggestions")
    func flagsRepeatedTypedOverSuggestions() {
        let events = [
            event(.suggestionTypedOver, suggestionID: "one", requestMode: "phraseContinuation", displayedText: "sounds good"),
            event(.suggestionTypedOver, suggestionID: "two", requestMode: "phraseContinuation", displayedText: " sounds   good ")
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.topMisses.contains { miss in
            miss.title == "Repeated typed-over: sounds good"
                && miss.count == 2
                && miss.fixCategory == "prompt issue"
        })
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
