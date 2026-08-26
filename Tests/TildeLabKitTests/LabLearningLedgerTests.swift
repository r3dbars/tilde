import Foundation
import Testing
@testable import TildeLabKit

@Suite("Tilde Lab checked-in learning ledger")
struct LabLearningLedgerTests {
    @Test("Bundled ledger is private, complete, and prioritizes the next work")
    func bundledLedger() throws {
        let snapshot = try LabLearningLedgerCatalog.loadBundled()

        #expect(snapshot.schema == LabLearningLedgerCatalog.schema)
        #expect(snapshot.privacy.safeToCheckIn)
        #expect(snapshot.entries.count == 33)
        #expect(snapshot.currentLearnings.count == 27)
        #expect(snapshot.archivedLearnings.count == 6)
        #expect(snapshot.researchQueue.count == 10)
        #expect(snapshot.promotionPath.map(\.order).sorted() == Array(1...7))
        #expect(snapshot.researchQueue.min(by: { $0.priority < $1.priority })?.id == "qwen-live-meaningful-sample")
        #expect(snapshot.entries.contains { $0.id == "qwen-9b-god-v1" && $0.status == .adopted })
        #expect(snapshot.entries.contains { $0.id == "protected-learning-cycle-stopped" && $0.status == .incomplete })
        #expect(snapshot.entries.contains { $0.id == "qwen-9b-scoring-confounds" && $0.status == .rejected })
    }

    @Test("Human summary keeps decisions and limitations visible")
    func humanSummary() throws {
        let output = LabLearningLedgerRenderer.humanSummary(
            try LabLearningLedgerCatalog.loadBundled()
        )

        #expect(output.contains("Tilde Learning Ledger"))
        #expect(output.contains("finding:"))
        #expect(output.contains("decision:"))
        #expect(output.contains("limitations:"))
        #expect(output.contains("Does Qwen 9B God v1 remain fast and useful"))
    }

    @Test("Raw-data keys are rejected even when Codable would ignore them")
    func rejectsForbiddenRawKey() throws {
        let data = try bundledData()
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["scenarioText"] = "must never be checked in"
        let unsafe = try JSONSerialization.data(withJSONObject: object)

        #expect(throws: LabLearningLedgerError.forbiddenKey("scenarioText")) {
            try LabLearningLedgerCatalog.decodeAndValidate(unsafe)
        }
    }

    @Test("Local paths and unsafe privacy flags are rejected")
    func rejectsUnsafeContent() throws {
        let data = try bundledData()
        var pathObject = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        pathObject["mission"] = "/Users/example/private"
        let localPath = try JSONSerialization.data(withJSONObject: pathObject)
        #expect(throws: LabLearningLedgerError.localPath) {
            try LabLearningLedgerCatalog.decodeAndValidate(localPath)
        }

        var privacyObject = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var privacy = try #require(privacyObject["privacy"] as? [String: Any])
        privacy["aggregateOnly"] = false
        privacyObject["privacy"] = privacy
        let unsafePrivacy = try JSONSerialization.data(withJSONObject: privacyObject)
        #expect(throws: LabLearningLedgerError.unsafePrivacyBoundary) {
            try LabLearningLedgerCatalog.decodeAndValidate(unsafePrivacy)
        }
    }

    private func bundledData() throws -> Data {
        let url = try #require(Bundle.module.url(
            forResource: "learning-ledger-v1",
            withExtension: "json"
        ))
        return try Data(contentsOf: url)
    }
}
