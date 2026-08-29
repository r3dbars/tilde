import TildeCore
import Foundation

/// F04 — the sanitized permanent regression library.
///
/// Every case freezes one historically discovered scoring loophole or
/// interaction failure as a deterministic, synthetic, text-safe check with a
/// stable identifier. A case passes only when BOTH halves hold:
///
/// - `guardHolds`: the frozen production-guard behavior stays safe; and
/// - `loopholeReproduced`: the known-unsafe diagnostic arm (or known-bad
///   evidence) still reproduces the historical failure, proving the case has
///   teeth rather than passing vacuously.
///
/// If a future change silently weakens a guard, `guardHolds` fails. If a
/// refactor makes the historical trap unrepresentable (so the case can no
/// longer detect anything), `loopholeReproduced` fails and the case must be
/// consciously retired, never quietly forgotten. All case content is
/// synthetic; no private writing, screens, prompts, or model output.
public struct LabPermanentRegressionOutcome: Equatable, Sendable {
    public let caseID: String
    public let failureClass: String
    public let guardHolds: Bool
    public let loopholeReproduced: Bool
    public let detail: String

    public var passed: Bool { guardHolds && loopholeReproduced }
}

public enum LabPermanentRegressions {
    public static let libraryVersion = "permanent-regressions.v1"

    public static let caseIdentifiers: [String] = [
        "regression.short-cap-echo-bypass.v1",
        "regression.repeat-penalty-aggression.v1",
        "regression.wrong-scene-facts.v1",
        "regression.stale-target-delivery.v1",
        "regression.prompt-example-removal.v1",
        "regression.factual-filter-weakening.v1",
        "regression.duplicate-insertion.v1",
        "regression.focus-change.v1",
        "regression.runtime-restart.v1",
        "regression.marked-text-damage.v1",
    ]

    public static func runAll() -> [LabPermanentRegressionOutcome] {
        [
            shortCapEchoBypass(),
            repeatPenaltyAggression(),
            wrongSceneFacts(),
            staleTargetDelivery(),
            promptExampleRemoval(),
            factualFilterWeakening(),
            duplicateInsertion(),
            focusChange(),
            runtimeRestart(),
            markedTextDamage(),
        ]
    }

    // MARK: - Scoring loopholes (ledger: qwen-9b-scoring-confounds)

    /// One- and two-word candidates fell below the three-word scene-echo
    /// floor, so a short visible cap made safety-rejected echoes score as
    /// shown. Guard: the full candidate is rejected as scene echo. Loophole:
    /// a two-word cap truncates the same output under the echo floor and it
    /// is shown.
    private static func shortCapEchoBypass() -> LabPermanentRegressionOutcome {
        let scenario = echoScenario()
        let raw = "coffee tomorrow morning"

        let guardArm = LabArmConfiguration()
        let guardDecision = judge(raw, scenario: scenario, arm: guardArm)

        var unsafeArm = LabArmConfiguration()
        unsafeArm.judgment.maximumVisibleWords = 2
        let unsafeDecision = judge(raw, scenario: scenario, arm: unsafeArm)

        return LabPermanentRegressionOutcome(
            caseID: "regression.short-cap-echo-bypass.v1",
            failureClass: "short-cap-echo-bypass",
            guardHolds: guardDecision.reason == .sceneEcho,
            loopholeReproduced: unsafeDecision.reason == .shown,
            detail: "guard=\(guardDecision.reason.rawValue) short-cap=\(unsafeDecision.reason.rawValue)"
        )
    }

    /// Repeat-heavy babble scored better by speaking more often. The frozen
    /// deterministic guard is the cleaner's self-repetition protection.
    /// Guard: repeated output is not shown verbatim. Loophole: a diagnostic
    /// arm with self-repetition protection off shows the babble.
    private static func repeatPenaltyAggression() -> LabPermanentRegressionOutcome {
        let scenario = echoScenario()
        let raw = "on my way on my way on my way on my way"

        let guardArm = LabArmConfiguration()
        let guardDecision = judge(raw, scenario: scenario, arm: guardArm)

        var unsafeArm = LabArmConfiguration()
        unsafeArm.judgment.cleanerPreset = .diagnostic
        unsafeArm.judgment.rejectsSelfRepetition = false
        let unsafeDecision = judge(raw, scenario: scenario, arm: unsafeArm)

        let guardSuggestion = guardDecision.suggestion ?? ""
        return LabPermanentRegressionOutcome(
            caseID: "regression.repeat-penalty-aggression.v1",
            failureClass: "repeat-penalty-aggression",
            guardHolds: guardSuggestion != raw,
            loopholeReproduced: unsafeDecision.suggestion?.split(separator: " ").count ?? 0
                > guardSuggestion.split(separator: " ").count,
            detail: "guard=\(guardDecision.reason.rawValue) diagnostic=\(unsafeDecision.reason.rawValue)"
        )
    }

    /// A candidate carrying a number that appears nowhere in the scene or
    /// typed context is a wrong-scene fact. Guard: numbers-and-names
    /// grounding rejects it. Loophole: grounding off delivers it.
    private static func wrongSceneFacts() -> LabPermanentRegressionOutcome {
        let scenario = meetingScenario()
        let raw = "Friday at 4 works"

        var guardArm = LabArmConfiguration()
        guardArm.judgment.factualGrounding = .numbersAndNames
        let guardDecision = judge(raw, scenario: scenario, arm: guardArm)

        var unsafeArm = LabArmConfiguration()
        unsafeArm.judgment.factualGrounding = .off
        let unsafeDecision = judge(raw, scenario: scenario, arm: unsafeArm)

        return LabPermanentRegressionOutcome(
            caseID: "regression.wrong-scene-facts.v1",
            failureClass: "wrong-scene-facts",
            guardHolds: guardDecision.reason == .unsupportedFact,
            loopholeReproduced: unsafeDecision.reason == .shown,
            detail: "guard=\(guardDecision.reason.rawValue) ungrounded=\(unsafeDecision.reason.rawValue)"
        )
    }

    /// A scene captured before the conversation changed must never reach the
    /// prompt. Guard: the freshness gate returns no scene for a 25-second-old
    /// snapshot under the 20-second cap. Loophole: bypassing the gate and
    /// classifying the same stale snapshot directly still yields a scene.
    private static func staleTargetDelivery() -> LabPermanentRegressionOutcome {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = ScreenSnapshot(
            capturedAt: now.addingTimeInterval(-25),
            displayID: 1,
            blocks: [
                ScreenSnapshot.TextBlock(
                    text: "are you around for a quick sync",
                    boundingBox: NormalizedDisplayRect(x: 0.05, y: 0.30, width: 0.35, height: 0.05),
                    windowOwnerBundleIdentifier: "com.example.synthetic-chat",
                    windowIdentifier: nil,
                    windowTitle: nil,
                    windowFrame: NormalizedDisplayRect(x: 0, y: 0, width: 1, height: 1),
                    confidence: nil
                ),
                ScreenSnapshot.TextBlock(
                    text: "yeah give me five minutes",
                    boundingBox: NormalizedDisplayRect(x: 0.55, y: 0.60, width: 0.35, height: 0.05),
                    windowOwnerBundleIdentifier: "com.example.synthetic-chat",
                    windowIdentifier: nil,
                    windowTitle: nil,
                    windowFrame: NormalizedDisplayRect(x: 0, y: 0, width: 1, height: 1),
                    confidence: nil
                ),
            ],
            evidence: nil
        )

        let gated = ScreenScene.freshScene(
            from: snapshot,
            now: now,
            frontmostBundleID: "com.example.synthetic-chat",
            fieldText: ""
        )
        let bypassed = ScreenScene.classify(
            snapshot: snapshot,
            frontmostBundleID: "com.example.synthetic-chat",
            fieldText: ""
        )

        return LabPermanentRegressionOutcome(
            caseID: "regression.stale-target-delivery.v1",
            failureClass: "stale-target-delivery",
            guardHolds: gated == nil,
            loopholeReproduced: !bypassed.conversationTurns.isEmpty,
            detail: "gated=\(gated == nil ? "refused" : "delivered") bypass-turns=\(bypassed.conversationTurns.count)"
        )
    }

    /// Removing the frozen prompt examples once looked like a win. Guard: the
    /// production prompt recipe carries the example scaffold's instruction
    /// line. Loophole: the minimal diagnostic recipe drops it.
    private static func promptExampleRemoval() -> LabPermanentRegressionOutcome {
        let scenario = meetingScenario()
        let marker = "Never reuse wording from the examples"

        let production = LabPromptComposer.prepare(
            scenario: scenario,
            configuration: LabPromptConfiguration()
        )
        var minimal = LabPromptConfiguration()
        minimal.recipe = .minimal
        let stripped = LabPromptComposer.prepare(scenario: scenario, configuration: minimal)

        return LabPermanentRegressionOutcome(
            caseID: "regression.prompt-example-removal.v1",
            failureClass: "prompt-example-removal",
            guardHolds: production.prompt.contains(marker),
            loopholeReproduced: !stripped.prompt.contains(marker),
            detail: "production-has-scaffold=\(production.prompt.contains(marker)) minimal-has-scaffold=\(stripped.prompt.contains(marker))"
        )
    }

    /// The strict scorer preset may not be weakened into ungrounded scoring.
    /// Guard: strict preset with grounding declared off still rejects an
    /// invented number. Loophole: the production preset with grounding off
    /// delivers the same candidate.
    private static func factualFilterWeakening() -> LabPermanentRegressionOutcome {
        let scenario = meetingScenario()
        let raw = "Friday at 4 works"

        var guardArm = LabArmConfiguration()
        guardArm.judgment.cleanerPreset = .strict
        guardArm.judgment.factualGrounding = .off
        let guardDecision = judge(raw, scenario: scenario, arm: guardArm)

        var unsafeArm = LabArmConfiguration()
        unsafeArm.judgment.cleanerPreset = .production
        unsafeArm.judgment.factualGrounding = .off
        let unsafeDecision = judge(raw, scenario: scenario, arm: unsafeArm)

        return LabPermanentRegressionOutcome(
            caseID: "regression.factual-filter-weakening.v1",
            failureClass: "factual-filter-weakening",
            guardHolds: guardDecision.reason == .unsupportedFact,
            loopholeReproduced: unsafeDecision.reason == .shown,
            detail: "strict=\(guardDecision.reason.rawValue) weakened=\(unsafeDecision.reason.rawValue)"
        )
    }

    // MARK: - Interaction failures (real-host gate sensitivity)

    /// The interaction gate must fail on a single stale insertion and pass on
    /// otherwise identical clean evidence.
    private static func duplicateInsertion() -> LabPermanentRegressionOutcome {
        interactionCase(
            caseID: "regression.duplicate-insertion.v1",
            failureClass: "duplicate-insertion",
            corrupt: { record in
                record.check == .committedTextIntegrity && record.host == .textEdit
                    ? interactionRecord(like: record, staleInsertions: 1)
                    : record
            }
        )
    }

    /// The interaction gate must fail on a focus-change failure.
    private static func focusChange() -> LabPermanentRegressionOutcome {
        interactionCase(
            caseID: "regression.focus-change.v1",
            failureClass: "focus-change",
            corrupt: { record in
                record.check == .focusChange && record.host == .textEdit
                    ? interactionRecord(like: record, failures: 1)
                    : record
            }
        )
    }

    /// The interaction gate must fail on a runtime-restart failure.
    private static func runtimeRestart() -> LabPermanentRegressionOutcome {
        interactionCase(
            caseID: "regression.runtime-restart.v1",
            failureClass: "runtime-restart",
            corrupt: { record in
                record.check == .runtimeRestart && record.host == .textEdit
                    ? interactionRecord(like: record, failures: 1)
                    : record
            }
        )
    }

    /// Marked-text damage has two frozen guards: committed-text corruption
    /// fails the interaction gate, and the streaming reveal path only ever
    /// exposes a stable word-boundary prefix, never an unstable fragment
    /// that a later token could rewrite.
    private static func markedTextDamage() -> LabPermanentRegressionOutcome {
        let gate = interactionCase(
            caseID: "regression.marked-text-damage.v1",
            failureClass: "marked-text-damage",
            corrupt: { record in
                record.check == .committedTextIntegrity && record.host == .textEdit
                    ? interactionRecord(like: record, committedTextCorruptions: 1)
                    : record
            }
        )
        let stream = "hello wor"
        let stable = StableStreamPrefix.prefix(of: stream)
        let boundaryOnly = stable == "hello" && stable != stream
        return LabPermanentRegressionOutcome(
            caseID: gate.caseID,
            failureClass: gate.failureClass,
            guardHolds: gate.guardHolds && boundaryOnly,
            loopholeReproduced: gate.loopholeReproduced,
            detail: gate.detail + " stable-prefix-boundary=\(boundaryOnly)"
        )
    }

    // MARK: - Shared synthetic fixtures

    private static func echoScenario() -> LabScenario {
        LabScenario(
            id: "regression.echo.root",
            category: "regression.synthetic",
            typedContext: "Sure, ",
            scene: LabScene(
                mode: .replying,
                turns: [
                    .init(speaker: .other, text: "are we still on for coffee tomorrow morning"),
                ]
            ),
            expectation: .init(shouldSuggest: true, goldenContinuation: "sounds good")
        )
    }

    private static func meetingScenario() -> LabScenario {
        LabScenario(
            id: "regression.meeting.root",
            category: "regression.synthetic",
            typedContext: "Sure, ",
            scene: LabScene(
                mode: .replying,
                turns: [.init(speaker: .other, text: "Can we meet Thursday at 3?")]
            ),
            expectation: .init(shouldSuggest: true, goldenContinuation: "Thursday at 3 works")
        )
    }

    private static func judge(
        _ raw: String,
        scenario: LabScenario,
        arm: LabArmConfiguration
    ) -> LabSuggestionDecision {
        let prepared = LabPromptComposer.prepare(scenario: scenario, configuration: arm.prompt)
        return LabOutputJudge.judge(
            rawOutput: raw,
            preparedPrompt: prepared,
            scenario: scenario,
            configuration: arm,
            meanTokenProbability: nil
        )
    }

    private static let interactionCampaignID = UUID(
        uuidString: "F04E0000-0000-4000-8000-000000000004"
    ) ?? UUID()
    private static let interactionDigest = String(repeating: "a", count: 64)

    private static func fullCoverageRecords() -> [LabInteractionEvidenceRecord] {
        LabInteractionHost.allCases.flatMap { host in
            LabInteractionCheck.allCases.map { check in
                LabInteractionEvidenceRecord(
                    campaignID: interactionCampaignID,
                    candidateArmID: "regression-guard-arm",
                    candidateArmDigestSHA256: interactionDigest,
                    host: host,
                    check: check,
                    attempts: 10
                )
            }
        }
    }

    private static func interactionRecord(
        like record: LabInteractionEvidenceRecord,
        failures: Int = 0,
        committedTextCorruptions: Int = 0,
        staleInsertions: Int = 0
    ) -> LabInteractionEvidenceRecord {
        LabInteractionEvidenceRecord(
            campaignID: record.campaignID,
            candidateArmID: record.candidateArmID,
            candidateArmDigestSHA256: record.candidateArmDigestSHA256,
            host: record.host,
            check: record.check,
            attempts: record.attempts,
            failures: failures,
            committedTextCorruptions: committedTextCorruptions,
            staleInsertions: staleInsertions
        )
    }

    /// guardHolds: the gate fails on the corrupted evidence.
    /// loopholeReproduced: the same gate passes on clean evidence, proving
    /// the failure signal — not a coverage artifact — drives the refusal.
    private static func interactionCase(
        caseID: String,
        failureClass: String,
        corrupt: (LabInteractionEvidenceRecord) -> LabInteractionEvidenceRecord
    ) -> LabPermanentRegressionOutcome {
        let clean = fullCoverageRecords()
        let corrupted = clean.map(corrupt)
        let cleanPassed = (try? LabInteractionEvidenceAnalyzer.analyze(
            clean,
            holdoutEvidenceDigestSHA256: interactionDigest
        ).passed) ?? false
        let corruptedPassed = (try? LabInteractionEvidenceAnalyzer.analyze(
            corrupted,
            holdoutEvidenceDigestSHA256: interactionDigest
        ).passed) ?? true
        return LabPermanentRegressionOutcome(
            caseID: caseID,
            failureClass: failureClass,
            guardHolds: !corruptedPassed,
            loopholeReproduced: cleanPassed,
            detail: "clean-gate=\(cleanPassed ? "passed" : "failed") corrupted-gate=\(corruptedPassed ? "passed" : "failed")"
        )
    }
}
