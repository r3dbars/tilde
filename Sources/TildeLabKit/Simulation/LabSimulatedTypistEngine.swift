import Foundation

public struct LabSimulatedTypistConfiguration: Sendable {
    /// The stack under test: the same prompt, generation, and display policy
    /// an ordinary Lab arm uses.
    public var arm: LabArmConfiguration
    /// Characters the persona types between two display opportunities.
    public var strideCharacters: Int
    /// Model calls allowed per persona/scenario pair.
    public var maximumDisplaysPerScenario: Int
    /// Characters a persona types before it will look at another ghost after
    /// clearing one.
    public var dismissalCooldownCharacters: Int
    public var timeoutSeconds: Double
    /// How many decision-policy calls of one round may be in flight at once.
    /// 1 is the sequential driver. Above 1 the round's batches — which already
    /// hold only causally independent sessions — are resolved concurrently, and
    /// the decisions are still applied in batch order.
    public var decisionWorkers: Int
    /// How many decision batches may fail — after the policy's own retries —
    /// before the run gives up. 0 is the historical behavior: one failed batch
    /// aborts the whole run. Above 0, that many failed batches abandon the
    /// sessions they held and the run continues; nothing about a skip is
    /// silent, because every one of them is counted into the report.
    public var skippedBatchAllowance: Int

    /// More than this many concurrent external commands buys throughput the
    /// decision backend cannot absorb and makes one failure cost more in-flight
    /// work than it saves.
    public static let maximumDecisionWorkers = 16

    /// Past this many skips a run is not surviving transient provider hiccups
    /// any more, it is grinding through a broken decision backend and throwing
    /// away its own sample. A run that needs more than this should fail and be
    /// re-launched, not quietly finish on whatever survived.
    public static let maximumSkippedBatches = 50

    public init(
        arm: LabArmConfiguration = LabArmConfiguration(id: "simulated-typist-baseline"),
        strideCharacters: Int = 4,
        maximumDisplaysPerScenario: Int = 8,
        dismissalCooldownCharacters: Int = 12,
        timeoutSeconds: Double = 30,
        decisionWorkers: Int = 1,
        skippedBatchAllowance: Int = 0
    ) {
        self.arm = arm
        self.strideCharacters = max(1, strideCharacters)
        self.maximumDisplaysPerScenario = max(1, maximumDisplaysPerScenario)
        self.dismissalCooldownCharacters = max(0, dismissalCooldownCharacters)
        self.timeoutSeconds = timeoutSeconds
        self.decisionWorkers = decisionWorkers
        self.skippedBatchAllowance = skippedBatchAllowance
    }
}

/// Drives a synthetic persona typing a scenario's golden continuation one
/// character at a time through the real Lab completion path: the production
/// prompt composer, the configured generation runner, the production cleaner,
/// and the Lab display judge. The only simulated part is the human at the
/// keyboard, which is exactly the part the decision policy owns.
public struct LabSimulatedTypistEngine: Sendable {
    private let configuration: LabSimulatedTypistConfiguration
    private let policy: any TypistDecisionPolicy

    public init(
        configuration: LabSimulatedTypistConfiguration = .init(),
        policy: any TypistDecisionPolicy
    ) {
        self.configuration = configuration
        self.policy = policy
    }

    /// Runs every persona against every simulatable scenario and returns an
    /// aggregate-only, permanently fenced discovery report.
    ///
    /// `assets` is the fingerprint of the generation stack that produced the
    /// candidates: without it two reports from two different models are
    /// indistinguishable once they leave the machine that made them. It is
    /// optional only because a stubbed client has no model to fingerprint.
    public func run(
        suite: LabScenarioSuite,
        personas: [LabTypistPersona],
        client: any LabCompletionClient,
        provenance: LabReportProvenance,
        assets: LabAssetSnapshot? = nil,
        startedAt: Date = Date()
    ) async throws -> LabSimulatedTypistReport {
        let simulatable = suite.scenarios.filter {
            $0.expectation.shouldSuggest
                && ($0.expectation.goldenContinuation?.isEmpty == false)
        }
        guard !simulatable.isEmpty else {
            throw LabSimulatedTypistError.noSimulatableScenarios
        }
        // One session per persona/scenario pair, persona-major so the
        // sequential driver visits them in exactly the order stage 1 did.
        var sessions = personas.flatMap { persona in
            simulatable.map {
                TypingSession(scenario: $0, persona: persona, configuration: configuration)
            }
        }
        let batchSize = effectiveBatchSize
        let workers = effectiveDecisionWorkers
        let skipAllowance = effectiveSkippedBatchAllowance
        var abandonment = Abandonment()
        // The historical driver is kept for the historical configuration: with
        // no batching, no workers, and no skip allowance the run is exactly the
        // one stage 1 shipped.
        if batchSize <= 1, workers <= 1, skipAllowance == 0 {
            try await runSequentially(&sessions, client: client)
        } else {
            abandonment = try await runBatched(
                &sessions,
                client: client,
                batchSize: batchSize,
                workers: workers,
                skipAllowance: skipAllowance
            )
        }

        var slices: [LabSimulatedTypistPersonaSlice] = []
        for (index, persona) in personas.enumerated() {
            var totals = PersonaTotals()
            var abandonedScenarios = 0
            for offset in 0..<simulatable.count {
                let session = sessions[index * simulatable.count + offset]
                // An abandoned session is dropped whole, not zero-filled: its
                // partial displays never became a decision the writer made, so
                // counting them as type-throughs or dismissals would invent
                // behavior the simulator never observed.
                guard !session.isAbandoned else {
                    abandonedScenarios += 1
                    continue
                }
                totals.add(session.outcome)
            }
            slices.append(totals.slice(
                persona: persona,
                scenarios: simulatable.count - abandonedScenarios,
                abandonedScenarios: abandonedScenarios
            ))
        }
        return try LabSimulatedTypistReport(
            startedAt: startedAt,
            finishedAt: Date(),
            suiteName: suite.name,
            suiteDigestSHA256: try suite.digestSHA256(),
            scenarioCount: simulatable.count,
            arm: configuration.arm,
            assets: assets,
            decisionPolicyIdentifier: policy.identifier,
            decisionBatchSize: batchSize,
            decisionWorkers: workers,
            skippedBatchAllowance: skipAllowance,
            skippedBatches: abandonment.skippedBatches,
            abandonedSessions: abandonment.sessions.count,
            abandonedMoments: abandonment.moments,
            provenance: provenance,
            personas: slices
        ).validated()
    }

    /// The batch size actually used: what the policy asks for, clamped to the
    /// contract's ceiling. A policy that never opted in stays at 1.
    var effectiveBatchSize: Int {
        min(max(1, policy.decisionBatchSize), LabTypistMomentBatch.maximumSize)
    }

    /// How many of a round's batches may be resolved at once, clamped to the
    /// contract's ceiling. A run that never opted in stays at 1.
    var effectiveDecisionWorkers: Int {
        min(
            max(1, configuration.decisionWorkers),
            LabSimulatedTypistConfiguration.maximumDecisionWorkers
        )
    }

    /// How many failed decision batches this run may skip, clamped to the
    /// contract's ceiling. A run that never opted in stays at 0 and aborts on
    /// the first failure, exactly as before.
    var effectiveSkippedBatchAllowance: Int {
        min(
            max(0, configuration.skippedBatchAllowance),
            LabSimulatedTypistConfiguration.maximumSkippedBatches
        )
    }

    // MARK: - Drivers

    /// Batch size 1: one session is typed to its end before the next one
    /// starts, which is exactly the stage 1 loop.
    private func runSequentially(
        _ sessions: inout [TypingSession],
        client: any LabCompletionClient
    ) async throws {
        for index in sessions.indices {
            var session = sessions[index]
            while let features = try await session.nextMoment(client: client) {
                session.apply(try policy.decide(features))
            }
            sessions[index] = session
        }
    }

    /// Batch size N: every still-active session is advanced to its own next
    /// undecided moment, and those moments are then decided in groups.
    ///
    /// INVARIANT — the batch grouping is decision-independent. Typing one
    /// scenario is strictly sequential: a decision changes how many characters
    /// the writer has typed, the dismissal cooldown, and the display and
    /// dismissal counts that the *next* moment of that same scenario reports.
    /// So two moments of one session may never share a batch. A round collects
    /// at most one pending moment per session (a session is advanced again only
    /// after its pending decision has been applied), so every batch holds
    /// moments from distinct persona/scenario sessions, which are causally
    /// independent of one another by construction. Batching therefore widens
    /// across scenarios and personas only, never along a scenario's own
    /// timeline, and the aggregates are identical to the sequential driver's.
    ///
    /// `workers` above 1 resolves several of a round's batches at the same
    /// time. That is safe for exactly the same reason batching is: the round's
    /// batches partition one round's moments, and a round holds at most one
    /// moment per session, so no two concurrent calls can touch one session's
    /// timeline. Concurrency is confined to the policy calls — the moments are
    /// collected before the round and every decision is applied after it, in
    /// batch order — so completion order cannot reach the aggregates.
    ///
    /// `skipAllowance` above 0 lets a failed batch abandon the sessions it held
    /// instead of ending the run. The failure verdict is taken in batch order
    /// after the round has joined, never in completion order, so which batches
    /// a run skips is a property of the policy's answers and not of the
    /// machine's scheduling. Abandoned sessions are never advanced again and
    /// never reach an aggregate; their surviving siblings are untouched,
    /// because sessions were already independent of one another.
    private func runBatched(
        _ sessions: inout [TypingSession],
        client: any LabCompletionClient,
        batchSize: Int,
        workers: Int,
        skipAllowance: Int
    ) async throws -> Abandonment {
        var abandonment = Abandonment()
        var active = Array(sessions.indices)
        while !active.isEmpty {
            var pending: [Int] = []
            var moments: [LabTypistMomentFeatures] = []
            for index in active {
                var session = sessions[index]
                let features = try await session.nextMoment(client: client)
                sessions[index] = session
                if let features {
                    pending.append(index)
                    moments.append(features)
                }
            }
            // The invariant the whole design rests on, checked rather than
            // assumed: one round carries at most one moment per session, so no
            // batch — sequential or concurrent — can hold two moments of one
            // persona/scenario timeline.
            guard Set(pending).count == pending.count else {
                throw LabSimulatedTypistError.sessionCollisionInRound
            }

            var batches: [[LabTypistMomentFeatures]] = []
            var owners: [[Int]] = []
            var start = 0
            while start < pending.count {
                let end = min(start + batchSize, pending.count)
                batches.append(Array(moments[start..<end]))
                owners.append(Array(pending[start..<end]))
                start = end
            }

            let answers = try await resolve(
                batches,
                workers: workers,
                skipBudget: skipAllowance - abandonment.skippedBatches
            )
            // Apply strictly in batch order, after the whole round has joined.
            // Whatever order the calls finished in, this loop is the same.
            var survivors: [Int] = []
            for (batch, answer) in zip(batches.indices, answers) {
                switch answer {
                case let .success(decisions):
                    // A policy that drops, adds, or pads answers would silently
                    // shift decisions onto the wrong scenarios; refuse instead.
                    guard decisions.count == batches[batch].count else {
                        throw LabTypistPolicyError.batchCountMismatch(
                            expected: batches[batch].count, received: decisions.count
                        )
                    }
                    for offset in 0..<decisions.count {
                        let index = owners[batch][offset]
                        var session = sessions[index]
                        session.apply(decisions[offset])
                        sessions[index] = session
                        survivors.append(index)
                    }
                case let .failure(error):
                    // The allowance is spent in batch order, so the batch that
                    // exceeds it — and the error that ends the run — is the
                    // same one on every machine.
                    guard abandonment.skippedBatches < skipAllowance else { throw error }
                    abandonment.skippedBatches += 1
                    for index in owners[batch] {
                        var session = sessions[index]
                        abandonment.sessions.insert(index)
                        abandonment.moments += session.decisionMoments
                        session.abandon()
                        sessions[index] = session
                    }
                }
            }
            active = survivors
        }
        return abandonment
    }

    /// Resolves one round's batches, at most `workers` policy calls in flight,
    /// and returns one answer per batch in batch order regardless of completion
    /// order. A failure is an answer here, not an exception: the caller owns
    /// the verdict, so the same failures always produce the same outcome.
    ///
    /// `skipBudget` is how many failures the caller can still absorb. While a
    /// failure is survivable this method resolves the whole round, so a failed
    /// batch never cancels a sibling that was already in flight. Once the
    /// failures in one round exceed the budget the run is going to abort no
    /// matter which batch the caller lands on, so scheduling stops, the batches
    /// still running are awaited, and the error is thrown — the historical
    /// behavior at a budget of 0, where the first failure ends the round.
    private func resolve(
        _ batches: [[LabTypistMomentFeatures]],
        workers: Int,
        skipBudget: Int
    ) async throws -> [Result<[LabTypistDecision], any Error>] {
        if workers <= 1 || batches.count <= 1 {
            var answers: [Result<[LabTypistDecision], any Error>] = []
            answers.reserveCapacity(batches.count)
            var failures = 0
            for batch in batches {
                try Task.checkCancellation()
                do {
                    answers.append(.success(try policy.decide(batch: batch)))
                } catch {
                    failures += 1
                    guard failures <= skipBudget else { throw error }
                    answers.append(.failure(error))
                }
            }
            return answers
        }
        let policy = self.policy
        var answers = [Int: Result<[LabTypistDecision], any Error>](
            minimumCapacity: batches.count
        )
        var failures = 0
        var abort: (any Error)?
        await withTaskGroup(of: BatchAnswer.self) { group in
            var next = 0
            var running = 0
            while next < batches.count || running > 0 {
                while running < workers, next < batches.count, abort == nil {
                    let index = next
                    let batch = batches[index]
                    group.addTask {
                        await Self.decide(batch: batch, index: index, with: policy)
                    }
                    next += 1
                    running += 1
                }
                guard let answer = await group.next() else { break }
                answers[answer.index] = answer.result
                running -= 1
                if case let .failure(error) = answer.result {
                    failures += 1
                    if failures > skipBudget, abort == nil {
                        abort = error
                        // Nothing more may start; what is already running is
                        // still awaited, so no decision command outlives the
                        // run even when it ends here.
                        group.cancelAll()
                    }
                }
            }
        }
        if let abort { throw abort }
        return try batches.indices.map { index in
            guard let answer = answers[index] else {
                throw LabTypistPolicyError.batchCountMismatch(
                    expected: batches[index].count, received: 0
                )
            }
            return answer
        }
    }

    /// One batch's answer, carried back out of the task group. The policy's own
    /// error type is not `Sendable`, so it crosses the boundary in a box that
    /// is only ever written once, before the task returns it.
    private struct BatchAnswer: @unchecked Sendable {
        let index: Int
        let result: Result<[LabTypistDecision], any Error>
    }

    /// The decision contract is synchronous — an external command is a process,
    /// not an async call — so a concurrent batch runs on a global queue rather
    /// than parking a cooperative thread the completion path also needs.
    private static func decide(
        batch: [LabTypistMomentFeatures],
        index: Int,
        with policy: any TypistDecisionPolicy
    ) async -> BatchAnswer {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: BatchAnswer(
                    index: index,
                    result: Result { try policy.decide(batch: batch) }
                ))
            }
        }
    }
}

/// What a run threw away to keep going: the failed batches it skipped, the
/// persona/scenario sessions those batches held, and the decision moments that
/// went with them. Every field ends up in the report; none of them is ever
/// folded into a persona's behavior.
private struct Abandonment {
    var skippedBatches = 0
    var sessions: Set<Int> = []
    var moments = 0
}

// MARK: - One persona typing one scenario

/// The keystroke driver for a single persona/scenario pair, split so the moment
/// that needs a decision can be handed out and the decision applied later. The
/// session is only ever advanced past a display once that display's decision
/// has been applied, which is what makes cross-session batching safe.
private struct TypingSession {
    let scenario: LabScenario
    let persona: LabTypistPersona
    let configuration: LabSimulatedTypistConfiguration
    private(set) var outcome = ScenarioOutcome()
    /// True once a failed decision batch abandoned this pair. An abandoned
    /// session is never advanced again and never reaches an aggregate.
    private(set) var isAbandoned = false

    /// The decision moments this session has produced — every display that was
    /// handed to the policy, including the one whose batch failed. It is what a
    /// skip costs, so it is what the report counts.
    var decisionMoments: Int { outcome.displays }

    private let golden: String?
    private var typedCount = 0
    private var cooldown = 0
    /// The display awaiting a decision. Non-nil exactly between `nextMoment`
    /// returning a moment and `apply` consuming it.
    private var pending: PendingDisplay?

    private struct PendingDisplay {
        let candidate: String
        let matchedPrefixCharacters: Int
    }

    init(
        scenario: LabScenario,
        persona: LabTypistPersona,
        configuration: LabSimulatedTypistConfiguration
    ) {
        self.scenario = scenario
        self.persona = persona
        self.configuration = configuration
        golden = scenario.expectation.goldenContinuation
        if let golden {
            outcome.baselineCharacters = golden.count
            outcome.opportunities = 1
        }
    }

    /// Types forward through silence until the next display, or returns nil
    /// when this scenario is finished.
    mutating func nextMoment(
        client: any LabCompletionClient
    ) async throws -> LabTypistMomentFeatures? {
        guard let golden else { return nil }
        while typedCount < golden.count, outcome.displays < configuration.maximumDisplaysPerScenario {
            try Task.checkCancellation()
            if cooldown > 0 {
                let step = min(cooldown, golden.count - typedCount)
                typedCount += step
                cooldown -= step
                continue
            }
            let split = golden.index(golden.startIndex, offsetBy: typedCount)
            let typed = String(golden[..<split])
            let remaining = String(golden[split...])
            guard !remaining.isEmpty else { break }

            let moment = LabPrefixReplay.momentScenario(
                scenario,
                typed: typed,
                remaining: remaining
            )
            let prepared = LabPromptComposer.prepare(
                scenario: moment,
                configuration: configuration.arm.prompt
            )
            let response = try await client.complete(LabModelRequest(
                prompt: prepared.prompt,
                generation: configuration.arm.generation,
                timeoutSeconds: configuration.timeoutSeconds
            ))
            let judged = LabOutputJudge.judge(
                rawOutput: response.content,
                preparedPrompt: prepared,
                scenario: moment,
                configuration: configuration.arm,
                meanTokenProbability: response.meanTokenProbability
            )
            guard let candidate = judged.suggestion, !candidate.isEmpty else {
                outcome.silentMoments += 1
                typedCount = min(golden.count, typedCount + configuration.strideCharacters)
                continue
            }

            outcome.displays += 1
            let matched = matchedPrefixCharacters(candidate: candidate, remaining: remaining)
            if matched == 0 { outcome.wrongDisplays += 1 }
            let features = features(
                candidate: candidate,
                remaining: remaining,
                matchedPrefixCharacters: matched,
                generationMilliseconds: response.latencyMilliseconds,
                meanTokenProbability: response.meanTokenProbability
            )
            pending = PendingDisplay(candidate: candidate, matchedPrefixCharacters: matched)
            return features
        }
        return nil
    }

    /// Drops this pair because the decision call that held its moment failed.
    /// The undecided display is discarded rather than guessed at, and the
    /// partial outcome is left for the aggregator to exclude whole.
    mutating func abandon() {
        pending = nil
        isAbandoned = true
    }

    /// Applies the decision for the display handed out by `nextMoment`. The
    /// session cannot advance until this has run, so the next moment of this
    /// scenario always sees the effect of this decision.
    mutating func apply(_ decision: LabTypistDecision) {
        guard let display = pending, let golden else { return }
        pending = nil
        let candidate = display.candidate
        let matched = display.matchedPrefixCharacters
        switch decision.action {
        case .accept:
            outcome.accepts += 1
            typedCount = apply(
                takenCharacters: matched,
                candidateCharacters: candidate.count,
                decision: decision
            )
        case .acceptWord:
            outcome.wordAccepts += 1
            let word = min(matched, firstWordLength(of: candidate))
            typedCount = apply(
                takenCharacters: word,
                candidateCharacters: min(candidate.count, firstWordLength(of: candidate)),
                decision: decision
            )
        case .continueTyping:
            outcome.typeThroughs += 1
            typedCount = min(golden.count, typedCount + configuration.strideCharacters)
        case .dismiss:
            outcome.dismissals += 1
            cooldown = configuration.dismissalCooldownCharacters
            typedCount = min(golden.count, typedCount + configuration.strideCharacters)
        }
    }

    /// Accepting takes the characters that agree with what the writer meant.
    /// Anything past that agreement is a correction they have to make, and a
    /// judgment that the text would not survive re-reading forfeits the
    /// retained-character credit even though the keystrokes were saved.
    private mutating func apply(
        takenCharacters: Int,
        candidateCharacters: Int,
        decision: LabTypistDecision
    ) -> Int {
        let taken = max(0, takenCharacters)
        outcome.acceptedCharacters += taken
        outcome.correctionCharacters += max(0, candidateCharacters - taken)
        if decision.wouldRetain { outcome.retainedCharacterPotential += taken }
        // A zero-agreement acceptance still moves the writer forward by the
        // stride they type while repairing it.
        return typedCount + max(taken, configuration.strideCharacters)
    }

    private func features(
        candidate: String,
        remaining: String,
        matchedPrefixCharacters: Int,
        generationMilliseconds: Int,
        meanTokenProbability: Double?
    ) -> LabTypistMomentFeatures {
        let words = candidate.split(whereSeparator: \.isWhitespace).count
        let prefixMatch: LabTypistPrefixMatch
        if matchedPrefixCharacters >= candidate.count {
            prefixMatch = .exact
        } else if matchedPrefixCharacters > 0 {
            prefixMatch = .partial
        } else {
            prefixMatch = .divergent
        }
        // The writer keeps typing while the model works; a display that lands
        // after they have moved on is late by construction.
        let sinceDisplay = max(0, generationMilliseconds)
        return LabTypistMomentFeatures(
            personaGoal: persona.goal,
            personaRegister: persona.register,
            personaTypingSpeed: persona.typingSpeed,
            personaInterruptionTolerance: persona.interruptionTolerance,
            boundary: boundary(afterTyping: typedCount, remaining: remaining),
            candidateLengthBucket: .from(wordCount: words),
            candidateCharacterCount: candidate.count,
            candidateWordCount: words,
            prefixMatch: prefixMatch,
            matchedPrefixCharacters: matchedPrefixCharacters,
            typedCharacters: typedCount,
            remainingCharacters: remaining.count,
            displaysSoFar: outcome.displays,
            dismissalsSoFar: outcome.dismissals,
            millisecondsSinceDisplay: sinceDisplay,
            generationMilliseconds: generationMilliseconds,
            meanTokenProbabilityBucket: .from(meanTokenProbability: meanTokenProbability)
        )
    }

    private func boundary(afterTyping typedCharacters: Int, remaining: String) -> LabOnlineBoundary {
        guard let next = remaining.first else { return .wordBoundary }
        if typedCharacters == 0 { return .sentenceBoundary }
        return next.isWhitespace ? .wordBoundary : .midWord
    }

    private func matchedPrefixCharacters(candidate: String, remaining: String) -> Int {
        var count = 0
        var candidateIndex = candidate.startIndex
        var remainingIndex = remaining.startIndex
        while candidateIndex < candidate.endIndex, remainingIndex < remaining.endIndex,
              candidate[candidateIndex] == remaining[remainingIndex] {
            count += 1
            candidateIndex = candidate.index(after: candidateIndex)
            remainingIndex = remaining.index(after: remainingIndex)
        }
        return count
    }

    private func firstWordLength(of candidate: String) -> Int {
        let trimmed = candidate.drop(while: \.isWhitespace)
        let leading = candidate.count - trimmed.count
        let word = trimmed.prefix(while: { !$0.isWhitespace })
        return leading + word.count
    }
}

// MARK: - Aggregation

private struct ScenarioOutcome {
    var opportunities = 0
    var displays = 0
    var accepts = 0
    var wordAccepts = 0
    var typeThroughs = 0
    var dismissals = 0
    var wrongDisplays = 0
    var silentMoments = 0
    var baselineCharacters = 0
    var acceptedCharacters = 0
    var correctionCharacters = 0
    var retainedCharacterPotential = 0
}

private struct PersonaTotals {
    var totals = ScenarioOutcome()

    mutating func add(_ outcome: ScenarioOutcome) {
        totals.opportunities += outcome.opportunities
        totals.displays += outcome.displays
        totals.accepts += outcome.accepts
        totals.wordAccepts += outcome.wordAccepts
        totals.typeThroughs += outcome.typeThroughs
        totals.dismissals += outcome.dismissals
        totals.wrongDisplays += outcome.wrongDisplays
        totals.silentMoments += outcome.silentMoments
        totals.baselineCharacters += outcome.baselineCharacters
        totals.acceptedCharacters += outcome.acceptedCharacters
        totals.correctionCharacters += outcome.correctionCharacters
        totals.retainedCharacterPotential += outcome.retainedCharacterPotential
    }

    func slice(
        persona: LabTypistPersona,
        scenarios: Int,
        abandonedScenarios: Int
    ) -> LabSimulatedTypistPersonaSlice {
        LabSimulatedTypistPersonaSlice(
            personaID: persona.id,
            register: persona.register,
            typingSpeed: persona.typingSpeed,
            interruptionTolerance: persona.interruptionTolerance,
            scenarios: scenarios,
            abandonedScenarios: abandonedScenarios,
            opportunities: totals.opportunities,
            displays: totals.displays,
            accepts: totals.accepts,
            wordAccepts: totals.wordAccepts,
            typeThroughs: totals.typeThroughs,
            dismissals: totals.dismissals,
            wrongDisplays: totals.wrongDisplays,
            silentMoments: totals.silentMoments,
            baselineCharacters: totals.baselineCharacters,
            acceptedCharacters: totals.acceptedCharacters,
            correctionCharacters: totals.correctionCharacters,
            retainedCharacterPotential: totals.retainedCharacterPotential
        )
    }
}
