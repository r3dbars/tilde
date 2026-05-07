import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion presentation policy")
struct SuggestionPresentationPolicyTests {
    @Test("Chooses primary render mode and mirror fallback from capabilities")
    func choosesPrimaryRenderModeAndMirrorFallbackFromCapabilities() throws {
        let policy = SuggestionPresentationPolicy()
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let mail = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.mail"))

        #expect(policy.baseRenderMode(
            for: textEdit,
            capabilities: SuggestionPresentationCapabilities(
                supportsInlineSuggestions: true,
                hasElementRect: true,
                hasWindowRect: false,
                hasCaretRect: true
            )
        ) == .inlineAdjacent)
        #expect(policy.baseRenderMode(
            for: textEdit,
            capabilities: SuggestionPresentationCapabilities(
                supportsInlineSuggestions: false,
                hasElementRect: true,
                hasWindowRect: false,
                hasCaretRect: false
            )
        ) == .floatingMirror)
        #expect(policy.baseRenderMode(
            for: mail,
            capabilities: SuggestionPresentationCapabilities(
                supportsInlineSuggestions: true,
                hasElementRect: true,
                hasWindowRect: false,
                hasCaretRect: true
            )
        ) == nil)
    }

    @Test("Suppresses detached mirror placement only when profile disallows it")
    func suppressesDetachedMirrorPlacementOnlyWhenProfileDisallowsIt() throws {
        let policy = SuggestionPresentationPolicy()
        let obsidian = try #require(CompatibilityProfileStore.mvp.profile(for: "md.obsidian"))
        let chrome = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))

        let detachedMirror = SuggestionPresentationCapabilities(
            supportsInlineSuggestions: false,
            hasElementRect: true,
            hasWindowRect: false,
            hasCaretRect: false
        )
        let caretBoundMirror = SuggestionPresentationCapabilities(
            supportsInlineSuggestions: false,
            hasElementRect: true,
            hasWindowRect: false,
            hasCaretRect: true
        )

        #expect(policy.suppressionReason(
            profile: obsidian,
            renderMode: .floatingMirror,
            capabilities: detachedMirror
        ) == .detachedSuggestionDisabled)
        #expect(policy.suppressionReason(
            profile: obsidian,
            renderMode: .floatingMirror,
            capabilities: caretBoundMirror
        ) == nil)
        #expect(policy.suppressionReason(
            profile: obsidian,
            renderMode: .inlineAdjacent,
            capabilities: detachedMirror
        ) == nil)
        #expect(policy.suppressionReason(
            profile: chrome,
            renderMode: .floatingMirror,
            capabilities: detachedMirror
        ) == nil)
    }
}
