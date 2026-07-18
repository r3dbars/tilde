import AutocompleteLabCore
import Testing

@Suite("Manual suggestion retry policy")
struct ManualSuggestionRetryPolicyTests {
    @Test("keeps the measured manual retry delay")
    func keepsMeasuredManualRetryDelay() {
        #expect(ManualSuggestionRetryPolicy().delayMilliseconds == 150)
        #expect(ManualSuggestionRetryPolicy(delayMilliseconds: 0).delayMilliseconds == 1)
    }
}
