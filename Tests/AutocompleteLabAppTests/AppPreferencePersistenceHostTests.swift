import AutocompleteLabCore
import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("App preference persistence host")
@MainActor
struct AppPreferencePersistenceHostTests {
    @Test("Persists preferences and local learning without AppDelegate")
    func persistsPreferencesAndLearning() throws {
        let suiteName = "SteadyType.AppPreferencePersistenceHostTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let host = AppPreferencePersistenceHost(defaults: defaults)
        host.load()
        host.keyboardShortcutConfiguration = KeyboardShortcutConfiguration(acceptAllShortcut: .optionTab)
        host.suggestionTuning = SuggestionTuning(
            aggressivenessLevel: 5,
            maxVisibleWords: 6,
            wordStartCharacters: 3,
            phraseStartWords: 4,
            responseSpeedLevel: 4,
            confidenceLevel: 5,
            learningRestraintLevel: 2
        )
        host.visiblePageContextEnabled = true
        host.acceptedAndKeptLearning.record(
            .kept,
            key: AcceptedAndKeptLearningKey(
                appBundleIdentifier: "com.example.editor",
                fieldKind: .multilineCompose,
                requestMode: .phraseContinuation,
                behaviorProfileID: .docsProse
            )
        )
        host.acceptedTextStyleMemory.recordKeptText(
            "a useful sentence.",
            key: AcceptedTextStyleMemoryKey(
                appBundleIdentifier: "com.example.editor",
                fieldKind: .multilineCompose,
                behaviorProfileID: .docsProse
            )
        )
        host.persistKeyboardShortcutConfiguration()
        host.persistSuggestionTuning()
        host.persistVisiblePageContextEnabled()
        host.persistAcceptedAndKeptLearning()
        host.persistAcceptedTextStyleMemory()

        let reloaded = AppPreferencePersistenceHost(defaults: defaults)
        reloaded.load()
        #expect(reloaded.keyboardShortcutConfiguration == host.keyboardShortcutConfiguration)
        #expect(reloaded.suggestionTuning == host.suggestionTuning)
        #expect(reloaded.visiblePageContextEnabled)
        #expect(reloaded.acceptedAndKeptLearning != AcceptedAndKeptLearningStore())
        #expect(reloaded.acceptedTextStyleMemory != AcceptedTextStyleMemoryStore())
    }

    @Test("Migrates legacy daily-driver tuning and clears learning data")
    func migratesAndClearsLearning() throws {
        let suiteName = "SteadyType.AppPreferencePersistenceHostTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(3, forKey: "SuggestionAggressivenessLevel")
        defaults.set(3, forKey: "SuggestionMaxVisibleWords")
        defaults.set(3, forKey: "SuggestionPhraseStartWords")
        defaults.set(3, forKey: "SuggestionResponseSpeedLevel")
        defaults.set(3, forKey: "SuggestionConfidenceLevel")
        defaults.set(2, forKey: "SuggestionLearningRestraintLevel")

        let host = AppPreferencePersistenceHost(defaults: defaults)
        host.load()
        #expect(host.suggestionTuning.aggressivenessLevel == SuggestionTuning.defaultAggressivenessLevel)
        #expect(host.suggestionTuning.maxVisibleWords == SuggestionTuning.defaultMaxVisibleWords)
        #expect(host.suggestionTuning.phraseStartWords == SuggestionTuning.defaultPhraseStartWords)
        #expect(host.suggestionTuning.responseSpeedLevel == SuggestionTuning.defaultResponseSpeedLevel)
        #expect(host.suggestionTuning.confidenceLevel == SuggestionTuning.defaultConfidenceLevel)
        #expect(host.suggestionTuning.learningRestraintLevel == SuggestionTuning.defaultLearningRestraintLevel)

        defaults.set(Data("persisted".utf8), forKey: "AcceptedAndKeptLearning")
        defaults.set(Data("persisted".utf8), forKey: "AcceptedTextStyleMemory")
        host.clearLearningData()
        #expect(defaults.data(forKey: "AcceptedAndKeptLearning") == nil)
        #expect(defaults.data(forKey: "AcceptedTextStyleMemory") == nil)
        #expect(host.acceptedAndKeptLearning == AcceptedAndKeptLearningStore())
        #expect(host.acceptedTextStyleMemory == AcceptedTextStyleMemoryStore())
    }

    @Test("AppDelegate keeps storage calls delegated to the preference host")
    func appDelegateDelegatesPreferenceStorage() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )

        #expect(appDelegate.contains("AppPreferencePersistenceHost()"))
        #expect(appDelegate.contains("appPreferencePersistenceHost.load()"))
        #expect(appDelegate.contains("appPreferencePersistenceHost.persistSuggestionTuning()"))
        #expect(!appDelegate.contains("SuggestionTuningDefaultsVersion"))
        #expect(!appDelegate.contains("UserDefaults.standard.set(\n            suggestionTuning"))
    }
}
