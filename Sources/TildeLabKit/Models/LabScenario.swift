import AutocompleteLabCore
import CryptoKit
import Foundation

public enum LabValidationError: Error, LocalizedError, Sendable {
    case invalidSchema
    case invalidSuiteName
    case emptySuite
    case tooManyScenarios
    case duplicateScenarioID(String)
    case invalidScenarioID(String)
    case invalidCategory(String)
    case emptyContext(String)
    case oversizedValue(String)
    case missingExpectation(String)
    case unverifiedProtectedCase(String)

    public var errorDescription: String? {
        switch self {
        case .invalidSchema:
            "The scenario suite schema is unsupported."
        case .invalidSuiteName:
            "The scenario suite name must be a short display label."
        case .emptySuite:
            "The scenario suite has no cases."
        case .tooManyScenarios:
            "A scenario suite may contain at most 10,000 cases."
        case let .duplicateScenarioID(id):
            "The scenario ID \(id) appears more than once."
        case let .invalidScenarioID(id):
            "The scenario ID \(id) is not a safe stable identifier."
        case let .invalidCategory(id):
            "Scenario \(id) has an invalid category identifier."
        case let .emptyContext(id):
            "Scenario \(id) has no typed context."
        case let .oversizedValue(id):
            "Scenario \(id) exceeds a bounded text field."
        case let .missingExpectation(id):
            "Scenario \(id) should receive a suggestion but has no grading expectation."
        case let .unverifiedProtectedCase(id):
            "Scenario \(id) cannot enter validation or holdout without verified temporal integrity."
        }
    }
}

public struct LabScenarioSuite: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.scenario-suite.v1"

    public let schema: String
    public let name: String
    public let scenarios: [LabScenario]

    public init(
        schema: String = LabScenarioSuite.currentSchema,
        name: String,
        scenarios: [LabScenario]
    ) {
        self.schema = schema
        self.name = name
        self.scenarios = scenarios
    }

    @discardableResult
    public func validated() throws -> LabScenarioSuite {
        guard schema == Self.currentSchema else { throw LabValidationError.invalidSchema }
        guard name.range(
            of: #"^[A-Za-z0-9][A-Za-z0-9 ._+-]{0,79}$"#,
            options: .regularExpression
        ) == name.startIndex..<name.endIndex else { throw LabValidationError.invalidSuiteName }
        guard !scenarios.isEmpty else { throw LabValidationError.emptySuite }
        guard scenarios.count <= 10_000 else { throw LabValidationError.tooManyScenarios }

        var identifiers = Set<String>()
        for scenario in scenarios {
            try scenario.validate()
            guard identifiers.insert(scenario.id).inserted else {
                throw LabValidationError.duplicateScenarioID(scenario.id)
            }
        }
        return self
    }

    /// Stable identity for pairing runs without putting fixture text in a report.
    public func digestSHA256() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(self)
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}

public struct LabScenario: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let category: String
    public let partition: LabScenarioPartition
    public let intent: LabScenarioIntent?
    public let tone: LabScenarioTone?
    public let language: String
    public let tags: [String]
    public let appBundleIdentifier: String?
    public let typedContext: String
    public let scene: LabScene?
    public let expectation: LabExpectation
    public let evaluation: LabEvaluationMetadata

    public init(
        id: String,
        category: String,
        partition: LabScenarioPartition = .development,
        intent: LabScenarioIntent? = nil,
        tone: LabScenarioTone? = nil,
        language: String = "en",
        tags: [String] = [],
        appBundleIdentifier: String? = nil,
        typedContext: String,
        scene: LabScene? = nil,
        expectation: LabExpectation,
        evaluation: LabEvaluationMetadata = .init()
    ) {
        self.id = id
        self.category = category
        self.partition = partition
        self.intent = intent
        self.tone = tone
        self.language = language
        self.tags = tags
        self.appBundleIdentifier = appBundleIdentifier
        self.typedContext = typedContext
        self.scene = scene
        self.expectation = expectation
        self.evaluation = evaluation
    }

    fileprivate func validate() throws {
        guard Self.safeIdentifier(id) else { throw LabValidationError.invalidScenarioID(id) }
        guard Self.safeIdentifier(category) else { throw LabValidationError.invalidCategory(id) }
        guard !typedContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LabValidationError.emptyContext(id)
        }
        guard typedContext.count <= 24_000,
              (scene?.allTextCount ?? 0) <= 24_000,
              expectation.allTextCount <= 12_000,
              evaluation.evidence.allTextCount <= 48_000 else {
            throw LabValidationError.oversizedValue(id)
        }
        guard language.range(of: #"^[A-Za-z][A-Za-z0-9-]{0,15}$"#, options: .regularExpression) != nil,
              tags.count <= 64,
              tags.allSatisfy(Self.safeIdentifier) else {
            throw LabValidationError.invalidCategory(id)
        }
        guard !expectation.shouldSuggest || expectation.hasPositiveSignal else {
            throw LabValidationError.missingExpectation(id)
        }
        if partition == .validation || partition == .holdout {
            guard evaluation.temporalIntegrity.passed else {
                throw LabValidationError.unverifiedProtectedCase(id)
            }
        }
    }

    private static func safeIdentifier(_ value: String) -> Bool {
        value.range(
            of: #"^[a-z0-9][a-z0-9._-]{0,127}$"#,
            options: .regularExpression
        ) == value.startIndex..<value.endIndex
    }

    private enum CodingKeys: String, CodingKey {
        case id, category, partition, intent, tone, language, tags
        case appBundleIdentifier, typedContext, scene, expectation, evaluation
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        category = try values.decode(String.self, forKey: .category)
        partition = try values.decodeIfPresent(LabScenarioPartition.self, forKey: .partition) ?? .development
        intent = try values.decodeIfPresent(LabScenarioIntent.self, forKey: .intent)
        tone = try values.decodeIfPresent(LabScenarioTone.self, forKey: .tone)
        language = try values.decodeIfPresent(String.self, forKey: .language) ?? "en"
        tags = try values.decodeIfPresent([String].self, forKey: .tags) ?? []
        appBundleIdentifier = try values.decodeIfPresent(String.self, forKey: .appBundleIdentifier)
        typedContext = try values.decode(String.self, forKey: .typedContext)
        scene = try values.decodeIfPresent(LabScene.self, forKey: .scene)
        expectation = try values.decode(LabExpectation.self, forKey: .expectation)
        evaluation = try values.decodeIfPresent(
            LabEvaluationMetadata.self,
            forKey: .evaluation
        ) ?? .init()
    }
}

public struct LabScene: Codable, Equatable, Sendable {
    public enum Mode: String, Codable, CaseIterable, Sendable {
        case replying
        case referencing
        case composing
    }

    public let mode: Mode
    public let turns: [LabSceneTurn]
    public let references: [String]

    public init(mode: Mode, turns: [LabSceneTurn] = [], references: [String] = []) {
        self.mode = mode
        self.turns = turns
        self.references = references
    }

    var allTextCount: Int {
        turns.reduce(0) { $0 + $1.text.count } + references.reduce(0) { $0 + $1.count }
    }

    public func productionScene() -> ScreenScene.Scene {
        let productionMode: ScreenScene.Mode
        switch mode {
        case .replying: productionMode = .replying
        case .referencing: productionMode = .referencing
        case .composing: productionMode = .composing
        }
        return ScreenScene.Scene(
            mode: productionMode,
            conversationTurns: turns.map(\.productionTurn),
            referenceSnippets: references
        )
    }
}

public struct LabSceneTurn: Codable, Equatable, Sendable {
    public enum Speaker: String, Codable, CaseIterable, Sendable {
        case selfSpeaker = "self"
        case other
        case unknown
    }

    public let speaker: Speaker
    public let text: String

    public init(speaker: Speaker, text: String) {
        self.speaker = speaker
        self.text = text
    }

    fileprivate var productionTurn: ScreenScene.ConversationTurn {
        let productionSpeaker: ScreenScene.Speaker
        switch speaker {
        case .selfSpeaker: productionSpeaker = .selfSpeaker
        case .other: productionSpeaker = .other
        case .unknown: productionSpeaker = .unknown
        }
        return ScreenScene.ConversationTurn(
            speaker: productionSpeaker,
            text: text
        )
    }
}

public struct LabExpectation: Codable, Equatable, Sendable {
    public let shouldSuggest: Bool
    public let goldenContinuation: String?
    public let acceptablePrefixes: [String]
    public let acceptableContinuations: [String]
    public let requiredTerms: [String]
    public let forbiddenTerms: [String]
    public let maximumWords: Int?

    public init(
        shouldSuggest: Bool,
        goldenContinuation: String? = nil,
        acceptablePrefixes: [String] = [],
        acceptableContinuations: [String] = [],
        requiredTerms: [String] = [],
        forbiddenTerms: [String] = [],
        maximumWords: Int? = nil
    ) {
        self.shouldSuggest = shouldSuggest
        self.goldenContinuation = goldenContinuation
        self.acceptablePrefixes = acceptablePrefixes
        self.acceptableContinuations = acceptableContinuations
        self.requiredTerms = requiredTerms
        self.forbiddenTerms = forbiddenTerms
        self.maximumWords = maximumWords
    }

    private enum CodingKeys: String, CodingKey {
        case shouldSuggest, goldenContinuation, acceptablePrefixes, acceptableContinuations
        case requiredTerms, forbiddenTerms, maximumWords
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        shouldSuggest = try values.decode(Bool.self, forKey: .shouldSuggest)
        goldenContinuation = try values.decodeIfPresent(String.self, forKey: .goldenContinuation)
        acceptablePrefixes = try values.decodeIfPresent([String].self, forKey: .acceptablePrefixes) ?? []
        acceptableContinuations = try values.decodeIfPresent(
            [String].self,
            forKey: .acceptableContinuations
        ) ?? []
        requiredTerms = try values.decodeIfPresent([String].self, forKey: .requiredTerms) ?? []
        forbiddenTerms = try values.decodeIfPresent([String].self, forKey: .forbiddenTerms) ?? []
        maximumWords = try values.decodeIfPresent(Int.self, forKey: .maximumWords)
    }

    fileprivate var hasPositiveSignal: Bool {
        goldenContinuation?.isEmpty == false
            || !acceptablePrefixes.isEmpty
            || !acceptableContinuations.isEmpty
            || !requiredTerms.isEmpty
    }

    fileprivate var allTextCount: Int {
        (goldenContinuation?.count ?? 0)
            + acceptablePrefixes.reduce(0) { $0 + $1.count }
            + acceptableContinuations.reduce(0) { $0 + $1.count }
            + requiredTerms.reduce(0) { $0 + $1.count }
            + forbiddenTerms.reduce(0) { $0 + $1.count }
    }
}
