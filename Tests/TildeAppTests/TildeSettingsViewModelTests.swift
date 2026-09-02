import Foundation
import Testing
@testable import TildeApp
@testable import TildeCore

/// The Settings model behind the Screen Memory covenant's mandatory master
/// toggle. There is no `AppDelegate` here — every use of it in the model is
/// optional-chained — and the settings store is a throwaway suite, so these
/// tests can never touch the owner's own daily driver.
@MainActor
@Suite("Tilde settings view model")
struct TildeSettingsViewModelTests {
    private func makeModel() -> (TildeSettingsViewModel, TildeSettings, UserDefaults) {
        let name = "tilde.tests.settings-view-model.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let settings = TildeSettings(keyboard: defaults)
        let model = TildeSettingsViewModel(
            appDelegate: nil,
            personalHistory: PersonalHistoryController(
                store: EmptyPersonalHistoryStore(),
                settings: settings
            ),
            settings: settings
        )
        return (model, settings, defaults)
    }

    @Test("Screen Memory starts on and the toggle can actually turn it off")
    func masterToggleTurnsScreenMemoryOff() {
        let (model, settings, defaults) = makeModel()

        // The covenant's default for a fresh install: on, with no key
        // written yet.
        #expect(model.screenMemoryEnabled)
        #expect(defaults.object(forKey: "ScreenMemoryEnabled") == nil)

        model.setScreenMemoryEnabled(false)

        // The published value, the shared settings store, and the key the
        // capture service reads all agree.
        #expect(!model.screenMemoryEnabled)
        #expect(!settings.screenMemoryEnabled)
        #expect(defaults.object(forKey: "ScreenMemoryEnabled") as? Bool == false)
    }

    @Test("An explicit off survives a rebuilt model, and turning it back on writes through")
    func explicitChoicePersists() {
        let name = "tilde.tests.settings-view-model.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let settings = TildeSettings(keyboard: defaults)
        func makeModel() -> TildeSettingsViewModel {
            TildeSettingsViewModel(
                appDelegate: nil,
                personalHistory: PersonalHistoryController(
                    store: EmptyPersonalHistoryStore(),
                    settings: settings
                ),
                settings: settings
            )
        }

        makeModel().setScreenMemoryEnabled(false)
        // A later launch reads the user's explicit choice, not the default.
        let reopened = makeModel()
        #expect(!reopened.screenMemoryEnabled)

        reopened.setScreenMemoryEnabled(true)
        #expect(reopened.screenMemoryEnabled)
        #expect(settings.screenMemoryEnabled)
        #expect(makeModel().screenMemoryEnabled)
    }

    @Test("Screen Memory off is reported as needing attention, like a missing permission")
    func offCountsAsScreenAccessAttention() {
        let (model, _, _) = makeModel()
        model.setScreenMemoryEnabled(false)
        #expect(model.screenAccessNeedsAttention)
    }

    /// The honest-copy rule: with Screen Memory off Tilde answers every
    /// completion request with silence (`ScreenMemoryStatus.disabled`), so
    /// the caption must not soften that into "fewer suggestions".
    @Test("Toggle copy says Tilde cannot see the reply context and stops suggesting")
    func copyStatesTheRealConsequence() {
        let (model, _, _) = makeModel()

        let onCopy = model.screenMemoryExplanation
        #expect(onCopy.contains("replying to"))
        #expect(onCopy.contains("stops suggesting"))
        #expect(onCopy.contains("this Mac"))

        model.setScreenMemoryEnabled(false)
        let offCopy = model.screenMemoryExplanation
        #expect(offCopy != onCopy)
        #expect(offCopy.contains("cannot see what you are replying to"))
        #expect(offCopy.contains("not suggesting anything"))
        #expect(
            !ScreenMemoryStatus.evaluate(enabled: false, permissionGranted: true)
                .allowsSuggestions
        )
    }

    @Test("Both accept keys are written down for the user")
    func acceptKeyCopyNamesBothKeys() {
        #expect(TildeAcceptKeys.wordShortcut == "Tab")
        #expect(TildeAcceptKeys.wholeSuggestionShortcut == "~")
        #expect(TildeAcceptKeys.summary.contains("Tab accepts the next word"))
        #expect(TildeAcceptKeys.summary.contains("accepts the whole suggestion"))
        #expect(TildeAcceptKeys.wholeSuggestionKeyDescription.contains("above Tab"))
        #expect(TildeAcceptKeys.readySummary.contains(TildeAcceptKeys.summary))
    }
}

/// The smallest store that satisfies the protocol: the view model only ever
/// asks it for a size, and nothing in these tests writes history.
private actor EmptyPersonalHistoryStore: PersonalHistoryStore {
    nonisolated let location = URL(fileURLWithPath: "/dev/null")

    func append(
        _ events: [PersonalHistoryEvent],
        checkpoint: PersonalNextWordStoredCheckpoint?
    ) async throws {}

    func loadReplay(maximumBytes: Int64) async throws -> PersonalHistoryReplay {
        PersonalHistoryReplay(events: [], checkpoint: nil)
    }

    func deleteAll() async throws {}

    func summary() async throws -> PersonalHistorySummary {
        PersonalHistorySummary(location: location, approximateBytes: 0)
    }
}
