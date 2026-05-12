import Testing
@testable import AutocompleteLabCore

@Suite("Insertion verification preflight policy")
struct InsertionVerificationPreflightPolicyTests {
    private let policy = InsertionVerificationPreflightPolicy()

    @Test("Allows verification only when the frontmost field still matches")
    func allowsMatchingField() {
        let expected = identity(bundleIdentifier: "com.apple.TextEdit", elementIdentifier: 42)

        #expect(policy.decision(
            expectedFieldIdentity: expected,
            currentContext: .frontmostApplication(
                bundleIdentifier: "com.apple.TextEdit",
                fieldIdentity: expected
            )
        ) == .proceed)
    }

    @Test("Fails when the frontmost app is missing")
    func failsMissingFrontmostApplication() {
        #expect(policy.decision(
            expectedFieldIdentity: identity(),
            currentContext: .missingFrontmostApplication
        ) == .fail(.missingFrontmostApplication))
    }

    @Test("Fails when focus moved to another app")
    func failsChangedFrontmostApplication() {
        #expect(policy.decision(
            expectedFieldIdentity: identity(bundleIdentifier: "com.apple.TextEdit"),
            currentContext: .frontmostApplication(
                bundleIdentifier: "com.openai.codex",
                fieldIdentity: nil
            )
        ) == .fail(.frontmostApplicationChanged))
    }

    @Test("Fails when focused text context cannot be read")
    func failsMissingFocusedTextContext() {
        #expect(policy.decision(
            expectedFieldIdentity: identity(bundleIdentifier: "com.apple.TextEdit"),
            currentContext: .frontmostApplication(
                bundleIdentifier: "com.apple.TextEdit",
                fieldIdentity: nil
            )
        ) == .fail(.missingFocusedTextContext))
    }

    @Test("Fails when focus moved to another field in the same app")
    func failsChangedFocusedField() {
        #expect(policy.decision(
            expectedFieldIdentity: identity(bundleIdentifier: "com.apple.TextEdit", elementIdentifier: 42),
            currentContext: .frontmostApplication(
                bundleIdentifier: "com.apple.TextEdit",
                fieldIdentity: identity(bundleIdentifier: "com.apple.TextEdit", elementIdentifier: 43)
            )
        ) == .fail(.focusedFieldChanged))
    }

    private func identity(
        bundleIdentifier: String = "com.example.App",
        elementIdentifier: Int = 1
    ) -> FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: bundleIdentifier,
            processIdentifier: 123,
            elementIdentifier: elementIdentifier
        )
    }
}
