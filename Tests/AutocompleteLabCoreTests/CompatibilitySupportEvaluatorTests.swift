import Testing
@testable import AutocompleteLabCore

@Suite("Compatibility support evaluator")
struct CompatibilitySupportEvaluatorTests {
    private let evaluator = CompatibilitySupportEvaluator()

    @Test("TextEdit can pass supported gates")
    func textEditCanPassSupportedGates() {
        let events = cleanEvents(
            appBundleIdentifier: "com.apple.TextEdit",
            shown: 20,
            kept: 4,
            latency: 700
        )

        let evaluation = evaluator.evaluate(bundleIdentifier: "com.apple.TextEdit", events: events)

        #expect(evaluation.state == .supported)
        #expect(evaluation.presentedCount == 20)
        #expect(evaluation.appFamily == "nativeText")
        #expect(evaluation.minimumSampleSize == 20)
        #expect(evaluation.acceptedAndKeptCount == 4)
        #expect(evaluation.acceptedAndKeptShownRate == 0.2)
        #expect(evaluation.insertionVerificationSuccessRate == 1)
        #expect(evaluation.p95LatencyMilliseconds == 700)
    }

    @Test("Chrome can pass caveated gates")
    func chromeCanPassCaveatedGates() {
        let events = cleanEvents(
            appBundleIdentifier: "com.google.Chrome",
            shown: 10,
            kept: 1,
            latency: 900
        )

        let evaluation = evaluator.evaluate(bundleIdentifier: "com.google.Chrome", events: events)

        #expect(evaluation.state == .caveated)
        #expect(evaluation.presentedCount == 10)
        #expect(evaluation.appFamily == "browserTextarea")
        #expect(evaluation.minimumSampleSize == 15)
        #expect(evaluation.acceptedAndKeptCount == 1)
        #expect(evaluation.p95LatencyMilliseconds == 900)
        #expect(evaluation.reasons.contains("Needs 15 shown suggestions for supported."))
    }

    @Test("Codex dogfood traces can become experimental")
    func codexDogfoodTracesCanBecomeExperimental() {
        let events = cleanEvents(
            appBundleIdentifier: "com.openai.codex",
            shown: 4,
            kept: 1,
            latency: 400
        )

        let evaluation = evaluator.evaluate(bundleIdentifier: "com.openai.codex", events: events)

        #expect(evaluation.state == .experimental)
        #expect(evaluation.reasons.contains("Needs 10 shown suggestions for caveated."))
        #expect(!evaluation.reasons.contains("Codex is diagnostics-only because it is sensitive."))
        #expect(!evaluation.reasons.contains("Codex cannot present suggestions safely yet."))
    }

    @Test("Blocked apps and plain terminal hosts stay blocked")
    func blockedAppsAndPlainTerminalHostsStayBlocked() {
        #expect(evaluator.evaluate(bundleIdentifier: "com.apple.mail", events: []).state == .blocked)
        #expect(evaluator.evaluate(bundleIdentifier: "com.openai.atlas", events: []).state == .blocked)
        #expect(evaluator.evaluate(bundleIdentifier: "com.apple.Terminal", events: []).state == .blocked)
    }

    @Test("Insertion, focus, Tab, and sensitive-field failures block support")
    func severeFailuresBlockSupport() {
        let base = cleanEvents(appBundleIdentifier: "com.apple.TextEdit", shown: 20, kept: 4, latency: 300)
        let duplicate = base + [
            event(.insertionFailed, suggestionID: "duplicate", reason: "duplicate text", metadata: ["duplicateDetected": "true"])
        ]
        let wrongInsertion = base + [
            event(.insertionFailed, suggestionID: "wrong", reason: "insert-verification-failed")
        ]
        let focusSteal = base + [
            event(.suggestionSuppressed, suggestionID: "focus", reason: "focus-steal")
        ]
        let tabConflict = base + [
            event(.suggestionSuppressed, suggestionID: "tab", reason: "tab-conflict")
        ]
        let sensitiveField = base + [
            event(.suggestionPresented, suggestionID: "search", metadata: ["fieldKind": "search"])
        ]
        let unprovenSurface = base + [
            event(.suggestionPresented, suggestionID: "docs", metadata: ["fieldKind": "unprovenSurface"])
        ]

        #expect(evaluator.evaluate(bundleIdentifier: "com.apple.TextEdit", events: duplicate).state == .blocked)
        #expect(evaluator.evaluate(bundleIdentifier: "com.apple.TextEdit", events: wrongInsertion).state == .blocked)
        #expect(evaluator.evaluate(bundleIdentifier: "com.apple.TextEdit", events: focusSteal).state == .blocked)
        #expect(evaluator.evaluate(bundleIdentifier: "com.apple.TextEdit", events: tabConflict).state == .blocked)
        #expect(evaluator.evaluate(bundleIdentifier: "com.apple.TextEdit", events: sensitiveField).state == .blocked)
        #expect(evaluator.evaluate(bundleIdentifier: "com.apple.TextEdit", events: unprovenSurface).state == .blocked)
    }

    @Test("Obsidian detached suppression is a caveat, but detached display is blocked")
    func obsidianDetachedSuppressionIsCaveatedButDetachedDisplayIsBlocked() {
        let caveatedEvents = cleanEvents(
            appBundleIdentifier: "md.obsidian",
            shown: 10,
            kept: 1,
            latency: 880
        ) + [
            event(
                .suggestionSuppressed,
                appBundleIdentifier: "md.obsidian",
                suggestionID: "detached-suppressed",
                reason: "detached-suggestion-disabled"
            )
        ]
        let blockedEvents = cleanEvents(
            appBundleIdentifier: "md.obsidian",
            shown: 10,
            kept: 1,
            latency: 880
        ) + [
            event(
                .suggestionPresented,
                appBundleIdentifier: "md.obsidian",
                suggestionID: "detached-shown",
                metadata: [
                    "effectiveRenderMode": "floatingMirror",
                    "hasCaretRect": "false"
                ]
            )
        ]

        let caveated = evaluator.evaluate(bundleIdentifier: "md.obsidian", events: caveatedEvents)
        let blocked = evaluator.evaluate(bundleIdentifier: "md.obsidian", events: blockedEvents)

        #expect(caveated.state == .caveated)
        #expect(caveated.reasons.contains("Detached suggestions were safely suppressed."))
        #expect(blocked.state == .blocked)
    }

    private func cleanEvents(
        appBundleIdentifier: String,
        shown: Int,
        kept: Int,
        latency: Int
    ) -> [AutocompleteTraceEvent] {
        var events: [AutocompleteTraceEvent] = []
        for index in 0..<shown {
            let suggestionID = "suggestion-\(index)"
            events.append(event(
                .suggestionPresented,
                appBundleIdentifier: appBundleIdentifier,
                suggestionID: suggestionID,
                latency: latency
            ))
            if index < kept {
                let acceptanceID = "accept-\(index)"
                events.append(event(
                    .suggestionAccepted,
                    appBundleIdentifier: appBundleIdentifier,
                    suggestionID: suggestionID,
                    metadata: ["acceptanceID": acceptanceID]
                ))
                events.append(event(
                    .insertionVerified,
                    appBundleIdentifier: appBundleIdentifier,
                    suggestionID: suggestionID,
                    metadata: ["acceptanceID": acceptanceID]
                ))
                events.append(event(
                    .acceptedTextEdited,
                    appBundleIdentifier: appBundleIdentifier,
                    suggestionID: suggestionID,
                    metadata: [
                        "acceptanceID": acceptanceID,
                        "checkpoint": "10s",
                        "survivalClass": "exactKept",
                        "strongAcceptedAndKept": "true"
                    ]
                ))
            }
        }
        return events
    }

    private func event(
        _ type: AutocompleteTraceEventType,
        appBundleIdentifier: String = "com.apple.TextEdit",
        suggestionID: String,
        reason: String = "",
        latency: Int? = nil,
        metadata: [String: String] = [:]
    ) -> AutocompleteTraceEvent {
        AutocompleteTraceEvent(
            timestamp: "2026-05-07T00:00:00Z",
            sessionID: "session",
            suggestionID: suggestionID,
            type: type,
            appBundleIdentifier: appBundleIdentifier,
            requestMode: "wordCompletion",
            latencyMilliseconds: latency,
            reason: reason,
            metadata: metadata
        )
    }
}
