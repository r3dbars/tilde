import Foundation

public enum AcceptedAndKeptLearningOutcome: String, Codable, Equatable, Sendable {
    case kept
    case rejected
    case immediateDeletion
    case typedOver
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
    public let keptCount: Int
    public let rejectedCount: Int
    public let priorProbability: Double
    public let userAffinityAdjustment: Double
    public let utilityAdjustment: Double
    public let learningRestraint: Double
    public let decayFactor: Double
    public let immediateDeletionCount: Int
    public let typedOverCount: Int
    public let highEditDistanceCount: Int
    public let averageNormalizedEditDistance: Double?
    public let tinySampleGuardrailActive: Bool

    public var traceMetadata: [String: String] {
        var metadata = [
            "acceptedAndKeptProbability": Self.format(probability),
            "acceptedAndKeptSamples": String(sampleCount),
            "acceptedAndKeptKept": String(keptCount),
            "acceptedAndKeptRejected": String(rejectedCount),
            "acceptedAndKeptPrior": Self.format(priorProbability),
            "acceptedAndKeptAffinityAdjustment": Self.format(userAffinityAdjustment),
            "acceptedAndKeptUtilityAdjustment": Self.format(utilityAdjustment),
            "acceptedAndKeptLearningRestraint": Self.format(learningRestraint),
            "acceptedAndKeptDecayFactor": Self.format(decayFactor),
            "acceptedAndKeptImmediateDeletion": String(immediateDeletionCount),
            "acceptedAndKeptTypedOver": String(typedOverCount),
            "acceptedAndKeptHighEditDistance": String(highEditDistanceCount),
            "acceptedAndKeptTinySampleGuardrail": String(tinySampleGuardrailActive)
        ]
        if let averageNormalizedEditDistance {
            metadata["acceptedAndKeptAverageEditDistance"] = Self.format(averageNormalizedEditDistance)
        }
        return metadata
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
        normalizedEditDistance: Double? = nil,
        now: Date = Date()
    ) -> AcceptedAndKeptLearningSignal {
        var bucket = buckets[key] ?? AcceptedAndKeptLearningBucket()
        switch outcome {
        case .kept:
            bucket.keptCount += 1
        case .rejected:
            bucket.rejectedCount += 1
        case .immediateDeletion:
            bucket.rejectedCount += 1
            bucket.immediateDeletionCount += 1
        case .typedOver:
            bucket.rejectedCount += 1
            bucket.typedOverCount += 1
        }
        if let normalizedEditDistance {
            let safeEditDistance = Self.bounded(normalizedEditDistance, to: 0...1)
            bucket.editDistanceTotal += safeEditDistance
            bucket.editDistanceSampleCount += 1
            if safeEditDistance >= 0.45 {
                bucket.highEditDistanceCount += 1
            }
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
        let rejectedWeight = (
            Double(bucket.rejectedCount)
                + Double(bucket.immediateDeletionCount) * 0.75
                + Double(bucket.typedOverCount) * 0.55
                + Double(bucket.highEditDistanceCount) * 0.35
        ) * decayFactor
        let probability = (keptWeight + prior * priorWeight)
            / max(1, keptWeight + rejectedWeight + priorWeight)
        let tinySampleGuardrailActive = samples < 3
        let adjustmentScale = tinySampleGuardrailActive
            ? 0
            : min(1, Double(samples) / 8)
        let adjustment = Self.bounded(
            (probability - prior) * 0.45 * adjustmentScale,
            to: -0.14...0.18
        )
        let utilityAdjustment = Self.bounded(
            (probability - prior) * 0.35 * adjustmentScale,
            to: -0.10...0.12
        )
        let averageEditDistance = bucket.averageNormalizedEditDistance
        let negativeSignalCount = bucket.immediateDeletionCount
            + bucket.typedOverCount
            + bucket.highEditDistanceCount
        let negativeSignalRate = samples == 0
            ? 0
            : Double(negativeSignalCount) / Double(samples)
        let editDistancePressure = max(0, (averageEditDistance ?? 0) - 0.35)
        let learningRestraint = Self.bounded(
            (negativeSignalRate * 0.35 + editDistancePressure * 0.25) * adjustmentScale,
            to: 0...0.35
        )

        return AcceptedAndKeptLearningSignal(
            probability: probability,
            sampleCount: samples,
            keptCount: bucket.keptCount,
            rejectedCount: bucket.rejectedCount,
            priorProbability: prior,
            userAffinityAdjustment: adjustment,
            utilityAdjustment: utilityAdjustment,
            learningRestraint: learningRestraint,
            decayFactor: decayFactor,
            immediateDeletionCount: bucket.immediateDeletionCount,
            typedOverCount: bucket.typedOverCount,
            highEditDistanceCount: bucket.highEditDistanceCount,
            averageNormalizedEditDistance: averageEditDistance,
            tinySampleGuardrailActive: tinySampleGuardrailActive
        )
    }

    public func probabilityThreshold(for mode: CompletionRequestMode) -> Double {
        switch mode {
        case .wordCompletion:
            return 0.20
        case .phraseContinuation:
            return 0.12
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
            return 0.34
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

    private static func bounded(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

private struct AcceptedAndKeptLearningBucket: Codable, Equatable, Sendable {
    var keptCount: Int = 0
    var rejectedCount: Int = 0
    var immediateDeletionCount: Int = 0
    var typedOverCount: Int = 0
    var highEditDistanceCount: Int = 0
    var editDistanceTotal: Double = 0
    var editDistanceSampleCount: Int = 0
    var lastUpdatedSequence: UInt64 = 0
    var lastUpdatedAt: Date = Date(timeIntervalSince1970: 0)

    var sampleCount: Int {
        keptCount + rejectedCount
    }

    var averageNormalizedEditDistance: Double? {
        guard editDistanceSampleCount > 0 else {
            return nil
        }

        return editDistanceTotal / Double(editDistanceSampleCount)
    }

    enum CodingKeys: String, CodingKey {
        case keptCount
        case rejectedCount
        case immediateDeletionCount
        case typedOverCount
        case highEditDistanceCount
        case editDistanceTotal
        case editDistanceSampleCount
        case lastUpdatedSequence
        case lastUpdatedAt
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keptCount = try container.decodeIfPresent(Int.self, forKey: .keptCount) ?? 0
        rejectedCount = try container.decodeIfPresent(Int.self, forKey: .rejectedCount) ?? 0
        immediateDeletionCount = try container.decodeIfPresent(Int.self, forKey: .immediateDeletionCount) ?? 0
        typedOverCount = try container.decodeIfPresent(Int.self, forKey: .typedOverCount) ?? 0
        highEditDistanceCount = try container.decodeIfPresent(Int.self, forKey: .highEditDistanceCount) ?? 0
        editDistanceTotal = try container.decodeIfPresent(Double.self, forKey: .editDistanceTotal) ?? 0
        editDistanceSampleCount = try container.decodeIfPresent(Int.self, forKey: .editDistanceSampleCount) ?? 0
        lastUpdatedSequence = try container.decodeIfPresent(UInt64.self, forKey: .lastUpdatedSequence) ?? 0
        lastUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt)
            ?? Date(timeIntervalSince1970: 0)
    }
}
