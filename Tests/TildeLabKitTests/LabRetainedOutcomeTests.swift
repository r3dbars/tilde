import Foundation
import Testing
@testable import TildeCore
@testable import TildeLabKit

@Suite("F03 retained-outcome ledger")
struct LabRetainedOutcomeTests {
    private let campaignID = UUID()

    @Test("Accept-and-keep is observed at every horizon and does not look like a miss")
    func acceptThenKeepAtEveryHorizon() throws {
        let event = try retainedEvent(
            outcome: .acceptedAll,
            accepted: 10,
            replacedWithin5s: 0,
            settledVisible: 400,
            five: try RetainedCharacterObservation(retainedCharacters: 10),
            thirty: try RetainedCharacterObservation(retainedCharacters: 10),
            segment: try RetainedCharacterObservation(retainedCharacters: 10)
        ).validated(for: plan())
        let report = try LabOnlineExperimentAnalyzer.analyze([event])
        #expect(report.retentionAt5Seconds.netRetainedCharacters == 10)
        #expect(report.retentionAt30Seconds.netRetainedCharacters == 10)
        #expect(report.retentionAtSegmentClose.netRetainedCharacters == 10)
        #expect(report.retentionAt5Seconds.missingEvents == 0)
        #expect(report.flickerAccepts == 0)
        #expect(report.settledReads == 1)
    }

    @Test("Replacement before each horizon reduces later kept counts only")
    func replacementAtEachHorizon() throws {
        let before5s = try retainedEvent(
            accepted: 10,
            replacedWithin5s: 10,
            five: try RetainedCharacterObservation(retainedCharacters: 0),
            thirty: try RetainedCharacterObservation(retainedCharacters: 0),
            segment: try RetainedCharacterObservation(retainedCharacters: 0)
        )
        let before30s = try retainedEvent(
            accepted: 10,
            replacedWithin5s: 0,
            five: try RetainedCharacterObservation(retainedCharacters: 10),
            thirty: try RetainedCharacterObservation(retainedCharacters: 0),
            segment: try RetainedCharacterObservation(retainedCharacters: 0)
        )
        let beforeSegment = try retainedEvent(
            accepted: 10,
            replacedWithin5s: 0,
            five: try RetainedCharacterObservation(retainedCharacters: 10),
            thirty: try RetainedCharacterObservation(retainedCharacters: 8),
            segment: try RetainedCharacterObservation(retainedCharacters: 0)
        )
        let report = try LabOnlineExperimentAnalyzer.analyze([before5s, before30s, beforeSegment])
        #expect(report.netAcceptedCharacters == 20)
        #expect(report.retentionAt5Seconds.netRetainedCharacters == 20)
        #expect(report.retentionAt30Seconds.netRetainedCharacters == 8)
        #expect(report.retentionAtSegmentClose.netRetainedCharacters == 0)
        #expect(report.retentionAt30Seconds.missingEvents == 0)
    }

    @Test("Typed-through stays distinct from ignored and dismissed")
    func typedThroughIsItsOwnOutcome() throws {
        let typed = try retainedEvent(
            outcome: .typedThrough,
            accepted: 0,
            displayed: true,
            settledVisible: 250
        ).validated(for: plan())
        let ignored = try retainedEvent(
            outcome: .ignored,
            accepted: 0,
            displayed: true,
            settledVisible: 250
        )
        let dismissed = try retainedEvent(
            outcome: .dismissed,
            accepted: 0,
            displayed: true,
            settledVisible: 250
        )
        let report = try LabOnlineExperimentAnalyzer.analyze([typed, ignored, dismissed])
        #expect(typed.outcome == .typedThrough)
        #expect(report.typedThrough == 1)
        #expect(report.ignored == 1)
        #expect(report.dismissed == 1)
        #expect(report.acceptedAll == 0)
        #expect(throws: LabOnlineExperimentError.invalidEvent) {
            try retainedEvent(
                outcome: .typedThrough,
                accepted: 0,
                displayed: true,
                settledVisible: 80
            ).validated(for: plan())
        }
    }

    @Test("A flicker accept is not counted as a read")
    func flickerAcceptIsNotARead() throws {
        let flicker = try retainedEvent(
            accepted: 8,
            settledVisible: 80,
            five: try RetainedCharacterObservation(retainedCharacters: 8),
            thirty: RetainedCharacterObservation(missingness: .notYetObserved),
            segment: RetainedCharacterObservation(missingness: .notYetObserved)
        )
        let report = try LabOnlineExperimentAnalyzer.analyze([flicker])
        #expect(report.acceptedAll == 1)
        #expect(report.flickerAccepts == 1)
        #expect(report.settledReads == 0)
    }

    @Test("Missingness is not coerced to zero kept characters")
    func missingnessIsNotZero() throws {
        let missing = try retainedEvent(
            accepted: 10,
            five: RetainedCharacterObservation(missingness: .notYetObserved),
            thirty: RetainedCharacterObservation(missingness: .observerStopped),
            segment: RetainedCharacterObservation(missingness: .privacyExcluded)
        )
        let report = try LabOnlineExperimentAnalyzer.analyze([missing])
        #expect(report.retentionAt5Seconds.observedEvents == 0)
        #expect(report.retentionAt5Seconds.missingEvents == 1)
        #expect(report.retentionAt5Seconds.netRetainedCharacters == 0)
        #expect(report.retentionAt30Seconds.missingnessCounts["observer-stopped"] == 1)
        #expect(report.retentionAtSegmentClose.missingnessCounts["privacy-excluded"] == 1)
        #expect(throws: LabOnlineExperimentError.ambiguousRetention) {
            try retainedEvent(
                accepted: 10,
                five: RetainedCharacterObservation(unchecked: 0, missingness: .notYetObserved)
            ).validated(for: plan())
        }
    }

    @Test("v2 events remain readable and keep 30s/segment as legacy missingness")
    func legacyV2EventsRemainReadable() throws {
        let payload: [String: Any] = [
            "schema": LabOnlineExperimentEvent.legacySchemaV2,
            "id": UUID().uuidString,
            "campaignID": campaignID.uuidString,
            "occurredAt": "1970-01-01T00:25:00Z",
            "sessionDigestSHA256": String(repeating: "f", count: 64),
            "variant": "champion",
            "appCategory": "chat",
            "register": "chat",
            "boundary": "word-boundary",
            "typingSpeedBucket": "medium",
            "safeOpportunity": true,
            "displayed": true,
            "outcome": "accepted-all",
            "acceptedCharacters": 10,
            "replacedCharactersWithin5Seconds": 2,
            "candidateCharacters": 10,
            "opportunityCharacters": 20,
            "deadlineMissed": false,
            "championDisagreed": false,
            "crashed": false,
            "timedOut": false,
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(LabOnlineExperimentEvent.self, from: data)
        #expect(event.schema == LabOnlineExperimentEvent.legacySchemaV2)
        #expect(event.retentionAt5Seconds.retainedCharacters == 8)
        #expect(event.retentionAt30Seconds.missingness == .legacySchema)
        #expect(event.retentionAtSegmentClose.missingness == .legacySchema)
        _ = try event.validated(for: plan())

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(event)
        let keys = Set((try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])).keys)
        #expect(!keys.contains("retentionAt30Seconds"))
        #expect(keys.isDisjoint(with: ["text", "prompt", "candidate", "screenText"]))
    }

    @Test("Text-bearing keys are rejected before decode")
    func textBearingKeysAreRejected() throws {
        let payload: [String: Any] = [
            "schema": LabOnlineExperimentEvent.currentSchema,
            "prompt": "must never be stored",
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        #expect(throws: LabOnlineExperimentError.forbiddenKey("prompt")) {
            try LabOnlineEventPrivacy.validateJSON(data)
        }
        let nested: [String: Any] = [
            "schema": LabOnlineExperimentEvent.currentSchema,
            "retentionAt5Seconds": ["candidate": "no"],
        ]
        #expect(throws: LabOnlineExperimentError.forbiddenKey("retentionAt5Seconds.candidate")) {
            try LabOnlineEventPrivacy.validateJSON(try JSONSerialization.data(withJSONObject: nested))
        }
    }

    @Test("Dismissed and hidden events can omit next-action time")
    func dismissedAndHiddenAllowMissingNextAction() throws {
        let dismissed = try retainedEvent(
            outcome: .dismissed,
            accepted: 0,
            displayed: true,
            nextAction: nil,
            settledVisible: 300
        ).validated(for: plan())
        let hidden = try LabOnlineExperimentEvent(
            campaignID: campaignID,
            occurredAt: Date(timeIntervalSince1970: 1_500),
            sessionDigestSHA256: String(repeating: "f", count: 64),
            variant: .hidden,
            appCategory: .chat,
            register: .chat,
            boundary: .wordBoundary,
            typingSpeedBucket: .medium,
            safeOpportunity: true,
            displayed: false,
            outcome: .hidden,
            nextActionMilliseconds: nil,
            candidateCharacters: 0,
            opportunityCharacters: 20
        ).validated(for: plan())
        #expect(dismissed.nextActionMilliseconds == nil)
        #expect(hidden.policyHidden)
        #expect(hidden.retentionAt5Seconds.retainedCharacters == 0)
    }

    private func plan() -> LabOnlineExperimentPlan {
        LabOnlineExperimentPlan(
            campaignID: campaignID,
            phase: .shadow,
            championArmID: "champion",
            championArmDigestSHA256: String(repeating: "d", count: 64),
            challengerArmID: "challenger",
            challengerArmDigestSHA256: String(repeating: "e", count: 64),
            challengerAllocation: 0,
            startsAt: Date(timeIntervalSince1970: 1_000),
            endsAt: Date(timeIntervalSince1970: 2_000)
        )
    }

    private func retainedEvent(
        outcome: LabOnlineInteractionOutcome = .acceptedAll,
        accepted: Int = 10,
        replacedWithin5s: Int = 0,
        displayed: Bool = true,
        nextAction: Int? = 300,
        settledVisible: Int? = 400,
        five: RetainedCharacterObservation? = nil,
        thirty: RetainedCharacterObservation? = nil,
        segment: RetainedCharacterObservation? = nil
    ) throws -> LabOnlineExperimentEvent {
        return LabOnlineExperimentEvent(
            campaignID: campaignID,
            occurredAt: Date(timeIntervalSince1970: 1_500),
            sessionDigestSHA256: String(repeating: "f", count: 64),
            variant: .champion,
            appCategory: .chat,
            register: .chat,
            boundary: .wordBoundary,
            typingSpeedBucket: .medium,
            safeOpportunity: true,
            displayed: displayed,
            outcome: outcome,
            acceptedCharacters: accepted,
            replacedCharactersWithin5Seconds: replacedWithin5s,
            nextActionMilliseconds: nextAction,
            generatorMilliseconds: 80,
            firstStableWordMilliseconds: 100,
            candidateCharacters: displayed ? max(accepted, 10) : 0,
            opportunityCharacters: 20,
            settledVisibleMilliseconds: settledVisible,
            retentionAt5Seconds: five,
            retentionAt30Seconds: thirty,
            retentionAtSegmentClose: segment
        )
    }
}
