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
    public let anchorQualityByApp: [String: [String: Int]]
    public let insertionModeByApp: [String: [String: Int]]
    public let insertionFailuresByAppAndMode: [String: [String: Int]]
    public let updateSourceByApp: [String: [String: Int]]
    public let axFailureReasonByApp: [String: [String: Int]]
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
        anchorQualityByApp: [String: [String: Int]] = [:],
        insertionModeByApp: [String: [String: Int]] = [:],
        insertionFailuresByAppAndMode: [String: [String: Int]] = [:],
        updateSourceByApp: [String: [String: Int]] = [:],
        axFailureReasonByApp: [String: [String: Int]] = [:],
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
        self.anchorQualityByApp = anchorQualityByApp
        self.insertionModeByApp = insertionModeByApp
        self.insertionFailuresByAppAndMode = insertionFailuresByAppAndMode
        self.updateSourceByApp = updateSourceByApp
        self.axFailureReasonByApp = axFailureReasonByApp
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
            p95LatencyMilliseconds: percentile(0.95, in: firstShownLatencies),
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
            anchorQualityByApp: countsByAppAndMetadata(events, keys: ["anchorQuality", "caretQuality", "geometryQuality"]),
            insertionModeByApp: countsByAppAndMetadata(
                events,
                keys: ["actualInsertionMode", "profileInsertionMode", "insertionMode"]
            ),
            insertionFailuresByAppAndMode: countsByAppAndMetadata(
                insertionFailures,
                keys: ["actualInsertionMode", "profileInsertionMode", "insertionMode"],
                fallback: \.requestMode
            ),
            updateSourceByApp: countsByAppAndMetadata(
                events,
                keys: ["updateSource", "refreshSource", "geometryUpdateSource"]
            ),
            axFailureReasonByApp: countsByAppAndMetadata(
                events,
                keys: ["axFailureReason", "geometryReason", "caretInvalidReason"]
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

    private func countsByAppAndMetadata(
        _ events: [AutocompleteTraceEvent],
        keys: [String],
        fallback: ((AutocompleteTraceEvent) -> String)? = nil
    ) -> [String: [String: Int]] {
        var result: [String: [String: Int]] = [:]

        for event in events {
            let bucket = rawMetadataValue(event, keys: keys) ?? fallback?(event)
            guard let bucket, !bucket.isEmpty else {
                continue
            }

            let app = event.appBundleIdentifier.isEmpty ? "unknown" : event.appBundleIdentifier
            result[app, default: [:]][bucket, default: 0] += 1
        }

        return result
    }

    private func isActionableSuppression(_ event: AutocompleteTraceEvent) -> Bool {
        event.reason != "no-fast-word-candidate"
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
               event.metadata["effectiveRenderMode"] == "floatingMirror",
               event.metadata["hasCaretRect"] == "false" {
                add(
                    key: "Detached suggestion shown in \(event.appBundleIdentifier)",
                    event: event,
                    cause: "A floating suggestion was shown from a whole-field or window anchor instead of a caret anchor.",
                    category: "renderer/caret bug",
                    buckets: &buckets
                )
            }

            if isCaretUnavailable(event) {
                add(
                    key: "Caret unavailable in \(appName(for: event))",
                    event: event,
                    cause: "No caret anchor was available, so the app had to suppress the suggestion or fall back to a less precise anchor.",
                    category: "renderer/caret bug",
                    buckets: &buckets
                )
            }

            if isCaretInvalid(event) {
                add(
                    key: "Caret invalid in \(appName(for: event))",
                    event: event,
                    cause: "Caret geometry was rejected by validation. Reason: \(geometryReason(for: event)).",
                    category: "renderer/caret bug",
                    buckets: &buckets
                )
            }

            if anchorSource(for: event) == "field" {
                add(
                    key: "Field anchor used in \(appName(for: event))",
                    event: event,
                    cause: "The suggestion used the focused field bounds instead of a caret or line anchor.",
                    category: "renderer/caret bug",
                    buckets: &buckets
                )
            }

            if anchorSource(for: event) == "window" {
                add(
                    key: "Window anchor used in \(appName(for: event))",
                    event: event,
                    cause: "The suggestion used window bounds, which is only safe for diagnostics or explicit invocation.",
                    category: "renderer/caret bug",
                    buckets: &buckets
                )
            }

            if isObserverMissedUpdate(event) {
                add(
                    key: "Observer missed update in \(appName(for: event))",
                    event: event,
                    cause: "A poll or fallback refresh noticed a change that the Accessibility observer should have delivered.",
                    category: "observer/update bug",
                    buckets: &buckets
                )
            }

            if isPollRecoveredUpdate(event) {
                add(
                    key: "Poll recovered update in \(appName(for: event))",
                    event: event,
                    cause: "Polling recovered the typing or geometry state after an observer miss.",
                    category: "observer/update bug",
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
            .prefix(10)
            .map { $0 }
    }

    private func isCaretUnavailable(_ event: AutocompleteTraceEvent) -> Bool {
        metadataValue(event, keys: ["hasCaretRect", "caretAvailable"]) == "false"
            || reasonContains(event, "caret-unavailable")
            || reasonContains(event, "missing-caret")
            || reasonContains(event, "missing-anchor")
    }

    private func isCaretInvalid(_ event: AutocompleteTraceEvent) -> Bool {
        metadataValue(event, keys: ["anchorQuality", "caretQuality", "geometryQuality"]) == "invalid"
            || metadataValue(event, keys: ["caretInvalid", "invalidCaret"]) == "true"
            || reasonContains(event, "caret-invalid")
            || invalidGeometryReasons.contains(geometryReason(for: event))
    }

    private var invalidGeometryReasons: Set<String> {
        [
            "zeroheight",
            "nonfinite",
            "outsideelement",
            "outsidewindow",
            "offscreen",
            "stale",
            "jumpedtoofar",
            "missingbounds"
        ]
    }

    private func anchorSource(for event: AutocompleteTraceEvent) -> String {
        if let source = metadataValue(
            event,
            keys: ["anchorSource", "effectiveAnchorSource", "fallbackAnchorSource", "suggestionAnchorSource"]
        ) {
            return source
        }

        if reasonContains(event, "field-anchor") {
            return "field"
        }

        if reasonContains(event, "window-anchor") {
            return "window"
        }

        if event.type == .suggestionPresented,
           event.metadata["effectiveRenderMode"] == "floatingMirror",
           event.metadata["hasCaretRect"] == "false" {
            if event.metadata["hasElementRect"] == "true" {
                return "field"
            }

            if event.metadata["hasWindowRect"] == "true" {
                return "window"
            }
        }

        return ""
    }

    private func isObserverMissedUpdate(_ event: AutocompleteTraceEvent) -> Bool {
        metadataValue(event, keys: ["observerMissedUpdate", "observerMissed"]) == "true"
            || reasonContains(event, "observer-missed")
            || (
                metadataValue(event, keys: ["expectedUpdateSource", "expectedSource"]) == "observer"
                    && updateSource(for: event).contains("poll")
            )
    }

    private func isPollRecoveredUpdate(_ event: AutocompleteTraceEvent) -> Bool {
        metadataValue(event, keys: ["pollRecoveredUpdate", "pollRecovered"]) == "true"
            || reasonContains(event, "poll-recovered")
            || (
                updateSource(for: event).contains("poll")
                    && isObserverMissedUpdate(event)
            )
    }

    private func updateSource(for event: AutocompleteTraceEvent) -> String {
        metadataValue(event, keys: ["updateSource", "refreshSource", "geometryUpdateSource"]) ?? ""
    }

    private func geometryReason(for event: AutocompleteTraceEvent) -> String {
        let reason = metadataValue(
            event,
            keys: ["geometryReason", "anchorReason", "fallbackReason", "caretInvalidReason", "axFailureReason"]
        ) ?? event.reason

        return normalizedToken(reason)
    }

    private func metadataValue(_ event: AutocompleteTraceEvent, keys: [String]) -> String? {
        for key in keys {
            if let value = event.metadata[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return normalizedToken(value)
            }
        }

        return nil
    }

    private func rawMetadataValue(_ event: AutocompleteTraceEvent, keys: [String]) -> String? {
        for key in keys {
            if let value = event.metadata[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }

        return nil
    }

    private func reasonContains(_ event: AutocompleteTraceEvent, _ token: String) -> Bool {
        normalizedToken(event.reason).contains(normalizedToken(token))
    }

    private func normalizedToken(_ text: String) -> String {
        text
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private func appName(for event: AutocompleteTraceEvent) -> String {
        event.appBundleIdentifier.isEmpty ? "unknown app" : event.appBundleIdentifier
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
