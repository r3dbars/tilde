import Testing
@testable import TildeCore

@Suite("Scene echo policy")
struct SceneEchoPolicyTests {
    private let scene = ScreenScene.Scene(
        mode: .replying,
        conversationTurns: [
            .init(speaker: .other, text: "are you still coming or should I go without you?"),
            .init(speaker: .selfSpeaker, text: "still coming, just running a bit behind."),
        ],
        referenceSnippets: ["Invoice 4821 shows a $200 discrepancy versus our PO."]
    )

    @Test("A verbatim turn fragment is an echo")
    func turnFragmentIsEcho() {
        #expect(SceneEchoPolicy.isEcho("should I go without you", scene: scene))
        #expect(SceneEchoPolicy.isEcho("Are you still coming?", scene: scene))
        #expect(SceneEchoPolicy.isEcho("shows a $200 discrepancy versus", scene: scene))
    }

    @Test("Ordinary short reuse is not an echo")
    func shortReuseIsFine() {
        #expect(!SceneEchoPolicy.isEcho("still coming!", scene: scene))
        #expect(!SceneEchoPolicy.isEcho("ok", scene: scene))
        #expect(!SceneEchoPolicy.isEcho("running late, sorry — be there soon", scene: scene))
    }

    @Test("No scene, no echo")
    func nilScene() {
        #expect(!SceneEchoPolicy.isEcho("are you still coming or should I go", scene: nil))
    }
}
