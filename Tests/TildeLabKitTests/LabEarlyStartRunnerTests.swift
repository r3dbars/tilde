import Foundation
import Testing
import TildeCore
@testable import TildeLabKit

@Suite("Early start timing falsifier")
struct LabEarlyStartRunnerTests {
    @Test("Only long words followed by a space and useful text become opportunities")
    func planning() {
        let cuts = LabEarlyStartPlanner.cuts(
            in: "should ship the release notes tomorrow",
            minimumUsefulCharacters: 6,
            maximumOpportunities: 8
        )
        // "the" is too short, "tomorrow" is last so no boundary follows it,
        // and "notes" leaves only " tomorrow" which still qualifies.
        #expect(cuts.map(\.cutOffset) == [3, 10, 19, 27])
        #expect(cuts[0].charactersToBoundary == 4)
        #expect(cuts[0].charactersAfterBoundary == 31)
    }

    @Test("A word with no following space is never an opportunity")
    func punctuationBoundary() {
        let cuts = LabEarlyStartPlanner.cuts(
            in: "sounds, good enough",
            minimumUsefulCharacters: 3,
            maximumOpportunities: 8
        )
        #expect(cuts.map(\.cutOffset) == [11])
    }

    @Test("Opportunities are capped so one situation cannot dominate compute")
    func opportunityCap() {
        let cuts = LabEarlyStartPlanner.cuts(
            in: "alpha bravo charlie delta echo foxtrot golf hotel india",
            minimumUsefulCharacters: 3,
            maximumOpportunities: 2
        )
        #expect(cuts.count == 2)
    }

    @Test("A ready, compatible, useful early branch locks and leads")
    func lockableBranch() {
        let measurement = measurement(
            charactersToBoundary: 4,
            remainder: "uld ship the release notes",
            cold: generation("uld ship the release", latency: 400, tokens: 8),
            boundary: generation("ship the release", latency: 380, tokens: 8)
        )
        #expect(LabEarlyStartAnalyzer.isReady(
            candidate: measurement.cold,
            measurement: measurement,
            keystrokeIntervalMilliseconds: 180
        ))
        #expect(LabEarlyStartAnalyzer.compatibleThroughBoundary(
            candidate: measurement.cold.text,
            measurement: measurement
        ))
        #expect(LabEarlyStartAnalyzer.futureCharactersBeyondBoundary(
            candidate: measurement.cold.text,
            measurement: measurement
        ) == 16)
        #expect(LabEarlyStartAnalyzer.leadMilliseconds(
            measurement: measurement,
            keystrokeIntervalMilliseconds: 180
        ) == 700)
    }

    @Test("A branch that finishes the word differently never locks")
    func incompatibleBranch() {
        let measurement = measurement(
            charactersToBoundary: 4,
            remainder: "uld ship the release notes",
            cold: generation("wing by tomorrow", latency: 200, tokens: 8),
            boundary: generation("ship the release", latency: 380, tokens: 8)
        )
        #expect(!LabEarlyStartAnalyzer.compatibleThroughBoundary(
            candidate: measurement.cold.text,
            measurement: measurement
        ))
        #expect(!LabEarlyStartAnalyzer.isLockable(
            candidate: measurement.cold,
            measurement: measurement,
            minimumUsefulCharacters: 6,
            keystrokeIntervalMilliseconds: 180
        ))
    }

    @Test("A slow branch is discarded even when it was right")
    func slowBranch() {
        let measurement = measurement(
            charactersToBoundary: 4,
            remainder: "uld ship the release notes",
            cold: generation("uld ship the release", latency: 900, tokens: 8),
            boundary: generation("ship the release", latency: 380, tokens: 8)
        )
        #expect(!LabEarlyStartAnalyzer.isReady(
            candidate: measurement.cold,
            measurement: measurement,
            keystrokeIntervalMilliseconds: 180
        ))
        #expect(!LabEarlyStartAnalyzer.isLockable(
            candidate: measurement.cold,
            measurement: measurement,
            minimumUsefulCharacters: 6,
            keystrokeIntervalMilliseconds: 180
        ))
    }

    @Test("A lock accepted only by normalization counts as a false lock")
    func falseLock() {
        let measurement = measurement(
            charactersToBoundary: 5,
            remainder: "cafe\u{301} is open today",
            cold: generation("caf\u{e9} is open today", latency: 300, tokens: 8),
            boundary: generation("is open today", latency: 300, tokens: 8)
        )
        #expect(LabEarlyStartAnalyzer.compatibleThroughBoundary(
            candidate: measurement.cold.text,
            measurement: measurement
        ))
        #expect(LabEarlyStartAnalyzer.isSimulatedFalseLock(
            measurement: measurement,
            keystrokeIntervalMilliseconds: 180
        ))
    }

    @Test("A surviving but unshowable branch still answers the boundary")
    func compatibleButTooShort() {
        let short = measurement(
            charactersToBoundary: 4,
            remainder: "uld ship the release notes",
            cold: generation("uld ship", latency: 300, tokens: 10),
            boundary: generation("ship the release", latency: 300, tokens: 10)
        )
        let metrics = LabEarlyStartAnalyzer.primary(
            measurements: [short],
            minimumUsefulCharacters: 6,
            keystrokeIntervalMilliseconds: 180
        )
        #expect(metrics.compatibleThroughBoundaryCount == 1)
        #expect(metrics.lockableCount == 0)
        // No second request: the branch is late-proof and uncontradicted.
        #expect(metrics.computeMultipleDecodedTokens == 1)
    }

    @Test("Compute adds the fallback only for a late or contradicted branch")
    func computeAccounting() {
        let locked = measurement(
            charactersToBoundary: 4,
            remainder: "uld ship the release notes",
            cold: generation("uld ship the release", latency: 400, tokens: 10),
            boundary: generation("ship the release", latency: 400, tokens: 10)
        )
        let discarded = measurement(
            charactersToBoundary: 4,
            remainder: "uld ship the release notes",
            cold: generation("wing by tomorrow", latency: 400, tokens: 10),
            boundary: generation("ship the release", latency: 400, tokens: 10)
        )
        let metrics = LabEarlyStartAnalyzer.primary(
            measurements: [locked, discarded],
            minimumUsefulCharacters: 6,
            keystrokeIntervalMilliseconds: 180
        )
        #expect(metrics.opportunityCount == 2)
        #expect(metrics.lockableCount == 1)
        // control 20 tokens; treatment 10 + 10 early plus 10 fallback = 30.
        #expect(metrics.computeMultipleDecodedTokens == 1.5)
        #expect(metrics.readyByBoundaryRate == 1)
    }

    @Test("The pair arm reports its own coverage, cost, and duplication")
    func pairArm() {
        let coldOnly = measurement(
            charactersToBoundary: 4,
            remainder: "uld ship the release notes",
            cold: generation("uld ship the release", latency: 300, tokens: 10),
            hot: generation("uld ship the release", latency: 300, tokens: 10),
            boundary: generation("ship the release", latency: 300, tokens: 10)
        )
        let hotOnly = measurement(
            charactersToBoundary: 4,
            remainder: "uld ship the release notes",
            cold: generation("wing by tomorrow", latency: 300, tokens: 10),
            hot: generation("uld ship the release", latency: 300, tokens: 10),
            boundary: generation("ship the release", latency: 300, tokens: 10)
        )
        let pair = LabEarlyStartAnalyzer.pair(
            measurements: [coldOnly, hotOnly],
            minimumUsefulCharacters: 6,
            keystrokeIntervalMilliseconds: 180
        )
        #expect(pair.coldLockableRate == 0.5)
        #expect(pair.pairLockableRate == 1)
        #expect(pair.pairCoverageGainPercentagePoints == 50)
        #expect(pair.hotOnlyLockCount == 1)
        #expect(pair.hotDuplicatesColdRate == 0.5)
        #expect(pair.hotCleanerSurvivalRate == 1)
        // control 20 tokens; pair 40 tokens with no fallback needed.
        #expect(pair.pairComputeMultipleDecodedTokens == 2)
    }

    @Test("Registered gates adjudicate the frozen Q10 numbers")
    func gates() {
        let passing = LabEarlyStartAnalyzer.primary(
            measurements: [
                measurement(
                    charactersToBoundary: 6,
                    remainder: "uldn\u{2019}t ship the release notes",
                    cold: generation("uldn\u{2019}t ship the release", latency: 300, tokens: 10),
                    boundary: generation("ship the release", latency: 300, tokens: 10)
                ),
            ],
            minimumUsefulCharacters: 6,
            keystrokeIntervalMilliseconds: 180
        )
        let pair = LabEarlyStartAnalyzer.pair(
            measurements: [],
            minimumUsefulCharacters: 6
        )
        let outcome = LabEarlyStartGateOutcome(primary: passing, pair: pair)
        #expect(outcome.readinessGatePassed)
        #expect(outcome.leadGatePassed)
        #expect(outcome.lockableGatePassed)
        #expect(outcome.falseLockGatePassed)
        #expect(outcome.computeGatePassed)
        #expect(outcome.primaryPromotionPassed)
        #expect(!outcome.pairCoverageGatePassed)
    }

    @Test("Replay moves typed characters out of the golden continuation")
    func replay() {
        let scenario = LabScenario(
            id: "case-1",
            category: "reply",
            typedContext: "Hi Sam, ",
            expectation: LabExpectation(
                shouldSuggest: true,
                goldenContinuation: "we should ship the notes",
                requiredTerms: ["we", "notes"]
            )
        )
        let replayed = LabEarlyStartRunner.replayed(scenario, typedSuffix: "we sho")
        #expect(replayed.typedContext == "Hi Sam, we sho")
        #expect(replayed.expectation.goldenContinuation == "uld ship the notes")
        #expect(replayed.expectation.requiredTerms == ["notes"])
    }

    @Test("Q10R protocol digest binds the exact arm, runtime, and invocation")
    func registeredProtocolDigest() throws {
        let protocolDefinition = makeProtocol()
        let digest = try protocolDefinition.canonicalDigestSHA256()
        #expect(digest == LabEarlyStartProtocol.registeredManifestDigestSHA256)
        #expect(protocolDefinition.expectedInvocationDigestSHA256
            == LabReportInvocationProvenance.canonicalDigest(arguments: [
                "./.build/release/tilde-lab-runner",
                "--early-start-full",
                "--helper",
                "/Applications/Tilde Model Preview.app/Contents/Helpers/llama-server",
                "--early-start-output",
                "/tmp/tilde-q10r-report.json",
            ]))
    }

    @Test("Complete Q10R aggregates become eligible only after explicit review")
    func decisionGradeReview() throws {
        let report = makeDecisionGradeReport()
        #expect(try report.validatedForPersistence() == report)
        #expect(report.effectiveEvidenceEligibility.reasons == [.reviewPending])

        let reviewed = try report.reviewed(
            conclusion: "Q10R rejects the registered primary hypothesis on its lockability kill rule.",
            status: .rejected,
            at: Date(timeIntervalSince1970: 5)
        )
        #expect(reviewed.effectiveEvidenceEligibility.eligible)
        #expect(reviewed.evidenceEligibility?.eligible == true)
        #expect(reviewed.provenance == report.provenance)
        #expect(reviewed.protocolDefinition == report.protocolDefinition)
        #expect(reviewed.primary == report.primary)

        let encoded = String(decoding: try JSONEncoder().encode(reviewed), as: UTF8.self)
        #expect(!encoded.contains("/Applications/"))
        #expect(!encoded.contains("/Users/"))
        #expect(!encoded.contains("--early-start-full"))
        #expect(!encoded.contains("remainderAfterCut"))
    }

    @Test("Legacy v1 early-start aggregates stay readable and ineligible")
    func legacyReportDecoding() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var object = try #require(
            JSONSerialization.jsonObject(
                with: encoder.encode(makeDecisionGradeReport())
            ) as? [String: Any]
        )
        object["schema"] = "tilde-lab.early-start.v1"
        for key in [
            "maximumSituations", "maximumOpportunitiesPerSituation",
            "coldTemperature", "coldSeed", "arm", "protocolDefinition",
            "provenance", "review", "evidenceEligibility",
        ] {
            object.removeValue(forKey: key)
        }
        let legacy = try LabEarlyStartReport.decodeAndValidate(
            JSONSerialization.data(withJSONObject: object)
        )
        #expect(try legacy.validatedForPersistence() == legacy)
        #expect(!legacy.effectiveEvidenceEligibility.eligible)
        #expect(legacy.effectiveEvidenceEligibility.reasons.contains(.legacyReportSchema))
        #expect(legacy.effectiveEvidenceEligibility.reasons.contains(.missingProvenance))
        #expect(legacy.effectiveEvidenceEligibility.reasons.contains(.reviewPending))
        #expect(throws: LabEarlyStartReportValidationError.missingDecisionGradeEnvelope) {
            try legacy.reviewed(conclusion: "Legacy evidence stays legacy.", status: .rejected)
        }
    }

    @Test("Missing, forged, dirty, and protocol-drifted v2 evidence fails closed")
    func evidenceIntegrity() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let report = makeDecisionGradeReport()
        var object = try #require(
            JSONSerialization.jsonObject(with: encoder.encode(report)) as? [String: Any]
        )
        object.removeValue(forKey: "evidenceEligibility")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let missing = try decoder.decode(
            LabEarlyStartReport.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(missing.effectiveEvidenceEligibility.reasons.contains(.evidenceDecisionMissing))
        #expect(throws: LabEarlyStartReportValidationError.missingDecisionGradeEnvelope) {
            try missing.validatedForPersistence()
        }

        object["evidenceEligibility"] = ["eligible": true, "reasons": []]
        let forged = try decoder.decode(
            LabEarlyStartReport.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(throws: LabEarlyStartReportValidationError.evidenceDecisionMismatch) {
            try forged.validatedForPersistence()
        }

        object = try #require(
            JSONSerialization.jsonObject(with: encoder.encode(report)) as? [String: Any]
        )
        object["hotSeed"] = 908
        let drifted = try decoder.decode(
            LabEarlyStartReport.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(drifted.effectiveEvidenceEligibility.reasons.contains(.protocolMismatch))
        #expect(throws: LabEarlyStartReportValidationError.evidenceDecisionMismatch) {
            try drifted.validatedForPersistence()
        }

        object = try #require(
            JSONSerialization.jsonObject(with: encoder.encode(report)) as? [String: Any]
        )
        var assets = try #require(object["assets"] as? [String: Any])
        assets["inferenceBackend"] = "codex-subscription"
        object["assets"] = assets
        let backendDrift = try decoder.decode(
            LabEarlyStartReport.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(backendDrift.effectiveEvidenceEligibility.reasons.contains(.protocolMismatch))
        #expect(throws: LabEarlyStartReportValidationError.evidenceDecisionMismatch) {
            try backendDrift.validatedForPersistence()
        }

        let dirty = makeDecisionGradeReport(treeState: .dirty, registered: false)
        #expect(dirty.effectiveEvidenceEligibility.reasons.contains(.dirtySourceTree))
        #expect(dirty.effectiveEvidenceEligibility.reasons.contains(.hypothesisUnregistered))
        #expect(dirty.effectiveEvidenceEligibility.reasons.contains(.protocolMismatch))
    }

    @Test("Q10R rejects report contracts that could retain or transmit text")
    func privacyContract() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var object = try #require(
            JSONSerialization.jsonObject(
                with: encoder.encode(makeDecisionGradeReport())
            ) as? [String: Any]
        )
        object["privacy"] = [
            "aggregateOnly": true,
            "rawScenarioText": false,
            "rawModelOutput": true,
            "filePaths": false,
            "networkInference": false,
        ]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let unsafe = try decoder.decode(
            LabEarlyStartReport.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(unsafe.effectiveEvidenceEligibility.reasons.contains(.unsafePrivacyContract))
        #expect(throws: LabEarlyStartReportValidationError.unsafePrivacyContract) {
            try unsafe.validatedForPersistence()
        }

        object = try #require(
            JSONSerialization.jsonObject(
                with: encoder.encode(makeDecisionGradeReport())
            ) as? [String: Any]
        )
        object["rawPrompt"] = "must never survive decoding"
        #expect(throws: LabEarlyStartReportValidationError.forbiddenRawData("rawPrompt")) {
            try LabEarlyStartReport.decodeAndValidate(
                JSONSerialization.data(withJSONObject: object)
            )
        }

        object.removeValue(forKey: "rawPrompt")
        object["note"] = "/Users/private/report.json"
        #expect(throws: LabEarlyStartReportValidationError.localPath) {
            try LabEarlyStartReport.decodeAndValidate(
                JSONSerialization.data(withJSONObject: object)
            )
        }
    }

    private func makeDecisionGradeReport(
        treeState: LabSourceTreeState = .clean,
        registered: Bool = true
    ) -> LabEarlyStartReport {
        let protocolDefinition = makeProtocol()
        let repeated = measurement(
            charactersToBoundary: 4,
            remainder: "uld ship the release notes",
            cold: generation("uld ship the release", latency: 300, tokens: 10),
            boundary: generation("ship the release", latency: 300, tokens: 10)
        )
        let measurements = Array(
            repeating: repeated,
            count: LabEarlyStartProtocol.expectedOpportunityCount
        )
        let primary = LabEarlyStartAnalyzer.primary(
            measurements: measurements,
            minimumUsefulCharacters: 6
        )
        let pair = LabEarlyStartAnalyzer.pair(
            measurements: measurements,
            minimumUsefulCharacters: 6
        )
        let sensitivity = LabEarlyStartAnalyzer.sensitivity(
            measurements: measurements,
            minimumUsefulCharacters: 6
        )
        let checkedAt = Date(timeIntervalSince1970: 1)
        let provenance = LabReportProvenance(
            capturedAt: checkedAt,
            source: LabReportSourceProvenance(
                gitCommitSHA: String(repeating: "a", count: 40),
                treeState: treeState,
                runnerSHA256: String(repeating: "b", count: 64)
            ),
            environment: LabReportEnvironmentProvenance(
                operatingSystemVersion: "macOS 26.6.2",
                operatingSystemBuild: "25G83",
                hardwareClass: "Mac17,7",
                machine: LabResearchMachineState(
                    powerSourceKnown: true,
                    isOnACPower: true,
                    lowPowerModeEnabled: false,
                    thermalLevel: .nominal,
                    checkedAt: checkedAt
                )
            ),
            invocation: LabReportInvocationProvenance(
                digestSHA256: LabEarlyStartProtocol.expectedInvocationDigestSHA256
            ),
            experiment: registered ? protocolDefinition.experimentRegistration : nil
        )
        let machine = provenance.environment.machine
        return LabEarlyStartReport(
            startedAt: checkedAt,
            finishedAt: Date(timeIntervalSince1970: 2),
            suiteName: "Certified Corpus V2",
            suiteDigestSHA256: LabEarlyStartProtocol.expectedSuiteDigestSHA256,
            situationCount: LabEarlyStartProtocol.expectedSituationCount,
            opportunityCount: LabEarlyStartProtocol.expectedOpportunityCount,
            plannedGenerations: LabEarlyStartProtocol.expectedGenerationCount,
            completedGenerations: LabEarlyStartProtocol.expectedGenerationCount,
            maximumSituations: LabEarlyStartProtocol.expectedSituationCount,
            maximumOpportunitiesPerSituation: 6,
            minimumUsefulCharacters: 6,
            predictionTokens: 12,
            arm: protocolDefinition.arm,
            protocolDefinition: protocolDefinition,
            assets: LabAssetSnapshot(
                modelIdentifier: ProductionModelAsset.identifier,
                modelRevision: ProductionModelAsset.revision,
                modelSHA256: ProductionModelAsset.sha256,
                helperSHA256: LabEarlyStartProtocol.expectedHelperSHA256
            ),
            execution: protocolDefinition.execution,
            startingThermalState: "nominal",
            worstThermalState: "nominal",
            startingMachineState: machine,
            finishingMachineState: machine,
            primary: primary,
            pair: pair,
            sensitivity: sensitivity,
            provenance: provenance
        )
    }

    private func makeProtocol() -> LabEarlyStartProtocol {
        var arm = LabArmConfiguration(
            id: "baseline-v2",
            temperature: 0,
            predictionTokens: 12,
            maxVisibleWords: 3,
            includesScene: true,
            suppressesSensitiveScenes: true
        )
        arm.scenarios.partition = .development
        arm.generation.requestMode = .productionStreaming
        arm.prompt.includesIntentFutures = true
        arm.id = "q10-early-start-k1"
        arm.generation.predictionTokens = 12
        arm.generation.requestMode = .finalResponse
        arm.generation.cachePrompt = false
        arm.prompt.includesIntentFutures = true
        arm.judgment.maximumVisibleWords = 3
        arm.judgment.maximumVisibleCharacters = 48
        arm.scenarios = LabScenarioVariationConfiguration(
            partition: .development,
            suggestionExpectation: .speakOnly,
            maximumDistinctSituations: LabEarlyStartProtocol.expectedSituationCount
        )
        let execution = LabRuntimeConfiguration(
            workerCount: 1,
            slotsPerWorker: 1,
            repetitions: 1,
            contextSizePerSlot: 4_096,
            cacheReuseTokens: 0,
            timeoutSeconds: 120,
            seed: 0x5449_4C44_454C_4142,
            promptCaching: false
        ).materialize(
            serverExecutable: URL(fileURLWithPath: "/not-retained/helper"),
            modelFile: URL(fileURLWithPath: "/not-retained/model")
        )
        return LabEarlyStartProtocol(arm: arm, execution: execution)
    }

    private func generation(
        _ text: String,
        latency: Int,
        tokens: Int
    ) -> LabEarlyStartGeneration {
        LabEarlyStartGeneration(
            text: text,
            rawContinuation: text,
            latencyMilliseconds: latency,
            decodedTokens: tokens
        )
    }

    private func measurement(
        charactersToBoundary: Int,
        remainder: String,
        cold: LabEarlyStartGeneration,
        hot: LabEarlyStartGeneration? = nil,
        boundary: LabEarlyStartGeneration
    ) -> LabEarlyStartMeasurement {
        LabEarlyStartMeasurement(
            cut: LabEarlyStartCut(
                cutOffset: 3,
                charactersToBoundary: charactersToBoundary,
                charactersAfterBoundary: max(0, remainder.count - charactersToBoundary)
            ),
            remainderAfterCut: remainder,
            cold: cold,
            hot: hot ?? cold,
            boundary: boundary
        )
    }
}
