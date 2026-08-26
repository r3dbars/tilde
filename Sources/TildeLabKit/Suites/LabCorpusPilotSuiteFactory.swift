import Foundation

public enum LabCorpusPilotSuiteFactory {
    public static let taskmasterRootCount = 600
    public static let syntheticRootCount = 400
    public static let totalRootCount = taskmasterRootCount + syntheticRootCount

    public static func make(
        taskmasterSourceURL: URL = LabCorpusRegistry.defaultTaskmasterSourceURL,
        taskmasterDescriptor: LabCorpusDescriptor = LabCorpusRegistry.taskmaster1
    ) throws -> LabCorpusPilot {
        let taskmaster = try LabTaskmasterAdapter.loadScenarios(
            from: taskmasterSourceURL,
            descriptor: taskmasterDescriptor,
            limit: taskmasterRootCount
        )
        let synthetic = LabCorpusSyntheticSuiteFactory.makeScenarios()
        guard synthetic.count == syntheticRootCount else {
            throw LabCorpusError.insufficientEligibleSituations(
                expected: syntheticRootCount,
                actual: synthetic.count
            )
        }

        let scenarios = taskmaster + synthetic
        var roots = Set<String>()
        for scenario in scenarios {
            let root = scenario.evaluation.rootScenarioID ?? scenario.id
            guard roots.insert(root).inserted else {
                throw LabCorpusError.duplicateRoot(root)
            }
        }
        guard roots.count == totalRootCount else {
            throw LabCorpusError.insufficientEligibleSituations(
                expected: totalRootCount,
                actual: roots.count
            )
        }

        let suite = try LabScenarioSuite(
            name: "Tilde Corpus Pilot V1 1000 roots",
            scenarios: scenarios
        ).validated()
        return LabCorpusPilot(
            suite: suite,
            descriptors: [taskmasterDescriptor, LabCorpusRegistry.tildeSyntheticPilot]
        )
    }
}
