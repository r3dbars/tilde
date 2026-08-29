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
        candidateSourceBucket: String = "unknown",
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
