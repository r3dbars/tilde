import AutocompleteLabCore
import Testing
@testable import AutocompleteLabApp

@Suite("Startup onboarding policy")
struct StartupOnboardingPolicyTests {
    private let policy = StartupOnboardingPolicy()

    @Test("Defers Accessibility prompt behind Settings explanation")
    func defersAccessibilityPromptBehindSettingsExplanation() {
        #expect(!policy.shouldRequestAccessibilityPromptOnLaunch(isTrusted: false))
        #expect(!policy.shouldRequestAccessibilityPromptOnLaunch(isTrusted: true))
    }

    @Test("Shows Settings when Accessibility is missing")
    func showsSettingsWhenAccessibilityIsMissing() {
        #expect(policy.shouldShowSettingsOnLaunch(
            isTrusted: false,
            runtimeStage: .ready,
            appEnablementSetupCompleted: true
        ))
    }

    @Test("Shows Settings for runtime setup blockers")
    func showsSettingsForRuntimeSetupBlockers() {
        for stage in [
            RuntimeReadinessStage.downloadNeeded,
            .repairNeeded,
            .runtimeUnavailable,
            .failed
        ] {
            #expect(policy.shouldShowSettingsOnLaunch(
                isTrusted: true,
                runtimeStage: stage,
                appEnablementSetupCompleted: true
            ))
        }
    }

    @Test("Shows Settings until app enablement setup is complete")
    func showsSettingsUntilAppEnablementSetupIsComplete() {
        #expect(policy.shouldShowSettingsOnLaunch(
            isTrusted: true,
            runtimeStage: .ready,
            appEnablementSetupCompleted: false
        ))

        #expect(!policy.shouldShowSettingsOnLaunch(
            isTrusted: true,
            runtimeStage: .ready,
            appEnablementSetupCompleted: true
        ))
    }
}
