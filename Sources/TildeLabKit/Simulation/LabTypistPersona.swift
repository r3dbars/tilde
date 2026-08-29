import Foundation

/// How much interruption a simulated writer tolerates before a visible ghost
/// costs more attention than it saves. This is a bucket, never a measurement.
public enum LabTypistInterruptionTolerance: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high
}

/// What the simulated writer is trying to do. These are coarse synthetic
/// labels, not sampled human intents.
public enum LabTypistGoal: String, Codable, CaseIterable, Sendable {
    case answerQuickly = "answer-quickly"
    case confirmDetail = "confirm-detail"
    case draftCarefully = "draft-carefully"
    case thinkAloud = "think-aloud"
}

/// A small synthetic persona. Every field is a bucket or a short synthetic
/// label; no persona carries the owner's writing, screen text, or any sampled
/// human material.
public struct LabTypistPersona: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let goal: LabTypistGoal
    public let register: LabOnlineRegister
    public let typingSpeed: LabTypingSpeedBucket
    public let interruptionTolerance: LabTypistInterruptionTolerance

    public init(
        id: String,
        goal: LabTypistGoal,
        register: LabOnlineRegister,
        typingSpeed: LabTypingSpeedBucket,
        interruptionTolerance: LabTypistInterruptionTolerance
    ) {
        self.id = id
        self.goal = goal
        self.register = register
        self.typingSpeed = typingSpeed
        self.interruptionTolerance = interruptionTolerance
    }

    /// Simulated inter-keystroke interval. A faster writer reaches the next
    /// display boundary sooner, so a slow candidate is worth less to them.
    public var millisecondsPerCharacter: Int {
        switch typingSpeed {
        case .fast: 90
        case .medium: 150
        case .slow: 260
        case .unknown: 150
        }
    }
}

public struct LabTypistPersonaCatalog: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.typist-personas.v1"

    public let schema: String
    public let personas: [LabTypistPersona]

    public init(schema: String = Self.currentSchema, personas: [LabTypistPersona]) {
        self.schema = schema
        self.personas = personas
    }

    @discardableResult
    public func validated() throws -> LabTypistPersonaCatalog {
        guard schema == Self.currentSchema else {
            throw LabTypistPersonaError.invalidSchema
        }
        guard (1...64).contains(personas.count) else {
            throw LabTypistPersonaError.invalidCatalogSize
        }
        var identifiers = Set<String>()
        for persona in personas {
            guard persona.id.range(
                of: #"^[a-z0-9][a-z0-9._-]{0,63}$"#,
                options: .regularExpression
            ) == persona.id.startIndex..<persona.id.endIndex else {
                throw LabTypistPersonaError.invalidPersonaID(persona.id)
            }
            guard identifiers.insert(persona.id).inserted else {
                throw LabTypistPersonaError.duplicatePersonaID(persona.id)
            }
        }
        return self
    }

    public static func loadBundled() throws -> LabTypistPersonaCatalog {
        guard let url = Bundle.module.url(
            forResource: "typist-personas-v1",
            withExtension: "json",
            subdirectory: "Fixtures"
        ) ?? Bundle.module.url(forResource: "typist-personas-v1", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try decode(Data(contentsOf: url, options: [.mappedIfSafe]))
    }

    public static func decode(_ data: Data) throws -> LabTypistPersonaCatalog {
        try JSONDecoder().decode(LabTypistPersonaCatalog.self, from: data).validated()
    }
}

public enum LabTypistPersonaError: Error, LocalizedError, Equatable, Sendable {
    case invalidSchema
    case invalidCatalogSize
    case invalidPersonaID(String)
    case duplicatePersonaID(String)
    case unknownPersonaID(String)

    public var errorDescription: String? {
        switch self {
        case .invalidSchema: "The typist persona catalog schema is unsupported."
        case .invalidCatalogSize: "A persona catalog holds between 1 and 64 personas."
        case let .invalidPersonaID(id): "Persona ID \(id) is not a safe stable identifier."
        case let .duplicatePersonaID(id): "Persona ID \(id) appears more than once."
        case let .unknownPersonaID(id): "No checked-in persona has the ID \(id)."
        }
    }
}
