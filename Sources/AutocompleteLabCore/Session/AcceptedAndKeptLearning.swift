import Foundation

public enum AcceptedAndKeptLearningOutcome: String, Codable, Equatable, Sendable {
    case kept
    case rejected
}

public struct AcceptedAndKeptLearningKey: Codable, Equatable, Hashable, Sendable {
    public let appBundleIdentifier: String
    public let fieldKind: String
    public let requestMode: String
    public let behaviorProfile: String

    public init(
        appBundleIdentifier: String,
        fieldKind: AXFieldKind,
        requestMode: CompletionRequestMode,
        behaviorProfileID: AutocompleteBehaviorProfileID
    ) {
        self.appBundleIdentifier = appBundleIdentifier.isEmpty ? "unknown" : appBundleIdentifier
        self.fieldKind = fieldKind.rawValue
        self.requestMode = requestMode.rawValue
        self.behaviorProfile = behaviorProfileID.rawValue
    }
}

public struct AcceptedAndKeptLearningSignal: Equatable, Sendable {
    public let probability: Double
    public let sampleCount: Int
    public let effectiveSampleCount: Double
    public let keptCount: Int
    public let rejectedCount: Int
    public let priorProbability: Double
    public let userAffinityAdjustment: Double
    public let utilityAdjustment: Double
    public let learningRestraint: Double
    public let decayFactor: Double

    public var traceMetadata: [String: String] {
        [
            "acceptedAndKeptProbability": Self.format(probability),
            "acceptedAndKeptSamples": String(sampleCount),
            "acceptedAndKeptEffectiveSamples": Self.format(effectiveSampleCount),
            "acceptedAndKeptKept": String(keptCount),
            "acceptedAndKeptRejected": String(rejectedCount),
            "acceptedAndKeptPrior": Self.format(priorProbability),
            "acceptedAndKeptAffinityAdjustment": Self.format(userAffinityAdjustment),
            "acceptedAndKeptUtilityAdjustment": Self.format(utilityAdjustment),
            "acceptedAndKeptLearningRestraint": Self.format(learningRestraint),
            "acceptedAndKeptDecayFactor": Self.format(decayFactor)
        ]
    }

    public var guidanceText: String {
        guard sampleCount > 0 else {
            return "Learning: no local accepted-and-kept evidence yet."
        }

        let counts = "\(keptCount) kept, \(rejectedCount) rejected"
        if keptCount > rejectedCount {
            return "Learning: this surface is earning trust locally (\(counts))."
        }

        if rejectedCount > keptCount {
            return "Learning: this surface is getting quieter locally (\(counts))."
        }

        return "Learning: mixed local signal (\(counts))."
    }

    static func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

public struct AcceptedAndKeptLearningStore: Codable, Equatable, Sendable {
    public let priorWeight: Double
    public let maximumBuckets: Int
    public let halfLifeSeconds: TimeInterval
    private var buckets: [AcceptedAndKeptLearningKey: AcceptedAndKeptLearningBucket] = [:]

    public init(
        priorWeight: Double = 4,
        maximumBuckets: Int = 512,
        halfLifeSeconds: TimeInterval = 14 * 24 * 60 * 60
    ) {
        self.priorWeight = max(0, priorWeight)
        self.maximumBuckets = max(1, maximumBuckets)
        self.halfLifeSeconds = max(60, halfLifeSeconds)
    }

    public init?(jsonData: Data) {
        guard let decoded = try? JSONDecoder().decode(Self.self, from: jsonData) else {
            return nil
        }
        self = decoded
    }

    public func jsonData() -> Data? {
        try? JSONEncoder().encode(self)
    }

    @discardableResult
    public mutating func record(
        _ outcome: AcceptedAndKeptLearningOutcome,
        key: AcceptedAndKeptLearningKey,
        now: Date = Date()
    ) -> AcceptedAndKeptLearningSignal {
        var bucket = buckets[key] ?? AcceptedAndKeptLearningBucket()
        switch outcome {
        case .kept:
            bucket.keptCount += 1
        case .rejected:
            bucket.rejectedCount += 1
        }
        bucket.lastUpdatedSequence = nextSequence()
        bucket.lastUpdatedAt = now
        buckets[key] = bucket
        trimIfNeeded()
        return signal(for: key, now: now)
    }

    public func signal(
        for key: AcceptedAndKeptLearningKey,
        now: Date = Date()
    ) -> AcceptedAndKeptLearningSignal {
        let bucket = buckets[key] ?? AcceptedAndKeptLearningBucket()
        let prior = priorProbability(for: key.requestMode)
        let samples = bucket.sampleCount
        let decayFactor = self.decayFactor(for: bucket, now: now)
        let keptWeight = Double(bucket.keptCount) * decayFactor
        let rejectedWeight = Double(bucket.rejectedCount) * decayFactor
        let effectiveSampleCount = keptWeight + rejectedWeight
        let probability = (keptWeight + prior * priorWeight)
            / max(1, keptWeight + rejectedWeight + priorWeight)
        let adjustmentScale = min(1, Double(samples) / 6)
        let adjustment = Self.bounded(
            (probability - prior) * 0.45 * adjustmentScale,
            to: -0.14...0.18
        )
        let utilityAdjustment = Self.bounded(
            (probability - prior) * 0.35 * adjustmentScale,
            to: -0.10...0.12
        )
        let learningRestraint = Self.learningRestraint(
            priorProbability: prior,
            probability: probability,
            keptWeight: keptWeight,
            rejectedWeight: rejectedWeight
        )

        return AcceptedAndKeptLearningSignal(
            probability: probability,
            sampleCount: samples,
            effectiveSampleCount: effectiveSampleCount,
            keptCount: bucket.keptCount,
            rejectedCount: bucket.rejectedCount,
            priorProbability: prior,
            userAffinityAdjustment: adjustment,
            utilityAdjustment: utilityAdjustment,
            learningRestraint: learningRestraint,
            decayFactor: decayFactor
        )
    }

    public func probabilityThreshold(for mode: CompletionRequestMode) -> Double {
        switch mode {
        case .wordCompletion:
            return 0.20
        case .phraseContinuation:
            return 0.30
        case .sentenceContinuation:
            return 0.18
        }
    }

    private func priorProbability(for requestMode: String) -> Double {
        switch requestMode {
        case CompletionRequestMode.wordCompletion.rawValue:
            return 0.42
        case CompletionRequestMode.sentenceContinuation.rawValue:
            return 0.28
        default:
            return 0.24
        }
    }

    private func decayFactor(
        for bucket: AcceptedAndKeptLearningBucket,
        now: Date
    ) -> Double {
        guard bucket.sampleCount > 0 else {
            return 1
        }

        let elapsed = max(0, now.timeIntervalSince(bucket.lastUpdatedAt))
        return pow(0.5, elapsed / halfLifeSeconds)
    }

    private mutating func trimIfNeeded() {
        guard buckets.count > maximumBuckets else {
            return
        }

        let trimCount = buckets.count - maximumBuckets
        let keysToRemove = buckets
            .sorted { $0.value.lastUpdatedSequence < $1.value.lastUpdatedSequence }
            .prefix(trimCount)
            .map(\.key)

        for key in keysToRemove {
            buckets[key] = nil
        }
    }

    private mutating func nextSequence() -> UInt64 {
        let currentMax = buckets.values.map(\.lastUpdatedSequence).max() ?? 0
        return currentMax + 1
    }

    private static func learningRestraint(
        priorProbability: Double,
        probability: Double,
        keptWeight: Double,
        rejectedWeight: Double
    ) -> Double {
        let effectiveSampleCount = keptWeight + rejectedWeight
        guard effectiveSampleCount >= 0.5 else {
            return 0
        }

        let evidenceScale = min(1, effectiveSampleCount / 4)
        let keptRate = keptWeight / max(0.0001, effectiveSampleCount)
        let rejectionRate = rejectedWeight / max(0.0001, effectiveSampleCount)
        let lowProbabilityPressure = max(0, (priorProbability - probability) / max(0.01, priorProbability))
        let lowKeptRatePressure = max(0, (0.25 - keptRate) / 0.25) * 0.85
        let rejectionDominancePressure = max(0, rejectionRate - 0.5) * 1.2
        let zeroKeptPressure = keptWeight < 0.5 && effectiveSampleCount >= 3 ? 1.0 : 0.0
        let pressure = max(
            zeroKeptPressure,
            lowProbabilityPressure,
            lowKeptRatePressure,
            rejectionDominancePressure
        )

        return bounded(pressure * evidenceScale * 0.75, to: 0...0.75)
    }

    private static func bounded(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

private struct AcceptedAndKeptLearningBucket: Codable, Equatable, Sendable {
    var keptCount: Int = 0
    var rejectedCount: Int = 0
    var lastUpdatedSequence: UInt64 = 0
    var lastUpdatedAt: Date = Date(timeIntervalSince1970: 0)

    var sampleCount: Int {
        keptCount + rejectedCount
    }
}
