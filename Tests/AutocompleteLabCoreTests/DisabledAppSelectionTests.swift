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
}
