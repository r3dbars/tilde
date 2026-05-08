import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Accepted and kept learning")
struct AcceptedAndKeptLearningTests {
    @Test("Starts from mode-specific priors without evidence")
    func startsFromModeSpecificPriors() {
        let store = AcceptedAndKeptLearningStore()

        let wordSignal = store.signal(for: key(mode: .wordCompletion))
        let phraseSignal = store.signal(for: key(mode: .phraseContinuation))
        let sentenceSignal = store.signal(for: key(mode: .sentenceContinuation))

        #expect(wordSignal.sampleCount == 0)
        #expect(wordSignal.probability == 0.42)
        #expect(phraseSignal.probability == 0.34)
        #expect(sentenceSignal.probability == 0.28)
        #expect(wordSignal.userAffinityAdjustment == 0)
    }

    @Test("Kept and rejected outcomes move probability and affinity")
    func outcomesMoveProbabilityAndAffinity() {
        var store = AcceptedAndKeptLearningStore(priorWeight: 2)
        let learningKey = key(mode: .phraseContinuation)
        let now = Date(timeIntervalSince1970: 1_000)

        _ = store.record(.kept, key: learningKey, now: now)
        _ = store.record(.kept, key: learningKey, now: now)
        let positive = store.signal(for: learningKey, now: now)

        #expect(positive.sampleCount == 2)
        #expect(positive.keptCount == 2)
        #expect(positive.rejectedCount == 0)
        #expect(positive.probability > positive.priorProbability)
        #expect(positive.userAffinityAdjustment > 0)
        #expect(positive.utilityAdjustment > 0)

        _ = store.record(.rejected, key: learningKey, now: now)
        _ = store.record(.rejected, key: learningKey, now: now)
        _ = store.record(.rejected, key: learningKey, now: now)
        _ = store.record(.rejected, key: learningKey, now: now)
        let negative = store.signal(for: learningKey, now: now)

        #expect(negative.sampleCount == 6)
        #expect(negative.rejectedCount == 4)
        #expect(negative.probability < negative.priorProbability)
        #expect(negative.userAffinityAdjustment < 0)
        #expect(negative.utilityAdjustment < 0)
        #expect(negative.traceMetadata["acceptedAndKeptSamples"] == "6")
        #expect(negative.traceMetadata["acceptedAndKeptUtilityAdjustment"] != nil)
    }

    @Test("Buckets are scoped by app field mode and behavior profile")
    func bucketsAreScopedByAppFieldModeAndBehaviorProfile() {
        var store = AcceptedAndKeptLearningStore(priorWeight: 1)
        let docsKey = key(mode: .phraseContinuation, behaviorProfileID: .docsProse)
        let chatKey = key(mode: .phraseContinuation, behaviorProfileID: .aiChat)

        _ = store.record(.kept, key: docsKey)
        _ = store.record(.rejected, key: chatKey)

        #expect(store.signal(for: docsKey).keptCount == 1)
        #expect(store.signal(for: docsKey).rejectedCount == 0)
        #expect(store.signal(for: chatKey).keptCount == 0)
        #expect(store.signal(for: chatKey).rejectedCount == 1)
    }

    @Test("Learning store persists and restores buckets")
    func learningStorePersistsAndRestoresBuckets() throws {
        var store = AcceptedAndKeptLearningStore(priorWeight: 2)
        let learningKey = key(mode: .sentenceContinuation)
        let now = Date(timeIntervalSince1970: 2_000)

        _ = store.record(.kept, key: learningKey, now: now)
        _ = store.record(.rejected, key: learningKey, now: now)

        let data = try #require(store.jsonData())
        let restored = try #require(AcceptedAndKeptLearningStore(jsonData: data))
        let signal = restored.signal(for: learningKey, now: now)

        #expect(signal.sampleCount == 2)
        #expect(signal.keptCount == 1)
        #expect(signal.rejectedCount == 1)
        #expect(signal.decayFactor == 1)
    }

    @Test("Old evidence decays toward the prior")
    func oldEvidenceDecaysTowardThePrior() {
        var store = AcceptedAndKeptLearningStore(
            priorWeight: 2,
            halfLifeSeconds: 60
        )
        let learningKey = key(mode: .phraseContinuation)
        let now = Date(timeIntervalSince1970: 1_000)

        _ = store.record(.kept, key: learningKey, now: now)
        _ = store.record(.kept, key: learningKey, now: now)
        let fresh = store.signal(for: learningKey, now: now)
        let stale = store.signal(
            for: learningKey,
            now: now.addingTimeInterval(60)
        )

        #expect(stale.decayFactor == 0.5)
        #expect(stale.probability < fresh.probability)
        #expect(stale.probability > stale.priorProbability)
    }

    private func key(
        appBundleIdentifier: String = "com.apple.TextEdit",
        fieldKind: AXFieldKind = .multilineCompose,
        mode: CompletionRequestMode,
        behaviorProfileID: AutocompleteBehaviorProfileID = .docsProse
    ) -> AcceptedAndKeptLearningKey {
        AcceptedAndKeptLearningKey(
            appBundleIdentifier: appBundleIdentifier,
            fieldKind: fieldKind,
            requestMode: mode,
            behaviorProfileID: behaviorProfileID
        )
    }
}
