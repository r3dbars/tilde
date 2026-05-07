import Foundation

public struct AutocompleteTraceMiss: Equatable, Sendable {
    public let title: String
    public let count: Int
    public let exampleSuggestionID: String
    public let appBundleIdentifier: String
    public let requestMode: String
    public let suggestedCause: String
    public let fixCategory: String

    public init(
        title: String,
        count: Int,
        exampleSuggestionID: String,
        appBundleIdentifier: String = "",
        requestMode: String = "",
        suggestedCause: String,
        fixCategory: String
    ) {
        self.title = title
        self.count = count
        self.exampleSuggestionID = exampleSuggestionID
        self.appBundleIdentifier = appBundleIdentifier
        self.requestMode = requestMode
        self.suggestedCause = suggestedCause
        self.fixCategory = fixCategory
    }
}

public struct AutocompleteTraceSummary: Equatable, Sendable {
    public static let slowP95LatencyThresholdMilliseconds = 1_000

    public let totalEvents: Int
    public let presentedCount: Int
    public let acceptedCount: Int
    public let typedThroughCount: Int
    public let typedOverCount: Int
    public let ignoredCount: Int
    public let suppressedCount: Int
    public let actionableSuppressedCount: Int
    public let insertionFailureCount: Int
    public let acceptRate: Double
    public let usefulRate: Double
    public let p50LatencyMilliseconds: Int?
    public let p90LatencyMilliseconds: Int?
    public let p95LatencyMilliseconds: Int?
    public let acceptRateByApp: [String: Double]
    public let acceptRateByMode: [String: Double]
    public let usefulRateByApp: [String: Double]
    public let usefulRateByMode: [String: Double]
    public let suppressedByReason: [String: Int]
    public let suppressedByApp: [String: Int]
    public let suppressedByMode: [String: Int]
    public let actionableSuppressedByApp: [String: Int]
    public let actionableSuppressedByMode: [String: Int]
    public let annoyanceCounters: [String: Int]
    public let doNotShipCounters: [String: Int]
    public let topMisses: [AutocompleteTraceMiss]

    public init(
        totalEvents: Int,
        presentedCount: Int,
        acceptedCount: Int,
        typedThroughCount: Int,
        typedOverCount: Int,
        ignoredCount: Int,
        suppressedCount: Int = 0,
        actionableSuppressedCount: Int = 0,
        insertionFailureCount: Int,
        acceptRate: Double,
        usefulRate: Double,
        p50LatencyMilliseconds: Int?,
        p90LatencyMilliseconds: Int?,
        p95LatencyMilliseconds: Int?,
        acceptRateByApp: [String: Double] = [:],
        acceptRateByMode: [String: Double] = [:],
        usefulRateByApp: [String: Double] = [:],
        usefulRateByMode: [String: Double] = [:],
        suppressedByReason: [String: Int] = [:],
        suppressedByApp: [String: Int] = [:],
        suppressedByMode: [String: Int] = [:],
        actionableSuppressedByApp: [String: Int] = [:],
        actionableSuppressedByMode: [String: Int] = [:],
        annoyanceCounters: [String: Int] = [:],
        doNotShipCounters: [String: Int] = [:],
        topMisses: [AutocompleteTraceMiss]
    ) {
        self.totalEvents = totalEvents
        self.presentedCount = presentedCount
        self.acceptedCount = acceptedCount
        self.typedThroughCount = typedThroughCount
        self.typedOverCount = typedOverCount
        self.ignoredCount = ignoredCount
        self.suppressedCount = suppressedCount
        self.actionableSuppressedCount = actionableSuppressedCount
        self.insertionFailureCount = insertionFailureCount
        self.acceptRate = acceptRate
        self.usefulRate = usefulRate
        self.p50LatencyMilliseconds = p50LatencyMilliseconds
        self.p90LatencyMilliseconds = p90LatencyMilliseconds
        self.p95LatencyMilliseconds = p95LatencyMilliseconds
        self.acceptRateByApp = acceptRateByApp
        self.acceptRateByMode = acceptRateByMode
        self.usefulRateByApp = usefulRateByApp
        self.usefulRateByMode = usefulRateByMode
        self.suppressedByReason = suppressedByReason
        self.suppressedByApp = suppressedByApp
        self.suppressedByMode = suppressedByMode
        self.actionableSuppressedByApp = actionableSuppressedByApp
        self.actionableSuppressedByMode = actionableSuppressedByMode
        self.annoyanceCounters = annoyanceCounters
        self.doNotShipCounters = doNotShipCounters
        self.topMisses = topMisses
    }
}

public struct AutocompleteTraceAnalyzer: Equatable, Sendable {
    public init() {}

    public func summary(for events: [AutocompleteTraceEvent]) -> AutocompleteTraceSummary {
        let presented = events.filter { $0.type == .suggestionPresented }
        let firstPresentedByID = firstEventsBySuggestionID(from: presented)
        let accepted = events.filter { $0.type == .suggestionAccepted }
        let presentedIDs = Set(firstPresentedByID.keys)
        let acceptedIDs = Set(accepted.map(\.suggestionID)).intersection(presentedIDs)
        let typedThroughIDs = Set(events
            .filter { $0.type == .suggestionHidden && $0.outcome == "typed-through" }
            .map(\.suggestionID))
            .intersection(presentedIDs)
        let usefulIDs = acceptedIDs.union(typedThroughIDs)
        let typedOver = events.filter { $0.type == .suggestionTypedOver }
        let hiddenIgnored = events.filter { $0.type == .suggestionHidden && $0.outcome == "ignored" }
        let suppressed = events.filter { $0.type == .suggestionSuppressed }
        let actionableSuppressed = suppressed.filter { isActionableSuppression($0) }
        let insertionFailures = events.filter { $0.type == .insertionFailed }
        let firstShownLatencies = firstPresentedByID.values.compactMap(\.latencyMilliseconds).sorted()
        let p95LatencyMilliseconds = percentile(0.95, in: firstShownLatencies)

        return AutocompleteTraceSummary(
            totalEvents: events.count,
            presentedCount: firstPresentedByID.count,
            acceptedCount: accepted.count,
            typedThroughCount: typedThroughIDs.count,
            typedOverCount: typedOver.count,
            ignoredCount: hiddenIgnored.count,
            suppressedCount: suppressed.count,
            actionableSuppressedCount: actionableSuppressed.count,
            insertionFailureCount: insertionFailures.count,
            acceptRate: presentedIDs.isEmpty ? 0 : Double(acceptedIDs.count) / Double(presentedIDs.count),
            usefulRate: presentedIDs.isEmpty ? 0 : Double(usefulIDs.count) / Double(presentedIDs.count),
            p50LatencyMilliseconds: percentile(0.50, in: firstShownLatencies),
            p90LatencyMilliseconds: percentile(0.90, in: firstShownLatencies),
            p95LatencyMilliseconds: p95LatencyMilliseconds,
            acceptRateByApp: rates(
                presentedByID: firstPresentedByID,
                outcomeIDs: acceptedIDs,
                key: \.appBundleIdentifier
            ),
            acceptRateByMode: rates(
                presentedByID: firstPresentedByID,
                outcomeIDs: acceptedIDs,
                key: \.requestMode
            ),
            usefulRateByApp: rates(
                presentedByID: firstPresentedByID,
                outcomeIDs: usefulIDs,
                key: \.appBundleIdentifier
            ),
            usefulRateByMode: rates(
                presentedByID: firstPresentedByID,
                outcomeIDs: usefulIDs,
                key: \.requestMode
            ),
            suppressedByReason: countsByReason(suppressed),
            suppressedByApp: counts(suppressed, key: \.appBundleIdentifier),
            suppressedByMode: counts(suppressed, key: \.requestMode),
            actionableSuppressedByApp: counts(actionableSuppressed, key: \.appBundleIdentifier),
            actionableSuppressedByMode: counts(actionableSuppressed, key: \.requestMode),
            annoyanceCounters: annoyanceCounters(
                from: events,
                insertionFailures: insertionFailures,
                p95LatencyMilliseconds: p95LatencyMilliseconds
            ),
            doNotShipCounters: doNotShipCounters(
                from: events,
                insertionFailures: insertionFailures,
                p95LatencyMilliseconds: p95LatencyMilliseconds
            ),
            topMisses: topMisses(from: events)
        )
    }

    private func firstEventsBySuggestionID(
        from events: [AutocompleteTraceEvent]
    ) -> [String: AutocompleteTraceEvent] {
        var eventsByID: [String: AutocompleteTraceEvent] = [:]
        for event in events where eventsByID[event.suggestionID] == nil {
            eventsByID[event.suggestionID] = event
        }
        return eventsByID
    }

    private func countsByReason(_ events: [AutocompleteTraceEvent]) -> [String: Int] {
        counts(events) { event in
            event.reason.isEmpty ? "unknown" : event.reason
        }
    }

    private func counts(
        _ events: [AutocompleteTraceEvent],
        key: (AutocompleteTraceEvent) -> String
    ) -> [String: Int] {
        Dictionary(grouping: events) { event in
            let bucket = key(event)
            return bucket.isEmpty ? "unknown" : bucket
        }
        .mapValues(\.count)
    }

    private func isActionableSuppression(_ event: AutocompleteTraceEvent) -> Bool {
        event.reason != "no-fast-word-candidate"
    }

    private func annoyanceCounters(
        from events: [AutocompleteTraceEvent],
        insertionFailures: [AutocompleteTraceEvent],
        p95LatencyMilliseconds: Int?
    ) -> [String: Int] {
        var counters: [String: Int] = [:]
        let hidden = events.filter { $0.type == .suggestionHidden }
        let suppressed = events.filter { $0.type == .suggestionSuppressed }

        setCount(hidden.filter { $0.reason == "escape" }.count, for: "escape-snooze", in: &counters)
        setCount(hidden.filter { $0.outcome == "ignored" }.count, for: "hidden-ignored", in: &counters)
        setCount(hidden.filter { $0.outcome == "typed-over" }.count, for: "hidden-typed-over", in: &counters)
        setCount(events.filter { $0.type == .suggestionTypedOver }.count, for: "typed-over", in: &counters)
        setCount(insertionFailures.count, for: "insertion-failed", in: &counters)
        setCount(repeatedUnacceptedSuggestionCount(from: events), for: "repeated-unaccepted", in: &counters)
        setCount(suppressed.filter { $0.reason == "repeated-miss" }.count, for: "repeated-suppression", in: &counters)
        setCount(hidden.filter { (integerMetadata("visibleMilliseconds", in: $0) ?? Int.max) < 500 }.count, for: "quick-hide-under-500ms", in: &counters)
        setCount(suppressed.filter(isAppDisabledSuppression).count, for: "app-disabled", in: &counters)
        setCount(suppressed.filter(isUnsupportedSignal).count, for: "unsupported-suppression", in: &counters)
        setCount(suppressed.filter(isSensitiveSignal).count, for: "sensitive-suppression", in: &counters)
        setCount(suppressed.filter(isDetachedSuppression).count, for: "detached-suppression", in: &counters)
        setCount(isSlowP95(p95LatencyMilliseconds) ? 1 : 0, for: "slow-p95", in: &counters)

        return counters
    }

    private func doNotShipCounters(
        from events: [AutocompleteTraceEvent],
        insertionFailures: [AutocompleteTraceEvent],
        p95LatencyMilliseconds: Int?
    ) -> [String: Int] {
        var counters: [String: Int] = [:]
        let presented = events.filter { $0.type == .suggestionPresented }

        setCount(insertionFailures.count, for: "insertion-failed", in: &counters)
        setCount(presented.filter(isUnsupportedSignal).count, for: "unsupported-app-presentation", in: &counters)
        setCount(presented.filter(isSecureSignal).count, for: "secure-field-presentation", in: &counters)
        setCount(presented.filter(isSensitiveSignal).count, for: "sensitive-field-presentation", in: &counters)
        setCount(presented.filter(isDetachedPresentation).count, for: "detached-suggestion-shown", in: &counters)
        setCount(presented.filter(isMockRuntimeFallback).count, for: "mock-runtime-fallback", in: &counters)
        setCount(isSlowP95(p95LatencyMilliseconds) ? 1 : 0, for: "slow-p95", in: &counters)

        return counters
    }

    private func setCount(_ count: Int, for key: String, in counters: inout [String: Int]) {
        guard count > 0 else {
            return
        }

        counters[key] = count
    }

    private func rates(
        presentedByID: [String: AutocompleteTraceEvent],
        outcomeIDs: Set<String>,
        key: (AutocompleteTraceEvent) -> String
    ) -> [String: Double] {
        let outcomePresented = presentedByID
            .filter { outcomeIDs.contains($0.key) }
            .map(\.value)
        let presentedCounts = Dictionary(grouping: Array(presentedByID.values), by: key)
            .mapValues(\.count)
        let outcomeCounts = Dictionary(grouping: outcomePresented, by: key)
            .mapValues(\.count)

        var rates: [String: Double] = [:]
        for (bucket, presentedCount) in presentedCounts where presentedCount > 0 {
            let normalizedBucket = bucket.isEmpty ? "unknown" : bucket
            rates[normalizedBucket] = Double(outcomeCounts[bucket] ?? 0) / Double(presentedCount)
        }
        return rates
    }

    private func topMisses(from events: [AutocompleteTraceEvent]) -> [AutocompleteTraceMiss] {
        var buckets: [String: (count: Int, example: AutocompleteTraceEvent, cause: String, category: String)] = [:]
        addRepeatedUnacceptedSuggestions(from: events, buckets: &buckets)

        for event in events {
            if event.type == .suggestionTypedOver {
                let typedSuffix = event.metadata["typedSuffix"]?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let title: String
                if typedSuffix.isEmpty {
                    title = "Typed over: \(event.displayedText)"
                } else {
                    title = "Typed over: \(event.displayedText) -> \(typedSuffix)"
                }

                add(
                    key: title,
                    event: event,
                    cause: typedSuffix.isEmpty
                        ? "The visible suggestion did not match what the user typed next."
                        : "The visible suggestion did not match the next typed text: \(typedSuffix).",
                    category: "word-completion issue",
                    buckets: &buckets
                )
            }

            if event.type == .suggestionHidden, event.outcome == "ignored" {
                add(
                    key: "Ignored: \(event.displayedText)",
                    event: event,
                    cause: "The suggestion stayed visible but was not accepted.",
                    category: "prompt issue",
                    buckets: &buckets
                )
            }

            if event.type == .modelResult,
               event.requestMode == "wordCompletion",
               event.cleanedVisibleText.contains(where: { $0.isWhitespace }) {
                add(
                    key: "Word mode returned phrase",
                    event: event,
                    cause: "Word-completion mode produced multi-word output.",
                    category: "output cleaning issue",
                    buckets: &buckets
                )
            }

            if event.type == .modelResult,
               event.rawOutput.localizedCaseInsensitiveContains("<think>") {
                add(
                    key: "Model leaked thinking text",
                    event: event,
                    cause: "The model output cleaner had to handle thinking markup.",
                    category: "output cleaning issue",
                    buckets: &buckets
                )
            }

            if event.type == .modelResult,
               looksLikeAssistantStyleCompletion(event.cleanedVisibleText.isEmpty ? event.rawOutput : event.cleanedVisibleText) {
                add(
                    key: "Assistant-style completion",
                    event: event,
                    cause: "The model returned a chat-assistant reply instead of text the user would type.",
                    category: "output cleaning issue",
                    buckets: &buckets
                )
            }

            if event.type == .insertionFailed {
                add(
                    key: "Insertion failed: \(event.reason)",
                    event: event,
                    cause: "The app did not verify the accepted text after insertion.",
                    category: "insertion bug",
                    buckets: &buckets
                )
            }

            if event.type == .suggestionSuppressed,
               event.reason == "detached-suggestion-disabled" {
                add(
                    key: "Detached suggestions suppressed in \(event.appBundleIdentifier)",
                    event: event,
                    cause: "The target app did not expose reliable caret bounds, so the app refused to show a detached suggestion.",
                    category: "renderer/caret bug",
                    buckets: &buckets
                )
            }

            if event.type == .suggestionPresented,
               isDetachedPresentation(event) {
                add(
                    key: "Detached suggestion shown in \(event.appBundleIdentifier)",
                    event: event,
                    cause: "A floating suggestion was shown from a whole-field or window anchor instead of a caret anchor.",
                    category: "renderer/caret bug",
                    buckets: &buckets
                )
            }

            if event.type == .suggestionPresented,
               isUnsupportedSignal(event) {
                add(
                    key: "Unsupported app presentation in \(event.appBundleIdentifier)",
                    event: event,
                    cause: "A suggestion was shown in an app marked unsupported.",
                    category: "do-not-ship",
                    buckets: &buckets
                )
            }

            if event.type == .suggestionPresented,
               isSecureSignal(event) || isSensitiveSignal(event) {
                add(
                    key: "Sensitive field presentation in \(event.appBundleIdentifier)",
                    event: event,
                    cause: "A suggestion was shown where secure or sensitive text was signaled.",
                    category: "do-not-ship",
                    buckets: &buckets
                )
            }

            if event.type == .suggestionPresented,
               isMockRuntimeFallback(event) {
                add(
                    key: "Mock runtime fallback",
                    event: event,
                    cause: "A suggestion was shown while trace metadata said the runtime was using a mock fallback.",
                    category: "do-not-ship",
                    buckets: &buckets
                )
            }

            if event.type == .suggestionPresented,
               let latencyMilliseconds = event.latencyMilliseconds,
               latencyMilliseconds >= 1_000 {
                add(
                    key: "Slow suggestion: \(event.requestMode)",
                    event: event,
                    cause: "The suggestion arrived after \(latencyMilliseconds) ms, which is too late for fluid typing.",
                    category: "model latency issue",
                    buckets: &buckets
                )
            }
        }

        addSlowP95Miss(from: events, buckets: &buckets)

        return buckets
            .map { key, value in
                AutocompleteTraceMiss(
                    title: key,
                    count: value.count,
                    exampleSuggestionID: value.example.suggestionID,
                    appBundleIdentifier: value.example.appBundleIdentifier,
                    requestMode: value.example.requestMode,
                    suggestedCause: value.cause,
                    fixCategory: value.category
                )
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.title < rhs.title
                }

                return lhs.count > rhs.count
            }
            .prefix(5)
            .map { $0 }
    }

    private func addSlowP95Miss(
        from events: [AutocompleteTraceEvent],
        buckets: inout [String: (count: Int, example: AutocompleteTraceEvent, cause: String, category: String)]
    ) {
        let presented = Array(firstEventsBySuggestionID(from: events.filter { $0.type == .suggestionPresented }).values)
        let latencies = presented.compactMap(\.latencyMilliseconds).sorted()
        guard let p95LatencyMilliseconds = percentile(0.95, in: latencies),
              isSlowP95(p95LatencyMilliseconds),
              let example = presented.max(by: { ($0.latencyMilliseconds ?? 0) < ($1.latencyMilliseconds ?? 0) })
        else {
            return
        }

        add(
            key: "Slow p95: \(p95LatencyMilliseconds) ms",
            event: example,
            cause: "The session p95 suggestion latency was \(p95LatencyMilliseconds) ms.",
            category: "model latency issue",
            buckets: &buckets
        )
    }

    private func addRepeatedUnacceptedSuggestions(
        from events: [AutocompleteTraceEvent],
        buckets: inout [String: (count: Int, example: AutocompleteTraceEvent, cause: String, category: String)]
    ) {
        let presentedByID = firstEventsBySuggestionID(from: events.filter { $0.type == .suggestionPresented })
        let usefulSuggestionIDs = Set(events
            .filter { $0.type == .suggestionAccepted || ($0.type == .suggestionHidden && $0.outcome == "typed-through") }
            .map(\.suggestionID))
        let repeated = Dictionary(grouping: presentedByID.values) { event in
            "\(event.requestMode)|\(normalizedSuggestionText(event.displayedText))"
        }

        for (_, suggestions) in repeated {
            let unacceptedSuggestions = suggestions.filter { !usefulSuggestionIDs.contains($0.suggestionID) }
            guard unacceptedSuggestions.count >= 3,
                  let example = unacceptedSuggestions.first,
                  !normalizedSuggestionText(example.displayedText).isEmpty
            else {
                continue
            }

            let repeatedText = normalizedSuggestionText(example.displayedText)
            let appCounts = Dictionary(grouping: unacceptedSuggestions, by: \.appBundleIdentifier)
                .mapValues(\.count)
            let topApp = appCounts.max { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key > rhs.key
                }

                return lhs.value < rhs.value
            }
            let appSummary = topApp.map { app, count in
                " Mostly in \(app.isEmpty ? "unknown app" : app) (\(count)/\(unacceptedSuggestions.count))."
            } ?? ""
            let title = "Repeated unaccepted: \(repeatedText)"
            add(
                key: title,
                event: example,
                cause: "The same \(example.requestMode) suggestion was shown \(unacceptedSuggestions.count) times without being accepted.\(appSummary)",
                category: example.requestMode == "wordCompletion" ? "word-completion issue" : "prompt issue",
                buckets: &buckets
            )

            if var existing = buckets[title] {
                existing.count = max(existing.count, unacceptedSuggestions.count)
                buckets[title] = existing
            }
        }
    }

    private func repeatedUnacceptedSuggestionCount(from events: [AutocompleteTraceEvent]) -> Int {
        let presentedByID = firstEventsBySuggestionID(from: events.filter { $0.type == .suggestionPresented })
        let usefulSuggestionIDs = Set(events
            .filter { $0.type == .suggestionAccepted || ($0.type == .suggestionHidden && $0.outcome == "typed-through") }
            .map(\.suggestionID))
        let repeated = Dictionary(grouping: presentedByID.values) { event in
            "\(event.requestMode)|\(normalizedSuggestionText(event.displayedText))"
        }

        return repeated.values.reduce(0) { total, suggestions in
            let unacceptedSuggestions = suggestions.filter { !usefulSuggestionIDs.contains($0.suggestionID) }
            guard unacceptedSuggestions.count >= 3,
                  let example = unacceptedSuggestions.first,
                  !normalizedSuggestionText(example.displayedText).isEmpty
            else {
                return total
            }

            return total + unacceptedSuggestions.count
        }
    }

    private func isSlowP95(_ latencyMilliseconds: Int?) -> Bool {
        guard let latencyMilliseconds else {
            return false
        }

        return latencyMilliseconds >= AutocompleteTraceSummary.slowP95LatencyThresholdMilliseconds
    }

    private func isDetachedSuppression(_ event: AutocompleteTraceEvent) -> Bool {
        event.reason == "detached-suggestion-disabled"
    }

    private func isDetachedPresentation(_ event: AutocompleteTraceEvent) -> Bool {
        event.metadata["effectiveRenderMode"] == "floatingMirror"
            && event.metadata["hasCaretRect"] == "false"
    }

    private func isAppDisabledSuppression(_ event: AutocompleteTraceEvent) -> Bool {
        signalText(for: event).contains("app-disabled")
            || signalText(for: event).contains("per-app-disabled")
            || signalText(for: event).contains("disabled-app")
    }

    private func isUnsupportedSignal(_ event: AutocompleteTraceEvent) -> Bool {
        signalText(for: event).contains("unsupported")
            || signalText(for: event).contains("profile-diagnostics-only")
    }

    private func isSensitiveSignal(_ event: AutocompleteTraceEvent) -> Bool {
        signalText(for: event).contains("sensitive")
            || event.metadata["isSensitive"] == "true"
    }

    private func isSecureSignal(_ event: AutocompleteTraceEvent) -> Bool {
        signalText(for: event).contains("secure-field")
            || signalText(for: event).contains("secure")
            || event.metadata["isSecure"] == "true"
    }

    private func isMockRuntimeFallback(_ event: AutocompleteTraceEvent) -> Bool {
        let text = signalText(for: event)
        return event.metadata["runtimeCandidate"] == "mock"
            || event.metadata["activeRuntime"] == "mock"
            || event.metadata["runtime"] == "mock"
            || (text.contains("mock") && text.contains("fallback"))
    }

    private func integerMetadata(_ key: String, in event: AutocompleteTraceEvent) -> Int? {
        event.metadata[key].flatMap(Int.init)
    }

    private func signalText(for event: AutocompleteTraceEvent) -> String {
        (
            [
                event.reason,
                event.outcome,
                event.triggerReason,
                event.appBundleIdentifier
            ] + event.metadata.flatMap { key, value in [key, value] }
        )
        .joined(separator: " ")
        .lowercased()
    }

    private func normalizedSuggestionText(_ text: String) -> String {
        text
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func looksLikeAssistantStyleCompletion(_ text: String) -> Bool {
        let normalized = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized.hasPrefix("i will do that")
            || normalized.hasPrefix("i'll do that")
            || normalized.hasPrefix("let me know")
            || normalized.hasPrefix("sure,")
            || normalized.hasPrefix("certainly,")
    }

    private func add(
        key: String,
        event: AutocompleteTraceEvent,
        cause: String,
        category: String,
        buckets: inout [String: (count: Int, example: AutocompleteTraceEvent, cause: String, category: String)]
    ) {
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else {
            return
        }

        if var existing = buckets[normalizedKey] {
            existing.count += 1
            buckets[normalizedKey] = existing
        } else {
            buckets[normalizedKey] = (1, event, cause, category)
        }
    }

    private func percentile(_ percentile: Double, in values: [Int]) -> Int? {
        guard !values.isEmpty else {
            return nil
        }

        let index = min(
            values.count - 1,
            max(0, Int((Double(values.count - 1) * percentile).rounded(.up)))
        )
        return values[index]
    }
}
