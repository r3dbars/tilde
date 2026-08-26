import Foundation

public enum LabCorpusCertificationError: Error, LocalizedError, Sendable {
    case staticGateFailed
    case incompleteReports
    case invalidExecution

    public var errorDescription: String? {
        switch self {
        case .staticGateFailed:
            "The corpus must pass every static quality and review gate before model certification."
        case .incompleteReports:
            "The context certification did not produce all three required reports."
        case .invalidExecution:
            "Corpus certification is a fixed 3,000-completion protocol with exactly one repetition."
        }
    }
}

public enum LabCorpusModelCertifier {
    public static func certify(
        suite: LabScenarioSuite,
        baseline: LabArmConfiguration,
        execution: LabExecutionConfiguration,
        runner: LabExperimentRunner,
        progress: @escaping LabExperimentRunner.ProgressHandler = { _ in }
    ) async throws -> LabCorpusModelCertificate {
        let quality = try LabCorpusQualityAuditor.auditCertifiedV2(suite: suite)
        guard quality.passesStaticGate else {
            throw LabCorpusCertificationError.staticGateFailed
        }
        guard execution.repetitions == 1 else {
            throw LabCorpusCertificationError.invalidExecution
        }

        var correctArm = baseline
        correctArm.id = "corpus-cert-correct-context"
        correctArm.prompt.includesScene = true
        correctArm.scenarios.partition = .all

        var typedArm = baseline
        typedArm.id = "corpus-cert-typed-only"
        typedArm.prompt.includesScene = false
        typedArm.scenarios.partition = .all

        let firstReports = try await runner.runMatrix(
            suite: suite,
            arms: [correctArm, typedArm],
            execution: execution,
            protocolRetryCount: 2,
            restartWorkers: true,
            stopWorkersAfterRun: false,
            progress: { update in
                await progress(certificateProgress(update, offset: 0, armIndexOffset: 0))
            }
        )
        guard firstReports.count == 2 else {
            throw LabCorpusCertificationError.incompleteReports
        }

        var wrongArm = baseline
        wrongArm.id = "corpus-cert-wrong-context"
        wrongArm.prompt.includesScene = true
        wrongArm.scenarios.partition = .all
        let wrongSuite = try LabCorpusFalsificationSuiteFactory.wrongContext(suite)
        let wrongReport = try await runner.run(
            suite: wrongSuite,
            arm: wrongArm,
            execution: execution,
            protocolRetryCount: 2,
            restartWorkers: false,
            stopWorkersAfterRun: true,
            progress: { update in
                await progress(certificateProgress(update, offset: 2_000, armIndexOffset: 2))
            }
        )

        let correctReport = firstReports[0]
        let typedReport = firstReports[1]
        let rootPartitions = Dictionary(uniqueKeysWithValues: suite.scenarios.map {
            ($0.evaluation.rootScenarioID ?? $0.id, $0.partition)
        })
        let protectedPartitions: [LabScenarioPartition] = [
            .development, .validation, .holdout,
        ]
        let partitions: [LabCorpusPartitionContextResult] = protectedPartitions.map { partition in
            let correct = metrics(correctReport, partition: partition, roots: rootPartitions)
            let typed = metrics(typedReport, partition: partition, roots: rootPartitions)
            let wrong = metrics(wrongReport, partition: partition, roots: rootPartitions)
            return LabCorpusPartitionContextResult(
                partition: partition,
                correctExactMatchAt1Rate: correct.exactMatchAt1Rate,
                typedOnlyExactMatchAt1Rate: typed.exactMatchAt1Rate,
                wrongContextExactMatchAt1Rate: wrong.exactMatchAt1Rate
            )
        }
        return LabCorpusModelCertificate(
            corpusID: LabCorpusRegistry.tildeCertifiedV2.id,
            corpusDigestSHA256: quality.corpusDigestSHA256,
            modelSHA256: correctReport.assets.modelSHA256,
            helperSHA256: correctReport.assets.helperSHA256,
            armID: baseline.id,
            correctContext: LabCorpusContextMetrics(metrics: correctReport.metrics),
            typedOnly: LabCorpusContextMetrics(metrics: typedReport.metrics),
            wrongContext: LabCorpusContextMetrics(metrics: wrongReport.metrics),
            partitions: partitions
        )
    }

    private static func metrics(
        _ report: LabRunReport,
        partition: LabScenarioPartition,
        roots: [String: LabScenarioPartition]
    ) -> LabAggregateMetrics {
        let cases = report.cases.filter {
            roots[$0.rootScenarioID ?? $0.scenarioID] == partition
        }
        return LabScorer.aggregate(
            cases,
            elapsedSeconds: 1,
            scoring: report.arm.scoring
        )
    }

    private static func certificateProgress(
        _ update: LabRunProgress,
        offset: Int,
        armIndexOffset: Int
    ) -> LabRunProgress {
        LabRunProgress(
            phase: update.phase,
            completed: update.phase == .running || update.phase == .finalizing || update.phase == .stopping
                ? min(3_000, offset + update.completed)
                : offset,
            total: 3_000,
            armIndex: min(2, armIndexOffset + update.armIndex),
            armCount: 3,
            armID: update.armID
        )
    }
}
