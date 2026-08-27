import TildeCore
import Foundation

public enum LabResearchSuiteKind: String, Codable, CaseIterable, Sendable {
    case certifiedV2 = "certified-v2"
    case builtIn = "built-in"
    case file
}

/// Local suite locator kept in the owner-only campaign file. Reports retain
/// only the selected suite digest, never a local path or fixture text.
public struct LabResearchSuiteReference: Codable, Equatable, Sendable {
    public let kind: LabResearchSuiteKind
    public let builtInSuite: LabBuiltInSuite?
    public let filePath: String?

    public init(
        kind: LabResearchSuiteKind,
        builtInSuite: LabBuiltInSuite? = nil,
        filePath: String? = nil
    ) {
        self.kind = kind
        self.builtInSuite = builtInSuite
        self.filePath = filePath
    }

    public static let certifiedV2 = LabResearchSuiteReference(kind: .certifiedV2)

    public static func builtIn(_ suite: LabBuiltInSuite) -> LabResearchSuiteReference {
        LabResearchSuiteReference(kind: .builtIn, builtInSuite: suite)
    }

    public static func file(_ path: String) -> LabResearchSuiteReference {
        LabResearchSuiteReference(kind: .file, filePath: path)
    }

    @discardableResult
    public func validated() throws -> LabResearchSuiteReference {
        switch kind {
        case .certifiedV2:
            guard builtInSuite == nil, filePath == nil else {
                throw LabResearchCampaignFileError.invalidSuiteReference
            }
        case .builtIn:
            guard builtInSuite != nil, filePath == nil else {
                throw LabResearchCampaignFileError.invalidSuiteReference
            }
        case .file:
            guard builtInSuite == nil, let filePath,
                  !filePath.isEmpty, filePath.utf8.count <= 4_096,
                  filePath.hasPrefix("/") else {
                throw LabResearchCampaignFileError.invalidSuiteReference
            }
        }
        return self
    }

    public func load() throws -> LabScenarioSuite {
        try validated()
        switch kind {
        case .certifiedV2:
            return try LabReplyingV2SuiteFactory.makeCertifiedCorpusV2()
        case .builtIn:
            return try LabScenarioSuiteLoader.builtIn(builtInSuite!)
        case .file:
            return try LabScenarioSuiteLoader.load(from: URL(fileURLWithPath: filePath!))
        }
    }
}

/// Model paths are deliberately local campaign state, not part of a shareable
/// experiment manifest or aggregate result.
public struct LabResearchModelConfiguration: Codable, Equatable, Sendable {
    public var verificationMode: LabModelVerificationMode
    public var identifier: String
    public var revision: String
    public var helperPath: String
    public var modelPath: String

    public init(
        verificationMode: LabModelVerificationMode = .productionPinned,
        identifier: String = ProductionModelAsset.identifier,
        revision: String = ProductionModelAsset.revision,
        helperPath: String = "/Applications/Tilde.app/Contents/Helpers/llama-server",
        modelPath: String = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Tilde/Models", isDirectory: true)
            .appendingPathComponent(ProductionModelAsset.identifier, isDirectory: true)
            .appendingPathComponent("model.gguf")
            .path
    ) {
        self.verificationMode = verificationMode
        self.identifier = identifier
        self.revision = revision
        self.helperPath = helperPath
        self.modelPath = modelPath
    }

    public var profile: LabModelProfile {
        switch verificationMode {
        case .productionPinned: .production
        case .experimentalLocal: .experimental(identifier: identifier, revision: revision)
        }
    }

    @discardableResult
    public func validated() throws -> LabResearchModelConfiguration {
        try profile.validated()
        guard !helperPath.isEmpty, !modelPath.isEmpty,
              helperPath.utf8.count <= 4_096, modelPath.utf8.count <= 4_096,
              helperPath.hasPrefix("/"), modelPath.hasPrefix("/") else {
            throw LabResearchCampaignFileError.invalidModelLocation
        }
        return self
    }

    public func execution(_ runtime: LabRuntimeConfiguration) -> LabExecutionConfiguration {
        runtime.materialize(
            serverExecutable: URL(fileURLWithPath: helperPath),
            modelFile: URL(fileURLWithPath: modelPath),
            modelProfile: profile
        )
    }
}

/// Owner-only, resumable control-plane document. It binds a safe manifest to
/// local assets and a bounded budget while keeping those local paths out of
/// reports and agent evidence.
public struct LabResearchCampaignFile: Codable, Equatable, Identifiable, Sendable {
    public static let currentSchema = "tilde-lab.research-campaign.v2"

    public let schema: String
    public let id: UUID
    public var name: String
    public let createdAt: Date
    public let parentCampaignID: UUID?
    public var suite: LabResearchSuiteReference
    public var manifest: LabExperimentManifest
    public var budget: LabResearchBudget
    public var model: LabResearchModelConfiguration

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        parentCampaignID: UUID? = nil,
        suite: LabResearchSuiteReference = .certifiedV2,
        manifest: LabExperimentManifest,
        budget: LabResearchBudget = .init(),
        model: LabResearchModelConfiguration = .init()
    ) {
        schema = Self.currentSchema
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.parentCampaignID = parentCampaignID
        self.suite = suite
        self.manifest = manifest
        self.budget = budget
        self.model = model
    }

    @discardableResult
    public func validated() throws -> LabResearchCampaignFile {
        guard schema == Self.currentSchema else {
            throw LabResearchCampaignFileError.unsupportedSchema
        }
        guard name.range(
            of: "^[A-Za-z0-9][A-Za-z0-9 ._:+-]{0,99}$",
            options: .regularExpression
        ) == name.startIndex..<name.endIndex else {
            throw LabResearchCampaignFileError.invalidName
        }
        try suite.validated()
        try model.validated()
        try budget.validated()
        try manifest.validated()
        guard let research = manifest.research,
              research.phase == .discovery else {
            throw LabResearchCampaignFileError.discoveryCampaignRequired
        }
        guard manifest.arms.count <= budget.maximumTrials else {
            throw LabResearchCampaignFileError.budgetExceeded
        }
        return self
    }

    @discardableResult
    public func validated(with loadedSuite: LabScenarioSuite) throws -> LabResearchCampaignFile {
        try validated()
        try loadedSuite.validated()
        guard let research = manifest.research else {
            throw LabResearchCampaignFileError.discoveryCampaignRequired
        }
        let selected = try manifest.arms.map {
            try LabResearchScenarioSelection.select(
                from: loadedSuite,
                configuration: $0.scenarios,
                phase: research.phase
            )
        }
        guard selected.allSatisfy({ !$0.scenarios.isEmpty }) else {
            throw LabResearchCampaignFileError.emptySelection
        }
        let digests = try selected.map { try $0.digestSHA256() }
        guard Set(digests).count == 1 else {
            throw LabResearchProtocolError.scenarioSelectionDrift
        }
        let rootsPerTrial = selected.map { suite in
            Set(suite.scenarios.map { $0.evaluation.rootScenarioID ?? $0.id }).count
        }.max() ?? 0
        let plannedRequests = selected.enumerated().reduce(0) { total, entry in
            let armID = manifest.arms[entry.offset].id
            let repetitions = research.runtimeByArm?[armID]?.repetitions
                ?? manifest.runtime.repetitions
            return total + entry.element.scenarios.count * repetitions
                * research.fixedGenerationSeeds.count
        }
        guard rootsPerTrial <= budget.maximumRootsPerTrial,
              plannedRequests <= budget.maximumModelRequests else {
            throw LabResearchCampaignFileError.budgetExceeded
        }
        return self
    }

    public var plannedModelRequests: Int? {
        guard let suite = try? suite.load(), let research = manifest.research else { return nil }
        return manifest.arms.reduce(0) { total, arm in
            guard let selected = try? LabResearchScenarioSelection.select(
                from: suite,
                configuration: arm.scenarios,
                phase: research.phase
            ) else { return total }
            let repetitions = research.runtimeByArm?[arm.id]?.repetitions
                ?? manifest.runtime.repetitions
            return total + selected.scenarios.count * repetitions
                * research.fixedGenerationSeeds.count
        }
    }
}

public enum LabResearchCampaignFileError: Error, LocalizedError, Equatable, Sendable {
    case unsupportedSchema
    case invalidName
    case invalidSuiteReference
    case invalidModelLocation
    case discoveryCampaignRequired
    case emptySelection
    case budgetExceeded
    case unsafeDocumentPath

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema: "The research campaign schema is unsupported."
        case .invalidName: "The research campaign name is not a safe display label."
        case .invalidSuiteReference: "The campaign suite reference is incomplete or unsafe."
        case .invalidModelLocation: "The local helper or model location is invalid."
        case .discoveryCampaignRequired:
            "Campaign files are development-only; protected work must use a frozen research plan."
        case .emptySelection: "At least one arm selects no research situations."
        case .budgetExceeded: "The campaign exceeds its pre-registered trial, root, or request budget."
        case .unsafeDocumentPath: "The campaign document path is not an owner-controlled regular file."
        }
    }
}

public enum LabResearchCampaignFileIO {
    public static func load(from url: URL) throws -> LabResearchCampaignFile {
        guard url.isFileURL else { throw LabResearchCampaignFileError.unsafeDocumentPath }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw LabResearchCampaignFileError.unsafeDocumentPath
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(
            LabResearchCampaignFile.self,
            from: Data(contentsOf: url, options: [.mappedIfSafe])
        ).validated()
    }

    public static func save(_ campaign: LabResearchCampaignFile, to url: URL) throws {
        try campaign.validated()
        guard url.isFileURL else { throw LabResearchCampaignFileError.unsafeDocumentPath }
        let manager = FileManager.default
        let directory = url.deletingLastPathComponent()
        try manager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        if manager.fileExists(atPath: url.path) {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw LabResearchCampaignFileError.unsafeDocumentPath
            }
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(campaign).write(to: url, options: .atomic)
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

public struct LabResearchArtifactLayout: Equatable, Sendable {
    public let documentURL: URL
    public let directory: URL
    public let reportsDirectory: URL
    public let comparisonsDirectory: URL
    public let candidateCacheURL: URL

    public init(documentURL: URL) {
        self.documentURL = documentURL.standardizedFileURL
        let stem = documentURL.deletingPathExtension().lastPathComponent
        directory = documentURL.deletingLastPathComponent()
            .appendingPathComponent("\(stem).research", isDirectory: true)
        reportsDirectory = directory.appendingPathComponent("reports", isDirectory: true)
        comparisonsDirectory = directory.appendingPathComponent("comparisons", isDirectory: true)
        candidateCacheURL = directory.appendingPathComponent("synthetic-candidates.sqlite3")
    }

    public func prepare() throws {
        for url in [directory, reportsDirectory, comparisonsDirectory] {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: url.path
            )
        }
    }
}
