import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion reveal delay")
struct SuggestionRevealDelayPolicyTests {
    @Test("Chromium browsers and Electron apps use calm marked text")
    func knownJumpyHostsUseCalmMarkedText() {
        #expect(SuggestionRevealDelayPolicy.requiresCalmMarkedText(
            bundleIdentifier: "com.google.Chrome.beta",
            hasElectronFramework: false
        ))
        #expect(SuggestionRevealDelayPolicy.requiresCalmMarkedText(
            bundleIdentifier: "com.example.editor",
            hasElectronFramework: true
        ))
        #expect(!SuggestionRevealDelayPolicy.requiresCalmMarkedText(
            bundleIdentifier: "com.apple.TextEdit",
            hasElectronFramework: false
        ))
    }

    @Test("The current grapheme selects native and calm reveal timing")
    func currentGraphemeSelectsDelay() {
        #expect(SuggestionRevealDelayPolicy.nanoseconds(
            afterUserTyped: "a",
            calmMarkedText: false
        ) == 10_000_000)
        #expect(SuggestionRevealDelayPolicy.nanoseconds(
            afterUserTyped: " ",
            calmMarkedText: false
        ) == 50_000_000)
        #expect(SuggestionRevealDelayPolicy.nanoseconds(
            afterUserTyped: "a",
            calmMarkedText: true
        ) == 120_000_000)
        #expect(SuggestionRevealDelayPolicy.nanoseconds(
            afterUserTyped: " ",
            calmMarkedText: true
        ) == 200_000_000)
    }

    @Test("Chromium and Electron start inference immediately and delay only reveal")
    func calmHostsDelayOnlyReveal() {
        let timing = SuggestionRevealDelayPolicy.schedule(
            afterUserTyped: " ",
            calmMarkedText: true
        )
        #expect(timing.inferenceDelayNanoseconds == 0)
        #expect(timing.revealDelayNanoseconds == 200_000_000)
    }
}
