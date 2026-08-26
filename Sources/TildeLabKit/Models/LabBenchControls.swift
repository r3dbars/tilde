import Foundation

public enum LabBenchKind: String, LabNamedOption {
    case reply
    case judgment
    case sceneMemory = "scene-memory"
    case personalization
    case interaction
    case performance

    public var title: String {
        switch self {
        case .reply: "Reply Quality"
        case .judgment: "Judgment"
        case .sceneMemory: "Scene Memory"
        case .personalization: "Personalization"
        case .interaction: "Interaction"
        case .performance: "Performance"
        }
    }

    public var systemImage: String {
        switch self {
        case .reply: "bubble.left.and.text.bubble.right"
        case .judgment: "checkmark.seal"
        case .sceneMemory: "rectangle.inset.filled.and.person.filled"
        case .personalization: "person.crop.circle.badge.checkmark"
        case .interaction: "keyboard"
        case .performance: "gauge.with.dots.needle.67percent"
        }
    }
}

public enum LabCaptureSource: String, LabNamedOption {
    case automatic
    case accessibility
    case ocr

    public var title: String {
        switch self {
        case .automatic: "AX then OCR"
        case .accessibility: "Accessibility only"
        case .ocr: "OCR only"
        }
    }
}

public enum LabOCRRecognitionMode: String, LabNamedOption {
    case fast
    case accurate

    public var title: String { rawValue.capitalized }
}

public struct LabSceneBenchConfiguration: Codable, Equatable, Sendable {
    public var captureSource: LabCaptureSource
    public var recognitionMode: LabOCRRecognitionMode
    public var usesLanguageCorrection: Bool
    public var freshnessSeconds: Double
    public var maximumTurns: Int
    public var maximumTurnCharacters: Int
    public var maximumReferenceCharacters: Int
    public var bubbleMinimumWidth: Double
    public var bubbleMaximumWidth: Double
    public var verticalBandCount: Int
    public var selfSpeakerMinimumX: Double
    public var otherSpeakerMaximumX: Double
    public var wrappedLineGapRatio: Double
    public var rareReferenceMinimumLength: Int
    public var dedupeMinimumLength: Int
    public var typingPauseSeconds: Double
    public var cadenceSeconds: Double
    public var changeCadenceFloorSeconds: Double
    public var activityWindowSeconds: Double
    public var gridWidth: Int
    public var gridHeight: Int
    public var tileChangeThreshold: Double
    public var fullFrameChangeFraction: Double
    public var regionPaddingTiles: Int
    public var injectsOCRNoise: Bool
    public var ocrNoiseRate: Double
    public var testsPromptInjection: Bool

    public init(
        captureSource: LabCaptureSource = .automatic,
        recognitionMode: LabOCRRecognitionMode = .fast,
        usesLanguageCorrection: Bool = false,
        freshnessSeconds: Double = 20,
        maximumTurns: Int = 8,
        maximumTurnCharacters: Int = 2_000,
        maximumReferenceCharacters: Int = 1_000,
        bubbleMinimumWidth: Double = 0.12,
        bubbleMaximumWidth: Double = 0.85,
        verticalBandCount: Int = 10,
        selfSpeakerMinimumX: Double = 0.58,
        otherSpeakerMaximumX: Double = 0.42,
        wrappedLineGapRatio: Double = 0.6,
        rareReferenceMinimumLength: Int = 4,
        dedupeMinimumLength: Int = 6,
        typingPauseSeconds: Double = 0.25,
        cadenceSeconds: Double = 2,
        changeCadenceFloorSeconds: Double = 0.5,
        activityWindowSeconds: Double = 10,
        gridWidth: Int = 48,
        gridHeight: Int = 30,
        tileChangeThreshold: Double = 0.02,
        fullFrameChangeFraction: Double = 0.4,
        regionPaddingTiles: Int = 1,
        injectsOCRNoise: Bool = false,
        ocrNoiseRate: Double = 0.05,
        testsPromptInjection: Bool = true
    ) {
        self.captureSource = captureSource
        self.recognitionMode = recognitionMode
        self.usesLanguageCorrection = usesLanguageCorrection
        self.freshnessSeconds = freshnessSeconds
        self.maximumTurns = maximumTurns
        self.maximumTurnCharacters = maximumTurnCharacters
        self.maximumReferenceCharacters = maximumReferenceCharacters
        self.bubbleMinimumWidth = bubbleMinimumWidth
        self.bubbleMaximumWidth = bubbleMaximumWidth
        self.verticalBandCount = verticalBandCount
        self.selfSpeakerMinimumX = selfSpeakerMinimumX
        self.otherSpeakerMaximumX = otherSpeakerMaximumX
        self.wrappedLineGapRatio = wrappedLineGapRatio
        self.rareReferenceMinimumLength = rareReferenceMinimumLength
        self.dedupeMinimumLength = dedupeMinimumLength
        self.typingPauseSeconds = typingPauseSeconds
        self.cadenceSeconds = cadenceSeconds
        self.changeCadenceFloorSeconds = changeCadenceFloorSeconds
        self.activityWindowSeconds = activityWindowSeconds
        self.gridWidth = gridWidth
        self.gridHeight = gridHeight
        self.tileChangeThreshold = tileChangeThreshold
        self.fullFrameChangeFraction = fullFrameChangeFraction
        self.regionPaddingTiles = regionPaddingTiles
        self.injectsOCRNoise = injectsOCRNoise
        self.ocrNoiseRate = ocrNoiseRate
        self.testsPromptInjection = testsPromptInjection
    }
}

public enum LabPersonalHistoryScope: String, LabNamedOption {
    case appSpecific = "app-specific"
    case global
    case appThenGlobal = "app-then-global"

    public var title: String {
        switch self {
        case .appSpecific: "App-specific"
        case .global: "Global"
        case .appThenGlobal: "App, then global"
        }
    }
}

public enum LabPersonalArbitration: String, LabNamedOption {
    case production
    case highestConfidence = "highest-confidence"
    case personalFirst = "personal-first"

    public var title: String {
        switch self {
        case .production: "Production guardrails"
        case .highestConfidence: "Highest confidence"
        case .personalFirst: "Personal first"
        }
    }
}

public struct LabPersonalizationConfiguration: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var minimumSupport: Int
    public var minimumConfidence: Double
    public var maximumTailWords: Int
    public var recencyWeight: Double
    public var frequencyWeight: Double
    public var scope: LabPersonalHistoryScope
    public var arbitration: LabPersonalArbitration
    public var lookupDeadlineMilliseconds: Int
    public var includesStaleHistoryCases: Bool
    public var includesContradictoryHistoryCases: Bool
    public var includesPoisonedHistoryCases: Bool

    public init(
        enabled: Bool = false,
        minimumSupport: Int = 2,
        minimumConfidence: Double = 2.0 / 3.0,
        maximumTailWords: Int = 2,
        recencyWeight: Double = 0.5,
        frequencyWeight: Double = 0.5,
        scope: LabPersonalHistoryScope = .appThenGlobal,
        arbitration: LabPersonalArbitration = .production,
        lookupDeadlineMilliseconds: Int = 250,
        includesStaleHistoryCases: Bool = true,
        includesContradictoryHistoryCases: Bool = true,
        includesPoisonedHistoryCases: Bool = true
    ) {
        self.enabled = enabled
        self.minimumSupport = minimumSupport
        self.minimumConfidence = minimumConfidence
        self.maximumTailWords = maximumTailWords
        self.recencyWeight = recencyWeight
        self.frequencyWeight = frequencyWeight
        self.scope = scope
        self.arbitration = arbitration
        self.lookupDeadlineMilliseconds = lookupDeadlineMilliseconds
        self.includesStaleHistoryCases = includesStaleHistoryCases
        self.includesContradictoryHistoryCases = includesContradictoryHistoryCases
        self.includesPoisonedHistoryCases = includesPoisonedHistoryCases
    }

    public var syntheticHistoryOnly: Bool { true }
    public var mayOverrideBaseSilence: Bool { false }
}

public enum LabTypingBoundary: String, LabNamedOption {
    case both
    case midWord = "mid-word"
    case wordBoundary = "word-boundary"

    public var title: String {
        switch self {
        case .both: "Both"
        case .midWord: "Mid-word"
        case .wordBoundary: "Word boundary"
        }
    }
}

public enum LabInteractionHost: String, LabNamedOption {
    case sceneHost = "scene-host"
    case textEdit = "textedit"
    case webKit = "webkit"
    case chromium
    case electron

    public var title: String {
        switch self {
        case .sceneHost: "Instrumented Scene Host"
        case .textEdit: "TextEdit"
        case .webKit: "WebKit"
        case .chromium: "Chromium"
        case .electron: "Electron"
        }
    }
}

public struct LabInteractionConfiguration: Codable, Equatable, Sendable {
    public var minimumTypedCharacters: Int
    public var boundary: LabTypingBoundary
    public var nativeMidWordRevealMilliseconds: Int
    public var nativeBoundaryRevealMilliseconds: Int
    public var chromiumMidWordRevealMilliseconds: Int
    public var chromiumBoundaryRevealMilliseconds: Int
    public var typingCharactersPerSecond: Double
    public var pauseBeforeInferenceMilliseconds: Int
    public var contextCharacterLimit: Int
    public var trailingContextCharacterLimit: Int
    public var socketTimeoutMilliseconds: Int
    public var testsCancellation: Bool
    public var testsBackspaceDuringInference: Bool
    public var testsCursorMovement: Bool
    public var testsSelectionChanges: Bool
    public var testsFocusChanges: Bool
    public var testsTabAcceptance: Bool
    public var testsEscapeDismissal: Bool
    public var testsWordAcceptance: Bool
    public var testsRuntimeRestart: Bool
    public var hosts: Set<LabInteractionHost>

    public init(
        minimumTypedCharacters: Int = 3,
        boundary: LabTypingBoundary = .both,
        nativeMidWordRevealMilliseconds: Int = 10,
        nativeBoundaryRevealMilliseconds: Int = 50,
        chromiumMidWordRevealMilliseconds: Int = 120,
        chromiumBoundaryRevealMilliseconds: Int = 200,
        typingCharactersPerSecond: Double = 8,
        pauseBeforeInferenceMilliseconds: Int = 0,
        contextCharacterLimit: Int = 3_000,
        trailingContextCharacterLimit: Int = 80,
        socketTimeoutMilliseconds: Int = 2_000,
        testsCancellation: Bool = true,
        testsBackspaceDuringInference: Bool = true,
        testsCursorMovement: Bool = true,
        testsSelectionChanges: Bool = true,
        testsFocusChanges: Bool = true,
        testsTabAcceptance: Bool = true,
        testsEscapeDismissal: Bool = true,
        testsWordAcceptance: Bool = true,
        testsRuntimeRestart: Bool = true,
        hosts: Set<LabInteractionHost> = Set(LabInteractionHost.allCases)
    ) {
        self.minimumTypedCharacters = minimumTypedCharacters
        self.boundary = boundary
        self.nativeMidWordRevealMilliseconds = nativeMidWordRevealMilliseconds
        self.nativeBoundaryRevealMilliseconds = nativeBoundaryRevealMilliseconds
        self.chromiumMidWordRevealMilliseconds = chromiumMidWordRevealMilliseconds
        self.chromiumBoundaryRevealMilliseconds = chromiumBoundaryRevealMilliseconds
        self.typingCharactersPerSecond = typingCharactersPerSecond
        self.pauseBeforeInferenceMilliseconds = pauseBeforeInferenceMilliseconds
        self.contextCharacterLimit = contextCharacterLimit
        self.trailingContextCharacterLimit = trailingContextCharacterLimit
        self.socketTimeoutMilliseconds = socketTimeoutMilliseconds
        self.testsCancellation = testsCancellation
        self.testsBackspaceDuringInference = testsBackspaceDuringInference
        self.testsCursorMovement = testsCursorMovement
        self.testsSelectionChanges = testsSelectionChanges
        self.testsFocusChanges = testsFocusChanges
        self.testsTabAcceptance = testsTabAcceptance
        self.testsEscapeDismissal = testsEscapeDismissal
        self.testsWordAcceptance = testsWordAcceptance
        self.testsRuntimeRestart = testsRuntimeRestart
        self.hosts = hosts
    }
}

public enum LabScenarioPartition: String, LabNamedOption {
    case development
    case validation
    case holdout
    case regression
    case adversarial
    case all

    public var title: String { rawValue.capitalized }
}

public enum LabScenarioIntent: String, LabNamedOption {
    case accept
    case decline
    case answer
    case clarify
    case acknowledge
    case commit
    case question
    case continueWriting = "continue-writing"

    public var title: String {
        switch self {
        case .continueWriting: "Continue writing"
        default: rawValue.capitalized
        }
    }
}

public enum LabScenarioTone: String, LabNamedOption {
    case friendly
    case formal
    case short
    case warm
    case direct
    case apologetic

    public var title: String { rawValue.capitalized }
}

public enum LabSuggestionExpectationFilter: String, LabNamedOption {
    case all
    case speakOnly = "speak-only"
    case silenceOnly = "silence-only"

    public var title: String {
        switch self {
        case .all: "Speak and silence"
        case .speakOnly: "Should speak only"
        case .silenceOnly: "Should stay silent only"
        }
    }
}

public struct LabScenarioVariationConfiguration: Codable, Equatable, Sendable {
    public var partition: LabScenarioPartition
    /// Nil preserves the original manifest meaning: include both positive and
    /// restraint cases. A non-nil value is an explicit diagnostic slice.
    public var suggestionExpectation: LabSuggestionExpectationFilter?
    /// Nil means all eligible roots. Limits are applied to stable root IDs so
    /// context/checkpoint variants cannot masquerade as distinct situations.
    public var maximumDistinctSituations: Int?
    public var intents: Set<LabScenarioIntent>
    public var tones: Set<LabScenarioTone>
    public var languages: [String]
    public var includesChat: Bool
    public var includesEmail: Bool
    public var includesProse: Bool
    public var includesMidWord: Bool
    public var includesWordBoundary: Bool
    public var includesTypos: Bool
    public var includesLongContext: Bool
    public var includesAmbiguity: Bool
    public var includesMultipleQuestions: Bool
    public var includesContradictions: Bool
    public var includesStaleContext: Bool
    public var includesIrrelevantContext: Bool
    public var includesNames: Bool
    public var includesDates: Bool
    public var includesTimes: Bool
    public var includesLocations: Bool
    public var includesQuantities: Bool
    public var includesDeadlines: Bool
    public var includesSensitiveCases: Bool
    public var includesSensitiveNearMisses: Bool
    public var includesPromptInjection: Bool
    public var includesCounterfactualPairs: Bool

    public init(
        partition: LabScenarioPartition = .all,
        suggestionExpectation: LabSuggestionExpectationFilter? = nil,
        maximumDistinctSituations: Int? = nil,
        intents: Set<LabScenarioIntent> = Set(LabScenarioIntent.allCases),
        tones: Set<LabScenarioTone> = Set(LabScenarioTone.allCases),
        languages: [String] = ["en"],
        includesChat: Bool = true,
        includesEmail: Bool = true,
        includesProse: Bool = true,
        includesMidWord: Bool = true,
        includesWordBoundary: Bool = true,
        includesTypos: Bool = true,
        includesLongContext: Bool = true,
        includesAmbiguity: Bool = true,
        includesMultipleQuestions: Bool = true,
        includesContradictions: Bool = true,
        includesStaleContext: Bool = true,
        includesIrrelevantContext: Bool = true,
        includesNames: Bool = true,
        includesDates: Bool = true,
        includesTimes: Bool = true,
        includesLocations: Bool = true,
        includesQuantities: Bool = true,
        includesDeadlines: Bool = true,
        includesSensitiveCases: Bool = true,
        includesSensitiveNearMisses: Bool = true,
        includesPromptInjection: Bool = true,
        includesCounterfactualPairs: Bool = true
    ) {
        self.partition = partition
        self.suggestionExpectation = suggestionExpectation
        self.maximumDistinctSituations = maximumDistinctSituations
        self.intents = intents
        self.tones = tones
        self.languages = languages
        self.includesChat = includesChat
        self.includesEmail = includesEmail
        self.includesProse = includesProse
        self.includesMidWord = includesMidWord
        self.includesWordBoundary = includesWordBoundary
        self.includesTypos = includesTypos
        self.includesLongContext = includesLongContext
        self.includesAmbiguity = includesAmbiguity
        self.includesMultipleQuestions = includesMultipleQuestions
        self.includesContradictions = includesContradictions
        self.includesStaleContext = includesStaleContext
        self.includesIrrelevantContext = includesIrrelevantContext
        self.includesNames = includesNames
        self.includesDates = includesDates
        self.includesTimes = includesTimes
        self.includesLocations = includesLocations
        self.includesQuantities = includesQuantities
        self.includesDeadlines = includesDeadlines
        self.includesSensitiveCases = includesSensitiveCases
        self.includesSensitiveNearMisses = includesSensitiveNearMisses
        self.includesPromptInjection = includesPromptInjection
        self.includesCounterfactualPairs = includesCounterfactualPairs
    }
}

public struct LabScoringConfiguration: Codable, Equatable, Sendable {
    public static let modelOutputQualityPolicy = "model-output-quality-v1"

    public var policyVersion: String
    public var usefulnessWeight: Double
    public var restraintWeight: Double
    public var factualityWeight: Double
    public var brevityWeight: Double
    public var weightsLockedDuringComparison: Bool

    public init(
        policyVersion: String = LabGoalContract.identifier,
        usefulnessWeight: Double = 0.55,
        restraintWeight: Double = 0.20,
        factualityWeight: Double = 0.15,
        brevityWeight: Double = 0.10,
        weightsLockedDuringComparison: Bool = true
    ) {
        self.policyVersion = policyVersion
        self.usefulnessWeight = usefulnessWeight
        self.restraintWeight = restraintWeight
        self.factualityWeight = factualityWeight
        self.brevityWeight = brevityWeight
        self.weightsLockedDuringComparison = weightsLockedDuringComparison
    }

    public var privacyGateRequired: Bool { true }
    public var textIntegrityGateRequired: Bool { true }
    public var secureInputGateRequired: Bool { true }
    public var sensitiveSceneGateRequired: Bool { true }
    public var usesScorecardV3: Bool { policyVersion == "scorecard-v3" }
    public var usesGoalContract: Bool { policyVersion == LabGoalContract.identifier }
    public var usesModelOutputQuality: Bool { policyVersion == Self.modelOutputQualityPolicy }

    public var normalizedWeights: (usefulness: Double, restraint: Double, factuality: Double, brevity: Double) {
        let values = [usefulnessWeight, restraintWeight, factualityWeight, brevityWeight].map { max(0, $0) }
        let total = values.reduce(0, +)
        guard total > 0 else { return (0.55, 0.20, 0.15, 0.10) }
        return (values[0] / total, values[1] / total, values[2] / total, values[3] / total)
    }
}
