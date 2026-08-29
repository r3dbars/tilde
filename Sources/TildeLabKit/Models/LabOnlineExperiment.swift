import CryptoKit
import Foundation
import TildeCore

public enum LabOnlineVariant: String, Codable, Sendable {
    case champion
    case challenger
    case hidden
}

public enum LabOnlineInteractionOutcome: String, Codable, CaseIterable, Sendable {
    case acceptedAll = "accepted-all"
    case acceptedWord = "accepted-word"
    case typedThrough = "typed-through"
    case ignored
    case dismissed
    case corrected
    case undone
    case hidden
    case unavailable
}

public enum LabOnlineAppCategory: String, Codable, CaseIterable, Sendable {
    case chat
    case email
    case prose
    case other
}

public enum LabTypingSpeedBucket: String, Codable, CaseIterable, Sendable {
    case slow
    case medium
    case fast
    case unknown
}

public enum LabOnlineRegister: String, Codable, CaseIterable, Sendable {
    case chat
    case email
    case prose
}

public enum LabOnlineBoundary: String, Codable, CaseIterable, Sendable {
    case midWord = "mid-word"
    case wordBoundary = "word-boundary"
    case sentenceBoundary = "sentence-boundary"
}

public struct LabOnlineExperimentPlan: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.online-plan.v2"

    public let schema: String
    public let campaignID: UUID
    public let phase: LabCampaignPhase
    public let championArmID: String
    public let championArmDigestSHA256: String
    public let challengerArmID: String
    public let challengerArmDigestSHA256: String
    public let challengerAllocation: Double
    public let attentionHoldbackRate: Double
    public let startsAt: Date
    public let endsAt: Date
    public let safetyEvidenceDigestSHA256: String?
    public let minimumObservedDurationSeconds: Double?
    public let minimumEventCount: Int?

    public init(
        campaignID: UUID,
        phase: LabCampaignPhase,
        championArmID: String,
        championArmDigestSHA256: String,
        challengerArmID: String,
        challengerArmDigestSHA256: String,
        challengerAllocation: Double,
        attentionHoldbackRate: Double = 0,
        startsAt: Date = Date(),
        endsAt: Date,
        safetyEvidenceDigestSHA256: String? = nil,
        minimumObservedDurationSeconds: Double? = nil,
        minimumEventCount: Int? = nil
    ) {
        schema = Self.currentSchema
        self.campaignID = campaignID
        self.phase = phase
        self.championArmID = championArmID
        self.championArmDigestSHA256 = championArmDigestSHA256
        self.challengerArmID = challengerArmID
        self.challengerArmDigestSHA256 = challengerArmDigestSHA256
        self.challengerAllocation = challengerAllocation
        self.attentionHoldbackRate = attentionHoldbackRate
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.safetyEvidenceDigestSHA256 = safetyEvidenceDigestSHA256
        self.minimumObservedDurationSeconds = minimumObservedDurationSeconds
        self.minimumEventCount = minimumEventCount
    }

    @discardableResult
    public func validated() throws -> LabOnlineExperimentPlan {
        guard schema == Self.currentSchema else { throw LabOnlineExperimentError.unsupportedSchema }
        guard phase == .shadow || phase == .dogfood || phase == .soak else {
            throw LabOnlineExperimentError.invalidPhase
        }
        guard startsAt < endsAt, endsAt.timeIntervalSince(startsAt) <= 31 * 86_400 else {
            throw LabOnlineExperimentError.invalidWindow
        }
        guard Self.safeID(championArmID), Self.safeID(challengerArmID),
              championArmID != challengerArmID,
              Self.isDigest(championArmDigestSHA256),
              Self.isDigest(challengerArmDigestSHA256) else {
            throw LabOnlineExperimentError.invalidArm
        }
        if phase == .shadow {
            guard challengerAllocation == 0, attentionHoldbackRate == 0 else {
                throw LabOnlineExperimentError.shadowMayNotDisplay
            }
            guard minimumObservedDurationSeconds == nil, minimumEventCount == nil else {
                throw LabOnlineExperimentError.invalidWindow
            }
        } else if phase == .dogfood {
            guard challengerAllocation > 0, challengerAllocation <= 0.5,
                  attentionHoldbackRate >= 0, attentionHoldbackRate <= 0.5 else {
                throw LabOnlineExperimentError.invalidAllocation
            }
            if challengerAllocation > 0.10 {
                guard safetyEvidenceDigestSHA256.map(Self.isDigest) == true else {
                    throw LabOnlineExperimentError.rampRequiresSafetyEvidence
                }
            }
            guard minimumObservedDurationSeconds == nil, minimumEventCount == nil else {
                throw LabOnlineExperimentError.invalidWindow
            }
        } else {
            guard challengerAllocation == 1, attentionHoldbackRate == 0,
                  safetyEvidenceDigestSHA256.map(Self.isDigest) == true,
                  let minimumObservedDurationSeconds,
                  (60...7 * 86_400).contains(minimumObservedDurationSeconds),
                  let minimumEventCount,
                  (1...10_000_000).contains(minimumEventCount) else {
                throw LabOnlineExperimentError.invalidSoakRequirements
            }
        }
        return self
    }

    public func assignment(sessionIdentifier: String) -> LabOnlineVariant {
        if phase == .soak { return .challenger }
        guard phase == .dogfood, !sessionIdentifier.isEmpty else { return .champion }
        let unit = Self.unitHash("\(campaignID.uuidString):variant:\(sessionIdentifier)")
        return unit < challengerAllocation ? .challenger : .champion
    }

    public func shouldHoldBack(opportunityIdentifier: UUID) -> Bool {
        guard phase == .dogfood, attentionHoldbackRate > 0 else { return false }
        return Self.unitHash("\(campaignID.uuidString):holdback:\(opportunityIdentifier.uuidString)")
            < attentionHoldbackRate
    }

    private static func unitHash(_ value: String) -> Double {
        let digest = SHA256.hash(data: Data(value.utf8))
        let prefix = digest.prefix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        return Double(prefix) / Double(UInt64.max)
    }

    private static func safeID(_ value: String) -> Bool {
        value.range(of: "^[A-Za-z0-9][A-Za-z0-9._:+-]{0,127}$", options: .regularExpression)
            == value.startIndex..<value.endIndex
    }

    private static func isDigest(_ value: String) -> Bool {
        value.range(of: "^[a-f0-9]{64}$", options: .regularExpression)
            == value.startIndex..<value.endIndex
    }
}

/// One text-free local event. IDs are random or hashed before this boundary;
/// no prompt, screen text, document text, candidate, bundle ID, or filename is
/// representable by the schema.
public struct LabOnlineExperimentEvent: Codable, Equatable, Identifiable, Sendable {
    public static let currentSchema = "tilde-lab.online-event.v3"
    public static let legacySchemaV2 = "tilde-lab.online-event.v2"

    public let schema: String
    public let id: UUID
    public let campaignID: UUID
    public let occurredAt: Date
    public let sessionDigestSHA256: String
    public let variant: LabOnlineVariant
    public let appCategory: LabOnlineAppCategory
    public let register: LabOnlineRegister
    public let boundary: LabOnlineBoundary
    public let typingSpeedBucket: LabTypingSpeedBucket
    public let safeOpportunity: Bool
    public let generated: Bool
    public let displayed: Bool
    public let policyHidden: Bool
    public let outcome: LabOnlineInteractionOutcome
    public let acceptedCharacters: Int
    public let replacedCharactersWithin5Seconds: Int
    public let nextActionMilliseconds: Int?
    public let generatorMilliseconds: Int?
    public let firstStableWordMilliseconds: Int?
    public let settledVisibleMilliseconds: Int?
    public let recentInterventionCount: Int?
    public let deadlineMissed: Bool
    public let confidence: Double?
    public let candidateCharacters: Int
    public let candidateSourceBucket: LabCandidateSourceBucket
    public let candidateLengthBucket: LabCandidateLengthBucket
    public let championDisagreed: Bool
    public let guardReason: LabDecisionReason?
    public let crashed: Bool
    public let timedOut: Bool
    public let opportunityCharacters: Int
    public let wrongInsertionCount: Int?
    public let insertionCorruptionCount: Int?
    public let networkEgressDetected: Bool?
    public let networkDenied: Bool?
    public let residentMemoryMegabytes: Int?
    public let memoryPressureObserved: Bool?
    public let thermalLevel: LabResearchThermalLevel?
    public let runtimeRestarted: Bool?
    public let sleepWakeObserved: Bool?
    public let appSwitchObserved: Bool?
    public let cacheHit: Bool?
    public let confidenceFeatures: LabConfidenceFeaturesV1?
    public let retentionAt5Seconds: RetainedCharacterObservation
    public let retentionAt30Seconds: RetainedCharacterObservation
    public let retentionAtSegmentClose: RetainedCharacterObservation

    public init(
        id: UUID = UUID(),
        campaignID: UUID,
        occurredAt: Date = Date(),
        sessionDigestSHA256: String,
        variant: LabOnlineVariant,
        appCategory: LabOnlineAppCategory,
        register: LabOnlineRegister,
        boundary: LabOnlineBoundary,
        typingSpeedBucket: LabTypingSpeedBucket,
        safeOpportunity: Bool,
        displayed: Bool,
        outcome: LabOnlineInteractionOutcome,
        acceptedCharacters: Int = 0,
        replacedCharactersWithin5Seconds: Int = 0,
        nextActionMilliseconds: Int? = nil,
        generatorMilliseconds: Int? = nil,
        firstStableWordMilliseconds: Int? = nil,
        deadlineMissed: Bool = false,
        confidence: Double? = nil,
        candidateCharacters: Int = 0,
        championDisagreed: Bool = false,
        guardReason: LabDecisionReason? = nil,
        crashed: Bool = false,
        timedOut: Bool = false,
        opportunityCharacters: Int = 1,
        wrongInsertionCount: Int? = nil,
        insertionCorruptionCount: Int? = nil,
        networkEgressDetected: Bool? = nil,
        networkDenied: Bool? = nil,
        residentMemoryMegabytes: Int? = nil,
        memoryPressureObserved: Bool? = nil,
        thermalLevel: LabResearchThermalLevel? = nil,
        runtimeRestarted: Bool? = nil,
        sleepWakeObserved: Bool? = nil,
        appSwitchObserved: Bool? = nil,
        cacheHit: Bool? = nil,
        confidenceFeatures: LabConfidenceFeaturesV1? = nil,
        generated: Bool? = nil,
        policyHidden: Bool? = nil,
        candidateSourceBucket: LabCandidateSourceBucket = .unknown,
        candidateLengthBucket: LabCandidateLengthBucket? = nil,
        settledVisibleMilliseconds: Int? = nil,
        recentInterventionCount: Int? = nil,
        retentionAt5Seconds: RetainedCharacterObservation? = nil,
        retentionAt30Seconds: RetainedCharacterObservation? = nil,
        retentionAtSegmentClose: RetainedCharacterObservation? = nil,
        schema: String = LabOnlineExperimentEvent.currentSchema
    ) {
        self.schema = schema
        self.id = id
        self.campaignID = campaignID
        self.occurredAt = occurredAt
        self.sessionDigestSHA256 = sessionDigestSHA256
        self.variant = variant
        self.appCategory = appCategory
        self.register = register
        self.boundary = boundary
        self.typingSpeedBucket = typingSpeedBucket
        self.safeOpportunity = safeOpportunity
        self.generated = generated ?? (displayed || candidateCharacters > 0)
        self.displayed = displayed
        self.policyHidden = policyHidden ?? (outcome == .hidden && !displayed)
        self.outcome = outcome
        self.acceptedCharacters = acceptedCharacters
        self.replacedCharactersWithin5Seconds = replacedCharactersWithin5Seconds
        self.nextActionMilliseconds = nextActionMilliseconds
        self.generatorMilliseconds = generatorMilliseconds
        self.firstStableWordMilliseconds = firstStableWordMilliseconds
        self.settledVisibleMilliseconds = settledVisibleMilliseconds
        self.recentInterventionCount = recentInterventionCount
        self.deadlineMissed = deadlineMissed
        self.confidence = confidence
        self.candidateCharacters = candidateCharacters
        self.candidateSourceBucket = candidateSourceBucket
        self.candidateLengthBucket = candidateLengthBucket
            ?? LabCandidateLengthBucket.from(wordCount: confidenceFeatures?.suggestionWords)
        self.championDisagreed = championDisagreed
        self.guardReason = guardReason
        self.crashed = crashed
        self.timedOut = timedOut
        self.opportunityCharacters = opportunityCharacters
        self.wrongInsertionCount = wrongInsertionCount
        self.insertionCorruptionCount = insertionCorruptionCount
        self.networkEgressDetected = networkEgressDetected
        self.networkDenied = networkDenied
        self.residentMemoryMegabytes = residentMemoryMegabytes
        self.memoryPressureObserved = memoryPressureObserved
        self.thermalLevel = thermalLevel
        self.runtimeRestarted = runtimeRestarted
        self.sleepWakeObserved = sleepWakeObserved
        self.appSwitchObserved = appSwitchObserved
        self.cacheHit = cacheHit
        self.confidenceFeatures = confidenceFeatures
        self.retentionAt5Seconds = retentionAt5Seconds ?? (
            try? LabRetentionAccounting.observation(
                acceptedCharacters: acceptedCharacters,
                replacedCharacters: replacedCharactersWithin5Seconds
            )
        ) ?? RetainedCharacterObservation(missingness: .notYetObserved)
        self.retentionAt30Seconds = retentionAt30Seconds
            ?? RetainedCharacterObservation(missingness: .notYetObserved)
        self.retentionAtSegmentClose = retentionAtSegmentClose
            ?? RetainedCharacterObservation(missingness: .notYetObserved)
    }

    @discardableResult
    public func validated(for plan: LabOnlineExperimentPlan) throws -> LabOnlineExperimentEvent {
        try plan.validated()
        guard schema == Self.currentSchema || schema == Self.legacySchemaV2,
              campaignID == plan.campaignID,
              occurredAt >= plan.startsAt, occurredAt <= plan.endsAt,
              sessionDigestSHA256.range(
                  of: "^[a-f0-9]{64}$", options: .regularExpression
              ) == sessionDigestSHA256.startIndex..<sessionDigestSHA256.endIndex,
              acceptedCharacters >= 0, replacedCharactersWithin5Seconds >= 0,
              candidateCharacters >= 0, opportunityCharacters > 0,
              wrongInsertionCount.map({ $0 >= 0 }) ?? true,
              insertionCorruptionCount.map({ $0 >= 0 }) ?? true,
              residentMemoryMegabytes.map({ (1...1_048_576).contains($0) }) ?? true,
              nextActionMilliseconds.map({ $0 >= 0 && $0 <= 300_000 }) ?? true,
              generatorMilliseconds.map({ $0 >= 0 && $0 <= 300_000 }) ?? true,
              firstStableWordMilliseconds.map({ $0 >= 0 && $0 <= 300_000 }) ?? true,
              settledVisibleMilliseconds.map({ $0 >= 0 && $0 <= 300_000 }) ?? true,
              recentInterventionCount.map({ $0 >= 0 && $0 <= 10_000 }) ?? true,
              confidence.map({ (0...1).contains($0) }) ?? true,
              acceptedCharacters <= candidateCharacters,
              replacedCharactersWithin5Seconds <= acceptedCharacters else {
            throw LabOnlineExperimentError.invalidEvent
        }
        do {
            _ = try retentionAt5Seconds.validated()
            _ = try retentionAt30Seconds.validated()
            _ = try retentionAtSegmentClose.validated()
        } catch RetainedCharacterObservationError.ambiguous {
            throw LabOnlineExperimentError.ambiguousRetention
        } catch {
            throw LabOnlineExperimentError.invalidEvent
        }
        if let five = retentionAt5Seconds.retainedCharacters,
           five > acceptedCharacters {
            throw LabOnlineExperimentError.invalidEvent
        }
        if let five = retentionAt5Seconds.retainedCharacters,
           let thirty = retentionAt30Seconds.retainedCharacters,
           thirty > five {
            throw LabOnlineExperimentError.invalidEvent
        }
        if let thirty = retentionAt30Seconds.retainedCharacters,
           let segment = retentionAtSegmentClose.retainedCharacters,
           segment > thirty {
            throw LabOnlineExperimentError.invalidEvent
        }
        if let five = retentionAt5Seconds.retainedCharacters,
           retentionAt30Seconds.retainedCharacters == nil,
           let segment = retentionAtSegmentClose.retainedCharacters,
           segment > five {
            throw LabOnlineExperimentError.invalidEvent
        }
        if let confidenceFeatures { try confidenceFeatures.validated() }
        if displayed && (!safeOpportunity || variant == .hidden || candidateCharacters == 0) {
            throw LabOnlineExperimentError.invalidEvent
        }
        if displayed && !generated { throw LabOnlineExperimentError.invalidEvent }
        if policyHidden && displayed { throw LabOnlineExperimentError.invalidEvent }
        if plan.phase == .shadow, variant == .challenger, displayed {
            throw LabOnlineExperimentError.shadowMayNotDisplay
        }
        if displayed == (outcome == .hidden || outcome == .unavailable) {
            throw LabOnlineExperimentError.invalidEvent
        }
        if (outcome == .acceptedAll || outcome == .acceptedWord), acceptedCharacters == 0 {
            throw LabOnlineExperimentError.invalidEvent
        }
        if (outcome == .ignored || outcome == .dismissed || outcome == .typedThrough
            || outcome == .hidden || outcome == .unavailable),
           acceptedCharacters != 0 || replacedCharactersWithin5Seconds != 0 {
            throw LabOnlineExperimentError.invalidEvent
        }
        if outcome == .typedThrough,
           !TypedThroughRule.isEligible(
               displayed: displayed,
               settledVisibleMilliseconds: settledVisibleMilliseconds
           ) {
            throw LabOnlineExperimentError.invalidEvent
        }
        return self
    }
}

extension LabOnlineExperimentEvent {
    enum CodingKeys: String, CodingKey {
        case schema, id, campaignID, occurredAt, sessionDigestSHA256, variant
        case appCategory, register, boundary, typingSpeedBucket, safeOpportunity
        case generated, displayed, policyHidden, outcome
        case acceptedCharacters, replacedCharactersWithin5Seconds
        case nextActionMilliseconds, generatorMilliseconds, firstStableWordMilliseconds
        case settledVisibleMilliseconds, recentInterventionCount
        case deadlineMissed, confidence, candidateCharacters
        case candidateSourceBucket, candidateLengthBucket
        case championDisagreed, guardReason, crashed, timedOut, opportunityCharacters
        case wrongInsertionCount, insertionCorruptionCount, networkEgressDetected
        case networkDenied, residentMemoryMegabytes, memoryPressureObserved
        case thermalLevel, runtimeRestarted, sleepWakeObserved, appSwitchObserved
        case cacheHit, confidenceFeatures
        case retentionAt5Seconds, retentionAt30Seconds, retentionAtSegmentClose
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schema = try container.decode(String.self, forKey: .schema)
        guard schema == Self.currentSchema || schema == Self.legacySchemaV2 else {
            throw DecodingError.dataCorruptedError(
                forKey: .schema,
                in: container,
                debugDescription: "Unsupported online event schema."
            )
        }
        let acceptedCharacters = try container.decode(Int.self, forKey: .acceptedCharacters)
        let replacedCharacters = try container.decode(Int.self, forKey: .replacedCharactersWithin5Seconds)
        let displayed = try container.decode(Bool.self, forKey: .displayed)
        let candidateCharacters = try container.decode(Int.self, forKey: .candidateCharacters)
        let outcome = try container.decode(LabOnlineInteractionOutcome.self, forKey: .outcome)
        let confidenceFeatures = try container.decodeIfPresent(
            LabConfidenceFeaturesV1.self,
            forKey: .confidenceFeatures
        )
        let isLegacy = schema == Self.legacySchemaV2
        let retention5: RetainedCharacterObservation
        let retention30: RetainedCharacterObservation
        let retentionSegment: RetainedCharacterObservation
        if isLegacy {
            retention5 = try container.decodeIfPresent(
                RetainedCharacterObservation.self,
                forKey: .retentionAt5Seconds
            ) ?? (try LabRetentionAccounting.observation(
                acceptedCharacters: acceptedCharacters,
                replacedCharacters: replacedCharacters
            ))
            retention30 = try container.decodeIfPresent(
                RetainedCharacterObservation.self,
                forKey: .retentionAt30Seconds
            ) ?? RetainedCharacterObservation(missingness: .legacySchema)
            retentionSegment = try container.decodeIfPresent(
                RetainedCharacterObservation.self,
                forKey: .retentionAtSegmentClose
            ) ?? RetainedCharacterObservation(missingness: .legacySchema)
        } else {
            retention5 = try container.decode(RetainedCharacterObservation.self, forKey: .retentionAt5Seconds)
            retention30 = try container.decode(RetainedCharacterObservation.self, forKey: .retentionAt30Seconds)
            retentionSegment = try container.decode(
                RetainedCharacterObservation.self,
                forKey: .retentionAtSegmentClose
            )
        }
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            campaignID: try container.decode(UUID.self, forKey: .campaignID),
            occurredAt: try container.decode(Date.self, forKey: .occurredAt),
            sessionDigestSHA256: try container.decode(String.self, forKey: .sessionDigestSHA256),
            variant: try container.decode(LabOnlineVariant.self, forKey: .variant),
            appCategory: try container.decode(LabOnlineAppCategory.self, forKey: .appCategory),
            register: try container.decode(LabOnlineRegister.self, forKey: .register),
            boundary: try container.decode(LabOnlineBoundary.self, forKey: .boundary),
            typingSpeedBucket: try container.decode(LabTypingSpeedBucket.self, forKey: .typingSpeedBucket),
            safeOpportunity: try container.decode(Bool.self, forKey: .safeOpportunity),
            displayed: displayed,
            outcome: outcome,
            acceptedCharacters: acceptedCharacters,
            replacedCharactersWithin5Seconds: replacedCharacters,
            nextActionMilliseconds: try container.decodeIfPresent(Int.self, forKey: .nextActionMilliseconds),
            generatorMilliseconds: try container.decodeIfPresent(Int.self, forKey: .generatorMilliseconds),
            firstStableWordMilliseconds: try container.decodeIfPresent(
                Int.self,
                forKey: .firstStableWordMilliseconds
            ),
            deadlineMissed: try container.decodeIfPresent(Bool.self, forKey: .deadlineMissed) ?? false,
            confidence: try container.decodeIfPresent(Double.self, forKey: .confidence),
            candidateCharacters: candidateCharacters,
            championDisagreed: try container.decodeIfPresent(Bool.self, forKey: .championDisagreed) ?? false,
            guardReason: try container.decodeIfPresent(LabDecisionReason.self, forKey: .guardReason),
            crashed: try container.decodeIfPresent(Bool.self, forKey: .crashed) ?? false,
            timedOut: try container.decodeIfPresent(Bool.self, forKey: .timedOut) ?? false,
            opportunityCharacters: try container.decodeIfPresent(Int.self, forKey: .opportunityCharacters) ?? 1,
            wrongInsertionCount: try container.decodeIfPresent(Int.self, forKey: .wrongInsertionCount),
            insertionCorruptionCount: try container.decodeIfPresent(Int.self, forKey: .insertionCorruptionCount),
            networkEgressDetected: try container.decodeIfPresent(Bool.self, forKey: .networkEgressDetected),
            networkDenied: try container.decodeIfPresent(Bool.self, forKey: .networkDenied),
            residentMemoryMegabytes: try container.decodeIfPresent(Int.self, forKey: .residentMemoryMegabytes),
            memoryPressureObserved: try container.decodeIfPresent(Bool.self, forKey: .memoryPressureObserved),
            thermalLevel: try container.decodeIfPresent(LabResearchThermalLevel.self, forKey: .thermalLevel),
            runtimeRestarted: try container.decodeIfPresent(Bool.self, forKey: .runtimeRestarted),
            sleepWakeObserved: try container.decodeIfPresent(Bool.self, forKey: .sleepWakeObserved),
            appSwitchObserved: try container.decodeIfPresent(Bool.self, forKey: .appSwitchObserved),
            cacheHit: try container.decodeIfPresent(Bool.self, forKey: .cacheHit),
            confidenceFeatures: confidenceFeatures,
            generated: try container.decodeIfPresent(Bool.self, forKey: .generated),
            policyHidden: try container.decodeIfPresent(Bool.self, forKey: .policyHidden),
            candidateSourceBucket: try container.decodeIfPresent(
                LabCandidateSourceBucket.self,
                forKey: .candidateSourceBucket
            ) ?? .unknown,
            candidateLengthBucket: try container.decodeIfPresent(
                LabCandidateLengthBucket.self,
                forKey: .candidateLengthBucket
            ),
            settledVisibleMilliseconds: try container.decodeIfPresent(
                Int.self,
                forKey: .settledVisibleMilliseconds
            ),
            recentInterventionCount: try container.decodeIfPresent(Int.self, forKey: .recentInterventionCount),
            retentionAt5Seconds: retention5,
            retentionAt30Seconds: retention30,
            retentionAtSegmentClose: retentionSegment,
            schema: schema
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schema, forKey: .schema)
        try container.encode(id, forKey: .id)
        try container.encode(campaignID, forKey: .campaignID)
        try container.encode(occurredAt, forKey: .occurredAt)
        try container.encode(sessionDigestSHA256, forKey: .sessionDigestSHA256)
        try container.encode(variant, forKey: .variant)
        try container.encode(appCategory, forKey: .appCategory)
        try container.encode(register, forKey: .register)
        try container.encode(boundary, forKey: .boundary)
        try container.encode(typingSpeedBucket, forKey: .typingSpeedBucket)
        try container.encode(safeOpportunity, forKey: .safeOpportunity)
        try container.encode(displayed, forKey: .displayed)
        try container.encode(outcome, forKey: .outcome)
        try container.encode(acceptedCharacters, forKey: .acceptedCharacters)
        try container.encode(replacedCharactersWithin5Seconds, forKey: .replacedCharactersWithin5Seconds)
        try container.encodeIfPresent(nextActionMilliseconds, forKey: .nextActionMilliseconds)
        try container.encodeIfPresent(generatorMilliseconds, forKey: .generatorMilliseconds)
        try container.encodeIfPresent(firstStableWordMilliseconds, forKey: .firstStableWordMilliseconds)
        try container.encode(deadlineMissed, forKey: .deadlineMissed)
        try container.encodeIfPresent(confidence, forKey: .confidence)
        try container.encode(candidateCharacters, forKey: .candidateCharacters)
        try container.encode(championDisagreed, forKey: .championDisagreed)
        try container.encodeIfPresent(guardReason, forKey: .guardReason)
        try container.encode(crashed, forKey: .crashed)
        try container.encode(timedOut, forKey: .timedOut)
        try container.encode(opportunityCharacters, forKey: .opportunityCharacters)
        try container.encodeIfPresent(wrongInsertionCount, forKey: .wrongInsertionCount)
        try container.encodeIfPresent(insertionCorruptionCount, forKey: .insertionCorruptionCount)
        try container.encodeIfPresent(networkEgressDetected, forKey: .networkEgressDetected)
        try container.encodeIfPresent(networkDenied, forKey: .networkDenied)
        try container.encodeIfPresent(residentMemoryMegabytes, forKey: .residentMemoryMegabytes)
        try container.encodeIfPresent(memoryPressureObserved, forKey: .memoryPressureObserved)
        try container.encodeIfPresent(thermalLevel, forKey: .thermalLevel)
        try container.encodeIfPresent(runtimeRestarted, forKey: .runtimeRestarted)
        try container.encodeIfPresent(sleepWakeObserved, forKey: .sleepWakeObserved)
        try container.encodeIfPresent(appSwitchObserved, forKey: .appSwitchObserved)
        try container.encodeIfPresent(cacheHit, forKey: .cacheHit)
        try container.encodeIfPresent(confidenceFeatures, forKey: .confidenceFeatures)
        guard schema != Self.legacySchemaV2 else { return }
        try container.encode(generated, forKey: .generated)
        try container.encode(policyHidden, forKey: .policyHidden)
        try container.encode(candidateSourceBucket, forKey: .candidateSourceBucket)
        try container.encode(candidateLengthBucket, forKey: .candidateLengthBucket)
        try container.encodeIfPresent(settledVisibleMilliseconds, forKey: .settledVisibleMilliseconds)
        try container.encodeIfPresent(recentInterventionCount, forKey: .recentInterventionCount)
        try container.encode(retentionAt5Seconds, forKey: .retentionAt5Seconds)
        try container.encode(retentionAt30Seconds, forKey: .retentionAt30Seconds)
        try container.encode(retentionAtSegmentClose, forKey: .retentionAtSegmentClose)
    }
}

public struct LabAttentionTaxEstimate: Codable, Equatable, Sendable {
    public let matchedStrata: Int
    public let shownEvents: Int
    public let hiddenEvents: Int
    public let attentionTaxMilliseconds: Double?
}

public struct LabOnlineExperimentReport: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.online-report.v3"

    public let schema: String
    public let campaignID: UUID
    public let events: Int
    public let safeOpportunities: Int
    public let displayed: Int
    public let acceptedAll: Int
    public let acceptedWord: Int
    public let dismissed: Int
    public let undone: Int
    public let corrected: Int
    public let deadlineMissRate: Double
    public let acceptanceRateWhenShown: Double
    public let undoOrCorrectionRateWhenShown: Double
    public let netAcceptedCharacters: Int
    public let p95GeneratorMilliseconds: Int?
    public let p95FirstStableWordMilliseconds: Int?
    public let p99FirstStableWordMilliseconds: Int?
    public let attentionTax: LabAttentionTaxEstimate
    public let netTimeSavedMilliseconds: Double
    public let netTimeSavedPer1000Characters: Double
    public let failureReasonCounts: [String: Int]
    public let crashes: Int
    public let timeouts: Int
    public let wrongInsertions: Int
    public let insertionCorruptions: Int
    public let networkEgressViolations: Int
    public let maximumResidentMemoryMegabytes: Int?
    public let networkDeniedEvents: Int
    public let memoryPressureEvents: Int
    public let runtimeRestarts: Int
    public let sleepWakeCycles: Int
    public let appSwitches: Int
    public let cacheHits: Int
    public let cacheMisses: Int
    public let confidenceCalibration: LabConfidenceCalibrationReport?
    public let typedThrough: Int
    public let ignored: Int
    public let policyHidden: Int
    public let flickerAccepts: Int
    public let settledReads: Int
    public let retentionAt5Seconds: LabRetentionHorizonReport
    public let retentionAt30Seconds: LabRetentionHorizonReport
    public let retentionAtSegmentClose: LabRetentionHorizonReport
}

public struct LabSoakReport: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.soak-report.v1"

    public let schema: String
    public let campaignID: UUID
    public let observedDurationSeconds: Double
    public let requiredDurationSeconds: Double
    public let eventCount: Int
    public let requiredEventCount: Int
    public let operational: LabOnlineExperimentReport
    public let failures: [String]
    public let passed: Bool
}

public enum LabOnlineExperimentError: Error, LocalizedError, Equatable, Sendable {
    case unsupportedSchema
    case invalidPhase
    case invalidWindow
    case invalidArm
    case invalidAllocation
    case shadowMayNotDisplay
    case rampRequiresSafetyEvidence
    case invalidSoakRequirements
    case invalidEvent
    case ambiguousRetention
    case forbiddenKey(String)
    case mixedCampaign

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema: "The online experiment schema is unsupported."
        case .invalidPhase: "Online plans must be shadow, dogfood, or soak."
        case .invalidWindow: "Online plans must use a positive window no longer than 31 days."
        case .invalidArm: "Online champion and challenger identities are invalid."
        case .invalidAllocation: "Dogfood allocation must start above zero and may not exceed 50%."
        case .shadowMayNotDisplay: "A shadow challenger may never be displayed."
        case .rampRequiresSafetyEvidence:
            "A challenger allocation above 10% requires a frozen safety-evidence digest."
        case .invalidSoakRequirements:
            "Soak requires one frozen candidate, a safety digest, full allocation, and bounded duration/event requirements."
        case .invalidEvent: "The online event is invalid or contains an unsupported value."
        case .ambiguousRetention:
            "Each retention horizon must be either a kept-character count or a missingness reason, never both and never neither."
        case .forbiddenKey(let key): "Online events cannot store raw key \(key)."
        case .mixedCampaign: "Online analysis cannot mix campaign identifiers."
        }
    }
}

/// One arm's slice of the same aggregate report. Comparing arms is the whole
/// point of H01, so the slices are the same instrument, never a second one.
public struct LabOnlineArmReport: Codable, Equatable, Sendable {
    public let variant: LabOnlineVariant
    public let report: LabOnlineExperimentReport
}

public struct LabOnlineArmComparison: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.online-arm-comparison.v1"

    public let schema: String
    public let campaignID: UUID
    public let arms: [LabOnlineArmReport]
}

public enum LabOnlineExperimentAnalyzer {
    /// The pooled report, sliced by the event's own `variant` tag. Arms are
    /// returned in a stable order so two runs of the same database print the
    /// same table.
    public static func analyzeByArm(
        _ events: [LabOnlineExperimentEvent]
    ) throws -> LabOnlineArmComparison {
        guard let campaignID = events.first?.campaignID,
              events.allSatisfy({ $0.campaignID == campaignID }) else {
            throw LabOnlineExperimentError.mixedCampaign
        }
        var arms: [LabOnlineArmReport] = []
        for variant in [LabOnlineVariant.champion, .challenger, .hidden] {
            let slice = events.filter { $0.variant == variant }
            guard !slice.isEmpty else { continue }
            arms.append(LabOnlineArmReport(variant: variant, report: try analyze(slice)))
        }
        return LabOnlineArmComparison(
            schema: LabOnlineArmComparison.currentSchema,
            campaignID: campaignID,
            arms: arms
        )
    }

    public static func analyze(
        _ events: [LabOnlineExperimentEvent],
        typingCharactersPerSecond: Double = 5,
        acceptanceActionMilliseconds: Double = 90,
        correctionMillisecondsPerCharacter: Double = 80
    ) throws -> LabOnlineExperimentReport {
        guard let campaignID = events.first?.campaignID,
              events.allSatisfy({ $0.campaignID == campaignID }) else {
            throw LabOnlineExperimentError.mixedCampaign
        }
        let safe = events.filter(\.safeOpportunity)
        let shown = safe.filter(\.displayed)
        let acceptedAll = shown.count { $0.outcome == .acceptedAll }
        let acceptedWord = shown.count { $0.outcome == .acceptedWord }
        let corrected = shown.count { $0.outcome == .corrected }
        let undone = shown.count { $0.outcome == .undone }
        let acceptedCharacters = safe.reduce(0) { $0 + $1.acceptedCharacters }
        let replacedCharacters = safe.reduce(0) { $0 + $1.replacedCharactersWithin5Seconds }
        let netAccepted = max(0, acceptedCharacters - replacedCharacters)
        let attention = attentionTax(safe)
        let acceptedActions = acceptedAll + acceptedWord
        let grossSaved = Double(netAccepted) / max(0.5, typingCharactersPerSecond) * 1_000
        let actionCost = Double(acceptedActions) * max(0, acceptanceActionMilliseconds)
        let attentionCost = Double(shown.count) * max(0, attention.attentionTaxMilliseconds ?? 0)
        let correctionCost = Double(replacedCharacters) * max(0, correctionMillisecondsPerCharacter)
        let netTime = grossSaved - actionCost - attentionCost - correctionCost
        let characters = safe.reduce(0) { $0 + $1.opportunityCharacters }
        var failures: [String: Int] = [:]
        for event in safe {
            if let reason = event.guardReason { failures[reason.rawValue, default: 0] += 1 }
            if event.crashed { failures["crash", default: 0] += 1 }
            if event.timedOut { failures["timeout", default: 0] += 1 }
            if (event.wrongInsertionCount ?? 0) > 0 {
                failures["wrong-insertion", default: 0] += event.wrongInsertionCount ?? 0
            }
            if (event.insertionCorruptionCount ?? 0) > 0 {
                failures["insertion-corruption", default: 0] += event.insertionCorruptionCount ?? 0
            }
            if event.networkEgressDetected == true {
                failures["network-egress", default: 0] += 1
            }
        }
        return LabOnlineExperimentReport(
            schema: LabOnlineExperimentReport.currentSchema,
            campaignID: campaignID,
            events: events.count,
            safeOpportunities: safe.count,
            displayed: shown.count,
            acceptedAll: acceptedAll,
            acceptedWord: acceptedWord,
            dismissed: shown.count { $0.outcome == .dismissed },
            undone: undone,
            corrected: corrected,
            deadlineMissRate: rate(safe.count(where: \.deadlineMissed), safe.count),
            acceptanceRateWhenShown: rate(acceptedAll + acceptedWord, shown.count),
            undoOrCorrectionRateWhenShown: rate(undone + corrected, shown.count),
            netAcceptedCharacters: netAccepted,
            p95GeneratorMilliseconds: percentile(safe.compactMap(\.generatorMilliseconds)),
            p95FirstStableWordMilliseconds: percentile(safe.compactMap(\.firstStableWordMilliseconds)),
            p99FirstStableWordMilliseconds: percentile(
                safe.compactMap(\.firstStableWordMilliseconds), fraction: 0.99
            ),
            attentionTax: attention,
            netTimeSavedMilliseconds: netTime,
            netTimeSavedPer1000Characters: characters > 0
                ? netTime / Double(characters) * 1_000
                : 0,
            failureReasonCounts: failures,
            crashes: safe.count(where: \.crashed),
            timeouts: safe.count(where: \.timedOut),
            wrongInsertions: safe.reduce(0) { $0 + ($1.wrongInsertionCount ?? 0) },
            insertionCorruptions: safe.reduce(0) { $0 + ($1.insertionCorruptionCount ?? 0) },
            networkEgressViolations: safe.count { $0.networkEgressDetected == true },
            maximumResidentMemoryMegabytes: safe.compactMap(\.residentMemoryMegabytes).max(),
            networkDeniedEvents: safe.count { $0.networkDenied == true },
            memoryPressureEvents: safe.count { $0.memoryPressureObserved == true },
            runtimeRestarts: safe.count { $0.runtimeRestarted == true },
            sleepWakeCycles: safe.count { $0.sleepWakeObserved == true },
            appSwitches: safe.count { $0.appSwitchObserved == true },
            cacheHits: safe.count { $0.cacheHit == true },
            cacheMisses: safe.count { $0.cacheHit == false },
            confidenceCalibration: try? LabConfidenceCalibrator.calibrate(events),
            typedThrough: shown.count { $0.outcome == .typedThrough },
            ignored: shown.count { $0.outcome == .ignored },
            policyHidden: safe.count(where: \.policyHidden),
            flickerAccepts: shown.count {
                ($0.outcome == .acceptedAll || $0.outcome == .acceptedWord)
                    && !SettledVisibility.countsAsRead($0.settledVisibleMilliseconds)
            },
            settledReads: shown.count { SettledVisibility.countsAsRead($0.settledVisibleMilliseconds) },
            retentionAt5Seconds: LabRetentionAccounting.report(
                safe,
                horizon: \.retentionAt5Seconds,
                replacedAtHorizon: { $0.replacedCharactersWithin5Seconds }
            ),
            retentionAt30Seconds: LabRetentionAccounting.report(
                safe,
                horizon: \.retentionAt30Seconds
            ),
            retentionAtSegmentClose: LabRetentionAccounting.report(
                safe,
                horizon: \.retentionAtSegmentClose
            )
        )
    }

    public static func analyzeSoak(
        _ events: [LabOnlineExperimentEvent],
        plan: LabOnlineExperimentPlan
    ) throws -> LabSoakReport {
        try plan.validated()
        guard plan.phase == .soak,
              events.allSatisfy({ $0.campaignID == plan.campaignID }) else {
            throw LabOnlineExperimentError.invalidPhase
        }
        let operational = try analyze(events)
        let ordered = events.map(\.occurredAt).sorted()
        let duration = zip(ordered, ordered.dropFirst()).reduce(0.0) { total, pair in
            let gap = pair.1.timeIntervalSince(pair.0)
            return total + (gap <= 30 * 60 ? max(0, gap) : 0)
        }
        let requiredDuration = plan.minimumObservedDurationSeconds ?? 4 * 3_600
        let requiredEvents = plan.minimumEventCount ?? 100
        var failures: [String] = []
        if duration < requiredDuration { failures.append("insufficient-active-duration") }
        if events.count < requiredEvents { failures.append("insufficient-events") }
        if operational.crashes > 0 { failures.append("crash") }
        if operational.timeouts > 0 { failures.append("timeout") }
        if operational.wrongInsertions > 0 { failures.append("wrong-insertion") }
        if operational.insertionCorruptions > 0 { failures.append("insertion-corruption") }
        if operational.networkEgressViolations > 0 { failures.append("network-egress") }
        if operational.networkDeniedEvents == 0 { failures.append("network-denied-not-exercised") }
        if operational.memoryPressureEvents == 0 { failures.append("memory-pressure-not-exercised") }
        if operational.runtimeRestarts == 0 { failures.append("runtime-restart-not-exercised") }
        if operational.appSwitches == 0 { failures.append("app-switch-not-exercised") }
        if operational.cacheHits == 0 || operational.cacheMisses == 0 {
            failures.append("cache-churn-not-exercised")
        }
        if requiredDuration >= 8 * 3_600, operational.sleepWakeCycles == 0 {
            failures.append("sleep-wake-not-exercised")
        }
        if (operational.p99FirstStableWordMilliseconds ?? Int.max) > 1_000 {
            failures.append("p99-first-stable-word")
        }
        return LabSoakReport(
            schema: LabSoakReport.currentSchema,
            campaignID: plan.campaignID,
            observedDurationSeconds: duration,
            requiredDurationSeconds: requiredDuration,
            eventCount: events.count,
            requiredEventCount: requiredEvents,
            operational: operational,
            failures: failures,
            passed: failures.isEmpty
        )
    }

    private static func attentionTax(
        _ events: [LabOnlineExperimentEvent]
    ) -> LabAttentionTaxEstimate {
        let timed = events.filter { $0.nextActionMilliseconds != nil }
        let strata = Dictionary(grouping: timed) { event in
            AttentionStratum(
                app: event.appCategory,
                register: event.register,
                boundary: event.boundary,
                speed: event.typingSpeedBucket,
                confidenceDecile: event.confidence.map { min(9, max(0, Int($0 * 10))) } ?? -1
            )
        }
        var differences: [(difference: Double, weight: Int)] = []
        var shownCount = 0
        var hiddenCount = 0
        for values in strata.values {
            let shown = values.filter(\.displayed).compactMap(\.nextActionMilliseconds)
            let hidden = values.filter { !$0.displayed }.compactMap(\.nextActionMilliseconds)
            guard !shown.isEmpty, !hidden.isEmpty else { continue }
            shownCount += shown.count
            hiddenCount += hidden.count
            let shownMean = Double(shown.reduce(0, +)) / Double(shown.count)
            let hiddenMean = Double(hidden.reduce(0, +)) / Double(hidden.count)
            differences.append((shownMean - hiddenMean, min(shown.count, hidden.count)))
        }
        let totalWeight = differences.reduce(0) { $0 + $1.weight }
        let estimate = totalWeight > 0
            ? differences.reduce(0) { $0 + $1.difference * Double($1.weight) } / Double(totalWeight)
            : nil
        return LabAttentionTaxEstimate(
            matchedStrata: differences.count,
            shownEvents: shownCount,
            hiddenEvents: hiddenCount,
            attentionTaxMilliseconds: estimate
        )
    }

    private static func percentile(_ values: [Int], fraction: Double = 0.95) -> Int? {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return nil }
        return sorted[min(
            sorted.count - 1,
            Int((Double(sorted.count - 1) * min(1, max(0, fraction))).rounded())
        )]
    }

    private static func rate(_ numerator: Int, _ denominator: Int) -> Double {
        denominator > 0 ? Double(numerator) / Double(denominator) : 0
    }

    private struct AttentionStratum: Hashable {
        let app: LabOnlineAppCategory
        let register: LabOnlineRegister
        let boundary: LabOnlineBoundary
        let speed: LabTypingSpeedBucket
        let confidenceDecile: Int
    }
}
