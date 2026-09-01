import TildeCore
import Testing
@testable import TildeApp

/// The 9B preview carries the owner-directed scene changes; every other
/// profile keeps the measured production prompt and gate byte for byte.
@Suite("Profile scene options")
struct ProfileSceneOptionsTests {
    @Test("Production and the other previews keep the measured gate and prompt")
    func productionIsUnchanged() {
        for profile in [TildeProductProfile.production, .preview26B, .modelPreview] {
            #expect(profile.sceneSuggestionOptions == .production)
            #expect(!profile.includesWindowTitleInScene)
        }
    }

    @Test("The 9B preview anchors the reply cue and includes the window title")
    func preview9BCarriesTheChanges() {
        #expect(TildeProductProfile.preview9B.sceneSuggestionOptions.replyCueAnchoredToCurrentSentence)
        #expect(!TildeProductProfile.preview9B.sceneSuggestionOptions.extendedOrdinarySilenceGate)
        #expect(TildeProductProfile.preview9B.includesWindowTitleInScene)
    }
}
