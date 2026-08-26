import Foundation

public struct LabCorpusDescriptor: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let version: String
    public let licenseIdentifier: String
    public let sourceURL: String?
    public let expectedSHA256: String?
    public let mayBundleSourceText: Bool
    public let developmentOnly: Bool

    public init(
        id: String,
        displayName: String,
        version: String,
        licenseIdentifier: String,
        sourceURL: String? = nil,
        expectedSHA256: String? = nil,
        mayBundleSourceText: Bool,
        developmentOnly: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.version = version
        self.licenseIdentifier = licenseIdentifier
        self.sourceURL = sourceURL
        self.expectedSHA256 = expectedSHA256
        self.mayBundleSourceText = mayBundleSourceText
        self.developmentOnly = developmentOnly
    }
}

public struct LabCorpusPilot: Sendable {
    public let suite: LabScenarioSuite
    public let descriptors: [LabCorpusDescriptor]

    public init(suite: LabScenarioSuite, descriptors: [LabCorpusDescriptor]) {
        self.suite = suite
        self.descriptors = descriptors
    }

    public var distinctRootCount: Int {
        Set(suite.scenarios.map { $0.evaluation.rootScenarioID ?? $0.id }).count
    }

    public var rootCountsByCorpus: [String: Int] {
        Dictionary(grouping: suite.scenarios) {
            $0.evaluation.corpusID ?? "unregistered"
        }.mapValues { scenarios in
            Set(scenarios.map { $0.evaluation.rootScenarioID ?? $0.id }).count
        }
    }
}

public enum LabCorpusRegistry {
    public static let taskmaster1 = LabCorpusDescriptor(
        id: "taskmaster-1-written",
        displayName: "Taskmaster-1 written dialogs",
        version: "TM-1-2019",
        licenseIdentifier: "CC-BY-4.0",
        sourceURL: "https://github.com/google-research-datasets/Taskmaster/tree/master/TM-1-2019",
        expectedSHA256: "1e590ed0ccee279e40c2fb9e083d3b9417477c6bfe35ce5b2277167698dd858d",
        mayBundleSourceText: false,
        developmentOnly: true
    )

    public static let tildeSyntheticPilot = LabCorpusDescriptor(
        id: "tilde-corpus-synthetic-v1",
        displayName: "Tilde Corpus synthetic pilot",
        version: "1",
        licenseIdentifier: "project-owned",
        mayBundleSourceText: true,
        developmentOnly: true
    )

    public static let tildeCertifiedV2 = LabCorpusDescriptor(
        id: "tilde-certified-corpus-v2",
        displayName: "Tilde Certified Corpus V2",
        version: "2",
        licenseIdentifier: "project-owned",
        mayBundleSourceText: true,
        developmentOnly: false
    )

    public static var defaultTaskmasterSourceURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Tilde Lab/Corpora/taskmaster-1")
            .appendingPathComponent("self-dialogs.json")
    }
}

public enum LabCorpusError: Error, LocalizedError, Sendable {
    case missingSource(String)
    case digestMismatch(String)
    case insufficientEligibleSituations(expected: Int, actual: Int)
    case duplicateRoot(String)

    public var errorDescription: String? {
        switch self {
        case let .missingSource(corpus):
            "The local source for \(corpus) is missing. Tilde Lab never downloads corpora automatically."
        case let .digestMismatch(corpus):
            "The local \(corpus) source does not match the reviewed corpus revision."
        case let .insufficientEligibleSituations(expected, actual):
            "The corpus produced \(actual) eligible situations; \(expected) are required for this pilot."
        case let .duplicateRoot(id):
            "The corpus pilot contains a duplicate root identifier: \(id)."
        }
    }
}
