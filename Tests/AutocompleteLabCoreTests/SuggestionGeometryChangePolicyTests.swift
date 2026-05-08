import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion geometry change policy")
struct SuggestionGeometryChangePolicyTests {
    private let policy = SuggestionGeometryChangePolicy()

    @Test("Screen layout changes hide visible suggestions")
    func screenLayoutChangesHideVisibleSuggestions() {
        #expect(policy.shouldInvalidateSuggestionState(
            hasVisibleSuggestion: true,
            hasPendingSuggestionRequest: false,
            previousScreenLayoutFingerprint: "0,0,1440x900@200",
            currentScreenLayoutFingerprint: "0,0,1728x1117@200"
        ))
    }

    @Test("Screen layout changes cancel pending requests")
    func screenLayoutChangesCancelPendingRequests() {
        #expect(policy.shouldInvalidateSuggestionState(
            hasVisibleSuggestion: false,
            hasPendingSuggestionRequest: true,
            previousScreenLayoutFingerprint: "0,0,1440x900@200",
            currentScreenLayoutFingerprint: "-1920,0,1920x1080@100|0,0,1440x900@200"
        ))
    }

    @Test("Unchanged screen layout keeps suggestion state")
    func unchangedScreenLayoutKeepsSuggestionState() {
        #expect(!policy.shouldInvalidateSuggestionState(
            hasVisibleSuggestion: true,
            hasPendingSuggestionRequest: true,
            previousScreenLayoutFingerprint: "0,0,1440x900@200",
            currentScreenLayoutFingerprint: "0,0,1440x900@200"
        ))
    }

    @Test("Missing fingerprints fail closed only when suggestion state exists")
    func missingFingerprintsFailClosedOnlyWhenSuggestionStateExists() {
        #expect(policy.shouldInvalidateSuggestionState(
            hasVisibleSuggestion: true,
            hasPendingSuggestionRequest: false,
            previousScreenLayoutFingerprint: nil,
            currentScreenLayoutFingerprint: "0,0,1440x900@200"
        ))
        #expect(!policy.shouldInvalidateSuggestionState(
            hasVisibleSuggestion: false,
            hasPendingSuggestionRequest: false,
            previousScreenLayoutFingerprint: nil,
            currentScreenLayoutFingerprint: "0,0,1440x900@200"
        ))
    }
}
