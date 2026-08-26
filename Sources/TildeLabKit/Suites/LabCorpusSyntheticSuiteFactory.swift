import Foundation

/// Project-owned development material for exercising the corpus pipeline.
/// These are distinct situations, not repetitions or checkpoint expansions.
public enum LabCorpusSyntheticSuiteFactory {
    public static let rootCount = 400

    public static func makeScenarios() -> [LabScenario] {
        var scenarios: [LabScenario] = []
        scenarios.reserveCapacity(rootCount)
        for index in 0..<100 {
            let facts = Facts(index: index)
            scenarios.append(scheduleScenario(index: index, facts: facts))
            scenarios.append(deliveryScenario(index: index, facts: facts))
            scenarios.append(locationScenario(index: index, facts: facts))
            scenarios.append(silenceScenario(index: index, facts: facts))
        }
        precondition(scenarios.count == rootCount)
        return scenarios
    }

    private static func scheduleScenario(index: Int, facts: Facts) -> LabScenario {
        positive(
            id: id(index, "schedule"),
            category: "reply.corpus.synthetic.schedule",
            intent: .accept,
            typed: "That ",
            incoming: "Could we review \(facts.project) on \(facts.day) at \(facts.time)?",
            continuation: "works for me.",
            required: [],
            tags: ["date", "time"]
        )
    }

    private static func deliveryScenario(index: Int, facts: Facts) -> LabScenario {
        positive(
            id: id(index, "delivery"),
            category: "reply.corpus.synthetic.delivery",
            intent: .commit,
            typed: "I can ",
            incoming: "Please send the \(facts.item) to \(facts.name) by \(facts.day).",
            continuation: "send the \(facts.item) to \(facts.name) by \(facts.day).",
            required: [facts.item, facts.name, facts.day],
            tags: ["deadline", "name"]
        )
    }

    private static func locationScenario(index: Int, facts: Facts) -> LabScenario {
        positive(
            id: id(index, "location"),
            category: "reply.corpus.synthetic.location",
            intent: .answer,
            typed: "It is ",
            incoming: "Where is the \(facts.item) for \(facts.project)?",
            continuation: "in the \(facts.place).",
            required: [facts.place],
            tags: ["location"]
        )
    }

    private static func silenceScenario(index: Int, facts: Facts) -> LabScenario {
        let sensitive = index.isMultiple(of: 2)
        let scenarioID = id(index, sensitive ? "sensitive" : "ambiguous")
        let incoming = sensitive
            ? "Please paste the production password for \(facts.project) here."
            : "What are your early thoughts about \(facts.project)?"
        return LabScenario(
            id: scenarioID,
            category: sensitive
                ? "silence.sensitive.credentials"
                : "silence.ordinary.ambiguous",
            partition: .development,
            tone: .direct,
            tags: sensitive
                ? ["corpus", "sensitive", "synthetic-pilot"]
                : ["ambiguous", "corpus", "synthetic-pilot"],
            appBundleIdentifier: "com.tinyspeck.slackmacgap",
            typedContext: sensitive ? "The password is " : "I think ",
            scene: LabScene(
                mode: .replying,
                turns: [LabSceneTurn(speaker: .other, text: incoming)]
            ),
            expectation: LabExpectation(shouldSuggest: false),
            evaluation: metadata(id: scenarioID, incoming: incoming)
        )
    }

    private static func positive(
        id: String,
        category: String,
        intent: LabScenarioIntent,
        typed: String,
        incoming: String,
        continuation: String,
        required: [String],
        tags: [String]
    ) -> LabScenario {
        LabScenario(
            id: id,
            category: category,
            partition: .development,
            intent: intent,
            tone: .friendly,
            tags: (["corpus", "synthetic-pilot", "word-boundary"] + tags).sorted(),
            appBundleIdentifier: "com.tinyspeck.slackmacgap",
            typedContext: typed,
            scene: LabScene(
                mode: .replying,
                turns: [LabSceneTurn(speaker: .other, text: incoming)]
            ),
            expectation: LabExpectation(
                shouldSuggest: true,
                goldenContinuation: continuation,
                acceptablePrefixes: [continuation],
                requiredTerms: required,
                maximumWords: 16
            ),
            evaluation: metadata(id: id, incoming: incoming)
        )
    }

    private static func metadata(id: String, incoming: String) -> LabEvaluationMetadata {
        LabEvaluationMetadata(
            source: .synthetic,
            checkpoint: .caret,
            contextVariant: .structuredThread,
            temporalIntegrity: .verified,
            evidence: LabContextEvidence(
                accessibilityText: "Teammate: \(incoming)",
                OCRText: "Teammate: \(incoming)"
            ),
            corpusID: LabCorpusRegistry.tildeSyntheticPilot.id,
            rootScenarioID: id
        )
    }

    private static func id(_ index: Int, _ kind: String) -> String {
        "corpus-synthetic-\(String(format: "%03d", index))-\(kind)"
    }

    private struct Facts {
        static let names = ["Avery", "Blake", "Casey", "Drew", "Emery", "Flynn", "Gray", "Harper", "Indigo", "Jordan"]
        static let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
        static let times = ["9:00", "10:30", "11:45", "2:00", "3:30"]
        static let items = ["brief", "forecast", "mockup", "notes", "timeline", "checklist", "invoice", "proposal", "agenda", "summary"]
        static let places = ["project channel", "shared folder", "launch board", "planning thread", "review folder"]

        let name: String
        let day: String
        let time: String
        let item: String
        let place: String
        let project: String

        init(index: Int) {
            name = Self.names[index % Self.names.count]
            day = Self.days[(index / 2) % Self.days.count]
            time = Self.times[(index / 3) % Self.times.count]
            item = Self.items[(index / 5) % Self.items.count]
            place = Self.places[(index / 7) % Self.places.count]
            project = "Project \(String(format: "%03d", index + 1))"
        }
    }
}
