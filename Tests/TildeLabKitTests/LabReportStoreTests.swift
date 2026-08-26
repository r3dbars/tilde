import Foundation
import Testing
@testable import TildeLabKit

@Suite("Tilde Lab aggregate report store")
struct LabReportStoreTests {
    @Test("Reports round-trip with owner-only permissions and no fixture or output text")
    func ownerOnlyAggregateRoundTrip() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tilde-lab-report-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = LabReportStore(directory: root)
        let result = LabCaseResult(
            scenarioID: "reply.private-sentinel",
            category: "reply.test",
            repetition: 0,
            outcome: .useful,
            expectedSuggestion: true,
            hasGoldenContinuation: true,
            offered: true,
            modelRequested: true,
            exactMatchAt1: true,
            keystrokesSaved: 4,
            latencyMilliseconds: 10,
            workerIndex: 0
        )
        let report = LabRunReport(
            startedAt: Date(timeIntervalSince1970: 1),
            finishedAt: Date(timeIntervalSince1970: 2),
            suiteName: "Synthetic suite",
            suiteDigestSHA256: String(repeating: "a", count: 64),
            scenarioCount: 1,
            arm: LabArmConfiguration(),
            execution: LabExecutionSnapshot(LabExecutionConfiguration(
                serverExecutable: URL(fileURLWithPath: "/not-persisted/helper"),
                modelFile: URL(fileURLWithPath: "/not-persisted/PRIVATE_FIXTURE_SENTINEL"),
                workerCount: 1,
                slotsPerWorker: 1,
                repetitions: 1
            )),
            assets: LabAssetSnapshot(
                modelIdentifier: "synthetic-model",
                modelRevision: "synthetic-revision",
                modelSHA256: String(repeating: "b", count: 64),
                helperSHA256: String(repeating: "c", count: 64)
            ),
            metrics: LabScorer.aggregate([result], elapsedSeconds: 1),
            cases: [result]
        )

        try await store.save(report)
        let loaded = await store.loadAll()
        #expect(loaded == [report])

        let file = root.appendingPathComponent("\(report.id.uuidString).json")
        let currentData = try Data(contentsOf: file)
        let encoded = String(decoding: currentData, as: UTF8.self)
        #expect(!encoded.contains("PRIVATE_FIXTURE_SENTINEL"))
        #expect(!encoded.contains("RAW_MODEL_OUTPUT"))
        #expect(!encoded.contains("/not-persisted/"))
        #expect(permissions(at: root) == 0o700)
        #expect(permissions(at: file) == 0o600)

        // The first development build wrote v1 reports before model-request
        // throughput fields existed. Keep those owner-created baselines usable.
        var legacy = try #require(
            JSONSerialization.jsonObject(with: currentData) as? [String: Any]
        )
        var metrics = try #require(legacy["metrics"] as? [String: Any])
        metrics.removeValue(forKey: "modelRequests")
        metrics.removeValue(forKey: "throughputModelRequestsPerSecond")
        legacy["metrics"] = metrics
        var cases = try #require(legacy["cases"] as? [[String: Any]])
        for index in cases.indices { cases[index].removeValue(forKey: "modelRequested") }
        legacy["cases"] = cases
        try JSONSerialization.data(withJSONObject: legacy).write(to: file, options: .atomic)

        let migrated = await store.loadAll()
        #expect(migrated.count == 1)
        #expect(migrated.first?.metrics.modelRequests == 1)
        #expect(migrated.first?.metrics.throughputModelRequestsPerSecond == 1)
        #expect(migrated.first?.cases.first?.modelRequested == true)
    }

    private func permissions(at url: URL) -> Int? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.posixPermissions] as? NSNumber)?.intValue
    }
}
