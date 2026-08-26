import Foundation

public struct LabModelBenchmarkSnapshot: Codable, Equatable, Sendable {
    public let schema: String
    public let capturedAt: Date
    public let suiteName: String
    public let comparisonPolicy: String
    public let entries: [LabModelBenchmarkEntry]
    public let promotedConfigurations: [LabPromotedConfiguration]

    public var fullComparisons: [LabModelBenchmarkEntry] {
        entries
            .filter { $0.evaluations == 360 }
            .sorted {
                if $0.qualityScore != $1.qualityScore {
                    return $0.qualityScore > $1.qualityScore
                }
                return ($0.totalP95Milliseconds ?? .max) < ($1.totalP95Milliseconds ?? .max)
            }
    }
}

public struct LabPromotedConfiguration: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let label: String
    public let modelEntryID: String
    public let evaluations: Int
    public let temperature: Double
    public let predictionTokens: Int
    public let maximumVisibleWords: Int
    public let qualityScore: Int
    public let useful: Int
    public let wrong: Int
    public let silent: Int
    public let badSuggestionRate: Double
    public let netKeystrokeSavingsRate: Double
    public let factualityRate: Double
    public let firstTokenP95Milliseconds: Int
    public let totalP95Milliseconds: Int
    public let baselineQualityScore: Int
    public let baselineUseful: Int
    public let baselineWrong: Int
    public let sourceReportID: UUID
    public let baselineSourceReportID: UUID
    public let evidenceNote: String
}

public struct LabModelBenchmarkEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let label: String
    public let family: String
    public let modelIdentifier: String
    public let modelRevision: String
    public let modelSHA256: String
    public let quantization: String
    public let inferenceBackend: String
    public let evaluations: Int
    public let qualityScore: Int
    public let useful: Int
    public let wrong: Int
    public let silent: Int
    public let factualityRate: Double
    public let firstTokenP95Milliseconds: Int?
    public let totalP95Milliseconds: Int?
    public let throughputRequestsPerSecond: Double
    public let sourceReportID: UUID
}

public enum LabModelBenchmarkCatalog {
    public static let schema = "tilde-lab.model-benchmarks.v1"

    public static func loadBundled() throws -> LabModelBenchmarkSnapshot {
        guard let url = Bundle.module.url(
            forResource: "model-benchmark-results-v1",
            withExtension: "json"
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(
            LabModelBenchmarkSnapshot.self,
            from: Data(contentsOf: url)
        )
        guard snapshot.schema == schema else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return snapshot
    }
}
