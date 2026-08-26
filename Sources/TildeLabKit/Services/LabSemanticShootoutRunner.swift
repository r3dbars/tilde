import Foundation

public enum LabSemanticShootoutError: Error, LocalizedError, Sendable {
    case unsafeSuite
    case mismatchedCandidates
    case malformedJudgment

    public var errorDescription: String? {
        switch self {
        case .unsafeSuite:
            "Semantic judging accepts only the project-owned synthetic Certified Corpus V2 development slice."
        case .mismatchedCandidates:
            "The two models did not produce a complete, matching candidate set."
        case .malformedJudgment:
            "The semantic referee returned an incomplete judgment set. No prompt or candidate text was retained."
        }
    }
}

public actor LabSemanticShootoutRunner {
    private let judge: any LabSemanticJudgeBatchClient

    public init(judge: any LabSemanticJudgeBatchClient = LabCodexSubscriptionClient()) {
        self.judge = judge
    }

    public func run(
        suite: LabScenarioSuite,
        arm: LabArmConfiguration,
        localReport: LabRunReport,
        frontierReport: LabRunReport,
        localCandidates: [String: String?],
        frontierCandidates: [String: String?],
        judgeModel: String = "gpt-5.6-sol",
        batchSize: Int = 25,
        timeoutSecondsPerBatch: Double = 300
    ) async throws -> LabSemanticShootoutReport {
        let selected = LabScenarioSelector.select(from: suite, configuration: arm.scenarios)
        try selected.validated()
        guard !selected.scenarios.isEmpty,
              selected.scenarios.count <= 200,
              selected.scenarios.allSatisfy({ scenario in
                  scenario.evaluation.source == .synthetic
                      && scenario.evaluation.corpusID == LabCorpusRegistry.tildeCertifiedV2.id
                      && scenario.partition == .development
                      && scenario.expectation.shouldSuggest
              }) else {
            throw LabSemanticShootoutError.unsafeSuite
        }
        let scenarioIDs = Set(selected.scenarios.map(\.id))
        guard Set(localCandidates.keys) == scenarioIDs,
              Set(frontierCandidates.keys) == scenarioIDs,
              Set(localReport.cases.map(\.scenarioID)) == scenarioIDs,
              Set(frontierReport.cases.map(\.scenarioID)) == scenarioIDs,
              (1...50).contains(batchSize),
              (30...900).contains(timeoutSecondsPerBatch) else {
            throw LabSemanticShootoutError.mismatchedCandidates
        }

        _ = try await judge.verifySubscription(model: judgeModel)
        let ordered = selected.scenarios.sorted { $0.id < $1.id }
        var swaps: [String: Bool] = [:]
        let items = ordered.enumerated().map { index, scenario in
            let swapped = !index.isMultiple(of: 2)
            swaps[scenario.id] = swapped
            let local = localCandidates[scenario.id] ?? nil
            let frontier = frontierCandidates[scenario.id] ?? nil
            let prompt = LabPromptComposer.prepare(scenario: scenario, configuration: arm.prompt).prompt
            return LabSemanticJudgePromptItem(
                id: scenario.id,
                prompt: prompt,
                candidateA: swapped ? frontier : local,
                candidateB: swapped ? local : frontier
            )
        }

        var judgments: [String: LabSemanticPairJudgment] = [:]
        for start in stride(from: 0, to: items.count, by: batchSize) {
            try Task.checkCancellation()
            let end = min(items.count, start + batchSize)
            let response = try await judge.judge(
                items: Array(items[start..<end]),
                model: judgeModel,
                timeoutSeconds: timeoutSecondsPerBatch
            )
            for judgment in response {
                guard judgments[judgment.id] == nil else {
                    throw LabSemanticShootoutError.malformedJudgment
                }
                judgments[judgment.id] = judgment
            }
        }
        guard Set(judgments.keys) == scenarioIDs else {
            throw LabSemanticShootoutError.malformedJudgment
        }

        var localScores: [LabSemanticScores] = []
        var frontierScores: [LabSemanticScores] = []
        for scenario in ordered {
            guard let judgment = judgments[scenario.id],
                  let swapped = swaps[scenario.id] else {
                throw LabSemanticShootoutError.malformedJudgment
            }
            localScores.append(swapped ? judgment.candidateB : judgment.candidateA)
            frontierScores.append(swapped ? judgment.candidateA : judgment.candidateB)
        }
        return LabSemanticShootoutReport(
            scenarioCount: ordered.count,
            judgeModel: judgeModel,
            first: LabSemanticJudgeScorer.summarize(
                modelIdentifier: localReport.assets.modelIdentifier,
                strictReport: localReport,
                scores: localScores
            ),
            second: LabSemanticJudgeScorer.summarize(
                modelIdentifier: frontierReport.assets.modelIdentifier,
                strictReport: frontierReport,
                scores: frontierScores
            )
        )
    }

    public func cancel() async {
        await judge.cancel()
    }
}
