import Foundation

public struct RuntimeProofOptions: Equatable, Sendable {
    public static let disableFastWordCompletionEnvironmentKey =
        "AUTOCOMPLETE_LAB_PROOF_DISABLE_FAST_WORD_COMPLETION"

    public let disablesFastWordCompletion: Bool

    public init(disablesFastWordCompletion: Bool = false) {
        self.disablesFastWordCompletion = disablesFastWordCompletion
    }

    public init(environment: [String: String]) {
        self.init(
            disablesFastWordCompletion: Self.isTruthy(
                environment[Self.disableFastWordCompletionEnvironmentKey]
            )
        )
    }

    public func disablesFastWordCompletion(
        appBundleIdentifier: String,
        activeProofBundleIdentifiers: Set<String>
    ) -> Bool {
        disablesFastWordCompletion
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
}
