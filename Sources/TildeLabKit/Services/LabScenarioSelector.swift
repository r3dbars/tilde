import Foundation

public enum LabScenarioSelector {
    public static func select(
        from suite: LabScenarioSuite,
        configuration: LabScenarioVariationConfiguration
    ) -> LabScenarioSuite {
        let selected = suite.scenarios.filter { scenario in
            matchesPartition(scenario, configuration: configuration)
                && matchesExpectation(scenario, configuration: configuration)
                && matchesStructuredAxes(scenario, configuration: configuration)
                && matchesRegister(scenario, configuration: configuration)
                && matchesTags(scenario, configuration: configuration)
        }
        let limited = limitDistinctSituations(selected, configuration: configuration)
        return LabScenarioSuite(
            name: suite.name + (configuration.partition == .all ? "" : " - \(configuration.partition.title)"),
            scenarios: limited
        )
    }

    private static func matchesPartition(
        _ scenario: LabScenario,
        configuration: LabScenarioVariationConfiguration
    ) -> Bool {
        configuration.partition == .all || scenario.partition == configuration.partition
    }

    private static func matchesExpectation(
        _ scenario: LabScenario,
        configuration: LabScenarioVariationConfiguration
    ) -> Bool {
        switch configuration.suggestionExpectation ?? .all {
        case .all: true
        case .speakOnly: scenario.expectation.shouldSuggest
        case .silenceOnly: !scenario.expectation.shouldSuggest
        }
    }

    private static func limitDistinctSituations(
        _ scenarios: [LabScenario],
        configuration: LabScenarioVariationConfiguration
    ) -> [LabScenario] {
        guard let limit = configuration.maximumDistinctSituations else { return scenarios }
        var orderedRoots: [String] = []
        var seenRoots = Set<String>()
        for scenario in scenarios {
            let root = scenario.evaluation.rootScenarioID ?? scenario.id
            if seenRoots.insert(root).inserted { orderedRoots.append(root) }
        }
        guard orderedRoots.count > limit else { return scenarios }

        // A cap is a breadth-oriented smoke sample, not "the first N rows."
        // Even spacing reaches the beginning, middle, and end of a structured
        // corpus without relying on Swift's process-randomized Hashable order.
        let allowedRoots = Set((0..<limit).map { sampleIndex in
            let scaled = (Double(sampleIndex) + 0.5) * Double(orderedRoots.count) / Double(limit)
            return orderedRoots[min(orderedRoots.count - 1, Int(scaled))]
        })
        return scenarios.filter {
            allowedRoots.contains($0.evaluation.rootScenarioID ?? $0.id)
        }
    }

    private static func matchesStructuredAxes(
        _ scenario: LabScenario,
        configuration: LabScenarioVariationConfiguration
    ) -> Bool {
        (scenario.intent.map(configuration.intents.contains) ?? true)
            && (scenario.tone.map(configuration.tones.contains) ?? true)
            && configuration.languages.contains(where: {
                $0.caseInsensitiveCompare(scenario.language) == .orderedSame
            })
    }

    private static func matchesRegister(
        _ scenario: LabScenario,
        configuration: LabScenarioVariationConfiguration
    ) -> Bool {
        if scenario.scene?.mode == .replying { return configuration.includesChat }
        let bundle = scenario.appBundleIdentifier?.lowercased() ?? ""
        if bundle.contains("mail") || bundle.contains("outlook") || bundle.contains("mimestream") {
            return configuration.includesEmail
        }
        return configuration.includesProse
    }

    private static func matchesTags(
        _ scenario: LabScenario,
        configuration: LabScenarioVariationConfiguration
    ) -> Bool {
        let tags = Set(scenario.tags)
        let rules: [(String, Bool)] = [
            ("mid-word", configuration.includesMidWord),
            ("word-boundary", configuration.includesWordBoundary),
            ("typo", configuration.includesTypos),
            ("long-context", configuration.includesLongContext),
            ("ambiguous", configuration.includesAmbiguity),
            ("multiple-questions", configuration.includesMultipleQuestions),
            ("contradiction", configuration.includesContradictions),
            ("stale-context", configuration.includesStaleContext),
            ("irrelevant-context", configuration.includesIrrelevantContext),
            ("name", configuration.includesNames),
            ("date", configuration.includesDates),
            ("time", configuration.includesTimes),
            ("location", configuration.includesLocations),
            ("quantity", configuration.includesQuantities),
            ("deadline", configuration.includesDeadlines),
            ("sensitive", configuration.includesSensitiveCases),
            ("sensitive-near-miss", configuration.includesSensitiveNearMisses),
            ("prompt-injection", configuration.includesPromptInjection),
            ("counterfactual", configuration.includesCounterfactualPairs),
        ]
        return rules.allSatisfy { tag, enabled in !tags.contains(tag) || enabled }
    }
}
