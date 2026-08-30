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
        #expect(snapshot.entries.count == 45)
        #expect(snapshot.currentLearnings.count == 38)
        #expect(snapshot.archivedLearnings.count == 7)
        let earlyStart = try #require(snapshot.entries.first {
            $0.id == "early-start-third-character-k1-rejected"
        })
        #expect(earlyStart.status == .rejected)
        #expect(earlyStart.evaluationCount == 1911)
        #expect(earlyStart.metrics.first { $0.key == "situations" }?.value == 360)
        #expect(earlyStart.metrics.first { $0.key == "opportunities" }?.value == 637)
        #expect(earlyStart.metrics.first { $0.key == "completed-generations" }?.value == 1911)
        #expect(earlyStart.metrics.first { $0.key == "ready-by-boundary" }?.value == 100)
        #expect(earlyStart.metrics.first { $0.key == "median-lead" }?.value == 689)
        #expect(earlyStart.metrics.first { $0.key == "lockable-opportunities" }?.value == 78)
        #expect(earlyStart.metrics.first { $0.key == "lockable-rate" }?.value == 12.2448979592)
        #expect(earlyStart.metrics.first { $0.key == "simulated-false-lock-rate" }?.value == 0)
        #expect(
            earlyStart.metrics.first { $0.key == "decoded-token-compute-multiple" }?.value
                == 1.8692756037
        )
        #expect(
            earlyStart.metrics.first { $0.key == "request-latency-multiple" }?.value
                == 1.7421521121
        )
        #expect(earlyStart.evidence.contains {
            $0.kind == "documentation"
                && $0.id == "docs/experiments/Q10-early-start-timing-falsifier.md"
        })
        #expect(earlyStart.evidence.contains {
            $0.kind == "documentation"
                && $0.id == "docs/experiments/Q10R-aggregate-results.json"
        })
        #expect(earlyStart.evidence.contains {
            $0.kind == "campaign"
                && $0.id == "2d06791d-1fd3-4d84-bfc2-0fb4b8eb1491"
        })
        #expect(earlyStart.evidence.contains {
            $0.kind == "git-commit"
                && $0.id == "78df853ff6a39a90b1e7b02cb22ebb545264ef59"
        })
        #expect(earlyStart.evidence.contains {
            $0.kind == "artifact-sha256"
                && $0.id == "0dead997418b0b38ff0c2d4988094a72c3054d416427e9a7430f098e63be4b83"
        })
        #expect(snapshot.entries.contains {
            $0.id == "qwen-prefix-cache-tail-target-rejected" && $0.status == .rejected
                && $0.evaluationCount == 57600
        })
        #expect(snapshot.entries.contains {
            $0.id == "future-lattice-k16-independent-branches-rejected"
                && $0.status == .directional
                && $0.evaluationCount == 5760
        })
        #expect(snapshot.entries.contains {
            $0.id == "qwen-confidence-filter-bounded" && $0.status == .directional
                && $0.evaluationCount == 3030
        })
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
        #expect(snapshot.researchQueue.first { $0.id == "report-provenance-v6" }?.status == "completed-foundation")
        #expect(snapshot.researchQueue.first { $0.id == "campaign-state-reconciliation" }?.status == "completed-foundation")
        #expect(
            snapshot.researchQueue.first { $0.id == "qwen-protected-validation" }?.status
                == "closed-replication-rejected"
        )
        #expect(
            snapshot.researchQueue.first { $0.id == "qwen-live-meaningful-sample" }?.status
                == "blocked-by-replication-rejection"
        )
        #expect(
            snapshot.entries.contains {
                $0.id == "qwen-factorial-v4-rejected" && $0.status == .rejected
                    && $0.evaluationCount == 345600
            }
        )
        #expect(snapshot.entries.contains { $0.id == "qwen-9b-god-v1" && $0.status == .adopted })
        #expect(
            snapshot.entries.contains {
                $0.id == "qwen-god-v1-replication-inconclusive" && $0.status == .incomplete
            }
        )
        #expect(snapshot.entries.contains { $0.id == "report-provenance-v6" && $0.status == .adopted })
        #expect(snapshot.entries.contains { $0.id == "campaign-state-reconciliation" && $0.status == .adopted })
        #expect(snapshot.entries.contains { $0.id == "staged-research-program-v1" && $0.status == .adopted })
        #expect(snapshot.entries.contains { $0.id == "protected-learning-cycle-stopped" && $0.status == .incomplete })
        #expect(snapshot.entries.contains { $0.id == "qwen-9b-scoring-confounds" && $0.status == .rejected })
        #expect(
            snapshot.entries.contains {
                $0.id == "lab-partnership-and-failure-log" && $0.status == .adopted
            }
        )
        #expect(
            snapshot.entries.contains {
                $0.id == "cloud-protocol-mac-live-split" && $0.status == .adopted
            }
        )
        #expect(
            snapshot.entries.contains {
                $0.id == "score-counts-diary-words" && $0.status == .adopted
            }
        )
    }

    @Test("Human summary keeps decisions and limitations visible")
    func humanSummary() throws {
        let output = LabLearningLedgerRenderer.humanSummary(
            try LabLearningLedgerCatalog.loadBundled()
        )

        #expect(output.contains("Tilde Learning Ledger"))
        #expect(output.contains("The lab writes down every try, learn, and fail"))
        #expect(output.contains("GitHub holds the ruler; the Mac must watch typing"))
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
