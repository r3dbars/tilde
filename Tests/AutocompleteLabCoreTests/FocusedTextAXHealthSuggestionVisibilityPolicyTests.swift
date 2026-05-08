import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Focused text AX health suggestion visibility policy")
struct FocusedTextAXHealthSuggestionVisibilityPolicyTests {
    @Test("Preserves same-app visible suggestion during AX cooldown")
    func preservesSameAppVisibleSuggestionDuringCooldown() {
        let policy = FocusedTextAXHealthSuggestionVisibilityPolicy()
        let cooldown = focusedTextAXCooldown(bundleIdentifier: "com.apple.Notes")

        #expect(!policy.shouldHideVisibleSuggestion(
            during: cooldown,
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: false
        ))
    }

    @Test("Hides visible suggestion after user typing invalidates it")
    func hidesSuggestionInvalidatedByTyping() {
        let policy = FocusedTextAXHealthSuggestionVisibilityPolicy()
        let cooldown = focusedTextAXCooldown(bundleIdentifier: "com.apple.Notes")

        #expect(policy.shouldHideVisibleSuggestion(
            during: cooldown,
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: true
        ))
    }

    @Test("Hides stale visible suggestion during AX cooldown")
    func hidesStaleVisibleSuggestionDuringCooldown() {
        let policy = FocusedTextAXHealthSuggestionVisibilityPolicy()
        let cooldown = focusedTextAXCooldown(bundleIdentifier: "com.apple.Notes")

        #expect(policy.shouldHideVisibleSuggestion(
            during: cooldown,
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: false,
            currentSuggestionAgeMilliseconds: 901,
            maximumPreservedAgeMilliseconds: 750
        ))

        #expect(!policy.shouldHideVisibleSuggestion(
            during: cooldown,
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: false,
            currentSuggestionAgeMilliseconds: 240,
            maximumPreservedAgeMilliseconds: 750
        ))
    }

    @Test("Hides visible suggestion with unknown age when freshness is required")
    func hidesVisibleSuggestionWithUnknownAgeWhenFreshnessRequired() {
        let policy = FocusedTextAXHealthSuggestionVisibilityPolicy()
        let cooldown = focusedTextAXCooldown(bundleIdentifier: "com.apple.Notes")

        #expect(policy.shouldHideVisibleSuggestion(
            during: cooldown,
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: false,
            maximumPreservedAgeMilliseconds: 750
        ))
    }

    @Test("Hides visible suggestion when cooldown app differs")
    func hidesSuggestionForDifferentAppCooldown() {
        let policy = FocusedTextAXHealthSuggestionVisibilityPolicy()
        let cooldown = focusedTextAXCooldown(bundleIdentifier: "com.apple.Notes")

        #expect(policy.shouldHideVisibleSuggestion(
            during: cooldown,
            currentSuggestionBundleIdentifier: "com.apple.TextEdit",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: false
        ))
    }

    @Test("Hides visible suggestion when app ownership is unknown")
    func hidesSuggestionWithUnknownAppOwnership() {
        let policy = FocusedTextAXHealthSuggestionVisibilityPolicy()
        let cooldown = focusedTextAXCooldown(bundleIdentifier: "com.apple.Notes")

        #expect(policy.shouldHideVisibleSuggestion(
            during: cooldown,
            currentSuggestionBundleIdentifier: nil,
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: false
        ))
    }

    @Test("Hides visible suggestion when field ownership is unknown or changed")
    func hidesSuggestionWithUnknownOrChangedFieldOwnership() {
        let policy = FocusedTextAXHealthSuggestionVisibilityPolicy()
        let cooldown = focusedTextAXCooldown(bundleIdentifier: "com.apple.Notes")

        #expect(policy.shouldHideVisibleSuggestion(
            during: cooldown,
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: nil,
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: false
        ))
        #expect(policy.shouldHideVisibleSuggestion(
            during: cooldown,
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: nil,
            isInvalidatedByUserTyping: false
        ))
        #expect(policy.shouldHideVisibleSuggestion(
            during: cooldown,
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(2),
            isInvalidatedByUserTyping: false
        ))
    }

    private func focusedTextAXCooldown(bundleIdentifier: String) -> FocusedTextAXHealthCooldown {
        FocusedTextAXHealthCooldown(
            bundleIdentifier: bundleIdentifier,
            reason: .readDuration,
            slowReadCount: 1,
            cooldownMilliseconds: 750,
            remainingMilliseconds: 750,
            cooldownUntil: Date().addingTimeInterval(0.75)
        )
    }

    private func fieldIdentity(_ elementIdentifier: Int) -> FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: "com.apple.Notes",
            processIdentifier: 123,
            elementIdentifier: elementIdentifier
        )
    }
}
