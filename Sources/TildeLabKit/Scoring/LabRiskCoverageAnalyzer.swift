import TildeCore
import Foundation

public enum LabRiskCoverageError: Error, LocalizedError, Equatable, Sendable {
    case nonSyntheticScenario
    case reportFingerprintMismatch
    case missingCachedCandidate(String)
    case incompleteProbabilityEvidence(String)
    case invalidThresholds

    public var errorDescription: String? {
        switch self {
        case .nonSyntheticScenario:
            "Complete risk-coverage replay is available only for project-owned synthetic scenarios."
        case .reportFingerprintMismatch:
            "Risk-coverage replay does not match the report arm or selected suite digest."
        case let .missingCachedCandidate(id):
            "Synthetic candidate cache is missing required scenario \(id); resume the campaign first."
        case let .incompleteProbabilityEvidence(id):
            "Scenario \(id) has no token-probability evidence; rerun with probabilityCount enabled."
        case .invalidThresholds:
            "Risk-coverage thresholds must be unique finite values in the closed interval 0...1."
        }
    }
}

/// Re-scores synthetic raw candidates already in the explicit local cache.
/// Raw prompt/candidate text remains inside this call and is never represented
/// in the returned aggregate artifact.
public enum LabRiskCoverageAnalyzer {
    public static func completeSyntheticReplay(
        report: LabRunReport,
        suite: LabScenarioSuite,
        protocolDefinition: LabResearchProtocol,
        runtime: LabRuntimeConfiguration,
        cache: LabSyntheticCandidateCache,
        trustLimit: Double = 0.01,
        thresholds: [Double] = stride(from: 0.0, through: 1.0, by: 0.025).map { $0 }
    ) async throws -> LabRiskCoverageReport {
        guard !thresholds.isEmpty,
              Set(thresholds).count == thresholds.count,
              thresholds.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
            throw LabRiskCoverageError.invalidThresholds
        }
        let selected = try LabResearchScenarioSelection.select(
            from: suite,
            configuration: report.arm.scenarios,
            phase: protocolDefinition.phase
        )
        guard try selected.digestSHA256() == report.suiteDigestSHA256,
              selected.scenarios.allSatisfy({ $0.evaluation.source == .synthetic }),
              protocolDefinition.fixedGenerationSeeds.count > 0 else {
            if !selected.scenarios.allSatisfy({ $0.evaluation.source == .synthetic }) {
                throw LabRiskCoverageError.nonSyntheticScenario
            }
            throw LabRiskCoverageError.reportFingerprintMismatch
        }
        let expectedCaseCount = selected.scenarios.count
            * runtime.repetitions * protocolDefinition.fixedGenerationSeeds.count
        guard report.cases.count == expectedCaseCount else {
            throw LabRiskCoverageError.reportFingerprintMismatch
        }

        var observations: [ReplayObservation] = []
        observations.reserveCapacity(expectedCaseCount)
        for seed in protocolDefinition.fixedGenerationSeeds {
            for repetition in 0..<runtime.repetitions {
                for scenario in selected.scenarios {
                    let prepared = LabPromptComposer.prepare(
                        scenario: scenario,
                        configuration: report.arm.prompt
                    )
                    if let reason = SceneSuggestionPolicy.suppressionReason(
                        scene: prepared.scene
                    ) {
                        observations.append(ReplayObservation(
                            scenario: scenario,
                            repetition: repetition,
                            seed: seed,
                            preparedPrompt: nil,
                            response: nil,
                            fixedReason: .sceneSuppression(reason)
                        ))
                        continue
                    }
                    if report.arm.suppressesSensitiveScenes,
                       SensitiveScenePolicy.isSensitive(scene: prepared.scene) {
                        observations.append(ReplayObservation(
                            scenario: scenario,
                            repetition: repetition,
                            seed: seed,
                            preparedPrompt: nil,
                            response: nil,
                            fixedReason: .sensitiveScene
                        ))
                        continue
                    }
                    guard !prepared.prompt.isEmpty else {
                        observations.append(ReplayObservation(
                            scenario: scenario,
                            repetition: repetition,
                            seed: seed,
                            preparedPrompt: nil,
                            response: nil,
                            fixedReason: .emptyPrompt
                        ))
                        continue
                    }
                    var generation = report.arm.generation
                    generation.seed = seed
                    let key = try LabCandidateCacheKey(
                        modelSHA256: report.assets.modelSHA256,
                        helperSHA256: report.assets.helperSHA256,
                        prompt: prepared.prompt,
                        generation: generation,
                        scenario: scenario
                    )
                    guard let cached = try await cache.value(for: key) else {
                        throw LabRiskCoverageError.missingCachedCandidate(scenario.id)
                    }
                    guard cached.meanTokenProbability != nil else {
                        throw LabRiskCoverageError.incompleteProbabilityEvidence(scenario.id)
                    }
                    observations.append(ReplayObservation(
                        scenario: scenario,
                        repetition: repetition,
                        seed: seed,
                        preparedPrompt: prepared,
                        response: cached.modelResponse,
                        fixedReason: nil
                    ))
                }
            }
        }

        let orderedThresholds = thresholds.sorted()
        let evaluated = orderedThresholds.map { threshold -> ThresholdEvaluation in
            var arm = report.arm
            arm.generation.minimumMeanTokenProbability = threshold
            let cases = observations.map { observation in
                score(observation, arm: arm)
            }
            return ThresholdEvaluation(threshold: threshold, cases: cases)
        }
        let points = evaluated.map {
            point(threshold: $0.threshold, cases: $0.cases, utility: protocolDefinition.utility)
        }
        let sliceNames = Set(selected.scenarios.flatMap(sliceLabels)).sorted()
        let slices = sliceNames.map { label -> LabRiskCoverageSliceReport in
            let scenarioIDs = Set(selected.scenarios.filter {
                sliceLabels($0).contains(label)
            }.map(\.id))
            let slicePoints = evaluated.map { evaluation in
                point(
                    threshold: evaluation.threshold,
                    cases: evaluation.cases.filter { scenarioIDs.contains($0.scenarioID) },
                    utility: protocolDefinition.utility
                )
            }
            return LabRiskCoverageSliceReport(
                slice: label,
                opportunities: evaluated.first?.cases.count {
                    scenarioIDs.contains($0.scenarioID)
                } ?? 0,
                points: slicePoints,
                highestCoverageUnderTrustLimit: trustedPoint(
                    slicePoints, trustLimit: trustLimit
                )
            )
        }
        return LabRiskCoverageReport(
            schema: LabRiskCoverageReport.currentSchema,
            sourceReportID: report.id,
            sourceArmID: report.arm.id,
            trustLimit: trustLimit,
            eligibleOpportunities: expectedCaseCount,
            scoredCandidateCount: observations.count { $0.response != nil },
            points: points,
            slices: slices,
            highestCoverageUnderTrustLimit: trustedPoint(points, trustLimit: trustLimit),
            completeCandidateReplay: true,
            limitation: "Complete synthetic cache replay. Confidence thresholds are evaluated without new inference; calibration against accepted live behavior still requires local dogfood events."
        )
    }

    private static func score(
        _ observation: ReplayObservation,
        arm: LabArmConfiguration
    ) -> LabCaseResult {
        guard let response = observation.response,
              let prepared = observation.preparedPrompt else {
            return LabScorer.score(
                scenario: observation.scenario,
                repetition: observation.repetition,
                generationSeed: observation.seed,
                suggestion: nil,
                policySuppressed: observation.fixedReason != nil
                    && observation.fixedReason != .emptyPrompt,
                decisionReason: observation.fixedReason ?? .emptyPrompt,
                candidateCacheHit: true
            )
        }
        let decision = LabOutputJudge.judge(
            rawOutput: response.content,
            preparedPrompt: prepared,
            scenario: observation.scenario,
            configuration: arm,
            meanTokenProbability: response.meanTokenProbability
        )
        return LabScorer.score(
            scenario: observation.scenario,
            repetition: observation.repetition,
            generationSeed: observation.seed,
            suggestion: decision.suggestion,
            modelRequested: true,
            latencyMilliseconds: response.latencyMilliseconds,
            firstTokenMilliseconds: response.firstTokenMilliseconds,
            meanTokenProbability: response.meanTokenProbability,
            decisionReason: decision.reason,
            candidateCacheHit: true
        )
    }

    private static func point(
        threshold: Double,
        cases: [LabCaseResult],
        utility: LabUtilityConfiguration
    ) -> LabRiskCoveragePoint {
        let selective = LabSelectivePredictionMetrics(cases: cases, utility: utility)
        let shown = cases.filter(\.offered)
        let bad = shown.count { $0.outcome == .wrong || $0.outcome == .unwanted }
        return LabRiskCoveragePoint(
            threshold: threshold,
            coverage: selective.showRate,
            precisionWhenShown: selective.precisionWhenShown,
            badWhenShown: selective.badWhenShown,
            badWhenShownUpper95Wilson: LabRareEventBound(
                events: bad, opportunities: shown.count
            ).upper95Wilson,
            usefulCoverage: selective.usefulCoverage,
            expectedUtilityMillisecondsPer1000Characters:
                selective.expectedUtilityMillisecondsPer1000Characters,
            shown: shown.count,
            meanVisibleCharacters: shown.isEmpty ? 0
                : Double(shown.reduce(0) { $0 + $1.visibleCharacterCount }) / Double(shown.count),
            meanVisibleWords: shown.isEmpty ? 0
                : Double(shown.reduce(0) { $0 + $1.visibleWordCount }) / Double(shown.count)
        )
    }

    private static func trustedPoint(
        _ points: [LabRiskCoveragePoint],
        trustLimit: Double
    ) -> LabRiskCoveragePoint? {
        points.filter {
            $0.shown > 0 && $0.badWhenShownUpper95Wilson <= trustLimit
        }.max { lhs, rhs in
            if lhs.coverage == rhs.coverage {
                return lhs.expectedUtilityMillisecondsPer1000Characters
                    < rhs.expectedUtilityMillisecondsPer1000Characters
            }
            return lhs.coverage < rhs.coverage
        }
    }

    private static func sliceLabels(_ scenario: LabScenario) -> [String] {
        let category = scenario.category.split(separator: ".").prefix(2).joined(separator: ".")
        let register: String
        if scenario.scene?.mode == .replying {
            register = "chat"
        } else if (scenario.appBundleIdentifier ?? "").lowercased().contains("mail") {
            register = "email"
        } else {
            register = "prose"
        }
        let boundary = scenario.tags.contains("mid-word") ? "mid-word" : "word-boundary"
        return [
            "category:\(category)",
            "register:\(register)",
            "boundary:\(boundary)",
            "context:\(scenario.evaluation.contextVariant.rawValue)",
        ]
    }

    private struct ReplayObservation {
        let scenario: LabScenario
        let repetition: Int
        let seed: Int
        let preparedPrompt: LabPreparedPrompt?
        let response: LabModelResponse?
        let fixedReason: LabDecisionReason?
    }

    private struct ThresholdEvaluation {
        let threshold: Double
        let cases: [LabCaseResult]
    }
}
