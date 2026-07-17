import Testing
@testable import AutocompleteLabApp

@Suite("Suggestion tuning defaults migration")
struct SuggestionTuningDefaultsMigrationTests {
    @Test("Migrates prior shipped visible-word defaults")
    func migratesPriorDefaults() {
        #expect(SuggestionTuningDefaultsMigration.maxVisibleWords(3, shouldMigrate: true) == 4)
        #expect(SuggestionTuningDefaultsMigration.maxVisibleWords(5, shouldMigrate: true) == 4)
    }

    @Test("Preserves explicit long-suggestion preferences")
    func preservesExplicitPreferences() {
        #expect(SuggestionTuningDefaultsMigration.maxVisibleWords(12, shouldMigrate: true) == 12)
        #expect(SuggestionTuningDefaultsMigration.maxVisibleWords(20, shouldMigrate: true) == 20)
        #expect(SuggestionTuningDefaultsMigration.maxVisibleWords(5, shouldMigrate: false) == 5)
    }
}
