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

public struct AutocompleteTraceFailureReason: Equatable, Sendable {
    public let title: String
    public let count: Int
    public let priority: Int
    public let category: String

    public init(title: String, count: Int, priority: Int, category: String) {
        self.title = title
        self.count = count
        self.priority = priority
        self.category = category
    }
}

public struct AutocompleteRecommendedFix: Equatable, Sendable {
    public let title: String
    public let reason: String
    public let priority: Int

    public init(title: String, reason: String, priority: Int) {
        self.title = title
        self.reason = reason
        self.priority = priority
    }
}

public struct AutocompleteTraceSummary: Equatable, Sendable {
    public let totalEvents: Int
    public let presentedCount: Int
    public let acceptedCount: Int
    public let typedThroughCount: Int
    public let typeThroughSurvivalRate: Double
    public let typedOverCount: Int
    public let suppressedCount: Int
    public let actionableSuppressedCount: Int
    public let insertionVerificationSuccessRate: Double
    public let acceptedAndKeptCount: Int
    public let acceptedAndKeptRateAccepted: Double
    public let acceptedAndKeptRateShown: Double
    public let acceptanceRetentionClearedCount: Int
    public let acceptanceRetentionClearedByReason: [String: Int]
    public let tabAcceptShare: Double
    public let duplicateTextCount: Int
    public let doNotShipCounters: [String: Int]
    public let caretGeometryFailureRate: Double
    public let annoyanceScore: Double
    public let activeWritingMinutes: Int
    public let shownPerActiveMinute: Double
    public let explicitDismissalsPerShown: Double
    public let typedOverRate: Double
    public let staleOrWrongContextRate: Double
    public let acceptRate: Double
    public let usefulRate: Double
    public let p50LatencyMilliseconds: Int?
    public let p95LatencyMilliseconds: Int?
    public let p95VisibleLifetimeMilliseconds: Int?
    public let p95HideLatencyMilliseconds: Int?
    public let topFailureReasons: [AutocompleteTraceFailureReason]
    public let recommendedFixes: [AutocompleteRecommendedFix]
    public let acceptRateByApp: [String: Double]
    public let acceptRateByMode: [String: Double]
    public let acceptedAndKeptRateByApp: [String: Double]
    public let acceptedAndKeptRateByFieldKind: [String: Double]
    public let acceptedAndKeptRateByRenderMode: [String: Double]
    public let acceptedAndKeptRateByInsertionMode: [String: Double]
    public let acceptedAndKeptRateByRequestMode: [String: Double]
    public let acceptedAndKeptRateByModel: [String: Double]
    public let acceptedAndKeptRateByExperimentArm: [String: Double]
    public let usefulRateByApp: [String: Double]
    public let usefulRateByMode: [String: Double]
    public let suppressedByReason: [String: Int]
    public let sensitiveSuppressedByCategory: [String: Int]
    public let sensitivePresentedByCategory: [String: Int]
    public let presentedByApp: [String: Int]
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
        typeThroughSurvivalRate: Double = 0,
        typedOverCount: Int,
        suppressedCount: Int = 0,
        actionableSuppressedCount: Int = 0,
        insertionVerificationSuccessRate: Double = 0,
        acceptedAndKeptCount: Int = 0,
        acceptedAndKeptRateAccepted: Double = 0,
        acceptedAndKeptRateShown: Double = 0,
        acceptanceRetentionClearedCount: Int = 0,
        acceptanceRetentionClearedByReason: [String: Int] = [:],
        tabAcceptShare: Double = 0,
        duplicateTextCount: Int = 0,
        doNotShipCounters: [String: Int] = [:],
        caretGeometryFailureRate: Double = 0,
        annoyanceScore: Double = 0,
        activeWritingMinutes: Int = 0,
        shownPerActiveMinute: Double = 0,
        explicitDismissalsPerShown: Double = 0,
        typedOverRate: Double = 0,
        staleOrWrongContextRate: Double = 0,
        acceptRate: Double,
        usefulRate: Double,
        p50LatencyMilliseconds: Int?,
        p95LatencyMilliseconds: Int?,
        p95VisibleLifetimeMilliseconds: Int? = nil,
        p95HideLatencyMilliseconds: Int? = nil,
        topFailureReasons: [AutocompleteTraceFailureReason] = [],
        recommendedFixes: [AutocompleteRecommendedFix] = [],
        acceptRateByApp: [String: Double] = [:],
        acceptRateByMode: [String: Double] = [:],
        acceptedAndKeptRateByApp: [String: Double] = [:],
        acceptedAndKeptRateByFieldKind: [String: Double] = [:],
        acceptedAndKeptRateByRenderMode: [String: Double] = [:],
        acceptedAndKeptRateByInsertionMode: [String: Double] = [:],
        acceptedAndKeptRateByRequestMode: [String: Double] = [:],
        acceptedAndKeptRateByModel: [String: Double] = [:],
        acceptedAndKeptRateByExperimentArm: [String: Double] = [:],
        usefulRateByApp: [String: Double] = [:],
        usefulRateByMode: [String: Double] = [:],
        suppressedByReason: [String: Int] = [:],
        sensitiveSuppressedByCategory: [String: Int] = [:],
        sensitivePresentedByCategory: [String: Int] = [:],
        presentedByApp: [String: Int] = [:],
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
        self.typeThroughSurvivalRate = typeThroughSurvivalRate
        self.typedOverCount = typedOverCount
        self.suppressedCount = suppressedCount
        self.actionableSuppressedCount = actionableSuppressedCount
        self.insertionVerificationSuccessRate = insertionVerificationSuccessRate
        self.acceptedAndKeptCount = acceptedAndKeptCount
        self.acceptedAndKeptRateAccepted = acceptedAndKeptRateAccepted
        self.acceptedAndKeptRateShown = acceptedAndKeptRateShown
        self.acceptanceRetentionClearedCount = acceptanceRetentionClearedCount
        self.acceptanceRetentionClearedByReason = acceptanceRetentionClearedByReason
        self.tabAcceptShare = tabAcceptShare
        self.duplicateTextCount = duplicateTextCount
        self.doNotShipCounters = doNotShipCounters
        self.caretGeometryFailureRate = caretGeometryFailureRate
        self.annoyanceScore = annoyanceScore
        self.activeWritingMinutes = activeWritingMinutes
        self.shownPerActiveMinute = shownPerActiveMinute
        self.explicitDismissalsPerShown = explicitDismissalsPerShown
        self.typedOverRate = typedOverRate
        self.staleOrWrongContextRate = staleOrWrongContextRate
        self.acceptRate = acceptRate
        self.usefulRate = usefulRate
        self.p50LatencyMilliseconds = p50LatencyMilliseconds
        self.p95LatencyMilliseconds = p95LatencyMilliseconds
        self.p95VisibleLifetimeMilliseconds = p95VisibleLifetimeMilliseconds
        self.p95HideLatencyMilliseconds = p95HideLatencyMilliseconds
        self.topFailureReasons = topFailureReasons
        self.recommendedFixes = recommendedFixes
        self.acceptRateByApp = acceptRateByApp
        self.acceptRateByMode = acceptRateByMode
        self.acceptedAndKeptRateByApp = acceptedAndKeptRateByApp
        self.acceptedAndKeptRateByFieldKind = acceptedAndKeptRateByFieldKind
        self.acceptedAndKeptRateByRenderMode = acceptedAndKeptRateByRenderMode
        self.acceptedAndKeptRateByInsertionMode = acceptedAndKeptRateByInsertionMode
        self.acceptedAndKeptRateByRequestMode = acceptedAndKeptRateByRequestMode
        self.acceptedAndKeptRateByModel = acceptedAndKeptRateByModel
        self.acceptedAndKeptRateByExperimentArm = acceptedAndKeptRateByExperimentArm
        self.usefulRateByApp = usefulRateByApp
        self.usefulRateByMode = usefulRateByMode
        self.suppressedByReason = suppressedByReason
        self.sensitiveSuppressedByCategory = sensitiveSuppressedByCategory
        self.sensitivePresentedByCategory = sensitivePresentedByCategory
        self.presentedByApp = presentedByApp
        self.suppressedByApp = suppressedByApp
        self.suppressedByMode = suppressedByMode
        self.actionableSuppressedByApp = actionableSuppressedByApp
        self.actionableSuppressedByMode = actionableSuppressedByMode
        self.topMisses = topMisses
    }
}

private struct TraceRect: Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
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
        let suppressed = events.filter { $0.type == .suggestionSuppressed }
        let actionableSuppressed = suppressed.filter { isActionableSuppression($0) }
        let sensitiveSuppressed = suppressed.filter { sensitiveCategory($0) != nil }
        let insertionFailures = events.filter { $0.type == .insertionFailed }
        let insertionVerified = events.filter { $0.type == .insertionVerified }
        let caretGeometryFailures = events.filter { $0.type == .caretGeometryFailed }
        let acceptedTextEdited = events.filter { $0.type == .acceptedTextEdited }
        let acceptanceRetentionCleared = events.filter { $0.type == .acceptanceRetentionCleared }
        let hidden = events.filter { $0.type == .suggestionHidden }
        let explicitDismissals = hidden.filter { $0.reason == "escape" }
        let activeMinutes = activeWritingMinutes(in: events)
        let visibleLifetimes = hidden
            .compactMap { intMetadata($0, key: "lifetimeMs") ?? intMetadata($0, key: "visibleLifetimeMs") }
            .sorted()
        let hideLatencies = hidden
            .compactMap { intMetadata($0, key: "hideLatencyMs") }
            .sorted()
        let staleOrWrongContextEvents = events.filter(isStaleOrWrongContextEvent)
        let firstShownLatencies = firstPresentedByID.values.compactMap(\.latencyMilliseconds).sorted()
        let acceptedEventIDs = Set(accepted.map(\.acceptanceIdentifier))
        let acceptedAndKeptEventIDs = Set(acceptedTextEdited
            .filter(\.isAcceptedAndKeptSignal)
            .map(\.acceptanceIdentifier))
        let acceptedAndKeptSuggestionIDs = Set(acceptedTextEdited
            .filter(\.isAcceptedAndKeptSignal)
            .map(\.suggestionID))
            .intersection(presentedIDs)
        let verifiedAndFailedCount = insertionVerified.count + insertionFailures.count
        let annoyanceSignals = annoyanceSignalCounts(from: events, presentedByID: firstPresentedByID)

        return AutocompleteTraceSummary(
            totalEvents: events.count,
            presentedCount: firstPresentedByID.count,
            acceptedCount: accepted.count,
            typedThroughCount: typedThroughIDs.count,
            typeThroughSurvivalRate: firstPresentedByID.isEmpty
                ? 0
                : Double(typedThroughIDs.count) / Double(firstPresentedByID.count),
            typedOverCount: typedOver.count,
            suppressedCount: suppressed.count,
            actionableSuppressedCount: actionableSuppressed.count,
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
            acceptanceRetentionClearedCount: acceptanceRetentionCleared.count,
            acceptanceRetentionClearedByReason: countsByReason(acceptanceRetentionCleared),
            tabAcceptShare: accepted.isEmpty ? 0 : Double(accepted.filter(isTabAccept).count) / Double(accepted.count),
            duplicateTextCount: insertionFailures.filter(\.isDuplicateInsertionSignal).count,
            doNotShipCounters: doNotShipCounters(from: events),
            caretGeometryFailureRate: rate(
                numerator: caretGeometryFailures.count,
                denominator: firstPresentedByID.count + caretGeometryFailures.count
            ),
            annoyanceScore: annoyanceScore(signalCounts: annoyanceSignals, presentedCount: firstPresentedByID.count),
            activeWritingMinutes: activeMinutes,
            shownPerActiveMinute: activeMinutes == 0
                ? 0
                : Double(firstPresentedByID.count) / Double(activeMinutes),
            explicitDismissalsPerShown: rate(
                numerator: explicitDismissals.count,
                denominator: firstPresentedByID.count
            ),
            typedOverRate: rate(
                numerator: typedOver.count,
                denominator: firstPresentedByID.count
            ),
            staleOrWrongContextRate: rate(
                numerator: staleOrWrongContextEvents.count,
                denominator: firstPresentedByID.count
            ),
            acceptRate: presentedIDs.isEmpty ? 0 : Double(acceptedIDs.count) / Double(presentedIDs.count),
            usefulRate: presentedIDs.isEmpty ? 0 : Double(usefulIDs.count) / Double(presentedIDs.count),
            p50LatencyMilliseconds: percentile(0.50, in: firstShownLatencies),
            p95LatencyMilliseconds: percentile(0.95, in: firstShownLatencies),
            p95VisibleLifetimeMilliseconds: percentile(0.95, in: visibleLifetimes),
            p95HideLatencyMilliseconds: percentile(0.95, in: hideLatencies),
            topFailureReasons: topFailureReasons(from: events),
            recommendedFixes: recommendedFixes(
                events: events,
                p95LatencyMilliseconds: percentile(0.95, in: firstShownLatencies)
            ),
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
            acceptedAndKeptRateByApp: rates(
                presentedByID: firstPresentedByID,
                outcomeIDs: acceptedAndKeptSuggestionIDs,
                key: \.appBundleIdentifier
            ),
            acceptedAndKeptRateByFieldKind: rates(
                presentedByID: firstPresentedByID,
                outcomeIDs: acceptedAndKeptSuggestionIDs,
                key: fieldKind
            ),
            acceptedAndKeptRateByRenderMode: rates(
                presentedByID: firstPresentedByID,
                outcomeIDs: acceptedAndKeptSuggestionIDs,
                key: renderMode
            ),
            acceptedAndKeptRateByInsertionMode: rates(
                presentedByID: firstPresentedByID,
                outcomeIDs: acceptedAndKeptSuggestionIDs,
                key: insertionMode
            ),
            acceptedAndKeptRateByRequestMode: rates(
                presentedByID: firstPresentedByID,
                outcomeIDs: acceptedAndKeptSuggestionIDs,
                key: \.requestMode
            ),
            acceptedAndKeptRateByModel: rates(
                presentedByID: firstPresentedByID,
                outcomeIDs: acceptedAndKeptSuggestionIDs,
                key: model
            ),
            acceptedAndKeptRateByExperimentArm: rates(
                presentedByID: firstPresentedByID,
                outcomeIDs: acceptedAndKeptSuggestionIDs,
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
            suppressedByReason: countsByReason(suppressed),
            sensitiveSuppressedByCategory: counts(sensitiveSuppressed, key: sensitiveSuppressionCategory),
            sensitivePresentedByCategory: counts(
                Array(firstPresentedByID.values).filter(isSensitivePresentation),
                key: sensitivePresentationCategory
            ),
            presentedByApp: counts(Array(firstPresentedByID.values), key: \.appBundleIdentifier),
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

    private func sensitiveCategory(_ event: AutocompleteTraceEvent) -> String? {
        event.metadata["sensitiveSuppressionCategory"]
            ?? event.metadata["sensitiveFieldCategory"]
    }

    private func sensitiveSuppressionCategory(_ event: AutocompleteTraceEvent) -> String {
        sensitiveCategory(event) ?? "unknown"
    }

    private func sensitivePresentationCategory(_ event: AutocompleteTraceEvent) -> String {
        sensitiveCategory(event) ?? (isSensitiveFieldKind(event) ? fieldKind(event) : "unknown")
    }

    private func isSensitivePresentation(_ event: AutocompleteTraceEvent) -> Bool {
        sensitiveCategory(event) != nil || isSensitiveFieldKind(event)
    }

    private func isSensitiveFieldKind(_ event: AutocompleteTraceEvent) -> Bool {
        ["search", "form", "url", "secure", "password", "unprovenSurface"]
            .contains(event.metadata["fieldKind"] ?? "")
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

    private func insertionMode(_ event: AutocompleteTraceEvent) -> String {
        if let mode = event.metadata["insertionMode"], !mode.isEmpty {
            return mode
        }

        return CompatibilityProfileStore.mvp
            .profile(for: event.appBundleIdentifier)?
            .insertionMode.rawValue ?? "unknown"
    }

    private func model(_ event: AutocompleteTraceEvent) -> String {
        if let model = event.metadata["model"], !model.isEmpty {
            return model
        }

        if let override = event.metadata["modelOverride"], !override.isEmpty {
            return override
        }

        if let asset = event.metadata["asset"], !asset.isEmpty {
            return asset
        }

        return "unknown"
    }

    private func isTabAccept(_ event: AutocompleteTraceEvent) -> Bool {
        event.metadata["acceptMode"] == "tab"
            || event.metadata["acceptMode"] == "acceptNextWord"
            || event.outcome == "acceptNextWord"
    }

    private func intMetadata(_ event: AutocompleteTraceEvent, key: String) -> Int? {
        event.intMetadata(key)
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
        let presentedByID = firstEventsBySuggestionID(from: events.filter { $0.type == .suggestionPresented })
        addRepeatedUnacceptedSuggestions(from: events, buckets: &buckets)
        addRepeatedTypedOverSuggestions(from: events, buckets: &buckets)

        for event in events {
            if event.type == .suggestionHidden,
               let presented = presentedByID[event.suggestionID],
               suggestionLifecycleScopeChanged(from: presented, to: event) {
                add(
                    key: "Suggestion hidden under a different field",
                    event: event,
                    cause: "The suggestion was presented for \(scopeDescription(presented)) but hidden for \(scopeDescription(event)).",
                    category: "trace ownership bug",
                    buckets: &buckets
                )
            }

            if event.type == .suggestionHidden,
               event.reason == "panel-frame-unusable" {
                add(
                    key: "Panel frame became unusable in \(event.appBundleIdentifier)",
                    event: event,
                    cause: "The visible suggestion was hidden because its panel frame stopped being usable.",
                    category: "renderer/caret bug",
                    buckets: &buckets
                )
            }

            if event.type == .suggestionHidden,
               event.reason == "focus-changed" {
                add(
                    key: "Suggestion hidden after focus changed",
                    event: event,
                    cause: "The suggestion was still visible when focus moved away from \(scopeDescription(event)).",
                    category: "trace ownership bug",
                    buckets: &buckets
                )
            }

            if event.type == .suggestionHidden,
               event.reason == "stale-after-keydown" {
                add(
                    key: "Stale suggestion passed through",
                    event: event,
                    cause: "The user typed after the suggestion became stale, so the app dismissed it instead of accepting it.",
                    category: "stale suggestion bug",
                    buckets: &buckets
                )
            }

            if event.type == .suggestionHidden,
               event.reason.hasPrefix("placement-") {
                let reason = String(event.reason.dropFirst("placement-".count))
                add(
                    key: "Placement changed while suggestion was visible",
                    event: event,
                    cause: "The visible suggestion was hidden after placement changed: \(reason).",
                    category: "renderer/caret bug",
                    buckets: &buckets
                )
            }

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

    private func topFailureReasons(from events: [AutocompleteTraceEvent]) -> [AutocompleteTraceFailureReason] {
        let insertionFailures = events.filter { $0.type == .insertionFailed }
        let duplicateText = insertionFailures.filter(\.isDuplicateInsertionSignal).count
        let wrongInsertion = insertionFailures.count - duplicateText
        let tabConflict = tabConflictCount(in: events)
        let focusStealing = focusStealingCount(in: events)
        let searchOrFormLeakage = searchOrFormLeakageCount(in: events)
        let caretFailed = events.filter { $0.type == .caretGeometryFailed }.count
        let flicker = overlayFlickerCount(in: events)

        let candidates = [
            AutocompleteTraceFailureReason(
                title: "Duplicate text",
                count: duplicateText,
                priority: 100,
                category: "insertion trust"
            ),
            AutocompleteTraceFailureReason(
                title: "Focus stealing",
                count: focusStealing,
                priority: 95,
                category: "insertion trust"
            ),
            AutocompleteTraceFailureReason(
                title: "Insertion failed",
                count: wrongInsertion,
                priority: 90,
                category: "insertion trust"
            ),
            AutocompleteTraceFailureReason(
                title: "Tab conflict",
                count: tabConflict,
                priority: 85,
                category: "keyboard trust"
            ),
            AutocompleteTraceFailureReason(
                title: "Search/form leakage",
                count: searchOrFormLeakage,
                priority: 80,
                category: "field targeting"
            ),
            AutocompleteTraceFailureReason(
                title: "Caret failed",
                count: caretFailed,
                priority: 75,
                category: "renderer/caret"
            ),
            AutocompleteTraceFailureReason(
                title: "Overlay flicker",
                count: flicker,
                priority: 60,
                category: "renderer/caret"
            )
        ]

        return candidates
            .filter { $0.count > 0 }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.priority > rhs.priority
                }

                return lhs.count > rhs.count
            }
    }

    private func recommendedFixes(
        events: [AutocompleteTraceEvent],
        p95LatencyMilliseconds: Int?
    ) -> [AutocompleteRecommendedFix] {
        let insertionFailures = events.filter { $0.type == .insertionFailed }
        let duplicateText = insertionFailures.filter(\.isDuplicateInsertionSignal).count
        let wrongInsertion = insertionFailures.count - duplicateText
        let focusStealing = focusStealingCount(in: events)
        let tabConflicts = tabConflictCount(in: events)
        let caretFailures = events.filter { $0.type == .caretGeometryFailed }.count
        let verificationFailures = insertionFailures.count
        let slowSuggestions = events
            .filter { $0.type == .suggestionPresented }
            .filter { ($0.latencyMilliseconds ?? 0) >= 1_000 }
            .count
        var fixes: [AutocompleteRecommendedFix] = []

        let insertionTrustCount = duplicateText + wrongInsertion + focusStealing + tabConflicts
        if insertionTrustCount > 0 {
            fixes.append(AutocompleteRecommendedFix(
                title: "Fix insertion trust before model tuning",
                reason: "\(insertionTrustCount) duplicate, focus, wrong-insert, or Tab-conflict signal(s) found.",
                priority: 100
            ))
        }

        if caretFailures + verificationFailures > 0 {
            fixes.append(AutocompleteRecommendedFix(
                title: "Fix caret or verification before prompt tuning",
                reason: "\(caretFailures) caret failure(s) and \(verificationFailures) insertion verification failure(s) found.",
                priority: 90
            ))
        }

        if slowSuggestions > 0 || (p95LatencyMilliseconds ?? 0) >= 1_000 {
            fixes.append(AutocompleteRecommendedFix(
                title: "Fix latency before length experiments",
                reason: "First-visible p95 is \(p95LatencyMilliseconds.map { "\($0)ms" } ?? "unknown") with \(slowSuggestions) slow shown suggestion(s).",
                priority: 80
            ))
        }

        if fixes.isEmpty,
           !events.contains(where: { $0.type == .acceptedTextEdited && $0.isAcceptedAndKeptSignal }),
           events.contains(where: { $0.type == .suggestionPresented }) {
            fixes.append(AutocompleteRecommendedFix(
                title: "Collect accepted-and-kept proof",
                reason: "Suggestions were shown, but no accepted text survived a checkpoint yet.",
                priority: 50
            ))
        }

        return fixes.sorted { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.title < rhs.title
            }

            return lhs.priority > rhs.priority
        }
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

    private func slowSuggestionThresholdMilliseconds(for requestMode: String) -> Int {
        switch requestMode {
        case CompletionRequestMode.wordCompletion.rawValue:
            return 25
        case CompletionRequestMode.sentenceContinuation.rawValue:
            return 450
        default:
            return 225
        }
    }

    private func suggestionLifecycleScopeChanged(
        from presented: AutocompleteTraceEvent,
        to hidden: AutocompleteTraceEvent
    ) -> Bool {
        presented.appBundleIdentifier != hidden.appBundleIdentifier
            || (
                !presented.fieldIdentity.isEmpty
                    && !hidden.fieldIdentity.isEmpty
                    && presented.fieldIdentity != hidden.fieldIdentity
            )
    }

    private func scopeDescription(_ event: AutocompleteTraceEvent) -> String {
        let app = event.appBundleIdentifier.isEmpty ? "unknown app" : event.appBundleIdentifier
        guard !event.fieldIdentity.isEmpty else {
            return app
        }

        return "\(app)/\(event.fieldIdentity)"
    }

    private func placementRenderMode(for event: AutocompleteTraceEvent) -> String {
        event.metadata["placementEffectiveRenderMode"]
            ?? event.metadata["effectiveRenderMode"]
            ?? (event.requestMode.isEmpty ? "unknown" : event.requestMode)
    }

    private func placementHealthReason(for event: AutocompleteTraceEvent) -> String {
        event.metadata["placementHealthReason"] ?? event.reason
    }

    private func isPlacementSuppression(_ event: AutocompleteTraceEvent) -> Bool {
        guard event.type == .suggestionSuppressed else {
            return false
        }

        if let action = event.metadata["placementSelfHealingAction"],
           action == "suppress" {
            return true
        }

        if event.metadata["placementHealthReason"] != nil {
            return true
        }

        return [
            "disabled",
            "missing-anchor",
            "missing-caret",
            "invalid-caret",
            "invalid-anchor",
            "caret-outside-focused-bounds",
            "missing-floating-fallback"
        ].contains(event.reason)
    }

    private func inlinePlacementLooksClipped(_ event: AutocompleteTraceEvent) -> Bool {
        guard event.metadata["effectiveRenderMode"] == "inlineAdjacent",
              let panelRect = traceRect(from: event.metadata["suggestionPanelRect"]),
              traceRect(from: event.metadata["clippingRect"]) != nil else {
            return false
        }

        let visibleCharacters = Double(Int(event.metadata["visibleChars"] ?? "") ?? event.displayedText.count)
        let expectedMinimumWidth = min(72, max(24, visibleCharacters * 3))
        return panelRect.width < expectedMinimumWidth
    }

    private func traceRect(from value: String?) -> TraceRect? {
        guard let value,
              value != "none" else {
            return nil
        }

        var values: [String: Double] = [:]
        for part in value.split(separator: ",") {
            let pieces = part.split(separator: "=", maxSplits: 1)
            guard pieces.count == 2,
                  let number = Double(pieces[1]) else {
                continue
            }
            values[String(pieces[0])] = number
        }

        guard let x = values["x"],
              let y = values["y"],
              let width = values["w"],
              let height = values["h"] else {
            return nil
        }

        return TraceRect(x: x, y: y, width: width, height: height)
    }

    private func addRepeatedTypedOverSuggestions(
        from events: [AutocompleteTraceEvent],
        buckets: inout [String: (count: Int, example: AutocompleteTraceEvent, cause: String, category: String)]
    ) {
        let typedOver = events.filter { $0.type == .suggestionTypedOver }
        let repeated = Dictionary(grouping: typedOver) { event in
            "\(event.requestMode)|\(normalizedSuggestionText(event.displayedText))"
        }

        for (_, suggestions) in repeated {
            guard suggestions.count >= 2,
                  let example = suggestions.first,
                  !normalizedSuggestionText(example.displayedText).isEmpty
            else {
                continue
            }

            let repeatedText = normalizedSuggestionText(example.displayedText)
            let title = "Repeated typed-over: \(repeatedText)"
            add(
                key: title,
                event: example,
                cause: "The same \(example.requestMode) suggestion was typed over \(suggestions.count) times.",
                category: example.requestMode == "wordCompletion" ? "word-completion issue" : "prompt issue",
                buckets: &buckets
            )

            if var existing = buckets[title] {
                existing.count = max(existing.count, suggestions.count)
                buckets[title] = existing
            }
        }
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

    private func activeWritingMinutes(in events: [AutocompleteTraceEvent]) -> Int {
        let dates = events
            .compactMap { iso8601Date(from: $0.timestamp) }
            .sorted()
        guard let first = dates.first, let last = dates.last else {
            return 0
        }

        let seconds = max(0, last.timeIntervalSince(first))
        return max(1, Int((seconds / 60).rounded(.up)))
    }

    private func doNotShipCounters(from events: [AutocompleteTraceEvent]) -> [String: Int] {
        var counters: [String: Int] = [:]

        func increment(_ key: String) {
            counters[key, default: 0] += 1
        }

        for event in events {
            if event.type == .insertionFailed {
                increment("insertion-failed")
            }

            if event.type == .suggestionSuppressed,
               event.reason == "wrong-app-or-field-before-accept" {
                increment("wrong-app-or-field-before-accept")
            }

            if event.type == .suggestionPresented,
               ["secure", "password"].contains(event.metadata["fieldKind"] ?? "") {
                increment("secure-field-suggestion")
            }

            if event.type == .suggestionPresented,
               isSensitiveFieldKind(event) {
                increment("sensitive-field-suggestion")
            }

            if event.type == .suggestionPresented,
               sensitiveCategory(event) != nil {
                increment("sensitive-category-suggestion")
            }

            if event.type == .suggestionPresented,
               event.metadata["supportState"] == "unsupported" {
                increment("unsupported-app-presentation")
            }

            if event.type == .suggestionPresented,
               event.metadata["effectiveRenderMode"] == "floatingMirror",
               event.metadata["hasCaretRect"] == "false" {
                increment("detached-suggestion-shown")
            }

            if event.metadata["mockRuntimeFallback"] == "true" {
                increment("mock-runtime-fallback")
            }

            if event.metadata["doNotShip"] == "true",
               !(event.type == .suggestionSuppressed && event.reason == "wrong-app-or-field-before-accept") {
                increment(event.reason.isEmpty ? "do-not-ship" : event.reason)
            }
        }

        let promptMetrics = PromptAppNoSubmitMetricsAnalyzer().metrics(from: events)
        if promptMetrics.accidentalSubmitCount > 0 {
            counters["prompt-accidental-submit"] = promptMetrics.accidentalSubmitCount
        }
        if promptMetrics.sendKeyCollisionCount > 0 {
            counters["prompt-send-key-collision"] = promptMetrics.sendKeyCollisionCount
        }
        if promptMetrics.promptMutationWithoutUserIntentCount > 0 {
            counters["prompt-mutation-without-user-intent"] = promptMetrics.promptMutationWithoutUserIntentCount
        }
        if promptMetrics.wrongContextInsertionCount > 0 {
            counters["prompt-wrong-context-insertion"] = promptMetrics.wrongContextInsertionCount
        }
        if promptMetrics.fullAcceptWithoutProofCount > 0 {
            counters["prompt-full-accept-without-proof"] = promptMetrics.fullAcceptWithoutProofCount
        }
        if promptMetrics.suggestionContentViolationCount > 0 {
            counters["prompt-suggestion-content-violation"] = promptMetrics.suggestionContentViolationCount
        }

        return counters
    }

    private func tabConflictCount(in events: [AutocompleteTraceEvent]) -> Int {
        events.filter(\.isTabConflictSignal).count
    }

    private func focusStealingCount(in events: [AutocompleteTraceEvent]) -> Int {
        events.filter(\.isFocusStealSignal).count
    }

    private func searchOrFormLeakageCount(in events: [AutocompleteTraceEvent]) -> Int {
        events.filter { event in
            event.type == .suggestionPresented
                && (isSensitiveFieldKind(event) || sensitiveCategory(event) != nil)
        }.count
    }

    private func overlayFlickerCount(in events: [AutocompleteTraceEvent]) -> Int {
        events.filter { event in
            event.type == .suggestionHidden
                && (intMetadata(event, key: "lifetimeMs") ?? Int.max) < 150
        }.count
    }

    private func isStaleOrWrongContextEvent(_ event: AutocompleteTraceEvent) -> Bool {
        if event.metadata["focusMismatch"] == "true" {
            return true
        }

        if event.reason == "wrong-app-or-field-before-accept"
            || event.reason == "focus-changed"
            || event.reason == "stale-after-keydown"
            || event.reason.hasPrefix("stale-") {
            return true
        }

        return false
    }

    // ISO8601DateFormatter.date(from:) is thread-safe; shared to avoid per-call allocation.
    nonisolated(unsafe) private static let iso8601Formatter = ISO8601DateFormatter()

    private func iso8601Date(from value: String) -> Date? {
        Self.iso8601Formatter.date(from: value)
    }

    private func isTooShortWordCompletion(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains(where: { $0.isWhitespace }),
              trimmed.allSatisfy({ $0.isLetter }) else {
            return false
        }

        return trimmed.count <= 2
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
                increment(event.isDuplicateInsertionSignal ? "duplicateText" : "wrongInsertion")
                if event.isFocusStealSignal {
                    increment("focusStealing")
                }
                if event.isTabConflictSignal {
                    increment("tabConflict")
                }

            case .suggestionTypedOver:
                if let delay = intMetadata(event, key: "delayMs") {
                    if delay <= 1_000 {
                        increment("typedOverWithinOneSecond")
                    }
                } else {
                    increment("typedOver")
                }

            case .acceptedTextEdited:
                if event.isAcceptedThenDeletedWithinTwoSecondsSignal {
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
                if ["search", "form", "url", "secure", "unprovenSurface"].contains(event.metadata["fieldKind"] ?? "") {
                    increment("searchOrFormLeakage")
                }

            case .suggestionSuppressed:
                if event.reason == "repeated-miss" {
                    increment("repeatedRejection")
                }

                if event.isTabConflictSignal {
                    increment("tabConflict")
                }

                if event.metadata["focusMismatch"] == "true" {
                    increment("focusMismatch")
                }

            case .appPaused:
                increment("manualPause")

            case .appDisabled:
                increment("appDisable")

            case .caretGeometryFailed:
                increment("caretGeometryFailed")

            default:
                if event.isFocusStealSignal {
                    increment("focusStealing")
                }

                if event.isTabConflictSignal {
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
            "caretGeometryFailed": 0.3
        ]

        let weightedTotal = signalCounts.reduce(0.0) { total, item in
            total + (weights[item.key] ?? 0.25) * Double(item.value)
        }

        return weightedTotal / Double(max(1, presentedCount))
    }

    private func millisecondsBetween(_ start: String, _ end: String) -> Int? {
        guard let startDate = iso8601Date(from: start),
              let endDate = iso8601Date(from: end) else {
            return nil
        }

        return max(0, Int(endDate.timeIntervalSince(startDate) * 1_000))
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
