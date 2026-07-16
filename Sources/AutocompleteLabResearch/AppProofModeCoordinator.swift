import AutocompleteLabCore
import Foundation

@MainActor
final class AppProofModeCoordinator {
    typealias DiagnosticsRecorder = (_ event: String, _ metadata: [String: String]) -> Void
    typealias ExpirationScheduler = (_ expire: @escaping @MainActor @Sendable () -> Void) -> Task<Void, Never>

    static var temporarilyEnabledBundleIDsEnvironmentKey: String {
        "AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS"
    }

    static var proofModeBundleIDsEnvironmentKey: String {
        "AUTOCOMPLETE_LAB_PROOF_MODE_BUNDLE_IDS"
    }

    private let runtimeProofOptions: RuntimeProofOptions
    private let expirationScheduler: ExpirationScheduler
    private let diagnosticsRecorder: DiagnosticsRecorder
    private var activeProofBundleIdentifiers: Set<String> = []
    private var scopePolicy = ProofModeScopePolicy()
    private var expirationTasks: [String: Task<Void, Never>] = [:]

    var activeBundleIdentifiers: Set<String> {
        activeProofBundleIdentifiers
    }

    init(
        runtimeProofOptions: RuntimeProofOptions = .fromProcessEnvironment(),
        expirationScheduler: @escaping ExpirationScheduler = { expire in
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 10 * 60 * 1_000_000_000)
                guard !Task.isCancelled else {
                    return
                }

                expire()
            }
        },
        diagnosticsRecorder: @escaping DiagnosticsRecorder = { event, metadata in
            ResearchDiagnosticsLog.shared.record(event, metadata: metadata)
        }
    ) {
        self.runtimeProofOptions = runtimeProofOptions
        self.expirationScheduler = expirationScheduler
        self.diagnosticsRecorder = diagnosticsRecorder
    }

    func loadEnvironmentOverrides(environment: [String: String] = ProcessInfo.processInfo.environment) {
        let environmentProofBundleIdentifiers = Set(
            DisabledAppSelection.parseBundleIdentifierList(environment[Self.proofModeBundleIDsEnvironmentKey])
        )
        let proofBundleIdentifiers = Set(
            DisabledAppSelection.parseBundleIdentifierList(environment[Self.temporarilyEnabledBundleIDsEnvironmentKey])
                + Array(environmentProofBundleIdentifiers)
        )
        scopePolicy = ProofModeScopePolicy(scopedBundleIdentifiers: environmentProofBundleIdentifiers)
        guard !proofBundleIdentifiers.isEmpty else {
            return
        }

        for bundleIdentifier in proofBundleIdentifiers.sorted() {
            begin(for: bundleIdentifier)
        }
        diagnosticsRecorder(
            "app-proof-mode-env",
            [
                "apps": proofBundleIdentifiers.sorted().joined(separator: ",")
            ]
        )
    }

    func allows(
        appBundleIdentifier: String,
        suggestionBundleIdentifier: String
    ) -> Bool {
        scopePolicy.allows(
            appBundleIdentifier: appBundleIdentifier,
            suggestionBundleIdentifier: suggestionBundleIdentifier
        )
    }

    func isActive(for bundleIdentifier: String) -> Bool {
        activeProofBundleIdentifiers.contains(bundleIdentifier)
    }

    func begin(for bundleIdentifier: String) {
        activeProofBundleIdentifiers.insert(bundleIdentifier)
        expirationTasks[bundleIdentifier]?.cancel()
        expirationTasks[bundleIdentifier] = expirationScheduler { [weak self] in
            self?.end(for: bundleIdentifier, reason: "expired")
        }

        var metadata = [
            "app": bundleIdentifier
        ]
        if let proofScenario = runtimeProofOptions.proofScenario {
            metadata["scenario"] = proofScenario
        }
        diagnosticsRecorder("app-proof-mode-started", metadata)
    }

    func end(for bundleIdentifier: String, reason: String) {
        expirationTasks[bundleIdentifier]?.cancel()
        expirationTasks.removeValue(forKey: bundleIdentifier)
        guard activeProofBundleIdentifiers.remove(bundleIdentifier) != nil else {
            return
        }

        diagnosticsRecorder(
            "app-proof-mode-ended",
            [
                "app": bundleIdentifier,
                "reason": reason
            ]
        )
    }

}
