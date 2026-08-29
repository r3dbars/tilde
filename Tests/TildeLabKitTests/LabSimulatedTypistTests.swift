import Foundation
import Testing
@testable import TildeLabKit

@Suite("Tilde Lab simulated typist")
struct LabSimulatedTypistTests {
    // MARK: - Personas

    @Test("Checked-in persona fixtures decode and validate")
    func personaFixturesDecode() throws {
        let catalog = try LabTypistPersonaCatalog.loadBundled()
        #expect(catalog.schema == LabTypistPersonaCatalog.currentSchema)
        #expect((3...5).contains(catalog.personas.count))
        #expect(Set(catalog.personas.map(\.id)).count == catalog.personas.count)
        #expect(catalog.personas.contains { $0.register == .chat })
        #expect(catalog.personas.contains { $0.register == .prose })
        #expect(Set(catalog.personas.map(\.typingSpeed)).count > 1)
        #expect(catalog.personas.allSatisfy { $0.millisecondsPerCharacter > 0 })
    }

    @Test("A duplicate persona identifier is rejected")
    func duplicatePersonaRejected() {
        let persona = LabTypistPersona(
            id: "one",
            goal: .answerQuickly,
            register: .chat,
            typingSpeed: .fast,
            interruptionTolerance: .low
        )
        #expect(throws: LabTypistPersonaError.duplicatePersonaID("one")) {
            try LabTypistPersonaCatalog(personas: [persona, persona]).validated()
        }
    }

    // MARK: - Deterministic heuristic

    @Test("The heuristic typist is deterministic across every feature combination")
    func heuristicIsDeterministic() throws {
        let policy = DeterministicHeuristicTypist()
        var seen = 0
        for tolerance in LabTypistInterruptionTolerance.allCases {
            for match in LabTypistPrefixMatch.allCases {
                for bucket in LabCandidateLengthBucket.allCases {
                    for boundary in LabOnlineBoundary.allCases {
                        let features = Self.features(
                            tolerance: tolerance,
                            prefixMatch: match,
                            lengthBucket: bucket,
                            boundary: boundary
                        )
                        let first = try policy.decide(features)
                        let second = try policy.decide(features)
                        let third = try DeterministicHeuristicTypist().decide(features)
                        #expect(first == second)
                        #expect(first == third)
                        seen += 1
                    }
                }
            }
        }
        #expect(seen == 3 * 3 * 5 * 3)
    }

    @Test("A divergent candidate is never accepted and never counted as retained")
    func heuristicRefusesDivergentCandidates() throws {
        let policy = DeterministicHeuristicTypist()
        for tolerance in LabTypistInterruptionTolerance.allCases {
            let decision = try policy.decide(Self.features(
                tolerance: tolerance,
                prefixMatch: .divergent,
                lengthBucket: .fourToSeven,
                boundary: .wordBoundary,
                matchedPrefixCharacters: 0
            ))
            #expect(decision.action == .dismiss || decision.action == .continueTyping)
            #expect(decision.wouldRetain == false)
        }
    }

    // MARK: - Text-free JSON contract

    @Test("The feature schema rejects text-bearing keys")
    func featureSchemaRejectsText() throws {
        let valid = try Self.features().encodedJSON()
        try LabTypistMomentFeatures.validateJSON(valid)

        var object = try #require(
            try JSONSerialization.jsonObject(with: valid) as? [String: Any]
        )
        object["candidateText"] = "works for me."
        #expect(throws: LabTypistPolicyError.forbiddenKey("candidateText")) {
            try LabTypistMomentFeatures.validateJSON(
                try JSONSerialization.data(withJSONObject: object)
            )
        }

        for smuggled in ["prompt", "typedContext", "sceneText", "goldenContinuation"] {
            var tampered = try #require(
                try JSONSerialization.jsonObject(with: valid) as? [String: Any]
            )
            tampered[smuggled] = "the owner's actual writing"
            #expect(throws: LabTypistPolicyError.forbiddenKey(smuggled)) {
                try LabTypistMomentFeatures.validateJSON(
                    try JSONSerialization.data(withJSONObject: tampered)
                )
            }
        }
    }

    @Test("The decision schema rejects text-bearing keys and unknown actions")
    func decisionSchemaRejectsText() throws {
        let valid = try JSONEncoder().encode(
            LabTypistDecision(action: .accept, wouldRetain: true)
        )
        #expect(try LabTypistDecision.decode(valid).action == .accept)

        let withText = Data(#"""
        {"schema":"tilde-lab.typist-decision.v1","action":"accept","wouldRetain":true,"rationale":"because the sentence read well"}
        """#.utf8)
        #expect(throws: LabTypistPolicyError.forbiddenKey("rationale")) {
            try LabTypistDecision.decode(withText)
        }

        let unknownAction = Data(#"""
        {"schema":"tilde-lab.typist-decision.v1","action":"rewrite","wouldRetain":true}
        """#.utf8)
        #expect(throws: LabTypistPolicyError.invalidDecisionPayload) {
            try LabTypistDecision.decode(unknownAction)
        }
    }

    // MARK: - External command policy

    @Test("The external-command policy round-trips the text-free JSON contract")
    func externalCommandRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tilde-typist-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        // The stub proves the contract in both directions: it fails unless the
        // payload it receives is a valid text-free feature object.
        let script = directory.appendingPathComponent("policy.sh")
        try #"""
        #!/bin/bash
        payload="$(cat)"
        case "$payload" in
          *'"schema":"tilde-lab.typist-moment-features.v1"'*) ;;
          *) exit 3 ;;
        esac
        case "$payload" in
          *'"prefixMatch":"exact"'*)
            echo '{"schema":"tilde-lab.typist-decision.v1","action":"accept","wouldRetain":true}' ;;
          *)
            echo '{"schema":"tilde-lab.typist-decision.v1","action":"dismiss","wouldRetain":false}' ;;
        esac
        """#.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: script.path
        )

        let policy = try ExternalCommandTypist(command: script.path)
        #expect(policy.identifier == "external-command-v1")

        let accepted = try policy.decide(Self.features(prefixMatch: .exact))
        #expect(accepted == LabTypistDecision(action: .accept, wouldRetain: true))

        let dismissed = try policy.decide(Self.features(prefixMatch: .divergent))
        #expect(dismissed == LabTypistDecision(action: .dismiss, wouldRetain: false))
    }

    @Test("A command that hangs without closing stdout fails at the deadline")
    func externalCommandHangHitsTimeout() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tilde-typist-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let script = directory.appendingPathComponent("hang.sh")
        try #"""
        #!/bin/bash
        cat > /dev/null
        sleep 3600
        """#.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: script.path
        )

        let policy = try ExternalCommandTypist(command: script.path, timeoutSeconds: 0.5)
        let started = Date()
        #expect(throws: LabTypistPolicyError.self) {
            _ = try policy.decide(Self.features(prefixMatch: .exact))
        }
        #expect(Date().timeIntervalSince(started) < 5)
    }

    @Test("A missing or non-executable decision command is refused before any run")
    func externalCommandMustBeExecutable() {
        #expect(throws: LabTypistPolicyError.self) {
            try ExternalCommandTypist(command: "policy.sh")
        }
        #expect(throws: LabTypistPolicyError.self) {
            try ExternalCommandTypist(command: "/definitely/not/a/policy/command")
        }
    }

    // MARK: - End-to-end smoke

    @Test("A stubbed generation path produces a fenced aggregate report")
    func endToEndSmoke() async throws {
        let suite = try Self.smokeSuite()
        let personas = Array(try LabTypistPersonaCatalog.loadBundled().personas.prefix(2))
        let engine = LabSimulatedTypistEngine(
            configuration: LabSimulatedTypistConfiguration(strideCharacters: 3),
            policy: DeterministicHeuristicTypist()
        )
        let report = try await engine.run(
            suite: suite,
            personas: personas,
            client: StubCompletionClient(content: " sounds good to me."),
            provenance: .unavailable()
        )

        #expect(report.schema == LabSimulatedTypistReport.currentSchema)
        #expect(report.scenarioCount == 2)
        #expect(report.personas.count == 2)
        #expect(report.decisionPolicyIdentifier == DeterministicHeuristicTypist.identifier)
        #expect(report.totalDisplays > 0)
        #expect(report.totalBaselineCharacters > 0)
        #expect(report.personas.allSatisfy { $0.opportunities == 2 })
        #expect(report.personas.allSatisfy {
            $0.accepts + $0.wordAccepts + $0.typeThroughs + $0.dismissals == $0.displays
        })
        #expect(report.personas.allSatisfy {
            $0.retainedCharacterPotential <= $0.acceptedCharacters
        })
        // The stub offers exactly what the persona meant to type, so the
        // driver must reach an acceptance rather than only typing through.
        #expect(report.personas.allSatisfy { $0.accepts + $0.wordAccepts > 0 })
        #expect(report.personas.allSatisfy { $0.wrongDisplays == 0 })
        #expect(report.totalRetainedCharacterPotential > 0)

        // Repeating the run with the same stub reproduces the same aggregates.
        let repeated = try await engine.run(
            suite: suite,
            personas: personas,
            client: StubCompletionClient(content: " sounds good to me."),
            provenance: .unavailable()
        )
        #expect(repeated.personas == report.personas)
    }

    @Test("A suite with no golden continuation cannot be simulated")
    func silenceOnlySuiteRefused() async throws {
        let suite = try LabScenarioSuite(
            name: "silence only",
            scenarios: [LabScenario(
                id: "silence.one",
                category: "silence.ordinary.ambiguous",
                typedContext: "I think ",
                expectation: LabExpectation(shouldSuggest: false)
            )]
        ).validated()
        await #expect(throws: LabSimulatedTypistError.noSimulatableScenarios) {
            try await LabSimulatedTypistEngine(policy: DeterministicHeuristicTypist()).run(
                suite: suite,
                personas: try LabTypistPersonaCatalog.loadBundled().personas,
                client: StubCompletionClient(content: "anything"),
                provenance: .unavailable()
            )
        }
    }

    // MARK: - Evidence fence

    @Test("A simulated report is permanently fenced out of protected comparisons")
    func simulatedReportIsFenced() throws {
        let report = LabSimulatedTypistReport(
            startedAt: Date(),
            finishedAt: Date(),
            suiteName: "smoke",
            suiteDigestSHA256: String(repeating: "a", count: 64),
            scenarioCount: 1,
            arm: LabArmConfiguration(id: "baseline"),
            decisionPolicyIdentifier: DeterministicHeuristicTypist.identifier,
            provenance: .unavailable(),
            personas: []
        )
        #expect(report.isDecisionGrade == false)
        #expect(report.evidenceEligibility.reasons == [.simulatedDecisionLayer])
        #expect(!LabRunReport.supportedSchemas.contains(report.schema))
        try report.validated()

        // Even a clean, registered, reviewed provenance envelope cannot lift
        // the fence, and a tampered artifact is refused on load.
        var object = try #require(
            try JSONSerialization.jsonObject(
                with: try JSONEncoder().encode(report)
            ) as? [String: Any]
        )
        object["evidenceEligibility"] = ["eligible": true, "reasons": []]
        let tampered = try JSONDecoder().decode(
            LabSimulatedTypistReport.self,
            from: try JSONSerialization.data(withJSONObject: object)
        )
        #expect(throws: LabSimulatedTypistError.evidenceFenceRemoved) {
            try tampered.validated()
        }
    }

    // MARK: - Helpers

    private static func features(
        tolerance: LabTypistInterruptionTolerance = .medium,
        prefixMatch: LabTypistPrefixMatch = .exact,
        lengthBucket: LabCandidateLengthBucket = .twoToThree,
        boundary: LabOnlineBoundary = .wordBoundary,
        matchedPrefixCharacters: Int = 12
    ) -> LabTypistMomentFeatures {
        LabTypistMomentFeatures(
            personaGoal: .answerQuickly,
            personaRegister: .chat,
            personaTypingSpeed: .medium,
            personaInterruptionTolerance: tolerance,
            boundary: boundary,
            candidateLengthBucket: lengthBucket,
            candidateCharacterCount: 12,
            candidateWordCount: 3,
            prefixMatch: prefixMatch,
            matchedPrefixCharacters: matchedPrefixCharacters,
            typedCharacters: 4,
            remainingCharacters: 18,
            displaysSoFar: 0,
            dismissalsSoFar: 0,
            millisecondsSinceDisplay: 120,
            generationMilliseconds: 120,
            meanTokenProbabilityBucket: .high
        )
    }

    private static func smokeSuite() throws -> LabScenarioSuite {
        let scenarios = ["one", "two"].map { suffix in
            LabScenario(
                id: "simulated.smoke.\(suffix)",
                category: "reply.simulated.smoke",
                typedContext: "That ",
                scene: LabScene(
                    mode: .replying,
                    turns: [LabSceneTurn(speaker: .other, text: "Can we meet on the usual day?")]
                ),
                expectation: LabExpectation(
                    shouldSuggest: true,
                    goldenContinuation: "sounds good to me.",
                    acceptablePrefixes: ["sounds good to me."]
                )
            )
        }
        return try LabScenarioSuite(name: "simulated smoke", scenarios: scenarios).validated()
    }
}

/// Stands in for the local helper so the simulated-typist suite never needs a
/// live llama-server.
private struct StubCompletionClient: LabCompletionClient {
    let workerIndex = 0
    let content: String

    init(content: String) {
        self.content = content
    }

    func complete(_ request: LabModelRequest) async throws -> LabModelResponse {
        LabModelResponse(
            content: content,
            latencyMilliseconds: 120,
            firstTokenMilliseconds: 40,
            meanTokenProbability: 0.8
        )
    }
}
