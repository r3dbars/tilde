import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Prefix family cooldown policy")
struct PrefixFamilyCooldownPolicyTests {
    @Test("Typed over starts a five second app field prefix cooldown")
    func typedOverStartsFiveSecondCooldown() {
        var policy = PrefixFamilyCooldownPolicy()
        let now = Date(timeIntervalSince1970: 1_000)
        let input = input(textBeforeCursor: "I think this works")

        let cooldown = policy.record(.typedOver, input: input, now: now)

        #expect(cooldown?.reason == .typedOver)
        #expect(cooldown?.durationMilliseconds == 5_000)
        #expect(cooldown?.prefixTokenCount == 3)
        #expect(policy.decision(for: input, now: now.addingTimeInterval(4.9)).canRequest == false)
        #expect(policy.decision(for: input, now: now.addingTimeInterval(5.1)) == .allowed)
    }

    @Test("Escape starts a fifteen second cooldown")
    func escapeStartsFifteenSecondCooldown() {
        var policy = PrefixFamilyCooldownPolicy()
        let now = Date(timeIntervalSince1970: 1_000)
        let input = input(textBeforeCursor: "Can you please")

        let cooldown = policy.record(.escapeDismissal, input: input, now: now)

        #expect(cooldown?.durationMilliseconds == 15_000)
        #expect(cooldown?.isEscalated == false)
        #expect(policy.decision(for: input, now: now.addingTimeInterval(14.9)).canRequest == false)
        #expect(policy.decision(for: input, now: now.addingTimeInterval(15.1)) == .allowed)
    }

    @Test("Repeated Escape escalates to a longer cooldown")
    func repeatedEscapeEscalatesToLongerCooldown() throws {
        var policy = PrefixFamilyCooldownPolicy()
        let now = Date(timeIntervalSince1970: 1_000)
        let input = input(textBeforeCursor: "Can you please")

        _ = policy.record(.escapeDismissal, input: input, now: now)
        let maybeRepeated = policy.record(
            .escapeDismissal,
            input: input,
            now: now.addingTimeInterval(5)
        )
        let repeated = try #require(maybeRepeated)

        #expect(repeated.durationMilliseconds == 60_000)
        #expect(repeated.isEscalated)
        #expect(repeated.metadata["prefixCooldownEscalated"] == "true")
        #expect(policy.decision(for: input, now: now.addingTimeInterval(64.9)).canRequest == false)
        #expect(policy.decision(for: input, now: now.addingTimeInterval(65.1)) == .allowed)
    }

    @Test("Deletion starts a short stabilization cooldown")
    func deletionStartsShortStabilizationCooldown() {
        var policy = PrefixFamilyCooldownPolicy()
        let now = Date(timeIntervalSince1970: 1_000)
        let input = input(textBeforeCursor: "Can you")

        let cooldown = policy.record(.deletion, input: input, now: now)

        #expect(cooldown?.durationMilliseconds == 250)
        #expect(policy.decision(for: input, now: now.addingTimeInterval(0.2)).canRequest == false)
        #expect(policy.decision(for: input, now: now.addingTimeInterval(0.3)) == .allowed)
    }

    @Test("Cooldowns are scoped by app field mode and prefix family")
    func scopedByAppFieldModeAndPrefixFamily() {
        var policy = PrefixFamilyCooldownPolicy()
        let now = Date(timeIntervalSince1970: 1_000)
        let blocked = input(textBeforeCursor: "I think this works")

        _ = policy.record(.typedOver, input: blocked, now: now)

        #expect(policy.decision(for: blocked, now: now).canRequest == false)
        #expect(policy.decision(for: input(app: "com.apple.Notes", textBeforeCursor: "I think this works"), now: now) == .allowed)
        #expect(policy.decision(for: input(field: "field-two", textBeforeCursor: "I think this works"), now: now) == .allowed)
        #expect(policy.decision(for: input(mode: .wordCompletion, textBeforeCursor: "I think this works"), now: now) == .allowed)
        #expect(policy.decision(for: input(textBeforeCursor: "I think this fails"), now: now) == .allowed)
    }

    @Test("Trace metadata is shape only")
    func traceMetadataIsShapeOnly() throws {
        var policy = PrefixFamilyCooldownPolicy()
        let recordedCooldown = policy.record(
            .typedOver,
            input: input(textBeforeCursor: "secret customer name"),
            now: Date(timeIntervalSince1970: 1_000)
        )
        let cooldown = try #require(recordedCooldown)

        #expect(cooldown.metadata["prefixCooldownReason"] == "typedOver")
        #expect(cooldown.metadata["prefixCooldownDurationMilliseconds"] == "5000")
        #expect(cooldown.metadata["prefixFamilyTokenCount"] == "3")
        #expect(cooldown.metadata["prefixCooldownEscalated"] == "false")
        #expect(!cooldown.metadata.values.joined(separator: " ").contains("secret"))
    }

    private func input(
        app: String = "com.apple.TextEdit",
        field: String = "field-one",
        mode: CompletionRequestMode? = .phraseContinuation,
        textBeforeCursor: String
    ) -> PrefixFamilyCooldownInput {
        PrefixFamilyCooldownInput(
            appBundleIdentifier: app,
            fieldIdentifier: field,
            requestMode: mode,
            textBeforeCursor: textBeforeCursor
        )
    }
}
