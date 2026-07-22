import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Focused text slow-read suggestion visibility policy")
struct FocusedTextSlowReadSuggestionVisibilityPolicyTests {
    // MARK: - AX-health cooldown scenarios (degradedBundleIdentifier from an active cooldown)

    @Test("Preserves same-app visible suggestion during AX cooldown")
    func preservesSameAppVisibleSuggestionDuringCooldown() {
        let policy = FocusedTextSlowReadSuggestionVisibilityPolicy()

        #expect(!policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: "com.apple.Notes",
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: false
        ))
    }

    @Test("Preserves virtual app suggestion during host AX cooldown")
    func preservesVirtualAppSuggestionDuringHostAXCooldown() {
        let policy = FocusedTextSlowReadSuggestionVisibilityPolicy()

        #expect(!policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: "com.mitchellh.ghostty",
            currentSuggestionBundleIdentifier: "com.anthropic.claude-code",
            currentSuggestionHostBundleIdentifier: "com.mitchellh.ghostty",
            currentSuggestionFieldIdentity: fieldIdentity(1, bundleIdentifier: "com.mitchellh.ghostty"),
            currentFieldIdentity: fieldIdentity(1, bundleIdentifier: "com.mitchellh.ghostty"),
            isInvalidatedByUserTyping: false,
            currentSuggestionAgeMilliseconds: 120,
            maximumPreservedAgeMilliseconds: 750
        ))
    }

    @Test("Hides visible suggestion after user typing invalidates it during AX cooldown")
    func hidesSuggestionInvalidatedByTypingDuringCooldown() {
        let policy = FocusedTextSlowReadSuggestionVisibilityPolicy()

        #expect(policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: "com.apple.Notes",
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: true
        ))
    }

    @Test("Hides stale visible suggestion during AX cooldown")
    func hidesStaleVisibleSuggestionDuringCooldown() {
        let policy = FocusedTextSlowReadSuggestionVisibilityPolicy()

        #expect(policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: "com.apple.Notes",
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: false,
            currentSuggestionAgeMilliseconds: 901,
            maximumPreservedAgeMilliseconds: 750
        ))

        #expect(!policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: "com.apple.Notes",
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: false,
            currentSuggestionAgeMilliseconds: 240,
            maximumPreservedAgeMilliseconds: 750
        ))
    }

    @Test("Hides visible suggestion with unknown age when freshness is required during AX cooldown")
    func hidesVisibleSuggestionWithUnknownAgeWhenFreshnessRequiredDuringCooldown() {
        let policy = FocusedTextSlowReadSuggestionVisibilityPolicy()

        #expect(policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: "com.apple.Notes",
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: false,
            maximumPreservedAgeMilliseconds: 750
        ))
    }

    @Test("Hides visible suggestion when cooldown app differs")
    func hidesSuggestionForDifferentAppCooldown() {
        let policy = FocusedTextSlowReadSuggestionVisibilityPolicy()

        #expect(policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: "com.apple.Notes",
            currentSuggestionBundleIdentifier: "com.apple.TextEdit",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: false
        ))
    }

    @Test("Hides visible suggestion when app ownership is unknown during AX cooldown")
    func hidesSuggestionWithUnknownAppOwnershipDuringCooldown() {
        let policy = FocusedTextSlowReadSuggestionVisibilityPolicy()

        #expect(policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: "com.apple.Notes",
            currentSuggestionBundleIdentifier: nil,
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: false
        ))
    }

    @Test("Hides visible suggestion when field ownership is unknown or changed during AX cooldown")
    func hidesSuggestionWithUnknownOrChangedFieldOwnershipDuringCooldown() {
        let policy = FocusedTextSlowReadSuggestionVisibilityPolicy()

        #expect(policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: "com.apple.Notes",
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: nil,
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: false
        ))
        #expect(policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: "com.apple.Notes",
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: nil,
            isInvalidatedByUserTyping: false
        ))
        #expect(policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: "com.apple.Notes",
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(2),
            isInvalidatedByUserTyping: false
        ))
    }

    // MARK: - Polling-throttle scenarios (degradedBundleIdentifier from the frontmost app)

    @Test("Preserves same-app visible suggestion during polling throttle")
    func preservesSameAppVisibleSuggestionDuringThrottle() {
        let policy = FocusedTextSlowReadSuggestionVisibilityPolicy()

        #expect(!policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: "com.apple.Notes",
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: false
        ))
    }

    @Test("Preserves virtual app suggestion when frontmost app is its host")
    func preservesVirtualAppSuggestionWhenFrontmostAppIsHost() {
        let policy = FocusedTextSlowReadSuggestionVisibilityPolicy()

        #expect(!policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: "com.mitchellh.ghostty",
            currentSuggestionBundleIdentifier: "com.anthropic.claude-code",
            currentSuggestionHostBundleIdentifier: "com.mitchellh.ghostty",
            currentSuggestionFieldIdentity: fieldIdentity(1, bundleIdentifier: "com.mitchellh.ghostty"),
            currentFieldIdentity: fieldIdentity(1, bundleIdentifier: "com.mitchellh.ghostty"),
            isInvalidatedByUserTyping: false,
            currentSuggestionAgeMilliseconds: 120,
            maximumPreservedAgeMilliseconds: 750
        ))
    }

    @Test("Hides suggestion invalidated by typing during polling throttle")
    func hidesSuggestionInvalidatedByTypingDuringThrottle() {
        let policy = FocusedTextSlowReadSuggestionVisibilityPolicy()

        #expect(policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: "com.apple.Notes",
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: true
        ))
    }

    @Test("Hides stale visible suggestion during polling throttle")
    func hidesStaleVisibleSuggestionDuringThrottle() {
        let policy = FocusedTextSlowReadSuggestionVisibilityPolicy()

        #expect(policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: "com.apple.Notes",
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: false,
            currentSuggestionAgeMilliseconds: 901,
            maximumPreservedAgeMilliseconds: 750
        ))

        #expect(!policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: "com.apple.Notes",
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: false,
            currentSuggestionAgeMilliseconds: 240,
            maximumPreservedAgeMilliseconds: 750
        ))
    }

    @Test("Hides visible suggestion with unknown age when freshness is required during polling throttle")
    func hidesVisibleSuggestionWithUnknownAgeWhenFreshnessRequiredDuringThrottle() {
        let policy = FocusedTextSlowReadSuggestionVisibilityPolicy()

        #expect(policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: "com.apple.Notes",
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: false,
            maximumPreservedAgeMilliseconds: 750
        ))
    }

    @Test("Hides suggestion when frontmost app changes")
    func hidesSuggestionWhenFrontmostAppChanges() {
        let policy = FocusedTextSlowReadSuggestionVisibilityPolicy()

        #expect(policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: "com.apple.TextEdit",
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: false
        ))
    }

    @Test("Hides suggestion when app ownership is unknown during polling throttle")
    func hidesSuggestionWithUnknownAppOwnershipDuringThrottle() {
        let policy = FocusedTextSlowReadSuggestionVisibilityPolicy()

        #expect(policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: "com.apple.Notes",
            currentSuggestionBundleIdentifier: nil,
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: false
        ))
        #expect(policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: nil,
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: false
        ))
    }

    @Test("Hides suggestion when field ownership is unknown or changed during polling throttle")
    func hidesSuggestionWithUnknownOrChangedFieldOwnershipDuringThrottle() {
        let policy = FocusedTextSlowReadSuggestionVisibilityPolicy()

        #expect(policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: "com.apple.Notes",
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: nil,
            currentFieldIdentity: fieldIdentity(1),
            isInvalidatedByUserTyping: false
        ))
        #expect(policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: "com.apple.Notes",
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: nil,
            isInvalidatedByUserTyping: false
        ))
        #expect(policy.shouldHideVisibleSuggestion(
            degradedBundleIdentifier: "com.apple.Notes",
            currentSuggestionBundleIdentifier: "com.apple.Notes",
            currentSuggestionFieldIdentity: fieldIdentity(1),
            currentFieldIdentity: fieldIdentity(2),
            isInvalidatedByUserTyping: false
        ))
    }

    private func fieldIdentity(
        _ elementIdentifier: Int,
        bundleIdentifier: String = "com.apple.Notes"
    ) -> FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: bundleIdentifier,
            processIdentifier: 123,
            elementIdentifier: elementIdentifier
        )
    }
}
