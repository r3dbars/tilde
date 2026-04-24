import Foundation

public enum CompletionRuntimeCandidate: String, Equatable, Sendable {
    case liteRTLM
    case mlx
    case mock

    public var displayName: String {
        switch self {
        case .liteRTLM:
            "LiteRT-LM"
        case .mlx:
            "MLX"
        case .mock:
            "Mock"
        }
    }
}

public struct CompletionLatencySample: Equatable, Sendable {
    public let candidate: CompletionRuntimeCandidate
    public let milliseconds: Int
    public let tokenCount: Int

    public init(candidate: CompletionRuntimeCandidate, milliseconds: Int, tokenCount: Int) {
        self.candidate = candidate
        self.milliseconds = milliseconds
        self.tokenCount = tokenCount
    }
}

public struct CompletionRuntimeBenchmark: Equatable, Sendable {
    public let candidate: CompletionRuntimeCandidate
    public let samples: [CompletionLatencySample]

    public init(candidate: CompletionRuntimeCandidate, samples: [CompletionLatencySample]) {
        self.candidate = candidate
        self.samples = samples
    }

    public var averageLatencyMilliseconds: Int? {
        guard !samples.isEmpty else {
            return nil
        }

        let total = samples.reduce(0) { $0 + $1.milliseconds }
        return total / samples.count
    }

    public func passesAutocompleteTarget(_ policy: CompletionModelPolicy = .mvp) -> Bool {
        guard let averageLatencyMilliseconds else {
            return false
        }

        return averageLatencyMilliseconds <= policy.targetLatencyMilliseconds
    }
}

public enum RuntimeBenchmarkAvailability: Equatable, Sendable {
    case available
    case unavailable(String)

    public var isAvailable: Bool {
        switch self {
        case .available:
            true
        case .unavailable:
            false
        }
    }
}

public struct RuntimeBenchmarkCandidatePlan: Equatable, Sendable {
    public let candidate: CompletionRuntimeCandidate
    public let modelIdentifier: String
    public let priority: Int
    public let notes: String

    public init(
        candidate: CompletionRuntimeCandidate,
        modelIdentifier: String,
        priority: Int,
        notes: String
    ) {
        self.candidate = candidate
        self.modelIdentifier = modelIdentifier
        self.priority = priority
        self.notes = notes
    }
}

public struct RuntimeBenchmarkPlan: Equatable, Sendable {
    public let model: LocalModelID
    public let candidates: [RuntimeBenchmarkCandidatePlan]
    public let warmupCount: Int
    public let sampleCount: Int
    public let targetLatencyMilliseconds: Int
    public let stretchLatencyMilliseconds: Int
    public let generatedTokenCount: Int

    public init(
        model: LocalModelID,
        candidates: [RuntimeBenchmarkCandidatePlan],
        warmupCount: Int,
        sampleCount: Int,
        targetLatencyMilliseconds: Int,
        stretchLatencyMilliseconds: Int,
        generatedTokenCount: Int
    ) {
        self.model = model
        self.candidates = candidates.sorted { $0.priority < $1.priority }
        self.warmupCount = warmupCount
        self.sampleCount = sampleCount
        self.targetLatencyMilliseconds = targetLatencyMilliseconds
        self.stretchLatencyMilliseconds = stretchLatencyMilliseconds
        self.generatedTokenCount = generatedTokenCount
    }

    public static func gemma4E2B(policy: CompletionModelPolicy = .mvp) -> RuntimeBenchmarkPlan {
        RuntimeBenchmarkPlan(
            model: .gemma4E2B,
            candidates: [
                RuntimeBenchmarkCandidatePlan(
                    candidate: .liteRTLM,
                    modelIdentifier: "gemma-4-E2B-it-litert-lm",
                    priority: 0,
                    notes: "Preferred app-owned runtime path for Gemma edge models."
                ),
                RuntimeBenchmarkCandidatePlan(
                    candidate: .mlx,
                    modelIdentifier: "gemma-4-E2B-it-mlx",
                    priority: 1,
                    notes: "Apple Silicon fallback if LiteRT-LM is not ready enough."
                )
            ],
            warmupCount: 3,
            sampleCount: 10,
            targetLatencyMilliseconds: policy.targetLatencyMilliseconds,
            stretchLatencyMilliseconds: 300,
            generatedTokenCount: policy.maxGeneratedTokens
        )
    }
}

public enum RuntimeBenchmarkTargetEvaluation: Equatable, Sendable {
    case stretch
    case target
    case tooSlow
    case notRun
}

public struct RuntimeBenchmarkCandidateResult: Equatable, Sendable {
    public let candidate: CompletionRuntimeCandidate
    public let availability: RuntimeBenchmarkAvailability
    public let samples: [CompletionLatencySample]

    public init(
        candidate: CompletionRuntimeCandidate,
        availability: RuntimeBenchmarkAvailability,
        samples: [CompletionLatencySample] = []
    ) {
        self.candidate = candidate
        self.availability = availability
        self.samples = samples.filter { $0.candidate == candidate }
    }

    public var averageLatencyMilliseconds: Int? {
        CompletionRuntimeBenchmark(candidate: candidate, samples: samples).averageLatencyMilliseconds
    }

    public func targetEvaluation(plan: RuntimeBenchmarkPlan) -> RuntimeBenchmarkTargetEvaluation {
        guard availability.isAvailable, let averageLatencyMilliseconds else {
            return .notRun
        }

        if averageLatencyMilliseconds <= plan.stretchLatencyMilliseconds {
            return .stretch
        }

        if averageLatencyMilliseconds <= plan.targetLatencyMilliseconds {
            return .target
        }

        return .tooSlow
    }
}

public struct RuntimeBenchmarkReport: Equatable, Sendable {
    public let plan: RuntimeBenchmarkPlan
    public let results: [RuntimeBenchmarkCandidateResult]

    public init(plan: RuntimeBenchmarkPlan, results: [RuntimeBenchmarkCandidateResult]) {
        self.plan = plan
        self.results = results
    }

    public var recommendedCandidate: CompletionRuntimeCandidate? {
        for candidatePlan in plan.candidates {
            guard let result = result(for: candidatePlan.candidate) else {
                continue
            }

            switch result.targetEvaluation(plan: plan) {
            case .stretch, .target:
                return result.candidate
            case .tooSlow, .notRun:
                continue
            }
        }

        return nil
    }

    public var summary: String {
        var lines = [
            "Gemma 4 E2B runtime benchmark",
            "warmup=\(plan.warmupCount) samples=\(plan.sampleCount) target=\(plan.targetLatencyMilliseconds)ms stretch=\(plan.stretchLatencyMilliseconds)ms"
        ]

        for candidatePlan in plan.candidates {
            guard let result = result(for: candidatePlan.candidate) else {
                lines.append("\(candidatePlan.candidate.displayName): not checked")
                continue
            }

            switch result.availability {
            case .available:
                let average = result.averageLatencyMilliseconds.map { "\($0)ms avg" } ?? "no samples"
                lines.append("\(result.candidate.displayName): \(average), \(label(for: result.targetEvaluation(plan: plan)))")
            case .unavailable(let reason):
                lines.append("\(result.candidate.displayName): unavailable - \(reason)")
            }
        }

        if let recommendedCandidate {
            lines.append("recommendation=\(recommendedCandidate.displayName)")
        } else {
            lines.append("recommendation=none")
        }

        return lines.joined(separator: "\n")
    }

    public func result(for candidate: CompletionRuntimeCandidate) -> RuntimeBenchmarkCandidateResult? {
        results.first { $0.candidate == candidate }
    }

    private func label(for evaluation: RuntimeBenchmarkTargetEvaluation) -> String {
        switch evaluation {
        case .stretch:
            "passes stretch"
        case .target:
            "passes target"
        case .tooSlow:
            "too slow"
        case .notRun:
            "not run"
        }
    }
}

public struct EmbeddedRuntimeDecision: Equatable, Sendable {
    public let preferredCandidate: CompletionRuntimeCandidate
    public let fallbackCandidate: CompletionRuntimeCandidate
    public let allowsUserManagedServer: Bool

    public init(
        preferredCandidate: CompletionRuntimeCandidate,
        fallbackCandidate: CompletionRuntimeCandidate,
        allowsUserManagedServer: Bool
    ) {
        self.preferredCandidate = preferredCandidate
        self.fallbackCandidate = fallbackCandidate
        self.allowsUserManagedServer = allowsUserManagedServer
    }

    public static let mvp = EmbeddedRuntimeDecision(
        preferredCandidate: .liteRTLM,
        fallbackCandidate: .mlx,
        allowsUserManagedServer: false
    )
}
