import Foundation
import Testing
import TildeCore
@testable import TildeLabKit

/// In-memory stand-in for the settings suite the app and input method share.
private final class MemoryDefaults: H01ExperimentDefaults, @unchecked Sendable {
    private var storage: [String: Any]
    private(set) var writes = 0

    init(_ storage: [String: Any] = [:]) {
        self.storage = storage
    }

    func object(forKey key: String) -> Any? { storage[key] }

    func set(_ value: Any?, forKey key: String) {
        writes += 1
        storage[key] = value
    }

    var snapshot: [String: Any] { storage }
}

@Suite("H01 block randomization harness")
struct H01BlockRandomizationTests {
    private let epoch = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Every block pair is one A and one B")
    func pairsAreBalanced() {
        for seed in [UInt64(0), 1, 42, 7_919, UInt64.max] {
            let schedule = H01BlockSchedule(seed: seed, epoch: epoch)
            for pair in 0..<64 {
                let first = schedule.arm(atBlockIndex: pair * 2)
                let second = schedule.arm(atBlockIndex: pair * 2 + 1)
                #expect(first != second)
            }
            let arms = (0..<128).map { schedule.arm(atBlockIndex: $0) }
            #expect(arms.count { $0 == .a } == 64)
            #expect(arms.count { $0 == .b } == 64)
        }
    }

    @Test("Both orientations occur, so the schedule is not a fixed alternation")
    func orientationsVary() {
        let schedule = H01BlockSchedule(seed: 20_260_829, epoch: epoch)
        let firstOfPair = (0..<200).map { schedule.arm(atBlockIndex: $0 * 2) }
        #expect(firstOfPair.contains(.a))
        #expect(firstOfPair.contains(.b))
    }

    @Test("The same seed reproduces the same arms; a different seed does not")
    func assignmentIsReproducible() {
        let one = H01BlockSchedule(seed: 99, epoch: epoch)
        let two = H01BlockSchedule(seed: 99, epoch: epoch)
        let other = H01BlockSchedule(seed: 100, epoch: epoch)
        let armsOne = (0..<200).map { one.arm(atBlockIndex: $0) }
        let armsTwo = (0..<200).map { two.arm(atBlockIndex: $0) }
        let armsOther = (0..<200).map { other.arm(atBlockIndex: $0) }
        #expect(armsOne == armsTwo)
        #expect(armsOne != armsOther)
    }

    @Test("Time maps to blocks, and a session inside one block keeps one arm")
    func timeMapsToBlocks() {
        let schedule = H01BlockSchedule(seed: 5, epoch: epoch, blockSeconds: 1_800)
        #expect(schedule.blockIndex(at: epoch) == 0)
        #expect(schedule.blockIndex(at: epoch.addingTimeInterval(-10_000)) == 0)
        #expect(schedule.blockIndex(at: epoch.addingTimeInterval(1_799)) == 0)
        #expect(schedule.blockIndex(at: epoch.addingTimeInterval(1_800)) == 1)
        #expect(schedule.blockIndex(at: epoch.addingTimeInterval(3_600)) == 2)
        let armAtStart = schedule.arm(at: epoch)
        #expect(schedule.arm(at: epoch.addingTimeInterval(900)) == armAtStart)
    }

    @Test("A persisted schedule survives a restart and is never reshuffled")
    func scheduleIsPersisted() throws {
        let defaults = MemoryDefaults()
        let created = H01BlockRandomization.schedule(in: defaults, now: epoch, seed: 1_234)
        #expect(defaults.object(forKey: H01BlockRandomization.scheduleKey) != nil)

        // A "restart" is a fresh read of the same storage with a fresh seed
        // that must be ignored, because the schedule already exists.
        let afterRestart = H01BlockRandomization.schedule(
            in: defaults,
            now: epoch.addingTimeInterval(86_400),
            seed: 9_999
        )
        #expect(afterRestart == created)
        #expect(afterRestart.seed == 1_234)
        #expect(afterRestart.epoch == created.epoch)
        let before = (0..<64).map { created.arm(atBlockIndex: $0) }
        let after = (0..<64).map { afterRestart.arm(atBlockIndex: $0) }
        #expect(before == after)

        let encoded = try created.encodedJSON()
        #expect(H01BlockSchedule.decodeJSON(encoded) == created)
        #expect(H01BlockSchedule.decodeJSON("not json") == nil)
    }

    @Test("Disabled by default: no arm, no schedule, nothing written")
    func disabledByDefault() {
        let defaults = MemoryDefaults()
        #expect(H01BlockRandomization.isEnabled(defaults) == false)
        #expect(H01BlockRandomization.arm(
            profile: .modelPreview,
            defaults: defaults,
            now: epoch
        ) == nil)
        #expect(defaults.writes == 0)
        #expect(defaults.object(forKey: H01BlockRandomization.scheduleKey) == nil)
        #expect(H01BlockRandomization.visibleWordCap(
            requestedArm: "b",
            profile: .modelPreview,
            defaults: defaults
        ) == nil)
    }

    @Test("Even enabled, only the Model Preview profile may run the harness")
    func onlyModelPreviewParticipates() {
        let defaults = MemoryDefaults()
        H01BlockRandomization.setEnabled(true, in: defaults)
        for profile in [TildeProductProfile.production, .preview9B, .preview26B] {
            #expect(H01BlockRandomization.arm(
                profile: profile,
                defaults: defaults,
                now: epoch
            ) == nil)
            #expect(H01BlockRandomization.visibleWordCap(
                requestedArm: "b",
                profile: profile,
                defaults: defaults
            ) == nil)
        }
        #expect(H01BlockRandomization.arm(
            profile: .modelPreview,
            defaults: defaults,
            now: epoch
        ) != nil)
    }

    @Test("Arm A is the production cap; arm B is three words")
    func armCaps() {
        #expect(H01Arm.a.visibleWordCap == CompletionSuggestion.defaultMaxVisibleWords)
        #expect(H01Arm.a.visibleWordCap == 8)
        #expect(H01Arm.b.visibleWordCap == 3)
        #expect(H01Arm.a.eventVariant == "champion")
        #expect(H01Arm.b.eventVariant == "challenger")
    }

    @Test("Only the two arm identifiers are registered by the Lab protocol")
    func armIdentifiersAreValidated() {
        let defaults = MemoryDefaults()
        H01BlockRandomization.setEnabled(true, in: defaults)
        #expect(H01BlockRandomization.isValidArmIdentifier("a"))
        #expect(H01BlockRandomization.isValidArmIdentifier("b"))
        #expect(H01BlockRandomization.isValidArmIdentifier("1") == false)
        #expect(H01BlockRandomization.isValidArmIdentifier("champion") == false)
        #expect(H01BlockRandomization.visibleWordCap(
            requestedArm: "1",
            profile: .modelPreview,
            defaults: defaults
        ) == nil)
        #expect(H01BlockRandomization.visibleWordCap(
            requestedArm: "b",
            profile: .modelPreview,
            defaults: defaults
        ) == 3)
    }

    @Test("Events carry the arm; an untagged event stays champion")
    func eventsAreTagged() throws {
        let untagged = opportunity(variant: nil)
        #expect(try untagged.eventWithoutAcceptedSpan().variant == "champion")

        for arm in H01Arm.allCases {
            let tagged = opportunity(variant: arm.eventVariant)
            let event = try tagged.eventWithoutAcceptedSpan()
            #expect(event.variant == arm.eventVariant)
            let encoded = try TextFreeOnlineEvent.encodeJSONL(event)
            let text = String(decoding: encoded, as: UTF8.self)
            #expect(text.contains("\"variant\":\"\(arm.eventVariant)\""))
        }
    }

    private func opportunity(variant: String?) -> LiveOnlineOpportunity {
        if let variant {
            return LiveOnlineOpportunity(
                shownAt: epoch,
                sessionDigestSHA256: String(repeating: "a", count: 64),
                variant: variant,
                appCategory: "prose",
                register: "prose",
                boundary: "word-boundary",
                safeOpportunity: true,
                candidateCharacters: 9,
                candidateWordCount: 2,
                opportunityCharacters: 40
            )
        }
        return LiveOnlineOpportunity(
            shownAt: epoch,
            sessionDigestSHA256: String(repeating: "a", count: 64),
            appCategory: "prose",
            register: "prose",
            boundary: "word-boundary",
            safeOpportunity: true,
            candidateCharacters: 9,
            candidateWordCount: 2,
            opportunityCharacters: 40
        )
    }
}
