import CryptoKit
import Foundation

/// Production-side v3 online event. Same schema Lab ingests. IME and App
/// encode this; they never import Tilde Lab.
public struct TextFreeOnlineEvent: Codable, Equatable, Sendable {
    public static let schema = "tilde-lab.online-event.v3"
    /// Public instrument campaign. Not a secret. `tilde-lab --instrument` uses it.
    public static let instrumentCampaignID = UUID(
        uuidString: "f03e0000-4c3d-41a1-8b00-000000000003"
    )!

    public let schema: String
    public let id: UUID
    public let campaignID: UUID
    public let occurredAt: Date
    public let sessionDigestSHA256: String
    public let variant: String
    public let appCategory: String
    public let register: String
    public let boundary: String
    public let typingSpeedBucket: String
    public let safeOpportunity: Bool
    public let generated: Bool
    public let displayed: Bool
    public let policyHidden: Bool
    public let outcome: String
    public let acceptedCharacters: Int
    public let replacedCharactersWithin5Seconds: Int
    public let nextActionMilliseconds: Int?
    public let settledVisibleMilliseconds: Int?
    public let deadlineMissed: Bool
    public let candidateCharacters: Int
    public let candidateSourceBucket: String
    public let candidateLengthBucket: String
    public let championDisagreed: Bool
    public let crashed: Bool
    public let timedOut: Bool
    public let opportunityCharacters: Int
    public let retentionAt5Seconds: RetainedCharacterObservation
    public let retentionAt30Seconds: RetainedCharacterObservation
    public let retentionAtSegmentClose: RetainedCharacterObservation

    public init(
        id: UUID = UUID(),
        campaignID: UUID = TextFreeOnlineEvent.instrumentCampaignID,
        occurredAt: Date,
        sessionDigestSHA256: String,
        variant: String = "champion",
        appCategory: String,
        register: String,
        boundary: String,
        typingSpeedBucket: String = "unknown",
        safeOpportunity: Bool,
        generated: Bool,
        displayed: Bool,
        policyHidden: Bool = false,
        outcome: String,
        acceptedCharacters: Int,
        replacedCharactersWithin5Seconds: Int = 0,
        nextActionMilliseconds: Int? = nil,
        settledVisibleMilliseconds: Int? = nil,
        deadlineMissed: Bool = false,
        candidateCharacters: Int,
        candidateSourceBucket: String,
        candidateLengthBucket: String,
        championDisagreed: Bool = false,
        crashed: Bool = false,
        timedOut: Bool = false,
        opportunityCharacters: Int,
        retentionAt5Seconds: RetainedCharacterObservation,
        retentionAt30Seconds: RetainedCharacterObservation,
        retentionAtSegmentClose: RetainedCharacterObservation
    ) {
        self.schema = Self.schema
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
        self.generated = generated
        self.displayed = displayed
        self.policyHidden = policyHidden
        self.outcome = outcome
        self.acceptedCharacters = acceptedCharacters
        self.replacedCharactersWithin5Seconds = replacedCharactersWithin5Seconds
        self.nextActionMilliseconds = nextActionMilliseconds
        self.settledVisibleMilliseconds = settledVisibleMilliseconds
        self.deadlineMissed = deadlineMissed
        self.candidateCharacters = candidateCharacters
        self.candidateSourceBucket = candidateSourceBucket
        self.candidateLengthBucket = candidateLengthBucket
        self.championDisagreed = championDisagreed
        self.crashed = crashed
        self.timedOut = timedOut
        self.opportunityCharacters = opportunityCharacters
        self.retentionAt5Seconds = retentionAt5Seconds
        self.retentionAt30Seconds = retentionAt30Seconds
        self.retentionAtSegmentClose = retentionAtSegmentClose
    }

    /// Every key this event can write, and therefore every key a production
    /// event line may carry. Lab ingest of the live ledger checks lines
    /// against this set, so the production DTO is the one definition of
    /// what production emitted: a Lab-only field can never appear in a live
    /// line, and a new production field cannot ship without appearing here.
    public static let allowedKeys: Set<String> = [
        "schema", "id", "campaignID", "occurredAt", "sessionDigestSHA256", "variant",
        "appCategory", "register", "boundary", "typingSpeedBucket", "safeOpportunity",
        "generated", "displayed", "policyHidden", "outcome",
        "acceptedCharacters", "replacedCharactersWithin5Seconds",
        "nextActionMilliseconds", "settledVisibleMilliseconds", "deadlineMissed",
        "candidateCharacters", "candidateSourceBucket", "candidateLengthBucket",
        "championDisagreed", "crashed", "timedOut", "opportunityCharacters",
        "retentionAt5Seconds", "retentionAt30Seconds", "retentionAtSegmentClose",
    ]

    /// Decodes one live ledger line strictly: v3 schema only, no key outside
    /// `allowedKeys`, dates in ISO 8601.
    public static func decodeProductionLine(_ data: Data) throws -> TextFreeOnlineEvent {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TextFreeOnlineEventError.malformedLine
        }
        if let key = Set(object.keys).subtracting(allowedKeys).sorted().first {
            throw TextFreeOnlineEventError.unexpectedKey(key)
        }
        guard object["schema"] as? String == schema else {
            throw TextFreeOnlineEventError.unsupportedSchema
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TextFreeOnlineEvent.self, from: data)
    }

    public static func sessionDigest(sessionIdentifier: String) -> String {
        SHA256.hash(data: Data(sessionIdentifier.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    public static func encodeJSONL(_ event: TextFreeOnlineEvent) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        var data = try encoder.encode(event)
        data.append(0x0A)
        return data
    }
}

public enum TextFreeOnlineEventError: Error, Equatable, Sendable {
    case malformedLine
    case unexpectedKey(String)
    case unsupportedSchema
}

/// Where the visible candidate came from. A fixed vocabulary so a report can
/// separate a dictionary suffix from a model phrase and the personal layer's
/// contribution from the base model's. New events always name one; only an
/// event written before the field existed may read `unknown-legacy`.
public enum TextFreeCandidateSource: String, Codable, CaseIterable, Sendable {
    /// `NSSpellChecker` word completion inside a partial word; no model ran.
    case dictionary
    /// The app-owned local model alone.
    case baseModel = "base-model"
    /// Personal History replaced the base prefix.
    case personal
    /// Personal History and the base model agreed on the prefix.
    case basePersonalAgreement = "base-personal-agreement"
    /// Written before the source travelled on the wire.
    case unknownLegacy = "unknown-legacy"

    /// The app's arbitration outcome, or `nil` when personal serving was off
    /// and the base model answered alone.
    public init(personal: PersonalSuggestionSource?) {
        switch personal {
        case .none, .base: self = .baseModel
        case .personal: self = .personal
        case .agreed: self = .basePersonalAgreement
        }
    }
}

/// Path computation only. Callers own create/append/delete.
/// Lives in its own 0700 directory so App delete can unlink it safely.
public enum TextFreeOnlineEventFile {
    public static let directoryName = "Outcome Ledger"
    public static let fileName = "events.jsonl"

    public static func url(homeDirectory: URL, supportDirectoryName: String) -> URL {
        homeDirectory
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(supportDirectoryName, isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName)
    }
}

public enum TextFreeCursorBoundary: String, Sendable {
    case midWord = "mid-word"
    case wordBoundary = "word-boundary"
    case sentenceBoundary = "sentence-boundary"

    public static func from(precedingCharacter: Character?) -> TextFreeCursorBoundary {
        guard let precedingCharacter else { return .wordBoundary }
        if ".!?".contains(precedingCharacter) { return .sentenceBoundary }
        if precedingCharacter.isWhitespace { return .wordBoundary }
        return .midWord
    }
}

public enum TextFreeLengthBucket: String, Sendable {
    case oneWord = "one-word"
    case twoToThree = "two-to-three"
    case fourToSeven = "four-to-seven"
    case eightPlus = "eight-plus"
    case unknown

    public static func from(wordCount: Int?) -> TextFreeLengthBucket {
        guard let wordCount, wordCount > 0 else { return .unknown }
        switch wordCount {
        case 1: return .oneWord
        case 2...3: return .twoToThree
        case 4...7: return .fourToSeven
        default: return .eightPlus
        }
    }
}

public enum TextFreeAppCategory: String, Sendable {
    case chat
    case email
    case prose
    case other

    public static func from(register: ContinuationRegister) -> TextFreeAppCategory {
        switch register {
        case .chat: return .chat
        case .email: return .email
        case .prose: return .prose
        }
    }
}
