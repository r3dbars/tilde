import Foundation
import Testing
@testable import TildeCore

@Suite("Latency optimization core invariants")
struct LatencyOptimizationTests {
    @Test("Scene prewarm prefix is a byte-identical prefix of live prompts across the first quantum")
    func prewarmPrefixMatchesLivePrompt() {
        let scene = ScreenScene.Scene(
            mode: .replying,
            conversationTurns: [
                .init(speaker: .other, text: "are we still on for the planning sync tomorrow?"),
                .init(speaker: .selfSpeaker, text: "yes, still on"),
                .init(speaker: .other, text: "awesome, can you share the notes ahead of time?"),
            ],
            referenceSnippets: [],
            windowTitle: "Team Sync"
        )
        let prefix = RawContinuationPrompt.prewarmPrefix(
            register: .chat,
            scene: scene,
            includesWindowTitle: true
        )
        #expect(prefix.contains("Conversation:"))
        #expect(prefix.contains(#"{"window":"Team Sync"}"#))

        for typed in ["Sure ", "Sure, I can send ", String(repeating: "word ", count: 40)] {
            let live = RawContinuationPrompt(
                textBeforeCursor: typed,
                register: .chat,
                scene: scene,
                includesWindowTitle: true
            )
            #expect(live.prompt.hasPrefix(prefix))
        }
    }

    @Test("Nil scene prewarm prefix falls back to the bare register scaffold")
    func nilScenePrewarmPrefixIsBareScaffold() {
        #expect(
            RawContinuationPrompt.prewarmPrefix(register: .email, scene: nil)
                == RawContinuationPrompt.scaffold(for: .email)
        )
        #expect(
            RawContinuationPrompt.prewarmPrefix(register: .prose, scene: nil)
                == RawContinuationPrompt.scaffold(for: .prose)
        )
    }

    @Test("Speculative chain key projects identical context across word-by-word Tab accepts and final consume")
    func speculativeChainKeyMatchesAtConsume() {
        // User has "That " typed, ghost is "sounds really good".
        // Tab #1 accepts "sounds ", remainder is "really good".
        let projectedAtTab1 = SpeculativeChainKey.projectedContext(
            beforeAccept: "That ",
            accepted: "sounds ",
            remainder: "really good",
            utf16Limit: 3_000
        )
        // Tab #2 accepts "really ", remainder is "good".
        let projectedAtTab2 = SpeculativeChainKey.projectedContext(
            beforeAccept: "That sounds ",
            accepted: "really ",
            remainder: "good",
            utf16Limit: 3_000
        )
        // Tab #3 accepts "good ", remainder is "" (consumed).
        let projectedAtConsume = SpeculativeChainKey.projectedContext(
            beforeAccept: "That sounds really ",
            accepted: "good ",
            remainder: "",
            utf16Limit: 3_000
        )

        #expect(projectedAtTab1 == "That sounds really good ")
        #expect(projectedAtTab2 == projectedAtTab1)
        #expect(projectedAtConsume == projectedAtTab1)

        let key1 = SpeculativeChainKey(
            clientIdentifier: "session-1",
            bundleIdentifier: "com.apple.Notes",
            context: projectedAtTab1
        )
        let keyConsume = SpeculativeChainKey(
            clientIdentifier: "session-1",
            bundleIdentifier: "com.apple.Notes",
            context: projectedAtConsume
        )
        let keyWrongBundle = SpeculativeChainKey(
            clientIdentifier: "session-1",
            bundleIdentifier: "com.apple.mail",
            context: projectedAtConsume
        )
        #expect(key1 == keyConsume)
        #expect(key1 != keyWrongBundle)
    }

    @Test("Projected context mirrors quantized stableWindowStart across the 3,000-char boundary")
    func projectedContextMatchesQuantizedWindow() {
        let fullDocBefore = String(repeating: "a", count: 2_998)
        let accepted = "word "
        let projected = SpeculativeChainKey.projectedContext(
            beforeAccept: fullDocBefore,
            accepted: accepted,
            remainder: "",
            utf16Limit: 3_000,
            selectionLocation: 2_998
        )
        let fullDocAfter = fullDocBefore + accepted
        let liveStart = RawContinuationPrompt.stableWindowStart(end: fullDocAfter.utf16.count, limit: 3_000)
        let liveRead = (fullDocAfter as NSString).substring(from: liveStart)
        #expect(projected == liveRead)
    }
}
