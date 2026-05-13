import Foundation

public struct RuntimeProofOptions: Equatable, Sendable {
    public static let disableFastWordCompletionEnvironmentKey =
        "AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION"
    public static let disablePhraseContinuationEnvironmentKey =
        "AUTOCOMPLETE_LAB_PROOF_DISABLE_PHRASE_CONTINUATION"
    public static let proofScenarioEnvironmentKey =
        "AUTOCOMPLETE_LAB_PROOF_SCENARIO"

    public let disablesFastWordCompletion: Bool
    public let disablesPhraseContinuation: Bool
    public let proofScenario: String?

    public init(
        disablesFastWordCompletion: Bool = false,
        disablesPhraseContinuation: Bool = false,
        proofScenario: String? = nil
    ) {
        self.disablesFastWordCompletion = disablesFastWordCompletion
        self.disablesPhraseContinuation = disablesPhraseContinuation
        self.proofScenario = Self.normalizedScenario(proofScenario)
    }

    public init(environment: [String: String]) {
        self.init(
            disablesFastWordCompletion: Self.isTruthy(
                environment[Self.disableFastWordCompletionEnvironmentKey]
            ),
            disablesPhraseContinuation: Self.isTruthy(
                environment[Self.disablePhraseContinuationEnvironmentKey]
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

    public func disablesPhraseContinuation(
        appBundleIdentifier: String,
        activeProofBundleIdentifiers: Set<String>
    ) -> Bool {
        disablesPhraseContinuation
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
