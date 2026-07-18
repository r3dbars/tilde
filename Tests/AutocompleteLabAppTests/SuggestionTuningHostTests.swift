import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@MainActor
struct SuggestionTuningHostTests {
    @Test("persists tuning and clears visible suggestion state")
    func persistsTuningAndClearsVisibleSuggestionState() {
        var tuning = SuggestionTuning()
        var persistCount = 0
        var clearCount = 0
        var hiddenReasons: [String] = []
        var decisions: [String] = []
        var refreshCount = 0
        let host = SuggestionTuningHost(
            currentTuning: { tuning },
            updateTuning: { tuning = $0 },
            persistTuning: { persistCount += 1 },
            clearPendingRequest: { clearCount += 1 },
            hasVisibleSuggestion: { true },
            hideSuggestion: { hiddenReasons.append($0) },
            setSuggestionDecision: { decisions.append($0) },
            refreshRuntimeChrome: { refreshCount += 1 }
        )

        host.setMaxVisibleWords(4)

        #expect(tuning.maxVisibleWords == 4)
        #expect(persistCount == 1)
        #expect(clearCount == 1)
        #expect(hiddenReasons == ["max-visible-words-changed"])
        #expect(decisions == ["Ready: \(tuning.displayName.lowercased()) suggestions"])
        #expect(refreshCount == 1)
    }

    @Test("does not persist an unchanged tuning value")
    func doesNotPersistAnUnchangedTuningValue() {
        let tuning = SuggestionTuning()
        var persistCount = 0
        var refreshCount = 0
        let host = SuggestionTuningHost(
            currentTuning: { tuning },
            updateTuning: { _ in },
            persistTuning: { persistCount += 1 },
            clearPendingRequest: {},
            hasVisibleSuggestion: { false },
            hideSuggestion: { _ in },
            setSuggestionDecision: { _ in },
            refreshRuntimeChrome: { refreshCount += 1 }
        )

        host.reset()

        #expect(persistCount == 0)
        #expect(refreshCount == 1)
    }
}
