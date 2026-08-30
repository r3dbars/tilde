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

    // MARK: - Batched decision contract

    @Test("The batch contract round-trips in order through an external command")
    func externalCommandBatchRoundTrip() throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let script = try Self.batchStub(in: directory, name: "batch.sh")

        let policy = try ExternalCommandTypist(
            command: script.path, timeoutSeconds: 20, batchSize: 4
        )
        #expect(policy.decisionBatchSize == 4)
        // The response cap and the deadline scale with the batch, both bounded.
        #expect(ExternalCommandTypist.responseByteLimitPerMoment == 4_096)
        #expect(policy.timeout(forMoments: 1) == 20)
        #expect(policy.timeout(forMoments: 4) == 80)
        #expect(policy.timeout(forMoments: 100) == 200)
        #expect(policy.timeout(forMoments: 100) <= ExternalCommandTypist.maximumTimeoutSeconds)

        // Deliberately mixed and interleaved, so a policy that sorted, grouped,
        // or reversed its answers would not reproduce this sequence.
        let matches: [LabTypistPrefixMatch] = [.divergent, .exact, .exact, .divergent]
        let decisions = try policy.decide(
            batch: matches.map { Self.features(prefixMatch: $0) }
        )
        #expect(decisions.count == matches.count)
        #expect(decisions.map(\.action) == [.dismiss, .accept, .accept, .dismiss])
        #expect(decisions.map(\.wouldRetain) == [false, true, true, false])
    }

    @Test("A batch of one still speaks the single-moment contract on the wire")
    func batchOfOneUsesSingleMomentContract() throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        // This stub refuses anything that is not a single-moment feature
        // object, so a default-size run cannot silently change the wire format.
        let script = directory.appendingPathComponent("single-only.sh")
        try #"""
        #!/bin/bash
        payload="$(cat)"
        case "$payload" in
          *'"schema":"tilde-lab.typist-moment-features.v1"'*) ;;
          *) exit 3 ;;
        esac
        echo '{"schema":"tilde-lab.typist-decision.v1","action":"accept","wouldRetain":true}'
        """#.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: script.path
        )

        let policy = try ExternalCommandTypist(command: script.path)
        #expect(policy.decisionBatchSize == 1)
        let decisions = try policy.decide(batch: [Self.features()])
        #expect(decisions.map(\.action) == [.accept])

        // And a policy is never asked to hold more than the batch size it
        // declared: over-capacity is refused rather than quietly split.
        #expect(throws: LabTypistPolicyError.batchSizeOutOfRange(2)) {
            _ = try policy.decide(batch: [Self.features(), Self.features()])
        }
    }

    @Test("A short, long, or reordered decision batch is refused, never tolerated")
    func batchCountMismatchIsRefused() throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let script = directory.appendingPathComponent("short.sh")
        try #"""
        #!/bin/bash
        cat > /dev/null
        echo '{"schema":"tilde-lab.typist-decision-batch.v1","decisions":[{"schema":"tilde-lab.typist-decision.v1","action":"accept","wouldRetain":true}]}'
        """#.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: script.path
        )

        let policy = try ExternalCommandTypist(command: script.path, batchSize: 3)
        #expect(throws: LabTypistPolicyError.batchCountMismatch(expected: 3, received: 1)) {
            _ = try policy.decide(batch: [
                Self.features(), Self.features(), Self.features(),
            ])
        }

        let extra = Data(#"""
        {"schema":"tilde-lab.typist-decision-batch.v1","decisions":[{"schema":"tilde-lab.typist-decision.v1","action":"accept","wouldRetain":true},{"schema":"tilde-lab.typist-decision.v1","action":"dismiss","wouldRetain":false}]}
        """#.utf8)
        #expect(throws: LabTypistPolicyError.batchCountMismatch(expected: 1, received: 2)) {
            _ = try LabTypistDecisionBatch.decode(extra, expectedCount: 1)
        }
    }

    @Test("Batch payloads reject text-bearing keys in the envelope and in any moment")
    func batchSchemaRejectsText() throws {
        let valid = try LabTypistMomentBatch(
            moments: [Self.features(), Self.features(prefixMatch: .divergent)]
        ).encodedJSON()
        try LabTypistMomentBatch.validateJSON(valid)

        var envelope = try #require(
            try JSONSerialization.jsonObject(with: valid) as? [String: Any]
        )
        envelope["prompt"] = "the owner's actual writing"
        #expect(throws: LabTypistPolicyError.forbiddenKey("prompt")) {
            try LabTypistMomentBatch.validateJSON(
                try JSONSerialization.data(withJSONObject: envelope)
            )
        }

        // A text-bearing key anywhere inside the array fails the whole batch:
        // the elements go through the same single-moment allowlist.
        var moments = try #require(
            try JSONSerialization.jsonObject(with: valid) as? [String: Any]
        )
        var elements = try #require(moments["moments"] as? [[String: Any]])
        elements[1]["candidateText"] = "works for me."
        moments["moments"] = elements
        #expect(throws: LabTypistPolicyError.forbiddenKey("candidateText")) {
            try LabTypistMomentBatch.validateJSON(
                try JSONSerialization.data(withJSONObject: moments)
            )
        }

        // An empty or oversized batch is not a batch.
        #expect(throws: LabTypistPolicyError.batchSizeOutOfRange(0)) {
            try LabTypistMomentBatch(moments: []).encodedJSON()
        }
        #expect(throws: LabTypistPolicyError.batchSizeOutOfRange(101)) {
            _ = try ExternalCommandTypist(
                command: "/definitely/not/a/policy/command", batchSize: 101
            )
        }

        let rationale = Data(#"""
        {"schema":"tilde-lab.typist-decision-batch.v1","decisions":[{"schema":"tilde-lab.typist-decision.v1","action":"accept","wouldRetain":true,"rationale":"because the sentence read well"}]}
        """#.utf8)
        #expect(throws: LabTypistPolicyError.forbiddenKey("rationale")) {
            _ = try LabTypistDecisionBatch.decode(rationale, expectedCount: 1)
        }

        let smuggledEnvelope = Data(#"""
        {"schema":"tilde-lab.typist-decision-batch.v1","note":"the owner's actual writing","decisions":[]}
        """#.utf8)
        #expect(throws: LabTypistPolicyError.forbiddenKey("note")) {
            _ = try LabTypistDecisionBatch.decode(smuggledEnvelope, expectedCount: 0)
        }
    }

    @Test("A batch only ever groups moments from different persona/scenario pairs")
    func batchGroupsOnlyIndependentMoments() async throws {
        let personas = Self.twoPersonas()
        let recorder = RecordingBatchTypist(batchSize: 4)
        let report = try await LabSimulatedTypistEngine(
            configuration: LabSimulatedTypistConfiguration(strideCharacters: 3),
            policy: recorder
        ).run(
            suite: try Self.distinguishableSuite(),
            personas: personas,
            client: PerScenarioStubClient(),
            provenance: .unavailable()
        )

        let batches = recorder.recordedBatches()
        #expect(batches.count > 1)
        #expect(batches.allSatisfy { $0.count <= 4 })
        // At least one round actually batched; otherwise this proves nothing.
        #expect(batches.contains { $0.count > 1 })
        for batch in batches {
            // Persona traits identify the persona; the stub returns a distinct
            // candidate per scenario, so the candidate length identifies the
            // scenario. Two moments of one session would collide on this key.
            let keys = batch.map {
                "\($0.personaGoal.rawValue)/\($0.personaInterruptionTolerance.rawValue)/\($0.candidateCharacterCount)"
            }
            #expect(Set(keys).count == keys.count)
        }
        #expect(report.decisionBatchSize == 4)

        // Batching is an execution detail, not a semantic one: the same
        // decisions taken one moment at a time produce the same aggregates.
        let sequential = try await LabSimulatedTypistEngine(
            configuration: LabSimulatedTypistConfiguration(strideCharacters: 3),
            policy: RecordingBatchTypist(batchSize: 1)
        ).run(
            suite: try Self.distinguishableSuite(),
            personas: personas,
            client: PerScenarioStubClient(),
            provenance: .unavailable()
        )
        #expect(sequential.personas == report.personas)
        #expect(sequential.decisionBatchSize == 1)
    }

    @Test("The default batch size is 1 and is recorded in the report")
    func defaultBatchSizeIsOne() async throws {
        let engine = LabSimulatedTypistEngine(policy: DeterministicHeuristicTypist())
        #expect(engine.effectiveBatchSize == 1)
        #expect(DeterministicHeuristicTypist().decisionBatchSize == 1)

        let report = try await engine.run(
            suite: try Self.smokeSuite(),
            personas: Array(try LabTypistPersonaCatalog.loadBundled().personas.prefix(2)),
            client: StubCompletionClient(content: " sounds good to me."),
            provenance: .unavailable()
        )
        #expect(report.decisionBatchSize == 1)
        try report.validated()
    }

    // MARK: - Concurrent decision workers

    @Test("Concurrent workers reproduce the sequential aggregates byte for byte")
    func concurrentWorkersMatchSequentialAggregates() async throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let script = try Self.dualStub(in: directory, name: "dual.sh")

        func run(workers: Int, batchSize: Int) async throws -> LabSimulatedTypistReport {
            var configuration = LabSimulatedTypistConfiguration(strideCharacters: 3)
            configuration.decisionWorkers = workers
            return try await LabSimulatedTypistEngine(
                configuration: configuration,
                policy: try ExternalCommandTypist(
                    command: script.path, timeoutSeconds: 20, batchSize: batchSize
                )
            ).run(
                suite: try Self.parallelSuite(scenarios: 6),
                personas: Self.twoPersonas(),
                client: StubCompletionClient(content: " sounds good to me."),
                provenance: .unavailable()
            )
        }

        let sequential = try await run(workers: 1, batchSize: 2)
        let concurrent = try await run(workers: 4, batchSize: 2)
        #expect(sequential.decisionWorkers == 1)
        #expect(concurrent.decisionWorkers == 4)
        #expect(concurrent.totalDisplays > 0)

        // Equatable is the readable assertion; the encoded bytes are the strict
        // one — completion order may not perturb a single count.
        #expect(concurrent.personas == sequential.personas)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        #expect(
            try encoder.encode(concurrent.personas) == encoder.encode(sequential.personas)
        )

        // And a batch-size-1 concurrent run still matches, so workers alone —
        // without batching — cannot move an aggregate either.
        let concurrentUnbatched = try await run(workers: 4, batchSize: 1)
        #expect(concurrentUnbatched.personas == sequential.personas)
    }

    @Test("No more than the configured number of decision calls are ever in flight")
    func workerCapIsEnforced() async throws {
        for workers in [1, 3] {
            let probe = ConcurrencyProbeTypist(batchSize: 1, holdSeconds: 0.05)
            var configuration = LabSimulatedTypistConfiguration(strideCharacters: 3)
            configuration.decisionWorkers = workers
            let report = try await LabSimulatedTypistEngine(
                configuration: configuration, policy: probe
            ).run(
                suite: try Self.parallelSuite(scenarios: 6),
                personas: Self.twoPersonas(),
                client: StubCompletionClient(content: " sounds good to me."),
                provenance: .unavailable()
            )
            #expect(report.decisionWorkers == workers)
            #expect(probe.calls() > workers)
            #expect(probe.peakConcurrency() <= workers)
            if workers > 1 {
                // A cap that is never reached would prove nothing about it.
                #expect(probe.peakConcurrency() > 1)
            }
        }
    }

    @Test("A run above the worker ceiling is clamped, not silently obeyed")
    func workerCountIsClamped() async throws {
        var configuration = LabSimulatedTypistConfiguration()
        configuration.decisionWorkers = 999
        let engine = LabSimulatedTypistEngine(
            configuration: configuration, policy: DeterministicHeuristicTypist()
        )
        #expect(
            engine.effectiveDecisionWorkers
                == LabSimulatedTypistConfiguration.maximumDecisionWorkers
        )
        var floored = LabSimulatedTypistConfiguration()
        floored.decisionWorkers = 0
        #expect(
            LabSimulatedTypistEngine(
                configuration: floored, policy: DeterministicHeuristicTypist()
            ).effectiveDecisionWorkers == 1
        )
        #expect(LabSimulatedTypistEngine(policy: DeterministicHeuristicTypist())
            .effectiveDecisionWorkers == 1)

        // The recorded value is validated on the artifact as well.
        #expect(throws: LabSimulatedTypistError.invalidDecisionWorkers) {
            try Self.report(decisionWorkers: 17).validated()
        }
        try Self.report(decisionWorkers: 16).validated()
    }

    @Test("Slow external decision commands actually overlap under concurrency")
    func externalCommandsOverlap() async throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        // The stub is its own overlap counter: it marks itself present, holds,
        // then records how many invocations were present alongside it.
        let markers = directory.appendingPathComponent("markers", isDirectory: true)
        try FileManager.default.createDirectory(at: markers, withIntermediateDirectories: true)
        let script = directory.appendingPathComponent("slow.sh")
        try """
        #!/bin/bash
        cat > /dev/null
        marker="\(markers.path)/$$"
        : > "$marker"
        sleep 0.4
        ls "\(markers.path)" | wc -l >> "\(directory.path)/observed"
        rm -f "$marker"
        echo '{"schema":"tilde-lab.typist-decision.v1","action":"accept","wouldRetain":true}'
        """.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: script.path
        )

        var configuration = LabSimulatedTypistConfiguration(strideCharacters: 3)
        configuration.maximumDisplaysPerScenario = 1
        configuration.decisionWorkers = 4
        let started = Date()
        _ = try await LabSimulatedTypistEngine(
            configuration: configuration,
            policy: try ExternalCommandTypist(command: script.path, timeoutSeconds: 20)
        ).run(
            suite: try Self.parallelSuite(scenarios: 4),
            personas: Self.twoPersonas(),
            client: StubCompletionClient(content: " sounds good to me."),
            provenance: .unavailable()
        )
        let elapsed = Date().timeIntervalSince(started)

        let observed = try String(
            contentsOf: directory.appendingPathComponent("observed"), encoding: .utf8
        ).split(whereSeparator: \.isNewline).compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        #expect((4...8).contains(observed.count))
        // Eight 0.4s invocations, four at a time: at least one invocation must
        // have seen a peer running, and the wall clock cannot be sequential.
        #expect(observed.max() ?? 0 >= 2)
        #expect(elapsed < 8 * 0.4)
    }

    @Test("A failed batch aborts the round and leaves nothing running behind it")
    func failureMidRoundAbortsCleanly() async throws {
        let policy = FailingProbeTypist(failOnCall: 3, holdSeconds: 0.05)
        var configuration = LabSimulatedTypistConfiguration(strideCharacters: 3)
        configuration.decisionWorkers = 4
        await #expect(throws: ProbeFailure.injected) {
            try await LabSimulatedTypistEngine(
                configuration: configuration, policy: policy
            ).run(
                suite: try Self.parallelSuite(scenarios: 6),
                personas: Self.twoPersonas(),
                client: StubCompletionClient(content: " sounds good to me."),
                provenance: .unavailable()
            )
        }
        // Every call that started also finished before the error surfaced: the
        // group awaits its in-flight batches instead of abandoning them.
        #expect(policy.started() == policy.finished())
        #expect(policy.started() >= 3)

        // The same failure aborts a sequential run with the same error, so
        // concurrency did not change what a broken policy costs.
        var sequential = LabSimulatedTypistConfiguration(strideCharacters: 3)
        sequential.decisionWorkers = 1
        await #expect(throws: ProbeFailure.injected) {
            try await LabSimulatedTypistEngine(
                configuration: sequential,
                policy: FailingProbeTypist(failOnCall: 3, holdSeconds: 0)
            ).run(
                suite: try Self.parallelSuite(scenarios: 6),
                personas: Self.twoPersonas(),
                client: StubCompletionClient(content: " sounds good to me."),
                provenance: .unavailable()
            )
        }
    }

    @Test("A failing external command under concurrency leaves no live process")
    func concurrentExternalFailureLeavesNoZombie() async throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let script = directory.appendingPathComponent("fails.sh")
        try """
        #!/bin/bash
        cat > /dev/null
        sleep 0.2
        exit 3
        """.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: script.path
        )

        var configuration = LabSimulatedTypistConfiguration(strideCharacters: 3)
        configuration.decisionWorkers = 4
        await #expect(throws: LabTypistPolicyError.decisionCommandFailed(3)) {
            try await LabSimulatedTypistEngine(
                configuration: configuration,
                policy: try ExternalCommandTypist(command: script.path, timeoutSeconds: 5)
            ).run(
                suite: try Self.parallelSuite(scenarios: 4),
                personas: Self.twoPersonas(),
                client: StubCompletionClient(content: " sounds good to me."),
                provenance: .unavailable()
            )
        }
        #expect(Self.runningProcesses(matching: script.path) == 0)
    }

    // MARK: - Counted skip of failed decision batches

    @Test("A failed batch abandons its sessions, and the report says so loudly")
    func skippedBatchesAreCountedAndStated() async throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let script = try Self.poisonedStub(in: directory, name: "poison.sh")

        let report = try await Self.simulate(
            command: script, skippedBatchAllowance: 5, personas: Self.twoPersonas()
        )

        // Three careful-persona sessions failed after their first decision.
        #expect(report.skippedBatchAllowance == 5)
        #expect(report.skippedBatches == 3)
        #expect(report.abandonedSessions == 3)
        // Each abandoned session had already spent a decision moment before the
        // failing one; both are discarded, and both are counted.
        #expect(report.abandonedMoments == 6)

        let quick = try #require(report.personas.first { $0.personaID == "batch-fast" })
        let careful = try #require(report.personas.first { $0.personaID == "batch-careful" })
        #expect(quick.scenarios == 3)
        #expect(quick.abandonedScenarios == 0)
        #expect(quick.displays > 0)

        // Excluded, not zero-filled: the abandoned sessions contribute no
        // opportunity, no baseline characters, and above all no dismissal or
        // type-through the simulated writer never made.
        #expect(careful.scenarios == 0)
        #expect(careful.abandonedScenarios == 3)
        #expect(careful.displays == 0)
        #expect(careful.opportunities == 0)
        #expect(careful.baselineCharacters == 0)
        #expect(careful.dismissals == 0)
        #expect(careful.typeThroughs == 0)
        #expect(careful.accepts + careful.wordAccepts == 0)

        // A reader who only reads the limitation still learns the sample is
        // incomplete, and by how much.
        #expect(report.hasSkippedBatches)
        #expect(report.limitation.contains("Incomplete sample"))
        #expect(report.limitation.contains("3 decision batches"))
        #expect(report.limitation.contains("3 persona/scenario sessions"))
        #expect(report.limitation.contains("6 decision moments"))
        #expect(report.limitation.hasPrefix(LabSimulatedTypistReport.limitation))
        try report.validated()
    }

    @Test("Exceeding the skip allowance aborts the run exactly as it does today")
    func skipAllowanceIsACapNotASuggestion() async throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let script = try Self.poisonedStub(in: directory, name: "poison.sh")

        // Three batches fail. Two skips are not enough, and the run ends with
        // the decision command's own error rather than a truncated report.
        for allowance in [0, 1, 2] {
            await #expect(throws: LabTypistPolicyError.decisionCommandFailed(7)) {
                try await Self.simulate(
                    command: script,
                    skippedBatchAllowance: allowance,
                    personas: Self.twoPersonas()
                )
            }
        }
        // One more than the failures is enough, so the cap is what decides.
        let report = try await Self.simulate(
            command: script, skippedBatchAllowance: 3, personas: Self.twoPersonas()
        )
        #expect(report.skippedBatches == 3)
    }

    @Test("Surviving sessions are identical whether or not other batches were skipped")
    func skippingDoesNotPerturbSurvivingSessions() async throws {
        let directory = try Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let script = try Self.poisonedStub(in: directory, name: "poison.sh")

        let withSkips = try await Self.simulate(
            command: script, skippedBatchAllowance: 5, personas: Self.twoPersonas()
        )
        // The control never trips the stub, never skips, and runs the
        // default-off driver: the surviving persona must not be able to tell.
        let control = try await Self.simulate(
            command: script,
            skippedBatchAllowance: 0,
            personas: Array(Self.twoPersonas().prefix(1))
        )
        #expect(control.skippedBatches == 0)

        // The same failing batches under four concurrent workers: which batches
        // a run skips comes from the policy's answers, not from what finished
        // first, so both the survivor and the skip accounting must repeat.
        let concurrent = try await Self.simulate(
            command: script,
            skippedBatchAllowance: 5,
            personas: Self.twoPersonas(),
            decisionWorkers: 4
        )
        #expect(concurrent.skippedBatches == withSkips.skippedBatches)
        #expect(concurrent.abandonedSessions == withSkips.abandonedSessions)
        #expect(concurrent.abandonedMoments == withSkips.abandonedMoments)

        let survivor = try #require(withSkips.personas.first { $0.personaID == "batch-fast" })
        let reference = try #require(control.personas.first { $0.personaID == "batch-fast" })
        let parallel = try #require(concurrent.personas.first { $0.personaID == "batch-fast" })
        #expect(survivor == reference)
        #expect(parallel == reference)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        #expect(try encoder.encode(survivor) == encoder.encode(reference))
        #expect(try encoder.encode(parallel) == encoder.encode(reference))
    }

    @Test("A skipped batch never cancels the sibling batches still in flight")
    func skippedBatchLeavesConcurrentSiblingsAlone() async throws {
        let probe = FailingProbeTypist(failOnCall: 3, holdSeconds: 0.05)
        var configuration = LabSimulatedTypistConfiguration(strideCharacters: 3)
        configuration.decisionWorkers = 4
        configuration.skippedBatchAllowance = 1
        let report = try await LabSimulatedTypistEngine(
            configuration: configuration, policy: probe
        ).run(
            suite: try Self.parallelSuite(scenarios: 6),
            personas: Self.twoPersonas(),
            client: StubCompletionClient(content: " sounds good to me."),
            provenance: .unavailable()
        )

        // The run finished instead of aborting, and every call that started —
        // including the three that were in flight beside the failing one —
        // finished rather than being cancelled out from under the round.
        #expect(report.skippedBatches == 1)
        #expect(report.abandonedSessions == 1)
        #expect(probe.started() == probe.finished())
        #expect(probe.started() > 3)
        // Twelve sessions are still accounted for: eleven aggregated, one
        // abandoned, none silently dropped.
        let counted = report.personas.reduce(0) { $0 + $1.scenarios + $1.abandonedScenarios }
        #expect(counted == 12)
        #expect(report.personas.reduce(0) { $0 + $1.abandonedScenarios } == 1)
        #expect(report.totalDisplays > 0)
        try report.validated()
    }

    @Test("With the option off a run behaves and reports exactly as before")
    func skipModeIsOffByDefault() async throws {
        let engine = LabSimulatedTypistEngine(policy: DeterministicHeuristicTypist())
        #expect(engine.effectiveSkippedBatchAllowance == 0)
        #expect(LabSimulatedTypistConfiguration().skippedBatchAllowance == 0)

        let report = try await engine.run(
            suite: try Self.smokeSuite(),
            personas: Array(try LabTypistPersonaCatalog.loadBundled().personas.prefix(2)),
            client: StubCompletionClient(content: " sounds good to me."),
            provenance: .unavailable()
        )
        #expect(report.skippedBatchAllowance == 0)
        #expect(report.skippedBatches == 0)
        #expect(report.abandonedSessions == 0)
        #expect(report.abandonedMoments == 0)
        #expect(report.hasSkippedBatches == false)
        #expect(report.limitation == LabSimulatedTypistReport.limitation)
        #expect(report.personas.allSatisfy { $0.abandonedScenarios == 0 })
        #expect(report.personas.allSatisfy { $0.scenarios == 2 })
        try report.validated()

        // A run asking for more skips than the contract allows is clamped, and
        // the ceiling is the one the report validates against.
        var beyond = LabSimulatedTypistConfiguration()
        beyond.skippedBatchAllowance = 999
        #expect(
            LabSimulatedTypistEngine(configuration: beyond, policy: DeterministicHeuristicTypist())
                .effectiveSkippedBatchAllowance
                == LabSimulatedTypistConfiguration.maximumSkippedBatches
        )
        var negative = LabSimulatedTypistConfiguration()
        negative.skippedBatchAllowance = -3
        #expect(
            LabSimulatedTypistEngine(configuration: negative, policy: DeterministicHeuristicTypist())
                .effectiveSkippedBatchAllowance == 0
        )
    }

    @Test("Skip accounting a report cannot back up is refused")
    func skipAccountingIsValidated() throws {
        try Self.report().validated()
        #expect(throws: LabSimulatedTypistError.invalidSkippedBatchCount) {
            try Self.report(skippedBatchAllowance: 51).validated()
        }
        #expect(throws: LabSimulatedTypistError.invalidSkippedBatchCount) {
            try Self.report(
                skippedBatchAllowance: 1, skippedBatches: 2,
                abandonedSessions: 2, abandonedMoments: 2
            ).validated()
        }
        // A skip that cost no session, a session that cost no moment, and a
        // loss with no skip behind it are all accounting errors.
        #expect(throws: LabSimulatedTypistError.inconsistentAbandonment) {
            try Self.report(skippedBatchAllowance: 5, skippedBatches: 2).validated()
        }
        #expect(throws: LabSimulatedTypistError.inconsistentAbandonment) {
            try Self.report(
                skippedBatchAllowance: 5, skippedBatches: 1,
                abandonedSessions: 2, abandonedMoments: 1
            ).validated()
        }
        #expect(throws: LabSimulatedTypistError.inconsistentAbandonment) {
            try Self.report(abandonedSessions: 3, abandonedMoments: 3).validated()
        }
        // The persona slices have to agree with the run-level total.
        #expect(throws: LabSimulatedTypistError.inconsistentAbandonment) {
            try Self.report(
                skippedBatchAllowance: 5, skippedBatches: 1,
                abandonedSessions: 1, abandonedMoments: 1,
                personas: [Self.slice(abandonedScenarios: 0)]
            ).validated()
        }
        try Self.report(
            skippedBatchAllowance: 5, skippedBatches: 1,
            abandonedSessions: 1, abandonedMoments: 2,
            personas: [Self.slice(abandonedScenarios: 1)]
        ).validated()

        // And a report whose limitation was quietly reset to the clean text is
        // refused rather than read as a complete run.
        let skipped = Self.report(
            skippedBatchAllowance: 5, skippedBatches: 1,
            abandonedSessions: 1, abandonedMoments: 2,
            personas: [Self.slice(abandonedScenarios: 1)]
        )
        var object = try #require(
            try JSONSerialization.jsonObject(
                with: try JSONEncoder().encode(skipped)
            ) as? [String: Any]
        )
        object["limitation"] = LabSimulatedTypistReport.limitation
        let tampered = try JSONDecoder().decode(
            LabSimulatedTypistReport.self,
            from: try JSONSerialization.data(withJSONObject: object)
        )
        #expect(throws: LabSimulatedTypistError.limitationMisstatesSkips) {
            try tampered.validated()
        }
    }

    // MARK: - Generation model provenance

    @Test("A Gemma run and a Qwen run are distinguishable from their reports alone")
    func reportNamesTheGenerationModel() async throws {
        let gemma = Self.report(assets: LabAssetSnapshot(
            verificationMode: .productionPinned,
            modelIdentifier: LabModelProfile.production.identifier,
            modelRevision: LabModelProfile.production.revision,
            modelSHA256: String(repeating: "a", count: 64),
            helperSHA256: String(repeating: "b", count: 64)
        ))
        let qwen = Self.report(assets: Self.experimentalAssets())
        try gemma.validated()
        try qwen.validated()
        #expect(gemma.assets != qwen.assets)
        #expect(gemma.assets?.modelIdentifier != qwen.assets?.modelIdentifier)
        #expect(qwen.assets?.modelRevision == "2026-08-01")
        #expect(qwen.assets?.modelSHA256 == String(repeating: "c", count: 64))
        #expect(qwen.assets?.helperSHA256 == String(repeating: "d", count: 64))

        // The identity survives the artifact round trip, which is the only way
        // two reports ever meet.
        let decoded = try JSONDecoder().decode(
            LabSimulatedTypistReport.self, from: try JSONEncoder().encode(qwen)
        )
        #expect(decoded.assets == qwen.assets)
        try decoded.validated()

        // And the engine records the stack it was actually run against.
        let report = try await LabSimulatedTypistEngine(
            configuration: LabSimulatedTypistConfiguration(strideCharacters: 3),
            policy: DeterministicHeuristicTypist()
        ).run(
            suite: try Self.smokeSuite(),
            personas: Self.twoPersonas(),
            client: StubCompletionClient(content: " sounds good to me."),
            provenance: .unavailable(),
            assets: Self.experimentalAssets()
        )
        #expect(report.assets == Self.experimentalAssets())
        try report.validated()
    }

    @Test("A report cannot claim a model identity it could not have had")
    func modelIdentityIsValidated() throws {
        // A digest that is not a digest.
        #expect(throws: LabSimulatedTypistError.invalidModelIdentity) {
            try Self.report(assets: Self.experimentalAssets(modelSHA256: "not-a-digest"))
                .validated()
        }
        #expect(throws: LabSimulatedTypistError.invalidModelIdentity) {
            try Self.report(assets: Self.experimentalAssets(
                helperSHA256: String(repeating: "A", count: 64)
            )).validated()
        }
        // An unusable identity or revision.
        #expect(throws: LabSimulatedTypistError.invalidModelIdentity) {
            try Self.report(assets: Self.experimentalAssets(identifier: "")).validated()
        }
        #expect(throws: LabSimulatedTypistError.invalidModelIdentity) {
            try Self.report(assets: Self.experimentalAssets(revision: "a revision")).validated()
        }
        // Production-pinned may only ever name the pinned production asset.
        #expect(throws: LabSimulatedTypistError.invalidModelIdentity) {
            try Self.report(assets: LabAssetSnapshot(
                verificationMode: .productionPinned,
                modelIdentifier: "qwen3-4b-instruct",
                modelRevision: "2026-08-01",
                modelSHA256: String(repeating: "c", count: 64),
                helperSHA256: String(repeating: "d", count: 64)
            )).validated()
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

    private static func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tilde-typist-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// A batch stub that proves the contract in both directions: it refuses a
    /// payload that is not a text-free moment batch, and answers one decision
    /// per moment in the order the moments arrived.
    private static func batchStub(in directory: URL, name: String) throws -> URL {
        let script = directory.appendingPathComponent(name)
        try #"""
        #!/bin/bash
        payload="$(cat)"
        case "$payload" in
          *'"schema":"tilde-lab.typist-moment-batch.v1"'*) ;;
          *) exit 3 ;;
        esac
        case "$payload" in
          *Text*|*prompt*|*continuation*) exit 4 ;;
        esac
        decisions=""
        for match in $(printf '%s' "$payload" | grep -o '"prefixMatch":"[a-z]*"' | sed 's/.*:"//;s/"//'); do
          if [ "$match" = "exact" ]; then
            one='{"schema":"tilde-lab.typist-decision.v1","action":"accept","wouldRetain":true}'
          else
            one='{"schema":"tilde-lab.typist-decision.v1","action":"dismiss","wouldRetain":false}'
          fi
          if [ -z "$decisions" ]; then decisions="$one"; else decisions="$decisions,$one"; fi
        done
        printf '{"schema":"tilde-lab.typist-decision-batch.v1","decisions":[%s]}' "$decisions"
        """#.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: script.path
        )
        return script
    }

    private static func twoPersonas() -> [LabTypistPersona] {
        [
            LabTypistPersona(
                id: "batch-fast",
                goal: .answerQuickly,
                register: .chat,
                typingSpeed: .fast,
                interruptionTolerance: .high
            ),
            LabTypistPersona(
                id: "batch-careful",
                goal: .draftCarefully,
                register: .prose,
                typingSpeed: .slow,
                interruptionTolerance: .low
            ),
        ]
    }

    /// Two scenarios whose candidates differ in length, so a recorded moment
    /// can be attributed to its session without any text crossing the contract.
    private static func distinguishableSuite() throws -> LabScenarioSuite {
        let scenarios = [
            LabScenario(
                id: "simulated.batch.one",
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
            ),
            LabScenario(
                id: "simulated.batch.two",
                category: "reply.simulated.smoke",
                typedContext: "It ",
                scene: LabScene(
                    mode: .replying,
                    turns: [LabSceneTurn(speaker: .other, text: "Does the afternoon slot still work?")]
                ),
                expectation: LabExpectation(
                    shouldSuggest: true,
                    goldenContinuation: "works for me either way today.",
                    acceptablePrefixes: ["works for me either way today."]
                )
            ),
        ]
        return try LabScenarioSuite(name: "simulated batch", scenarios: scenarios).validated()
    }

    /// Speaks both contracts, because a round's last batch may hold a single
    /// moment even when the policy batches: a moment batch is answered element
    /// for element, a lone moment with the single-moment envelope. The answer
    /// depends only on the moment, so it is identical however the run groups.
    private static func dualStub(in directory: URL, name: String) throws -> URL {
        let script = directory.appendingPathComponent(name)
        try #"""
        #!/bin/bash
        payload="$(cat)"
        case "$payload" in
          *Text*|*prompt*|*continuation*) exit 4 ;;
        esac
        decide() {
          if [ "$1" = "exact" ]; then
            printf '{"schema":"tilde-lab.typist-decision.v1","action":"accept","wouldRetain":true}'
          else
            printf '{"schema":"tilde-lab.typist-decision.v1","action":"dismiss","wouldRetain":false}'
          fi
        }
        matches="$(printf '%s' "$payload" | grep -o '"prefixMatch":"[a-z]*"' | sed 's/.*:"//;s/"//')"
        case "$payload" in
          *'"schema":"tilde-lab.typist-moment-batch.v1"'*)
            decisions=""
            for match in $matches; do
              one="$(decide "$match")"
              if [ -z "$decisions" ]; then decisions="$one"; else decisions="$decisions,$one"; fi
            done
            printf '{"schema":"tilde-lab.typist-decision-batch.v1","decisions":[%s]}' "$decisions" ;;
          *'"schema":"tilde-lab.typist-moment-features.v1"'*)
            decide "$matches" ;;
          *) exit 3 ;;
        esac
        """#.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: script.path
        )
        return script
    }

    /// Enough independent persona/scenario sessions that one round has several
    /// batches to resolve at once.
    private static func parallelSuite(scenarios: Int) throws -> LabScenarioSuite {
        let cases = (0..<scenarios).map { index in
            LabScenario(
                id: "simulated.parallel.\(index)",
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
        return try LabScenarioSuite(name: "simulated parallel", scenarios: cases).validated()
    }

    private static func report(
        decisionWorkers: Int = 1,
        assets: LabAssetSnapshot? = nil,
        skippedBatchAllowance: Int = 0,
        skippedBatches: Int = 0,
        abandonedSessions: Int = 0,
        abandonedMoments: Int = 0,
        personas: [LabSimulatedTypistPersonaSlice] = []
    ) -> LabSimulatedTypistReport {
        LabSimulatedTypistReport(
            startedAt: Date(),
            finishedAt: Date(),
            suiteName: "smoke",
            suiteDigestSHA256: String(repeating: "a", count: 64),
            scenarioCount: 1,
            arm: LabArmConfiguration(id: "baseline"),
            assets: assets,
            decisionPolicyIdentifier: DeterministicHeuristicTypist.identifier,
            decisionWorkers: decisionWorkers,
            skippedBatchAllowance: skippedBatchAllowance,
            skippedBatches: skippedBatches,
            abandonedSessions: abandonedSessions,
            abandonedMoments: abandonedMoments,
            provenance: .unavailable(),
            personas: personas
        )
    }

    private static func slice(abandonedScenarios: Int) -> LabSimulatedTypistPersonaSlice {
        LabSimulatedTypistPersonaSlice(
            personaID: "batch-fast",
            register: .chat,
            typingSpeed: .fast,
            interruptionTolerance: .high,
            scenarios: 1,
            abandonedScenarios: abandonedScenarios,
            opportunities: 1,
            displays: 0,
            accepts: 0,
            wordAccepts: 0,
            typeThroughs: 0,
            dismissals: 0,
            wrongDisplays: 0,
            silentMoments: 0,
            baselineCharacters: 0,
            acceptedCharacters: 0,
            correctionCharacters: 0,
            retainedCharacterPotential: 0
        )
    }

    /// A Lab-only alternate model, so a report built with it cannot be
    /// confused with a production Gemma run.
    private static func experimentalAssets(
        identifier: String = "qwen3-4b-instruct",
        revision: String = "2026-08-01",
        modelSHA256: String = String(repeating: "c", count: 64),
        helperSHA256: String = String(repeating: "d", count: 64)
    ) -> LabAssetSnapshot {
        LabAssetSnapshot(
            verificationMode: .experimentalLocal,
            modelIdentifier: identifier,
            modelRevision: revision,
            modelSHA256: modelSHA256,
            helperSHA256: helperSHA256
        )
    }

    /// A decision command that fails for one identifiable set of sessions, so a
    /// chosen batch fails on every machine rather than whichever one happened
    /// to be in flight. The careful persona's first display is answered — the
    /// session spends a real decision — and every later display of that persona
    /// exits non-zero, so an abandoned session always carries partial results
    /// the report must exclude rather than count.
    private static func poisonedStub(in directory: URL, name: String) throws -> URL {
        let script = directory.appendingPathComponent(name)
        try #"""
        #!/bin/bash
        payload="$(cat)"
        case "$payload" in
          *Text*|*prompt*|*continuation*) exit 4 ;;
        esac
        case "$payload" in
          *'"personaGoal":"draft-carefully"'*)
            case "$payload" in
              *'"displaysSoFar":1,'*)
                printf '{"schema":"tilde-lab.typist-decision.v1","action":"continue","wouldRetain":false}'
                exit 0 ;;
              *) exit 7 ;;
            esac ;;
        esac
        decide() {
          if [ "$1" = "exact" ]; then
            printf '{"schema":"tilde-lab.typist-decision.v1","action":"accept","wouldRetain":true}'
          else
            printf '{"schema":"tilde-lab.typist-decision.v1","action":"dismiss","wouldRetain":false}'
          fi
        }
        matches="$(printf '%s' "$payload" | grep -o '"prefixMatch":"[a-z]*"' | sed 's/.*:"//;s/"//')"
        case "$payload" in
          *'"schema":"tilde-lab.typist-moment-batch.v1"'*)
            decisions=""
            for match in $matches; do
              one="$(decide "$match")"
              if [ -z "$decisions" ]; then decisions="$one"; else decisions="$decisions,$one"; fi
            done
            printf '{"schema":"tilde-lab.typist-decision-batch.v1","decisions":[%s]}' "$decisions" ;;
          *'"schema":"tilde-lab.typist-moment-features.v1"'*)
            decide "$matches" ;;
          *) exit 3 ;;
        esac
        """#.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: script.path
        )
        return script
    }

    @discardableResult
    private static func simulate(
        command: URL,
        skippedBatchAllowance: Int,
        personas: [LabTypistPersona],
        scenarios: Int = 3,
        decisionWorkers: Int = 1
    ) async throws -> LabSimulatedTypistReport {
        var configuration = LabSimulatedTypistConfiguration(strideCharacters: 3)
        configuration.skippedBatchAllowance = skippedBatchAllowance
        configuration.decisionWorkers = decisionWorkers
        return try await LabSimulatedTypistEngine(
            configuration: configuration,
            policy: try ExternalCommandTypist(command: command.path, timeoutSeconds: 20)
        ).run(
            suite: try parallelSuite(scenarios: scenarios),
            personas: personas,
            client: StubCompletionClient(content: " sounds good to me."),
            provenance: .unavailable()
        )
    }

    /// A zombie check with no privileged access: how many live processes are
    /// running the stub command.
    private static func runningProcesses(matching path: String) -> Int {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", path]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return 0 }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
            .split(whereSeparator: \.isNewline).count
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

/// Records every batch it is handed, then answers with the frozen heuristic so
/// the batched and sequential drivers can be compared decision for decision.
private final class RecordingBatchTypist: TypistDecisionPolicy, @unchecked Sendable {
    let identifier = "recording-batch-typist"
    let decisionBatchSize: Int

    private let lock = NSLock()
    private var batches: [[LabTypistMomentFeatures]] = []
    private let inner = DeterministicHeuristicTypist()

    init(batchSize: Int) {
        decisionBatchSize = batchSize
    }

    func decide(_ features: LabTypistMomentFeatures) throws -> LabTypistDecision {
        try inner.decide(features)
    }

    func decide(batch: [LabTypistMomentFeatures]) throws -> [LabTypistDecision] {
        lock.lock()
        batches.append(batch)
        lock.unlock()
        return try batch.map { try inner.decide($0) }
    }

    func recordedBatches() -> [[LabTypistMomentFeatures]] {
        lock.lock()
        defer { lock.unlock() }
        return batches
    }
}

private enum ProbeFailure: Error, Equatable {
    case injected
}

/// Holds each call open long enough to overlap with its peers and records the
/// highest number that were ever inside `decide` at the same time.
private final class ConcurrencyProbeTypist: TypistDecisionPolicy, @unchecked Sendable {
    let identifier = "concurrency-probe-typist"
    let decisionBatchSize: Int

    private let holdSeconds: Double
    private let lock = NSLock()
    private var inFlight = 0
    private var peak = 0
    private var callCount = 0
    private let inner = DeterministicHeuristicTypist()

    init(batchSize: Int, holdSeconds: Double) {
        decisionBatchSize = batchSize
        self.holdSeconds = holdSeconds
    }

    func decide(_ features: LabTypistMomentFeatures) throws -> LabTypistDecision {
        try decide(batch: [features])[0]
    }

    func decide(batch: [LabTypistMomentFeatures]) throws -> [LabTypistDecision] {
        lock.lock()
        inFlight += 1
        callCount += 1
        peak = max(peak, inFlight)
        lock.unlock()
        if holdSeconds > 0 { Thread.sleep(forTimeInterval: holdSeconds) }
        defer {
            lock.lock()
            inFlight -= 1
            lock.unlock()
        }
        return try batch.map { try inner.decide($0) }
    }

    func peakConcurrency() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return peak
    }

    func calls() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return callCount
    }
}

/// Fails one nominated call after every call has had time to start, so the
/// abort happens with peers still in flight.
private final class FailingProbeTypist: TypistDecisionPolicy, @unchecked Sendable {
    let identifier = "failing-probe-typist"
    let decisionBatchSize = 1

    private let failOnCall: Int
    private let holdSeconds: Double
    private let lock = NSLock()
    private var startedCount = 0
    private var finishedCount = 0
    private let inner = DeterministicHeuristicTypist()

    init(failOnCall: Int, holdSeconds: Double) {
        self.failOnCall = failOnCall
        self.holdSeconds = holdSeconds
    }

    func decide(_ features: LabTypistMomentFeatures) throws -> LabTypistDecision {
        lock.lock()
        startedCount += 1
        let ordinal = startedCount
        lock.unlock()
        if holdSeconds > 0 { Thread.sleep(forTimeInterval: holdSeconds) }
        defer {
            lock.lock()
            finishedCount += 1
            lock.unlock()
        }
        guard ordinal != failOnCall else { throw ProbeFailure.injected }
        return try inner.decide(features)
    }

    func started() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return startedCount
    }

    func finished() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return finishedCount
    }
}

/// Answers with a different candidate per scenario so a recorded, text-free
/// moment can still be attributed to the session that produced it.
private struct PerScenarioStubClient: LabCompletionClient {
    let workerIndex = 0

    func complete(_ request: LabModelRequest) async throws -> LabModelResponse {
        let content = request.prompt.contains("usual day")
            ? " sounds good to me."
            : " works for me either way today."
        return LabModelResponse(
            content: content,
            latencyMilliseconds: 120,
            firstTokenMilliseconds: 40,
            meanTokenProbability: 0.8
        )
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
