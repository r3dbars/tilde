import Testing
@testable import AutocompleteLabApp

@Suite("Raw suggestion evaluation mode")
struct RawSuggestionEvaluationModeTests {
    @Test("Mode stays off unless explicitly enabled")
    func defaultsOff() {
        #expect(!RawSuggestionEvaluationMode(environment: [:]).isEnabled)
        #expect(!RawSuggestionEvaluationMode(environment: [
            RawSuggestionEvaluationMode.environmentKey: "false"
        ]).isEnabled)
    }

    @Test("Common affirmative values enable the mode")
    func parsesAffirmativeValues() {
        for value in ["1", "true", "YES", " on "] {
            #expect(RawSuggestionEvaluationMode(environment: [
                RawSuggestionEvaluationMode.environmentKey: value
            ]).isEnabled)
        }
    }
}
