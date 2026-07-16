import Foundation
import AutocompleteLabCore

enum ModelWarmProofCommand {
    private static let flag = "--model-warm-proof"

    static func isRequested(arguments: [String]) -> Bool {
        arguments.contains(flag)
    }

    @discardableResult
    static func run(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        defaults: UserDefaults = .standard
    ) async -> Int32 {
        let bundle = AppModelRuntimeFactory.makeRuntime(
            environment: environment,
            defaults: defaults
        )

        guard bundle.bootstrapPlan.canWarmPreferredRuntime else {
            fputs("Model warm proof failed: runtime is unavailable\n", stderr)
            return 1
        }

        do {
            try await bundle.runtime.warm()
            defer {
                bundle.runtime.cancel()
            }

            guard await bundle.runtime.state == .ready(candidate: .mlx) else {
                fputs("Model warm proof failed: runtime did not become ready\n", stderr)
                return 1
            }

            print("Model warm proof passed: runtime ready")
            return 0
        } catch {
            fputs("Model warm proof failed: \(error.localizedDescription)\n", stderr)
            return 1
        }
    }
}
