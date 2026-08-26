import Foundation

/// Creates a development set that is approximately 60% real replay and 40%
/// curated synthetic coverage, while keeping validation and holdout entirely
/// protected and synthetic until historical temporal integrity can be proven.
public enum LabMixedLearningSuiteFactory {
    public static func make(
        historical: LabScenarioSuite,
        protected: LabScenarioSuite
    ) throws -> LabScenarioSuite {
        let protectedDevelopment = protected.scenarios.filter { $0.partition == .development }
        let protectedFinal = protected.scenarios.filter {
            $0.partition == .validation || $0.partition == .holdout
        }
        let availableHistory = historical.scenarios.filter { $0.partition == .development }
        let idealHistoryCount = Int(ceil(Double(protectedDevelopment.count) * 1.5))
        let selectedHistory = Array(availableHistory.prefix(idealHistoryCount))
        let allowedSyntheticCount = selectedHistory.isEmpty
            ? protectedDevelopment.count
            : min(protectedDevelopment.count, Int(floor(Double(selectedHistory.count) * 2.0 / 3.0)))
        let selectedSynthetic = Array(protectedDevelopment.prefix(allowedSyntheticCount))
        return try LabScenarioSuite(
            name: "Mixed Learning 60 real 40 synthetic",
            scenarios: selectedHistory + selectedSynthetic + protectedFinal
        ).validated()
    }
}
