import AutocompleteLabCore
import Foundation

/// Owns UserDefaults-backed preference and local learning persistence.
///
/// The app coordinator keeps policy and user-facing actions; this host keeps
/// serialization, migration, and the defaults keys in one small boundary.
@MainActor
final class AppPreferencePersistenceHost {
    private enum DefaultsKey {
        static let acceptAllShortcut = "AcceptAllShortcut"
        static let suggestionAggressiveness = "SuggestionAggressiveness"
        static let suggestionAggressivenessLevel = "SuggestionAggressivenessLevel"
        static let suggestionMaxVisibleWords = "SuggestionMaxVisibleWords"
        static let suggestionWordStartCharacters = "SuggestionWordStartCharacters"
        static let suggestionPhraseStartWords = "SuggestionPhraseStartWords"
        static let suggestionResponseSpeedLevel = "SuggestionResponseSpeedLevel"
        static let suggestionConfidenceLevel = "SuggestionConfidenceLevel"
        static let suggestionLearningRestraintLevel = "SuggestionLearningRestraintLevel"
        static let suggestionTuningDefaultsVersion = "SuggestionTuningDefaultsVersion"
        static let visiblePageContextEnabled = "VisiblePageContextEnabled"
        static let acceptedAndKeptLearning = "AcceptedAndKeptLearning"
        static let acceptedTextStyleMemory = "AcceptedTextStyleMemory"
    }

    private static let currentSuggestionTuningDefaultsVersion = 6
    private static let previousDefaultSuggestionAggressivenessLevel =
        SuggestionAggressiveness.normal.defaultTuningLevel

    private let defaults: UserDefaults

    var keyboardShortcutConfiguration = KeyboardShortcutConfiguration.default
    var suggestionTuning = SuggestionTuning()
    var visiblePageContextEnabled = false
    var acceptedAndKeptLearning = AcceptedAndKeptLearningStore()
    var acceptedTextStyleMemory = AcceptedTextStyleMemoryStore()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() {
        loadKeyboardShortcutConfiguration()
        loadSuggestionTuning()
        loadVisiblePageContextEnabled()
        loadAcceptedAndKeptLearning()
        loadAcceptedTextStyleMemory()
    }

    func persistKeyboardShortcutConfiguration() {
        defaults.set(
            keyboardShortcutConfiguration.acceptAllShortcut.rawValue,
            forKey: DefaultsKey.acceptAllShortcut
        )
    }

    func persistSuggestionTuning() {
        defaults.set(
            suggestionTuning.legacyAggressiveness.rawValue,
            forKey: DefaultsKey.suggestionAggressiveness
        )
        defaults.set(
            suggestionTuning.aggressivenessLevel,
            forKey: DefaultsKey.suggestionAggressivenessLevel
        )
        defaults.set(
            suggestionTuning.maxVisibleWords,
            forKey: DefaultsKey.suggestionMaxVisibleWords
        )
        defaults.set(
            suggestionTuning.wordStartCharacters,
            forKey: DefaultsKey.suggestionWordStartCharacters
        )
        defaults.set(
            suggestionTuning.phraseStartWords,
            forKey: DefaultsKey.suggestionPhraseStartWords
        )
        defaults.set(
            suggestionTuning.responseSpeedLevel,
            forKey: DefaultsKey.suggestionResponseSpeedLevel
        )
        defaults.set(
            suggestionTuning.confidenceLevel,
            forKey: DefaultsKey.suggestionConfidenceLevel
        )
        defaults.set(
            suggestionTuning.learningRestraintLevel,
            forKey: DefaultsKey.suggestionLearningRestraintLevel
        )
    }

    func persistVisiblePageContextEnabled() {
        defaults.set(
            visiblePageContextEnabled,
            forKey: DefaultsKey.visiblePageContextEnabled
        )
    }

    func persistAcceptedAndKeptLearning() {
        guard let data = acceptedAndKeptLearning.jsonData() else {
            return
        }

        defaults.set(data, forKey: DefaultsKey.acceptedAndKeptLearning)
    }

    func persistAcceptedTextStyleMemory() {
        guard let data = acceptedTextStyleMemory.jsonData() else {
            return
        }

        defaults.set(data, forKey: DefaultsKey.acceptedTextStyleMemory)
    }

    func clearLearningData() {
        acceptedAndKeptLearning = AcceptedAndKeptLearningStore()
        acceptedTextStyleMemory = AcceptedTextStyleMemoryStore()
        defaults.removeObject(forKey: DefaultsKey.acceptedAndKeptLearning)
        defaults.removeObject(forKey: DefaultsKey.acceptedTextStyleMemory)
    }
}

private extension AppPreferencePersistenceHost {
    func loadKeyboardShortcutConfiguration() {
        keyboardShortcutConfiguration = KeyboardShortcutConfiguration(
            persistedAcceptAllShortcutRawValue: defaults.string(forKey: DefaultsKey.acceptAllShortcut)
        )
    }

    func loadSuggestionTuning() {
        var level: Int
        let hasStoredLevel = defaults.object(forKey: DefaultsKey.suggestionAggressivenessLevel) != nil
        if hasStoredLevel {
            level = defaults.integer(forKey: DefaultsKey.suggestionAggressivenessLevel)
        } else {
            level = SuggestionAggressiveness
                .parsed(defaults.string(forKey: DefaultsKey.suggestionAggressiveness))
                .defaultTuningLevel
        }
        if defaults.object(forKey: DefaultsKey.suggestionTuningDefaultsVersion) == nil,
           hasStoredLevel,
           level == Self.previousDefaultSuggestionAggressivenessLevel {
            level = SuggestionTuning.defaultAggressivenessLevel
        }

        let storedTuningVersion = defaults.object(forKey: DefaultsKey.suggestionTuningDefaultsVersion) as? Int
        let shouldMigrateDailyDriverDefaults =
            (storedTuningVersion ?? 0) < Self.currentSuggestionTuningDefaultsVersion
        if shouldMigrateDailyDriverDefaults, level == 3 {
            level = SuggestionTuning.defaultAggressivenessLevel
        }

        var maxVisibleWords: Int
        if defaults.object(forKey: DefaultsKey.suggestionMaxVisibleWords) != nil {
            maxVisibleWords = defaults.integer(forKey: DefaultsKey.suggestionMaxVisibleWords)
        } else {
            maxVisibleWords = SuggestionTuning.defaultMaxVisibleWords
        }

        let wordStartCharacters = defaults.object(forKey: DefaultsKey.suggestionWordStartCharacters) != nil
            ? defaults.integer(forKey: DefaultsKey.suggestionWordStartCharacters)
            : SuggestionTuning.defaultWordStartCharacters
        var phraseStartWords = defaults.object(forKey: DefaultsKey.suggestionPhraseStartWords) != nil
            ? defaults.integer(forKey: DefaultsKey.suggestionPhraseStartWords)
            : SuggestionTuning.defaultPhraseStartWords
        var responseSpeedLevel = defaults.object(forKey: DefaultsKey.suggestionResponseSpeedLevel) != nil
            ? defaults.integer(forKey: DefaultsKey.suggestionResponseSpeedLevel)
            : SuggestionTuning.defaultResponseSpeedLevel
        var confidenceLevel = defaults.object(forKey: DefaultsKey.suggestionConfidenceLevel) != nil
            ? defaults.integer(forKey: DefaultsKey.suggestionConfidenceLevel)
            : SuggestionTuning.defaultConfidenceLevel
        var learningRestraintLevel = defaults.object(forKey: DefaultsKey.suggestionLearningRestraintLevel) != nil
            ? defaults.integer(forKey: DefaultsKey.suggestionLearningRestraintLevel)
            : SuggestionTuning.defaultLearningRestraintLevel

        if shouldMigrateDailyDriverDefaults {
            if maxVisibleWords == 3 || maxVisibleWords == 5 {
                maxVisibleWords = SuggestionTuning.defaultMaxVisibleWords
            }
            if phraseStartWords == 3 {
                phraseStartWords = SuggestionTuning.defaultPhraseStartWords
            }
            if responseSpeedLevel == 3 {
                responseSpeedLevel = SuggestionTuning.defaultResponseSpeedLevel
            }
            if confidenceLevel == 3 {
                confidenceLevel = SuggestionTuning.defaultConfidenceLevel
            }
            if learningRestraintLevel == 2 {
                learningRestraintLevel = SuggestionTuning.defaultLearningRestraintLevel
            }
        }

        suggestionTuning = SuggestionTuning(
            aggressivenessLevel: level,
            maxVisibleWords: maxVisibleWords,
            wordStartCharacters: wordStartCharacters,
            phraseStartWords: phraseStartWords,
            responseSpeedLevel: responseSpeedLevel,
            confidenceLevel: confidenceLevel,
            learningRestraintLevel: learningRestraintLevel
        )
        persistSuggestionTuning()
        defaults.set(
            Self.currentSuggestionTuningDefaultsVersion,
            forKey: DefaultsKey.suggestionTuningDefaultsVersion
        )
    }

    func loadVisiblePageContextEnabled() {
        visiblePageContextEnabled = defaults.bool(forKey: DefaultsKey.visiblePageContextEnabled)
    }

    func loadAcceptedAndKeptLearning() {
        guard let data = defaults.data(forKey: DefaultsKey.acceptedAndKeptLearning),
              let store = AcceptedAndKeptLearningStore(jsonData: data) else {
            acceptedAndKeptLearning = AcceptedAndKeptLearningStore()
            return
        }

        acceptedAndKeptLearning = store
    }

    func loadAcceptedTextStyleMemory() {
        guard let data = defaults.data(forKey: DefaultsKey.acceptedTextStyleMemory),
              let store = AcceptedTextStyleMemoryStore(jsonData: data) else {
            acceptedTextStyleMemory = AcceptedTextStyleMemoryStore()
            return
        }

        acceptedTextStyleMemory = store
    }
}
