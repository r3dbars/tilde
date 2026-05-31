import Testing
@testable import AutocompleteLabCore

@Suite("Disabled app selection")
struct DisabledAppSelectionTests {
    @Test("Persisted bundle IDs are deduplicated and sorted")
    func persistedBundleIDsAreDeduplicatedAndSorted() {
        let selection = DisabledAppSelection(
            persistedBundleIdentifiers: [
                "md.obsidian",
                "com.apple.TextEdit",
                "md.obsidian",
                ""
            ]
        )

        #expect(selection.persistedBundleIdentifiers == ["com.apple.TextEdit", "md.obsidian"])
    }

    @Test("Toggle adds and removes bundle IDs")
    func toggleAddsAndRemovesBundleIDs() {
        var selection = DisabledAppSelection()

        selection.toggle("com.apple.TextEdit")
        #expect(selection.contains("com.apple.TextEdit"))

        selection.toggle("com.apple.TextEdit")
        #expect(!selection.contains("com.apple.TextEdit"))
    }

    @Test("Set directly enables and disables bundle IDs")
    func setDirectlyEnablesAndDisablesBundleIDs() {
        var selection = DisabledAppSelection()

        selection.set("com.apple.TextEdit", disabled: true)
        #expect(selection.contains("com.apple.TextEdit"))

        selection.set("com.apple.TextEdit", disabled: false)
        #expect(!selection.contains("com.apple.TextEdit"))
    }

    @Test("Clear removes all disabled apps")
    func clearRemovesAllDisabledApps() {
        var selection = DisabledAppSelection(bundleIdentifiers: ["com.apple.TextEdit", "md.obsidian"])

        #expect(!selection.isEmpty)
        #expect(selection.count == 2)

        selection.clear()

        #expect(selection.isEmpty)
        #expect(selection.count == 0)
        #expect(selection.persistedBundleIdentifiers == [])
    }

    @Test("Empty bundle IDs are ignored")
    func emptyBundleIDsAreIgnored() {
        var selection = DisabledAppSelection()

        selection.toggle("")
        selection.set("", disabled: true)

        #expect(selection.isEmpty)
        #expect(selection.persistedBundleIdentifiers == [])
    }

    @Test("Fresh install default is open for suggestion capable apps")
    func freshInstallDefaultIsOpenForSuggestionCapableApps() {
        let selection = DisabledAppSelection(defaultOffProfileStore: .mvp)

        #expect(selection.isEmpty)
        #expect(!selection.contains("com.apple.TextEdit"))
        #expect(!selection.contains("com.apple.Notes"))
        #expect(!selection.contains("md.obsidian"))
        #expect(!selection.contains("com.google.Chrome"))
        #expect(!selection.contains("com.apple.mail"))
        #expect(!selection.contains("com.apple.Safari"))
        #expect(!selection.contains("com.apple.Passwords"))
    }

    @Test("Missing persisted defaults start with no paused apps")
    func missingPersistedDefaultsStartWithNoPausedApps() {
        let selection = DisabledAppSelection(
            persistedBundleIdentifiers: nil,
            defaultOffProfileStore: .mvp
        )

        #expect(selection.isEmpty)
        #expect(!selection.contains("com.apple.TextEdit"))
        #expect(!selection.contains("com.apple.Notes"))
        #expect(!selection.contains("com.apple.mail"))
    }

    @Test("Persisted defaults stay authoritative")
    func persistedDefaultsStayAuthoritative() {
        let selection = DisabledAppSelection(
            persistedBundleIdentifiers: ["com.apple.TextEdit"],
            defaultOffProfileStore: .mvp
        )

        #expect(selection.contains("com.apple.TextEdit"))
        #expect(!selection.contains("com.apple.Notes"))
    }

    @Test("Temporary enable override removes target apps from disabled set")
    func temporaryEnableOverrideRemovesTargetAppsFromDisabledSet() {
        var selection = DisabledAppSelection(
            bundleIdentifiers: [
                "com.apple.TextEdit",
                "com.google.Chrome",
                "md.obsidian"
            ]
        )

        selection.temporarilyEnable(bundleIdentifiers: "com.apple.TextEdit, md.obsidian")

        #expect(!selection.contains("com.apple.TextEdit"))
        #expect(selection.contains("com.google.Chrome"))
        #expect(!selection.contains("md.obsidian"))
    }

    @Test("Temporary enable override parses comma space and newline lists")
    func temporaryEnableOverrideParsesLists() {
        #expect(
            DisabledAppSelection.parseBundleIdentifierList(
                "com.apple.TextEdit, md.obsidian\ncom.google.Chrome  "
            )
            == [
                "com.apple.TextEdit",
                "md.obsidian",
                "com.google.Chrome"
            ]
        )
    }
}
