import Foundation

public struct CompletionDecodingStrategy: Equatable, Sendable {
    public let temperature: Double
    public let topP: Double
    public let repetitionPenalty: Double?
    public let sampleCount: Int

    public init(
        temperature: Double,
        topP: Double = 1,
        repetitionPenalty: Double? = 1.05,
        sampleCount: Int = 1
    ) {
        self.temperature = max(0, temperature)
        self.topP = min(max(topP, 0), 1)
        self.repetitionPenalty = repetitionPenalty.map { max(1, $0) }
        self.sampleCount = max(1, sampleCount)
    }

    public var identifier: String {
        "temp-\(Self.format(temperature))-top-p-\(Self.format(topP))-repeat-\(repetitionPenalty.map(Self.format) ?? "off")-samples-\(sampleCount)"
    }

    public func strategy(forSampleAt index: Int) -> CompletionDecodingStrategy {
        guard index > 0 else {
            return CompletionDecodingStrategy(
                temperature: 0,
                repetitionPenalty: repetitionPenalty,
                sampleCount: 1
            )
        }
        return CompletionDecodingStrategy(
            temperature: temperature,
            topP: topP,
            repetitionPenalty: repetitionPenalty,
            sampleCount: 1
        )
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

public struct CompletionDecodingStrategyPolicy: Equatable, Sendable {
    public let sampledTokenThreshold: Int

    public init(sampledTokenThreshold: Int = 24) {
        self.sampledTokenThreshold = max(8, sampledTokenThreshold)
    }

    public func strategy(for mode: CompletionRequestMode, maxGeneratedTokens: Int) -> CompletionDecodingStrategy {
        guard mode.isContinuation, maxGeneratedTokens >= sampledTokenThreshold else {
            return CompletionDecodingStrategy(temperature: 0)
        }
        return CompletionDecodingStrategy(
            temperature: 0.35,
            topP: 0.9,
            repetitionPenalty: 1.05,
            sampleCount: 2
        )
    }
}
