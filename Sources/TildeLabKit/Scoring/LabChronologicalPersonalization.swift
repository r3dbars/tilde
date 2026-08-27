import AutocompleteLabCore
import Foundation

public enum LabPersonalHistoryStressKind: String, Codable, CaseIterable, Sendable {
    case stale
    case contradictory
    case poisoned
}

public struct LabPersonalizationAggregate: Codable, Equatable, Sendable {
    public let opportunities: Int
    public let baselinePredictions: Int
    public let baselineExactHits: Int
    public let personalPredictions: Int
    public let personalExactHits: Int
    public let disagreements: Int
    public let liftEvents: Int
    public let harmEvents: Int
    public let baselinePrecision: Double
    public let personalPrecision: Double
    public let baselineCoverage: Double
    public let personalCoverage: Double

    init(snapshots: [PersonalNextWordShadowSnapshot]) {
        let opportunities = snapshots.reduce(0) { $0 + $1.opportunities }
        let baselinePredictions = snapshots.reduce(0) { $0 + $1.baselinePredictions }
        let baselineHits = snapshots.reduce(0) { $0 + $1.baselineExactHits }
        let personalPredictions = snapshots.reduce(0) { $0 + $1.predictions }
        let personalHits = snapshots.reduce(0) { $0 + $1.exactHits }
        self.opportunities = opportunities
        self.baselinePredictions = baselinePredictions
        baselineExactHits = baselineHits
        self.personalPredictions = personalPredictions
        personalExactHits = personalHits
        disagreements = snapshots.reduce(0) { $0 + $1.predictionDisagreements }
        liftEvents = snapshots.reduce(0) { total, snapshot in
            let cells = snapshot.outcomeCells
            return total + cells.baselineSilentCandidateCorrect
                + cells.baselineWrongCandidateCorrect
        }
        harmEvents = snapshots.reduce(0) { total, snapshot in
            let cells = snapshot.outcomeCells
            return total + cells.baselineCorrectCandidateSilent
                + cells.baselineCorrectCandidateWrong
                + cells.baselineSilentCandidateWrong
        }
        baselinePrecision = Self.rate(baselineHits, baselinePredictions)
        personalPrecision = Self.rate(personalHits, personalPredictions)
        baselineCoverage = Self.rate(baselinePredictions, opportunities)
        personalCoverage = Self.rate(personalPredictions, opportunities)
    }

    init(baseline: [String?], personal: [String?], targets: [String]) {
        precondition(baseline.count == personal.count && personal.count == targets.count)
        opportunities = targets.count
        var baselinePredictionCount = 0
        var baselineHitCount = 0
        var personalPredictionCount = 0
        var personalHitCount = 0
        var disagreementCount = 0
        var liftCount = 0
        var harmCount = 0
        for index in targets.indices {
            let baselineValue = baseline[index]
            let personalValue = personal[index]
            let target = targets[index]
            if baselineValue != nil { baselinePredictionCount += 1 }
            if baselineValue == target { baselineHitCount += 1 }
            if personalValue != nil { personalPredictionCount += 1 }
            if personalValue == target { personalHitCount += 1 }
            if baselineValue != personalValue { disagreementCount += 1 }
            if personalValue == target, baselineValue != target { liftCount += 1 }
            if baselineValue == target, personalValue != target {
                harmCount += 1
            } else if baselineValue == nil, personalValue != nil, personalValue != target {
                harmCount += 1
            }
        }
        baselinePredictions = baselinePredictionCount
        baselineExactHits = baselineHitCount
        personalPredictions = personalPredictionCount
        personalExactHits = personalHitCount
        disagreements = disagreementCount
        liftEvents = liftCount
        harmEvents = harmCount
        baselinePrecision = Self.rate(baselineExactHits, baselinePredictions)
        personalPrecision = Self.rate(personalExactHits, personalPredictions)
        baselineCoverage = Self.rate(baselinePredictions, opportunities)
        personalCoverage = Self.rate(personalPredictions, opportunities)
    }

    private static func rate(_ numerator: Int, _ denominator: Int) -> Double {
        denominator > 0 ? Double(numerator) / Double(denominator) : 0
    }
}

public struct LabChronologicalPersonalizationReport: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.chronological-personalization.v1"

    public let schema: String
    public let eventCount: Int
    public let distinctApplications: Int
    public let earliestTimestampMilliseconds: Int64?
    public let latestTimestampMilliseconds: Int64?
    public let futureHistoryViolations: Int
    public let global: LabPersonalizationAggregate
    public let appSpecific: LabPersonalizationAggregate
    public let selectedScope: LabPersonalHistoryScope
    public let selected: LabPersonalizationAggregate
    public let stressCaseCounts: [LabPersonalHistoryStressKind: Int]
    public let stressAggregates: [LabPersonalHistoryStressKind: LabPersonalizationAggregate]
    public let personalLift: Int
    public let personalHarm: Int
    public let staleOverrideBlocks: Int
    public let staleOverrideBlocked: Bool
    public let limitation: String
}

public enum LabChronologicalPersonalizationError: Error, LocalizedError, Equatable, Sendable {
    case emptyEvents
    case mixedHistory
    case duplicateEventID
    case invalidConfiguration

    public var errorDescription: String? {
        switch self {
        case .emptyEvents: "Chronological personalization replay needs at least one local event."
        case .mixedHistory: "A chronological replay cannot mix different history or consent epochs."
        case .duplicateEventID: "A chronological replay cannot count the same event ID twice."
        case .invalidConfiguration: "The personalization blend, support, or confidence controls are invalid."
        }
    }
}

/// Replays local Personal History strictly in event time. Each word is scored
/// before that word is learned by Core's paired shadow model. The input may be
/// arbitrarily ordered; sorting happens before any model sees an event.
public enum LabChronologicalPersonalization {
    public static func evaluate(
        events: [PersonalHistoryEvent],
        configuration: LabPersonalizationConfiguration,
        evaluationStartMilliseconds: Int64 = 0,
        stressLabels: [String: LabPersonalHistoryStressKind] = [:]
    ) throws -> LabChronologicalPersonalizationReport {
        guard !events.isEmpty else { throw LabChronologicalPersonalizationError.emptyEvents }
        guard Set(events.map(\.historyIdentifier)).count == 1,
              Set(events.map(\.consentIdentifier)).count == 1 else {
            throw LabChronologicalPersonalizationError.mixedHistory
        }
        guard Set(events.map(\.id)).count == events.count else {
            throw LabChronologicalPersonalizationError.duplicateEventID
        }
        guard (1...100).contains(configuration.minimumSupport),
              (0...1).contains(configuration.minimumConfidence),
              (0...1).contains(configuration.recencyWeight),
              (0...1).contains(configuration.frequencyWeight),
              configuration.recencyWeight + configuration.frequencyWeight > 0 else {
            throw LabChronologicalPersonalizationError.invalidConfiguration
        }
        let ordered = events.sorted {
            if $0.timestampMilliseconds == $1.timestampMilliseconds { return $0.id < $1.id }
            return $0.timestampMilliseconds < $1.timestampMilliseconds
        }

        let replay = WeightedPersonalReplay(
            configuration: configuration,
            evaluationStartMilliseconds: evaluationStartMilliseconds,
            stressLabels: stressLabels
        ).evaluate(ordered)
        let global = LabPersonalizationAggregate(
            baseline: replay.global,
            personal: replay.global,
            targets: replay.targets
        )
        let appSpecific = LabPersonalizationAggregate(
            baseline: replay.global,
            personal: replay.app,
            targets: replay.targets
        )
        let selected = LabPersonalizationAggregate(
            baseline: replay.global,
            personal: replay.selected,
            targets: replay.targets
        )
        let byApp = Dictionary(grouping: ordered, by: \.appBundleIdentifier)
        let labels = Dictionary(grouping: stressLabels.values, by: { $0 })
            .mapValues(\.count)
        let stressPairs: [(LabPersonalHistoryStressKind, LabPersonalizationAggregate)] =
            LabPersonalHistoryStressKind.allCases.compactMap { kind in
                let indices = replay.stress.enumerated().compactMap { index, value in
                    value == kind ? index : nil
                }
                guard !indices.isEmpty else { return nil }
                return (kind, LabPersonalizationAggregate(
                    baseline: indices.map { replay.global[$0] },
                    personal: indices.map { replay.selected[$0] },
                    targets: indices.map { replay.targets[$0] }
                ))
            }
        let stressAggregates = Dictionary(uniqueKeysWithValues: stressPairs)
        return LabChronologicalPersonalizationReport(
            schema: LabChronologicalPersonalizationReport.currentSchema,
            eventCount: ordered.count,
            distinctApplications: byApp.count,
            earliestTimestampMilliseconds: ordered.first?.timestampMilliseconds,
            latestTimestampMilliseconds: ordered.last?.timestampMilliseconds,
            futureHistoryViolations: 0,
            global: global,
            appSpecific: appSpecific,
            selectedScope: configuration.scope,
            selected: selected,
            stressCaseCounts: labels,
            stressAggregates: stressAggregates,
            personalLift: selected.liftEvents,
            personalHarm: selected.harmEvents,
            staleOverrideBlocks: replay.staleOverrideBlocks,
            staleOverrideBlocked: configuration.enabled
                && configuration.arbitration == .production,
            limitation: "Aggregate-only first-word replay. Frequency/recency, support, confidence, scope, and arbitration are evaluated chronologically; full-suggestion utility still requires local dogfood events."
        )
    }

    private static func chronologicalOrder(
        _ lhs: PersonalHistoryEvent,
        _ rhs: PersonalHistoryEvent
    ) -> Bool {
        if lhs.timestampMilliseconds == rhs.timestampMilliseconds { return lhs.id < rhs.id }
        return lhs.timestampMilliseconds < rhs.timestampMilliseconds
    }
}

fileprivate struct WeightedPersonalReplay {
    private struct StreamKey: Hashable {
        let history: String
        let consent: String
        let session: String
        let app: String
    }

    private struct StreamState {
        var context: [String] = []
        var lastTimestampMilliseconds: Int64?
    }

    private struct TargetEvidence {
        var count = 0
        var lastSeenMilliseconds: Int64 = 0
    }

    private struct Prediction {
        let word: String
        let support: Int
        let confidence: Double
    }

    private struct Model {
        var transitions: [String: [String: TargetEvidence]] = [:]

        mutating func learn(_ target: String, after context: [String], at timestamp: Int64) {
            let maximum = min(4, context.count)
            guard maximum > 0 else { return }
            for order in 1...maximum {
                let key = Self.key(Array(context.suffix(order)))
                var evidence = transitions[key, default: [:]][target, default: TargetEvidence()]
                if evidence.count < Int.max { evidence.count += 1 }
                evidence.lastSeenMilliseconds = max(evidence.lastSeenMilliseconds, timestamp)
                transitions[key, default: [:]][target] = evidence
            }
        }

        func predict(
            after context: [String],
            at timestamp: Int64,
            configuration: LabPersonalizationConfiguration
        ) -> Prediction? {
            let maximum = min(4, context.count)
            guard maximum > 0 else { return nil }
            for order in stride(from: maximum, through: 1, by: -1) {
                let key = Self.key(Array(context.suffix(order)))
                guard let candidates = transitions[key], !candidates.isEmpty else { continue }
                let totalCount = max(1, candidates.values.reduce(0) { $0 + $1.count })
                let recencies = candidates.mapValues { evidence in
                    exp(-Double(max(0, timestamp - evidence.lastSeenMilliseconds)) / Self.halfLifeMilliseconds)
                }
                let totalRecency = max(Double.leastNonzeroMagnitude, recencies.values.reduce(0, +))
                let totalWeight = configuration.frequencyWeight + configuration.recencyWeight
                let ranked = candidates.map { word, evidence -> (String, TargetEvidence, Double) in
                    let frequencyShare = Double(evidence.count) / Double(totalCount)
                    let recencyShare = (recencies[word] ?? 0) / totalRecency
                    let confidence = (
                        configuration.frequencyWeight * frequencyShare
                            + configuration.recencyWeight * recencyShare
                    ) / totalWeight
                    return (word, evidence, confidence)
                }.sorted {
                    if $0.2 != $1.2 { return $0.2 > $1.2 }
                    if $0.1.count != $1.1.count { return $0.1.count > $1.1.count }
                    return $0.0 < $1.0
                }
                guard let winner = ranked.first,
                      winner.1.count >= configuration.minimumSupport,
                      winner.2 >= configuration.minimumConfidence else { continue }
                return Prediction(word: winner.0, support: winner.1.count, confidence: winner.2)
            }
            return nil
        }

        private static let halfLifeMilliseconds = 30.0 * 24 * 60 * 60 * 1_000

        private static func key(_ context: [String]) -> String {
            context.joined(separator: "\u{1f}")
        }
    }

    struct Result {
        var targets: [String] = []
        var global: [String?] = []
        var app: [String?] = []
        var selected: [String?] = []
        var stress: [LabPersonalHistoryStressKind?] = []
        var staleOverrideBlocks = 0
    }

    let configuration: LabPersonalizationConfiguration
    let evaluationStartMilliseconds: Int64
    let stressLabels: [String: LabPersonalHistoryStressKind]

    func evaluate(_ events: [PersonalHistoryEvent]) -> Result {
        var globalModel = Model()
        var appModels: [String: Model] = [:]
        var streams: [StreamKey: StreamState] = [:]
        var result = Result()

        for event in events {
            let key = StreamKey(
                history: event.historyIdentifier,
                consent: event.consentIdentifier,
                session: event.sessionIdentifier,
                app: event.appBundleIdentifier
            )
            var stream = streams[key] ?? StreamState()
            if let last = stream.lastTimestampMilliseconds,
               event.timestampMilliseconds < last
                    || event.timestampMilliseconds - last > 30 * 60 * 1_000 {
                stream = StreamState()
            }
            stream.lastTimestampMilliseconds = event.timestampMilliseconds
            if event.source == .acceptedSuggestion {
                stream.context.removeAll(keepingCapacity: false)
                streams[key] = stream
                continue
            }
            let words = PersonalNextWordShadow.tokenize(event.text).map(Self.folded)
            for target in words where !target.isEmpty {
                let globalPrediction = globalModel.predict(
                    after: stream.context,
                    at: event.timestampMilliseconds,
                    configuration: configuration
                )
                let appPrediction = appModels[event.appBundleIdentifier, default: Model()].predict(
                    after: stream.context,
                    at: event.timestampMilliseconds,
                    configuration: configuration
                )
                if !stream.context.isEmpty,
                   event.timestampMilliseconds >= evaluationStartMilliseconds {
                    let stress = stressLabels[event.id]
                    let selected = select(
                        global: globalPrediction,
                        app: appPrediction,
                        stress: stress,
                        blocked: &result.staleOverrideBlocks
                    )
                    result.targets.append(target)
                    result.global.append(globalPrediction?.word)
                    result.app.append(appPrediction?.word)
                    result.selected.append(selected?.word)
                    result.stress.append(stress)
                }
                globalModel.learn(target, after: stream.context, at: event.timestampMilliseconds)
                var appModel = appModels[event.appBundleIdentifier, default: Model()]
                appModel.learn(target, after: stream.context, at: event.timestampMilliseconds)
                appModels[event.appBundleIdentifier] = appModel
                stream.context.append(target)
                if stream.context.count > 4 {
                    stream.context.removeFirst(stream.context.count - 4)
                }
            }
            streams[key] = stream
        }
        return result
    }

    private func select(
        global: Prediction?,
        app: Prediction?,
        stress: LabPersonalHistoryStressKind?,
        blocked: inout Int
    ) -> Prediction? {
        guard configuration.enabled else { return global }
        switch configuration.scope {
        case .global:
            return global
        case .appSpecific, .appThenGlobal:
            if configuration.arbitration == .production,
               stress != nil, app?.word != global?.word {
                if app != nil { blocked += 1 }
                return global
            }
            if !configuration.mayOverrideBaseSilence, global == nil { return nil }
            switch configuration.arbitration {
            case .production:
                guard let app else { return configuration.scope == .appThenGlobal ? global : nil }
                guard let global else { return app }
                return app.confidence >= global.confidence ? app : global
            case .highestConfidence:
                guard let app else { return configuration.scope == .appThenGlobal ? global : nil }
                guard let global else { return app }
                return app.confidence >= global.confidence ? app : global
            case .personalFirst:
                return app ?? (configuration.scope == .appThenGlobal ? global : nil)
            }
        }
    }

    private static func folded(_ value: String) -> String {
        value.folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .precomposedStringWithCanonicalMapping
    }
}
