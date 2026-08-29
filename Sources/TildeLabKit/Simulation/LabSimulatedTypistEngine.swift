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

    public init(
        arm: LabArmConfiguration = LabArmConfiguration(id: "simulated-typist-baseline"),
        strideCharacters: Int = 4,
        maximumDisplaysPerScenario: Int = 8,
        dismissalCooldownCharacters: Int = 12,
        timeoutSeconds: Double = 30
    ) {
        self.arm = arm
        self.strideCharacters = max(1, strideCharacters)
        self.maximumDisplaysPerScenario = max(1, maximumDisplaysPerScenario)
        self.dismissalCooldownCharacters = max(0, dismissalCooldownCharacters)
        self.timeoutSeconds = timeoutSeconds
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
    public func run(
        suite: LabScenarioSuite,
        personas: [LabTypistPersona],
        client: any LabCompletionClient,
        provenance: LabReportProvenance,
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
        if batchSize <= 1 {
            try await runSequentially(&sessions, client: client)
        } else {
            try await runBatched(&sessions, client: client, batchSize: batchSize)
        }

        var slices: [LabSimulatedTypistPersonaSlice] = []
        for (index, persona) in personas.enumerated() {
            var totals = PersonaTotals()
            for offset in 0..<simulatable.count {
                totals.add(sessions[index * simulatable.count + offset].outcome)
            }
            slices.append(totals.slice(persona: persona, scenarios: simulatable.count))
        }
        return try LabSimulatedTypistReport(
            startedAt: startedAt,
            finishedAt: Date(),
            suiteName: suite.name,
            suiteDigestSHA256: try suite.digestSHA256(),
            scenarioCount: simulatable.count,
            arm: configuration.arm,
            decisionPolicyIdentifier: policy.identifier,
            decisionBatchSize: batchSize,
            provenance: provenance,
            personas: slices
        ).validated()
    }

    /// The batch size actually used: what the policy asks for, clamped to the
    /// contract's ceiling. A policy that never opted in stays at 1.
    var effectiveBatchSize: Int {
        min(max(1, policy.decisionBatchSize), LabTypistMomentBatch.maximumSize)
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
    private func runBatched(
        _ sessions: inout [TypingSession],
        client: any LabCompletionClient,
        batchSize: Int
    ) async throws {
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
            var start = 0
            while start < pending.count {
                let end = min(start + batchSize, pending.count)
                let slice = Array(moments[start..<end])
                let decisions = try policy.decide(batch: slice)
                // A policy that drops, adds, or pads answers would silently
                // shift decisions onto the wrong scenarios; refuse instead.
                guard decisions.count == slice.count else {
                    throw LabTypistPolicyError.batchCountMismatch(
                        expected: slice.count, received: decisions.count
                    )
                }
                for offset in 0..<slice.count {
                    let index = pending[start + offset]
                    var session = sessions[index]
                    session.apply(decisions[offset])
                    sessions[index] = session
                }
                start = end
            }
            active = pending
        }
    }
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

    func slice(persona: LabTypistPersona, scenarios: Int) -> LabSimulatedTypistPersonaSlice {
        LabSimulatedTypistPersonaSlice(
            personaID: persona.id,
            register: persona.register,
            typingSpeed: persona.typingSpeed,
            interruptionTolerance: persona.interruptionTolerance,
            scenarios: scenarios,
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
