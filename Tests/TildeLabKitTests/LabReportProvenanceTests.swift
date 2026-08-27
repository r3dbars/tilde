import Foundation
import Testing
@testable import TildeLabKit

@Suite("Tilde Lab report provenance v6")
struct LabReportProvenanceTests {
    @Test("Registered clean reviewed reports are decision-grade evidence")
    func registeredReviewedEligibility() throws {
        let campaignID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let report = makeReport(provenance: completeProvenance(campaignID: campaignID))

        #expect(!report.effectiveEvidenceEligibility.eligible)
        #expect(report.effectiveEvidenceEligibility.reasons == [.reviewPending])
        #expect(report.evidenceEligibility == report.effectiveEvidenceEligibility)

        let reviewed = try report.reviewed(
            conclusion: "F01 supports requiring complete provenance for decision-grade reports.",
            status: .supported,
            at: Date(timeIntervalSince1970: 3)
        )
        #expect(reviewed.effectiveEvidenceEligibility.eligible)
        #expect(reviewed.evidenceEligibility?.eligible == true)
        #expect(reviewed.provenance == report.provenance)
        #expect(reviewed.review?.status == .supported)

        let encoded = String(decoding: try JSONEncoder().encode(reviewed), as: UTF8.self)
        #expect(encoded.contains("\"evidenceEligibility\""))
        #expect(encoded.contains("\"eligible\":true"))
        #expect(!encoded.contains("CommandLine.arguments"))
        #expect(!encoded.contains("/Users/"))
    }

    @Test("Dirty, incomplete, and unregistered reports explain why they are ineligible")
    func explicitIneligibilityReasons() throws {
        let campaignID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let complete = completeProvenance(campaignID: campaignID)
        let dirty = LabReportProvenance(
            capturedAt: complete.capturedAt,
            source: LabReportSourceProvenance(
                gitCommitSHA: complete.source.gitCommitSHA,
                treeState: .dirty,
                runnerSHA256: complete.source.runnerSHA256
            ),
            environment: complete.environment,
            invocation: complete.invocation,
            experiment: nil
        )
        let reviewed = try makeReport(provenance: dirty).reviewed(
            conclusion: "The diagnostic report is readable but cannot support promotion.",
            status: .inconclusive,
            at: Date(timeIntervalSince1970: 3)
        )

        #expect(!reviewed.effectiveEvidenceEligibility.eligible)
        #expect(reviewed.effectiveEvidenceEligibility.reasons.contains(.dirtySourceTree))
        #expect(reviewed.effectiveEvidenceEligibility.reasons.contains(.hypothesisUnregistered))
    }

    @Test("Legacy reports remain readable but cannot become decision-grade")
    func legacyReportsRemainReadable() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let current = makeReport(provenance: completeProvenance(campaignID: UUID()))
        var object = try #require(
            JSONSerialization.jsonObject(with: encoder.encode(current)) as? [String: Any]
        )
        object.removeValue(forKey: "provenance")
        object.removeValue(forKey: "review")
        object.removeValue(forKey: "evidenceEligibility")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for schema in LabRunReport.supportedSchemas where schema != LabRunReport.currentSchema {
            object["schema"] = schema
            let legacy = try decoder.decode(
                LabRunReport.self,
                from: JSONSerialization.data(withJSONObject: object)
            )

            #expect(try legacy.validatedForPersistence() == legacy)
            #expect(!legacy.effectiveEvidenceEligibility.eligible)
            #expect(legacy.effectiveEvidenceEligibility.reasons.contains(.legacyReportSchema))
            #expect(legacy.effectiveEvidenceEligibility.reasons.contains(.missingProvenance))
            #expect(legacy.effectiveEvidenceEligibility.reasons.contains(.reviewPending))
            #expect(throws: LabReportProvenanceError.invalidReview) {
                try legacy.reviewed(
                    conclusion: "Do not upgrade legacy evidence.",
                    status: .supported
                )
            }
        }
    }

    @Test("A v6 report cannot omit or forge its persisted eligibility decision")
    func evidenceDecisionIntegrity() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let report = makeReport(provenance: completeProvenance(campaignID: UUID()))
        var object = try #require(
            JSONSerialization.jsonObject(with: encoder.encode(report)) as? [String: Any]
        )
        object.removeValue(forKey: "evidenceEligibility")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let missing = try decoder.decode(
            LabRunReport.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(missing.effectiveEvidenceEligibility.reasons.contains(.evidenceDecisionMissing))
        #expect(throws: LabRunReportValidationError.missingEvidenceDecision) {
            try missing.validatedForPersistence()
        }

        object["evidenceEligibility"] = ["eligible": true, "reasons": []]
        let forged = try decoder.decode(
            LabRunReport.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(throws: LabRunReportValidationError.evidenceDecisionMismatch) {
            try forged.validatedForPersistence()
        }
    }

    @Test("Malformed or path-bearing provenance fails closed")
    func malformedProvenanceFailsClosed() {
        let valid = completeProvenance(campaignID: UUID())
        let malformed = LabReportProvenance(
            capturedAt: valid.capturedAt,
            source: valid.source,
            environment: valid.environment,
            invocation: valid.invocation,
            experiment: LabExperimentRegistration(
                id: "F01",
                campaignID: UUID(),
                manifestDigestSHA256: String(repeating: "d", count: 64),
                hypothesis: "Read /Users/private/writing.txt"
            )
        )

        #expect(throws: LabReportProvenanceError.invalidExperiment) {
            try malformed.validated()
        }
    }

    @Test("Canonical invocation digests are deterministic and argument-sensitive")
    func canonicalInvocationDigest() {
        let first = LabReportInvocationProvenance.canonicalDigest(
            arguments: ["tilde-lab", "run", "campaign.json", "--resume"]
        )
        let repeated = LabReportInvocationProvenance.canonicalDigest(
            arguments: ["tilde-lab", "run", "campaign.json", "--resume"]
        )
        let changed = LabReportInvocationProvenance.canonicalDigest(
            arguments: ["tilde-lab", "run", "campaign.json"]
        )

        #expect(first.count == 64)
        #expect(first == repeated)
        #expect(first != changed)
        #expect(!first.contains("campaign"))
    }

    @Test("Campaign hypothesis registration is optional only for legacy files")
    func campaignHypothesisRegistration() throws {
        var arm = LabArmConfiguration(id: "baseline")
        arm.scenarios.partition = .development
        let manifest = LabExperimentManifest(
            arms: [arm],
            research: LabResearchProtocol(
                phase: .discovery,
                baselineArmID: arm.id,
                fixedGenerationSeeds: [arm.generation.seed]
            )
        )
        let registered = LabResearchCampaignFile(
            name: "F01 campaign",
            hypothesisID: "F01",
            hypothesis: "Complete provenance makes report eligibility auditable.",
            manifest: manifest
        )
        #expect(try registered.validated() == registered)

        let missingStatement = LabResearchCampaignFile(
            name: "Invalid campaign",
            hypothesisID: "F01",
            manifest: manifest
        )
        #expect(throws: LabResearchCampaignFileError.invalidHypothesis) {
            try missingStatement.validated()
        }

        let encoder = JSONEncoder()
        var legacy = try #require(
            JSONSerialization.jsonObject(with: encoder.encode(registered)) as? [String: Any]
        )
        legacy.removeValue(forKey: "hypothesisID")
        legacy.removeValue(forKey: "hypothesis")
        let decoded = try JSONDecoder().decode(
            LabResearchCampaignFile.self,
            from: JSONSerialization.data(withJSONObject: legacy)
        )
        #expect(decoded.hypothesisID == nil)
        #expect(decoded.hypothesis == nil)
        #expect(try decoded.validated() == decoded)
    }

    private func completeProvenance(campaignID: UUID) -> LabReportProvenance {
        LabReportProvenance(
            capturedAt: Date(timeIntervalSince1970: 1),
            source: LabReportSourceProvenance(
                gitCommitSHA: String(repeating: "a", count: 40),
                treeState: .clean,
                runnerSHA256: String(repeating: "b", count: 64)
            ),
            environment: LabReportEnvironmentProvenance(
                operatingSystemVersion: "macOS 26.0",
                operatingSystemBuild: "25A123",
                hardwareClass: "Mac16,8",
                machine: LabResearchMachineState(
                    powerSourceKnown: true,
                    isOnACPower: true,
                    lowPowerModeEnabled: false,
                    thermalLevel: .nominal,
                    checkedAt: Date(timeIntervalSince1970: 1)
                )
            ),
            invocation: LabReportInvocationProvenance(
                digestSHA256: String(repeating: "c", count: 64)
            ),
            experiment: LabExperimentRegistration(
                id: "F01",
                campaignID: campaignID,
                manifestDigestSHA256: String(repeating: "d", count: 64),
                hypothesis: "Complete provenance makes report eligibility auditable."
            )
        )
    }

    private func makeReport(provenance: LabReportProvenance) -> LabRunReport {
        let result = LabCaseResult(
            scenarioID: "reply.synthetic",
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
        return LabRunReport(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            startedAt: Date(timeIntervalSince1970: 1),
            finishedAt: Date(timeIntervalSince1970: 2),
            suiteName: "Synthetic suite",
            suiteDigestSHA256: String(repeating: "e", count: 64),
            scenarioCount: 1,
            arm: LabArmConfiguration(),
            execution: LabExecutionSnapshot(LabExecutionConfiguration(
                serverExecutable: URL(fileURLWithPath: "/not-persisted/helper"),
                modelFile: URL(fileURLWithPath: "/not-persisted/model"),
                workerCount: 1,
                slotsPerWorker: 1,
                repetitions: 1
            )),
            assets: LabAssetSnapshot(
                modelIdentifier: "synthetic-model",
                modelRevision: "synthetic-revision",
                modelSHA256: String(repeating: "f", count: 64),
                helperSHA256: String(repeating: "0", count: 64)
            ),
            provenance: provenance,
            metrics: LabScorer.aggregate([result], elapsedSeconds: 1),
            cases: [result]
        )
    }
}
