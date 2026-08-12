import Foundation

/// Aggregate-only result of the local personal next-word experiment.
/// No targets, contexts, applications, sessions, or event identifiers escape
/// the in-memory learner through this value.
public struct PersonalNextWordShadowSnapshot: Equatable, Sendable {
    public let opportunities: Int
    public let predictions: Int
    public let exactHits: Int
    public let learnedContexts: Int
    public let learnedTransitions: Int
    public let capacityLimited: Bool

    public var coverage: Double {
        opportunities == 0 ? 0 : Double(predictions) / Double(opportunities)
    }

    public var precision: Double {
        predictions == 0 ? 0 : Double(exactHits) / Double(predictions)
    }
}

/// A bounded, deterministic, shadow-only personal next-word predictor.
///
/// The `r1945-live-v1` recipe safely adapts frozen discovery recipe `r1945`:
/// global counts from all observed history, folded contexts of up to four
/// words, support of at least two, winner share of at least one half, and
/// deterministic surface-exact targets. A candidate is frozen when its
/// predecessor closes, then scored before its target is learned, so replay
/// cannot see the answer before predicting it. A fresh live stream censors its
/// first token because events carry no reliable document-boundary provenance.
public struct PersonalNextWordShadow: Sendable {
    public static let recipeID = "r1945-live-v1"
    public static let evaluationStartMilliseconds: Int64 = 1_786_552_800_000

    static let maximumContexts = 8_192
    static let maximumTransitions = 32_768
    static let maximumActiveStreams = 64
    static let maximumRecentEventIDs = 2_048
    private static let maximumContextWords = 4
    private static let maximumTokenCharacters = 30
    private static let minimumWinnerSupport = 2
    private static let streamGapMilliseconds: Int64 = 30 * 60 * 1_000

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

    private struct StreamState: Sendable {
        var token = ""
        var tokenTooLong = false
        // History events do not say whether their first scalar is a complete
        // token or a tail fragment, so a fresh stream waits for a delimiter.
        var censored = true
        var context: [String] = []
        var hasOpportunity = false
        var prediction: String?
        var lastTimestampMilliseconds: Int64?
    }

    private struct ContextKey: Hashable, Sendable {
        let tokens: [String]
    }

    private struct TargetBag: Sendable {
        var counts: [String: Int] = [:]
        var total = 0
        var top: String?

        mutating func add(_ target: String) {
            counts[target] = Self.incremented(counts[target, default: 0])
            total = Self.incremented(total)

            if let top, top != target {
                let topCount = counts[top, default: 0]
                let targetCount = counts[target, default: 0]
                if targetCount > topCount
                    || targetCount == topCount
                        && PersonalNextWordShadow.surfacePrecedes(target, top) {
                    self.top = target
                }
            } else if top == nil {
                top = target
            }
        }

        var winner: (surface: String, support: Int, total: Int)? {
            guard let top else { return nil }
            return (
                surface: top,
                support: counts[top, default: 0],
                total: total
            )
        }

        private static func incremented(_ value: Int) -> Int {
            value == Int.max ? value : value + 1
        }
    }

    private let evaluationStart: Int64
    private var model: [ContextKey: TargetBag] = [:]
    private var transitionCount = 0
    private var streams: [StreamKey: StreamState] = [:]
    private var streamOrder: [StreamKey] = []
    private var recentEventIDs: [EventIdentity] = []
    private var recentEventIDSet: Set<EventIdentity> = []
    private var nextEventEvictionIndex = 0
    private var opportunities = 0
    private var predictions = 0
    private var exactHits = 0
    private var capacityLimited = false

    public init(
        evaluationStartMilliseconds: Int64 = Self.evaluationStartMilliseconds
    ) {
        evaluationStart = evaluationStartMilliseconds
    }

    public var snapshot: PersonalNextWordShadowSnapshot {
        PersonalNextWordShadowSnapshot(
            opportunities: opportunities,
            predictions: predictions,
            exactHits: exactHits,
            learnedContexts: model.count,
            learnedTransitions: transitionCount,
            capacityLimited: capacityLimited
        )
    }

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

            if event.source == .acceptedSuggestion {
                censorAcceptedText(event.text, state: &state)
            } else {
                for scalar in event.text.precomposedStringWithCanonicalMapping.unicodeScalars {
                    consumeTyped(
                        scalar,
                        timestampMilliseconds: event.timestampMilliseconds,
                        state: &state
                    )
                }
            }
            streams[key] = state
        }
    }

    public mutating func reset() {
        self = Self(evaluationStartMilliseconds: evaluationStart)
    }

    private mutating func takeStream(for key: StreamKey) -> StreamState {
        if let state = streams.removeValue(forKey: key) { return state }
        if streams.count >= Self.maximumActiveStreams,
           let oldest = streamOrder.first {
            streamOrder.removeFirst()
            streams.removeValue(forKey: oldest)
        }
        streamOrder.append(key)
        return StreamState()
    }

    private mutating func consumeTyped(
        _ scalar: Unicode.Scalar,
        timestampMilliseconds: Int64,
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
        finishToken(timestampMilliseconds: timestampMilliseconds, state: &state)
    }

    private mutating func finishToken(
        timestampMilliseconds: Int64,
        state: inout StreamState
    ) {
        defer {
            state.token.removeAll(keepingCapacity: true)
            state.tokenTooLong = false
        }
        guard !state.tokenTooLong, !state.token.isEmpty else { return }

        let target = Self.surface(state.token)
        guard (1...Self.maximumTokenCharacters).contains(target.unicodeScalars.count) else {
            return
        }

        if state.hasOpportunity, timestampMilliseconds >= evaluationStart {
            opportunities += 1
            if let prediction = state.prediction {
                predictions += 1
                if prediction == target { exactHits += 1 }
            }
        }

        learn(target, after: state.context)
        state.context.append(Self.folded(target))
        if state.context.count > Self.maximumContextWords {
            state.context.removeFirst(state.context.count - Self.maximumContextWords)
        }
        state.hasOpportunity = true
        state.prediction = candidate(after: state.context)
    }

    private mutating func censorAcceptedText(_ text: String, state: inout StreamState) {
        state.token.removeAll(keepingCapacity: false)
        state.tokenTooLong = false
        state.context.removeAll(keepingCapacity: false)
        state.hasOpportunity = false
        state.prediction = nil
        state.censored = true

        for scalar in text.precomposedStringWithCanonicalMapping.unicodeScalars {
            state.censored = Self.isLetter(scalar)
        }
    }

    private func candidate(after history: [String]) -> String? {
        let maximum = min(Self.maximumContextWords, history.count)
        for order in stride(from: maximum, through: 0, by: -1) {
            let key = Self.contextKey(order: order, history: history)
            guard let winner = model[key]?.winner else { continue }
            let requiredShare = winner.total / 2 + winner.total % 2
            if winner.support >= Self.minimumWinnerSupport,
               winner.support >= requiredShare {
                return winner.surface
            }
        }
        return nil
    }

    private mutating func learn(_ target: String, after history: [String]) {
        guard !capacityLimited else { return }
        let maximum = min(Self.maximumContextWords, history.count)
        let keys = (0...maximum).map { Self.contextKey(order: $0, history: history) }
        let addedContexts = keys.reduce(into: 0) { count, key in
            if model[key] == nil { count += 1 }
        }
        let addedTransitions = keys.reduce(into: 0) { count, key in
            if model[key]?.counts[target] == nil { count += 1 }
        }
        guard model.count <= Self.maximumContexts - addedContexts,
              transitionCount <= Self.maximumTransitions - addedTransitions else {
            capacityLimited = true
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
            nextEventEvictionIndex = (nextEventEvictionIndex + 1)
                % Self.maximumRecentEventIDs
        }
        return true
    }

    private static func contextKey(order: Int, history: [String]) -> ContextKey {
        ContextKey(tokens: order == 0 ? [] : Array(history.suffix(order)))
    }

    private static func folded(_ token: String) -> String {
        surface(token).folding(
            options: [.caseInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        ).precomposedStringWithCanonicalMapping
    }

    private static func surface(_ token: String) -> String {
        token.precomposedStringWithCanonicalMapping
    }

    private static func surfacePrecedes(_ left: String, _ right: String) -> Bool {
        var leftScalars = left.unicodeScalars.makeIterator()
        var rightScalars = right.unicodeScalars.makeIterator()
        while let leftScalar = leftScalars.next() {
            guard let rightScalar = rightScalars.next() else { return false }
            if leftScalar.value != rightScalar.value {
                return leftScalar.value < rightScalar.value
            }
        }
        return rightScalars.next() != nil
    }

    private static func isLetter(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter,
             .modifierLetter, .otherLetter:
            true
        default:
            false
        }
    }

    private static func isMark(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark:
            true
        default:
            false
        }
    }
}
