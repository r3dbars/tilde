import Foundation
import TildeCore

public enum LabCandidateSourceBucket: String, Codable, CaseIterable, Sendable {
    // Production vocabulary (`TextFreeCandidateSource`), what the live
    // ledger writes since 2026-09-02.
    case dictionary
    case baseModel = "base-model"
    case personal
    case basePersonalAgreement = "base-personal-agreement"
    case unknownLegacy = "unknown-legacy"
    // Lab-only buckets used by synthetic runners and older stored events.
    case generator
    case scene
    case mixed
    case unknown

    public init(production: TextFreeCandidateSource) {
        switch production {
        case .dictionary: self = .dictionary
        case .baseModel: self = .baseModel
        case .personal: self = .personal
        case .basePersonalAgreement: self = .basePersonalAgreement
        case .unknownLegacy: self = .unknownLegacy
        }
    }
}

public enum LabCandidateLengthBucket: String, Codable, CaseIterable, Sendable {
    case oneWord = "one-word"
    case twoToThree = "two-to-three"
    case fourToSeven = "four-to-seven"
    case eightPlus = "eight-plus"
    case unknown

    public static func from(wordCount: Int?) -> LabCandidateLengthBucket {
        guard let wordCount, wordCount > 0 else { return .unknown }
        switch wordCount {
        case 1: return .oneWord
        case 2...3: return .twoToThree
        case 4...7: return .fourToSeven
        default: return .eightPlus
        }
    }
}

public struct LabRetentionHorizonReport: Codable, Equatable, Sendable {
    public let observedEvents: Int
    public let missingEvents: Int
    public let missingnessCounts: [String: Int]
    public let retainedCharacters: Int
    public let replacedCharacters: Int
    public let netRetainedCharacters: Int

    public var coverage: Double {
        let total = observedEvents + missingEvents
        return total > 0 ? Double(observedEvents) / Double(total) : 0
    }
}

public enum LabOnlineEventPrivacy {
    public static let allowedTopLevelKeys: Set<String> = [
        "schema", "id", "campaignID", "occurredAt", "sessionDigestSHA256", "variant",
        "appCategory", "register", "boundary", "typingSpeedBucket", "safeOpportunity",
        "generated", "displayed", "policyHidden", "outcome",
        "acceptedCharacters", "replacedCharactersWithin5Seconds",
        "nextActionMilliseconds", "generatorMilliseconds", "firstStableWordMilliseconds",
        "settledVisibleMilliseconds", "recentInterventionCount",
        "deadlineMissed", "confidence", "candidateCharacters",
        "candidateSourceBucket", "candidateLengthBucket",
        "championDisagreed", "guardReason", "crashed", "timedOut", "opportunityCharacters",
        "wrongInsertionCount", "insertionCorruptionCount", "networkEgressDetected",
        "networkDenied", "residentMemoryMegabytes", "memoryPressureObserved",
        "thermalLevel", "runtimeRestarted",
        "sleepWakeObserved", "appSwitchObserved", "cacheHit", "confidenceFeatures",
        "retentionAt5Seconds", "retentionAt30Seconds", "retentionAtSegmentClose",
    ]

    public static let allowedHorizonKeys: Set<String> = [
        "retainedCharacters", "missingness",
    ]

    public static let allowedConfidenceFeatureKeys: Set<String> = [
        "schema", "firstTokenProbability", "meanSequenceLogProbability",
        "minimumTokenProbability", "meanProbabilityMargin", "meanTokenEntropy",
        "suggestionCharacters", "suggestionWords", "punctuationStop",
        "contextSourceQuality", "sceneFreshnessSeconds", "personalSupport",
        "personalConfidence", "firstTokenMilliseconds", "perturbationAgreement",
    ]

    public static func validateJSON(_ data: Data) throws {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LabOnlineExperimentError.invalidEvent
        }
        if let key = Set(object.keys).subtracting(allowedTopLevelKeys).sorted().first {
            throw LabOnlineExperimentError.forbiddenKey(key)
        }
        try validateHorizon(object["retentionAt5Seconds"], name: "retentionAt5Seconds")
        try validateHorizon(object["retentionAt30Seconds"], name: "retentionAt30Seconds")
        try validateHorizon(object["retentionAtSegmentClose"], name: "retentionAtSegmentClose")
        if let features = object["confidenceFeatures"] {
            guard let features = features as? [String: Any] else {
                throw LabOnlineExperimentError.invalidEvent
            }
            if let key = Set(features.keys).subtracting(allowedConfidenceFeatureKeys).sorted().first {
                throw LabOnlineExperimentError.forbiddenKey("confidenceFeatures.\(key)")
            }
        }
    }

    private static func validateHorizon(_ value: Any?, name: String) throws {
        guard let value else { return }
        guard let object = value as? [String: Any] else {
            throw LabOnlineExperimentError.invalidEvent
        }
        if let key = Set(object.keys).subtracting(allowedHorizonKeys).sorted().first {
            throw LabOnlineExperimentError.forbiddenKey("\(name).\(key)")
        }
    }
}

enum LabRetentionAccounting {
    static func observation(
        acceptedCharacters: Int,
        replacedCharacters: Int
    ) throws -> RetainedCharacterObservation {
        try RetainedCharacterObservation(
            retainedCharacters: max(0, acceptedCharacters - replacedCharacters)
        ).validated()
    }

    static func report(
        _ events: [LabOnlineExperimentEvent],
        horizon: KeyPath<LabOnlineExperimentEvent, RetainedCharacterObservation>,
        replacedAtHorizon: ((LabOnlineExperimentEvent) -> Int)? = nil
    ) -> LabRetentionHorizonReport {
        var observed = 0
        var missing = 0
        var missingnessCounts: [String: Int] = [:]
        var retained = 0
        var replaced = 0
        for event in events {
            let observation = event[keyPath: horizon]
            if let count = observation.retainedCharacters {
                observed += 1
                retained += count
                if let replacedAtHorizon {
                    replaced += replacedAtHorizon(event)
                } else if event.acceptedCharacters >= count {
                    replaced += event.acceptedCharacters - count
                }
            } else if let reason = observation.missingness {
                missing += 1
                missingnessCounts[reason.rawValue, default: 0] += 1
            }
        }
        return LabRetentionHorizonReport(
            observedEvents: observed,
            missingEvents: missing,
            missingnessCounts: missingnessCounts,
            retainedCharacters: retained,
            replacedCharacters: replaced,
            netRetainedCharacters: retained
        )
    }
}
