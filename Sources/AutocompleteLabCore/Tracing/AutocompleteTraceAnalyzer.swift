import Foundation

public struct AutocompleteTraceMiss: Equatable, Sendable {
    public let title: String
    public let count: Int
    public let exampleSuggestionID: String
    public let suggestedCause: String
    public let fixCategory: String

    public init(
        title: String,
        count: Int,
        exampleSuggestionID: String,
        suggestedCause: String,
        fixCategory: String
    ) {
        self.title = title
        self.count = count
        self.exampleSuggestionID = exampleSuggestionID
        self.suggestedCause = suggestedCause
        self.fixCategory = fixCategory
    }
}

public struct AutocompleteTraceSummary: Equatable, Sendable {
    public let totalEvents: Int
    public let presentedCount: Int
    public let acceptedCount: Int
    public let typedOverCount: Int
    public let ignoredCount: Int
    public let insertionFailureCount: Int
    public let acceptRate: Double
    public let p50LatencyMilliseconds: Int?
    public let p90LatencyMilliseconds: Int?
    public let p95LatencyMilliseconds: Int?
    public let topMisses: [AutocompleteTraceMiss]

    public init(
        totalEvents: Int,
        presentedCount: Int,
        acceptedCount: Int,
        typedOverCount: Int,
        ignoredCount: Int,
        insertionFailureCount: Int,
        acceptRate: Double,
        p50LatencyMilliseconds: Int?,
        p90LatencyMilliseconds: Int?,
        p95LatencyMilliseconds: Int?,
        topMisses: [AutocompleteTraceMiss]
    ) {
        self.totalEvents = totalEvents
        self.presentedCount = presentedCount
        self.acceptedCount = acceptedCount
        self.typedOverCount = typedOverCount
        self.ignoredCount = ignoredCount
        self.insertionFailureCount = insertionFailureCount
        self.acceptRate = acceptRate
        self.p50LatencyMilliseconds = p50LatencyMilliseconds
        self.p90LatencyMilliseconds = p90LatencyMilliseconds
        self.p95LatencyMilliseconds = p95LatencyMilliseconds
        self.topMisses = topMisses
    }
}

public struct AutocompleteTraceAnalyzer: Equatable, Sendable {
    public init() {}

    public func summary(for events: [AutocompleteTraceEvent]) -> AutocompleteTraceSummary {
        let presented = events.filter { $0.type == .suggestionPresented }
        let accepted = events.filter { $0.type == .suggestionAccepted }
        let typedOver = events.filter { $0.type == .suggestionTypedOver }
        let hiddenIgnored = events.filter { $0.type == .suggestionHidden && $0.outcome == "ignored" }
        let insertionFailures = events.filter { $0.type == .insertionFailed }
        let latencies = events.compactMap(\.latencyMilliseconds).sorted()

        return AutocompleteTraceSummary(
            totalEvents: events.count,
            presentedCount: presented.count,
            acceptedCount: accepted.count,
            typedOverCount: typedOver.count,
            ignoredCount: hiddenIgnored.count,
            insertionFailureCount: insertionFailures.count,
            acceptRate: presented.isEmpty ? 0 : Double(accepted.count) / Double(presented.count),
            p50LatencyMilliseconds: percentile(0.50, in: latencies),
            p90LatencyMilliseconds: percentile(0.90, in: latencies),
            p95LatencyMilliseconds: percentile(0.95, in: latencies),
            topMisses: topMisses(from: events)
        )
    }

    private func topMisses(from events: [AutocompleteTraceEvent]) -> [AutocompleteTraceMiss] {
        var buckets: [String: (count: Int, example: AutocompleteTraceEvent, cause: String, category: String)] = [:]

        for event in events {
            if event.type == .suggestionTypedOver {
                add(
                    key: "Typed over: \(event.displayedText)",
                    event: event,
                    cause: "The visible suggestion did not match what the user typed next.",
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

            if event.type == .insertionFailed {
                add(
                    key: "Insertion failed: \(event.reason)",
                    event: event,
                    cause: "The app did not verify the accepted text after insertion.",
                    category: "insertion bug",
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
