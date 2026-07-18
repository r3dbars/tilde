import Foundation
import AutocompleteLabCore

struct FieldControlTarget: Equatable {
    let appBundleIdentifier: String
    let appDisplayName: String
    let fieldIdentity: FocusedFieldIdentity
    let requestMode: CompletionRequestMode?
    let fieldKind: AXFieldKind
}

/// Owns the last known eligible app and field targets used by Settings and
/// field controls when the frontmost app is SteadyType itself or temporarily
/// unavailable through Accessibility.
@MainActor
final class AppTargetStateHost {
    private let profileStore: CompatibilityProfileStore
    private var lastEligibleTargetApp: RunningApplicationInfo?
    private var lastObservedSettingsApp: RunningApplicationInfo?
    private var lastFieldControlTarget: FieldControlTarget?

    init(profileStore: CompatibilityProfileStore) {
        self.profileStore = profileStore
    }

    func fieldControlTarget(currentFieldIdentity: FocusedFieldIdentity?) -> FieldControlTarget? {
        if let currentFieldIdentity,
           let target = lastFieldControlTarget,
           target.fieldIdentity == currentFieldIdentity {
            return target
        }

        return lastFieldControlTarget
    }

    func appForSettingsState(frontmostApplication: RunningApplicationInfo?) -> RunningApplicationInfo? {
        if let frontmostApplication,
           frontmostApplication.bundleIdentifier != Bundle.main.bundleIdentifier {
            return frontmostApplication
        }

        return lastObservedSettingsApp ?? targetAppForControls(frontmostApplication: frontmostApplication)
    }

    func targetAppForControls(frontmostApplication: RunningApplicationInfo?) -> RunningApplicationInfo? {
        if let frontmostApplication,
           profileStore.allows(bundleIdentifier: frontmostApplication.bundleIdentifier) {
            rememberEligibleTargetApp(frontmostApplication)
            return frontmostApplication
        }

        guard let app = lastEligibleTargetApp,
              profileStore.allows(bundleIdentifier: app.bundleIdentifier) else {
            return nil
        }

        return app
    }

    func rememberEligibleTargetApp(_ app: RunningApplicationInfo) {
        guard profileStore.allows(bundleIdentifier: app.bundleIdentifier) else {
            return
        }

        lastEligibleTargetApp = app
    }

    func rememberFieldControlTarget(
        app: RunningApplicationInfo,
        fieldIdentity: FocusedFieldIdentity,
        requestMode: CompletionRequestMode?,
        fieldKind: AXFieldKind
    ) {
        lastFieldControlTarget = FieldControlTarget(
            appBundleIdentifier: app.bundleIdentifier,
            appDisplayName: app.localizedName,
            fieldIdentity: fieldIdentity,
            requestMode: requestMode,
            fieldKind: fieldKind
        )
    }

    func noteObservedSettingsApp(_ app: RunningApplicationInfo) {
        lastObservedSettingsApp = app
    }
}
