import Testing
@testable import AutocompleteLabCore

@Suite("Experiment planning")
struct ExperimentPlanTests {
    @Test("Counterbalanced crossover keeps a deterministic within-user order")
    func counterbalancedCrossoverOrderIsDeterministic() {
        let first = AutocompleteExperimentPlanner.withinUserCrossoverPlan(
            testerIdentifier: "tester-a",
            sessionsPerArm: 2
        )
        let second = AutocompleteExperimentPlanner.withinUserCrossoverPlan(
            testerIdentifier: "tester-a",
            sessionsPerArm: 2
        )

        #expect(first == second)
        #expect(first.phases.count == 4)
        #expect(Set(first.armOrder) == Set([.length1Word, .length3Word]))
        #expect(first.armOrder[0] == first.armOrder[2])
        #expect(first.armOrder[1] == first.armOrder[3])
    }

    @Test("Tiny experiment samples are directional instead of winners")
    func tinySamplesAreDirectional() {
        let events = [
            event(.suggestionPresented, arm: "length_1_word", suggestionID: "one", latency: 80),
            event(.suggestionAccepted, arm: "length_1_word", suggestionID: "one"),
            event(
                .acceptedTextEdited,
                arm: "length_1_word",
                suggestionID: "one",
                metadata: [
                    "checkpoint": "10s",
                    "survivalClass": "exactKept",
                    "strongAcceptedAndKept": "true"
                ]
            )
        ]

        let outcomes = AutocompleteExperimentPlanner.outcomes(
            for: events,
            thresholds: AutocompleteExperimentGuardrailThresholds(minimumShownSamples: 5)
        )

        #expect(outcomes.first?.label == .directional)
        #expect(outcomes.first?.label.treatsAsWinner == false)
        #expect(outcomes.first?.guardrails.reasons.contains("sample is below 5; treat as directional") == true)
    }

    @Test("Guardrails block slow or annoying arms")
    func guardrailsBlockRiskyArms() {
        let events = [
            event(.suggestionPresented, arm: "length_3_word", suggestionID: "one", latency: 1_200),
            event(.suggestionPresented, arm: "length_3_word", suggestionID: "two", latency: 1_300),
            event(.suggestionPresented, arm: "length_3_word", suggestionID: "three", latency: 1_500),
            event(.insertionVerified, arm: "length_3_word", suggestionID: "one"),
            event(
                .insertionFailed,
                arm: "length_3_word",
                suggestionID: "two",
                reason: "duplicate insertion",
                metadata: ["duplicateDetected": "true"]
            ),
            event(.appDisabled, arm: "length_3_word", suggestionID: "app", reason: "manual")
        ]

        let outcome = AutocompleteExperimentPlanner.outcomes(
            for: events,
            thresholds: AutocompleteExperimentGuardrailThresholds(
                minimumShownSamples: 3,
                maximumP95LatencyMilliseconds: 1_000,
                minimumInsertionSuccessRate: 0.95,
                maximumDuplicateRate: 0,
                maximumAppDisableRate: 0
            )
        ).first

        #expect(outcome?.label == .guardrailBlocked)
        #expect(outcome?.guardrails.passed == false)
        #expect(outcome?.guardrails.reasons.contains { $0.contains("p95 first-visible latency") } == true)
        #expect(outcome?.guardrails.reasons.contains { $0.contains("insertion success") } == true)
        #expect(outcome?.guardrails.reasons.contains { $0.contains("duplicate rate") } == true)
        #expect(outcome?.guardrails.reasons.contains { $0.contains("app disable rate") } == true)
    }

    private func event(
        _ type: AutocompleteTraceEventType,
        arm: String,
        suggestionID: String,
        latency: Int? = nil,
        reason: String = "",
        metadata: [String: String] = [:]
    ) -> AutocompleteTraceEvent {
        AutocompleteTraceEvent(
            experimentArm: arm,
            timestamp: "2026-05-07T00:00:00Z",
            sessionID: "session",
            suggestionID: suggestionID,
            type: type,
            appBundleIdentifier: "com.apple.TextEdit",
            requestMode: "phraseContinuation",
            latencyMilliseconds: latency,
            reason: reason,
            metadata: metadata
        )
    }
}
