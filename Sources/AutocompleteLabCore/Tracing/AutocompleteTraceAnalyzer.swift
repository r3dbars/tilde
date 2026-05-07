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
    public let insertionVerifiedCount: Int
    public let insertionVerificationSuccessRate: Double
    public let acceptedAndKeptCount: Int
    public let acceptedAndKeptRateAccepted: Double
    public let acceptedAndKeptRateShown: Double
    public let medianEditDistanceAfterAccept: Double?
    public let medianTimeUntilFirstEditAfterAcceptMilliseconds: Int?
    public let tabAcceptShare: Double
    public let fullAcceptShare: Double
    public let duplicateTextCount: Int
    public let appDisableCount: Int
    public let caretGeometryFailureCount: Int
    public let caretGeometryFailureRate: Double
    public let caretGeometryFailuresByApp: [String: Int]
    public let caretGeometryFailureRateByApp: [String: Double]
    public let caretGeometryFailuresByRenderMode: [String: Int]
    public let caretGeometryFailureRateByRenderMode: [String: Double]
    public let annoyanceScore: Double
    public let annoyanceSignalCounts: [String: Int]
    public let acceptRate: Double
    public let usefulRate: Double
    public let p50LatencyMilliseconds: Int?
    public let p90LatencyMilliseconds: Int?
    public let p95LatencyMilliseconds: Int?
    public let acceptRateByApp: [String: Double]
    public let acceptRateByMode: [String: Double]
    public let acceptRateByExperimentArm: [String: Double]
    public let usefulRateByApp: [String: Double]
    public let usefulRateByMode: [String: Double]
    public let usefulRateByExperimentArm: [String: Double]
    public let presentedByExperimentArm: [String: Int]
    public let acceptedAndKeptByExperimentArm: [String: Int]
    public let suppressedByExperimentArm: [String: Int]
    public let presentedByFieldKind: [String: Int]
    public let acceptedAndKeptByFieldKind: [String: Int]
    public let suppressedByFieldKind: [String: Int]
    public let suppressedByReason: [String: Int]
    public let suppressedByApp: [String: Int]
    public let suppressedByMode: [String: Int]
    public let actionableSuppressedByApp: [String: Int]
    public let actionableSuppressedByMode: [String: Int]
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
        insertionVerifiedCount: Int = 0,
        insertionVerificationSuccessRate: Double = 0,
        acceptedAndKeptCount: Int = 0,
        acceptedAndKeptRateAccepted: Double = 0,
        acceptedAndKeptRateShown: Double = 0,
        medianEditDistanceAfterAccept: Double? = nil,
        medianTimeUntilFirstEditAfterAcceptMilliseconds: Int? = nil,
        tabAcceptShare: Double = 0,
        fullAcceptShare: Double = 0,
        duplicateTextCount: Int = 0,
        appDisableCount: Int = 0,
        caretGeometryFailureCount: Int = 0,
        caretGeometryFailureRate: Double = 0,
        caretGeometryFailuresByApp: [String: Int] = [:],
        caretGeometryFailureRateByApp: [String: Double] = [:],
        caretGeometryFailuresByRenderMode: [String: Int] = [:],
        caretGeometryFailureRateByRenderMode: [String: Double] = [:],
        annoyanceScore: Double = 0,
        annoyanceSignalCounts: [String: Int] = [:],
        acceptRate: Double,
        usefulRate: Double,
        p50LatencyMilliseconds: Int?,
        p90LatencyMilliseconds: Int?,
        p95LatencyMilliseconds: Int?,
        acceptRateByApp: [String: Double] = [:],
        acceptRateByMode: [String: Double] = [:],
        acceptRateByExperimentArm: [String: Double] = [:],
        usefulRateByApp: [String: Double] = [:],
        usefulRateByMode: [String: Double] = [:],
        usefulRateByExperimentArm: [String: Double] = [:],
        presentedByExperimentArm: [String: Int] = [:],
        acceptedAndKeptByExperimentArm: [String: Int] = [:],
        suppressedByExperimentArm: [String: Int] = [:],
        presentedByFieldKind: [String: Int] = [:],
        acceptedAndKeptByFieldKind: [String: Int] = [:],
        suppressedByFieldKind: [String: Int] = [:],
        suppressedByReason: [String: Int] = [:],
        suppressedByApp: [String: Int] = [:],
        suppressedByMode: [String: Int] = [:],
        actionableSuppressedByApp: [String: Int] = [:],
        actionableSuppressedByMode: [String: Int] = [:],
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
        self.insertionVerifiedCount = insertionVerifiedCount
        self.insertionVerificationSuccessRate = insertionVerificationSuccessRate
        self.acceptedAndKeptCount = acceptedAndKeptCount
        self.acceptedAndKeptRateAccepted = acceptedAndKeptRateAccepted
        self.acceptedAndKeptRateShown = acceptedAndKeptRateShown
        self.medianEditDistanceAfterAccept = medianEditDistanceAfterAccept
        self.medianTimeUntilFirstEditAfterAcceptMilliseconds = medianTimeUntilFirstEditAfterAcceptMilliseconds
        self.tabAcceptShare = tabAcceptShare
        self.fullAcceptShare = fullAcceptShare
        self.duplicateTextCount = duplicateTextCount
        self.appDisableCount = appDisableCount
        self.caretGeometryFailureCount = caretGeometryFailureCount
        self.caretGeometryFailureRate = caretGeometryFailureRate
        self.caretGeometryFailuresByApp = caretGeometryFailuresByApp
        self.caretGeometryFailureRateByApp = caretGeometryFailureRateByApp
        self.caretGeometryFailuresByRenderMode = caretGeometryFailuresByRenderMode
        self.caretGeometryFailureRateByRenderMode = caretGeometryFailureRateByRenderMode
        self.annoyanceScore = annoyanceScore
        self.annoyanceSignalCounts = annoyanceSignalCounts
        self.acceptRate = acceptRate
        self.usefulRate = usefulRate
        self.p50LatencyMilliseconds = p50LatencyMilliseconds
        self.p90LatencyMilliseconds = p90LatencyMilliseconds
        self.p95LatencyMilliseconds = p95LatencyMilliseconds
        self.acceptRateByApp = acceptRateByApp
        self.acceptRateByMode = acceptRateByMode
        self.acceptRateByExperimentArm = acceptRateByExperimentArm
        self.usefulRateByApp = usefulRateByApp
        self.usefulRateByMode = usefulRateByMode
        self.usefulRateByExperimentArm = usefulRateByExperimentArm
        self.presentedByExperimentArm = presentedByExperimentArm
        self.acceptedAndKeptByExperimentArm = acceptedAndKeptByExperimentArm
        self.suppressedByExperimentArm = suppressedByExperimentArm
        self.presentedByFieldKind = presentedByFieldKind
        self.acceptedAndKeptByFieldKind = acceptedAndKeptByFieldKind
        self.suppressedByFieldKind = suppressedByFieldKind
        self.suppressedByReason = suppressedByReason
        self.suppressedByApp = suppressedByApp
        self.suppressedByMode = suppressedByMode
        self.actionableSuppressedByApp = actionableSuppressedByApp
        self.actionableSuppressedByMode = actionableSuppressedByMode
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
        let insertionVerified = events.filter { $0.type == .insertionVerified }
        let caretGeometryFailures = events.filter { $0.type == .caretGeometryFailed }
        let acceptedTextEdited = events.filter { $0.type == .acceptedTextEdited }
        let firstShownLatencies = firstPresentedByID.values.compactMap(\.latencyMilliseconds).sorted()
        let acceptedEventIDs = Set(accepted.map(acceptanceIdentifier))
        let acceptedAndKeptEventIDs = Set(acceptedTextEdited
            .filter(isAcceptedAndKeptEvent)
            .map(acceptanceIdentifier))
        let acceptedAndKeptSuggestionIDs = Set(acceptedTextEdited
            .filter(isAcceptedAndKeptEvent)
            .map(\.suggestionID))
            .intersection(presentedIDs)
        let editDistances = acceptedTextEdited
            .compactMap { doubleMetadata($0, key: "normalizedEditDistance") }
            .sorted()
        let firstEditDelays = acceptedTextEdited
            .compactMap { intMetadata($0, key: "firstEditDelayMs") }
            .sorted()
        let verifiedAndFailedCount = insertionVerified.count + insertionFailures.count
        let annoyanceSignals = annoyanceSignalCounts(from: events, presentedByID: firstPresentedByID)

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
            insertionVerifiedCount: insertionVerified.count,
            insertionVerificationSuccessRate: verifiedAndFailedCount == 0
                ? 0
                : Double(insertionVerified.count) / Double(verifiedAndFailedCount),
            acceptedAndKeptCount: acceptedAndKeptEventIDs.count,
            acceptedAndKeptRateAccepted: acceptedEventIDs.isEmpty
                ? 0
                : Double(acceptedAndKeptEventIDs.intersection(acceptedEventIDs).count) / Double(acceptedEventIDs.count),
            acceptedAndKeptRateShown: presentedIDs.isEmpty
                ? 0
                : Double(acceptedAndKeptSuggestionIDs.count) / Double(presentedIDs.count),
            medianEditDistanceAfterAccept: median(editDistances),
            medianTimeUntilFirstEditAfterAcceptMilliseconds: percentile(0.50, in: firstEditDelays),
            tabAcceptShare: accepted.isEmpty ? 0 : Double(accepted.filter(isTabAccept).count) / Double(accepted.count),
            fullAcceptShare: accepted.isEmpty ? 0 : Double(accepted.filter(isFullAccept).count) / Double(accepted.count),
            duplicateTextCount: insertionFailures.filter(isDuplicateTextEvent).count,
            appDisableCount: events.filter { $0.type == .appDisabled }.count,
            caretGeometryFailureCount: caretGeometryFailures.count,
            caretGeometryFailureRate: rate(
                numerator: caretGeometryFailures.count,
                denominator: firstPresentedByID.count + caretGeometryFailures.count
            ),
            caretGeometryFailuresByApp: counts(caretGeometryFailures, key: \.appBundleIdentifier),
            caretGeometryFailureRateByApp: failureRates(
                presented: Array(firstPresentedByID.values),
                failures: caretGeometryFailures,
                key: \.appBundleIdentifier
            ),
            caretGeometryFailuresByRenderMode: counts(caretGeometryFailures, key: renderMode),
            caretGeometryFailureRateByRenderMode: failureRates(
                presented: Array(firstPresentedByID.values),
                failures: caretGeometryFailures,
                key: renderMode
            ),
            annoyanceScore: annoyanceScore(signalCounts: annoyanceSignals, presentedCount: firstPresentedByID.count),
            annoyanceSignalCounts: annoyanceSignals,
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
            acceptRateByExperimentArm: rates(
                presentedByID: firstPresentedByID,
                outcomeIDs: acceptedIDs,
                key: experimentArm
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
            usefulRateByExperimentArm: rates(
                presentedByID: firstPresentedByID,
                outcomeIDs: usefulIDs,
                key: experimentArm
            ),
            presentedByExperimentArm: counts(Array(firstPresentedByID.values), key: experimentArm),
            acceptedAndKeptByExperimentArm: counts(
                acceptedTextEdited.filter(isAcceptedAndKeptEvent),
                key: experimentArm
            ),
            suppressedByExperimentArm: counts(suppressed, key: experimentArm),
            presentedByFieldKind: counts(Array(firstPresentedByID.values), key: fieldKind),
            acceptedAndKeptByFieldKind: counts(
                acceptedTextEdited.filter(isAcceptedAndKeptEvent),
                key: fieldKind
            ),
            suppressedByFieldKind: counts(suppressed, key: fieldKind),
            suppressedByReason: countsByReason(suppressed),
            suppressedByApp: counts(suppressed, key: \.appBundleIdentifier),
            suppressedByMode: counts(suppressed, key: \.requestMode),
            actionableSuppressedByApp: counts(actionableSuppressed, key: \.appBundleIdentifier),
            actionableSuppressedByMode: counts(actionableSuppressed, key: \.requestMode),
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

    private func fieldKind(_ event: AutocompleteTraceEvent) -> String {
        let kind = event.metadata["fieldKind"] ?? ""
        return kind.isEmpty ? "unknown" : kind
    }

    private func experimentArm(_ event: AutocompleteTraceEvent) -> String {
        let arm = event.experimentArm.isEmpty
            ? event.metadata["experimentArm"] ?? ""
            : event.experimentArm
        return arm.isEmpty ? "unknown" : arm
    }

    private func renderMode(_ event: AutocompleteTraceEvent) -> String {
        let mode = event.metadata["effectiveRenderMode"] ?? event.metadata["renderMode"] ?? ""
        return mode.isEmpty ? "unknown" : mode
    }

    private func acceptanceIdentifier(_ event: AutocompleteTraceEvent) -> String {
        event.metadata["acceptanceID"] ?? event.suggestionID
    }

    private func isAcceptedAndKeptEvent(_ event: AutocompleteTraceEvent) -> Bool {
        if event.metadata["strongAcceptedAndKept"] == "true"
            || event.metadata["finalAcceptedAndKept"] == "true" {
            return true
        }

        guard ["10s", "30s", "fieldBlur"].contains(event.metadata["checkpoint"] ?? "") else {
            return false
        }

        return ["exactKept", "lightlyEditedKept", "partiallyKept"].contains(event.metadata["survivalClass"] ?? "")
    }

    private func isTabAccept(_ event: AutocompleteTraceEvent) -> Bool {
        event.metadata["acceptMode"] == "tab" || event.outcome == "acceptNextWord"
    }

    private func isFullAccept(_ event: AutocompleteTraceEvent) -> Bool {
        event.metadata["acceptMode"] == "full" || event.outcome == "acceptAllVisible"
    }

    private func isDuplicateTextEvent(_ event: AutocompleteTraceEvent) -> Bool {
        event.metadata["duplicateDetected"] == "true"
            || event.reason.localizedCaseInsensitiveContains("duplicate")
            || event.outcome.localizedCaseInsensitiveContains("duplicate")
    }

    private func doubleMetadata(_ event: AutocompleteTraceEvent, key: String) -> Double? {
        guard let value = event.metadata[key] else {
            return nil
        }

        return Double(value)
    }

    private func intMetadata(_ event: AutocompleteTraceEvent, key: String) -> Int? {
        guard let value = event.metadata[key] else {
            return nil
        }

        return Int(value)
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

    private func rate(numerator: Int, denominator: Int) -> Double {
        denominator == 0 ? 0 : Double(numerator) / Double(denominator)
    }

    private func failureRates(
        presented: [AutocompleteTraceEvent],
        failures: [AutocompleteTraceEvent],
        key: (AutocompleteTraceEvent) -> String
    ) -> [String: Double] {
        let presentedCounts = counts(presented, key: key)
        let failureCounts = counts(failures, key: key)
        var rates: [String: Double] = [:]

        for bucket in Set(presentedCounts.keys).union(failureCounts.keys) {
            let failures = failureCounts[bucket] ?? 0
            let shown = presentedCounts[bucket] ?? 0
            rates[bucket] = rate(numerator: failures, denominator: shown + failures)
        }

        return rates
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

            if event.type == .acceptedTextEdited,
               event.metadata["survivalClass"] == AcceptanceSurvivalClass.rejectedAfterAccept.rawValue {
                let checkpoint = event.metadata["checkpoint"] ?? "unknown"
                add(
                    key: "Accepted text did not survive",
                    event: event,
                    cause: "Accepted text was gone or heavily edited by the \(checkpoint) checkpoint.",
                    category: "accepted-and-kept issue",
                    buckets: &buckets
                )
            }

            if event.type == .appDisabled {
                add(
                    key: "App disabled: \(event.appBundleIdentifier)",
                    event: event,
                    cause: "The user or auto-policy disabled suggestions in this app.",
                    category: "trust issue",
                    buckets: &buckets
                )
            }

            if event.type == .caretGeometryFailed {
                add(
                    key: "Caret geometry failed: \(event.reason)",
                    event: event,
                    cause: "The app could not place the suggestion reliably near the caret.",
                    category: "renderer/caret bug",
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
            .prefix(5)
            .map { $0 }
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

    private func annoyanceSignalCounts(
        from events: [AutocompleteTraceEvent],
        presentedByID: [String: AutocompleteTraceEvent]
    ) -> [String: Int] {
        var counts: [String: Int] = [:]

        func increment(_ signal: String) {
            counts[signal, default: 0] += 1
        }

        for event in events {
            switch event.type {
            case .insertionFailed:
                increment(isDuplicateTextEvent(event) ? "duplicateText" : "wrongInsertion")

            case .suggestionTypedOver:
                if let delay = intMetadata(event, key: "delayMs") {
                    if delay <= 1_000 {
                        increment("typedOverWithinOneSecond")
                    }
                } else {
                    increment("typedOver")
                }

            case .acceptedTextEdited:
                let rejected = event.metadata["survivalClass"] == AcceptanceSurvivalClass.rejectedAfterAccept.rawValue
                let fastDelete = (intMetadata(event, key: "firstEditDelayMs") ?? Int.max) <= 2_000
                    || event.metadata["checkpoint"] == AcceptanceSurvivalCheckpoint.twoSeconds.rawValue
                if rejected && fastDelete {
                    increment("acceptedThenDeleted")
                }

            case .suggestionHidden:
                if event.reason == "escape",
                   let presented = presentedByID[event.suggestionID],
                   let elapsed = millisecondsBetween(presented.timestamp, event.timestamp),
                   elapsed <= 700 {
                    increment("rapidEscDismissal")
                }

                if let lifetime = intMetadata(event, key: "lifetimeMs"), lifetime < 150 {
                    increment("overlayFlicker")
                }

            case .suggestionPresented:
                if ["search", "form", "url", "secure"].contains(event.metadata["fieldKind"] ?? "") {
                    increment("searchOrFormLeakage")
                }

            case .suggestionSuppressed:
                if event.reason == "repeated-miss" {
                    increment("repeatedRejection")
                }

                if event.reason == "tab-conflict" {
                    increment("tabConflict")
                }

            case .appPaused:
                increment("manualPause")

            case .appDisabled:
                increment("appDisable")

            case .caretGeometryFailed:
                increment("caretGeometryFailed")

            default:
                if event.metadata["focusStealing"] == "true" {
                    increment("focusStealing")
                }

                if event.metadata["tabConflict"] == "true" {
                    increment("tabConflict")
                }
            }
        }

        return counts
    }

    private func annoyanceScore(signalCounts: [String: Int], presentedCount: Int) -> Double {
        let weights: [String: Double] = [
            "wrongInsertion": 1.0,
            "duplicateText": 1.0,
            "focusStealing": 1.0,
            "tabConflict": 0.8,
            "rapidEscDismissal": 0.5,
            "typedOverWithinOneSecond": 0.4,
            "typedOver": 0.4,
            "acceptedThenDeleted": 0.7,
            "searchOrFormLeakage": 0.6,
            "overlayFlicker": 0.4,
            "repeatedRejection": 0.4,
            "manualPause": 1.0,
            "appDisable": 1.2,
            "caretGeometryFailed": 0.6
        ]

        let weightedTotal = signalCounts.reduce(0.0) { total, item in
            total + (weights[item.key] ?? 0.25) * Double(item.value)
        }

        return weightedTotal / Double(max(1, presentedCount))
    }

    private func millisecondsBetween(_ start: String, _ end: String) -> Int? {
        let formatter = ISO8601DateFormatter()
        guard let startDate = formatter.date(from: start),
              let endDate = formatter.date(from: end) else {
            return nil
        }

        return max(0, Int(endDate.timeIntervalSince(startDate) * 1_000))
    }

    private func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else {
            return nil
        }

        let middle = values.count / 2
        if values.count.isMultiple(of: 2) {
            return (values[middle - 1] + values[middle]) / 2
        }

        return values[middle]
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
