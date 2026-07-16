import Testing
@testable import AutocompleteLabApp
@testable import AutocompleteLabResearch
import AutocompleteLabCore

@Suite("App proof mode coordinator")
struct AppProofModeCoordinatorTests {
    @Test("Environment overrides activate proof apps and keep scoped proof gating")
    @MainActor
    func environmentOverridesActivateProofAppsAndKeepScopedProofGating() {
        var records: [(event: String, metadata: [String: String])] = []
        let coordinator = AppProofModeCoordinator(
            expirationScheduler: { _ in Task {} },
            diagnosticsRecorder: { event, metadata in
                records.append((event, metadata))
            }
        )

        coordinator.loadEnvironmentOverrides(environment: [
            AppProofModeCoordinator.temporarilyEnabledBundleIDsEnvironmentKey: "com.google.Chrome",
            AppProofModeCoordinator.proofModeBundleIDsEnvironmentKey: "com.apple.TextEdit"
        ])

        #expect(coordinator.activeBundleIdentifiers == ["com.apple.TextEdit", "com.google.Chrome"])
        #expect(coordinator.allows(
            appBundleIdentifier: "com.apple.TextEdit",
            suggestionBundleIdentifier: "com.apple.TextEdit"
        ))
        #expect(!coordinator.allows(
            appBundleIdentifier: "com.google.Chrome",
            suggestionBundleIdentifier: "com.google.Chrome"
        ))
        #expect(records.contains { record in
            record.event == "app-proof-mode-env"
                && record.metadata["apps"] == "com.apple.TextEdit,com.google.Chrome"
        })
    }

    @Test("Proof mode expires through the injected scheduler")
    @MainActor
    func proofModeExpiresThroughInjectedScheduler() {
        var expirations: [@MainActor @Sendable () -> Void] = []
        var records: [(event: String, metadata: [String: String])] = []
        let coordinator = AppProofModeCoordinator(
            runtimeProofOptions: RuntimeProofOptions(proofScenario: "textedit-smoke"),
            expirationScheduler: { expire in
                expirations.append(expire)
                return Task {}
            },
            diagnosticsRecorder: { event, metadata in
                records.append((event, metadata))
            }
        )

        coordinator.begin(for: "com.apple.TextEdit")

        #expect(coordinator.isActive(for: "com.apple.TextEdit"))
        #expect(expirations.count == 1)
        #expect(records.last?.event == "app-proof-mode-started")
        #expect(records.last?.metadata["app"] == "com.apple.TextEdit")
        #expect(records.last?.metadata["scenario"] == "textedit-smoke")

        expirations[0]()

        #expect(!coordinator.isActive(for: "com.apple.TextEdit"))
        #expect(records.last?.event == "app-proof-mode-ended")
        #expect(records.last?.metadata["app"] == "com.apple.TextEdit")
        #expect(records.last?.metadata["reason"] == "expired")
    }
}
