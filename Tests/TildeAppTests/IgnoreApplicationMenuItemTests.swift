import Foundation
import Testing
@testable import TildeApp
@testable import TildeCore

/// The pure half of the menu bar's one-click "Ignore <App>": what the item
/// is called, and what adding an app does to the shared excluded-apps list.
@Suite("Ignore current app menu item")
struct IgnoreApplicationMenuItemTests {
    private let safari = ForegroundApplication(
        bundleIdentifier: "com.apple.Safari",
        name: "Safari"
    )

    @Test("The item names the app the user was actually writing in")
    func titleNamesTheApp() {
        #expect(
            IgnoreApplicationMenuItem.title(for: safari, isIgnored: false) == "Ignore Safari"
        )
    }

    @Test("An already-ignored app says so instead of offering the same click again")
    func titleReportsAnIgnoredApp() {
        #expect(
            IgnoreApplicationMenuItem.title(for: safari, isIgnored: true) == "Ignoring Safari"
        )
    }

    @Test("With no other app seen yet there is nothing to offer")
    func titleIsNilWithoutAForegroundApp() {
        #expect(IgnoreApplicationMenuItem.title(for: nil, isIgnored: false) == nil)
    }

    @Test("An app with no display name falls back to its bundle identifier")
    func titleFallsBackToBundleIdentifier() {
        let unnamed = ForegroundApplication(bundleIdentifier: "com.example.Editor", name: "")
        #expect(
            IgnoreApplicationMenuItem.title(for: unnamed, isIgnored: false)
                == "Ignore com.example.Editor"
        )
    }

    @Test("Adding an app writes the bundle identifier into the shared list")
    func addingStoresTheBundleIdentifier() {
        let updated = IgnoreApplicationMenuItem.adding(safari.bundleIdentifier, to: [])
        #expect(updated == ["com.apple.Safari"])
    }

    @Test("Adding the same app twice changes nothing")
    func addingIsIdempotent() {
        let once = IgnoreApplicationMenuItem.adding(
            safari.bundleIdentifier,
            to: ["com.tinyspeck.slackmacgap"]
        )
        let twice = IgnoreApplicationMenuItem.adding(safari.bundleIdentifier, to: once)
        #expect(once == twice)
        #expect(twice == ["com.apple.Safari", "com.tinyspeck.slackmacgap"])
    }

    /// The list is keyed by bundle identifier and shared with Personal
    /// History, so an identifier that contract would reject is never
    /// stored: it could not match anything, and would only look like an
    /// exclusion that silently never fires.
    @Test("An identifier the shared contract rejects is never stored")
    func invalidIdentifierIsRefused() {
        let existing: Set<String> = ["com.apple.Safari"]
        #expect(IgnoreApplicationMenuItem.adding("", to: existing) == existing)
        #expect(IgnoreApplicationMenuItem.adding("not a bundle id", to: existing) == existing)
    }

    @Test("The exclusion an ignore writes is the one every reader already checks")
    func addedAppIsExcludedEverywhere() {
        let updated = IgnoreApplicationMenuItem.adding(safari.bundleIdentifier, to: [])
        #expect(
            DefaultExcludedApps.isExcluded(
                safari.bundleIdentifier,
                configuredExcludedApps: updated
            )
        )
        #expect(
            PersonalHistoryCapturePolicy().decision(
                enabled: true,
                secureInput: false,
                appBundleIdentifier: safari.bundleIdentifier,
                excludedApps: updated
            ) == .blocked(.excludedApp)
        )
    }
}
