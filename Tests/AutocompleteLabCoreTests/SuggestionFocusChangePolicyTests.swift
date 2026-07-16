import Testing
@testable import AutocompleteLabCore
@testable import AutocompleteLabResearch

@Suite("Suggestion focus change policy")
struct SuggestionFocusChangePolicyTests {
    private let policy = SuggestionFocusChangePolicy()

    @Test("Keeps suggestions when the active app has not changed")
    func keepsSuggestionForSameApp() {
        #expect(!policy.shouldHideVisibleSuggestion(
            visibleSuggestionBundleIdentifier: "com.apple.TextEdit",
            activatedBundleIdentifier: "com.apple.TextEdit"
        ))
    }

    @Test("Hides suggestions when another app becomes active")
    func hidesSuggestionForDifferentApp() {
        #expect(policy.shouldHideVisibleSuggestion(
            visibleSuggestionBundleIdentifier: "com.apple.TextEdit",
            activatedBundleIdentifier: "com.apple.Notes"
        ))
    }

    @Test("Hides suggestions when activation lacks a bundle identifier")
    func hidesSuggestionWhenActivatedBundleIsUnknown() {
        #expect(policy.shouldHideVisibleSuggestion(
            visibleSuggestionBundleIdentifier: "com.apple.TextEdit",
            activatedBundleIdentifier: nil
        ))
    }

    @Test("Does nothing when no suggestion app is visible")
    func doesNothingWithoutVisibleSuggestionApp() {
        #expect(!policy.shouldHideVisibleSuggestion(
            visibleSuggestionBundleIdentifier: nil,
            activatedBundleIdentifier: "com.apple.TextEdit"
        ))
        #expect(!policy.shouldHideVisibleSuggestion(
            visibleSuggestionBundleIdentifier: " ",
            activatedBundleIdentifier: "com.apple.TextEdit"
        ))
    }
}
