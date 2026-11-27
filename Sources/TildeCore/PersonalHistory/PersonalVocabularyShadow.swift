import Foundation

public struct PersonalNextWordOutcomeCells: Codable, Equatable, Sendable {
    public private(set) var baselineSilentCandidateSilent: Int
    public private(set) var baselineSilentCandidateCorrect: Int
    public private(set) var baselineSilentCandidateWrong: Int
    public private(set) var baselineCorrectCandidateSilent: Int
    public private(set) var baselineCorrectCandidateCorrect: Int
    public private(set) var baselineCorrectCandidateWrong: Int
    public private(set) var baselineWrongCandidateSilent: Int
    public private(set) var baselineWrongCandidateCorrect: Int
    public private(set) var baselineWrongCandidateWrong: Int

    init(
        baselineSilentCandidateSilent: Int = 0,
        baselineSilentCandidateCorrect: Int = 0,
        baselineSilentCandidateWrong: Int = 0,
        baselineCorrectCandidateSilent: Int = 0,
        baselineCorrectCandidateCorrect: Int = 0,
        baselineCorrectCandidateWrong: Int = 0,
        baselineWrongCandidateSilent: Int = 0,
        baselineWrongCandidateCorrect: Int = 0,
        baselineWrongCandidateWrong: Int = 0
    ) {
        self.baselineSilentCandidateSilent = baselineSilentCandidateSilent
        self.baselineSilentCandidateCorrect = baselineSilentCandidateCorrect
        self.baselineSilentCandidateWrong = baselineSilentCandidateWrong
        self.baselineCorrectCandidateSilent = baselineCorrectCandidateSilent
        self.baselineCorrectCandidateCorrect = baselineCorrectCandidateCorrect
        self.baselineCorrectCandidateWrong = baselineCorrectCandidateWrong
        self.baselineWrongCandidateSilent = baselineWrongCandidateSilent
        self.baselineWrongCandidateCorrect = baselineWrongCandidateCorrect
        self.baselineWrongCandidateWrong = baselineWrongCandidateWrong
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var decoded: [Int] = []
        for _ in 0..<9 { decoded.append(try container.decode(Int.self)) }
        guard container.isAtEnd else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Invalid paired outcome cells"
            )
        }
        baselineSilentCandidateSilent = decoded[0]
        baselineSilentCandidateCorrect = decoded[1]
        baselineSilentCandidateWrong = decoded[2]
        baselineCorrectCandidateSilent = decoded[3]
        baselineCorrectCandidateCorrect = decoded[4]
        baselineCorrectCandidateWrong = decoded[5]
        baselineWrongCandidateSilent = decoded[6]
        baselineWrongCandidateCorrect = decoded[7]
        baselineWrongCandidateWrong = decoded[8]
        guard isValid else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Invalid paired outcome cells"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for value in values { try container.encode(value) }
    }

    public var opportunities: Int { values.reduce(0, Self.addingWithoutOverflow) }
    public var baselinePredictions: Int {
        baselineCorrectCandidateSilent + baselineCorrectCandidateCorrect
            + baselineCorrectCandidateWrong + baselineWrongCandidateSilent
            + baselineWrongCandidateCorrect + baselineWrongCandidateWrong
    }
    public var baselineExactHits: Int {
        baselineCorrectCandidateSilent + baselineCorrectCandidateCorrect
            + baselineCorrectCandidateWrong
    }
    public var candidatePredictions: Int {
        baselineSilentCandidateCorrect + baselineSilentCandidateWrong
            + baselineCorrectCandidateCorrect + baselineCorrectCandidateWrong
            + baselineWrongCandidateCorrect + baselineWrongCandidateWrong
    }
    public var candidateExactHits: Int {
        baselineSilentCandidateCorrect + baselineCorrectCandidateCorrect
            + baselineWrongCandidateCorrect
    }
    fileprivate var minimumPredictionDisagreements: Int {
        baselineSilentCandidateCorrect + baselineSilentCandidateWrong
            + baselineCorrectCandidateSilent + baselineCorrectCandidateWrong
            + baselineWrongCandidateSilent + baselineWrongCandidateCorrect
    }

    fileprivate var isValid: Bool { values.allSatisfy { $0 >= 0 } && sumIsRepresentable }
    fileprivate var values: [Int] {
        [
            baselineSilentCandidateSilent,
            baselineSilentCandidateCorrect,
            baselineSilentCandidateWrong,
            baselineCorrectCandidateSilent,
            baselineCorrectCandidateCorrect,
            baselineCorrectCandidateWrong,
            baselineWrongCandidateSilent,
            baselineWrongCandidateCorrect,
            baselineWrongCandidateWrong,
        ]
    }

    fileprivate mutating func record(
        baseline: PersonalNextWordShadow.PredictionOutcome,
        candidate: PersonalNextWordShadow.PredictionOutcome
    ) {
        switch (baseline, candidate) {
        case (.silent, .silent): baselineSilentCandidateSilent = incremented(baselineSilentCandidateSilent)
        case (.silent, .correct): baselineSilentCandidateCorrect = incremented(baselineSilentCandidateCorrect)
        case (.silent, .wrong): baselineSilentCandidateWrong = incremented(baselineSilentCandidateWrong)
        case (.correct, .silent): baselineCorrectCandidateSilent = incremented(baselineCorrectCandidateSilent)
        case (.correct, .correct): baselineCorrectCandidateCorrect = incremented(baselineCorrectCandidateCorrect)
        case (.correct, .wrong): baselineCorrectCandidateWrong = incremented(baselineCorrectCandidateWrong)
        case (.wrong, .silent): baselineWrongCandidateSilent = incremented(baselineWrongCandidateSilent)
        case (.wrong, .correct): baselineWrongCandidateCorrect = incremented(baselineWrongCandidateCorrect)
        case (.wrong, .wrong): baselineWrongCandidateWrong = incremented(baselineWrongCandidateWrong)
        }
    }

    private var sumIsRepresentable: Bool {
        var total = 0
        for value in values {
            let result = total.addingReportingOverflow(value)
            if result.overflow { return false }
            total = result.partialValue
        }
        return true
    }

    private func incremented(_ value: Int) -> Int {
        value < Int.max ? value + 1 : value
    }

    private static func addingWithoutOverflow(_ left: Int, _ right: Int) -> Int {
        let result = left.addingReportingOverflow(right)
        return result.overflow ? Int.max : result.partialValue
    }
}

public struct PersonalNextWordPairedAggregate: Codable, Equatable, Sendable {
    public let outcomeCells: PersonalNextWordOutcomeCells
    public let predictionDisagreements: Int

    init(
        outcomeCells: PersonalNextWordOutcomeCells = .init(),
        predictionDisagreements: Int = 0
    ) {
        self.outcomeCells = outcomeCells
        self.predictionDisagreements = predictionDisagreements
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        outcomeCells = try container.decode(PersonalNextWordOutcomeCells.self)
        predictionDisagreements = try container.decode(Int.self)
        guard container.isAtEnd, isValid else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Invalid paired aggregate"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(outcomeCells)
        try container.encode(predictionDisagreements)
    }

    public var opportunities: Int { outcomeCells.opportunities }
    public var baselinePredictions: Int { outcomeCells.baselinePredictions }
    public var baselineExactHits: Int { outcomeCells.baselineExactHits }
    public var candidatePredictions: Int { outcomeCells.candidatePredictions }
    public var candidateExactHits: Int { outcomeCells.candidateExactHits }

    fileprivate var isValid: Bool {
        outcomeCells.isValid
            && predictionDisagreements >= 0
            && predictionDisagreements >= outcomeCells.minimumPredictionDisagreements
            && predictionDisagreements <= opportunities
    }
}

public struct PersonalNextWordDailyAggregate: Codable, Equatable, Sendable {
    /// One of the most recent 64 UTC day buckets. Lifetime totals remain in
    /// the checkpoint after an older bucket ages out.
    public let utcDayStartMilliseconds: Int64
    public let aggregate: PersonalNextWordPairedAggregate

    init(
        utcDayStartMilliseconds: Int64,
        aggregate: PersonalNextWordPairedAggregate
    ) {
        self.utcDayStartMilliseconds = utcDayStartMilliseconds
        self.aggregate = aggregate
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        utcDayStartMilliseconds = try container.decode(Int64.self)
        aggregate = try container.decode(PersonalNextWordPairedAggregate.self)
        guard container.isAtEnd else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Invalid daily aggregate"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(utcDayStartMilliseconds)
        try container.encode(aggregate)
    }
}

public struct PersonalNextWordShadowCheckpoint: Codable, Equatable, Sendable {
    public static let version = 1

    public let v: Int
    public let baselineRecipeID: String
    public let candidateRecipeID: String
    public let evaluationStartMilliseconds: Int64
    public let totals: PersonalNextWordPairedAggregate
    public let activeDays: [PersonalNextWordDailyAggregate]
    public let everCapacityLimited: Bool

    init?(
        evaluationStartMilliseconds: Int64,
        totals: PersonalNextWordPairedAggregate,
        activeDays: [PersonalNextWordDailyAggregate],
        everCapacityLimited: Bool = false
    ) {
        self.v = Self.version
        self.baselineRecipeID = PersonalNextWordShadow.baselineRecipeID
        self.candidateRecipeID = PersonalNextWordShadow.candidateRecipeID
        self.evaluationStartMilliseconds = evaluationStartMilliseconds
        self.totals = totals
        self.activeDays = activeDays
        self.everCapacityLimited = everCapacityLimited
        guard isStructurallyValid else { return nil }
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        v = try container.decode(Int.self)
        baselineRecipeID = try container.decode(String.self)
        candidateRecipeID = try container.decode(String.self)
        evaluationStartMilliseconds = try container.decode(Int64.self)
        totals = try container.decode(PersonalNextWordPairedAggregate.self)
        activeDays = try container.decode([PersonalNextWordDailyAggregate].self)
        everCapacityLimited = try container.decode(Bool.self)
        guard container.isAtEnd, isStructurallyValid else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid aggregate checkpoint")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(v)
        try container.encode(baselineRecipeID)
        try container.encode(candidateRecipeID)
        try container.encode(evaluationStartMilliseconds)
        try container.encode(totals)
        try container.encode(activeDays)
        try container.encode(everCapacityLimited)
    }

    /// Whether this structurally safe checkpoint belongs to the active paired
    /// experiment. Old experiments may decode so their aggregates can be
    /// discarded or migrated without duplicating Core's validation rules.
    public var isCompatibleWithCurrentExperiment: Bool {
        v == Self.version
            && baselineRecipeID == PersonalNextWordShadow.baselineRecipeID
            && candidateRecipeID == PersonalNextWordShadow.candidateRecipeID
            && evaluationStartMilliseconds == PersonalNextWordShadow.evaluationStartMilliseconds
    }

    fileprivate var isStructurallyValid: Bool {
        guard v > 0,
              PersonalHistoryEvent.validIdentifier(baselineRecipeID),
              PersonalHistoryEvent.validIdentifier(candidateRecipeID),
              evaluationStartMilliseconds > 0,
              totals.isValid,
              activeDays.count <= PersonalNextWordShadow.maximumActiveDays else {
            return false
        }
        var priorDay: Int64?
        var dailyCells = Array(repeating: 0, count: 9)
        var dailyDisagreements = 0
        for day in activeDays {
            guard day.utcDayStartMilliseconds >= 0,
                  day.utcDayStartMilliseconds % PersonalNextWordShadow.dayMilliseconds == 0,
                  priorDay.map({ $0 < day.utcDayStartMilliseconds }) ?? true,
                  day.aggregate.isValid,
                  day.aggregate.opportunities > 0 else { return false }
            priorDay = day.utcDayStartMilliseconds
            for (index, value) in day.aggregate.outcomeCells.values.enumerated() {
                let sum = dailyCells[index].addingReportingOverflow(value)
                guard !sum.overflow else { return false }
                dailyCells[index] = sum.partialValue
            }
            let disagreementSum = dailyDisagreements.addingReportingOverflow(
                day.aggregate.predictionDisagreements
            )
            guard !disagreementSum.overflow else { return false }
            dailyDisagreements = disagreementSum.partialValue
        }
        return zip(dailyCells, totals.outcomeCells.values).allSatisfy(<=)
            && dailyDisagreements <= totals.predictionDisagreements
    }
}

/// The trained next-word model itself: the context→target count table the
/// serving lookup reads, plus the per-stream parser state that decides how the
/// next keystroke extends it.
///
/// Until this existed, only `PersonalNextWordShadowCheckpoint`'s paired
/// aggregate counters were durable, and the table was rebuilt on every launch
/// from a bounded tail of raw history — so everything learned beyond that tail
/// quietly disappeared. Persisting it is only safe if a restore is
/// indistinguishable from that rebuild, which is why the streams travel with
/// the table: a restart in the middle of a sentence must not reset the context
/// words, the half-typed token, or the censoring state.
///
/// It carries writing (learned words and the words being typed) and so is only
/// ever written to the same owner-only encrypted store as the history log, and
/// never to a log, diagnostic, or report.
public struct PersonalNextWordTrainedModel: Codable, Equatable, Sendable {
    /// 2: the bounded duplicate-event guard travels with the table, so a
    /// retried append after a restart is skipped exactly as a rebuild would
    /// skip it. A version-1 file is refused and rebuilt from history.
    public static let version = 2

    /// One consumed event, as the shadow remembers it to refuse a repeat.
    public struct RecentEvent: Codable, Equatable, Sendable {
        public let historyIdentifier: String
        public let consentIdentifier: String
        public let sessionIdentifier: String
        public let appBundleIdentifier: String
        public let eventID: String
    }

    public struct Transition: Codable, Equatable, Sendable {
        public let word: String
        public let count: Int
    }

    public struct Context: Codable, Equatable, Sendable {
        public let tokens: [String]
        public let transitions: [Transition]
        public let total: Int
        public let top: String?
        public let runner: String?
    }

    public struct Stream: Codable, Equatable, Sendable {
        public let historyIdentifier: String
        public let consentIdentifier: String
        public let sessionIdentifier: String
        public let appBundleIdentifier: String
        public let token: String
        public let tokenTooLong: Bool
        public let censored: Bool
        public let context: [String]
        public let hasOpportunity: Bool
        public let baselinePrediction: String?
        public let candidatePrediction: String?
        public let lastTimestampMilliseconds: Int64?
    }

    public let v: Int
    /// The learning recipe the table was built with. A recipe change means the
    /// counts no longer mean what a restore would assume, so the model is
    /// discarded and rebuilt rather than misread.
    public let recipeID: String
    public let contexts: [Context]
    public let streams: [Stream]
    public let transitionCount: Int
    public let capacityLimited: Bool
    public let everCapacityLimited: Bool
    /// The in-session duplicate guard, oldest first, bounded by
    /// `PersonalNextWordShadow.maximumRecentEventIDs`.
    public let recentEvents: [RecentEvent]

    init(
        contexts: [Context],
        streams: [Stream],
        transitionCount: Int,
        capacityLimited: Bool,
        everCapacityLimited: Bool,
        recentEvents: [RecentEvent] = []
    ) {
        v = Self.version
        recipeID = PersonalNextWordShadow.recipeID
        self.contexts = contexts
        self.streams = streams
        self.transitionCount = transitionCount
        self.capacityLimited = capacityLimited
        self.everCapacityLimited = everCapacityLimited
        self.recentEvents = recentEvents
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        v = try container.decode(Int.self)
        recipeID = try container.decode(String.self)
        contexts = try container.decode([Context].self)
        streams = try container.decode([Stream].self)
        transitionCount = try container.decode(Int.self)
        capacityLimited = try container.decode(Bool.self)
        everCapacityLimited = try container.decode(Bool.self)
        recentEvents = try container.decode([RecentEvent].self)
        guard container.isAtEnd, isStructurallyValid else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid trained model")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(v)
        try container.encode(recipeID)
        try container.encode(contexts)
        try container.encode(streams)
        try container.encode(transitionCount)
        try container.encode(capacityLimited)
        try container.encode(everCapacityLimited)
        try container.encode(recentEvents)
    }

    /// A schema or recipe change rebuilds instead of misreading a table whose
    /// counts were produced by different rules.
    public var isCompatibleWithCurrentRecipe: Bool {
        v == Self.version && recipeID == PersonalNextWordShadow.recipeID
    }

    var isStructurallyValid: Bool {
        guard v > 0,
              PersonalHistoryEvent.validIdentifier(recipeID),
              transitionCount >= 0,
              transitionCount <= PersonalNextWordShadow.maximumTransitions,
              contexts.count <= PersonalNextWordShadow.maximumContexts,
              streams.count <= PersonalNextWordShadow.maximumActiveStreams,
              recentEvents.count <= PersonalNextWordShadow.maximumRecentEventIDs else { return false }
        var contextKeys = Set<[String]>()
        var transitions = 0
        for context in contexts {
            guard context.tokens.count <= PersonalNextWordShadow.maximumContextWords,
                  context.tokens.allSatisfy(Self.isValidToken),
                  contextKeys.insert(context.tokens).inserted,
                  !context.transitions.isEmpty,
                  context.total >= 0 else { return false }
            var words = Set<String>()
            var largest = 0
            for transition in context.transitions {
                guard transition.count > 0,
                      Self.isValidToken(transition.word),
                      words.insert(transition.word).inserted else { return false }
                largest = max(largest, transition.count)
            }
            guard context.total >= largest else { return false }
            // Transitions are non-empty above, so a top word always exists.
            guard let top = context.top, words.contains(top),
                  context.runner.map({ words.contains($0) && $0 != top }) ?? true else { return false }
            transitions += context.transitions.count
            guard transitions <= PersonalNextWordShadow.maximumTransitions else { return false }
        }
        guard transitions == transitionCount else { return false }
        var streamKeys = Set<[String]>()
        for stream in streams {
            guard PersonalHistoryEvent.validIdentifier(stream.historyIdentifier),
                  PersonalHistoryEvent.validIdentifier(stream.consentIdentifier),
                  PersonalHistoryEvent.validIdentifier(stream.sessionIdentifier),
                  PersonalHistoryEvent.validBundleIdentifier(stream.appBundleIdentifier),
                  streamKeys.insert([
                      stream.historyIdentifier, stream.consentIdentifier,
                      stream.sessionIdentifier, stream.appBundleIdentifier,
                  ]).inserted,
                  stream.token.unicodeScalars.count <= PersonalNextWordShadow.maximumTokenCharacters,
                  stream.context.count <= PersonalNextWordShadow.maximumContextWords,
                  stream.context.allSatisfy(Self.isValidToken),
                  stream.baselinePrediction.map(Self.isValidToken) ?? true,
                  stream.candidatePrediction.map(Self.isValidToken) ?? true,
                  stream.lastTimestampMilliseconds.map({ $0 >= 0 }) ?? true else { return false }
        }
        return true
    }

    private static func isValidToken(_ token: String) -> Bool {
        !token.isEmpty
            && token.unicodeScalars.count <= PersonalNextWordShadow.maximumTokenCharacters
    }
}

/// Aggregate-only result of the paired local next-word experiment.
public struct PersonalNextWordShadowSnapshot: Equatable, Sendable {
    // Candidate aliases retained for the original live shadow API.
    public let opportunities: Int
    public let predictions: Int
    public let exactHits: Int
    public let learnedContexts: Int
    public let learnedTransitions: Int
    public let capacityLimited: Bool
    public let baselinePredictions: Int
    public let baselineExactHits: Int
    public let outcomeCells: PersonalNextWordOutcomeCells
    public let predictionDisagreements: Int
    public let activeDays: Int

    init(
        opportunities: Int,
        predictions: Int,
        exactHits: Int,
        learnedContexts: Int,
        learnedTransitions: Int,
        capacityLimited: Bool,
        baselinePredictions: Int = 0,
        baselineExactHits: Int = 0,
        outcomeCells: PersonalNextWordOutcomeCells = .init(),
        predictionDisagreements: Int = 0,
        activeDays: Int = 0
    ) {
        self.opportunities = opportunities
        self.predictions = predictions
        self.exactHits = exactHits
        self.learnedContexts = learnedContexts
        self.learnedTransitions = learnedTransitions
        self.capacityLimited = capacityLimited
        self.baselinePredictions = baselinePredictions
        self.baselineExactHits = baselineExactHits
        self.outcomeCells = outcomeCells
        self.predictionDisagreements = predictionDisagreements
        self.activeDays = activeDays
    }

    public var coverage: Double {
        opportunities == 0 ? 0 : Double(predictions) / Double(opportunities)
    }
    public var precision: Double {
        predictions == 0 ? 0 : Double(exactHits) / Double(predictions)
    }
    public var baselineCoverage: Double {
        opportunities == 0 ? 0 : Double(baselinePredictions) / Double(opportunities)
    }
    public var baselinePrecision: Double {
        baselinePredictions == 0 ? 0 : Double(baselineExactHits) / Double(baselinePredictions)
    }
}

/// A single production-serving lookup result from `predictNextWord`. Not
/// part of the paired shadow experiment's scoring types above — this is the
/// read-only path the "Personal suggestions (experimental)" toggle uses.
public struct PersonalNextWordPrediction: Equatable, Sendable {
    public let word: String
    public let support: Int
    public let total: Int
}

/// One parser and count model score the conservative baseline and the candidate.
public struct PersonalNextWordShadow: Sendable {
    public static let baselineRecipeID = "r1435-live-v1"
    public static let candidateRecipeID = "r1945-live-v1"
    public static let recipeID = candidateRecipeID
    public static let evaluationStartMilliseconds: Int64 = 1_786_556_700_000

    static let maximumContexts = 8_192
    static let maximumTransitions = 32_768
    static let maximumActiveStreams = 64
    static let maximumRecentEventIDs = 2_048
    static let maximumActiveDays = 64
    static let dayMilliseconds: Int64 = 24 * 60 * 60 * 1_000
    static let maximumContextWords = 4
    static let maximumTokenCharacters = 30
    private static let minimumWinnerSupport = 2
    private static let streamGapMilliseconds: Int64 = 30 * 60 * 1_000

    fileprivate enum PredictionOutcome { case silent, correct, wrong }

    private struct StreamKey: Hashable, Sendable {
        let history: String
        let consent: String
        let session: String
        let app: String
    }
    private struct EventIdentity: Hashable, Sendable {
        let stream: StreamKey
        let event: String
    }
    private struct Predictions: Equatable, Sendable {
        var baseline: String?
        var candidate: String?
    }
    private struct StreamState: Sendable {
        var token = ""
        var tokenTooLong = false
        var censored = true
        var context: [String] = []
        var hasOpportunity = false
        var predictions = Predictions()
        var lastTimestampMilliseconds: Int64?
    }
    private struct ContextKey: Hashable, Sendable { let tokens: [String] }
    private struct TargetBag: Sendable {
        var counts: [String: Int] = [:]
        var total = 0
        var top: String?
        var runner: String?

        mutating func add(_ target: String) {
            counts[target] = incremented(counts[target, default: 0])
            total = incremented(total)
            let choices = Set([top, runner, target].compactMap { $0 })
            let ranked = choices.sorted { left, right in
                let leftCount = counts[left, default: 0]
                let rightCount = counts[right, default: 0]
                if leftCount != rightCount { return leftCount > rightCount }
                return PersonalNextWordShadow.surfacePrecedes(left, right)
            }
            top = ranked.first
            runner = ranked.dropFirst().first
        }

        var winner: (surface: String, support: Int, runner: Int, total: Int)? {
            guard let top else { return nil }
            return (top, counts[top, default: 0], runner.map { counts[$0, default: 0] } ?? 0, total)
        }

        private func incremented(_ value: Int) -> Int { value == Int.max ? value : value + 1 }
    }

    private let evaluationStart: Int64
    private var model: [ContextKey: TargetBag] = [:]
    private var transitionCount = 0
    private var streams: [StreamKey: StreamState] = [:]
    private var streamOrder: [StreamKey] = []
    private var recentEventIDs: [EventIdentity] = []
    private var recentEventIDSet: Set<EventIdentity> = []
    private var nextEventEvictionIndex = 0
    private var totals = PersonalNextWordPairedAggregate()
    private var days: [Int64: PersonalNextWordPairedAggregate] = [:]
    private var capacityLimited = false
    private var everCapacityLimited = false

    public init(evaluationStartMilliseconds: Int64 = Self.evaluationStartMilliseconds) {
        evaluationStart = max(0, evaluationStartMilliseconds)
    }

    public init?(checkpoint: PersonalNextWordShadowCheckpoint) {
        guard checkpoint.isCompatibleWithCurrentExperiment else { return nil }
        evaluationStart = checkpoint.evaluationStartMilliseconds
        totals = checkpoint.totals
        days = Dictionary(uniqueKeysWithValues: checkpoint.activeDays.map {
            ($0.utcDayStartMilliseconds, $0.aggregate)
        })
        everCapacityLimited = checkpoint.everCapacityLimited
    }

    public var checkpoint: PersonalNextWordShadowCheckpoint {
        precondition(
            evaluationStart == Self.evaluationStartMilliseconds,
            "Only the prospective production experiment can be checkpointed"
        )
        return PersonalNextWordShadowCheckpoint(
            evaluationStartMilliseconds: evaluationStart,
            totals: totals,
            activeDays: days.keys.sorted().map {
                PersonalNextWordDailyAggregate(utcDayStartMilliseconds: $0, aggregate: days[$0]!)
            },
            everCapacityLimited: everCapacityLimited || capacityLimited
        )!
    }

    /// The durable form of everything training has produced. Deterministic
    /// (contexts and transitions in a fixed order) so two shadows that would
    /// predict identically also serialize identically.
    ///
    /// `recentEvents` travels too: an append whose acknowledgement was lost
    /// is retried after a restart, and a restored table must refuse it the
    /// way a rebuild from the log would.
    public var trainedModel: PersonalNextWordTrainedModel {
        let contexts = model.keys
            .sorted { Self.tokensPrecede($0.tokens, $1.tokens) }
            .map { key -> PersonalNextWordTrainedModel.Context in
                let bag = model[key]!
                return PersonalNextWordTrainedModel.Context(
                    tokens: key.tokens,
                    transitions: bag.counts.keys
                        .sorted(by: Self.surfacePrecedes)
                        .map { .init(word: $0, count: bag.counts[$0]!) },
                    total: bag.total,
                    top: bag.top,
                    runner: bag.runner
                )
            }
        let streams = streamOrder.compactMap { key -> PersonalNextWordTrainedModel.Stream? in
            guard let state = self.streams[key] else { return nil }
            return PersonalNextWordTrainedModel.Stream(
                historyIdentifier: key.history,
                consentIdentifier: key.consent,
                sessionIdentifier: key.session,
                appBundleIdentifier: key.app,
                token: state.token,
                tokenTooLong: state.tokenTooLong,
                censored: state.censored,
                context: state.context,
                hasOpportunity: state.hasOpportunity,
                baselinePrediction: state.predictions.baseline,
                candidatePrediction: state.predictions.candidate,
                lastTimestampMilliseconds: state.lastTimestampMilliseconds
            )
        }
        return PersonalNextWordTrainedModel(
            contexts: contexts,
            streams: streams,
            transitionCount: transitionCount,
            capacityLimited: capacityLimited,
            everCapacityLimited: everCapacityLimited,
            recentEvents: recentEventsOldestFirst.map {
                PersonalNextWordTrainedModel.RecentEvent(
                    historyIdentifier: $0.stream.history,
                    consentIdentifier: $0.stream.consent,
                    sessionIdentifier: $0.stream.session,
                    appBundleIdentifier: $0.stream.app,
                    eventID: $0.event
                )
            }
        )
    }

    /// The ring in the order it would be evicted, so a restore rebuilds the
    /// same eviction sequence.
    private var recentEventsOldestFirst: [EventIdentity] {
        guard recentEventIDs.count == Self.maximumRecentEventIDs else { return recentEventIDs }
        return Array(recentEventIDs[nextEventEvictionIndex...] + recentEventIDs[..<nextEventEvictionIndex])
    }

    /// Puts a persisted table back, leaving the paired aggregate counters
    /// (which travel in `PersonalNextWordShadowCheckpoint`) untouched.
    /// Returns false — and changes nothing — for a model from another recipe
    /// or schema, so the caller falls back to rebuilding from raw history.
    @discardableResult
    public mutating func restore(_ trained: PersonalNextWordTrainedModel) -> Bool {
        guard trained.isCompatibleWithCurrentRecipe, trained.isStructurallyValid else {
            return false
        }
        var restored: [ContextKey: TargetBag] = [:]
        restored.reserveCapacity(trained.contexts.count)
        for context in trained.contexts {
            var bag = TargetBag()
            bag.counts = Dictionary(
                uniqueKeysWithValues: context.transitions.map { ($0.word, $0.count) }
            )
            bag.total = context.total
            bag.top = context.top
            bag.runner = context.runner
            restored[ContextKey(tokens: context.tokens)] = bag
        }
        model = restored
        transitionCount = trained.transitionCount
        capacityLimited = trained.capacityLimited
        everCapacityLimited = trained.everCapacityLimited
        recentEventIDs = []
        recentEventIDSet = []
        nextEventEvictionIndex = 0
        for recent in trained.recentEvents {
            let identity = EventIdentity(
                stream: StreamKey(
                    history: recent.historyIdentifier,
                    consent: recent.consentIdentifier,
                    session: recent.sessionIdentifier,
                    app: recent.appBundleIdentifier
                ),
                event: recent.eventID
            )
            guard recentEventIDSet.insert(identity).inserted else { continue }
            recentEventIDs.append(identity)
        }
        streams = [:]
        streamOrder = []
        for stream in trained.streams {
            let key = StreamKey(
                history: stream.historyIdentifier,
                consent: stream.consentIdentifier,
                session: stream.sessionIdentifier,
                app: stream.appBundleIdentifier
            )
            var state = StreamState()
            state.token = stream.token
            state.tokenTooLong = stream.tokenTooLong
            state.censored = stream.censored
            state.context = stream.context
            state.hasOpportunity = stream.hasOpportunity
            state.predictions = Predictions(
                baseline: stream.baselinePrediction,
                candidate: stream.candidatePrediction
            )
            state.lastTimestampMilliseconds = stream.lastTimestampMilliseconds
            streams[key] = state
            streamOrder.append(key)
        }
        return true
    }

    private static func tokensPrecede(_ left: [String], _ right: [String]) -> Bool {
        if left.count != right.count { return left.count < right.count }
        for (leftToken, rightToken) in zip(left, right) where leftToken != rightToken {
            return surfacePrecedes(leftToken, rightToken)
        }
        return false
    }

    public var snapshot: PersonalNextWordShadowSnapshot {
        PersonalNextWordShadowSnapshot(
            opportunities: totals.opportunities,
            predictions: totals.candidatePredictions,
            exactHits: totals.candidateExactHits,
            learnedContexts: model.count,
            learnedTransitions: transitionCount,
            capacityLimited: capacityLimited || everCapacityLimited,
            baselinePredictions: totals.baselinePredictions,
            baselineExactHits: totals.baselineExactHits,
            outcomeCells: totals.outcomeCells,
            predictionDisagreements: totals.predictionDisagreements,
            activeDays: days.count
        )
    }

    public mutating func consume(_ events: [PersonalHistoryEvent], scoring: Bool = true) {
        for event in events {
            let key = StreamKey(
                history: event.historyIdentifier,
                consent: event.consentIdentifier,
                session: event.sessionIdentifier,
                app: event.appBundleIdentifier
            )
            guard remember(event, in: key) else { continue }
            var state = takeStream(for: key)
            if let last = state.lastTimestampMilliseconds,
               event.timestampMilliseconds < last
                || event.timestampMilliseconds - last > Self.streamGapMilliseconds {
                state = StreamState()
            }
            state.lastTimestampMilliseconds = event.timestampMilliseconds

            if event.source == .acceptedSuggestion {
                censorAcceptedText(event.text, state: &state)
            } else {
                for scalar in event.text.precomposedStringWithCanonicalMapping.unicodeScalars {
                    consumeTyped(
                        scalar,
                        timestampMilliseconds: event.timestampMilliseconds,
                        scoring: scoring,
                        state: &state
                    )
                }
            }
            streams[key] = state
        }
    }

    public mutating func reset() { self = Self(evaluationStartMilliseconds: evaluationStart) }

    private mutating func takeStream(for key: StreamKey) -> StreamState {
        if let state = streams.removeValue(forKey: key) { return state }
        if streams.count >= Self.maximumActiveStreams, let oldest = streamOrder.first {
            streamOrder.removeFirst()
            streams.removeValue(forKey: oldest)
        }
        streamOrder.append(key)
        return StreamState()
    }

    private mutating func consumeTyped(
        _ scalar: Unicode.Scalar,
        timestampMilliseconds: Int64,
        scoring: Bool,
        state: inout StreamState
    ) {
        if Self.isLetter(scalar) {
            guard !state.censored, !state.tokenTooLong else { return }
            state.token.unicodeScalars.append(scalar)
            if state.token.unicodeScalars.count > Self.maximumTokenCharacters {
                state.token.removeAll(keepingCapacity: false)
                state.tokenTooLong = true
            }
            return
        }
        if Self.isMark(scalar), !state.censored, !state.tokenTooLong, !state.token.isEmpty {
            let combined = Self.surface(state.token + String(scalar))
            if combined.unicodeScalars.allSatisfy(Self.isLetter) {
                state.token = combined
                return
            }
        }
        if state.censored {
            state.censored = false
            state.token.removeAll(keepingCapacity: true)
            state.tokenTooLong = false
            return
        }
        finishToken(
            timestampMilliseconds: timestampMilliseconds,
            scoring: scoring,
            state: &state
        )
    }

    private mutating func finishToken(
        timestampMilliseconds: Int64,
        scoring: Bool,
        state: inout StreamState
    ) {
        defer {
            state.token.removeAll(keepingCapacity: true)
            state.tokenTooLong = false
        }
        guard !state.tokenTooLong, !state.token.isEmpty else { return }
        let target = Self.surface(state.token)
        guard (1...Self.maximumTokenCharacters).contains(target.unicodeScalars.count) else { return }

        if scoring, state.hasOpportunity, timestampMilliseconds >= evaluationStart {
            record(predictions: state.predictions, target: target, at: timestampMilliseconds)
        }
        learn(target, after: state.context)
        state.context.append(Self.folded(target))
        if state.context.count > Self.maximumContextWords {
            state.context.removeFirst(state.context.count - Self.maximumContextWords)
        }
        state.hasOpportunity = true
        state.predictions = Predictions(
            baseline: candidate(after: state.context, maximumContext: 2, minimumRatio: 2),
            candidate: candidate(after: state.context, maximumContext: 4, minimumRatio: 1)
        )
    }

    private mutating func record(predictions: Predictions, target: String, at timestamp: Int64) {
        let baseline = Self.outcome(predictions.baseline, target: target)
        let candidate = Self.outcome(predictions.candidate, target: target)
        let disagreed = predictions.baseline != predictions.candidate
        var totalCells = totals.outcomeCells
        totalCells.record(baseline: baseline, candidate: candidate)
        totals = PersonalNextWordPairedAggregate(
            outcomeCells: totalCells,
            predictionDisagreements: Self.incremented(totals.predictionDisagreements, if: disagreed)
        )

        let day = timestamp / Self.dayMilliseconds * Self.dayMilliseconds
        var daily = days[day] ?? PersonalNextWordPairedAggregate()
        var dailyCells = daily.outcomeCells
        dailyCells.record(baseline: baseline, candidate: candidate)
        daily = PersonalNextWordPairedAggregate(
            outcomeCells: dailyCells,
            predictionDisagreements: Self.incremented(daily.predictionDisagreements, if: disagreed)
        )
        days[day] = daily
        if days.count > Self.maximumActiveDays, let oldest = days.keys.min() {
            days.removeValue(forKey: oldest)
        }
    }

    private mutating func censorAcceptedText(_ text: String, state: inout StreamState) {
        state.token.removeAll(keepingCapacity: false)
        state.tokenTooLong = false
        state.context.removeAll(keepingCapacity: false)
        state.hasOpportunity = false
        state.predictions = Predictions()
        state.censored = true
        for scalar in text.precomposedStringWithCanonicalMapping.unicodeScalars {
            state.censored = Self.isLetter(scalar)
        }
    }

    private func candidate(
        after history: [String],
        maximumContext: Int,
        minimumRatio: Int
    ) -> String? {
        Self.winningPrediction(
            in: model,
            after: history,
            maximumContext: maximumContext,
            minimumRatio: minimumRatio
        )?.word
    }

    /// Read-only production lookup for experimental personal-word serving
    /// (`docs/plans/road-to-paid.md` Phase 3, the "Personal suggestions
    /// (experimental)" menu toggle). Deliberately reuses the shadow
    /// experiment's own conservative "baseline" recipe parameters
    /// (`baselineRecipeID`'s 2-word context, 2x-support-over-runner-up
    /// ratio) rather than the looser candidate recipe still under live A/B
    /// test — serving a real suggestion should never lean on a threshold
    /// that hasn't itself been vetted as a safe production bar. Purely a
    /// lookup over `model`: no mutation, no interaction with `consume`'s
    /// paired scoring, callable any number of times with no side effects.
    /// Splits `text` into the same letter-run tokens `consume` extracts one
    /// keystroke at a time while training the model: a run of Unicode
    /// letters is one token (a combining mark only extends it when the
    /// combination stays all-letters, matching `consumeTyped`'s rule), and
    /// everything else — whitespace, punctuation, apostrophes, hyphens,
    /// digits — is a separator. Serving must tokenize context with this
    /// exact rule, not a looser one: "don't" was learned as two
    /// transitions, `["don", "t"]`, never as one token `["don't"]`.
    public static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var token = ""
        for scalar in text.precomposedStringWithCanonicalMapping.unicodeScalars {
            if isLetter(scalar) {
                token.unicodeScalars.append(scalar)
                continue
            }
            if isMark(scalar), !token.isEmpty {
                let combined = surface(token + String(scalar))
                if combined.unicodeScalars.allSatisfy(isLetter) {
                    token = combined
                    continue
                }
            }
            if !token.isEmpty {
                tokens.append(surface(token))
                token = ""
            }
        }
        if !token.isEmpty { tokens.append(surface(token)) }
        return tokens
    }

    /// English contraction remainders the letter-run tokenizer produces
    /// when it splits on the apostrophe ("I'll" -> `["i", "ll"]`, "don't"
    /// -> `["don", "t"]`). These are real transitions the model needs for
    /// context, but never a legitimate whole next word on their own —
    /// serving one verbatim glues onto whatever the user is mid-typing
    /// next ("I think I " -> "ll").
    private static let contractionFragments: Set<String> = ["t", "s", "d", "m", "ll", "re", "ve"]

    public func predictNextWord(afterTailWords tailWords: [String]) -> PersonalNextWordPrediction? {
        let folded = tailWords.suffix(Self.maximumContextWords).map(Self.folded)
        guard let prediction = Self.winningPrediction(
            in: model,
            after: Array(folded),
            maximumContext: 2,
            minimumRatio: 2,
            // Never fall all the way back to the empty-context global
            // unigram bag for a served suggestion — a single globally
            // dominant word (e.g. a name typed constantly) would otherwise
            // surface in totally unrelated contexts. The shadow's own A/B
            // recipe evaluation below still backs off to order 0 by
            // default; this bound only tightens what's actually served.
            minimumOrder: 1
        ) else { return nil }
        guard !Self.contractionFragments.contains(Self.folded(prediction.word)) else { return nil }
        return prediction
    }

    /// Non-mutating read of high-support personal vocabulary and context-matched
    /// continuations for decode-time Word Nudge (`logit_bias`). Never alters
    /// shadow scoring or model state.
    public func topBiasTerms(
        afterTailWords tailWords: [String],
        limit: Int = 12
    ) -> [WeightedBiasTerm] {
        guard limit > 0 else { return [] }
        let foldedHistory = tailWords.suffix(Self.maximumContextWords).map(Self.folded)
        var candidates: [String: (surface: String, weight: Double, support: Int)] = [:]

        // 1. Context-conditioned continuations (order 2 -> order 1) get higher nudge.
        let maxOrder = min(2, foldedHistory.count)
        if maxOrder >= 1 {
            for order in stride(from: maxOrder, through: 1, by: -1) {
                guard let bag = model[Self.contextKey(order: order, history: Array(foldedHistory))] else {
                    continue
                }
                for (surface, count) in bag.counts where count >= 2 {
                    let folded = Self.folded(surface)
                    guard DecodeBiasPolicy.isEligibleBiasWord(folded),
                          !Self.contractionFragments.contains(folded) else { continue }
                    let weight = DecodeBiasPolicy.personalContextWeight
                    if let existing = candidates[folded] {
                        if weight > existing.weight || (weight == existing.weight && count > existing.support) {
                            candidates[folded] = (surface, weight, count)
                        }
                    } else {
                        candidates[folded] = (surface, weight, count)
                    }
                }
            }
        }

        // 2. High-support personal salient lexicon words (order 0) fill remaining slots.
        if let unigramBag = model[Self.contextKey(order: 0, history: [])] {
            for (surface, count) in unigramBag.counts where count >= 4 {
                let folded = Self.folded(surface)
                guard DecodeBiasPolicy.isEligibleBiasWord(folded),
                      !Self.contractionFragments.contains(folded) else { continue }
                let weight = DecodeBiasPolicy.personalLexiconWeight
                if candidates[folded] == nil {
                    candidates[folded] = (surface, weight, count)
                }
            }
        }

        return candidates.values
            .sorted { lhs, rhs in
                if lhs.weight != rhs.weight { return lhs.weight > rhs.weight }
                if lhs.support != rhs.support { return lhs.support > rhs.support }
                return lhs.surface < rhs.surface
            }
            .prefix(limit)
            .map { WeightedBiasTerm(term: $0.surface, weight: $0.weight) }
    }

    private static func winningPrediction(
        in model: [ContextKey: TargetBag],
        after history: [String],
        maximumContext: Int,
        minimumRatio: Int,
        minimumOrder: Int = 0
    ) -> PersonalNextWordPrediction? {
        let maximum = min(maximumContext, history.count)
        guard maximum >= minimumOrder else { return nil }
        for order in stride(from: maximum, through: minimumOrder, by: -1) {
            guard let winner = model[Self.contextKey(order: order, history: history)]?.winner else {
                continue
            }
            let requiredShare = winner.total / 2 + winner.total % 2
            let meetsRatio = minimumRatio == 1
                || winner.runner == 0
                || winner.runner <= winner.support / minimumRatio
            if winner.support >= Self.minimumWinnerSupport,
               winner.support >= requiredShare,
               meetsRatio {
                return PersonalNextWordPrediction(word: winner.surface, support: winner.support, total: winner.total)
            }
        }
        return nil
    }

    private mutating func learn(_ target: String, after history: [String]) {
        guard !capacityLimited else { return }
        let maximum = min(Self.maximumContextWords, history.count)
        let keys = (0...maximum).map { Self.contextKey(order: $0, history: history) }
        let addedContexts = keys.reduce(into: 0) { if model[$1] == nil { $0 += 1 } }
        let addedTransitions = keys.reduce(into: 0) { if model[$1]?.counts[target] == nil { $0 += 1 } }
        guard model.count <= Self.maximumContexts - addedContexts,
              transitionCount <= Self.maximumTransitions - addedTransitions else {
            capacityLimited = true
            everCapacityLimited = true
            return
        }
        for key in keys {
            let isNewTransition = model[key]?.counts[target] == nil
            model[key, default: TargetBag()].add(target)
            if isNewTransition { transitionCount += 1 }
        }
    }

    private mutating func remember(_ event: PersonalHistoryEvent, in stream: StreamKey) -> Bool {
        let identity = EventIdentity(stream: stream, event: event.id)
        guard recentEventIDSet.insert(identity).inserted else { return false }
        if recentEventIDs.count < Self.maximumRecentEventIDs {
            recentEventIDs.append(identity)
        } else {
            recentEventIDSet.remove(recentEventIDs[nextEventEvictionIndex])
            recentEventIDs[nextEventEvictionIndex] = identity
            nextEventEvictionIndex = (nextEventEvictionIndex + 1) % Self.maximumRecentEventIDs
        }
        return true
    }

    private static func outcome(_ prediction: String?, target: String) -> PredictionOutcome {
        guard let prediction else { return .silent }
        return prediction == target ? .correct : .wrong
    }
    private static func incremented(_ value: Int, if condition: Bool) -> Int {
        condition && value < Int.max ? value + 1 : value
    }
    private static func contextKey(order: Int, history: [String]) -> ContextKey {
        ContextKey(tokens: order == 0 ? [] : Array(history.suffix(order)))
    }
    private static func folded(_ token: String) -> String {
        surface(token).folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .precomposedStringWithCanonicalMapping
    }
    private static func surface(_ token: String) -> String {
        token.precomposedStringWithCanonicalMapping
    }
    private static func surfacePrecedes(_ left: String, _ right: String) -> Bool {
        var leftScalars = left.unicodeScalars.makeIterator()
        var rightScalars = right.unicodeScalars.makeIterator()
        while let leftScalar = leftScalars.next() {
            guard let rightScalar = rightScalars.next() else { return false }
            if leftScalar.value != rightScalar.value { return leftScalar.value < rightScalar.value }
        }
        return rightScalars.next() != nil
    }
    private static func isLetter(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter:
            true
        default: false
        }
    }
    private static func isMark(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark: true
        default: false
        }
    }
}

// MARK: - Personal Phrase & Recency Expert (H11 / H13)

/// Read-only result of a `<1 ms` chronological 2–4 gram personal phrase lookup.
/// Carries only the matched continuation statistics needed for quiet-gate
/// agreement scoring and offline Lab evaluation.
public struct PersonalPhraseMatch: Equatable, Sendable {
    /// Matched n-gram order (`2` = 1-word context, `3` = 2-word context,
    /// `4` = 3-word context).
    public let order: Int
    /// Exact raw observation count of `firstWord` in the matched context.
    public let support: Int
    /// Chronologically decayed support (`halfLifeDays` exponential decay) at the
    /// lookup's reference timestamp.
    public let recencySupport: Double
    /// Total observation count across all continuations in the matched context.
    public let contextTotal: Int
    /// Smoothed confidence `Double(support) / (Double(contextTotal) + alpha)`.
    public let confidence: Double
    /// Lowercase normalized top-1 continuation word.
    public let firstWord: String
    /// Clean surface casing for `firstWord`.
    public let firstWordSurface: String
    /// Up to top-3 normalized continuation words ranked by recency-aware score.
    public let topFirstWords: [String]
    /// Best 1–3 word personal continuation phrase.
    public let phrase: String
    /// Number of words in `phrase`.
    public let wordCount: Int
    /// Whether the match came from the same writing register channel.
    public let registerMatched: Bool

    public init(
        order: Int,
        support: Int,
        recencySupport: Double,
        contextTotal: Int,
        confidence: Double,
        firstWord: String,
        firstWordSurface: String,
        topFirstWords: [String],
        phrase: String,
        wordCount: Int,
        registerMatched: Bool
    ) {
        self.order = order
        self.support = support
        self.recencySupport = recencySupport
        self.contextTotal = contextTotal
        self.confidence = confidence
        self.firstWord = firstWord
        self.firstWordSurface = firstWordSurface
        self.topFirstWords = topFirstWords
        self.phrase = phrase
        self.wordCount = wordCount
        self.registerMatched = registerMatched
    }

    /// Evaluates agreement between this personal phrase prediction and a model
    /// candidate's visible text, returning the strictly text-free features
    /// consumed by `SuggestionQuietGate`.
    ///
    /// Returns `(false, 0.0)` whenever the candidate does not agree on the
    /// first word, so disagreeing candidates are never boosted.
    public func agreement(with suggestionVisibleText: String) -> (agreed: Bool, logSupport: Double) {
        guard let candidateFirst = PersonalPhraseExpert.firstNormalizedWord(in: suggestionVisibleText),
              candidateFirst == firstWord else {
            return (false, 0.0)
        }
        let effectiveSupport = recencySupport > 0
            ? max(recencySupport, Double(support) * 0.25)
            : Double(support)
        let logSupport = effectiveSupport > 0 ? log(1.0 + effectiveSupport) : 0.0
        return (true, logSupport.isFinite ? max(0.0, logSupport) : 0.0)
    }
}

/// Durable, versioned representation of `PersonalPhraseExpert` encrypted at
/// rest alongside `PersonalNextWordTrainedModel` inside the owner-only
/// Personal History store. Never written to logs, diagnostics, or reports.
public struct PersonalPhraseExpertSnapshot: Codable, Equatable, Sendable {
    public static let version = 1
    public static let recipeID = "personal-phrase-expert-v1"

    public struct Transition: Codable, Equatable, Sendable {
        public let word: String
        public let surface: String
        public let count: Int
        public let recencyWeight: Double
        public let lastTimestampMilliseconds: Int64

        public init(
            word: String,
            surface: String,
            count: Int,
            recencyWeight: Double,
            lastTimestampMilliseconds: Int64
        ) {
            self.word = word
            self.surface = surface
            self.count = count
            self.recencyWeight = recencyWeight
            self.lastTimestampMilliseconds = lastTimestampMilliseconds
        }

        public init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            word = try c.decode(String.self)
            surface = try c.decode(String.self)
            count = try c.decode(Int.self)
            recencyWeight = try c.decode(Double.self)
            lastTimestampMilliseconds = try c.decode(Int64.self)
            guard c.isAtEnd else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid phrase transition")
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.unkeyedContainer()
            try c.encode(word)
            try c.encode(surface)
            try c.encode(count)
            try c.encode(recencyWeight)
            try c.encode(lastTimestampMilliseconds)
        }
    }

    public struct ContextEntry: Codable, Equatable, Sendable {
        public let tokens: [String]
        public let transitions: [Transition]
        public let total: Int

        public init(tokens: [String], transitions: [Transition], total: Int) {
            self.tokens = tokens
            self.transitions = transitions
            self.total = total
        }

        public init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            tokens = try c.decode([String].self)
            transitions = try c.decode([Transition].self)
            total = try c.decode(Int.self)
            guard c.isAtEnd else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid phrase context")
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.unkeyedContainer()
            try c.encode(tokens)
            try c.encode(transitions)
            try c.encode(total)
        }
    }

    public struct RegisterContextEntry: Codable, Equatable, Sendable {
        public let register: ContinuationRegister
        public let tokens: [String]
        public let transitions: [Transition]
        public let total: Int

        public init(
            register: ContinuationRegister,
            tokens: [String],
            transitions: [Transition],
            total: Int
        ) {
            self.register = register
            self.tokens = tokens
            self.transitions = transitions
            self.total = total
        }

        public init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            register = try c.decode(ContinuationRegister.self)
            tokens = try c.decode([String].self)
            transitions = try c.decode([Transition].self)
            total = try c.decode(Int.self)
            guard c.isAtEnd else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid register context")
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.unkeyedContainer()
            try c.encode(register)
            try c.encode(tokens)
            try c.encode(transitions)
            try c.encode(total)
        }
    }

    public struct PhraseTransition: Codable, Equatable, Sendable {
        public let words: [String]
        public let surfaces: [String]
        public let count: Int
        public let recencyWeight: Double
        public let lastTimestampMilliseconds: Int64

        public init(
            words: [String],
            surfaces: [String],
            count: Int,
            recencyWeight: Double,
            lastTimestampMilliseconds: Int64
        ) {
            self.words = words
            self.surfaces = surfaces
            self.count = count
            self.recencyWeight = recencyWeight
            self.lastTimestampMilliseconds = lastTimestampMilliseconds
        }

        public init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            words = try c.decode([String].self)
            surfaces = try c.decode([String].self)
            count = try c.decode(Int.self)
            recencyWeight = try c.decode(Double.self)
            lastTimestampMilliseconds = try c.decode(Int64.self)
            guard c.isAtEnd else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid multi-word transition")
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.unkeyedContainer()
            try c.encode(words)
            try c.encode(surfaces)
            try c.encode(count)
            try c.encode(recencyWeight)
            try c.encode(lastTimestampMilliseconds)
        }
    }

    public struct PhraseContextEntry: Codable, Equatable, Sendable {
        public let tokens: [String]
        public let transitions: [PhraseTransition]

        public init(tokens: [String], transitions: [PhraseTransition]) {
            self.tokens = tokens
            self.transitions = transitions
        }

        public init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            tokens = try c.decode([String].self)
            transitions = try c.decode([PhraseTransition].self)
            guard c.isAtEnd else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid multi-word context")
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.unkeyedContainer()
            try c.encode(tokens)
            try c.encode(transitions)
        }
    }

    public struct StreamSnapshot: Codable, Equatable, Sendable {
        public let historyIdentifier: String
        public let consentIdentifier: String
        public let sessionIdentifier: String
        public let appBundleIdentifier: String
        public let context: [String]
        public let pendingBuffer: String
        public let lastTimestampMilliseconds: Int64?
    }

    public struct RecentEvent: Codable, Equatable, Sendable {
        public let historyIdentifier: String
        public let consentIdentifier: String
        public let sessionIdentifier: String
        public let appBundleIdentifier: String
        public let eventID: String
    }

    public let v: Int
    public let recipeID: String
    public let latestTimestampMilliseconds: Int64
    public let globalContexts: [ContextEntry]
    public let registerContexts: [RegisterContextEntry]
    public let phraseContexts: [PhraseContextEntry]
    public let streams: [StreamSnapshot]
    public let recentEvents: [RecentEvent]

    public var isCompatibleWithCurrentRecipe: Bool {
        v == Self.version && recipeID == Self.recipeID
    }

    public var isStructurallyValid: Bool {
        guard v > 0,
              PersonalHistoryEvent.validIdentifier(recipeID),
              latestTimestampMilliseconds >= 0,
              globalContexts.count <= PersonalPhraseExpert.maximumGlobalContexts,
              registerContexts.count <= PersonalPhraseExpert.maximumRegisterContexts,
              phraseContexts.count <= PersonalPhraseExpert.maximumPhraseContexts,
              streams.count <= PersonalPhraseExpert.maximumActiveStreams,
              recentEvents.count <= PersonalPhraseExpert.maximumRecentEventIDs else {
            return false
        }
        var seenGlobal = Set<[String]>()
        for entry in globalContexts {
            guard (1...3).contains(entry.tokens.count),
                  entry.tokens.allSatisfy(PersonalPhraseExpert.isValidStoredToken),
                  seenGlobal.insert(entry.tokens).inserted,
                  !entry.transitions.isEmpty,
                  entry.transitions.count <= PersonalPhraseExpert.maximumTargetsPerContext,
                  entry.total >= 0 else {
                return false
            }
            var seenTargets = Set<String>()
            for t in entry.transitions {
                guard PersonalPhraseExpert.isValidStoredToken(t.word),
                      PersonalPhraseExpert.isValidStoredToken(t.surface),
                      t.count > 0,
                      t.recencyWeight.isFinite, t.recencyWeight >= 0,
                      t.lastTimestampMilliseconds >= 0,
                      seenTargets.insert(t.word).inserted else {
                    return false
                }
            }
        }
        for entry in registerContexts {
            guard (1...3).contains(entry.tokens.count),
                  entry.tokens.allSatisfy(PersonalPhraseExpert.isValidStoredToken),
                  !entry.transitions.isEmpty,
                  entry.transitions.count <= PersonalPhraseExpert.maximumTargetsPerContext,
                  entry.total >= 0 else {
                return false
            }
            var seenTargets = Set<String>()
            for t in entry.transitions {
                guard PersonalPhraseExpert.isValidStoredToken(t.word),
                      PersonalPhraseExpert.isValidStoredToken(t.surface),
                      t.count > 0,
                      t.recencyWeight.isFinite, t.recencyWeight >= 0,
                      t.lastTimestampMilliseconds >= 0,
                      seenTargets.insert(t.word).inserted else {
                    return false
                }
            }
        }
        var seenPhrase = Set<[String]>()
        for entry in phraseContexts {
            guard (2...3).contains(entry.tokens.count),
                  entry.tokens.allSatisfy(PersonalPhraseExpert.isValidStoredToken),
                  seenPhrase.insert(entry.tokens).inserted,
                  !entry.transitions.isEmpty,
                  entry.transitions.count <= PersonalPhraseExpert.maximumPhrasesPerContext else {
                return false
            }
            for t in entry.transitions {
                guard (2...3).contains(t.words.count),
                      t.words.count == t.surfaces.count,
                      t.words.allSatisfy(PersonalPhraseExpert.isValidStoredToken),
                      t.surfaces.allSatisfy(PersonalPhraseExpert.isValidStoredToken),
                      t.count > 0,
                      t.recencyWeight.isFinite, t.recencyWeight >= 0,
                      t.lastTimestampMilliseconds >= 0 else {
                    return false
                }
            }
        }
        for stream in streams {
            guard PersonalHistoryEvent.validIdentifier(stream.historyIdentifier),
                  PersonalHistoryEvent.validIdentifier(stream.consentIdentifier),
                  PersonalHistoryEvent.validIdentifier(stream.sessionIdentifier),
                  PersonalHistoryEvent.validBundleIdentifier(stream.appBundleIdentifier),
                  stream.context.count <= 5,
                  stream.context.allSatisfy(PersonalPhraseExpert.isValidStoredToken),
                  stream.pendingBuffer.count <= PersonalPhraseExpert.maximumPendingBufferCharacters,
                  stream.lastTimestampMilliseconds.map({ $0 >= 0 }) ?? true else {
                return false
            }
        }
        return true
    }
}

/// Pure-Swift, sub-millisecond chronological 2–4 gram personal phrase and
/// recency expert (`H11/H13`).
///
/// Safety guarantees:
/// - Ingests strictly user-authored `.typed` events (never `.acceptedSuggestion`).
/// - Runs `SecretRules.scrub(..., config: .forPersistence)` over coalesced stream
///   buffers before extracting tokens; redacted spans break context cleanly.
/// - Drops digits, URLs, emails, paths, symbol-bearing tokens, and high-entropy
///   secret-like tokens, breaking n-gram context across every unsafe boundary.
/// - Applies exact exponential recency decay (30-day half-life) so stale facts
///   decay below `minimumRecencySupport` and are excluded from serving and
///   evicted first under the bounded memory cap.
public struct PersonalPhraseExpert: Equatable, Sendable {
    public static let defaultHalfLifeDays: Double = 30.0
    public static let defaultMinimumRecencySupport: Double = 0.05
    public static let defaultSmoothingAlpha: Double = 2.0

    public static let maximum2GramGlobalContexts = 2_048
    public static let maximum3GramGlobalContexts = 8_192
    public static let maximum4GramGlobalContexts = 12_288
    public static let maximumGlobalContexts =
        maximum2GramGlobalContexts + maximum3GramGlobalContexts + maximum4GramGlobalContexts
    public static let maximumRegisterContexts = 4_096
    public static let maximumPhraseContexts = 4_096
    public static let maximumTargetsPerContext = 4
    public static let maximumPhrasesPerContext = 3
    public static let maximumActiveStreams = 64
    public static let maximumRecentEventIDs = 2_048
    public static let maximumTokenCharacters = 24
    public static let maximumPendingBufferCharacters = 512

    private static let dayMilliseconds: Double = 86_400_000.0
    private static let streamGapMilliseconds: Int64 = 30 * 60 * 1_000
    private static let ln2: Double = log(2.0)
    private static let undatedOccurrenceWeight: Double = 0.25

    private static let contractionFragments: Set<String> = [
        "t", "s", "d", "m", "ll", "re", "ve",
    ]
    private static let neverEndOn: Set<String> = [
        "a", "an", "the", "of", "on", "in", "to", "at", "by", "as", "if",
        "and", "or", "but", "with", "for", "from", "that", "than", "so",
        "my", "your", "our", "their", "his", "her", "its", "is", "are",
        "was", "be", "been", "will", "would", "can", "could", "should",
        "very", "more", "most", "quite", "really",
    ]
    private static let forbiddenSymbolScalars = CharacterSet(
        charactersIn: "@#/:$€£¥₹\\|<>{}[]=+_~*%⟨⟩"
    )
    private static let trimEdgeCharacters = CharacterSet(
        charactersIn: ".,!?;:\"'()[]{}—–-“”‘’"
    )
    private static let sentenceBoundaryCharacters: Set<Character> = [
        ".", "!", "?", ";", "\n", "\r",
    ]

    private struct ContextKey: Hashable, Sendable {
        let tokens: [String]
    }

    private struct RegisterContextKey: Hashable, Sendable {
        let register: ContinuationRegister
        let tokens: [String]
    }

    private struct TransitionValue: Equatable, Sendable {
        var count: Int
        var recencyWeight: Double
        var lastTimestampMilliseconds: Int64
        var surface: String

        mutating func observe(
            surface newSurface: String,
            timestampMilliseconds: Int64,
            halfLifeMilliseconds: Double
        ) {
            count = count < Int.max ? count + 1 : count
            if timestampMilliseconds > 0 {
                if lastTimestampMilliseconds == 0 {
                    recencyWeight += 1.0
                    lastTimestampMilliseconds = timestampMilliseconds
                    surface = newSurface
                } else if timestampMilliseconds >= lastTimestampMilliseconds {
                    let delta = Double(timestampMilliseconds - lastTimestampMilliseconds)
                    let decay = exp(-PersonalPhraseExpert.ln2 * delta / halfLifeMilliseconds)
                    recencyWeight = recencyWeight * decay + 1.0
                    lastTimestampMilliseconds = timestampMilliseconds
                    surface = newSurface
                } else {
                    let delta = Double(lastTimestampMilliseconds - timestampMilliseconds)
                    let decay = exp(-PersonalPhraseExpert.ln2 * delta / halfLifeMilliseconds)
                    recencyWeight += decay
                }
            } else {
                recencyWeight += PersonalPhraseExpert.undatedOccurrenceWeight
                if lastTimestampMilliseconds == 0 {
                    surface = newSurface
                }
            }
        }

        func decayedRecency(
            at referenceTimestampMilliseconds: Int64,
            halfLifeMilliseconds: Double
        ) -> Double {
            guard lastTimestampMilliseconds > 0,
                  referenceTimestampMilliseconds > lastTimestampMilliseconds else {
                return recencyWeight
            }
            let delta = Double(referenceTimestampMilliseconds - lastTimestampMilliseconds)
            return recencyWeight * exp(-PersonalPhraseExpert.ln2 * delta / halfLifeMilliseconds)
        }
    }

    private struct TargetBag: Equatable, Sendable {
        var entries: [String: TransitionValue] = [:]
        var total: Int = 0

        mutating func add(
            word: String,
            surface: String,
            timestampMilliseconds: Int64,
            halfLifeMilliseconds: Double,
            referenceTimestampMilliseconds: Int64,
            maxTargets: Int
        ) {
            total = total < Int.max ? total + 1 : total
            if var existing = entries[word] {
                existing.observe(
                    surface: surface,
                    timestampMilliseconds: timestampMilliseconds,
                    halfLifeMilliseconds: halfLifeMilliseconds
                )
                entries[word] = existing
            } else {
                let initialWeight = timestampMilliseconds > 0
                    ? 1.0
                    : PersonalPhraseExpert.undatedOccurrenceWeight
                entries[word] = TransitionValue(
                    count: 1,
                    recencyWeight: initialWeight,
                    lastTimestampMilliseconds: max(0, timestampMilliseconds),
                    surface: surface
                )
                if entries.count > maxTargets {
                    evictWeakest(
                        at: referenceTimestampMilliseconds,
                        halfLifeMilliseconds: halfLifeMilliseconds
                    )
                }
            }
        }

        func maxDecayedRecency(
            at referenceTimestampMilliseconds: Int64,
            halfLifeMilliseconds: Double
        ) -> Double {
            entries.values.reduce(0.0) { best, value in
                max(
                    best,
                    value.decayedRecency(
                        at: referenceTimestampMilliseconds,
                        halfLifeMilliseconds: halfLifeMilliseconds
                    )
                )
            }
        }

        func maxTimestampMilliseconds() -> Int64 {
            entries.values.reduce(0) { max($0, $1.lastTimestampMilliseconds) }
        }

        private mutating func evictWeakest(
            at referenceTimestampMilliseconds: Int64,
            halfLifeMilliseconds: Double
        ) {
            guard let victim = entries.min(by: { lhs, rhs in
                let lr = lhs.value.decayedRecency(
                    at: referenceTimestampMilliseconds,
                    halfLifeMilliseconds: halfLifeMilliseconds
                )
                let rr = rhs.value.decayedRecency(
                    at: referenceTimestampMilliseconds,
                    halfLifeMilliseconds: halfLifeMilliseconds
                )
                if abs(lr - rr) > 1e-9 { return lr < rr }
                if lhs.value.count != rhs.value.count { return lhs.value.count < rhs.value.count }
                return lhs.key > rhs.key
            })?.key else { return }
            entries.removeValue(forKey: victim)
        }
    }

    private struct PhraseValue: Equatable, Sendable {
        var count: Int
        var recencyWeight: Double
        var lastTimestampMilliseconds: Int64
        var surfaces: [String]

        mutating func observe(
            surfaces newSurfaces: [String],
            timestampMilliseconds: Int64,
            halfLifeMilliseconds: Double
        ) {
            count = count < Int.max ? count + 1 : count
            if timestampMilliseconds > 0 {
                if lastTimestampMilliseconds == 0 {
                    recencyWeight += 1.0
                    lastTimestampMilliseconds = timestampMilliseconds
                    surfaces = newSurfaces
                } else if timestampMilliseconds >= lastTimestampMilliseconds {
                    let delta = Double(timestampMilliseconds - lastTimestampMilliseconds)
                    let decay = exp(-PersonalPhraseExpert.ln2 * delta / halfLifeMilliseconds)
                    recencyWeight = recencyWeight * decay + 1.0
                    lastTimestampMilliseconds = timestampMilliseconds
                    surfaces = newSurfaces
                } else {
                    let delta = Double(lastTimestampMilliseconds - timestampMilliseconds)
                    let decay = exp(-PersonalPhraseExpert.ln2 * delta / halfLifeMilliseconds)
                    recencyWeight += decay
                }
            } else {
                recencyWeight += PersonalPhraseExpert.undatedOccurrenceWeight
                if lastTimestampMilliseconds == 0 {
                    surfaces = newSurfaces
                }
            }
        }

        func decayedRecency(
            at referenceTimestampMilliseconds: Int64,
            halfLifeMilliseconds: Double
        ) -> Double {
            guard lastTimestampMilliseconds > 0,
                  referenceTimestampMilliseconds > lastTimestampMilliseconds else {
                return recencyWeight
            }
            let delta = Double(referenceTimestampMilliseconds - lastTimestampMilliseconds)
            return recencyWeight * exp(-PersonalPhraseExpert.ln2 * delta / halfLifeMilliseconds)
        }
    }

    private struct PhraseBag: Equatable, Sendable {
        var entries: [[String]: PhraseValue] = [:]

        mutating func add(
            words: [String],
            surfaces: [String],
            timestampMilliseconds: Int64,
            halfLifeMilliseconds: Double,
            referenceTimestampMilliseconds: Int64,
            maxPhrases: Int
        ) {
            if var existing = entries[words] {
                existing.observe(
                    surfaces: surfaces,
                    timestampMilliseconds: timestampMilliseconds,
                    halfLifeMilliseconds: halfLifeMilliseconds
                )
                entries[words] = existing
            } else {
                let initialWeight = timestampMilliseconds > 0
                    ? 1.0
                    : PersonalPhraseExpert.undatedOccurrenceWeight
                entries[words] = PhraseValue(
                    count: 1,
                    recencyWeight: initialWeight,
                    lastTimestampMilliseconds: max(0, timestampMilliseconds),
                    surfaces: surfaces
                )
                if entries.count > maxPhrases {
                    if let victim = entries.min(by: { lhs, rhs in
                        let lr = lhs.value.decayedRecency(
                            at: referenceTimestampMilliseconds,
                            halfLifeMilliseconds: halfLifeMilliseconds
                        )
                        let rr = rhs.value.decayedRecency(
                            at: referenceTimestampMilliseconds,
                            halfLifeMilliseconds: halfLifeMilliseconds
                        )
                        if abs(lr - rr) > 1e-9 { return lr < rr }
                        return lhs.value.count < rhs.value.count
                    })?.key {
                        entries.removeValue(forKey: victim)
                    }
                }
            }
        }

        func maxDecayedRecency(
            at referenceTimestampMilliseconds: Int64,
            halfLifeMilliseconds: Double
        ) -> Double {
            entries.values.reduce(0.0) { best, value in
                max(
                    best,
                    value.decayedRecency(
                        at: referenceTimestampMilliseconds,
                        halfLifeMilliseconds: halfLifeMilliseconds
                    )
                )
            }
        }
    }

    private struct StreamKey: Hashable, Sendable {
        let history: String
        let consent: String
        let session: String
        let app: String
    }

    private struct EventIdentity: Hashable, Sendable {
        let stream: StreamKey
        let event: String
    }

    private struct StreamState: Equatable, Sendable {
        var context: [String] = []
        var contextSurfaces: [String] = []
        var pendingBuffer: String = ""
        var lastTimestampMilliseconds: Int64?
    }

    public let halfLifeDays: Double
    public let minimumRecencySupport: Double
    private let halfLifeMilliseconds: Double

    private var global2Contexts: [ContextKey: TargetBag] = [:]
    private var global3Contexts: [ContextKey: TargetBag] = [:]
    private var global4Contexts: [ContextKey: TargetBag] = [:]
    private var registerContexts: [RegisterContextKey: TargetBag] = [:]
    private var phraseContexts: [ContextKey: PhraseBag] = [:]
    private var streams: [StreamKey: StreamState] = [:]
    private var streamOrder: [StreamKey] = []
    private var recentEventIDs: [EventIdentity] = []
    private var recentEventIDSet: Set<EventIdentity> = []
    private var nextEventEvictionIndex = 0
    public private(set) var latestTimestampMilliseconds: Int64 = 0

    public init(
        halfLifeDays: Double = PersonalPhraseExpert.defaultHalfLifeDays,
        minimumRecencySupport: Double = PersonalPhraseExpert.defaultMinimumRecencySupport
    ) {
        let safeHalfLife = max(1.0, halfLifeDays.isFinite ? halfLifeDays : Self.defaultHalfLifeDays)
        self.halfLifeDays = safeHalfLife
        self.minimumRecencySupport = max(0.0, minimumRecencySupport.isFinite ? minimumRecencySupport : 0.0)
        self.halfLifeMilliseconds = safeHalfLife * Self.dayMilliseconds
    }

    public var isEmpty: Bool {
        global2Contexts.isEmpty && global3Contexts.isEmpty && global4Contexts.isEmpty && registerContexts.isEmpty
    }

    public var globalContextCount: Int {
        global2Contexts.count + global3Contexts.count + global4Contexts.count
    }
    public var registerContextCount: Int { registerContexts.count }
    public var phraseContextCount: Int { phraseContexts.count }

    public mutating func reset() {
        self = Self(halfLifeDays: halfLifeDays, minimumRecencySupport: minimumRecencySupport)
    }

    // MARK: - Ingestion

    /// Consumes a batch of Personal History events in arrival order.
    /// Only `.typed` events are learned; `.acceptedSuggestion` breaks the active
    /// stream context so accepted model output cannot create feedback loops.
    public mutating func consume(_ events: [PersonalHistoryEvent]) {
        for event in events {
            let key = StreamKey(
                history: event.historyIdentifier,
                consent: event.consentIdentifier,
                session: event.sessionIdentifier,
                app: event.appBundleIdentifier
            )
            guard remember(event, in: key) else { continue }
            var state = takeStream(for: key)
            if let last = state.lastTimestampMilliseconds,
               event.timestampMilliseconds < last
                || event.timestampMilliseconds - last > Self.streamGapMilliseconds {
                state = StreamState()
            }
            state.lastTimestampMilliseconds = event.timestampMilliseconds
            if event.timestampMilliseconds > latestTimestampMilliseconds {
                latestTimestampMilliseconds = event.timestampMilliseconds
            }

            if event.source == .acceptedSuggestion {
                state.context.removeAll(keepingCapacity: false)
                state.contextSurfaces.removeAll(keepingCapacity: false)
                state.pendingBuffer.removeAll(keepingCapacity: false)
            } else {
                let register = ContinuationRegister.from(bundleIdentifier: event.appBundleIdentifier)
                appendTypedText(
                    event.text,
                    register: register,
                    timestampMilliseconds: event.timestampMilliseconds,
                    state: &state
                )
            }
            streams[key] = state
        }
    }

    /// Directly ingests a complete document or memory text (e.g., for offline
    /// Lab evaluation or unit tests). Runs the exact same `SecretRules` scrub
    /// and token safety pipeline as live streaming ingestion.
    public mutating func ingestDocument(
        _ text: String,
        register: ContinuationRegister = .prose,
        timestampMilliseconds: Int64? = nil
    ) {
        let ts = max(0, timestampMilliseconds ?? 0)
        if ts > latestTimestampMilliseconds {
            latestTimestampMilliseconds = ts
        }
        var state = StreamState()
        processScrubbedSegment(
            text,
            register: register,
            timestampMilliseconds: ts,
            state: &state
        )
    }

    private mutating func appendTypedText(
        _ text: String,
        register: ContinuationRegister,
        timestampMilliseconds: Int64,
        state: inout StreamState
    ) {
        state.pendingBuffer += text
        if state.pendingBuffer.count > Self.maximumPendingBufferCharacters {
            if let splitIdx = state.pendingBuffer.lastIndex(where: { $0.isWhitespace }) {
                let completed = String(state.pendingBuffer[...splitIdx])
                let remainder = String(state.pendingBuffer[state.pendingBuffer.index(after: splitIdx)...])
                state.pendingBuffer = String(remainder.suffix(Self.maximumPendingBufferCharacters / 2))
                processScrubbedSegment(
                    completed,
                    register: register,
                    timestampMilliseconds: timestampMilliseconds,
                    state: &state
                )
            } else {
                state.pendingBuffer.removeAll(keepingCapacity: false)
                state.context.removeAll(keepingCapacity: false)
                state.contextSurfaces.removeAll(keepingCapacity: false)
            }
            return
        }

        guard let splitIdx = state.pendingBuffer.lastIndex(where: { $0.isWhitespace }) else {
            return
        }
        let completed = String(state.pendingBuffer[...splitIdx])
        let remainder = String(state.pendingBuffer[state.pendingBuffer.index(after: splitIdx)...])
        state.pendingBuffer = remainder
        processScrubbedSegment(
            completed,
            register: register,
            timestampMilliseconds: timestampMilliseconds,
            state: &state
        )
    }

    private mutating func processScrubbedSegment(
        _ rawText: String,
        register: ContinuationRegister,
        timestampMilliseconds: Int64,
        state: inout StreamState
    ) {
        guard !rawText.isEmpty else { return }
        let scrubbed = SecretRules.scrub(rawText, config: .forPersistence).clean
        let parts = Self.extractSafeTokens(fromScrubbed: scrubbed)
        for item in parts {
            switch item {
            case .contextBreak:
                state.context.removeAll(keepingCapacity: true)
                state.contextSurfaces.removeAll(keepingCapacity: true)
            case let .word(folded, surface, endsSentence):
                recordToken(
                    folded: folded,
                    surface: surface,
                    register: register,
                    timestampMilliseconds: timestampMilliseconds,
                    state: &state
                )
                if endsSentence {
                    state.context.removeAll(keepingCapacity: true)
                    state.contextSurfaces.removeAll(keepingCapacity: true)
                }
            }
        }
    }

    private mutating func recordToken(
        folded: String,
        surface: String,
        register: ContinuationRegister,
        timestampMilliseconds: Int64,
        state: inout StreamState
    ) {
        let history = state.context
        let historyCount = history.count
        let refTs = max(latestTimestampMilliseconds, timestampMilliseconds)

        if !Self.contractionFragments.contains(folded), historyCount >= 1 {
            let k1 = [history[historyCount - 1]]
            addNextWord(
                context: k1,
                word: folded,
                surface: surface,
                register: register,
                timestampMilliseconds: timestampMilliseconds,
                referenceTimestampMilliseconds: refTs
            )
            if historyCount >= 2 {
                let k2 = [history[historyCount - 2], history[historyCount - 1]]
                addNextWord(
                    context: k2,
                    word: folded,
                    surface: surface,
                    register: register,
                    timestampMilliseconds: timestampMilliseconds,
                    referenceTimestampMilliseconds: refTs
                )
            }
            if historyCount >= 3 {
                let k3 = [history[historyCount - 3], history[historyCount - 2], history[historyCount - 1]]
                addNextWord(
                    context: k3,
                    word: folded,
                    surface: surface,
                    register: register,
                    timestampMilliseconds: timestampMilliseconds,
                    referenceTimestampMilliseconds: refTs
                )
            }

            let surfHistory = state.contextSurfaces
            if historyCount >= 3, !Self.contractionFragments.contains(history[historyCount - 1]) {
                let ctx2 = [history[historyCount - 3], history[historyCount - 2]]
                addPhrase(
                    context: ctx2,
                    words: [history[historyCount - 1], folded],
                    surfaces: [surfHistory[historyCount - 1], surface],
                    timestampMilliseconds: timestampMilliseconds,
                    referenceTimestampMilliseconds: refTs
                )
            }
            if historyCount >= 4, !Self.contractionFragments.contains(history[historyCount - 1]) {
                let ctx3 = [history[historyCount - 4], history[historyCount - 3], history[historyCount - 2]]
                addPhrase(
                    context: ctx3,
                    words: [history[historyCount - 1], folded],
                    surfaces: [surfHistory[historyCount - 1], surface],
                    timestampMilliseconds: timestampMilliseconds,
                    referenceTimestampMilliseconds: refTs
                )
            }
            if historyCount >= 4, !Self.contractionFragments.contains(history[historyCount - 2]) {
                let ctx2 = [history[historyCount - 4], history[historyCount - 3]]
                addPhrase(
                    context: ctx2,
                    words: [history[historyCount - 2], history[historyCount - 1], folded],
                    surfaces: [surfHistory[historyCount - 2], surfHistory[historyCount - 1], surface],
                    timestampMilliseconds: timestampMilliseconds,
                    referenceTimestampMilliseconds: refTs
                )
            }
            if historyCount >= 5, !Self.contractionFragments.contains(history[historyCount - 2]) {
                let ctx3 = [history[historyCount - 5], history[historyCount - 4], history[historyCount - 3]]
                addPhrase(
                    context: ctx3,
                    words: [history[historyCount - 2], history[historyCount - 1], folded],
                    surfaces: [surfHistory[historyCount - 2], surfHistory[historyCount - 1], surface],
                    timestampMilliseconds: timestampMilliseconds,
                    referenceTimestampMilliseconds: refTs
                )
            }
        }

        state.context.append(folded)
        state.contextSurfaces.append(surface)
        if state.context.count > 5 {
            state.context.removeFirst(state.context.count - 5)
            state.contextSurfaces.removeFirst(state.contextSurfaces.count - 5)
        }
    }

    private mutating func addNextWord(
        context: [String],
        word: String,
        surface: String,
        register: ContinuationRegister,
        timestampMilliseconds: Int64,
        referenceTimestampMilliseconds: Int64
    ) {
        let gKey = ContextKey(tokens: context)
        switch context.count {
        case 1:
            global2Contexts[gKey, default: TargetBag()].add(
                word: word,
                surface: surface,
                timestampMilliseconds: timestampMilliseconds,
                halfLifeMilliseconds: halfLifeMilliseconds,
                referenceTimestampMilliseconds: referenceTimestampMilliseconds,
                maxTargets: Self.maximumTargetsPerContext
            )
            if global2Contexts.count > Self.maximum2GramGlobalContexts {
                pruneContextMap(
                    &global2Contexts,
                    maxCount: Self.maximum2GramGlobalContexts,
                    at: referenceTimestampMilliseconds
                )
            }
        case 2:
            global3Contexts[gKey, default: TargetBag()].add(
                word: word,
                surface: surface,
                timestampMilliseconds: timestampMilliseconds,
                halfLifeMilliseconds: halfLifeMilliseconds,
                referenceTimestampMilliseconds: referenceTimestampMilliseconds,
                maxTargets: Self.maximumTargetsPerContext
            )
            if global3Contexts.count > Self.maximum3GramGlobalContexts {
                pruneContextMap(
                    &global3Contexts,
                    maxCount: Self.maximum3GramGlobalContexts,
                    at: referenceTimestampMilliseconds
                )
            }
        default:
            global4Contexts[gKey, default: TargetBag()].add(
                word: word,
                surface: surface,
                timestampMilliseconds: timestampMilliseconds,
                halfLifeMilliseconds: halfLifeMilliseconds,
                referenceTimestampMilliseconds: referenceTimestampMilliseconds,
                maxTargets: Self.maximumTargetsPerContext
            )
            if global4Contexts.count > Self.maximum4GramGlobalContexts {
                pruneContextMap(
                    &global4Contexts,
                    maxCount: Self.maximum4GramGlobalContexts,
                    at: referenceTimestampMilliseconds
                )
            }
        }

        let rKey = RegisterContextKey(register: register, tokens: context)
        registerContexts[rKey, default: TargetBag()].add(
            word: word,
            surface: surface,
            timestampMilliseconds: timestampMilliseconds,
            halfLifeMilliseconds: halfLifeMilliseconds,
            referenceTimestampMilliseconds: referenceTimestampMilliseconds,
            maxTargets: Self.maximumTargetsPerContext
        )
        if registerContexts.count > Self.maximumRegisterContexts {
            pruneRegisterContexts(at: referenceTimestampMilliseconds)
        }
    }

    private mutating func addPhrase(
        context: [String],
        words: [String],
        surfaces: [String],
        timestampMilliseconds: Int64,
        referenceTimestampMilliseconds: Int64
    ) {
        let key = ContextKey(tokens: context)
        phraseContexts[key, default: PhraseBag()].add(
            words: words,
            surfaces: surfaces,
            timestampMilliseconds: timestampMilliseconds,
            halfLifeMilliseconds: halfLifeMilliseconds,
            referenceTimestampMilliseconds: referenceTimestampMilliseconds,
            maxPhrases: Self.maximumPhrasesPerContext
        )
        if phraseContexts.count > Self.maximumPhraseContexts {
            prunePhraseContexts(at: referenceTimestampMilliseconds)
        }
    }

    // MARK: - Stale-First Bounded Eviction

    private func pruneContextMap(
        _ map: inout [ContextKey: TargetBag],
        maxCount: Int,
        at referenceTimestampMilliseconds: Int64
    ) {
        let targetCount = Int(Double(maxCount) * 0.80)
        let removeCount = map.count - targetCount
        guard removeCount > 0 else { return }
        let ranked = map.map { entry -> (key: ContextKey, score: Double, total: Int, latestTs: Int64) in
            let rec = entry.value.maxDecayedRecency(
                at: referenceTimestampMilliseconds,
                halfLifeMilliseconds: halfLifeMilliseconds
            )
            // Weight recency strongly so stale facts evict first, while
            // preferring repeated phrases over one-off noise at equal age.
            let score = rec * (1.0 + 0.25 * min(Double(entry.value.total), 8.0))
            return (
                key: entry.key,
                score: score,
                total: entry.value.total,
                latestTs: entry.value.maxTimestampMilliseconds()
            )
        }.sorted { lhs, rhs in
            if abs(lhs.score - rhs.score) > 1e-9 { return lhs.score < rhs.score }
            if lhs.latestTs != rhs.latestTs { return lhs.latestTs < rhs.latestTs }
            if lhs.total != rhs.total { return lhs.total < rhs.total }
            return Self.tokensPrecede(lhs.key.tokens, rhs.key.tokens)
        }
        for item in ranked.prefix(removeCount) {
            map.removeValue(forKey: item.key)
        }
    }

    private mutating func pruneRegisterContexts(at referenceTimestampMilliseconds: Int64) {
        let targetCount = Int(Double(Self.maximumRegisterContexts) * 0.80)
        let removeCount = registerContexts.count - targetCount
        guard removeCount > 0 else { return }
        let ranked = registerContexts.map { entry -> (key: RegisterContextKey, score: Double, total: Int, latestTs: Int64) in
            let rec = entry.value.maxDecayedRecency(
                at: referenceTimestampMilliseconds,
                halfLifeMilliseconds: halfLifeMilliseconds
            )
            // Protect higher-order (3/4-gram) register phrases over generic 2-grams.
            let orderBoost = entry.key.tokens.count >= 2 ? 1.5 : 1.0
            let score = rec * orderBoost * (1.0 + 0.25 * min(Double(entry.value.total), 8.0))
            return (
                key: entry.key,
                score: score,
                total: entry.value.total,
                latestTs: entry.value.maxTimestampMilliseconds()
            )
        }.sorted { lhs, rhs in
            if abs(lhs.score - rhs.score) > 1e-9 { return lhs.score < rhs.score }
            if lhs.latestTs != rhs.latestTs { return lhs.latestTs < rhs.latestTs }
            if lhs.total != rhs.total { return lhs.total < rhs.total }
            if lhs.key.register.rawValue != rhs.key.register.rawValue {
                return lhs.key.register.rawValue < rhs.key.register.rawValue
            }
            return Self.tokensPrecede(lhs.key.tokens, rhs.key.tokens)
        }
        for item in ranked.prefix(removeCount) {
            registerContexts.removeValue(forKey: item.key)
        }
    }

    private mutating func prunePhraseContexts(at referenceTimestampMilliseconds: Int64) {
        let targetCount = Int(Double(Self.maximumPhraseContexts) * 0.80)
        let removeCount = phraseContexts.count - targetCount
        guard removeCount > 0 else { return }
        let ranked = phraseContexts.map {
            (
                key: $0.key,
                score: $0.value.maxDecayedRecency(
                    at: referenceTimestampMilliseconds,
                    halfLifeMilliseconds: halfLifeMilliseconds
                )
            )
        }.sorted { $0.score < $1.score }
        for item in ranked.prefix(removeCount) {
            phraseContexts.removeValue(forKey: item.key)
        }
    }

    private func globalBag(for context: [String]) -> TargetBag? {
        switch context.count {
        case 1: return global2Contexts[ContextKey(tokens: context)]
        case 2: return global3Contexts[ContextKey(tokens: context)]
        case 3: return global4Contexts[ContextKey(tokens: context)]
        default: return nil
        }
    }

    // MARK: - Sub-Millisecond Lookup

    /// Performs a `<1 ms` chronological 2–4 gram personal phrase lookup for
    /// `textBeforeCursor`. Returns `nil` when empty, or when all matching
    /// transitions have decayed below `minimumRecencySupport`.
    public func query(
        textBeforeCursor: String,
        register: ContinuationRegister = .prose,
        referenceTimestampMilliseconds: Int64? = nil,
        alpha: Double = PersonalPhraseExpert.defaultSmoothingAlpha
    ) -> PersonalPhraseMatch? {
        guard !isEmpty else { return nil }
        let tailTokens = Self.queryTailTokens(from: textBeforeCursor)
        guard !tailTokens.isEmpty else { return nil }

        let refTs = max(latestTimestampMilliseconds, referenceTimestampMilliseconds ?? 0)

        var matchedOrder = 0
        var matchedBag: TargetBag?
        var registerMatched = false
        var matchedContext: [String] = []

        func activeTotal(_ bag: TargetBag) -> Int {
            var total = 0
            for value in bag.entries.values {
                if !isStale(value, at: refTs) {
                    total += value.count
                }
            }
            return total
        }

        if tailTokens.count >= 3 {
            let k3 = Array(tailTokens.suffix(3))
            if let rBag = registerContexts[RegisterContextKey(register: register, tokens: k3)],
               activeTotal(rBag) >= 2 {
                matchedOrder = 4
                matchedBag = rBag
                registerMatched = true
                matchedContext = k3
            } else if let gBag = global4Contexts[ContextKey(tokens: k3)],
                      activeTotal(gBag) >= 1 {
                matchedOrder = 4
                matchedBag = gBag
                registerMatched = false
                matchedContext = k3
            }
        }

        if matchedBag == nil, tailTokens.count >= 2 {
            let k2 = Array(tailTokens.suffix(2))
            if let rBag = registerContexts[RegisterContextKey(register: register, tokens: k2)],
               activeTotal(rBag) >= 2 {
                matchedOrder = 3
                matchedBag = rBag
                registerMatched = true
                matchedContext = k2
            } else if let gBag = global3Contexts[ContextKey(tokens: k2)],
                      activeTotal(gBag) >= 1 {
                matchedOrder = 3
                matchedBag = gBag
                registerMatched = false
                matchedContext = k2
            }
        }

        if matchedBag == nil, let lastToken = tailTokens.last {
            let k1 = [lastToken]
            if let rBag = registerContexts[RegisterContextKey(register: register, tokens: k1)],
               activeTotal(rBag) >= 3 {
                matchedOrder = 2
                matchedBag = rBag
                registerMatched = true
                matchedContext = k1
            } else if let gBag = global2Contexts[ContextKey(tokens: k1)],
                      activeTotal(gBag) >= 3 {
                matchedOrder = 2
                matchedBag = gBag
                registerMatched = false
                matchedContext = k1
            }
        }

        guard let bag = matchedBag else { return nil }

        var ranked: [(word: String, value: TransitionValue, recency: Double)] = []
        ranked.reserveCapacity(bag.entries.count)
        var nonStaleTotal = 0
        for (word, value) in bag.entries {
            let rec = value.decayedRecency(at: refTs, halfLifeMilliseconds: halfLifeMilliseconds)
            if value.lastTimestampMilliseconds > 0 && rec < minimumRecencySupport {
                continue
            }
            nonStaleTotal += value.count
            ranked.append((word, value, rec))
        }
        guard !ranked.isEmpty else { return nil }

        ranked.sort { lhs, rhs in
            if abs(lhs.recency - rhs.recency) > 1e-9 { return lhs.recency > rhs.recency }
            if lhs.value.count != rhs.value.count { return lhs.value.count > rhs.value.count }
            return lhs.word < rhs.word
        }

        let top = ranked[0]
        let top3 = ranked.prefix(3).map(\.word)
        let denom = Double(max(nonStaleTotal, bag.total)) + max(0.0, alpha)
        let confidence = denom > 0 ? Double(top.value.count) / denom : 0.0

        let globalRecency = globalBag(for: matchedContext)?
            .entries[top.word]?
            .decayedRecency(at: refTs, halfLifeMilliseconds: halfLifeMilliseconds)
            ?? top.recency

        var phraseSurfaces = [top.value.surface]
        var phraseFolded = [top.word]

        if tailTokens.count >= 3,
           let pBag = phraseContexts[ContextKey(tokens: Array(tailTokens.suffix(3)))] {
            if let ext = bestPhraseExtension(
                in: pBag,
                startingWith: top.word,
                preferredLength: 3,
                minSupport: 2,
                minShareOfW1: 0.50,
                w1Support: top.value.count,
                at: refTs
            ) {
                phraseFolded = ext.words
                phraseSurfaces = ext.surfaces
            } else if let ext = bestPhraseExtension(
                in: pBag,
                startingWith: top.word,
                preferredLength: 2,
                minSupport: 2,
                minShareOfW1: 0.50,
                w1Support: top.value.count,
                at: refTs
            ) {
                phraseFolded = ext.words
                phraseSurfaces = ext.surfaces
            }
        }

        if phraseSurfaces.count == 1,
           tailTokens.count >= 2,
           let pBag = phraseContexts[ContextKey(tokens: Array(tailTokens.suffix(2)))] {
            if let ext = bestPhraseExtension(
                in: pBag,
                startingWith: top.word,
                preferredLength: 2,
                minSupport: 3,
                minShareOfW1: 0.45,
                w1Support: top.value.count,
                at: refTs
            ) {
                phraseFolded = ext.words
                phraseSurfaces = ext.surfaces
            }
        }

        if phraseSurfaces.count == 1, let lastToken = tailTokens.last,
           let nextBag = global3Contexts[ContextKey(tokens: [lastToken, top.word])] {
            var bestNext: (word: String, value: TransitionValue, rec: Double)?
            var nextActiveTotal = 0
            for (word, val) in nextBag.entries {
                let rec = val.decayedRecency(at: refTs, halfLifeMilliseconds: halfLifeMilliseconds)
                if val.lastTimestampMilliseconds > 0 && rec < minimumRecencySupport { continue }
                nextActiveTotal += val.count
                if bestNext == nil || rec > bestNext!.rec {
                    bestNext = (word, val, rec)
                }
            }
            if let next = bestNext,
               next.value.count >= 4,
               Double(next.value.count) / (Double(nextActiveTotal) + 2.0) >= 0.40 {
                phraseFolded.append(next.word)
                phraseSurfaces.append(next.value.surface)
            }
        }

        while phraseFolded.count > 1,
              let lastWord = phraseFolded.last,
              Self.neverEndOn.contains(lastWord) {
            phraseFolded.removeLast()
            phraseSurfaces.removeLast()
        }

        let phrase = phraseSurfaces.joined(separator: " ")
        return PersonalPhraseMatch(
            order: matchedOrder,
            support: top.value.count,
            recencySupport: globalRecency,
            contextTotal: nonStaleTotal,
            confidence: confidence,
            firstWord: top.word,
            firstWordSurface: top.value.surface,
            topFirstWords: top3,
            phrase: phrase,
            wordCount: phraseSurfaces.count,
            registerMatched: registerMatched
        )
    }

    private func isStale(_ value: TransitionValue, at referenceTimestampMilliseconds: Int64) -> Bool {
        guard value.lastTimestampMilliseconds > 0 else { return false }
        let rec = value.decayedRecency(at: referenceTimestampMilliseconds, halfLifeMilliseconds: halfLifeMilliseconds)
        return rec < minimumRecencySupport
    }

    private func bestPhraseExtension(
        in bag: PhraseBag,
        startingWith firstWord: String,
        preferredLength: Int,
        minSupport: Int,
        minShareOfW1: Double,
        w1Support: Int,
        at referenceTimestampMilliseconds: Int64
    ) -> (words: [String], surfaces: [String])? {
        var best: (words: [String], surfaces: [String], rec: Double, count: Int)?
        for (words, val) in bag.entries {
            guard words.count == preferredLength,
                  words.first == firstWord,
                  val.count >= minSupport,
                  Double(val.count) / Double(max(1, w1Support)) >= minShareOfW1 else {
                continue
            }
            let rec = val.decayedRecency(
                at: referenceTimestampMilliseconds,
                halfLifeMilliseconds: halfLifeMilliseconds
            )
            if val.lastTimestampMilliseconds > 0 && rec < minimumRecencySupport {
                continue
            }
            if best == nil || rec > best!.rec || (abs(rec - best!.rec) <= 1e-9 && val.count > best!.count) {
                best = (words, val.surfaces, rec, val.count)
            }
        }
        return best.map { ($0.words, $0.surfaces) }
    }

    // MARK: - Snapshot & Restore

    public var snapshot: PersonalPhraseExpertSnapshot {
        func encodeMap(_ map: [ContextKey: TargetBag]) -> [PersonalPhraseExpertSnapshot.ContextEntry] {
            map.keys
                .sorted { Self.tokensPrecede($0.tokens, $1.tokens) }
                .map { key -> PersonalPhraseExpertSnapshot.ContextEntry in
                    let bag = map[key]!
                    return PersonalPhraseExpertSnapshot.ContextEntry(
                        tokens: key.tokens,
                        transitions: bag.entries.keys.sorted().map { word in
                            let val = bag.entries[word]!
                            return PersonalPhraseExpertSnapshot.Transition(
                                word: word,
                                surface: val.surface,
                                count: val.count,
                                recencyWeight: val.recencyWeight,
                                lastTimestampMilliseconds: val.lastTimestampMilliseconds
                            )
                        },
                        total: bag.total
                    )
                }
        }
        let sortedGlobals = encodeMap(global2Contexts) + encodeMap(global3Contexts) + encodeMap(global4Contexts)
        let sortedRegisters = registerContexts.keys
            .sorted { lhs, rhs in
                if lhs.register.rawValue != rhs.register.rawValue {
                    return lhs.register.rawValue < rhs.register.rawValue
                }
                return Self.tokensPrecede(lhs.tokens, rhs.tokens)
            }
            .map { key -> PersonalPhraseExpertSnapshot.RegisterContextEntry in
                let bag = registerContexts[key]!
                return PersonalPhraseExpertSnapshot.RegisterContextEntry(
                    register: key.register,
                    tokens: key.tokens,
                    transitions: bag.entries.keys.sorted().map { word in
                        let val = bag.entries[word]!
                        return PersonalPhraseExpertSnapshot.Transition(
                            word: word,
                            surface: val.surface,
                            count: val.count,
                            recencyWeight: val.recencyWeight,
                            lastTimestampMilliseconds: val.lastTimestampMilliseconds
                        )
                    },
                    total: bag.total
                )
            }
        let sortedPhrases = phraseContexts.keys
            .sorted { Self.tokensPrecede($0.tokens, $1.tokens) }
            .map { key -> PersonalPhraseExpertSnapshot.PhraseContextEntry in
                let bag = phraseContexts[key]!
                return PersonalPhraseExpertSnapshot.PhraseContextEntry(
                    tokens: key.tokens,
                    transitions: bag.entries.keys
                        .sorted { Self.tokensPrecede($0, $1) }
                        .map { words in
                            let val = bag.entries[words]!
                            return PersonalPhraseExpertSnapshot.PhraseTransition(
                                words: words,
                                surfaces: val.surfaces,
                                count: val.count,
                                recencyWeight: val.recencyWeight,
                                lastTimestampMilliseconds: val.lastTimestampMilliseconds
                            )
                        }
                )
            }
        let streamSnapshots = streamOrder.compactMap { key -> PersonalPhraseExpertSnapshot.StreamSnapshot? in
            guard let state = streams[key] else { return nil }
            return PersonalPhraseExpertSnapshot.StreamSnapshot(
                historyIdentifier: key.history,
                consentIdentifier: key.consent,
                sessionIdentifier: key.session,
                appBundleIdentifier: key.app,
                context: state.context,
                pendingBuffer: state.pendingBuffer,
                lastTimestampMilliseconds: state.lastTimestampMilliseconds
            )
        }
        let recentSnapshots = recentEventsOldestFirst.map {
            PersonalPhraseExpertSnapshot.RecentEvent(
                historyIdentifier: $0.stream.history,
                consentIdentifier: $0.stream.consent,
                sessionIdentifier: $0.stream.session,
                appBundleIdentifier: $0.stream.app,
                eventID: $0.event
            )
        }
        return PersonalPhraseExpertSnapshot(
            v: PersonalPhraseExpertSnapshot.version,
            recipeID: PersonalPhraseExpertSnapshot.recipeID,
            latestTimestampMilliseconds: latestTimestampMilliseconds,
            globalContexts: sortedGlobals,
            registerContexts: sortedRegisters,
            phraseContexts: sortedPhrases,
            streams: streamSnapshots,
            recentEvents: recentSnapshots
        )
    }

    @discardableResult
    public mutating func restore(_ snapshot: PersonalPhraseExpertSnapshot) -> Bool {
        guard snapshot.isCompatibleWithCurrentRecipe, snapshot.isStructurallyValid else {
            return false
        }
        var nextGlobal2: [ContextKey: TargetBag] = [:]
        var nextGlobal3: [ContextKey: TargetBag] = [:]
        var nextGlobal4: [ContextKey: TargetBag] = [:]
        for entry in snapshot.globalContexts {
            var bag = TargetBag()
            bag.total = entry.total
            for t in entry.transitions {
                bag.entries[t.word] = TransitionValue(
                    count: t.count,
                    recencyWeight: t.recencyWeight,
                    lastTimestampMilliseconds: t.lastTimestampMilliseconds,
                    surface: t.surface
                )
            }
            let key = ContextKey(tokens: entry.tokens)
            switch entry.tokens.count {
            case 1: nextGlobal2[key] = bag
            case 2: nextGlobal3[key] = bag
            case 3: nextGlobal4[key] = bag
            default: break
            }
        }
        var nextRegisters: [RegisterContextKey: TargetBag] = [:]
        nextRegisters.reserveCapacity(snapshot.registerContexts.count)
        for entry in snapshot.registerContexts {
            var bag = TargetBag()
            bag.total = entry.total
            for t in entry.transitions {
                bag.entries[t.word] = TransitionValue(
                    count: t.count,
                    recencyWeight: t.recencyWeight,
                    lastTimestampMilliseconds: t.lastTimestampMilliseconds,
                    surface: t.surface
                )
            }
            nextRegisters[RegisterContextKey(register: entry.register, tokens: entry.tokens)] = bag
        }
        var nextPhrases: [ContextKey: PhraseBag] = [:]
        nextPhrases.reserveCapacity(snapshot.phraseContexts.count)
        for entry in snapshot.phraseContexts {
            var bag = PhraseBag()
            for t in entry.transitions {
                bag.entries[t.words] = PhraseValue(
                    count: t.count,
                    recencyWeight: t.recencyWeight,
                    lastTimestampMilliseconds: t.lastTimestampMilliseconds,
                    surfaces: t.surfaces
                )
            }
            nextPhrases[ContextKey(tokens: entry.tokens)] = bag
        }
        var nextStreams: [StreamKey: StreamState] = [:]
        var nextStreamOrder: [StreamKey] = []
        for s in snapshot.streams {
            let key = StreamKey(
                history: s.historyIdentifier,
                consent: s.consentIdentifier,
                session: s.sessionIdentifier,
                app: s.appBundleIdentifier
            )
            var state = StreamState()
            state.context = s.context
            state.contextSurfaces = s.context
            state.pendingBuffer = s.pendingBuffer
            state.lastTimestampMilliseconds = s.lastTimestampMilliseconds
            nextStreams[key] = state
            nextStreamOrder.append(key)
        }
        var nextRecentIDs: [EventIdentity] = []
        var nextRecentSet: Set<EventIdentity> = []
        for r in snapshot.recentEvents {
            let id = EventIdentity(
                stream: StreamKey(
                    history: r.historyIdentifier,
                    consent: r.consentIdentifier,
                    session: r.sessionIdentifier,
                    app: r.appBundleIdentifier
                ),
                event: r.eventID
            )
            if nextRecentSet.insert(id).inserted {
                nextRecentIDs.append(id)
            }
        }

        global2Contexts = nextGlobal2
        global3Contexts = nextGlobal3
        global4Contexts = nextGlobal4
        registerContexts = nextRegisters
        phraseContexts = nextPhrases
        streams = nextStreams
        streamOrder = nextStreamOrder
        recentEventIDs = nextRecentIDs
        recentEventIDSet = nextRecentSet
        nextEventEvictionIndex = 0
        latestTimestampMilliseconds = snapshot.latestTimestampMilliseconds
        return true
    }

    // MARK: - Token Safety & Normalization

    private enum TokenStreamItem {
        case word(folded: String, surface: String, endsSentence: Bool)
        case contextBreak
    }

    static func queryTailTokens(from textBeforeCursor: String) -> [String] {
        // Read-only lookup: never stores or logs any text, and the index itself
        // is already scrubbed through `SecretRules` at ingest time. Using the
        // O(N) character/token sanitizer directly keeps hot-path lookup <30 µs
        // instead of running 10+ regexes per keystroke.
        let window = textBeforeCursor.count > 160
            ? String(textBeforeCursor.suffix(160))
            : textBeforeCursor
        let items = extractSafeTokens(fromScrubbed: window)
        var tail: [String] = []
        for item in items {
            switch item {
            case .contextBreak:
                tail.removeAll(keepingCapacity: true)
            case let .word(folded, _, endsSentence):
                if endsSentence {
                    tail.removeAll(keepingCapacity: true)
                } else {
                    tail.append(folded)
                    if tail.count > 3 {
                        tail.removeFirst(tail.count - 3)
                    }
                }
            }
        }
        return tail
    }

    public static func firstNormalizedWord(in text: String) -> String? {
        for rawSlice in text.split(whereSeparator: \.isWhitespace) {
            let raw = String(rawSlice)
            if let sanitized = sanitizeToken(raw) {
                return sanitized.folded
            }
            return nil
        }
        return nil
    }

    private static func extractSafeTokens(fromScrubbed text: String) -> [TokenStreamItem] {
        var result: [TokenStreamItem] = []
        var current = ""
        var sawNewline = false

        func flushCurrent() {
            guard !current.isEmpty else { return }
            defer { current.removeAll(keepingCapacity: true) }
            let endsSentence = current.last.map { sentenceBoundaryCharacters.contains($0) } ?? false
            if let sanitized = sanitizeToken(current) {
                result.append(.word(
                    folded: sanitized.folded,
                    surface: sanitized.surface,
                    endsSentence: endsSentence
                ))
            } else {
                result.append(.contextBreak)
            }
        }

        for ch in text {
            if ch == "\n" || ch == "\r" {
                flushCurrent()
                if !sawNewline {
                    result.append(.contextBreak)
                    sawNewline = true
                }
            } else if ch.isWhitespace {
                flushCurrent()
                sawNewline = false
            } else {
                sawNewline = false
                current.append(ch)
            }
        }
        flushCurrent()
        return result
    }

    static func sanitizeToken(_ raw: String) -> (folded: String, surface: String)? {
        guard !raw.isEmpty else { return nil }
        if raw.contains(where: \.isNumber) { return nil }
        if raw.unicodeScalars.contains(where: { forbiddenSymbolScalars.contains($0) }) {
            return nil
        }

        let trimmed = raw.trimmingCharacters(in: trimEdgeCharacters)
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .precomposedStringWithCanonicalMapping
        guard !trimmed.isEmpty,
              trimmed.unicodeScalars.count <= maximumTokenCharacters else {
            return nil
        }
        guard let first = trimmed.first, first.isLetter,
              let last = trimmed.last, last.isLetter else {
            return nil
        }
        guard trimmed.allSatisfy({ $0.isLetter || $0 == "'" || $0 == "-" }) else {
            return nil
        }
        if isHighEntropyOrSecretLike(trimmed) {
            return nil
        }
        let folded = trimmed.folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .precomposedStringWithCanonicalMapping
        return (folded: folded, surface: trimmed)
    }

    static func isHighEntropyOrSecretLike(_ token: String) -> Bool {
        let count = token.count
        guard count >= 10 else { return false }

        var transitions = 0
        var hasLower = false
        var hasUpper = false
        var prevIsUpper: Bool?
        var freqs: [Character: Int] = [:]
        freqs.reserveCapacity(count)

        for ch in token {
            freqs[ch, default: 0] += 1
            if ch.isLetter {
                let isUpper = ch.isUppercase
                if isUpper { hasUpper = true } else { hasLower = true }
                if let prev = prevIsUpper, prev != isUpper {
                    transitions += 1
                }
                prevIsUpper = isUpper
            }
        }

        if transitions >= 4 { return true }

        let total = Double(count)
        var entropy = 0.0
        for c in freqs.values {
            let p = Double(c) / total
            entropy -= p * log2(p)
        }
        if count >= 12, hasUpper, hasLower, transitions >= 2, entropy >= 3.5 {
            return true
        }
        if count >= 16, entropy >= 3.8 {
            return true
        }
        return false
    }

    static func isValidStoredToken(_ token: String) -> Bool {
        !token.isEmpty
            && token.unicodeScalars.count <= maximumTokenCharacters
            && !token.contains(where: \.isNumber)
            && !token.unicodeScalars.contains(where: { forbiddenSymbolScalars.contains($0) })
    }

    private mutating func takeStream(for key: StreamKey) -> StreamState {
        if let state = streams.removeValue(forKey: key) { return state }
        if streams.count >= Self.maximumActiveStreams, let oldest = streamOrder.first {
            streamOrder.removeFirst()
            streams.removeValue(forKey: oldest)
        }
        streamOrder.append(key)
        return StreamState()
    }

    private mutating func remember(_ event: PersonalHistoryEvent, in stream: StreamKey) -> Bool {
        let identity = EventIdentity(stream: stream, event: event.id)
        guard recentEventIDSet.insert(identity).inserted else { return false }
        if recentEventIDs.count < Self.maximumRecentEventIDs {
            recentEventIDs.append(identity)
        } else {
            recentEventIDSet.remove(recentEventIDs[nextEventEvictionIndex])
            recentEventIDs[nextEventEvictionIndex] = identity
            nextEventEvictionIndex = (nextEventEvictionIndex + 1) % Self.maximumRecentEventIDs
        }
        return true
    }

    private var recentEventsOldestFirst: [EventIdentity] {
        guard recentEventIDs.count == Self.maximumRecentEventIDs else { return recentEventIDs }
        return Array(recentEventIDs[nextEventEvictionIndex...] + recentEventIDs[..<nextEventEvictionIndex])
    }

    private static func tokensPrecede(_ left: [String], _ right: [String]) -> Bool {
        if left.count != right.count { return left.count < right.count }
        for (l, r) in zip(left, right) where l != r {
            return l < r
        }
        return false
    }
}
