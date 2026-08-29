import Testing
@testable import TildeLabKit

@Suite("Early start timing falsifier")
struct LabEarlyStartRunnerTests {
    @Test("Only long words followed by a space and useful text become opportunities")
    func planning() {
        let cuts = LabEarlyStartPlanner.cuts(
            in: "should ship the release notes tomorrow",
            minimumUsefulCharacters: 6,
            maximumOpportunities: 8
        )
        // "the" is too short, "tomorrow" is last so no boundary follows it,
        // and "notes" leaves only " tomorrow" which still qualifies.
        #expect(cuts.map(\.cutOffset) == [3, 10, 19, 27])
        #expect(cuts[0].charactersToBoundary == 4)
        #expect(cuts[0].charactersAfterBoundary == 31)
    }

    @Test("A word with no following space is never an opportunity")
    func punctuationBoundary() {
        let cuts = LabEarlyStartPlanner.cuts(
            in: "sounds, good enough",
            minimumUsefulCharacters: 3,
            maximumOpportunities: 8
        )
        #expect(cuts.map(\.cutOffset) == [11])
    }

    @Test("Opportunities are capped so one situation cannot dominate compute")
    func opportunityCap() {
        let cuts = LabEarlyStartPlanner.cuts(
            in: "alpha bravo charlie delta echo foxtrot golf hotel india",
            minimumUsefulCharacters: 3,
            maximumOpportunities: 2
        )
        #expect(cuts.count == 2)
    }

    @Test("A ready, compatible, useful early branch locks and leads")
    func lockableBranch() {
        let measurement = measurement(
            charactersToBoundary: 4,
            remainder: "uld ship the release notes",
            cold: generation("uld ship the release", latency: 400, tokens: 8),
            boundary: generation("ship the release", latency: 380, tokens: 8)
        )
        #expect(LabEarlyStartAnalyzer.isReady(
            candidate: measurement.cold,
            measurement: measurement,
            keystrokeIntervalMilliseconds: 180
        ))
        #expect(LabEarlyStartAnalyzer.compatibleThroughBoundary(
            candidate: measurement.cold.text,
            measurement: measurement
        ))
        #expect(LabEarlyStartAnalyzer.futureCharactersBeyondBoundary(
            candidate: measurement.cold.text,
            measurement: measurement
        ) == 16)
        #expect(LabEarlyStartAnalyzer.leadMilliseconds(
            measurement: measurement,
            keystrokeIntervalMilliseconds: 180
        ) == 700)
    }

    @Test("A branch that finishes the word differently never locks")
    func incompatibleBranch() {
        let measurement = measurement(
            charactersToBoundary: 4,
            remainder: "uld ship the release notes",
            cold: generation("wing by tomorrow", latency: 200, tokens: 8),
            boundary: generation("ship the release", latency: 380, tokens: 8)
        )
        #expect(!LabEarlyStartAnalyzer.compatibleThroughBoundary(
            candidate: measurement.cold.text,
            measurement: measurement
        ))
        #expect(!LabEarlyStartAnalyzer.isLockable(
            candidate: measurement.cold,
            measurement: measurement,
            minimumUsefulCharacters: 6,
            keystrokeIntervalMilliseconds: 180
        ))
    }

    @Test("A slow branch is discarded even when it was right")
    func slowBranch() {
        let measurement = measurement(
            charactersToBoundary: 4,
            remainder: "uld ship the release notes",
            cold: generation("uld ship the release", latency: 900, tokens: 8),
            boundary: generation("ship the release", latency: 380, tokens: 8)
        )
        #expect(!LabEarlyStartAnalyzer.isReady(
            candidate: measurement.cold,
            measurement: measurement,
            keystrokeIntervalMilliseconds: 180
        ))
        #expect(!LabEarlyStartAnalyzer.isLockable(
            candidate: measurement.cold,
            measurement: measurement,
            minimumUsefulCharacters: 6,
            keystrokeIntervalMilliseconds: 180
        ))
    }

    @Test("A lock accepted only by normalization counts as a false lock")
    func falseLock() {
        let measurement = measurement(
            charactersToBoundary: 5,
            remainder: "cafe\u{301} is open today",
            cold: generation("caf\u{e9} is open today", latency: 300, tokens: 8),
            boundary: generation("is open today", latency: 300, tokens: 8)
        )
        #expect(LabEarlyStartAnalyzer.compatibleThroughBoundary(
            candidate: measurement.cold.text,
            measurement: measurement
        ))
        #expect(LabEarlyStartAnalyzer.isSimulatedFalseLock(
            measurement: measurement,
            keystrokeIntervalMilliseconds: 180
        ))
    }

    @Test("A surviving but unshowable branch still answers the boundary")
    func compatibleButTooShort() {
        let short = measurement(
            charactersToBoundary: 4,
            remainder: "uld ship the release notes",
            cold: generation("uld ship", latency: 300, tokens: 10),
            boundary: generation("ship the release", latency: 300, tokens: 10)
        )
        let metrics = LabEarlyStartAnalyzer.primary(
            measurements: [short],
            minimumUsefulCharacters: 6,
            keystrokeIntervalMilliseconds: 180
        )
        #expect(metrics.compatibleThroughBoundaryCount == 1)
        #expect(metrics.lockableCount == 0)
        // No second request: the branch is late-proof and uncontradicted.
        #expect(metrics.computeMultipleDecodedTokens == 1)
    }

    @Test("Compute adds the fallback only for a late or contradicted branch")
    func computeAccounting() {
        let locked = measurement(
            charactersToBoundary: 4,
            remainder: "uld ship the release notes",
            cold: generation("uld ship the release", latency: 400, tokens: 10),
            boundary: generation("ship the release", latency: 400, tokens: 10)
        )
        let discarded = measurement(
            charactersToBoundary: 4,
            remainder: "uld ship the release notes",
            cold: generation("wing by tomorrow", latency: 400, tokens: 10),
            boundary: generation("ship the release", latency: 400, tokens: 10)
        )
        let metrics = LabEarlyStartAnalyzer.primary(
            measurements: [locked, discarded],
            minimumUsefulCharacters: 6,
            keystrokeIntervalMilliseconds: 180
        )
        #expect(metrics.opportunityCount == 2)
        #expect(metrics.lockableCount == 1)
        // control 20 tokens; treatment 10 + 10 early plus 10 fallback = 30.
        #expect(metrics.computeMultipleDecodedTokens == 1.5)
        #expect(metrics.readyByBoundaryRate == 1)
    }

    @Test("The pair arm reports its own coverage, cost, and duplication")
    func pairArm() {
        let coldOnly = measurement(
            charactersToBoundary: 4,
            remainder: "uld ship the release notes",
            cold: generation("uld ship the release", latency: 300, tokens: 10),
            hot: generation("uld ship the release", latency: 300, tokens: 10),
            boundary: generation("ship the release", latency: 300, tokens: 10)
        )
        let hotOnly = measurement(
            charactersToBoundary: 4,
            remainder: "uld ship the release notes",
            cold: generation("wing by tomorrow", latency: 300, tokens: 10),
            hot: generation("uld ship the release", latency: 300, tokens: 10),
            boundary: generation("ship the release", latency: 300, tokens: 10)
        )
        let pair = LabEarlyStartAnalyzer.pair(
            measurements: [coldOnly, hotOnly],
            minimumUsefulCharacters: 6,
            keystrokeIntervalMilliseconds: 180
        )
        #expect(pair.coldLockableRate == 0.5)
        #expect(pair.pairLockableRate == 1)
        #expect(pair.pairCoverageGainPercentagePoints == 50)
        #expect(pair.hotOnlyLockCount == 1)
        #expect(pair.hotDuplicatesColdRate == 0.5)
        #expect(pair.hotCleanerSurvivalRate == 1)
        // control 20 tokens; pair 40 tokens with no fallback needed.
        #expect(pair.pairComputeMultipleDecodedTokens == 2)
    }

    @Test("Registered gates adjudicate the frozen Q10 numbers")
    func gates() {
        let passing = LabEarlyStartAnalyzer.primary(
            measurements: [
                measurement(
                    charactersToBoundary: 6,
                    remainder: "uldn\u{2019}t ship the release notes",
                    cold: generation("uldn\u{2019}t ship the release", latency: 300, tokens: 10),
                    boundary: generation("ship the release", latency: 300, tokens: 10)
                ),
            ],
            minimumUsefulCharacters: 6,
            keystrokeIntervalMilliseconds: 180
        )
        let pair = LabEarlyStartAnalyzer.pair(
            measurements: [],
            minimumUsefulCharacters: 6
        )
        let outcome = LabEarlyStartGateOutcome(primary: passing, pair: pair)
        #expect(outcome.readinessGatePassed)
        #expect(outcome.leadGatePassed)
        #expect(outcome.lockableGatePassed)
        #expect(outcome.falseLockGatePassed)
        #expect(outcome.computeGatePassed)
        #expect(outcome.primaryPromotionPassed)
        #expect(!outcome.pairCoverageGatePassed)
    }

    @Test("Replay moves typed characters out of the golden continuation")
    func replay() {
        let scenario = LabScenario(
            id: "case-1",
            category: "reply",
            typedContext: "Hi Sam, ",
            expectation: LabExpectation(
                shouldSuggest: true,
                goldenContinuation: "we should ship the notes",
                requiredTerms: ["we", "notes"]
            )
        )
        let replayed = LabEarlyStartRunner.replayed(scenario, typedSuffix: "we sho")
        #expect(replayed.typedContext == "Hi Sam, we sho")
        #expect(replayed.expectation.goldenContinuation == "uld ship the notes")
        #expect(replayed.expectation.requiredTerms == ["notes"])
    }

    private func generation(
        _ text: String,
        latency: Int,
        tokens: Int
    ) -> LabEarlyStartGeneration {
        LabEarlyStartGeneration(
            text: text,
            rawContinuation: text,
            latencyMilliseconds: latency,
            decodedTokens: tokens
        )
    }

    private func measurement(
        charactersToBoundary: Int,
        remainder: String,
        cold: LabEarlyStartGeneration,
        hot: LabEarlyStartGeneration? = nil,
        boundary: LabEarlyStartGeneration
    ) -> LabEarlyStartMeasurement {
        LabEarlyStartMeasurement(
            cut: LabEarlyStartCut(
                cutOffset: 3,
                charactersToBoundary: charactersToBoundary,
                charactersAfterBoundary: max(0, remainder.count - charactersToBoundary)
            ),
            remainderAfterCut: remainder,
            cold: cold,
            hot: hot ?? cold,
            boundary: boundary
        )
    }
}
