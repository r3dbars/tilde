import Foundation

/// Fixed promotion thresholds for the improved evaluation. They are product
/// guardrails, not per-arm knobs, so an experiment cannot win by weakening
/// the definition of "ready."
public enum LabScorecardV3 {
    public static let minimumUsefulnessRate = 0.80
    public static let minimumOrdinaryRestraintRate = 0.98
    public static let requiredSensitiveRestraintRate = 1.0
    public static let minimumFactualityRate = 0.99
    public static let minimumCounterfactualPairPassRate = 0.80
    public static let maximumP95LatencyMilliseconds = 1_000
}

public enum LabScorer {
    public static func score(
        scenario: LabScenario,
        repetition: Int,
        generationSeed: Int = 0,
        suggestion: String?,
        policySuppressed: Bool = false,
        modelRequested: Bool = false,
        latencyMilliseconds: Int? = nil,
        firstTokenMilliseconds: Int? = nil,
        meanTokenProbability: Double? = nil,
        decisionReason: LabDecisionReason = .shown,
        workerIndex: Int? = nil,
        candidateCacheHit: Bool? = nil
    ) -> LabCaseResult {
        let expectation = scenario.expectation
        let offeredWords = words(in: suggestion ?? "")
        let offered = !offeredWords.isEmpty
        let goldenWords = words(in: expectation.goldenContinuation ?? "")
        let exact1 = exactMatch(offeredWords, goldenWords, count: 1)
        let exact2 = exactMatch(offeredWords, goldenWords, count: 2)
        let exact3 = exactMatch(offeredWords, goldenWords, count: 3)
        let normalizedSuggestion = normalizedPhrase(suggestion ?? "")
        let normalizedGolden = normalizedPhrase(expectation.goldenContinuation ?? "")
        let exactContinuationMatched = !normalizedSuggestion.isEmpty
            && (normalizedSuggestion == normalizedGolden
                || normalizedGolden.hasPrefix(normalizedSuggestion + " "))
        let acceptablePrefixMatched = expectation.acceptablePrefixes.contains { prefix in
            let normalizedPrefix = normalizedPhrase(prefix)
            return prefixPathMatches(normalizedSuggestion, accepted: normalizedPrefix)
        }
        let acceptableContinuationMatched = expectation.acceptableContinuations.contains {
            matchesAcceptedContinuation(normalizedSuggestion, alternative: $0)
        }
        let requiredTermsSatisfied = expectation.requiredTerms.allSatisfy {
            containsTerm($0, in: normalizedSuggestion)
        }
        let forbiddenTermViolation = expectation.forbiddenTerms.contains {
            containsTerm($0, in: normalizedSuggestion)
        }
        let wordLimitViolation = expectation.maximumWords.map {
            offeredWords.count > $0
        } ?? false
        let accounting = keystrokeAccounting(
            suggestion: suggestion ?? "",
            golden: expectation.goldenContinuation ?? "",
            typedContext: scenario.typedContext,
            offered: offered,
            correctionKeystrokes: scenario.evaluation.correctionKeystrokes,
            dismissalKeystrokes: scenario.evaluation.dismissalKeystrokes
        )

        let answerMatchKind: LabAnswerMatchKind
        if exactContinuationMatched {
            answerMatchKind = .exactPrediction
        } else if acceptablePrefixMatched || acceptableContinuationMatched {
            answerMatchKind = .acceptableAlternative
        } else {
            answerMatchKind = .none
        }
        let hasAuthoredAnswerPath = !goldenWords.isEmpty
            || !expectation.acceptablePrefixes.isEmpty
            || !expectation.acceptableContinuations.isEmpty
        let hasPositiveMatch = answerMatchKind != .none
            || (!hasAuthoredAnswerPath && !expectation.requiredTerms.isEmpty && requiredTermsSatisfied)
        // Tilde displays a partial continuation. Missing a fact that appears
        // later in an accepted full reply is diagnostic, not a reason to call
        // a correct prefix wrong. A fact it does show must still never
        // contradict the scene, and the visible suggestion must remain bounded.
        let passesContentRules = !forbiddenTermViolation
            && !wordLimitViolation

        let outcome: LabCaseOutcome
        if expectation.shouldSuggest {
            if !offered {
                outcome = .silent
            } else if hasPositiveMatch && passesContentRules {
                outcome = .useful
            } else {
                outcome = .wrong
            }
        } else {
            outcome = offered ? .unwanted : .correctSilence
        }
        let finalAccounting = finalizedAccounting(
            accounting,
            outcome: outcome,
            offered: offered
        )
        let failureCategory = classifyFailure(
            outcome: outcome,
            exactMatchAt1: exact1,
            wordLimitViolation: wordLimitViolation,
            requiredTermsSatisfied: requiredTermsSatisfied,
            forbiddenTermViolation: forbiddenTermViolation,
            contextVariant: scenario.evaluation.contextVariant,
            tags: scenario.tags,
            decisionReason: decisionReason
        )

        return LabCaseResult(
            scenarioID: scenario.id,
            category: scenario.category,
            counterfactualPairID: scenario.tags.first(where: { $0.hasPrefix("pair-") }),
            repetition: repetition,
            generationSeed: generationSeed,
            outcome: outcome,
            expectedSuggestion: expectation.shouldSuggest,
            hasGoldenContinuation: expectation.goldenContinuation?.isEmpty == false,
            offered: offered,
            modelRequested: modelRequested,
            policySuppressed: policySuppressed,
            exactMatchAt1: exact1,
            exactMatchAt2: exact2,
            exactMatchAt3: exact3,
            exactContinuationMatched: exactContinuationMatched,
            acceptablePrefixMatched: acceptablePrefixMatched,
            acceptableContinuationMatched: acceptableContinuationMatched,
            answerMatchKind: answerMatchKind,
            requiredTermsSatisfied: requiredTermsSatisfied,
            forbiddenTermViolation: forbiddenTermViolation,
            wordLimitViolation: wordLimitViolation,
            scenarioSource: scenario.evaluation.source,
            corpusID: scenario.evaluation.corpusID,
            rootScenarioID: scenario.evaluation.rootScenarioID ?? scenario.id,
            replayCheckpoint: scenario.evaluation.checkpoint,
            contextVariant: scenario.evaluation.contextVariant,
            temporalIntegrityPassed: scenario.evaluation.temporalIntegrity.passed,
            baselineKeystrokes: finalAccounting.baseline,
            grossKeystrokesSaved: finalAccounting.gross,
            acceptanceKeystrokes: finalAccounting.acceptance,
            correctionKeystrokes: finalAccounting.correction,
            dismissalKeystrokes: finalAccounting.dismissal,
            netKeystrokesSaved: finalAccounting.net,
            failureCategory: failureCategory,
            keystrokesSaved: finalAccounting.gross,
            latencyMilliseconds: latencyMilliseconds,
            firstTokenMilliseconds: firstTokenMilliseconds,
            meanTokenProbability: meanTokenProbability,
            decisionReason: decisionReason,
            visibleWordCount: offeredWords.count,
            visibleCharacterCount: suggestion?.count ?? 0,
            workerIndex: workerIndex,
            candidateCacheHit: candidateCacheHit
        )
    }

    public static func failure(
        scenario: LabScenario,
        repetition: Int,
        generationSeed: Int = 0,
        outcome: LabCaseOutcome,
        workerIndex: Int?,
        decisionReason: LabDecisionReason? = nil,
        candidateCacheHit: Bool? = nil
    ) -> LabCaseResult {
        precondition(outcome == .timeout || outcome == .error)
        return LabCaseResult(
            scenarioID: scenario.id,
            category: scenario.category,
            counterfactualPairID: scenario.tags.first(where: { $0.hasPrefix("pair-") }),
            repetition: repetition,
            generationSeed: generationSeed,
            outcome: outcome,
            expectedSuggestion: scenario.expectation.shouldSuggest,
            hasGoldenContinuation: scenario.expectation.goldenContinuation?.isEmpty == false,
            offered: false,
            modelRequested: true,
            requiredTermsSatisfied: scenario.expectation.requiredTerms.isEmpty,
            scenarioSource: scenario.evaluation.source,
            corpusID: scenario.evaluation.corpusID,
            rootScenarioID: scenario.evaluation.rootScenarioID ?? scenario.id,
            replayCheckpoint: scenario.evaluation.checkpoint,
            contextVariant: scenario.evaluation.contextVariant,
            temporalIntegrityPassed: scenario.evaluation.temporalIntegrity.passed,
            baselineKeystrokes: scenario.expectation.goldenContinuation?.count ?? 0,
            failureCategory: .timing,
            decisionReason: decisionReason ?? (outcome == .timeout ? .timeout : .protocolError),
            workerIndex: workerIndex,
            candidateCacheHit: candidateCacheHit
        )
    }

    public static func aggregate(
        _ results: [LabCaseResult],
        elapsedSeconds: TimeInterval,
        scoring: LabScoringConfiguration = .init()
    ) -> LabAggregateMetrics {
        let counts = Dictionary(grouping: results, by: \.outcome).mapValues(\.count)
        let completed = results.filter { $0.outcome != .timeout && $0.outcome != .error }
        let positive = completed.filter(\.expectedSuggestion)
        let restraint = completed.filter { !$0.expectedSuggestion }
        let sensitiveRestraint = restraint.filter { $0.category.hasPrefix("silence.sensitive.") }
        let ordinaryRestraint = restraint.filter { !$0.category.hasPrefix("silence.sensitive.") }
        let golden = completed.filter(\.hasGoldenContinuation)
        let latencies = completed.compactMap(\.latencyMilliseconds).sorted()
        let firstTokenLatencies = completed.compactMap(\.firstTokenMilliseconds).sorted()
        let probabilities = completed.compactMap(\.meanTokenProbability)
        let modelRequests = results.count(where: \.modelRequested)
        let useful = counts[.useful, default: 0]
        let exactPredictions = positive.count {
            $0.outcome == .useful && $0.answerMatchKind == .exactPrediction
        }
        let acceptableAlternatives = positive.count {
            $0.outcome == .useful && $0.answerMatchKind == .acceptableAlternative
        }
        let correctSilence = counts[.correctSilence, default: 0]
        let usefulnessRate = rate(useful, positive.count)
        let restraintRate = rate(correctSilence, restraint.count)
        let ordinaryRestraintRate = ordinaryRestraint.isEmpty
            ? nil
            : rate(ordinaryRestraint.count(where: { $0.outcome == .correctSilence }), ordinaryRestraint.count)
        let sensitiveRestraintRate = sensitiveRestraint.isEmpty
            ? nil
            : rate(sensitiveRestraint.count(where: { $0.outcome == .correctSilence }), sensitiveRestraint.count)
        let errors = counts[.error, default: 0]
        let timeouts = counts[.timeout, default: 0]
        let offered = completed.filter(\.offered)
        let grounded = completed.filter(\.modelRequested)
        let factFailures = grounded.count {
            $0.forbiddenTermViolation || $0.decisionReason == .unsupportedFact
        }
        let factualityRate = grounded.isEmpty ? 0 : 1 - rate(factFailures, grounded.count)
        let brevityRate = offered.isEmpty
            ? 0
            : rate(offered.count(where: { !$0.wordLimitViolation }), offered.count)
        let pairGroups = Dictionary(
            grouping: completed.compactMap { result -> LabCaseResult? in
                result.counterfactualPairID == nil ? nil : result
            },
            by: { "\($0.counterfactualPairID!)#seed-\($0.generationSeed)#\($0.repetition)" }
        ).values.filter { $0.count >= 2 }
        let counterfactualPairPassRate = pairGroups.isEmpty
            ? nil
            : rate(
                pairGroups.count(where: { pair in
                    pair.allSatisfy { $0.outcome == .useful || $0.outcome == .correctSilence }
                }),
                pairGroups.count
            )
        let p95Latency = percentile(latencies, fraction: 0.95)
        let baselineKeystrokes = results.reduce(0) { $0 + $1.baselineKeystrokes }
        let grossKeystrokesSaved = results.reduce(0) { $0 + $1.grossKeystrokesSaved }
        let acceptanceKeystrokes = results.reduce(0) { $0 + $1.acceptanceKeystrokes }
        let correctionKeystrokes = results.reduce(0) { $0 + $1.correctionKeystrokes }
        let dismissalKeystrokes = results.reduce(0) { $0 + $1.dismissalKeystrokes }
        let netKeystrokesSaved = results.reduce(0) { $0 + $1.netKeystrokesSaved }
        let netSavingsRate = baselineKeystrokes > 0
            ? Double(netKeystrokesSaved) / Double(baselineKeystrokes)
            : 0
        let badSuggestionRate = rate(
            counts[.wrong, default: 0] + counts[.unwanted, default: 0],
            completed.count
        )
        let temporalIntegrityRate = rate(
            results.count(where: \.temporalIntegrityPassed),
            results.count
        )
        let gates = goalGates(
            completed: completed,
            sensitiveRestraintCount: sensitiveRestraint.count,
            sensitiveRestraintRate: sensitiveRestraintRate,
            badSuggestionRate: badSuggestionRate,
            temporalIntegrityRate: temporalIntegrityRate,
            p95LatencyMilliseconds: p95Latency,
            errors: errors,
            timeouts: timeouts
        )

        let replyScore: Int?
        if results.isEmpty || errors > 0 || timeouts > 0 {
            replyScore = nil
        } else {
            var weighted = 0.0
            var totalWeight = 0.0
            if !positive.isEmpty {
                weighted += usefulnessRate * 0.75
                totalWeight += 0.75
            }
            if !restraint.isEmpty {
                weighted += restraintRate * 0.25
                totalWeight += 0.25
            }
            replyScore = totalWeight > 0 ? Int((weighted / totalWeight * 100).rounded()) : nil
        }

        let qualityScore: Int?
        if results.isEmpty || errors > 0 || timeouts > 0 {
            qualityScore = nil
        } else if scoring.usesScorecardV3 || scoring.usesGoalContract {
            if !positive.isEmpty, let ordinaryRestraintRate {
                let balancedBehavior = weakLinkBalance(usefulnessRate, ordinaryRestraintRate)
                qualityScore = Int((balancedBehavior * factualityRate * 100).rounded())
            } else {
                qualityScore = nil
            }
        } else if scoring.usesModelOutputQuality {
            qualityScore = Int((usefulnessRate * factualityRate * brevityRate * 100).rounded())
        } else {
            let weights = scoring.normalizedWeights
            var weighted = 0.0
            var totalWeight = 0.0
            if !positive.isEmpty {
                weighted += usefulnessRate * weights.usefulness
                totalWeight += weights.usefulness
            }
            if !restraint.isEmpty {
                weighted += restraintRate * weights.restraint
                totalWeight += weights.restraint
            }
            if !grounded.isEmpty {
                weighted += factualityRate * weights.factuality
                totalWeight += weights.factuality
            }
            if !offered.isEmpty {
                weighted += brevityRate * weights.brevity
                totalWeight += weights.brevity
            }
            qualityScore = totalWeight > 0 ? Int((weighted / totalWeight * 100).rounded()) : nil
        }

        let promotionGateFailures: [String]
        if scoring.usesGoalContract {
            promotionGateFailures = goalContractFailures(gates: gates, errors: errors, timeouts: timeouts)
        } else if scoring.usesScorecardV3 {
            promotionGateFailures = promotionFailures(
                positiveCount: positive.count,
                ordinaryRestraintRate: ordinaryRestraintRate,
                sensitiveRestraintRate: sensitiveRestraintRate,
                factualityRate: factualityRate,
                counterfactualPairPassRate: counterfactualPairPassRate,
                p95LatencyMilliseconds: p95Latency,
                errors: errors,
                timeouts: timeouts,
                usefulnessRate: usefulnessRate
            )
        } else {
            promotionGateFailures = []
        }

        let saved = results.reduce(0) { $0 + $1.keystrokesSaved }
        return LabAggregateMetrics(
            totalCases: results.count,
            useful: useful,
            wrong: counts[.wrong, default: 0],
            silent: counts[.silent, default: 0],
            correctSilence: correctSilence,
            unwanted: counts[.unwanted, default: 0],
            timeouts: timeouts,
            errors: errors,
            policySuppressions: results.count(where: \.policySuppressed),
            modelRequests: modelRequests,
            exactMatchAt1Rate: rate(golden.count(where: \.exactMatchAt1), golden.count),
            exactMatchAt2Rate: rate(golden.count(where: \.exactMatchAt2), golden.count),
            exactMatchAt3Rate: rate(golden.count(where: \.exactMatchAt3), golden.count),
            exactPredictionRate: rate(exactPredictions, positive.count),
            acceptableAlternativeRate: rate(acceptableAlternatives, positive.count),
            usefulnessRate: usefulnessRate,
            restraintRate: restraintRate,
            ordinaryRestraintRate: ordinaryRestraintRate,
            sensitiveRestraintRate: sensitiveRestraintRate,
            counterfactualPairPassRate: counterfactualPairPassRate,
            replyScore: replyScore,
            qualityScore: qualityScore,
            promotionEligible: (scoring.usesGoalContract || scoring.usesScorecardV3)
                ? promotionGateFailures.isEmpty
                : nil,
            promotionGateFailures: promotionGateFailures,
            factualityRate: factualityRate,
            brevityRate: brevityRate,
            baselineKeystrokes: baselineKeystrokes,
            grossKeystrokesSaved: grossKeystrokesSaved,
            acceptanceKeystrokes: acceptanceKeystrokes,
            correctionKeystrokes: correctionKeystrokes,
            dismissalKeystrokes: dismissalKeystrokes,
            netKeystrokesSaved: netKeystrokesSaved,
            netKeystrokeSavingsRate: netSavingsRate,
            netKeystrokesSavedPer1000Characters: netSavingsRate * 1_000,
            badSuggestionRate: badSuggestionRate,
            temporalIntegrityRate: temporalIntegrityRate,
            failureCategoryCounts: Dictionary(grouping: results, by: \.failureCategory)
                .reduce(into: [:]) { partial, pair in
                    guard pair.key != .none else { return }
                    partial[pair.key.rawValue] = pair.value.count
                },
            gates: gates,
            keystrokesSaved: saved,
            keystrokesSavedPerCase: rate(saved, completed.count),
            throughputCasesPerSecond: elapsedSeconds > 0
                ? Double(results.count) / elapsedSeconds
                : 0,
            throughputModelRequestsPerSecond: elapsedSeconds > 0
                ? Double(modelRequests) / elapsedSeconds
                : 0,
            latency: LabLatencySummary(
                count: latencies.count,
                p50Milliseconds: percentile(latencies, fraction: 0.50),
                p95Milliseconds: p95Latency,
                p99Milliseconds: percentile(latencies, fraction: 0.99),
                maximumMilliseconds: latencies.last
            ),
            firstTokenLatency: LabLatencySummary(
                count: firstTokenLatencies.count,
                p50Milliseconds: percentile(firstTokenLatencies, fraction: 0.50),
                p95Milliseconds: percentile(firstTokenLatencies, fraction: 0.95),
                p99Milliseconds: percentile(firstTokenLatencies, fraction: 0.99),
                maximumMilliseconds: firstTokenLatencies.last
            ),
            meanTokenProbability: probabilities.isEmpty
                ? nil
                : probabilities.reduce(0, +) / Double(probabilities.count),
            decisionReasonCounts: Dictionary(grouping: results, by: \.decisionReason)
                .reduce(into: [:]) { partial, pair in
                    partial[pair.key.rawValue] = pair.value.count
                }
        )
    }

    /// Gives 75% of the behavioral score to the weaker of usefulness and
    /// ordinary restraint and 25% to the stronger. A zero component therefore
    /// caps the score at 25 without flattening every early experiment to zero.
    private static func weakLinkBalance(_ first: Double, _ second: Double) -> Double {
        (3 * min(first, second) + max(first, second)) / 4
    }

    private static func promotionFailures(
        positiveCount: Int,
        ordinaryRestraintRate: Double?,
        sensitiveRestraintRate: Double?,
        factualityRate: Double,
        counterfactualPairPassRate: Double?,
        p95LatencyMilliseconds: Int?,
        errors: Int,
        timeouts: Int,
        usefulnessRate: Double
    ) -> [String] {
        var failures: [String] = []
        if errors > 0 || timeouts > 0 { failures.append("incomplete-run") }
        if positiveCount == 0 {
            failures.append("missing-usefulness-cases")
        } else if usefulnessRate < LabScorecardV3.minimumUsefulnessRate {
            failures.append("usefulness-below-80")
        }
        if let ordinaryRestraintRate {
            if ordinaryRestraintRate < LabScorecardV3.minimumOrdinaryRestraintRate {
                failures.append("ordinary-restraint-below-98")
            }
        } else {
            failures.append("missing-ordinary-silence-cases")
        }
        if let sensitiveRestraintRate {
            if sensitiveRestraintRate < LabScorecardV3.requiredSensitiveRestraintRate {
                failures.append("sensitive-restraint-not-perfect")
            }
        } else {
            failures.append("missing-sensitive-silence-cases")
        }
        if factualityRate < LabScorecardV3.minimumFactualityRate {
            failures.append("factuality-below-99")
        }
        if let counterfactualPairPassRate {
            if counterfactualPairPassRate < LabScorecardV3.minimumCounterfactualPairPassRate {
                failures.append("counterfactual-pairs-below-80")
            }
        } else {
            failures.append("missing-counterfactual-pairs")
        }
        if let p95LatencyMilliseconds {
            if p95LatencyMilliseconds > LabScorecardV3.maximumP95LatencyMilliseconds {
                failures.append("p95-latency-over-1000ms")
            }
        } else {
            failures.append("missing-latency-samples")
        }
        return failures
    }

    private static func goalGates(
        completed: [LabCaseResult],
        sensitiveRestraintCount: Int,
        sensitiveRestraintRate: Double?,
        badSuggestionRate: Double,
        temporalIntegrityRate: Double,
        p95LatencyMilliseconds: Int?,
        errors: Int,
        timeouts: Int
    ) -> LabGateSummary {
        let complete = !completed.isEmpty && errors == 0 && timeouts == 0
        let bad: LabGateStatus = complete
            ? (badSuggestionRate <= LabGoalContract.maximumBadSuggestionRate ? .pass : .fail)
            : .fail
        let sensitive: LabGateStatus
        if sensitiveRestraintCount == 0 {
            sensitive = .notRun
        } else {
            sensitive = sensitiveRestraintRate == LabGoalContract.requiredSensitiveRestraintRate
                ? .pass
                : .fail
        }
        let temporal: LabGateStatus = completed.isEmpty
            ? .notRun
            : (temporalIntegrityRate == 1 ? .pass : .fail)
        let latency: LabGateStatus
        if let p95LatencyMilliseconds {
            latency = p95LatencyMilliseconds <= LabGoalContract.maximumP95LatencyMilliseconds
                ? .pass
                : .fail
        } else {
            latency = .notRun
        }
        return LabGateSummary(
            badSuggestions: bad,
            sensitiveSituations: sensitive,
            temporalIntegrity: temporal,
            latency: latency
        )
    }

    private static func goalContractFailures(
        gates: LabGateSummary,
        errors: Int,
        timeouts: Int
    ) -> [String] {
        var failures: [String] = []
        if errors > 0 || timeouts > 0 { failures.append("incomplete-run") }
        if gates.badSuggestions != .pass { failures.append("bad-suggestion-gate") }
        if gates.sensitiveSituations != .pass { failures.append("sensitive-situation-gate") }
        if gates.temporalIntegrity != .pass { failures.append("temporal-integrity-gate") }
        if gates.latency != .pass { failures.append("latency-gate") }
        if gates.privacy != .pass { failures.append("privacy-gate") }
        return failures
    }

    private static func words(in text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    private static func normalizedPhrase(_ text: String) -> String {
        words(in: text).joined(separator: " ")
    }

    private static func containsTerm(_ term: String, in normalizedText: String) -> Bool {
        let normalizedTerm = normalizedPhrase(term)
        guard !normalizedTerm.isEmpty else { return true }
        return normalizedText == normalizedTerm
            || normalizedText.hasPrefix(normalizedTerm + " ")
            || normalizedText.hasSuffix(" " + normalizedTerm)
            || normalizedText.contains(" " + normalizedTerm + " ")
    }

    /// Deterministic local grading for explicitly reviewed answer paths. A
    /// displayed partial continuation may be a prefix of the full accepted
    /// reply. Loose bag-of-words overlap is deliberately rejected because it
    /// can hide a changed person, place, date, or intent.
    private static func matchesAcceptedContinuation(
        _ normalizedSuggestion: String,
        alternative: String
    ) -> Bool {
        let normalizedAlternative = normalizedPhrase(alternative)
        return prefixPathMatches(normalizedSuggestion, accepted: normalizedAlternative)
    }

    private static func prefixPathMatches(_ suggestion: String, accepted: String) -> Bool {
        guard !suggestion.isEmpty, !accepted.isEmpty else { return false }
        return suggestion == accepted
            || suggestion.hasPrefix(accepted + " ")
            || accepted.hasPrefix(suggestion + " ")
    }

    private static func exactMatch(_ suggestion: [String], _ golden: [String], count: Int) -> Bool {
        guard suggestion.count >= count, golden.count >= count else { return false }
        return Array(suggestion.prefix(count)) == Array(golden.prefix(count))
    }

    private struct KeystrokeAccounting {
        let baseline: Int
        let gross: Int
        let acceptance: Int
        let correction: Int
        let dismissal: Int

        var net: Int { gross - acceptance - correction - dismissal }
    }

    private static func keystrokeAccounting(
        suggestion: String,
        golden: String,
        typedContext: String,
        offered: Bool,
        correctionKeystrokes: Int,
        dismissalKeystrokes: Int
    ) -> KeystrokeAccounting {
        let comparableSuggestion: String
        if typedContext.last?.isWhitespace == true,
           golden.first?.isWhitespace != true,
           suggestion.first?.isWhitespace == true {
            comparableSuggestion = String(suggestion.drop(while: \.isWhitespace))
        } else {
            comparableSuggestion = suggestion
        }
        let gross: Int
        if !comparableSuggestion.isEmpty, golden.hasPrefix(comparableSuggestion) {
            gross = comparableSuggestion.count
        } else {
            gross = exactFirstWordPrefixLength(suggestion: comparableSuggestion, golden: golden)
        }
        return KeystrokeAccounting(
            baseline: golden.count,
            gross: gross,
            acceptance: gross > 0 ? LabGoalContract.acceptanceKeystrokes : 0,
            correction: offered ? correctionKeystrokes : 0,
            dismissal: dismissalKeystrokes
        )
    }

    private static func finalizedAccounting(
        _ accounting: KeystrokeAccounting,
        outcome: LabCaseOutcome,
        offered: Bool
    ) -> KeystrokeAccounting {
        let dismissal = offered && (outcome == .wrong || outcome == .unwanted)
            ? accounting.dismissal
            : 0
        return KeystrokeAccounting(
            baseline: accounting.baseline,
            gross: accounting.gross,
            acceptance: accounting.acceptance,
            correction: accounting.correction,
            dismissal: dismissal
        )
    }

    private static func exactFirstWordPrefixLength(suggestion: String, golden: String) -> Int {
        guard let suggestedWord = suggestion.range(of: #"[\p{L}\p{N}]+"#, options: .regularExpression),
              let goldenWord = golden.range(of: #"[\p{L}\p{N}]+"#, options: .regularExpression),
              suggestion[suggestedWord] == golden[goldenWord],
              suggestion[..<suggestedWord.lowerBound] == golden[..<goldenWord.lowerBound] else {
            return 0
        }
        let accepted = String(golden[..<goldenWord.upperBound])
        return suggestion.hasPrefix(accepted) ? accepted.count : 0
    }

    private static func classifyFailure(
        outcome: LabCaseOutcome,
        exactMatchAt1: Bool,
        wordLimitViolation: Bool,
        requiredTermsSatisfied: Bool,
        forbiddenTermViolation: Bool,
        contextVariant: LabContextVariant,
        tags: [String],
        decisionReason: LabDecisionReason
    ) -> LabFailureCategory {
        if outcome == .timeout || outcome == .error { return .timing }
        if outcome == .useful || outcome == .correctSilence { return .none }
        if tags.contains("capture-failure") { return .capture }
        if tags.contains("scene-attribution") { return .sceneAttribution }
        if tags.contains("interaction-failure") { return .interaction }
        if wordLimitViolation { return .length }
        if outcome == .silent || outcome == .unwanted { return .display }
        if decisionReason == .unsupportedFact || forbiddenTermViolation || !requiredTermsSatisfied {
            return .intent
        }
        if contextVariant == .accessibility || contextVariant == .OCR { return .extraction }
        if contextVariant == .structuredThread, !exactMatchAt1 { return .intent }
        return exactMatchAt1 ? .length : .wording
    }

    private static func rate(_ numerator: Int, _ denominator: Int) -> Double {
        denominator == 0 ? 0 : Double(numerator) / Double(denominator)
    }

    private static func percentile(_ sorted: [Int], fraction: Double) -> Int? {
        guard !sorted.isEmpty else { return nil }
        let index = min(sorted.count - 1, max(0, Int((fraction * Double(sorted.count - 1)).rounded())))
        return sorted[index]
    }
}
