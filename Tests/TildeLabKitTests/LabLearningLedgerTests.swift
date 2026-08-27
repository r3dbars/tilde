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
        #expect(snapshot.entries.count == 34)
        #expect(snapshot.currentLearnings.count == 28)
        #expect(snapshot.archivedLearnings.count == 6)
        #expect(snapshot.researchProgram.count == 6)
        #expect(snapshot.researchProgram.map(\.order).sorted() == Array(0...5))
        #expect(snapshot.researchProgram.first?.status == .active)
        #expect(snapshot.researchProgram.dropFirst().allSatisfy { $0.status == .locked })
        #expect(
            snapshot.researchProgram
                .flatMap(\.hypotheses)
                .map(\.id)
                .filter { $0.hasPrefix("H") }
                .sorted()
                == (1...18).map { String(format: "H%02d", $0) }
        )
        #expect(snapshot.researchQueue.count == 12)
        #expect(snapshot.promotionPath.map(\.order).sorted() == Array(1...7))
        #expect(snapshot.researchQueue.min(by: { $0.priority < $1.priority })?.id == "report-provenance-v6")
        #expect(snapshot.entries.contains { $0.id == "qwen-9b-god-v1" && $0.status == .adopted })
        #expect(snapshot.entries.contains { $0.id == "staged-research-program-v1" && $0.status == .adopted })
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
        #expect(output.contains("[Active] Stage 0: Make the evidence loop trustworthy"))
        #expect(output.contains("hypotheses: H16, H17, H18"))
        #expect(output.contains("Can every future result be reproduced"))
    }

    @Test("Research stages cannot overlap or repeat hypothesis IDs")
    func rejectsInvalidResearchProgram() throws {
        let data = try bundledData()
        var overlappingObject = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var overlappingProgram = try #require(overlappingObject["researchProgram"] as? [[String: Any]])
        overlappingProgram[1]["status"] = "active"
        overlappingObject["researchProgram"] = overlappingProgram
        let overlapping = try JSONSerialization.data(withJSONObject: overlappingObject)
        #expect(throws: LabLearningLedgerError.invalidResearchProgram) {
            try LabLearningLedgerCatalog.decodeAndValidate(overlapping)
        }

        var duplicateObject = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var duplicateProgram = try #require(duplicateObject["researchProgram"] as? [[String: Any]])
        var secondStage = duplicateProgram[1]
        var secondStageHypotheses = try #require(secondStage["hypotheses"] as? [[String: Any]])
        secondStageHypotheses[0]["id"] = "F01"
        secondStage["hypotheses"] = secondStageHypotheses
        duplicateProgram[1] = secondStage
        duplicateObject["researchProgram"] = duplicateProgram
        let duplicate = try JSONSerialization.data(withJSONObject: duplicateObject)
        #expect(throws: LabLearningLedgerError.duplicateResearchHypothesisID("F01")) {
            try LabLearningLedgerCatalog.decodeAndValidate(duplicate)
        }
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
