import TildeCore
import Foundation
import Testing
@testable import TildeApp

@Suite("Screen Memory proof stimulus")
struct ScreenMemoryProofStimulusTests {
    @Test("The synthetic window classifies as a real conversation")
    func syntheticSceneClassifies() {
        let scene = ScreenMemoryProofStimulus.classifiedScene()
        #expect(scene.mode == .replying)
        #expect(scene.conversationTurns.count == 3)
        // Left/right geometry must produce both speakers, or the stimulus
        // would not exercise speaker bucketing.
        #expect(Set(scene.conversationTurns.map(\.speaker)).count == 2)
    }

    @Test("The stimulus prompt carries the conversation block")
    func promptCarriesScene() {
        let scene = ScreenMemoryProofStimulus.classifiedScene()
        let prompt = RawContinuationPrompt(
            textBeforeCursor: "Sure, I can send ",
            register: ContinuationRegister.following(scene: scene, hostBundleIdentifier: nil),
            scene: scene
        )
        #expect(prompt.prompt.contains("Conversation:"))
        #expect(prompt.prompt.contains("send the summary"))
    }

    @Test("The report is count-only: no synthetic sentence text is encoded")
    func reportCarriesNoText() throws {
        let report = ScreenMemoryProofStimulus.Report(
            schema: "tilde.release-proof-screen-memory-stimulus.v1",
            sceneMode: "replying", classifiedTurns: 3,
            promptContainsConversation: true, completionRan: true,
            completionCharacters: 12, redactionOutcome: "dropped-modelUnavailable",
            rawTextPersisted: false
        )
        let json = String(decoding: try JSONEncoder().encode(report), as: UTF8.self)
        #expect(!json.contains("summary"))
        #expect(!json.contains("meeting"))
        #expect(json.contains("dropped-modelUnavailable"))
    }
}
