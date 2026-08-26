import Foundation

public enum LabPrefixReplay {
    public static func expand(
        _ scenario: LabScenario,
        checkpoints: [LabReplayCheckpoint] = LabReplayCheckpoint.allCases
    ) -> [LabScenario] {
        guard scenario.expectation.shouldSuggest,
              let continuation = scenario.expectation.goldenContinuation,
              !continuation.isEmpty else {
            return [scenario]
        }

        return checkpoints.compactMap { checkpoint in
            let consumedCount = consumedCharacterCount(in: continuation, checkpoint: checkpoint)
            guard consumedCount < continuation.count else { return nil }
            let split = continuation.index(continuation.startIndex, offsetBy: consumedCount)
            let consumed = String(continuation[..<split])
            let remaining = String(continuation[split...])
            guard !remaining.isEmpty else { return nil }
            let required = scenario.expectation.requiredTerms.filter {
                !consumed.localizedCaseInsensitiveContains($0)
            }
            return LabScenario(
                id: "\(scenario.id)-\(checkpoint.rawValue)",
                category: scenario.category,
                partition: scenario.partition,
                intent: scenario.intent,
                tone: scenario.tone,
                language: scenario.language,
                tags: scenario.tags + ["checkpoint-\(checkpoint.rawValue)"],
                appBundleIdentifier: scenario.appBundleIdentifier,
                typedContext: scenario.typedContext + consumed,
                scene: scenario.scene,
                expectation: LabExpectation(
                    shouldSuggest: true,
                    goldenContinuation: remaining,
                    acceptablePrefixes: [remaining],
                    requiredTerms: required,
                    forbiddenTerms: scenario.expectation.forbiddenTerms,
                    maximumWords: scenario.expectation.maximumWords
                ),
                evaluation: LabEvaluationMetadata(
                    source: scenario.evaluation.source,
                    checkpoint: checkpoint,
                    contextVariant: scenario.evaluation.contextVariant,
                    temporalIntegrity: scenario.evaluation.temporalIntegrity,
                    evidence: scenario.evaluation.evidence,
                    corpusID: scenario.evaluation.corpusID,
                    rootScenarioID: scenario.evaluation.rootScenarioID ?? scenario.id,
                    correctionKeystrokes: scenario.evaluation.correctionKeystrokes,
                    dismissalKeystrokes: scenario.evaluation.dismissalKeystrokes
                )
            )
        }
    }

    public static func contextAblations(
        _ scenario: LabScenario,
        variants: [LabContextVariant]
    ) -> [LabScenario] {
        variants.compactMap { variant in
            guard evidenceExists(for: variant, in: scenario) else { return nil }
            return LabScenario(
                id: "\(scenario.id)-\(variant.rawValue)",
                category: scenario.category,
                partition: scenario.partition,
                intent: scenario.intent,
                tone: scenario.tone,
                language: scenario.language,
                tags: scenario.tags + ["context-\(variant.rawValue)"],
                appBundleIdentifier: scenario.appBundleIdentifier,
                typedContext: scenario.typedContext,
                scene: scenario.scene,
                expectation: scenario.expectation,
                evaluation: LabEvaluationMetadata(
                    source: scenario.evaluation.source,
                    checkpoint: scenario.evaluation.checkpoint,
                    contextVariant: variant,
                    temporalIntegrity: scenario.evaluation.temporalIntegrity,
                    evidence: scenario.evaluation.evidence,
                    corpusID: scenario.evaluation.corpusID,
                    rootScenarioID: scenario.evaluation.rootScenarioID ?? scenario.id,
                    correctionKeystrokes: scenario.evaluation.correctionKeystrokes,
                    dismissalKeystrokes: scenario.evaluation.dismissalKeystrokes
                )
            )
        }
    }

    private static func evidenceExists(for variant: LabContextVariant, in scenario: LabScenario) -> Bool {
        switch variant {
        case .typedOnly, .appMetadata: true
        case .accessibility: scenario.evaluation.evidence.accessibilityText?.isEmpty == false
        case .OCR: scenario.evaluation.evidence.OCRText?.isEmpty == false
        case .structuredThread: scenario.scene != nil
        case .personalized: scenario.evaluation.evidence.personalStyleHint?.isEmpty == false
        case .recordedScreen: scenario.evaluation.evidence.recordedScreenText?.isEmpty == false
        }
    }

    private static func consumedCharacterCount(
        in continuation: String,
        checkpoint: LabReplayCheckpoint
    ) -> Int {
        switch checkpoint {
        case .caret: return 0
        case .firstCharacter: return min(1, continuation.count)
        case .firstWord: return endOfWord(1, in: continuation)
        case .twoWords: return endOfWord(2, in: continuation)
        case .threeWords: return endOfWord(3, in: continuation)
        case .midSentence: return max(1, continuation.count / 2)
        case .nearEnd:
            let words = wordRanges(in: continuation)
            guard let last = words.last else { return max(0, continuation.count - 1) }
            return continuation.distance(from: continuation.startIndex, to: last.lowerBound)
        }
    }

    private static func endOfWord(_ ordinal: Int, in text: String) -> Int {
        let ranges = wordRanges(in: text)
        guard !ranges.isEmpty else { return min(ordinal, text.count) }
        let range = ranges[min(ordinal - 1, ranges.count - 1)]
        return text.distance(from: text.startIndex, to: range.upperBound)
    }

    private static func wordRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let range = text.range(
                  of: #"[\p{L}\p{N}]+"#,
                  options: .regularExpression,
                  range: searchStart..<text.endIndex
              ) {
            ranges.append(range)
            searchStart = range.upperBound
        }
        return ranges
    }
}
