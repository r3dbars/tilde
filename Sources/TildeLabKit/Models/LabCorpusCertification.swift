import Foundation

public enum LabCorpusCheckStatus: String, Codable, Equatable, Sendable {
    case pass
    case fail
    case pending
}

public struct LabCorpusQualityCheck: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let status: LabCorpusCheckStatus
    public let detail: String

    public init(id: String, title: String, status: LabCorpusCheckStatus, detail: String) {
        self.id = id
        self.title = title
        self.status = status
        self.detail = detail
    }
}

public struct LabCorpusReviewReceipt: Codable, Equatable, Sendable {
    public let rubricVersion: String
    public let reviewer: String
    public let reviewedAt: String
    public let corpusDigestSHA256: String
    public let sampleDigestSHA256: String
    public let reviewedCases: Int
    public let approvedCases: Int

    public init(
        rubricVersion: String,
        reviewer: String,
        reviewedAt: String,
        corpusDigestSHA256: String,
        sampleDigestSHA256: String,
        reviewedCases: Int,
        approvedCases: Int
    ) {
        self.rubricVersion = rubricVersion
        self.reviewer = reviewer
        self.reviewedAt = reviewedAt
        self.corpusDigestSHA256 = corpusDigestSHA256
        self.sampleDigestSHA256 = sampleDigestSHA256
        self.reviewedCases = reviewedCases
        self.approvedCases = approvedCases
    }

    public var approvalRate: Double {
        reviewedCases > 0 ? Double(approvedCases) / Double(reviewedCases) : 0
    }
}

public enum LabCorpusStaticVerdict: String, Codable, Equatable, Sendable {
    case rejected
    case needsReview = "needs-review"
    case readyForModelCertification = "ready-for-model-certification"
}

public struct LabCorpusQualityReport: Codable, Equatable, Sendable {
    public let corpusID: String
    public let corpusName: String
    public let corpusDigestSHA256: String
    public let rootCount: Int
    public let positiveCount: Int
    public let silenceCount: Int
    public let categoryFamilyCount: Int
    public let applicationCount: Int
    public let counterfactualPairCount: Int
    public let supportedPositiveRate: Double
    public let developmentCount: Int
    public let validationCount: Int
    public let holdoutCount: Int
    public let checks: [LabCorpusQualityCheck]

    public init(
        corpusID: String,
        corpusName: String,
        corpusDigestSHA256: String,
        rootCount: Int,
        positiveCount: Int,
        silenceCount: Int,
        categoryFamilyCount: Int,
        applicationCount: Int,
        counterfactualPairCount: Int,
        supportedPositiveRate: Double,
        developmentCount: Int,
        validationCount: Int,
        holdoutCount: Int,
        checks: [LabCorpusQualityCheck]
    ) {
        self.corpusID = corpusID
        self.corpusName = corpusName
        self.corpusDigestSHA256 = corpusDigestSHA256
        self.rootCount = rootCount
        self.positiveCount = positiveCount
        self.silenceCount = silenceCount
        self.categoryFamilyCount = categoryFamilyCount
        self.applicationCount = applicationCount
        self.counterfactualPairCount = counterfactualPairCount
        self.supportedPositiveRate = supportedPositiveRate
        self.developmentCount = developmentCount
        self.validationCount = validationCount
        self.holdoutCount = holdoutCount
        self.checks = checks
    }

    public var verdict: LabCorpusStaticVerdict {
        if checks.contains(where: { $0.status == .fail }) { return .rejected }
        if checks.contains(where: { $0.status == .pending }) { return .needsReview }
        return .readyForModelCertification
    }

    public var passesStaticGate: Bool {
        verdict == .readyForModelCertification
    }
}

public struct LabCorpusContextMetrics: Codable, Equatable, Sendable {
    public let exactMatchAt1Rate: Double
    public let usefulnessRate: Double
    public let netKeystrokeSavingsRate: Double
    public let errors: Int
    public let timeouts: Int

    public init(metrics: LabAggregateMetrics) {
        exactMatchAt1Rate = metrics.exactMatchAt1Rate
        usefulnessRate = metrics.usefulnessRate
        netKeystrokeSavingsRate = metrics.netKeystrokeSavingsRate
        errors = metrics.errors
        timeouts = metrics.timeouts
    }

    public init(
        exactMatchAt1Rate: Double,
        usefulnessRate: Double,
        netKeystrokeSavingsRate: Double,
        errors: Int = 0,
        timeouts: Int = 0
    ) {
        self.exactMatchAt1Rate = exactMatchAt1Rate
        self.usefulnessRate = usefulnessRate
        self.netKeystrokeSavingsRate = netKeystrokeSavingsRate
        self.errors = errors
        self.timeouts = timeouts
    }
}

public struct LabCorpusPartitionContextResult: Codable, Equatable, Sendable {
    public let partition: LabScenarioPartition
    public let correctExactMatchAt1Rate: Double
    public let typedOnlyExactMatchAt1Rate: Double
    public let wrongContextExactMatchAt1Rate: Double

    public init(
        partition: LabScenarioPartition,
        correctExactMatchAt1Rate: Double,
        typedOnlyExactMatchAt1Rate: Double,
        wrongContextExactMatchAt1Rate: Double
    ) {
        self.partition = partition
        self.correctExactMatchAt1Rate = correctExactMatchAt1Rate
        self.typedOnlyExactMatchAt1Rate = typedOnlyExactMatchAt1Rate
        self.wrongContextExactMatchAt1Rate = wrongContextExactMatchAt1Rate
    }

    public var correctContextWins: Bool {
        correctExactMatchAt1Rate > typedOnlyExactMatchAt1Rate
            && correctExactMatchAt1Rate > wrongContextExactMatchAt1Rate
    }
}

public struct LabCorpusModelCertificate: Codable, Equatable, Sendable {
    public static let currentSchema = "tilde-lab.corpus-model-certificate.v1"

    public let schema: String
    public let createdAt: Date
    public let corpusID: String
    public let corpusDigestSHA256: String
    public let modelSHA256: String
    public let helperSHA256: String
    public let armID: String
    public let correctContext: LabCorpusContextMetrics
    public let typedOnly: LabCorpusContextMetrics
    public let wrongContext: LabCorpusContextMetrics
    public let partitions: [LabCorpusPartitionContextResult]

    public init(
        createdAt: Date = Date(),
        corpusID: String,
        corpusDigestSHA256: String,
        modelSHA256: String,
        helperSHA256: String,
        armID: String,
        correctContext: LabCorpusContextMetrics,
        typedOnly: LabCorpusContextMetrics,
        wrongContext: LabCorpusContextMetrics,
        partitions: [LabCorpusPartitionContextResult]
    ) {
        schema = Self.currentSchema
        self.createdAt = createdAt
        self.corpusID = corpusID
        self.corpusDigestSHA256 = corpusDigestSHA256
        self.modelSHA256 = modelSHA256
        self.helperSHA256 = helperSHA256
        self.armID = armID
        self.correctContext = correctContext
        self.typedOnly = typedOnly
        self.wrongContext = wrongContext
        self.partitions = partitions
    }

    public var failures: [String] {
        var result: [String] = []
        if correctContext.errors + typedOnly.errors + wrongContext.errors > 0 {
            result.append("protocol-errors")
        }
        if correctContext.timeouts + typedOnly.timeouts + wrongContext.timeouts > 0 {
            result.append("timeouts")
        }
        if correctContext.exactMatchAt1Rate <= typedOnly.exactMatchAt1Rate {
            result.append("correct-context-not-better-than-typed-only")
        }
        if correctContext.exactMatchAt1Rate <= wrongContext.exactMatchAt1Rate {
            result.append("correct-context-not-better-than-wrong-context")
        }
        if correctContext.netKeystrokeSavingsRate <= typedOnly.netKeystrokeSavingsRate {
            result.append("correct-context-nks-not-better-than-typed-only")
        }
        if correctContext.netKeystrokeSavingsRate <= wrongContext.netKeystrokeSavingsRate {
            result.append("correct-context-nks-not-better-than-wrong-context")
        }
        if partitions.contains(where: { !$0.correctContextWins }) {
            result.append("context-win-not-stable-across-partitions")
        }
        return result
    }

    public var passes: Bool { failures.isEmpty }
}

public enum LabCertifiedCorpusV2 {
    public static let reviewSampleSize = 100
    public static let minimumReviewApprovalRate = 0.95

    // Any corpus edit changes its digest and invalidates this receipt
    // automatically, forcing the frozen sample to be reviewed again.
    public static let reviewReceipt = LabCorpusReviewReceipt(
        rubricVersion: "multi-answer-intent-partial-v2",
        reviewer: "Codex structured multi-answer review",
        reviewedAt: "2026-08-25",
        corpusDigestSHA256: "353d3a87b543604075a09e7481b634f955f6b4804f40e018bceb9cee6f61756c",
        sampleDigestSHA256: "86aec7614ed5e0eb2cca0b0ef82d914c3cf7e7c2417819fb4cfd73d3c070227b",
        reviewedCases: 100,
        approvedCases: 100
    )
}
