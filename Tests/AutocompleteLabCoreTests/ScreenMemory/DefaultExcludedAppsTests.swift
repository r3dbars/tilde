import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Default excluded apps")
struct DefaultExcludedAppsTests {
    @Test("Known password managers and Keychain Access are always excluded")
    func knownAppsAreExcluded() {
        for bundleIdentifier in [
            "com.apple.keychainaccess",
            "com.1password.1password",
            "com.1password.1password7",
            "com.agilebits.onepassword7",
            "com.agilebits.onepassword-osx",
            "com.bitwarden.desktop",
            "com.dashlane.dashlanephonefinal",
            "com.lastpass.LastPass",
            "org.keepassxc.KeePassXC",
            "com.KeePass.mac",
            "com.nordsec.nordpass",
            "in.sinew.Enpass-Desktop",
        ] {
            #expect(DefaultExcludedApps.isAlwaysExcluded(bundleIdentifier), "\(bundleIdentifier) should be always-excluded")
        }
    }

    @Test("Ordinary apps are not always-excluded")
    func ordinaryAppsAreNotExcluded() {
        #expect(!DefaultExcludedApps.isAlwaysExcluded("com.apple.TextEdit"))
        #expect(!DefaultExcludedApps.isAlwaysExcluded("com.apple.Safari"))
        #expect(!DefaultExcludedApps.isAlwaysExcluded(""))
    }

    @Test("union always adds the default set on top of the caller's set, never replacing it")
    func unionIsAdditive() {
        let userSet: Set<String> = ["com.example.CustomApp"]
        let merged = DefaultExcludedApps.union(with: userSet)
        #expect(merged.contains("com.example.CustomApp"))
        #expect(merged.contains("com.1password.1password"))
        #expect(merged.isSuperset(of: DefaultExcludedApps.bundleIdentifiers))
    }

    @Test("union of an empty caller set still contains every default")
    func unionOfEmptySetIsStillTheDefaults() {
        #expect(DefaultExcludedApps.union(with: []) == DefaultExcludedApps.bundleIdentifiers)
    }

    @Test("Bundle identifiers are exact-match only, no accidental prefix matching")
    func noPrefixMatching() {
        // A hypothetical app whose id happens to start with a listed one
        // must NOT be treated as excluded — Set.contains is exact-match,
        // this test guards against a future refactor to prefix matching.
        #expect(!DefaultExcludedApps.isAlwaysExcluded("com.1password.1password.helper"))
    }
}
