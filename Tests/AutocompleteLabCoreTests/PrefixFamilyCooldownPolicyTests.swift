import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Prefix family cooldown policy")
struct PrefixFamilyCooldownPolicyTests {
    @Test("Typed over starts a short app field prefix cooldown")
    func typedOverStartsShortCooldown() {
        var policy = PrefixFamilyCooldownPolicy()
        let now = Date(timeIntervalSince1970: 1_000)
        let input = input(textBeforeCursor: "I think this works")

        let cooldown = policy.record(.typedOver, input: input, now: now)

        #expect(cooldown?.reason == .typedOver)
        #expect(cooldown?.durationMilliseconds == 750)
        #expect(cooldown?.prefixTokenCount == 3)
        #expect(policy.decision(for: input, now: now.addingTimeInterval(0.7)).canRequest == false)
        #expect(policy.decision(for: input, now: now.addingTimeInterval(0.8)) == .allowed)
    }

    @Test("Repeated typed over escalates to a longer cooldown")
    func repeatedTypedOverEscalatesToLongerCooldown() throws {
        var policy = PrefixFamilyCooldownPolicy()
        let now = Date(timeIntervalSince1970: 1_000)
        let input = input(textBeforeCursor: "I think this works")

        _ = policy.record(.typedOver, input: input, now: now)
        let maybeRepeated = policy.record(
            .typedOver,
            input: input,
            now: now.addingTimeInterval(0.5)
        )
        let repeated = try #require(maybeRepeated)

        #expect(repeated.reason == .typedOver)
        #expect(repeated.durationMilliseconds == 5_000)
        #expect(repeated.isEscalated)
        #expect(repeated.metadata["prefixCooldownEscalated"] == "true")
        #expect(policy.decision(for: input, now: now.addingTimeInterval(5.4)).canRequest == false)
        #expect(policy.decision(for: input, now: now.addingTimeInterval(5.6)) == .allowed)
    }

    @Test("One typed over miss does not make future suggestions less eager")
    func oneTypedOverMissDoesNotMakeFutureSuggestionsLessEager() {
        var policy = PrefixFamilyCooldownPolicy()
        let now = Date(timeIntervalSince1970: 1_000)
        let input = input(textBeforeCursor: "I think this works")

        _ = policy.record(.typedOver, input: input, now: now)
        let adjustment = policy.eagernessAdjustment(for: input, now: now.addingTimeInterval(1))

        #expect(!adjustment.isActive)
        #expect(adjustment.thresholdAdjustment == 0)
        #expect(adjustment.metadata["prefixEagernessApplied"] == "false")
    }

    @Test("Repeated typed over misses make the same prefix family less eager after cooldown")
    func repeatedTypedOverMissesMakeSamePrefixFamilyLessEagerAfterCooldown() throws {
        var policy = PrefixFamilyCooldownPolicy()
        let now = Date(timeIntervalSince1970: 1_000)
        let input = input(textBeforeCursor: "I think this works")

        _ = policy.record(.typedOver, input: input, now: now)
        _ = policy.record(.typedOver, input: input, now: now.addingTimeInterval(0.5))

        #expect(policy.decision(for: input, now: now.addingTimeInterval(5.6)) == .allowed)
        let adjustment = policy.eagernessAdjustment(for: input, now: now.addingTimeInterval(5.6))

        #expect(adjustment.isActive)
        #expect(adjustment.thresholdAdjustment > 0.15)
        #expect(adjustment.repeatedTypedOverThreshold == 1.5)
        #expect(adjustment.metadata["prefixEagernessApplied"] == "true")
        #expect(adjustment.metadata["prefixEagernessRepeatedTypedOverThreshold"] == "1.50")
        #expect(adjustment.metadata["prefixEagernessThresholdAdjustment"] != "0.00")
    }

    @Test("Repeated typed over eagerness pressure decays")
    func repeatedTypedOverEagernessPressureDecays() {
        var policy = PrefixFamilyCooldownPolicy(
            typedOverCooldownMilliseconds: 0,
            repeatedTypedOverCooldownMilliseconds: 0,
            typedOverEagernessHalfLifeSeconds: 5
        )
        let now = Date(timeIntervalSince1970: 1_000)
        let input = input(textBeforeCursor: "I think this works")

        _ = policy.record(.typedOver, input: input, now: now)
        _ = policy.record(.typedOver, input: input, now: now.addingTimeInterval(1))

        #expect(policy.eagernessAdjustment(for: input, now: now.addingTimeInterval(1.1)).isActive)
        #expect(!policy.eagernessAdjustment(for: input, now: now.addingTimeInterval(8)).isActive)
    }

    @Test("Repeated typed over eagerness is scoped by app field mode and prefix family")
    func repeatedTypedOverEagernessIsScopedByAppFieldModeAndPrefixFamily() {
        var policy = PrefixFamilyCooldownPolicy(
            typedOverCooldownMilliseconds: 0,
            repeatedTypedOverCooldownMilliseconds: 0
        )
        let now = Date(timeIntervalSince1970: 1_000)
        let blocked = input(textBeforeCursor: "I think this works")

        _ = policy.record(.typedOver, input: blocked, now: now)
        _ = policy.record(.typedOver, input: blocked, now: now.addingTimeInterval(1))

        #expect(policy.eagernessAdjustment(for: blocked, now: now.addingTimeInterval(2)).isActive)
        #expect(!policy.eagernessAdjustment(
            for: input(app: "com.apple.Notes", textBeforeCursor: "I think this works"),
            now: now.addingTimeInterval(2)
        ).isActive)
        #expect(!policy.eagernessAdjustment(
            for: input(field: "field-two", textBeforeCursor: "I think this works"),
            now: now.addingTimeInterval(2)
        ).isActive)
        #expect(!policy.eagernessAdjustment(
            for: input(mode: .wordCompletion, textBeforeCursor: "I think this works"),
            now: now.addingTimeInterval(2)
        ).isActive)
        #expect(!policy.eagernessAdjustment(
            for: input(textBeforeCursor: "I think this fails"),
            now: now.addingTimeInterval(2)
        ).isActive)
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

    @Test("Accepted then deleted starts a long prefix cooldown")
    func acceptedThenDeletedStartsLongPrefixCooldown() throws {
        var policy = PrefixFamilyCooldownPolicy()
        let now = Date(timeIntervalSince1970: 1_000)
        let input = input(textBeforeCursor: "I think this works")

        let recordedCooldown = policy.record(.acceptedThenDeleted, input: input, now: now)
        let cooldown = try #require(recordedCooldown)

        #expect(cooldown.reason == .acceptedThenDeleted)
        #expect(cooldown.durationMilliseconds == 60_000)
        #expect(cooldown.metadata["prefixCooldownReason"] == "acceptedThenDeleted")
        #expect(policy.decision(for: input, now: now.addingTimeInterval(59.9)).canRequest == false)
        #expect(policy.decision(for: input, now: now.addingTimeInterval(60.1)) == .allowed)
    }

    @Test("Repeated accepted then deleted makes that prefix less eager after cooldown")
    func repeatedAcceptedThenDeletedMakesThatPrefixLessEagerAfterCooldown() {
        var policy = PrefixFamilyCooldownPolicy(
            acceptedThenDeletedCooldownMilliseconds: 0,
            repeatedAcceptedThenDeletedCooldownMilliseconds: 0,
            acceptedThenDeletedEagernessThreshold: 1,
            acceptedThenDeletedEagernessHalfLifeSeconds: 5
        )
        let now = Date(timeIntervalSince1970: 1_000)
        let input = input(textBeforeCursor: "I think this works")

        _ = policy.record(.acceptedThenDeleted, input: input, now: now)
        _ = policy.record(.acceptedThenDeleted, input: input, now: now.addingTimeInterval(1))

        let adjustment = policy.eagernessAdjustment(for: input, now: now.addingTimeInterval(2))

        #expect(adjustment.isActive)
        #expect(adjustment.acceptedThenDeletedScore > 1)
        #expect(adjustment.thresholdAdjustment > 0.30)
        #expect(adjustment.metadata["prefixEagernessApplied"] == "true")
        #expect(adjustment.metadata["prefixEagernessAcceptedThenDeletedScore"] != "0.00")
        #expect(adjustment.metadata["prefixEagernessRepeatedAcceptedThenDeletedThreshold"] == "1.00")
    }

    @Test("Accepted then deleted eagerness is scoped and decays")
    func acceptedThenDeletedEagernessIsScopedAndDecays() {
        var policy = PrefixFamilyCooldownPolicy(
            acceptedThenDeletedCooldownMilliseconds: 0,
            repeatedAcceptedThenDeletedCooldownMilliseconds: 0,
            acceptedThenDeletedEagernessThreshold: 1,
            acceptedThenDeletedEagernessHalfLifeSeconds: 5
        )
        let now = Date(timeIntervalSince1970: 1_000)
        let blocked = input(textBeforeCursor: "I think this works")

        _ = policy.record(.acceptedThenDeleted, input: blocked, now: now)
        _ = policy.record(.acceptedThenDeleted, input: blocked, now: now.addingTimeInterval(1))

        #expect(policy.eagernessAdjustment(for: blocked, now: now.addingTimeInterval(2)).isActive)
        #expect(!policy.eagernessAdjustment(
            for: input(field: "field-two", textBeforeCursor: "I think this works"),
            now: now.addingTimeInterval(2)
        ).isActive)
        #expect(!policy.eagernessAdjustment(
            for: input(textBeforeCursor: "I think this fails"),
            now: now.addingTimeInterval(2)
        ).isActive)
        #expect(!policy.eagernessAdjustment(for: blocked, now: now.addingTimeInterval(30)).isActive)
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
        var policy = PrefixFamilyCooldownPolicy(traceFingerprintSecret: Data("unit-test-secret".utf8))
        let recordedCooldown = policy.record(
            .typedOver,
            input: input(textBeforeCursor: "secret customer name"),
            now: Date(timeIntervalSince1970: 1_000)
        )
        let cooldown = try #require(recordedCooldown)

        #expect(cooldown.metadata["prefixCooldownReason"] == "typedOver")
        #expect(cooldown.metadata["prefixCooldownDurationMilliseconds"] == "750")
        #expect(cooldown.metadata["prefixFamilyTokenCount"] == "3")
        #expect(cooldown.metadata["prefixCooldownEscalated"] == "false")
        #expect(cooldown.metadata["prefixFamilyFingerprintVersion"] == TracePrivacyFingerprint.prefixFamilyVersion)
        #expect(cooldown.metadata["prefixFamilyHMACToken"]?.count == 24)
        #expect(!cooldown.metadata.values.joined(separator: " ").contains("secret"))
    }

    @Test("Eagerness metadata is shape only")
    func eagernessMetadataIsShapeOnly() throws {
        var policy = PrefixFamilyCooldownPolicy(
            typedOverCooldownMilliseconds: 0,
            repeatedTypedOverCooldownMilliseconds: 0,
            traceFingerprintSecret: Data("unit-test-secret".utf8)
        )
        let now = Date(timeIntervalSince1970: 1_000)
        let sensitive = input(textBeforeCursor: "secret customer name")

        _ = policy.record(.typedOver, input: sensitive, now: now)
        _ = policy.record(.typedOver, input: sensitive, now: now.addingTimeInterval(1))
        let adjustment = policy.eagernessAdjustment(for: sensitive, now: now.addingTimeInterval(2))

        #expect(adjustment.metadata["prefixEagernessApplied"] == "true")
        #expect(adjustment.metadata["prefixEagernessRepeatedTypedOverThreshold"] == "1.50")
        #expect(adjustment.metadata["prefixFamilyTokenCount"] == "3")
        #expect(adjustment.metadata["prefixFamilyFingerprintVersion"] == TracePrivacyFingerprint.prefixFamilyVersion)
        #expect(adjustment.metadata["prefixFamilyHMACToken"]?.count == 24)
        #expect(!adjustment.metadata.values.joined(separator: " ").contains("secret"))
        #expect(!adjustment.metadata.values.joined(separator: " ").contains("customer"))
    }

    @Test("Prefix family fingerprints are stable and keyed")
    func prefixFamilyFingerprintsAreStableAndKeyed() throws {
        let secret = Data("unit-test-secret".utf8)
        var policy = PrefixFamilyCooldownPolicy(traceFingerprintSecret: secret)
        var samePolicy = PrefixFamilyCooldownPolicy(traceFingerprintSecret: secret)
        var differentSecretPolicy = PrefixFamilyCooldownPolicy(
            traceFingerprintSecret: Data("different-secret".utf8)
        )

        let maybeFirst = policy.record(
            .typedOver,
            input: input(textBeforeCursor: "Secret   customer NAME"),
            now: Date(timeIntervalSince1970: 1_000)
        )
        let maybeSame = samePolicy.record(
            .typedOver,
            input: input(textBeforeCursor: "secret customer name"),
            now: Date(timeIntervalSince1970: 1_000)
        )
        let maybeDifferentSecret = differentSecretPolicy.record(
            .typedOver,
            input: input(textBeforeCursor: "secret customer name"),
            now: Date(timeIntervalSince1970: 1_000)
        )
        let first = try #require(maybeFirst)
        let same = try #require(maybeSame)
        let differentSecret = try #require(maybeDifferentSecret)

        #expect(first.metadata["prefixFamilyHMACToken"] == same.metadata["prefixFamilyHMACToken"])
        #expect(first.metadata["prefixFamilyHMACToken"] != differentSecret.metadata["prefixFamilyHMACToken"])
        let json = String(decoding: try JSONEncoder().encode(first.metadata), as: UTF8.self)
        #expect(!json.localizedCaseInsensitiveContains("secret"))
        #expect(!json.localizedCaseInsensitiveContains("customer"))
        #expect(!json.localizedCaseInsensitiveContains("name"))
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
