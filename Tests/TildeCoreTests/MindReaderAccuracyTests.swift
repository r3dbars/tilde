import TildeCore
import Foundation
import Testing

@Suite("Mind-reader accuracy optimizations")
struct MindReaderAccuracyTests {
    @Test("DecodeBiasPolicy extracts salient scene terms, prioritizes newest other turn, scrubs secrets, and excludes trailing typed echo")
    func sceneTermExtraction() {
        let scene = ScreenScene.Scene(
            mode: .replying,
            conversationTurns: [
                .init(speaker: .other, text: "Earlier we talked about PostgreSQL migrations"),
                .init(speaker: .selfSpeaker, text: "Got it"),
                .init(speaker: .other, text: "Can we ship Kubernetes on Thursday? My token is sk-1234567890abcdef1234567890abcdef"),
            ],
            referenceSnippets: ["Release checklist for Terraform"]
        )
        let typed = PreparedTypedContext(textBeforeCursor: "Yes let's ship Kubernetes ")
        let terms = DecodeBiasPolicy.extractSceneTerms(scene: scene, typed: typed)
        let lowered = Set(terms.map { $0.term.lowercased() })

        // "Kubernetes" is in trailing typed context -> excluded to prevent immediate echo.
        #expect(!lowered.contains("kubernetes"))
        // Newest other turn term "Thursday" is present with highest weight.
        let thursday = terms.first { $0.term.lowercased() == "thursday" }
        #expect(thursday != nil)
        #expect(thursday?.weight == DecodeBiasPolicy.latestOtherTurnWeight)
        // Earlier turn and reference snippet terms included with lower weights.
        let postgres = terms.first { $0.term.lowercased() == "postgresql" }
        #expect(postgres != nil)
        #expect(postgres!.weight < thursday!.weight)
        #expect(lowered.contains("terraform"))
        // Secret scrubbed — raw token AND redaction placeholder never enter bias terms.
        #expect(!terms.contains { $0.term.lowercased().contains("sk-123456") })
        #expect(!terms.contains { $0.term.lowercased().contains("redacted") })
    }

    @Test("DecodeBiasPolicy excludes active mid-word prefixes and digit-leading terms")
    func excludesMidWordPrefixAndDigits() {
        let scene = ScreenScene.Scene(
            mode: .replying,
            conversationTurns: [.init(speaker: .other, text: "Can we ship Kubernetes at 10am on Thursday?")],
            referenceSnippets: []
        )
        let midWordTyped = PreparedTypedContext(textBeforeCursor: "Yes let's ship Kube")
        let terms = DecodeBiasPolicy.extractSceneTerms(scene: scene, typed: midWordTyped)
        let lowered = Set(terms.map { $0.term.lowercased() })
        // "Kubernetes" starts with active partial "kube" -> excluded so leading-space bias never causes "Kube Kubernetes".
        #expect(!lowered.contains("kubernetes"))
        // "10am" starts with a digit -> excluded so BPE space token is never biased.
        #expect(!lowered.contains("10am"))
        #expect(lowered.contains("thursday"))
    }

    @Test("DecodeBiasPolicy merges scene and personal terms deterministically and clamps bias")
    func mergeAndClamp() {
        let scene = [
            WeightedBiasTerm(term: "Thursday", weight: 1.35),
            WeightedBiasTerm(term: "Kubernetes", weight: 5.0),
        ]
        let personal = [
            WeightedBiasTerm(term: "thursday", weight: 0.50),
            WeightedBiasTerm(term: "Transcripted", weight: 0.65),
        ]
        let merged = DecodeBiasPolicy.merge(scene: scene, personal: personal, maxTerms: 3, maxBias: 1.6)
        #expect(merged.count == 3)
        #expect(merged[0].term == "Kubernetes")
        #expect(merged[0].weight == 1.6)
        #expect(merged[1].term == "Thursday")
        #expect(merged[1].weight == 1.35)
        #expect(merged[2].term == "Transcripted")
        #expect(merged[2].weight == 0.65)
    }

    @Test("DecodeBiasPolicy trims repeated nudged content words without harming short function words")
    func trimRepeatedContentWord() {
        #expect(
            DecodeBiasPolicy.trimRepeatedContentWord(" on Thursday at Thursday afternoon")
                == " on Thursday at"
        )
        // Function words ("to", "the") are allowed to repeat legitimately.
        #expect(
            DecodeBiasPolicy.trimRepeatedContentWord(" go to the store to buy")
                == " go to the store to buy"
        )
    }

    @Test("PersonalVoiceScaffoldBuilder keeps only fact-free typed sentences and rejects proper nouns, numbers, and secrets")
    func personalVoiceScaffoldFiltering() {
        let now: Int64 = 1_760_000_000_000
        let events: [PersonalHistoryEvent] = [
            // Clean fact-free chat sentences (4 examples -> meets minimum of 3)
            PersonalHistoryEvent(
                id: "e1", timestampMilliseconds: now,
                historyIdentifier: "h1", consentIdentifier: "c1", sessionIdentifier: "s1",
                appBundleIdentifier: "com.tinyspeck.slackmacgap", source: .typed,
                text: "honestly this approach feels way cleaner and should work really well."
            )!,
            PersonalHistoryEvent(
                id: "e2", timestampMilliseconds: now + 1,
                historyIdentifier: "h1", consentIdentifier: "c1", sessionIdentifier: "s1",
                appBundleIdentifier: "com.tinyspeck.slackmacgap", source: .typed,
                text: "sounds good to me and I will take a look right after."
            )!,
            PersonalHistoryEvent(
                id: "e3", timestampMilliseconds: now + 2,
                historyIdentifier: "h1", consentIdentifier: "c1", sessionIdentifier: "s1",
                appBundleIdentifier: "com.tinyspeck.slackmacgap", source: .typed,
                text: "let me double check that detail before we ship anything out today."
            )!,
            PersonalHistoryEvent(
                id: "e4", timestampMilliseconds: now + 3,
                historyIdentifier: "h1", consentIdentifier: "c1", sessionIdentifier: "s1",
                appBundleIdentifier: "com.tinyspeck.slackmacgap", source: .typed,
                text: "totally agree we should keep this super simple and easy to read."
            )!,
            // Must be rejected: proper noun mid-sentence
            PersonalHistoryEvent(
                id: "e5", timestampMilliseconds: now + 4,
                historyIdentifier: "h1", consentIdentifier: "c1", sessionIdentifier: "s1",
                appBundleIdentifier: "com.tinyspeck.slackmacgap", source: .typed,
                text: "please ask Sarah to review the document before lunch arrives today."
            )!,
            // Must be rejected: contains digits
            PersonalHistoryEvent(
                id: "e6", timestampMilliseconds: now + 5,
                historyIdentifier: "h1", consentIdentifier: "c1", sessionIdentifier: "s1",
                appBundleIdentifier: "com.tinyspeck.slackmacgap", source: .typed,
                text: "let us meet at 4pm to talk through the whole plan together."
            )!,
            // Must be rejected: accepted suggestion (not typed)
            PersonalHistoryEvent(
                id: "e7", timestampMilliseconds: now + 6,
                historyIdentifier: "h1", consentIdentifier: "c1", sessionIdentifier: "s1",
                appBundleIdentifier: "com.tinyspeck.slackmacgap", source: .acceptedSuggestion,
                text: "this accepted suggestion should never be trained back into the voice scaffold."
            )!,
        ]

        let set = PersonalVoiceScaffoldBuilder.build(from: events)
        let chat = set.scaffold(for: .chat)
        #expect(chat != nil)
        #expect(chat?.contains("Sarah") == false)
        #expect(chat?.contains("4pm") == false)
        #expect(chat?.contains("accepted suggestion") == false)
        #expect(chat?.contains("Text:") == true)
        #expect(chat?.contains("Continuation:") == true)
        // Prose had 0 examples -> falls back to nil (stock scaffold).
        #expect(set.scaffold(for: .prose) == nil)
    }

    @Test("RawContinuationPrompt customScaffold stays byte-identical between prewarmPrefix and live prompt")
    func customScaffoldPrewarmParity() {
        let custom = "Custom header\n\nText: sounds good to\nContinuation: me right now.\n\n\n"
        let scene = ScreenScene.Scene(
            mode: .replying,
            conversationTurns: [.init(speaker: .other, text: "Want to sync later?")],
            referenceSnippets: []
        )
        let prewarm = RawContinuationPrompt.prewarmPrefix(
            register: .chat,
            scene: scene,
            customScaffold: custom
        )
        let live = RawContinuationPrompt(
            textBeforeCursor: "yeah sounds ",
            register: .chat,
            scene: scene,
            customScaffold: custom
        )
        #expect(live.prompt.hasPrefix(prewarm))
    }

    @Test("WordConfidenceTruncator keeps confident multi-word phrases and trims collapsing tail words")
    func wordConfidenceTruncation() {
        // Confident 3-word phrase stays intact.
        let strongSuggestion = CompletionSuggestion(text: " works for me", maxVisibleWords: 3)
        let strongTokens = [
            StreamedTokenProbability(piece: " works", probability: 0.72),
            StreamedTokenProbability(piece: " for", probability: 0.81),
            StreamedTokenProbability(piece: " me", probability: 0.85),
        ]
        let kept = WordConfidenceTruncator.trim(suggestion: strongSuggestion, tokens: strongTokens)
        #expect(kept.visibleText == " works for me")

        // Shaky 3rd word collapses -> trimmed cleanly back to 2 words.
        let shakyTailSuggestion = CompletionSuggestion(text: " works great purple", maxVisibleWords: 3)
        let shakyTailTokens = [
            StreamedTokenProbability(piece: " works", probability: 0.82),
            StreamedTokenProbability(piece: " great", probability: 0.78),
            StreamedTokenProbability(piece: " purple", probability: 0.01),
        ]
        let trimmed = WordConfidenceTruncator.trim(
            suggestion: shakyTailSuggestion,
            tokens: shakyTailTokens,
            temperature: 2.0,
            riskPenalty: 3.0
        )
        #expect(trimmed.visibleText == " works great")

        // Empty token probabilities fail open cleanly.
        let failOpen = WordConfidenceTruncator.trim(suggestion: strongSuggestion, tokens: [])
        #expect(failOpen.visibleText == " works for me")
    }

    @Test("PersonalNextWordShadow.topBiasTerms is read-only and returns high-support personal terms")
    func personalBiasTermsReadOnly() {
        var shadow = PersonalNextWordShadow()
        let base: Int64 = 1_760_000_000_000
        let events = (0..<5).map { idx in
            PersonalHistoryEvent(
                id: "ev-\(idx)",
                timestampMilliseconds: base + Int64(idx * 1_000),
                historyIdentifier: "h1",
                consentIdentifier: "c1",
                sessionIdentifier: "s1",
                appBundleIdentifier: "com.tinyspeck.slackmacgap",
                source: .typed,
                text: "check transcripted pipeline today "
            )!
        }
        shadow.consume(events, scoring: false)
        let snapshotBefore = shadow.snapshot
        let terms = shadow.topBiasTerms(afterTailWords: ["check"], limit: 5)
        #expect(shadow.snapshot == snapshotBefore)
        #expect(terms.contains { $0.term.lowercased() == "transcripted" })
    }
}
