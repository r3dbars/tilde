import AutocompleteLabCore

struct StartupOnboardingPolicy: Equatable {
    func shouldRequestAccessibilityPromptOnLaunch(isTrusted: Bool) -> Bool {
        !isTrusted
    }

    func shouldShowSettingsOnLaunch(
        isTrusted: Bool,
        runtimeStage: RuntimeReadinessStage,
        appEnablementSetupCompleted: Bool
    ) -> Bool {
        if !isTrusted {
            return true
        }

        switch runtimeStage {
        case .downloadNeeded, .repairNeeded, .runtimeUnavailable, .failed:
            return true
        case .warming, .ready:
            return !appEnablementSetupCompleted
        }
    }
}
