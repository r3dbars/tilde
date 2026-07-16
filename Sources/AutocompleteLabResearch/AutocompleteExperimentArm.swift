import Foundation
import AutocompleteLabCore

public extension CompletionModelPolicy {
    static let smallDraftExperiment = CompletionModelPolicy(
        model: .qwen3Medium,
        runtimeOwnership: .appOwnedEmbedded,
        minimumMemoryGB: 8,
        maxGeneratedTokens: 16,
        maxVisibleWords: 5,
        debounceMilliseconds: 10,
        targetLatencyMilliseconds: 35,
        reasoningEnabled: false
    )
}

public enum AutocompleteExperimentArm: String, Codable, Equatable, Sendable, CaseIterable {
    case length3Word = "length_3_word"
    case length1Word = "length_1_word"

    public var defaultMaxVisibleWords: Int {
        switch self {
        case .length3Word:
            8
        case .length1Word:
            1
        }
    }

    public var defaultMaxGeneratedTokens: Int {
        switch self {
        case .length3Word:
            20
        case .length1Word:
            4
        }
    }

    public var lengthConfiguration: CompletionLengthConfiguration {
        CompletionLengthConfiguration(
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
