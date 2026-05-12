import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("App residency policy")
struct AppResidencyPolicyTests {
    @Test("Menu bar agent disables automatic termination")
    func menuBarAgentDisablesAutomaticTermination() {
        #expect(AppResidencyPolicy.activityOptions.contains(.automaticTerminationDisabled))
        #expect(AppResidencyPolicy.automaticTerminationReason.contains("persistent menu bar agent"))
    }
}
