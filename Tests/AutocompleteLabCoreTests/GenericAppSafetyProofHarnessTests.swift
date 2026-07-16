import Testing
@testable import AutocompleteLabCore
@testable import AutocompleteLabResearch

@Suite("Generic app fallback safety proof")
struct GenericAppSafetyProofHarnessTests {
    private let results = GenericAppSafetyProofHarness().run()

    private func result(_ name: String) -> GenericAppSafetyResult {
        guard let match = results.first(where: { $0.fixture.name == name }) else {
            fatalError("missing generic-app fixture \(name)")
        }
        return match
    }

    @Test("Every fixture is genuinely on the Generic App fallback")
    func everyFixtureResolvesToGenericFallback() {
        #expect(!results.isEmpty)
        for result in results {
            #expect(
                result.resolvedToGenericFallback,
                "\(result.fixture.name) did not resolve to the generic fallback in both layers"
            )
            #expect(result.routerDecision.profile.id == AppCompatibilityProfile.fallback.id)
            #expect(result.routerDecision.profile.displayName == "Generic App")
        }
    }

    @Test("Wrong and sensitive fields stay silent in both compatibility layers")
    func wrongAndSensitiveFieldsStaySilent() {
        let silent = results.filter { $0.fixture.expectation == .silent }
        #expect(!silent.isEmpty)
        for result in silent {
            #expect(result.routerSuppressed, "router presented \(result.fixture.name)")
            #expect(result.liveSilent, "live stack presented \(result.fixture.name)")
            #expect(result.routerDecision.suppressionReason != nil)
            #expect(!result.routerDecision.canShowSuggestion)
            #expect(!result.routerDecision.canAcceptSuggestion)
            #expect(!result.activationDecision.canSuggest)
            #expect(result.matchesExpectation)
        }
    }

    @Test("The generic fallback still presents in positively classified compose fields")
    func genericFallbackPresentsInComposeFields() {
        let present = results.filter { $0.fixture.expectation == .present }
        #expect(present.count >= 2)
        for result in present {
            #expect(!result.routerSuppressed, "router suppressed safe compose \(result.fixture.name)")
            #expect(!result.liveSilent, "live stack suppressed safe compose \(result.fixture.name)")
            #expect(result.routerDecision.canShowSuggestion)
            #expect(result.routerDecision.canAcceptSuggestion)
            #expect(result.routerDecision.acceptMode == .directAccessibility)
            #expect(result.activationDecision.canSuggest)
            #expect(result.matchesExpectation)
        }
    }

    @Test("Every generic field category is exercised")
    func everyCategoryIsExercised() {
        let covered = Set(results.map(\.fixture.category))
        #expect(covered == Set(GenericAppSafetyFieldCategory.allCases))
    }

    @Test("Required sensitive and wrong-field categories are suppressed")
    func requiredSilentCategoriesAreSuppressed() {
        let requiredSilent: [GenericAppSafetyFieldCategory] = [
            .secureField, .password, .payment, .search, .urlAddress,
            .login, .formField, .commandPrompt, .unknownField
        ]
        let silentCategories = Set(
            results.filter { $0.routerSuppressed && $0.liveSilent }.map(\.fixture.category)
        )
        for category in requiredSilent {
            #expect(silentCategories.contains(category), "\(category.rawValue) was not suppressed")
        }
    }

    @Test("Trace metadata is redacted and decision-consistent")
    func traceMetadataIsRedactedAndConsistent() {
        for result in results {
            let metadata = result.traceMetadata
            #expect(metadata["rawTextIncluded"] == "false")
            #expect(metadata["genericAppFallbackResolved"] == "true")
            #expect(metadata["genericAppFieldCategory"] == result.fixture.category.rawValue)
            #expect(metadata["genericAppExpectation"] == result.fixture.expectation.rawValue)

            switch result.fixture.expectation {
            case .silent:
                #expect(metadata["genericAppRouterDecision"] == "suppressed")
                #expect(metadata["genericAppLiveDecision"] == "blocked")
                #expect(result.traceEventType == "suggestionSuppressed")
            case .present:
                #expect(metadata["genericAppRouterDecision"] == "allowed")
                #expect(metadata["genericAppLiveDecision"] == "presented")
                #expect(result.traceEventType == "suggestionPresented")
            }

            // No fixture typed text may appear anywhere in the emitted metadata.
            let joined = metadata.values.joined(separator: " ")
            #expect(!joined.contains(GenericAppSafetyFixture.neutralContext.trimmingCharacters(in: .whitespaces)))
            #expect(!joined.contains(result.fixture.textBeforeCursor) || result.fixture.textBeforeCursor.isEmpty)
        }
    }

    @Test("Named CompatibilityRouter blocks every wrong field kind for unknown apps")
    func routerBlocksWrongFieldKindsForUnknownApps() {
        let router = CompatibilityRouter()
        let cases: [(String, AXFieldClassifierInput, Bool)] = [
            ("secure", AXFieldClassifierInput(role: "AXTextField", subrole: "AXSecureTextField", placeholder: "Password", isSecure: true), true),
            ("search", AXFieldClassifierInput(role: "AXSearchField", placeholder: "Search"), false),
            ("url", AXFieldClassifierInput(role: "AXTextField", identifier: "omnibox", placeholder: "Search or enter address"), false),
            ("login-form", AXFieldClassifierInput(role: "AXTextField", identifier: "username", placeholder: "Username"), false),
            ("payment-form", AXFieldClassifierInput(role: "AXTextField", identifier: "card-number", placeholder: "Card number"), false),
            ("command-prompt", AXFieldClassifierInput(role: "AXTextField", placeholder: "Command line", windowTitle: "Web terminal"), false),
            ("unknown-role", AXFieldClassifierInput(role: "AXGroup"), false)
        ]

        for (label, input, isSecure) in cases {
            let decision = router.decision(
                for: CompatibilityEvaluationContext(
                    bundleIdentifier: "com.example.\(label).unknownapp",
                    elementRole: input.role,
                    elementSubrole: input.subrole,
                    fieldClassifierInput: input,
                    isSecureTextEntry: isSecure,
                    textBeforeCursor: "the quick brown fox jumps ",
                    hasCaretRect: true
                ),
                settings: .mvp
            )

            #expect(decision.profile.id == AppCompatibilityProfile.fallback.id, "\(label) left the fallback")
            #expect(!decision.shouldRequestSuggestion, "\(label) was not suppressed under generic fallback")
            #expect(decision.rung == .blocked)
            #expect(decision.acceptMode == .none)
            #expect(decision.suppressionReason != nil)
        }
    }

    @Test("Generic fallback requires a validated caret before suggesting")
    func genericFallbackRequiresValidatedCaret() {
        let decision = CompatibilityRouter().decision(
            for: CompatibilityEvaluationContext(
                bundleIdentifier: "com.example.scratchpad",
                elementRole: "AXTextArea",
                elementSubrole: nil,
                fieldClassifierInput: AXFieldClassifierInput(role: "AXTextArea", placeholder: "Journal entry"),
                isSecureTextEntry: false,
                textBeforeCursor: "Let me jot down a quick ",
                hasCaretRect: false
            ),
            settings: .mvp
        )

        #expect(decision.profile.id == AppCompatibilityProfile.fallback.id)
        #expect(decision.suppressionReason == .missingCaretRect)
        #expect(!decision.shouldRequestSuggestion)
        #expect(!decision.canAcceptSuggestion)
    }
}
