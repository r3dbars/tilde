import Testing
@testable import AutocompleteLabCore

@Suite("Insertion target identity guard")
struct InsertionTargetIdentityGuardTests {
    private let guardPolicy = InsertionTargetIdentityGuard()

    private func identity(
        bundle: String = "com.apple.TextEdit",
        pid: Int32 = 4321,
        element: Int = 42
    ) -> FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: bundle,
            processIdentifier: pid,
            elementIdentifier: element
        )
    }

    @Test("Allows a write when the live target matches the validated identity")
    func allowsMatchingTarget() {
        let expected = identity()
        #expect(guardPolicy.decision(expected: expected, current: expected) == .allow)
    }

    @Test("Refuses the write when the application changed (cross-app injection)")
    func blocksDifferentApplication() {
        let expected = identity(bundle: "com.apple.TextEdit", pid: 100, element: 42)
        let current = identity(bundle: "com.malicious.app", pid: 100, element: 42)

        #expect(guardPolicy.decision(expected: expected, current: current) == .block(.appChanged))
    }

    @Test("Refuses the write when the pid changed even if the bundle id matches (spoofing)")
    func blocksDifferentProcessIdentifier() {
        let expected = identity(bundle: "com.google.Chrome", pid: 100, element: 42)
        let current = identity(bundle: "com.google.Chrome", pid: 200, element: 42)

        #expect(guardPolicy.decision(expected: expected, current: current) == .block(.appChanged))
    }

    @Test("Refuses the write when focus moved to a different element in the same app")
    func blocksDifferentElement() {
        let expected = identity(element: 42)
        let current = identity(element: 43)

        #expect(guardPolicy.decision(expected: expected, current: current) == .block(.fieldChanged))
    }

    @Test("Fails closed when the live target cannot be resolved")
    func blocksMissingCurrentTarget() {
        #expect(
            guardPolicy.decision(expected: identity(), current: nil)
                == .block(.missingCurrentTarget)
        )
    }

    @Test("Descendant fallback tolerates an element change but still enforces app identity")
    func descendantFallbackToleratesElementChange() {
        let expected = identity(element: 42)
        let differentElementSameApp = identity(element: 9_999)

        #expect(
            guardPolicy.decision(
                expected: expected,
                current: differentElementSameApp,
                requireElementMatch: false
            ) == .allow
        )

        let differentApp = identity(bundle: "com.malicious.app", element: 9_999)
        #expect(
            guardPolicy.decision(
                expected: expected,
                current: differentApp,
                requireElementMatch: false
            ) == .block(.appChanged)
        )
    }

    @Test("Decision conveniences expose allow/block state")
    func decisionConveniences() {
        #expect(InsertionTargetIdentityDecision.allow.isAllowed)
        #expect(InsertionTargetIdentityDecision.allow.blockReason == nil)
        #expect(!InsertionTargetIdentityDecision.block(.appChanged).isAllowed)
        #expect(InsertionTargetIdentityDecision.block(.fieldChanged).blockReason == .fieldChanged)
    }
}
