import Testing
@testable import AutocompleteLabApp

@Suite("Tilde settings presentation")
struct TildeSettingsPresentationTests {
    @Test("Main settings use short, calm status language")
    func simpleStatusCopy() {
        #expect(TildeSettingsPresentation.simpleStatusText(for: "Tilde is Ready") == "Ready")
        #expect(TildeSettingsPresentation.simpleStatusText(for: "Tilde is Paused") == "Paused")
        #expect(TildeSettingsPresentation.simpleStatusText(for: "Model is Loading") == "Getting ready…")
        #expect(TildeSettingsPresentation.simpleStatusText(for: "Tilde Needs Attention") == "Needs attention")
    }
}
