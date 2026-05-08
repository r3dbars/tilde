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
        #expect(summary.doNotShipCounters["insertion-failed"] == 1)
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

    @Test("counts wrong-app acceptance blocks as do-not-ship blockers")
    func countsWrongAppAcceptanceBlocksAsDoNotShipBlockers() {
        let events = [
            event(
                .suggestionSuppressed,
                suggestionID: "one",
                reason: "wrong-app-or-field-before-accept",
                metadata: [
                    "acceptanceGuardReason": "app-changed-before-accept",
                    "doNotShip": "true",
                    "focusMismatch": "true",
                    "severe": "true"
                ]
            )
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.doNotShipCounters["wrong-app-or-field-before-accept"] == 1)
        #expect(summary.dailySummaries.first?.severeFailures == 1)
        #expect(summary.annoyanceSignalCounts["focusMismatch"] == 1)
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

    @Test("summarizes caret geometry failures by app and render mode")
    func summarizesCaretGeometryFailures() {
        let events = [
            event(
                .suggestionPresented,
                suggestionID: "shown",
                appBundleIdentifier: "com.apple.TextEdit",
                metadata: ["effectiveRenderMode": "inlineAdjacent"]
            ),
            event(
                .caretGeometryFailed,
                suggestionID: "fallback",
                appBundleIdentifier: "com.apple.TextEdit",
                reason: "inline-caret-unavailable-fell-back",
                metadata: ["effectiveRenderMode": "floatingMirror"]
            ),
            event(
                .caretGeometryFailed,
                suggestionID: "missing",
                appBundleIdentifier: "md.obsidian",
                reason: "detached-suggestion-disabled",
                metadata: ["effectiveRenderMode": "floatingMirror"]
            )
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.caretGeometryFailureCount == 2)
        #expect(summary.caretGeometryFailureRate == 2.0 / 3.0)
        #expect(summary.caretGeometryFailuresByApp["com.apple.TextEdit"] == 1)
        #expect(summary.caretGeometryFailuresByApp["md.obsidian"] == 1)
        #expect(summary.caretGeometryFailureRateByApp["com.apple.TextEdit"] == 0.5)
        #expect(summary.caretGeometryFailureRateByApp["md.obsidian"] == 1.0)
        #expect(summary.caretGeometryFailuresByRenderMode["floatingMirror"] == 2)
        #expect(summary.caretGeometryFailureRateByRenderMode["floatingMirror"] == 1.0)
        #expect(summary.topMisses.contains { $0.title == "Caret geometry failed: detached-suggestion-disabled" })
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

    @Test("summarizes accepted-and-kept and first ten metrics")
    func summarizesAcceptedAndKeptMetrics() {
        let events = [
            event(.suggestionPresented, suggestionID: "one", displayedText: "make this easier", latency: 80),
            event(.suggestionPresented, suggestionID: "two", displayedText: "wrong direction", latency: 120),
            event(
                .suggestionAccepted,
                suggestionID: "one",
                acceptedText: "make",
                outcome: "acceptNextWord",
                metadata: ["acceptanceID": "accept-one", "acceptMode": "tab"]
            ),
            event(
                .suggestionAccepted,
                suggestionID: "two",
                acceptedText: "wrong direction",
                outcome: "acceptAllVisible",
                metadata: ["acceptanceID": "accept-two", "acceptMode": "full"]
            ),
            event(
                .acceptedTextEdited,
                suggestionID: "one",
                metadata: [
                    "acceptanceID": "accept-one",
                    "checkpoint": "10s",
                    "survivalClass": "lightlyEditedKept",
                    "tokenRecall": "0.800",
                    "normalizedEditDistance": "0.100",
                    "firstEditDelayMs": "6000",
                    "strongAcceptedAndKept": "true"
                ]
            ),
            event(
                .acceptedTextEdited,
                suggestionID: "two",
                metadata: [
                    "acceptanceID": "accept-two",
                    "checkpoint": "2s",
                    "survivalClass": "rejectedAfterAccept",
                    "tokenRecall": "0.000",
                    "normalizedEditDistance": "1.000",
                    "firstEditDelayMs": "900"
                ]
            ),
            event(.insertionVerified, suggestionID: "one", metadata: ["acceptanceID": "accept-one"]),
            event(.insertionFailed, suggestionID: "two", reason: "insert-verification-failed", metadata: ["acceptanceID": "accept-two", "duplicateDetected": "true"]),
            event(.appDisabled, suggestionID: "", reason: "manual")
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.acceptedAndKeptCount == 1)
        #expect(summary.acceptedAndKeptRateAccepted == 0.5)
        #expect(summary.acceptedAndKeptRateShown == 0.5)
        #expect(summary.medianEditDistanceAfterAccept == 0.55)
        #expect(summary.medianTimeUntilFirstEditAfterAcceptMilliseconds == 6_000)
        #expect(summary.tabAcceptShare == 0.5)
        #expect(summary.fullAcceptShare == 0.5)
        #expect(summary.insertionVerifiedCount == 1)
        #expect(summary.insertionVerificationSuccessRate == 0.5)
        #expect(summary.duplicateTextCount == 1)
        #expect(summary.appDisableCount == 1)
        #expect(summary.topMisses.contains { $0.fixCategory == "accepted-and-kept issue" })
        #expect(summary.topMisses.contains { $0.fixCategory == "trust issue" })
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

    @Test("summarizes annoyance signals")
    func summarizesAnnoyanceSignals() {
        let events = [
            event(.suggestionPresented, suggestionID: "one", timestamp: "2026-04-26T00:00:00Z"),
            event(.suggestionHidden, suggestionID: "one", timestamp: "2026-04-26T00:00:00Z", outcome: "ignored", reason: "escape"),
            event(.suggestionTypedOver, suggestionID: "two", metadata: ["delayMs": "500"]),
            event(
                .acceptedTextEdited,
                suggestionID: "three",
                metadata: [
                    "checkpoint": "2s",
                    "survivalClass": "rejectedAfterAccept",
                    "firstEditDelayMs": "900"
                ]
            ),
            event(.suggestionPresented, suggestionID: "four", metadata: ["fieldKind": "search"]),
            event(.suggestionPresented, suggestionID: "four-b", metadata: ["fieldKind": "unprovenSurface"]),
            event(.suggestionSuppressed, suggestionID: "five", reason: "repeated-miss"),
            event(.insertionFailed, suggestionID: "six", reason: "insert-verification-failed"),
            event(.appDisabled, suggestionID: "seven", reason: "manual"),
            event(.suggestionHidden, suggestionID: "eight", reason: "hidden", metadata: ["lifetimeMs": "90"])
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.annoyanceSignalCounts["rapidEscDismissal"] == 1)
        #expect(summary.annoyanceSignalCounts["typedOverWithinOneSecond"] == 1)
        #expect(summary.annoyanceSignalCounts["acceptedThenDeleted"] == 1)
        #expect(summary.annoyanceSignalCounts["searchOrFormLeakage"] == 2)
        #expect(summary.annoyanceSignalCounts["repeatedRejection"] == 1)
        #expect(summary.annoyanceSignalCounts["wrongInsertion"] == 1)
        #expect(summary.annoyanceSignalCounts["appDisable"] == 1)
        #expect(summary.annoyanceSignalCounts["overlayFlicker"] == 1)
        #expect(summary.annoyanceScore > 0)
    }

    @Test("summarizes field-kind slices")
    func summarizesFieldKindSlices() {
        let events = [
            event(.suggestionPresented, suggestionID: "one", metadata: ["fieldKind": "multilineCompose"]),
            event(.suggestionPresented, suggestionID: "two", metadata: ["fieldKind": "singlelineCompose"]),
            event(.suggestionSuppressed, suggestionID: "three", reason: "blockedFieldKind", metadata: ["fieldKind": "form"]),
            event(.suggestionSuppressed, suggestionID: "four", reason: "blockedFieldKind", metadata: ["fieldKind": "search"]),
            event(
                .acceptedTextEdited,
                suggestionID: "one",
                metadata: [
                    "fieldKind": "multilineCompose",
                    "checkpoint": "10s",
                    "survivalClass": "exactKept",
                    "strongAcceptedAndKept": "true"
                ]
            )
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.presentedByFieldKind["multilineCompose"] == 1)
        #expect(summary.presentedByFieldKind["singlelineCompose"] == 1)
        #expect(summary.suppressedByFieldKind["form"] == 1)
        #expect(summary.suppressedByFieldKind["search"] == 1)
        #expect(summary.acceptedAndKeptByFieldKind["multilineCompose"] == 1)
    }

    @Test("summarizes experiment arm slices")
    func summarizesExperimentArmSlices() {
        let events = [
            event(.suggestionPresented, experimentArm: "length_1_word", suggestionID: "one"),
            event(.suggestionAccepted, experimentArm: "length_1_word", suggestionID: "one"),
            event(
                .acceptedTextEdited,
                experimentArm: "length_1_word",
                suggestionID: "one",
                metadata: [
                    "checkpoint": "10s",
                    "survivalClass": "exactKept",
                    "strongAcceptedAndKept": "true"
                ]
            ),
            event(.suggestionPresented, experimentArm: "length_3_word", suggestionID: "two"),
            event(.suggestionPresented, experimentArm: "length_3_word", suggestionID: "three"),
            event(.suggestionHidden, experimentArm: "length_3_word", suggestionID: "three", outcome: "typed-through"),
            event(.suggestionSuppressed, experimentArm: "length_1_word", suggestionID: "four", reason: "repeated-miss"),
            event(
                .suggestionSuppressed,
                experimentArm: "",
                suggestionID: "five",
                reason: "repeated-miss",
                metadata: ["experimentArm": "metadata_arm"]
            )
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.acceptRateByExperimentArm["length_1_word"] == 1.0)
        #expect(summary.acceptRateByExperimentArm["length_3_word"] == 0)
        #expect(summary.usefulRateByExperimentArm["length_3_word"] == 0.5)
        #expect(summary.presentedByExperimentArm["length_1_word"] == 1)
        #expect(summary.presentedByExperimentArm["length_3_word"] == 2)
        #expect(summary.acceptedAndKeptByExperimentArm["length_1_word"] == 1)
        #expect(summary.suppressedByExperimentArm["length_1_word"] == 1)
        #expect(summary.suppressedByExperimentArm["metadata_arm"] == 1)
    }

    @Test("summarizes survival slices and retention clearing")
    func summarizesSurvivalSlicesAndRetentionClearing() {
        let events = [
            event(
                .suggestionPresented,
                experimentArm: "length_1_word",
                suggestionID: "one",
                appBundleIdentifier: "com.apple.TextEdit",
                requestMode: "wordCompletion",
                metadata: [
                    "fieldKind": "multilineCompose",
                    "effectiveRenderMode": "inlineAdjacent",
                    "model": "qwen35-4b"
                ]
            ),
            event(
                .acceptedTextEdited,
                experimentArm: "length_1_word",
                suggestionID: "one",
                appBundleIdentifier: "com.apple.TextEdit",
                requestMode: "wordCompletion",
                metadata: [
                    "fieldKind": "multilineCompose",
                    "checkpoint": "10s",
                    "survivalClass": "exactKept",
                    "strongAcceptedAndKept": "true",
                    "model": "qwen35-4b"
                ]
            ),
            event(
                .acceptanceRetentionCleared,
                suggestionID: "one",
                appBundleIdentifier: "com.apple.TextEdit",
                requestMode: "wordCompletion",
                reason: "thirty-second-retention-expiry",
                metadata: [
                    "retentionCleared": "true",
                    "rawAcceptedTextDurable": "false"
                ]
            ),
            event(
                .suggestionPresented,
                experimentArm: "length_3_word",
                suggestionID: "two",
                appBundleIdentifier: "md.obsidian",
                requestMode: "phraseContinuation",
                metadata: [
                    "fieldKind": "multilineCompose",
                    "effectiveRenderMode": "floatingMirror",
                    "model": "qwen35-4b"
                ]
            )
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.acceptanceRetentionClearedCount == 1)
        #expect(summary.acceptanceRetentionClearedByReason["thirty-second-retention-expiry"] == 1)
        #expect(summary.acceptedAndKeptRateByApp["com.apple.TextEdit"] == 1.0)
        #expect(summary.acceptedAndKeptRateByApp["md.obsidian"] == 0.0)
        #expect(summary.acceptedAndKeptRateByFieldKind["multilineCompose"] == 0.5)
        #expect(summary.acceptedAndKeptRateByRenderMode["inlineAdjacent"] == 1.0)
        #expect(summary.acceptedAndKeptRateByRenderMode["floatingMirror"] == 0.0)
        #expect(summary.acceptedAndKeptRateByInsertionMode["axSelectedText"] == 1.0)
        #expect(summary.acceptedAndKeptRateByInsertionMode["axThenKeyEvents"] == 0.0)
        #expect(summary.acceptedAndKeptRateByRequestMode["wordCompletion"] == 1.0)
        #expect(summary.acceptedAndKeptRateByRequestMode["phraseContinuation"] == 0.0)
        #expect(summary.acceptedAndKeptRateByModel["qwen35-4b"] == 0.5)
        #expect(summary.acceptedAndKeptRateByExperimentArm["length_1_word"] == 1.0)
        #expect(summary.acceptedAndKeptRateByExperimentArm["length_3_word"] == 0.0)
    }

    @Test("builds dashboard funnels, daily summaries, and recommended fixes")
    func buildsDashboardSummaries() {
        let events = [
            event(.suggestionRequested, suggestionID: "one", timestamp: "2026-04-26T10:00:00Z"),
            event(.modelResult, suggestionID: "one", timestamp: "2026-04-26T10:00:01Z", latency: 1_200),
            event(
                .suggestionPresented,
                suggestionID: "one",
                timestamp: "2026-04-26T10:00:02Z",
                latency: 1_100,
                metadata: ["fieldKind": "search", "effectiveRenderMode": "inlineAdjacent"]
            ),
            event(
                .suggestionAccepted,
                suggestionID: "one",
                timestamp: "2026-04-26T10:00:03Z",
                metadata: ["acceptanceID": "accept-one", "acceptMode": "tab"]
            ),
            event(
                .acceptedTextEdited,
                suggestionID: "one",
                timestamp: "2026-04-26T10:00:05Z",
                metadata: [
                    "acceptanceID": "accept-one",
                    "checkpoint": "10s",
                    "survivalClass": "exactKept",
                    "strongAcceptedAndKept": "true"
                ]
            ),
            event(
                .acceptedTextEdited,
                suggestionID: "one",
                timestamp: "2026-04-26T10:00:35Z",
                metadata: [
                    "acceptanceID": "accept-one",
                    "checkpoint": "30s",
                    "survivalClass": "exactKept",
                    "strongAcceptedAndKept": "true"
                ]
            ),
            event(.suggestionHidden, suggestionID: "one", timestamp: "2026-04-26T10:00:36Z", outcome: "ignored", reason: "escape", metadata: ["lifetimeMs": "90"]),
            event(.suggestionTypedOver, suggestionID: "two", timestamp: "2026-04-26T10:01:00Z"),
            event(.insertionFailed, suggestionID: "three", timestamp: "2026-04-26T10:01:10Z", metadata: ["duplicateDetected": "true"]),
            event(.caretGeometryFailed, suggestionID: "four", timestamp: "2026-04-26T10:01:20Z", metadata: ["severe": "true", "effectiveRenderMode": "floatingMirror"]),
            event(.appPaused, suggestionID: "five", timestamp: "2026-04-26T10:01:30Z"),
            event(.appDisabled, suggestionID: "six", timestamp: "2026-04-26T10:01:40Z")
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.modelResultP50LatencyMilliseconds == 1_200)
        #expect(summary.modelResultP95LatencyMilliseconds == 1_200)
        #expect(summary.acceptanceFunnel.requested == 1)
        #expect(summary.acceptanceFunnel.modelReturned == 1)
        #expect(summary.acceptanceFunnel.shown == 1)
        #expect(summary.acceptanceFunnel.accepted == 1)
        #expect(summary.acceptanceFunnel.keptAt10Seconds == 1)
        #expect(summary.acceptanceFunnel.keptAt30SecondsOrBlur == 1)
        #expect(summary.annoyanceFunnel.shown == 1)
        #expect(summary.annoyanceFunnel.ignored == 1)
        #expect(summary.annoyanceFunnel.typedOver == 1)
        #expect(summary.annoyanceFunnel.escapeDismissed == 1)
        #expect(summary.annoyanceFunnel.paused == 1)
        #expect(summary.annoyanceFunnel.disabled == 1)
        #expect(summary.dailySummaries.first?.date == "2026-04-26")
        #expect(summary.dailySummaries.first?.activeWritingMinutes == 2)
        #expect(summary.dailySummaries.first?.severeFailures == 3)
        #expect(summary.topFailureReasons.first?.title == "Duplicate text")
        #expect(summary.topFailureReasons.contains { $0.title == "Search/form leakage" })
        #expect(summary.topFailureReasons.contains { $0.title == "Overlay flicker" })
        #expect(summary.recommendedFixes.first?.title == "Fix insertion trust before model tuning")
        #expect(summary.recommendedFixes.contains { $0.title == "Fix caret or verification before prompt tuning" })
        #expect(summary.recommendedFixes.contains { $0.title == "Fix latency before length experiments" })
    }

    @Test("summarizes insertion reliability by app and mode")
    func summarizesInsertionReliabilityByAppAndMode() {
        let events = [
            event(
                .insertionVerified,
                suggestionID: "one",
                appBundleIdentifier: "com.apple.TextEdit",
                metadata: ["insertionMode": "axSelectedText"]
            ),
            event(
                .insertionVerified,
                suggestionID: "two",
                appBundleIdentifier: "com.apple.TextEdit",
                metadata: ["insertionMode": "axSelectedText"]
            ),
            event(
                .insertionFailed,
                suggestionID: "three",
                appBundleIdentifier: "com.apple.TextEdit",
                reason: "tab-literal-tab",
                metadata: [
                    "insertionMode": "axSelectedText",
                    "tabConflict": "true",
                    "literalTabInserted": "true",
                    "rollbackAttempted": "false"
                ]
            ),
            event(
                .insertionFailed,
                suggestionID: "four",
                appBundleIdentifier: "md.obsidian",
                metadata: [
                    "insertionMode": "keyEvents",
                    "focusStealing": "true",
                    "rollbackAttempted": "false"
                ]
            )
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.insertionReliabilityByAppAndMode.contains { row in
            row.appBundleIdentifier == "com.apple.TextEdit"
                && row.insertionMode == "axSelectedText"
                && row.verifiedCount == 2
                && row.failedCount == 1
                && abs(row.successRate - (2.0 / 3.0)) < 0.0001
        })
        #expect(summary.annoyanceSignalCounts["tabConflict"] == 1)
        #expect(summary.annoyanceSignalCounts["focusStealing"] == 1)
    }

    @Test("summarizes model quality tracking buckets")
    func summarizesModelQualityTrackingBuckets() {
        let events = [
            event(
                .modelResult,
                suggestionID: "one",
                rawOutput: "later today",
                cleanedVisibleText: "later today",
                latency: 180,
                metadata: [
                    "cleanedWordCount": "2",
                    "firstTokenLatencyMilliseconds": "44"
                ]
            ),
            event(
                .modelResult,
                suggestionID: "two",
                rawOutput: "Let me think",
                cleanedVisibleText: "",
                latency: 520,
                metadata: [
                    "cleanedWordCount": "0",
                    "firstTokenLatencyMilliseconds": "160"
                ]
            ),
            event(.suggestionPresented, suggestionID: "one", latency: 60),
            event(.suggestionSuppressed, suggestionID: "two", reason: "empty-model-result"),
            event(.suggestionSuppressed, suggestionID: "three", reason: "blocked-field-kind")
        ]

        let summary = AutocompleteTraceAnalyzer().summary(for: events)

        #expect(summary.emptyModelResultCount == 1)
        #expect(summary.emptyModelResultRate == 0.5)
        #expect(summary.preRenderBlockedCount == 2)
        #expect(summary.preRenderBlockedByReason["empty-model-result"] == 1)
        #expect(summary.preRenderBlockedByReason["blocked-field-kind"] == 1)
        #expect(summary.modelFirstTokenLatencyBuckets["0-50ms"] == 1)
        #expect(summary.modelFirstTokenLatencyBuckets["101-250ms"] == 1)
        #expect(summary.modelFirstVisibleLatencyBuckets["51-100ms"] == 1)
        #expect(summary.modelTotalGenerationLatencyBuckets["101-250ms"] == 1)
        #expect(summary.modelTotalGenerationLatencyBuckets["501-1000ms"] == 1)
    }

    private func event(
        _ type: AutocompleteTraceEventType,
        experimentArm: String = "length_3_word",
        suggestionID: String,
        timestamp: String = "2026-04-26T00:00:00Z",
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
            experimentArm: experimentArm,
            timestamp: timestamp,
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
