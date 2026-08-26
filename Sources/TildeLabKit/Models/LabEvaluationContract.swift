import Foundation

/// The immutable product contract campaigns optimize. A campaign may mutate
/// Tilde's behavior, but never these definitions or thresholds.
public enum LabGoalContract {
    public static let identifier = "net-keystrokes-v1"
    public static let mission = "Save the user's actual keystrokes without getting in their way."

    public static let acceptanceKeystrokes = 1
    public static let dismissalKeystrokes = 1
    public static let maximumBadSuggestionRate = 0.01
    public static let requiredSensitiveRestraintRate = 1.0
    public static let maximumP95LatencyMilliseconds = 1_000
}

public enum LabScenarioSource: String, Codable, CaseIterable, Sendable {
    case synthetic
    case handCurated = "hand-curated"
    case publicCorpus = "public-corpus"
    case historicalAccepted = "historical-accepted"
    case historicalTypedInstead = "historical-typed-instead"

    public var isHistorical: Bool {
        self == .historicalAccepted || self == .historicalTypedInstead
    }
}

/// The point in the user's real continuation at which the model is replayed.
public enum LabReplayCheckpoint: String, Codable, CaseIterable, Sendable {
    case caret
    case firstCharacter = "first-character"
    case firstWord = "first-word"
    case twoWords = "two-words"
    case threeWords = "three-words"
    case midSentence = "mid-sentence"
    case nearEnd = "near-end"
}

/// Context-ablation ladder. The value is recorded per case so aggregate
/// reports can say which source actually created the improvement.
public enum LabContextVariant: String, Codable, CaseIterable, Sendable {
    case typedOnly = "typed-only"
    case appMetadata = "app-metadata"
    case accessibility
    case OCR = "ocr"
    case structuredThread = "structured-thread"
    case personalized
    case recordedScreen = "recorded-screen"
}

/// Raw evidence remains only in the in-memory suite. Run reports retain the
/// variant and opaque scenario ID, never these strings.
public struct LabContextEvidence: Codable, Equatable, Sendable {
    public let accessibilityText: String?
    public let OCRText: String?
    public let recordedScreenText: String?
    public let personalStyleHint: String?

    public init(
        accessibilityText: String? = nil,
        OCRText: String? = nil,
        recordedScreenText: String? = nil,
        personalStyleHint: String? = nil
    ) {
        self.accessibilityText = accessibilityText
        self.OCRText = OCRText
        self.recordedScreenText = recordedScreenText
        self.personalStyleHint = personalStyleHint
    }

    var allTextCount: Int {
        (accessibilityText?.count ?? 0)
            + (OCRText?.count ?? 0)
            + (recordedScreenText?.count ?? 0)
            + (personalStyleHint?.count ?? 0)
    }
}

/// A historical case is eligible for protected validation only when every
/// temporal statement can be proven. Unknown is not silently treated as true.
public struct LabTemporalIntegrity: Codable, Equatable, Sendable {
    public let containsNoFutureCharacters: Bool
    public let contextWasContemporaneous: Bool
    public let correctWindowAndThread: Bool
    public let noStaleSnapshot: Bool
    public let targetWasCorrect: Bool
    public let activeFieldWasReconciled: Bool

    public init(
        containsNoFutureCharacters: Bool,
        contextWasContemporaneous: Bool,
        correctWindowAndThread: Bool = true,
        noStaleSnapshot: Bool = true,
        targetWasCorrect: Bool,
        activeFieldWasReconciled: Bool
    ) {
        self.containsNoFutureCharacters = containsNoFutureCharacters
        self.contextWasContemporaneous = contextWasContemporaneous
        self.correctWindowAndThread = correctWindowAndThread
        self.noStaleSnapshot = noStaleSnapshot
        self.targetWasCorrect = targetWasCorrect
        self.activeFieldWasReconciled = activeFieldWasReconciled
    }

    public static let verified = LabTemporalIntegrity(
        containsNoFutureCharacters: true,
        contextWasContemporaneous: true,
        correctWindowAndThread: true,
        noStaleSnapshot: true,
        targetWasCorrect: true,
        activeFieldWasReconciled: true
    )

    public static let unverifiedHistorical = LabTemporalIntegrity(
        containsNoFutureCharacters: true,
        contextWasContemporaneous: false,
        correctWindowAndThread: false,
        noStaleSnapshot: false,
        targetWasCorrect: false,
        activeFieldWasReconciled: true
    )

    public var passed: Bool {
        containsNoFutureCharacters
            && contextWasContemporaneous
            && correctWindowAndThread
            && noStaleSnapshot
            && targetWasCorrect
            && activeFieldWasReconciled
    }

    private enum CodingKeys: String, CodingKey {
        case containsNoFutureCharacters, contextWasContemporaneous
        case correctWindowAndThread, noStaleSnapshot
        case targetWasCorrect, activeFieldWasReconciled
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        containsNoFutureCharacters = try values.decode(
            Bool.self,
            forKey: .containsNoFutureCharacters
        )
        contextWasContemporaneous = try values.decode(Bool.self, forKey: .contextWasContemporaneous)
        correctWindowAndThread = try values.decodeIfPresent(
            Bool.self,
            forKey: .correctWindowAndThread
        ) ?? true
        noStaleSnapshot = try values.decodeIfPresent(Bool.self, forKey: .noStaleSnapshot) ?? true
        targetWasCorrect = try values.decode(Bool.self, forKey: .targetWasCorrect)
        activeFieldWasReconciled = try values.decode(Bool.self, forKey: .activeFieldWasReconciled)
    }
}

public struct LabEvaluationMetadata: Codable, Equatable, Sendable {
    public let source: LabScenarioSource
    public let checkpoint: LabReplayCheckpoint
    public let contextVariant: LabContextVariant
    public let temporalIntegrity: LabTemporalIntegrity
    public let evidence: LabContextEvidence
    /// Stable, non-text identifiers used to distinguish one underlying writing
    /// situation from its checkpoints, context variants, and repetitions.
    public let corpusID: String?
    public let rootScenarioID: String?
    public let correctionKeystrokes: Int
    public let dismissalKeystrokes: Int

    public init(
        source: LabScenarioSource = .synthetic,
        checkpoint: LabReplayCheckpoint = .caret,
        contextVariant: LabContextVariant = .structuredThread,
        temporalIntegrity: LabTemporalIntegrity = .verified,
        evidence: LabContextEvidence = .init(),
        corpusID: String? = nil,
        rootScenarioID: String? = nil,
        correctionKeystrokes: Int = 0,
        dismissalKeystrokes: Int = LabGoalContract.dismissalKeystrokes
    ) {
        self.source = source
        self.checkpoint = checkpoint
        self.contextVariant = contextVariant
        self.temporalIntegrity = temporalIntegrity
        self.evidence = evidence
        self.corpusID = corpusID
        self.rootScenarioID = rootScenarioID
        self.correctionKeystrokes = max(0, correctionKeystrokes)
        self.dismissalKeystrokes = max(0, dismissalKeystrokes)
    }
}

public enum LabFailureCategory: String, Codable, CaseIterable, Sendable {
    case none
    case capture
    case extraction
    case sceneAttribution = "scene-attribution"
    case intent
    case wording
    case display
    case length
    case timing
    case interaction
}

public enum LabGateStatus: String, Codable, Sendable {
    case pass
    case fail
    case notRun = "not-run"
}

public struct LabGateSummary: Codable, Equatable, Sendable {
    public let badSuggestions: LabGateStatus
    public let sensitiveSituations: LabGateStatus
    public let temporalIntegrity: LabGateStatus
    public let latency: LabGateStatus
    public let interactionIntegrity: LabGateStatus
    public let privacy: LabGateStatus

    public init(
        badSuggestions: LabGateStatus,
        sensitiveSituations: LabGateStatus,
        temporalIntegrity: LabGateStatus,
        latency: LabGateStatus,
        interactionIntegrity: LabGateStatus = .notRun,
        privacy: LabGateStatus = .pass
    ) {
        self.badSuggestions = badSuggestions
        self.sensitiveSituations = sensitiveSituations
        self.temporalIntegrity = temporalIntegrity
        self.latency = latency
        self.interactionIntegrity = interactionIntegrity
        self.privacy = privacy
    }

    public var researchEligible: Bool {
        badSuggestions == .pass
            && sensitiveSituations == .pass
            && temporalIntegrity == .pass
            && latency == .pass
            && privacy == .pass
    }

    public var releaseEligible: Bool {
        researchEligible && interactionIntegrity == .pass
    }
}
