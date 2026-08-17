import AutocompleteLabCore
import Testing
@testable import AutocompleteLabApp

@Suite("Intent future cache")
struct IntentFutureCacheTests {
    private func scene(_ text: String) -> ScreenScene.Scene {
        .init(
            mode: .replying,
            conversationTurns: [.init(speaker: .other, text: text)],
            referenceSnippets: []
        )
    }

    @Test("Same scene keeps its original prior while live text changes")
    func reusesPrior() {
        let cache = IntentFutureCache()
        let s = scene("Can you send it tonight?")
        let first = cache.futures(scene: s, textBeforeCursor: "Yep ")
        let second = cache.futures(scene: s, textBeforeCursor: "Which ")
        #expect(first.first?.kind == .accept)
        #expect(second.first?.kind == .clarify)
    }

    @Test("Changing scenes replaces the cached prior")
    func sceneChangeReplacesPrior() {
        let cache = IntentFutureCache()
        _ = cache.futures(scene: scene("Can you send it tonight?"), textBeforeCursor: "")
        let changed = cache.futures(
            scene: scene("What do you think about delaying launch?"),
            textBeforeCursor: "I think "
        )
        #expect(changed.first?.kind == .answer)
    }
}
