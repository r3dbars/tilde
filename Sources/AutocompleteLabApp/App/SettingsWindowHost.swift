import Foundation
import AutocompleteLabCore

enum SettingsWindowAction {
    case requestPermission
    case openAccessibilitySettings
    case toggleSuggestionsPaused
    case pauseSuggestionsFor15Minutes
    case pauseSuggestionsFor1Hour
    case pauseSuggestionsUntilTomorrow
    case silenceCurrentField
    case performRuntimeAction(RuntimeReadinessAction)
    case toggleCurrentApp
    case toggleCurrentAppMirrorMode
    case startCurrentAppProof
    case startTextEditPractice
    case enableAllApps
    case toggleTracingPaused
    case toggleRawContentTracing
    case toggleScreenshotTracing
    case toggleVisiblePageContext
    case deleteLocalLogs
    case clearLearningData
    case exportPrivacyBundle
    case cycleAcceptAllShortcut
    case setAcceptAllShortcut(AcceptAllShortcut)
    case setSuggestionAggressivenessLevel(Int)
    case setSuggestionMaxVisibleWords(Int)
    case setSuggestionWordStartCharacters(Int)
    case setSuggestionPhraseStartWords(Int)
    case setSuggestionResponseSpeedLevel(Int)
    case setSuggestionConfidenceLevel(Int)
    case setSuggestionLearningRestraintLevel(Int)
    case resetSuggestionTuning
}

@MainActor
protocol SettingsWindowActionHandling: AnyObject {
    func handleSettingsWindowAction(_ action: SettingsWindowAction)
}

/// Owns SettingsWindowController construction and translates UI callbacks into one
/// app action surface. AppDelegate keeps the product decisions; this host keeps the
/// launch/UI wiring out of the application coordinator.
@MainActor
final class SettingsWindowHost {
    private weak var handler: (any SettingsWindowActionHandling)?

    lazy var controller = SettingsWindowController(
        requestPermission: { [weak self] in
            self?.send(.requestPermission)
        },
        openAccessibilitySettings: { [weak self] in
            self?.send(.openAccessibilitySettings)
        },
        toggleSuggestionsPaused: { [weak self] in
            self?.send(.toggleSuggestionsPaused)
        },
        pauseSuggestionsFor15Minutes: { [weak self] in
            self?.send(.pauseSuggestionsFor15Minutes)
        },
        pauseSuggestionsFor1Hour: { [weak self] in
            self?.send(.pauseSuggestionsFor1Hour)
        },
        pauseSuggestionsUntilTomorrow: { [weak self] in
            self?.send(.pauseSuggestionsUntilTomorrow)
        },
        silenceCurrentField: { [weak self] in
            self?.send(.silenceCurrentField)
        },
        performRuntimeAction: { [weak self] action in
            self?.send(.performRuntimeAction(action))
        },
        toggleCurrentApp: { [weak self] in
            self?.send(.toggleCurrentApp)
        },
        toggleCurrentAppMirrorMode: { [weak self] in
            self?.send(.toggleCurrentAppMirrorMode)
        },
        startCurrentAppProof: { [weak self] in
            self?.send(.startCurrentAppProof)
        },
        startTextEditPractice: { [weak self] in
            self?.send(.startTextEditPractice)
        },
        enableAllApps: { [weak self] in
            self?.send(.enableAllApps)
        },
        toggleTracingPaused: { [weak self] in
            self?.send(.toggleTracingPaused)
        },
        toggleRawContentTracing: { [weak self] in
            self?.send(.toggleRawContentTracing)
        },
        toggleScreenshotTracing: { [weak self] in
            self?.send(.toggleScreenshotTracing)
        },
        toggleVisiblePageContext: { [weak self] in
            self?.send(.toggleVisiblePageContext)
        },
        deleteLocalLogs: { [weak self] in
            self?.send(.deleteLocalLogs)
        },
        clearLearningData: { [weak self] in
            self?.send(.clearLearningData)
        },
        exportPrivacyBundle: { [weak self] in
            self?.send(.exportPrivacyBundle)
        },
        cycleAcceptAllShortcut: { [weak self] in
            self?.send(.cycleAcceptAllShortcut)
        },
        setAcceptAllShortcut: { [weak self] shortcut in
            self?.send(.setAcceptAllShortcut(shortcut))
        },
        setSuggestionAggressivenessLevel: { [weak self] level in
            self?.send(.setSuggestionAggressivenessLevel(level))
        },
        setSuggestionMaxVisibleWords: { [weak self] words in
            self?.send(.setSuggestionMaxVisibleWords(words))
        },
        setSuggestionWordStartCharacters: { [weak self] characters in
            self?.send(.setSuggestionWordStartCharacters(characters))
        },
        setSuggestionPhraseStartWords: { [weak self] words in
            self?.send(.setSuggestionPhraseStartWords(words))
        },
        setSuggestionResponseSpeedLevel: { [weak self] level in
            self?.send(.setSuggestionResponseSpeedLevel(level))
        },
        setSuggestionConfidenceLevel: { [weak self] level in
            self?.send(.setSuggestionConfidenceLevel(level))
        },
        setSuggestionLearningRestraintLevel: { [weak self] level in
            self?.send(.setSuggestionLearningRestraintLevel(level))
        },
        resetSuggestionTuning: { [weak self] in
            self?.send(.resetSuggestionTuning)
        }
    )

    init(handler: any SettingsWindowActionHandling) {
        self.handler = handler
    }

    private func send(_ action: SettingsWindowAction) {
        handler?.handleSettingsWindowAction(action)
    }
}
