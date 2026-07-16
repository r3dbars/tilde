import Foundation
import AutocompleteLabCore

public struct RuntimeProofOptions: Equatable, Sendable {
    public static let disableFastWordCompletionEnvironmentKey =
        "AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION"
    public static let disableWordCompletionEnvironmentKey =
        "AUTOCOMPLETE_LAB_PROOF_DISABLE_WORD_COMPLETION"
    public static let disablePhraseContinuationEnvironmentKey =
        "AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION"
    public static let disableFastPhraseFallbackEnvironmentKey =
        "AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_PHRASE_FALLBACK"
    public static let proofScenarioEnvironmentKey =
        "AUTOCOMPLETE_LAB_PROOF_SCENARIO"
    public static let codexPromptFullAcceptNoSubmitScenario =
        "codex-full-accept-no-submit"

    public let disablesFastWordCompletion: Bool
    public let disablesWordCompletion: Bool
    public let disablesPhraseContinuation: Bool
    public let disablesFastPhraseFallback: Bool
    public let proofScenario: String?

    public var allowsCodexPromptFullAcceptNoSubmitProof: Bool {
        proofScenario == Self.codexPromptFullAcceptNoSubmitScenario
    }

    public init(
        disablesFastWordCompletion: Bool = false,
        disablesWordCompletion: Bool = false,
        disablesPhraseContinuation: Bool = false,
        disablesFastPhraseFallback: Bool = false,
        proofScenario: String? = nil
    ) {
        self.disablesFastWordCompletion = disablesFastWordCompletion
        self.disablesWordCompletion = disablesWordCompletion
        self.disablesPhraseContinuation = disablesPhraseContinuation
        self.disablesFastPhraseFallback = disablesFastPhraseFallback
        self.proofScenario = Self.normalizedScenario(proofScenario)
    }

    public init(environment: [String: String]) {
        self.init(
            disablesFastWordCompletion: Self.isTruthy(
                environment[Self.disableFastWordCompletionEnvironmentKey]
            ),
            disablesWordCompletion: Self.isTruthy(
                environment[Self.disableWordCompletionEnvironmentKey]
            ),
            disablesPhraseContinuation: Self.isTruthy(
                environment[Self.disablePhraseContinuationEnvironmentKey]
            ),
            disablesFastPhraseFallback: Self.isTruthy(
                environment[Self.disableFastPhraseFallbackEnvironmentKey]
            ),
            proofScenario: environment[Self.proofScenarioEnvironmentKey]
        )
    }

    public func disablesFastWordCompletion(
        appBundleIdentifier: String,
        activeProofBundleIdentifiers: Set<String>
    ) -> Bool {
        disablesFastWordCompletion
            && activeProofBundleIdentifiers.contains(appBundleIdentifier)
    }

    public func disablesWordCompletion(
        appBundleIdentifier: String,
        activeProofBundleIdentifiers: Set<String>
    ) -> Bool {
        disablesWordCompletion
            && activeProofBundleIdentifiers.contains(appBundleIdentifier)
    }

    public func disablesPhraseContinuation(
        appBundleIdentifier: String,
        activeProofBundleIdentifiers: Set<String>
    ) -> Bool {
        disablesPhraseContinuation
            && activeProofBundleIdentifiers.contains(appBundleIdentifier)
    }

    public func disablesFastPhraseFallback(
        appBundleIdentifier: String,
        activeProofBundleIdentifiers: Set<String>
    ) -> Bool {
        disablesFastPhraseFallback
            && activeProofBundleIdentifiers.contains(appBundleIdentifier)
    }

    public static func fromProcessEnvironment() -> RuntimeProofOptions {
        RuntimeProofOptions(environment: ProcessInfo.processInfo.environment)
    }

    private static func isTruthy(_ value: String?) -> Bool {
        guard let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        else {
            return false
        }

        return ["1", "true", "yes", "on"].contains(normalized)
    }

    private static func normalizedScenario(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalized, !normalized.isEmpty else {
            return nil
        }
        return normalized
    }
}
