import Foundation

public enum AcceptedAndKeptLearningOutcome: String, Equatable, Sendable {
    case kept
    case rejected
}

public struct AcceptedAndKeptLearningKey: Equatable, Hashable, Sendable {
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

    public var traceMetadata: [String: String] {
        [
            "acceptedAndKeptProbability": Self.format(probability),
            "acceptedAndKeptSamples": String(sampleCount),
            "acceptedAndKeptKept": String(keptCount),
            "acceptedAndKeptRejected": String(rejectedCount),
            "acceptedAndKeptPrior": Self.format(priorProbability),
            "acceptedAndKeptAffinityAdjustment": Self.format(userAffinityAdjustment)
        ]
    }

    static func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

public struct AcceptedAndKeptLearningStore: Equatable, Sendable {
    public let priorWeight: Double
    public let maximumBuckets: Int
    private var buckets: [AcceptedAndKeptLearningKey: AcceptedAndKeptLearningBucket] = [:]

    public init(
        priorWeight: Double = 4,
        maximumBuckets: Int = 512
    ) {
        self.priorWeight = max(0, priorWeight)
        self.maximumBuckets = max(1, maximumBuckets)
    }

    @discardableResult
    public mutating func record(
        _ outcome: AcceptedAndKeptLearningOutcome,
        key: AcceptedAndKeptLearningKey
    ) -> AcceptedAndKeptLearningSignal {
        var bucket = buckets[key] ?? AcceptedAndKeptLearningBucket()
        switch outcome {
        case .kept:
            bucket.keptCount += 1
        case .rejected:
            bucket.rejectedCount += 1
        }
        bucket.lastUpdatedSequence = nextSequence()
        buckets[key] = bucket
        trimIfNeeded()
        return signal(for: key)
    }

    public func signal(for key: AcceptedAndKeptLearningKey) -> AcceptedAndKeptLearningSignal {
        let bucket = buckets[key] ?? AcceptedAndKeptLearningBucket()
        let prior = priorProbability(for: key.requestMode)
        let samples = bucket.sampleCount
        let probability = (Double(bucket.keptCount) + prior * priorWeight)
            / max(1, Double(samples) + priorWeight)
        let adjustmentScale = min(1, Double(samples) / 6)
        let adjustment = Self.bounded(
            (probability - prior) * 0.45 * adjustmentScale,
            to: -0.14...0.18
        )

        return AcceptedAndKeptLearningSignal(
            probability: probability,
            sampleCount: samples,
            keptCount: bucket.keptCount,
            rejectedCount: bucket.rejectedCount,
            priorProbability: prior,
            userAffinityAdjustment: adjustment
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

private struct AcceptedAndKeptLearningBucket: Equatable, Sendable {
    var keptCount: Int = 0
    var rejectedCount: Int = 0
    var lastUpdatedSequence: UInt64 = 0

    var sampleCount: Int {
        keptCount + rejectedCount
    }
}
