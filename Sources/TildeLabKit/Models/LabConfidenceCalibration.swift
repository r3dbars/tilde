import Foundation

/// Text-free confidence evidence. The feature vector deliberately excludes
/// prompts, candidates, token strings, app identifiers, and document data.
/// Missing values remain explicit because older helpers may expose only the
/// chosen-token probability.
public struct LabConfidenceFeaturesV1: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.confidence-features.v1"

    public let schema: String
    public let firstTokenProbability: Double?
    public let meanSequenceLogProbability: Double?
    public let minimumTokenProbability: Double?
    public let meanProbabilityMargin: Double?
    public let meanTokenEntropy: Double?
    public let suggestionCharacters: Int
    public let suggestionWords: Int
    public let punctuationStop: Bool
    public let contextSourceQuality: Double?
    public let sceneFreshnessSeconds: Double?
    public let personalSupport: Int?
    public let personalConfidence: Double?
    public let firstTokenMilliseconds: Int?
    public let perturbationAgreement: Double?

    public init(
        firstTokenProbability: Double? = nil,
        meanSequenceLogProbability: Double? = nil,
        minimumTokenProbability: Double? = nil,
        meanProbabilityMargin: Double? = nil,
        meanTokenEntropy: Double? = nil,
        suggestionCharacters: Int,
        suggestionWords: Int,
        punctuationStop: Bool,
        contextSourceQuality: Double? = nil,
        sceneFreshnessSeconds: Double? = nil,
        personalSupport: Int? = nil,
        personalConfidence: Double? = nil,
        firstTokenMilliseconds: Int? = nil,
        perturbationAgreement: Double? = nil
    ) {
        schema = Self.currentSchema
        self.firstTokenProbability = firstTokenProbability
        self.meanSequenceLogProbability = meanSequenceLogProbability
        self.minimumTokenProbability = minimumTokenProbability
        self.meanProbabilityMargin = meanProbabilityMargin
        self.meanTokenEntropy = meanTokenEntropy
        self.suggestionCharacters = suggestionCharacters
        self.suggestionWords = suggestionWords
        self.punctuationStop = punctuationStop
        self.contextSourceQuality = contextSourceQuality
        self.sceneFreshnessSeconds = sceneFreshnessSeconds
        self.personalSupport = personalSupport
        self.personalConfidence = personalConfidence
        self.firstTokenMilliseconds = firstTokenMilliseconds
        self.perturbationAgreement = perturbationAgreement
    }

    public init(
        response: LabModelResponse,
        contextSourceQuality: Double? = nil,
        sceneFreshnessSeconds: Double? = nil,
        personalSupport: Int? = nil,
        personalConfidence: Double? = nil,
        perturbationAgreement: Double? = nil
    ) {
        let probabilities = response.tokenLogProbabilities.map(exp)
        self.init(
            firstTokenProbability: probabilities.first,
            meanSequenceLogProbability: response.tokenLogProbabilities.isEmpty
                ? nil
                : response.tokenLogProbabilities.reduce(0, +)
                    / Double(response.tokenLogProbabilities.count),
            minimumTokenProbability: probabilities.min(),
            meanProbabilityMargin: Self.mean(response.tokenProbabilityMargins),
            meanTokenEntropy: Self.mean(response.tokenEntropies),
            suggestionCharacters: response.content.count,
            suggestionWords: response.content.split(whereSeparator: { $0.isWhitespace }).count,
            punctuationStop: response.content.last.map { ".!?;:".contains($0) } ?? false,
            contextSourceQuality: contextSourceQuality,
            sceneFreshnessSeconds: sceneFreshnessSeconds,
            personalSupport: personalSupport,
            personalConfidence: personalConfidence,
            firstTokenMilliseconds: response.firstTokenMilliseconds,
            perturbationAgreement: perturbationAgreement
        )
    }

    @discardableResult
    public func validated() throws -> LabConfidenceFeaturesV1 {
        guard schema == Self.currentSchema,
              suggestionCharacters >= 0, suggestionCharacters <= 16_384,
              suggestionWords >= 0, suggestionWords <= 1_024,
              Self.probability(firstTokenProbability),
              Self.finiteAtMostZero(meanSequenceLogProbability),
              Self.probability(minimumTokenProbability),
              Self.probability(meanProbabilityMargin),
              meanTokenEntropy.map({ $0.isFinite && $0 >= 0 && $0 <= 100 }) ?? true,
              Self.probability(contextSourceQuality),
              sceneFreshnessSeconds.map({ $0.isFinite && $0 >= 0 && $0 <= 86_400 }) ?? true,
              personalSupport.map({ (0...1_000_000).contains($0) }) ?? true,
              Self.probability(personalConfidence),
              firstTokenMilliseconds.map({ (0...300_000).contains($0) }) ?? true,
              Self.probability(perturbationAgreement) else {
            throw LabConfidenceCalibrationError.invalidFeatures
        }
        return self
    }

    private static func probability(_ value: Double?) -> Bool {
        value.map({ $0.isFinite && (0...1).contains($0) }) ?? true
    }

    private static func finiteAtMostZero(_ value: Double?) -> Bool {
        value.map({ $0.isFinite && $0 <= 0 }) ?? true
    }

    private static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}

public struct LabIsotonicConfidenceKnot: Codable, Equatable, Sendable {
    public let minimumRawConfidence: Double
    public let maximumRawConfidence: Double
    public let calibratedAcceptanceProbability: Double
    public let trainingEvents: Int
}

public struct LabConfidenceCalibrationSlice: Codable, Equatable, Sendable {
    public let slice: String
    public let events: Int
    public let empiricalAcceptanceRate: Double
    public let meanPredictedAcceptance: Double
    public let expectedCalibrationError: Double
    public let brierScore: Double
}

public struct LabConfidenceCalibrationReport: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.confidence-calibration.v1"

    public let schema: String
    public let campaignID: UUID
    public let eligibleEvents: Int
    public let trainingEvents: Int
    public let validationEvents: Int
    public let empiricalAcceptanceRate: Double
    public let rawExpectedCalibrationError: Double
    public let calibratedExpectedCalibrationError: Double
    public let rawBrierScore: Double
    public let calibratedBrierScore: Double
    public let isotonicKnots: [LabIsotonicConfidenceKnot]
    public let slices: [LabConfidenceCalibrationSlice]
    public let featureCoverage: [String: Int]
    public let limitation: String
}

public enum LabConfidenceCalibrationError: Error, LocalizedError, Equatable, Sendable {
    case invalidFeatures
    case insufficientEvents
    case mixedCampaign

    public var errorDescription: String? {
        switch self {
        case .invalidFeatures: "One or more text-free confidence features are invalid."
        case .insufficientEvents:
            "Confidence calibration needs at least four displayed events with a finite raw confidence."
        case .mixedCampaign: "Confidence calibration cannot mix campaign identifiers."
        }
    }
}

/// Fits an isotonic acceptance calibrator on the chronological first 70% and
/// reports only out-of-sample metrics on the remaining 30%. This is a local,
/// text-free utility calibrator; protected offline holdout cases are not an
/// accepted input type.
public enum LabConfidenceCalibrator {
    public static func calibrate(
        _ events: [LabOnlineExperimentEvent]
    ) throws -> LabConfidenceCalibrationReport {
        guard let campaignID = events.first?.campaignID,
              events.allSatisfy({ $0.campaignID == campaignID }) else {
            throw LabConfidenceCalibrationError.mixedCampaign
        }
        let eligible = events.compactMap(Observation.init).sorted {
            if $0.occurredAt == $1.occurredAt { return $0.id.uuidString < $1.id.uuidString }
            return $0.occurredAt < $1.occurredAt
        }
        guard eligible.count >= 4 else {
            throw LabConfidenceCalibrationError.insufficientEvents
        }
        let trainingCount = min(eligible.count - 1, max(2, Int(Double(eligible.count) * 0.70)))
        let training = Array(eligible[..<trainingCount])
        let validation = Array(eligible[trainingCount...])
        let knots = fit(training)
        let rawPredictions = validation.map(\.confidence)
        let calibrated = validation.map { predict($0.confidence, knots: knots) }
        let labels = validation.map(\.accepted)
        var slices: [LabConfidenceCalibrationSlice] = []
        for label in Set(validation.flatMap(\.sliceLabels)).sorted() {
            let members = zip(validation, calibrated).filter { $0.0.sliceLabels.contains(label) }
            let memberLabels = members.map { $0.0.accepted }
            let memberPredictions = members.map(\.1)
            slices.append(LabConfidenceCalibrationSlice(
                slice: label,
                events: members.count,
                empiricalAcceptanceRate: mean(memberLabels),
                meanPredictedAcceptance: mean(memberPredictions),
                expectedCalibrationError: expectedCalibrationError(
                    predictions: memberPredictions,
                    labels: memberLabels
                ),
                brierScore: brier(predictions: memberPredictions, labels: memberLabels)
            ))
        }
        var coverage: [String: Int] = [:]
        for event in events {
            guard let features = event.confidenceFeatures else { continue }
            coverage["confidence-features-v1", default: 0] += 1
            if features.firstTokenProbability != nil { coverage["first-token-probability", default: 0] += 1 }
            if features.meanSequenceLogProbability != nil { coverage["mean-sequence-log-probability", default: 0] += 1 }
            if features.minimumTokenProbability != nil { coverage["minimum-token-probability", default: 0] += 1 }
            if features.meanProbabilityMargin != nil { coverage["probability-margin", default: 0] += 1 }
            if features.meanTokenEntropy != nil { coverage["token-entropy", default: 0] += 1 }
            if features.personalConfidence != nil { coverage["personal-confidence", default: 0] += 1 }
            if features.perturbationAgreement != nil { coverage["perturbation-agreement", default: 0] += 1 }
        }
        return LabConfidenceCalibrationReport(
            schema: LabConfidenceCalibrationReport.currentSchema,
            campaignID: campaignID,
            eligibleEvents: eligible.count,
            trainingEvents: training.count,
            validationEvents: validation.count,
            empiricalAcceptanceRate: mean(eligible.map(\.accepted)),
            rawExpectedCalibrationError: expectedCalibrationError(
                predictions: rawPredictions, labels: labels
            ),
            calibratedExpectedCalibrationError: expectedCalibrationError(
                predictions: calibrated, labels: labels
            ),
            rawBrierScore: brier(predictions: rawPredictions, labels: labels),
            calibratedBrierScore: brier(predictions: calibrated, labels: labels),
            isotonicKnots: knots,
            slices: slices,
            featureCoverage: coverage,
            limitation: "Chronological out-of-sample isotonic calibration of displayed local events. It estimates acceptance, not semantic correctness, and must be revalidated after a policy or user-distribution shift."
        )
    }

    private static func fit(_ observations: [Observation]) -> [LabIsotonicConfidenceKnot] {
        struct Block {
            var minimum: Double
            var maximum: Double
            var positives: Double
            var count: Int
            var mean: Double { positives / Double(count) }
        }
        var blocks = observations.sorted { $0.confidence < $1.confidence }.map {
            Block(
                minimum: $0.confidence,
                maximum: $0.confidence,
                positives: $0.accepted,
                count: 1
            )
        }
        var index = 0
        while index + 1 < blocks.count {
            if blocks[index].mean <= blocks[index + 1].mean {
                index += 1
                continue
            }
            let right = blocks.remove(at: index + 1)
            blocks[index].maximum = right.maximum
            blocks[index].positives += right.positives
            blocks[index].count += right.count
            if index > 0 { index -= 1 }
        }
        return blocks.map {
            LabIsotonicConfidenceKnot(
                minimumRawConfidence: $0.minimum,
                maximumRawConfidence: $0.maximum,
                calibratedAcceptanceProbability: $0.mean,
                trainingEvents: $0.count
            )
        }
    }

    private static func predict(
        _ confidence: Double,
        knots: [LabIsotonicConfidenceKnot]
    ) -> Double {
        if let containing = knots.first(where: {
            confidence >= $0.minimumRawConfidence && confidence <= $0.maximumRawConfidence
        }) { return containing.calibratedAcceptanceProbability }
        if let first = knots.first, confidence < first.minimumRawConfidence {
            return first.calibratedAcceptanceProbability
        }
        return knots.last?.calibratedAcceptanceProbability ?? confidence
    }

    private static func expectedCalibrationError(
        predictions: [Double],
        labels: [Double]
    ) -> Double {
        guard !predictions.isEmpty else { return 0 }
        var weighted = 0.0
        for bin in 0..<10 {
            let lower = Double(bin) / 10
            let upper = Double(bin + 1) / 10
            let indices = predictions.indices.filter {
                predictions[$0] >= lower && (bin == 9 ? predictions[$0] <= upper : predictions[$0] < upper)
            }
            guard !indices.isEmpty else { continue }
            let predicted = mean(indices.map { predictions[$0] })
            let observed = mean(indices.map { labels[$0] })
            weighted += abs(predicted - observed) * Double(indices.count)
        }
        return weighted / Double(predictions.count)
    }

    private static func brier(predictions: [Double], labels: [Double]) -> Double {
        guard !predictions.isEmpty else { return 0 }
        return zip(predictions, labels).reduce(0) { total, pair in
            total + pow(pair.0 - pair.1, 2)
        } / Double(predictions.count)
    }

    private static func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    private struct Observation {
        let id: UUID
        let occurredAt: Date
        let confidence: Double
        let accepted: Double
        let sliceLabels: [String]

        init?(_ event: LabOnlineExperimentEvent) {
            guard event.safeOpportunity, event.displayed,
                  let confidence = event.confidence,
                  confidence.isFinite, (0...1).contains(confidence) else { return nil }
            switch event.outcome {
            case .acceptedAll, .acceptedWord:
                accepted = 1
            case .ignored, .dismissed, .corrected, .undone:
                accepted = 0
            case .hidden, .unavailable:
                return nil
            }
            id = event.id
            occurredAt = event.occurredAt
            self.confidence = confidence
            let length = event.candidateCharacters <= 20 ? "short"
                : event.candidateCharacters <= 60 ? "medium" : "long"
            sliceLabels = [
                "app:\(event.appCategory.rawValue)",
                "register:\(event.register.rawValue)",
                "boundary:\(event.boundary.rawValue)",
                "length:\(length)",
                "personal:\(event.confidenceFeatures?.personalSupport == nil ? "no" : "yes")",
            ]
        }
    }
}
