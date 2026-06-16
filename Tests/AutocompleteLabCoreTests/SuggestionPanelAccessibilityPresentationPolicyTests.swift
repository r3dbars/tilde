import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion panel accessibility presentation policy")
struct SuggestionPanelAccessibilityPresentationPolicyTests {
    @Test("Default: fades in and uses translucent material when no prefs are set")
    func defaultPresentation() {
        let presentation = SuggestionPanelAccessibilityPresentationPolicy.resolve(
            reduceMotion: false,
            reduceTransparency: false
        )

        #expect(presentation.firstAppearanceFadeDuration
            == SuggestionPanelAccessibilityPresentationPolicy.defaultFirstAppearanceFadeDuration)
        #expect(presentation.firstAppearanceFadeDuration > 0)
        #expect(presentation.animatesFirstAppearance)
        #expect(presentation.background == .translucentMaterial)
    }

    @Test("Reduce Motion: snaps in with no fade but keeps the translucent material")
    func reduceMotionSnapsIn() {
        let presentation = SuggestionPanelAccessibilityPresentationPolicy.resolve(
            reduceMotion: true,
            reduceTransparency: false
        )

        #expect(presentation.firstAppearanceFadeDuration == 0)
        #expect(!presentation.animatesFirstAppearance)
        #expect(presentation.background == .translucentMaterial)
    }

    @Test("Reduce Transparency: uses a solid background but keeps the fade")
    func reduceTransparencyUsesSolidBackground() {
        let presentation = SuggestionPanelAccessibilityPresentationPolicy.resolve(
            reduceMotion: false,
            reduceTransparency: true
        )

        #expect(presentation.background == .solid)
        #expect(presentation.firstAppearanceFadeDuration
            == SuggestionPanelAccessibilityPresentationPolicy.defaultFirstAppearanceFadeDuration)
        #expect(presentation.animatesFirstAppearance)
    }

    @Test("Both prefs: snaps in and uses a solid background")
    func bothPreferences() {
        let presentation = SuggestionPanelAccessibilityPresentationPolicy.resolve(
            reduceMotion: true,
            reduceTransparency: true
        )

        #expect(presentation.firstAppearanceFadeDuration == 0)
        #expect(!presentation.animatesFirstAppearance)
        #expect(presentation.background == .solid)
    }

    @Test("The two preferences are decided independently")
    func preferencesAreIndependent() {
        // Motion controls only the fade; transparency controls only the background.
        let motionOnly = SuggestionPanelAccessibilityPresentationPolicy.resolve(
            reduceMotion: true,
            reduceTransparency: false
        )
        let transparencyOnly = SuggestionPanelAccessibilityPresentationPolicy.resolve(
            reduceMotion: false,
            reduceTransparency: true
        )

        #expect(motionOnly.background == .translucentMaterial)
        #expect(transparencyOnly.animatesFirstAppearance)
        #expect(motionOnly.firstAppearanceFadeDuration != transparencyOnly.firstAppearanceFadeDuration)
        #expect(motionOnly.background != transparencyOnly.background)
    }
}
