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

/// The socket a decision layer plugs into. Stage 1 ships a frozen heuristic
/// and an external-command shim; a cheap frontier model can later stand behind
/// the same method without touching the keystroke driver.
public protocol TypistDecisionPolicy: Sendable {
    /// Stable, aggregate-safe label recorded in the simulated report.
    var identifier: String { get }

    func decide(_ features: LabTypistMomentFeatures) throws -> LabTypistDecision
}

public enum LabTypistPolicyError: Error, LocalizedError, Equatable, Sendable {
    case invalidFeaturePayload
    case invalidDecisionPayload
    case forbiddenKey(String)
    case decisionCommandUnavailable(String)
    case decisionCommandFailed(Int32)

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
        }
    }
}
