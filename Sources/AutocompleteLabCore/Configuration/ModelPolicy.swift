import Foundation

public struct HardwareProfile: Equatable, Sendable {
    public let chipName: String
    public let memoryGB: Int
    public let isAppleSilicon: Bool

    public init(chipName: String, memoryGB: Int, isAppleSilicon: Bool) {
        self.chipName = chipName
        self.memoryGB = memoryGB
        self.isAppleSilicon = isAppleSilicon
    }
}

public enum LocalModelID: String, Equatable, Sendable {
    case gemma4E2B = "Gemma 4 E2B"
    case gemma4E4B = "Gemma 4 E4B"
    case gemma4E4BItOptiQ = "Gemma 4 E4B IT OptiQ"
    case gemma4A4B = "Gemma 4 26B A4B"
    case qwen3Small = "Qwen3 0.6B"
    case qwen3Medium = "Qwen3 1.7B"
    case qwen35FourB = "Qwen3.5 4B"
    case qwen35NineB = "Qwen3.5 9B"
}

public enum ModelRuntimeOwnership: String, Equatable, Sendable {
    case appOwnedEmbedded
}

public struct CompletionModelPolicy: Equatable, Sendable {
    public static let minimumVisibleWords = 1
    public static let maximumVisibleWords = 20
    public static let minimumGeneratedTokens = 3
    public static let maximumGeneratedTokens = 48

    public let model: LocalModelID
    public let runtimeOwnership: ModelRuntimeOwnership
    public let minimumMemoryGB: Int
    public let maxGeneratedTokens: Int
    public let maxVisibleWords: Int
    public let debounceMilliseconds: Int
    public let targetLatencyMilliseconds: Int
    public let reasoningEnabled: Bool

    public init(
        model: LocalModelID,
        runtimeOwnership: ModelRuntimeOwnership,
        minimumMemoryGB: Int,
        maxGeneratedTokens: Int,
        maxVisibleWords: Int,
        debounceMilliseconds: Int,
        targetLatencyMilliseconds: Int,
        reasoningEnabled: Bool
    ) {
        self.model = model
        self.runtimeOwnership = runtimeOwnership
        self.minimumMemoryGB = minimumMemoryGB
        self.maxGeneratedTokens = maxGeneratedTokens
        self.maxVisibleWords = Self.clampedVisibleWords(maxVisibleWords)
        self.debounceMilliseconds = debounceMilliseconds
        self.targetLatencyMilliseconds = targetLatencyMilliseconds
        self.reasoningEnabled = reasoningEnabled
    }

    public static let mvp = CompletionModelPolicy(
        model: .gemma4E4BItOptiQ,
        runtimeOwnership: .appOwnedEmbedded,
        minimumMemoryGB: 16,
        maxGeneratedTokens: 20,
        maxVisibleWords: 8,
        debounceMilliseconds: 15,
        targetLatencyMilliseconds: 50,
        reasoningEnabled: false
    )

    public func supports(_ hardware: HardwareProfile) -> Bool {
        hardware.isAppleSilicon && hardware.memoryGB >= minimumMemoryGB
    }

    public func allowsVisibleWordCount(_ wordCount: Int) -> Bool {
        wordCount >= Self.minimumVisibleWords && wordCount <= maxVisibleWords
    }

    public static func clampedVisibleWords(_ value: Int) -> Int {
        min(maximumVisibleWords, max(minimumVisibleWords, value))
    }

    public static func clampedGeneratedTokens(_ value: Int) -> Int {
        min(maximumGeneratedTokens, max(minimumGeneratedTokens, value))
    }

    public static func generatedTokenBudget(forVisibleWords visibleWords: Int) -> Int {
        let visibleWords = clampedVisibleWords(visibleWords)
        guard visibleWords > mvp.maxVisibleWords else {
            return clampedGeneratedTokens(visibleWords + 6)
        }

        return clampedGeneratedTokens((visibleWords * 2) + 4)
    }

    public static func preferredMinimumVisibleWords(forVisibleWords visibleWords: Int) -> Int {
        let visibleWords = clampedVisibleWords(visibleWords)
        switch visibleWords {
        case 16...:
            return 12
        case 12...:
            return 8
        case 9...:
            return 5
        case 5...:
            return 3
        default:
            return minimumVisibleWords
        }
    }
}

public struct CompletionLengthConfiguration: Equatable, Sendable {
    public let maxVisibleWords: Int
    public let maxGeneratedTokens: Int

    public init(
        maxVisibleWords: Int,
        maxGeneratedTokens: Int? = nil
    ) {
        let visibleWords = min(
            CompletionModelPolicy.maximumVisibleWords,
            max(CompletionModelPolicy.minimumVisibleWords, maxVisibleWords)
        )
        self.maxVisibleWords = visibleWords
        self.maxGeneratedTokens = CompletionModelPolicy.clampedGeneratedTokens(
            maxGeneratedTokens ?? Self.defaultGeneratedTokens(forVisibleWords: visibleWords)
        )
    }

    public static let `default` = CompletionLengthConfiguration(
        maxVisibleWords: CompletionModelPolicy.mvp.maxVisibleWords,
        maxGeneratedTokens: CompletionModelPolicy.mvp.maxGeneratedTokens
    )

    public var displaySummary: String {
        "\(maxVisibleWords) words / \(maxGeneratedTokens) tokens"
    }

    private static func defaultGeneratedTokens(forVisibleWords visibleWords: Int) -> Int {
        CompletionModelPolicy.generatedTokenBudget(forVisibleWords: visibleWords)
    }
}
