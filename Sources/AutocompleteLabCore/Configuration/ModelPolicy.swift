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
    public static let maximumVisibleWords = 7
    public static let minimumGeneratedTokens = 3
    public static let maximumGeneratedTokens = 16

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
        model: .qwen35FourB,
        runtimeOwnership: .appOwnedEmbedded,
        minimumMemoryGB: 16,
        maxGeneratedTokens: 10,
        maxVisibleWords: 5,
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
}

public struct CompletionLengthConfiguration: Equatable, Sendable {
    public let experimentArm: AutocompleteExperimentArm
    public let maxVisibleWords: Int
    public let maxGeneratedTokens: Int

    public init(
        experimentArm: AutocompleteExperimentArm = .length3Word,
        maxVisibleWords: Int,
        maxGeneratedTokens: Int? = nil
    ) {
        self.experimentArm = experimentArm
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
        experimentArm: .length3Word,
        maxVisibleWords: CompletionModelPolicy.mvp.maxVisibleWords,
        maxGeneratedTokens: CompletionModelPolicy.mvp.maxGeneratedTokens
    )

    public var displaySummary: String {
        "\(maxVisibleWords) words / \(maxGeneratedTokens) tokens"
    }

    public static func fromEnvironment(_ environment: [String: String]) -> CompletionLengthConfiguration {
        let arm = AutocompleteExperimentArm.fromEnvironment(environment)
        let visibleWords = parsedInt(environment["AUTOCOMPLETE_LAB_VISIBLE_WORDS"])
        let generatedTokens = parsedInt(environment["AUTOCOMPLETE_LAB_MAX_GENERATED_TOKENS"])
        let hasExperimentOverride = environment["AUTOCOMPLETE_LAB_EXPERIMENT_ARM"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false

        guard hasExperimentOverride || visibleWords != nil || generatedTokens != nil else {
            return CompletionLengthConfiguration(
                experimentArm: arm,
                maxVisibleWords: CompletionModelPolicy.mvp.maxVisibleWords,
                maxGeneratedTokens: CompletionModelPolicy.mvp.maxGeneratedTokens
            )
        }

        return CompletionLengthConfiguration(
            experimentArm: arm,
            maxVisibleWords: visibleWords ?? arm.defaultMaxVisibleWords,
            maxGeneratedTokens: generatedTokens ?? (visibleWords == nil ? arm.defaultMaxGeneratedTokens : nil)
        )
    }

    private static func parsedInt(_ value: String?) -> Int? {
        guard let value else {
            return nil
        }

        return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func defaultGeneratedTokens(forVisibleWords visibleWords: Int) -> Int {
        CompletionModelPolicy.clampedGeneratedTokens(visibleWords + 6)
    }
}

public enum AutocompleteExperimentArm: String, Codable, Equatable, Sendable, CaseIterable {
    case length3Word = "length_3_word"
    case length1Word = "length_1_word"

    public var defaultMaxVisibleWords: Int {
        switch self {
        case .length3Word:
            3
        case .length1Word:
            1
        }
    }

    public var defaultMaxGeneratedTokens: Int {
        switch self {
        case .length3Word:
            9
        case .length1Word:
            4
        }
    }

    public var lengthConfiguration: CompletionLengthConfiguration {
        CompletionLengthConfiguration(
            experimentArm: self,
            maxVisibleWords: defaultMaxVisibleWords,
            maxGeneratedTokens: defaultMaxGeneratedTokens
        )
    }

    public static func fromEnvironment(_ environment: [String: String]) -> AutocompleteExperimentArm {
        guard let rawValue = environment["AUTOCOMPLETE_LAB_EXPERIMENT_ARM"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !rawValue.isEmpty else {
            return .length3Word
        }

        return AutocompleteExperimentArm(rawValue: rawValue) ?? .length3Word
    }
}

public struct AutocompleteExperimentArmSelection: Equatable, Sendable {
    public enum Source: String, Equatable, Sendable {
        case environment
        case persisted
        case assigned
    }

    public let arm: AutocompleteExperimentArm
    public let source: Source

    public var shouldPersist: Bool {
        source != .persisted
    }

    public init(arm: AutocompleteExperimentArm, source: Source) {
        self.arm = arm
        self.source = source
    }

    public static func current(
        environment: [String: String],
        persistedRawValue: String?,
        chooseArm: @Sendable () -> AutocompleteExperimentArm = {
            Bool.random() ? .length1Word : .length3Word
        }
    ) -> AutocompleteExperimentArmSelection {
        if let rawValue = environment["AUTOCOMPLETE_LAB_EXPERIMENT_ARM"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            let arm = AutocompleteExperimentArm(rawValue: rawValue) {
            return AutocompleteExperimentArmSelection(arm: arm, source: .environment)
        }

        if let rawValue = persistedRawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
           let arm = AutocompleteExperimentArm(rawValue: rawValue) {
            return AutocompleteExperimentArmSelection(arm: arm, source: .persisted)
        }

        return AutocompleteExperimentArmSelection(arm: chooseArm(), source: .assigned)
    }
}
