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
}

public enum ModelRuntimeOwnership: String, Equatable, Sendable {
    case appOwnedEmbedded
}

public struct CompletionModelPolicy: Equatable, Sendable {
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
        self.maxVisibleWords = maxVisibleWords
        self.debounceMilliseconds = debounceMilliseconds
        self.targetLatencyMilliseconds = targetLatencyMilliseconds
        self.reasoningEnabled = reasoningEnabled
    }

    public static let mvp = CompletionModelPolicy(
        model: .gemma4E2B,
        runtimeOwnership: .appOwnedEmbedded,
        minimumMemoryGB: 16,
        maxGeneratedTokens: 16,
        maxVisibleWords: 8,
        debounceMilliseconds: 200,
        targetLatencyMilliseconds: 700,
        reasoningEnabled: false
    )

    public func supports(_ hardware: HardwareProfile) -> Bool {
        hardware.isAppleSilicon && hardware.memoryGB >= minimumMemoryGB
    }
}
