import Foundation

public struct LabResearchComparisonArtifact: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.comparison-artifact.v1"

    public let schema: String
    public let campaignID: UUID
    public let baselineArmID: String
    public let candidateArmID: String
    public let createdAt: Date
    public let comparison: LabPairedComparisonReport

    public init(
        campaignID: UUID,
        baselineArmID: String,
        candidateArmID: String,
        createdAt: Date = Date(),
        comparison: LabPairedComparisonReport
    ) {
        schema = Self.currentSchema
        self.campaignID = campaignID
        self.baselineArmID = baselineArmID
        self.candidateArmID = candidateArmID
        self.createdAt = createdAt
        self.comparison = comparison
    }

    @discardableResult
    public func validated() throws -> LabResearchComparisonArtifact {
        guard schema == Self.currentSchema,
              Self.safeID(baselineArmID), Self.safeID(candidateArmID),
              baselineArmID != candidateArmID,
              comparison.schema == LabPairedComparisonReport.currentSchema else {
            throw LabResearchArtifactError.invalidComparison
        }
        return self
    }

    private static func safeID(_ value: String) -> Bool {
        value.range(
            of: "^[A-Za-z0-9][A-Za-z0-9._:+-]{0,127}$",
            options: .regularExpression
        ) == value.startIndex..<value.endIndex
    }
}

public enum LabResearchArtifactError: Error, LocalizedError, Equatable, Sendable {
    case invalidComparison
    case unsafePath

    public var errorDescription: String? {
        switch self {
        case .invalidComparison: "The paired-comparison artifact is invalid."
        case .unsafePath: "The research artifact path is not an owner-controlled regular file."
        }
    }
}

public enum LabResearchArtifactIO {
    public static func save<T: Encodable>(_ value: T, to url: URL) throws {
        guard url.isFileURL else { throw LabResearchArtifactError.unsafePath }
        let manager = FileManager.default
        let directory = url.deletingLastPathComponent()
        if !manager.fileExists(atPath: directory.path) {
            try manager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
        if manager.fileExists(atPath: url.path) {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw LabResearchArtifactError.unsafePath
            }
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url, options: .atomic)
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public static func load<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        guard url.isFileURL else { throw LabResearchArtifactError.unsafePath }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw LabResearchArtifactError.unsafePath
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: Data(contentsOf: url, options: [.mappedIfSafe]))
    }
}
