import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion privacy policy")
struct SuggestionPrivacyPolicyTests {
    @Test("MVP settings keep suggestions allowlisted and local-friendly")
    func mvpSettings() {
        let settings = SuggestionPrivacySettings.mvp

        #expect(settings.isAppAllowlistEnabled)
        #expect(settings.allowedBundleIdentifiers.contains("com.apple.TextEdit"))
        #expect(!settings.allowedBundleIdentifiers.contains("com.apple.mail"))
        #expect(settings.suppressSecureFields)
        #expect(settings.minimumCharactersBeforeSuggestion == 3)
        #expect(settings.suppressEmptyText)
        #expect(settings.suppressImmediatelyAfterNewline)
        #expect(settings.debounceMilliseconds == CompletionModelPolicy.mvp.debounceMilliseconds)
        #expect(settings.targetLatencyMilliseconds == CompletionModelPolicy.mvp.targetLatencyMilliseconds)
    }

    @Test("Mail stays outside the default allowlist")
    func mailStaysOutsideTheDefaultAllowlist() {
        let policy = SuggestionPrivacyPolicy()
        let context = FocusedSuggestionPrivacyContext(
            bundleIdentifier: "com.apple.mail",
            textBeforeCursor: "Private email draft",
            isSecureTextEntry: false
        )

        #expect(policy.decision(for: context) == .suppressed(.bundleIdentifierNotAllowed("com.apple.mail")))
    }

    @Test("Allowed app with enough plain text can request a suggestion")
    func allowedContextCanRequestSuggestion() {
        let policy = SuggestionPrivacyPolicy()
        let context = FocusedSuggestionPrivacyContext(
            bundleIdentifier: "com.apple.TextEdit",
            textBeforeCursor: "Ship",
            isSecureTextEntry: false
        )

        #expect(policy.decision(for: context) == .allowed)
        #expect(policy.shouldRequestSuggestion(for: context))
    }

    @Test("Missing bundle identifier is suppressed while allowlist is enabled")
    func missingBundleIdentifierIsSuppressed() {
        let policy = SuggestionPrivacyPolicy()
        let context = FocusedSuggestionPrivacyContext(
            bundleIdentifier: nil,
            textBeforeCursor: "Ship",
            isSecureTextEntry: false
        )

        #expect(policy.decision(for: context) == .suppressed(.missingBundleIdentifier))
    }

    @Test("Apps outside the allowlist are suppressed")
    func unallowedBundleIdentifierIsSuppressed() {
        let policy = SuggestionPrivacyPolicy()
        let context = FocusedSuggestionPrivacyContext(
            bundleIdentifier: "com.example.Unknown",
            textBeforeCursor: "Ship",
            isSecureTextEntry: false
        )

        #expect(
            policy.decision(for: context) == .suppressed(
                .bundleIdentifierNotAllowed("com.example.Unknown")
            )
        )
    }

    @Test("Allowlist can be turned off for tests and experiments")
    func allowlistCanBeDisabled() {
        let settings = SuggestionPrivacySettings(
            isAppAllowlistEnabled: false,
            allowedBundleIdentifiers: [],
            suppressSecureFields: true,
            minimumCharactersBeforeSuggestion: 3,
            suppressEmptyText: true,
            suppressImmediatelyAfterNewline: true,
            debounceMilliseconds: 200,
            targetLatencyMilliseconds: 700
        )
        let policy = SuggestionPrivacyPolicy(settings: settings)
        let context = FocusedSuggestionPrivacyContext(
            bundleIdentifier: nil,
            textBeforeCursor: "Ship",
            isSecureTextEntry: false
        )

        #expect(policy.decision(for: context) == .allowed)
    }

    @Test("Secure fields are suppressed")
    func secureFieldsAreSuppressed() {
        let policy = SuggestionPrivacyPolicy()
        let context = FocusedSuggestionPrivacyContext(
            bundleIdentifier: "com.apple.TextEdit",
            textBeforeCursor: "secret",
            isSecureTextEntry: true
        )

        #expect(policy.decision(for: context) == .suppressed(.secureTextEntry))
    }

    @Test("Empty text is suppressed")
    func emptyTextIsSuppressed() {
        let policy = SuggestionPrivacyPolicy()
        let context = FocusedSuggestionPrivacyContext(
            bundleIdentifier: "com.apple.TextEdit",
            textBeforeCursor: "",
            isSecureTextEntry: false
        )

        #expect(policy.decision(for: context) == .suppressed(.emptyText))
    }

    @Test("Text immediately after a newline is suppressed")
    func textAfterNewlineIsSuppressed() {
        let policy = SuggestionPrivacyPolicy()
        let context = FocusedSuggestionPrivacyContext(
            bundleIdentifier: "com.apple.TextEdit",
            textBeforeCursor: "Hello\n",
            isSecureTextEntry: false
        )

        #expect(policy.decision(for: context) == .suppressed(.afterNewline))
    }

    @Test("Text below the minimum character count is suppressed")
    func textBelowMinimumCharacterCountIsSuppressed() {
        let policy = SuggestionPrivacyPolicy()
        let context = FocusedSuggestionPrivacyContext(
            bundleIdentifier: "com.apple.TextEdit",
            textBeforeCursor: "Hi",
            isSecureTextEntry: false
        )

        #expect(
            policy.decision(for: context) == .suppressed(
                .belowMinimumCharacters(required: 3, actual: 2)
            )
        )
    }
}
