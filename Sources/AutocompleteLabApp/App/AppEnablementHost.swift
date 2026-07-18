import AutocompleteLabCore
import Foundation

/// Owns persisted per-app suggestion enablement state. The app coordinator keeps
/// the user-facing actions and safety decisions; this host owns storage and
/// `DisabledAppSelection` lifecycle.
@MainActor
final class AppEnablementHost {
    private static let disabledAppsDefaultsKey = "DisabledBundleIdentifiers"
    private static let setupCompletedDefaultsKey = "AppEnablementSetupCompleted"
    private static let temporarilyEnabledBundleIDsEnvironmentKey =
        "AUTOCOMPLETE_LAB_TEMPORARILY_ENABLE_BUNDLE_IDS"

    private let profileStore: CompatibilityProfileStore
    var disabledBundleIdentifiers: Set<String> = []
    var setupCompleted = true

    init(profileStore: CompatibilityProfileStore) {
        self.profileStore = profileStore
    }

    func load(defaults: UserDefaults = .standard) {
        let disabledAppsKeyExists = defaults.object(forKey: Self.disabledAppsDefaultsKey) != nil
        let setupKeyExists = defaults.object(forKey: Self.setupCompletedDefaultsKey) != nil
        let temporarilyEnabledBundleIDs = ProcessInfo.processInfo.environment[
            Self.temporarilyEnabledBundleIDsEnvironmentKey
        ]

        if disabledAppsKeyExists {
            let persisted = defaults.stringArray(forKey: Self.disabledAppsDefaultsKey) ?? []
            var selection = DisabledAppSelection(persistedBundleIdentifiers: persisted)
            selection.temporarilyEnable(bundleIdentifiers: temporarilyEnabledBundleIDs)
            disabledBundleIdentifiers = selection.bundleIdentifiers
            setupCompleted = setupKeyExists
                ? defaults.bool(forKey: Self.setupCompletedDefaultsKey)
                : true
            defaults.set(setupCompleted, forKey: Self.setupCompletedDefaultsKey)
            return
        }

        var defaultOffSelection = DisabledAppSelection(defaultOffProfileStore: profileStore)
        disabledBundleIdentifiers = defaultOffSelection.bundleIdentifiers
        setupCompleted = false
        defaults.set(false, forKey: Self.setupCompletedDefaultsKey)
        persist(defaults: defaults)

        defaultOffSelection.temporarilyEnable(bundleIdentifiers: temporarilyEnabledBundleIDs)
        disabledBundleIdentifiers = defaultOffSelection.bundleIdentifiers
    }

    func persist(defaults: UserDefaults = .standard) {
        let selection = DisabledAppSelection(bundleIdentifiers: disabledBundleIdentifiers)
        defaults.set(
            selection.persistedBundleIdentifiers,
            forKey: Self.disabledAppsDefaultsKey
        )
    }

    func markSetupCompleted(defaults: UserDefaults = .standard) {
        guard !setupCompleted else {
            return
        }

        setupCompleted = true
        defaults.set(true, forKey: Self.setupCompletedDefaultsKey)
    }
}
