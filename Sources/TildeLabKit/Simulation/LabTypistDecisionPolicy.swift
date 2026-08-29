import Foundation

/// How the offered candidate relates to the writer's remaining intended text.
/// The simulator knows the golden continuation; the decision policy is told
/// only which of these three shapes it has, never the characters themselves.
public enum LabTypistPrefixMatch: String, Codable, CaseIterable, Sendable {
    /// Every visible character continues the writer's intended text.
    case exact
    /// The opening word agrees and the rest diverges.
    case partial
    /// Nothing the writer intended to type next.
    case divergent
}

public enum LabTypistAction: String, Codable, CaseIterable, Sendable {
    /// Take the whole visible candidate.
    case accept
    /// Take only the first visible word.
    case acceptWord = "accept-word"
    /// Keep typing and leave the ghost alone.
    case continueTyping = "continue"
    /// Actively clear the ghost.
    case dismiss
}

/// The text-free feature object handed to a decision policy at one display.
///
/// The schema itself is the privacy boundary: every field is a bucket, a
/// boolean, or a count. There is no field that can carry scenario text, a
/// prompt, or a candidate, and `validateJSON` rejects any key that is not on
/// the allowlist, so an external policy can never be fed writing.
public struct LabTypistMomentFeatures: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.typist-moment-features.v1"

    public static let allowedKeys: Set<String> = [
        "schema", "personaGoal", "personaRegister", "personaTypingSpeed",
        "personaInterruptionTolerance", "boundary", "candidateLengthBucket",
        "candidateCharacterCount", "candidateWordCount", "prefixMatch",
        "matchedPrefixCharacters", "typedCharacters", "remainingCharacters",
        "displaysSoFar", "dismissalsSoFar", "millisecondsSinceDisplay",
        "generationMilliseconds", "meanTokenProbabilityBucket",
    ]

    public let schema: String
    public let personaGoal: LabTypistGoal
    public let personaRegister: LabOnlineRegister
    public let personaTypingSpeed: LabTypingSpeedBucket
    public let personaInterruptionTolerance: LabTypistInterruptionTolerance
    public let boundary: LabOnlineBoundary
    public let candidateLengthBucket: LabCandidateLengthBucket
    public let candidateCharacterCount: Int
    public let candidateWordCount: Int
    public let prefixMatch: LabTypistPrefixMatch
    public let matchedPrefixCharacters: Int
    public let typedCharacters: Int
    public let remainingCharacters: Int
    public let displaysSoFar: Int
    public let dismissalsSoFar: Int
    public let millisecondsSinceDisplay: Int
    public let generationMilliseconds: Int
    public let meanTokenProbabilityBucket: LabTypistConfidenceBucket

    public init(
        schema: String = Self.currentSchema,
        personaGoal: LabTypistGoal,
        personaRegister: LabOnlineRegister,
        personaTypingSpeed: LabTypingSpeedBucket,
        personaInterruptionTolerance: LabTypistInterruptionTolerance,
        boundary: LabOnlineBoundary,
        candidateLengthBucket: LabCandidateLengthBucket,
        candidateCharacterCount: Int,
        candidateWordCount: Int,
        prefixMatch: LabTypistPrefixMatch,
        matchedPrefixCharacters: Int,
        typedCharacters: Int,
        remainingCharacters: Int,
        displaysSoFar: Int,
        dismissalsSoFar: Int,
        millisecondsSinceDisplay: Int,
        generationMilliseconds: Int,
        meanTokenProbabilityBucket: LabTypistConfidenceBucket
    ) {
        self.schema = schema
        self.personaGoal = personaGoal
        self.personaRegister = personaRegister
        self.personaTypingSpeed = personaTypingSpeed
        self.personaInterruptionTolerance = personaInterruptionTolerance
        self.boundary = boundary
        self.candidateLengthBucket = candidateLengthBucket
        self.candidateCharacterCount = candidateCharacterCount
        self.candidateWordCount = candidateWordCount
        self.prefixMatch = prefixMatch
        self.matchedPrefixCharacters = matchedPrefixCharacters
        self.typedCharacters = typedCharacters
        self.remainingCharacters = remainingCharacters
        self.displaysSoFar = displaysSoFar
        self.dismissalsSoFar = dismissalsSoFar
        self.millisecondsSinceDisplay = millisecondsSinceDisplay
        self.generationMilliseconds = generationMilliseconds
        self.meanTokenProbabilityBucket = meanTokenProbabilityBucket
    }

    /// Rejects a payload that carries any key outside the text-free allowlist,
    /// or any string value long enough to smuggle writing.
    public static func validateJSON(_ data: Data) throws {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LabTypistPolicyError.invalidFeaturePayload
        }
        if let key = Set(object.keys).subtracting(allowedKeys).sorted().first {
            throw LabTypistPolicyError.forbiddenKey(key)
        }
        guard object["schema"] as? String == currentSchema else {
            throw LabTypistPolicyError.invalidFeaturePayload
        }
        for (key, value) in object {
            if let text = value as? String, text.count > 64 {
                throw LabTypistPolicyError.forbiddenKey(key)
            }
            if value is [Any] || (value is [String: Any] && key != "schema") {
                throw LabTypistPolicyError.forbiddenKey(key)
            }
        }
    }

    public func encodedJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        try Self.validateJSON(data)
        return data
    }
}

/// Confidence is reported as a bucket so a policy can weigh it without ever
/// seeing a per-token distribution.
public enum LabTypistConfidenceBucket: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high
    case unknown

    public static func from(meanTokenProbability: Double?) -> LabTypistConfidenceBucket {
        guard let meanTokenProbability, meanTokenProbability.isFinite else { return .unknown }
        switch meanTokenProbability {
        case ..<0.35: return .low
        case ..<0.65: return .medium
        default: return .high
        }
    }
}

/// One simulated decision: what the writer does with the ghost, plus whether
/// the accepted characters would still be there when they re-read the line.
public struct LabTypistDecision: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.typist-decision.v1"

    public static let allowedKeys: Set<String> = ["schema", "action", "wouldRetain"]

    public let schema: String
    public let action: LabTypistAction
    public let wouldRetain: Bool

    public init(
        schema: String = Self.currentSchema,
        action: LabTypistAction,
        wouldRetain: Bool
    ) {
        self.schema = schema
        self.action = action
        self.wouldRetain = wouldRetain
    }

    public static func validateJSON(_ data: Data) throws {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LabTypistPolicyError.invalidDecisionPayload
        }
        if let key = Set(object.keys).subtracting(allowedKeys).sorted().first {
            throw LabTypistPolicyError.forbiddenKey(key)
        }
        guard object["schema"] as? String == currentSchema,
              let action = object["action"] as? String,
              LabTypistAction(rawValue: action) != nil,
              object["wouldRetain"] is Bool else {
            throw LabTypistPolicyError.invalidDecisionPayload
        }
    }

    public static func decode(_ data: Data) throws -> LabTypistDecision {
        try validateJSON(data)
        return try JSONDecoder().decode(LabTypistDecision.self, from: data)
    }
}

/// A batch of moments handed to a decision policy in one call.
///
/// The envelope adds nothing but a schema and an ordered array: every element
/// is validated by the same text-free feature allowlist as the single-moment
/// contract, so batching cannot widen what may cross the boundary.
public struct LabTypistMomentBatch: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.typist-moment-batch.v1"

    public static let allowedKeys: Set<String> = ["schema", "moments"]

    /// One process invocation may not be asked to hold more moments than this.
    /// A bigger batch buys nothing and makes a single command failure cost more
    /// re-work than it saves.
    public static let maximumSize = 100

    public let schema: String
    public let moments: [LabTypistMomentFeatures]

    public init(
        schema: String = Self.currentSchema,
        moments: [LabTypistMomentFeatures]
    ) {
        self.schema = schema
        self.moments = moments
    }

    /// Rejects any envelope key outside the allowlist, any batch outside
    /// 1...`maximumSize`, and any element that is not a text-free v1 feature
    /// object — each element is re-serialized and run through the single-moment
    /// validator, so a text-bearing key anywhere in the batch fails the batch.
    public static func validateJSON(_ data: Data) throws {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LabTypistPolicyError.invalidFeaturePayload
        }
        if let key = Set(object.keys).subtracting(allowedKeys).sorted().first {
            throw LabTypistPolicyError.forbiddenKey(key)
        }
        guard object["schema"] as? String == currentSchema,
              let moments = object["moments"] as? [Any] else {
            throw LabTypistPolicyError.invalidFeaturePayload
        }
        guard (1...maximumSize).contains(moments.count) else {
            throw LabTypistPolicyError.batchSizeOutOfRange(moments.count)
        }
        for moment in moments {
            guard let element = moment as? [String: Any] else {
                throw LabTypistPolicyError.invalidFeaturePayload
            }
            try LabTypistMomentFeatures.validateJSON(
                try JSONSerialization.data(withJSONObject: element)
            )
        }
    }

    public func encodedJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        try Self.validateJSON(data)
        return data
    }
}

/// The answer to a `LabTypistMomentBatch`: the same number of decisions, in the
/// same order as the moments that produced them. There is no identifier to
/// correlate on — a text-free contract has nothing safe to key by — so position
/// *is* the correlation, and a short, long, or reordered answer is an error
/// rather than something the engine silently repairs.
public struct LabTypistDecisionBatch: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.typist-decision-batch.v1"

    public static let allowedKeys: Set<String> = ["schema", "decisions"]

    public let schema: String
    public let decisions: [LabTypistDecision]

    public init(
        schema: String = Self.currentSchema,
        decisions: [LabTypistDecision]
    ) {
        self.schema = schema
        self.decisions = decisions
    }

    /// `expectedCount` is the number of moments sent. A mismatch is fatal: the
    /// engine cannot know which moment a missing or extra decision belongs to.
    public static func validateJSON(_ data: Data, expectedCount: Int) throws {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LabTypistPolicyError.invalidDecisionPayload
        }
        if let key = Set(object.keys).subtracting(allowedKeys).sorted().first {
            throw LabTypistPolicyError.forbiddenKey(key)
        }
        guard object["schema"] as? String == currentSchema,
              let decisions = object["decisions"] as? [Any] else {
            throw LabTypistPolicyError.invalidDecisionPayload
        }
        guard decisions.count == expectedCount else {
            throw LabTypistPolicyError.batchCountMismatch(
                expected: expectedCount, received: decisions.count
            )
        }
        for decision in decisions {
            guard let element = decision as? [String: Any] else {
                throw LabTypistPolicyError.invalidDecisionPayload
            }
            try LabTypistDecision.validateJSON(
                try JSONSerialization.data(withJSONObject: element)
            )
        }
    }

    public static func decode(_ data: Data, expectedCount: Int) throws -> [LabTypistDecision] {
        try validateJSON(data, expectedCount: expectedCount)
        return try JSONDecoder().decode(LabTypistDecisionBatch.self, from: data).decisions
    }
}

/// The socket a decision layer plugs into. Stage 1 ships a frozen heuristic
/// and an external-command shim; a cheap frontier model can later stand behind
/// the same method without touching the keystroke driver.
public protocol TypistDecisionPolicy: Sendable {
    /// Stable, aggregate-safe label recorded in the simulated report.
    var identifier: String { get }

    /// How many decision-independent moments this policy will take in one call.
    /// The default is 1: one moment, one answer, today's behavior.
    var decisionBatchSize: Int { get }

    func decide(_ features: LabTypistMomentFeatures) throws -> LabTypistDecision

    /// Decides a batch of moments the engine has proven independent of one
    /// another. Implementations must answer in the same order, one decision per
    /// moment.
    func decide(batch: [LabTypistMomentFeatures]) throws -> [LabTypistDecision]
}

public extension TypistDecisionPolicy {
    var decisionBatchSize: Int { 1 }

    /// A policy that has no batch backend still satisfies the batch method by
    /// answering each moment on its own, in order.
    func decide(batch: [LabTypistMomentFeatures]) throws -> [LabTypistDecision] {
        try batch.map { try decide($0) }
    }
}

public enum LabTypistPolicyError: Error, LocalizedError, Equatable, Sendable {
    case invalidFeaturePayload
    case invalidDecisionPayload
    case forbiddenKey(String)
    case decisionCommandUnavailable(String)
    case decisionCommandFailed(Int32)
    case batchSizeOutOfRange(Int)
    case batchCountMismatch(expected: Int, received: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidFeaturePayload:
            "The typist feature payload is not a text-free v1 feature object."
        case .invalidDecisionPayload:
            "The typist decision payload is not a text-free v1 decision object."
        case let .forbiddenKey(key):
            "The typist decision contract forbids key \(key); only buckets, booleans, and counts may cross it."
        case let .decisionCommandUnavailable(path):
            "The external decision command is not an executable owner-controlled file: \(path)."
        case let .decisionCommandFailed(status):
            "The external decision command exited with status \(status)."
        case let .batchSizeOutOfRange(size):
            "A typist moment batch must hold 1...\(LabTypistMomentBatch.maximumSize) moments, not \(size)."
        case let .batchCountMismatch(expected, received):
            "The typist decision batch answered \(received) of \(expected) moments; decisions must match the moments one for one, in order."
        }
    }
}
