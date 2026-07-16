import Foundation
import AutocompleteLabCore

/// Whether a generic-fallback fixture must stay silent (a wrong or sensitive field
/// in an arbitrary app) or may present a suggestion (a positively classified safe
/// compose field). The product promise is that wrong-field suggestions are
/// unacceptable, so every non-compose surface in an unknown app must be silent.
public enum GenericAppSafetyExpectation: String, Codable, Equatable, Sendable {
    case silent
    case present
}

/// Field categories exercised under the "Generic App" fallback for arbitrary apps
/// that have no custom compatibility profile. Everything except the two explicit
/// compose controls must be suppressed.
public enum GenericAppSafetyFieldCategory: String, Codable, CaseIterable, Equatable, Sendable {
    case secureField = "secure-field"
    case password
    case payment
    case search
    case urlAddress = "url-address"
    case login
    case formField = "form-field"
    case commandPrompt = "command-prompt"
    case unknownField = "unknown-field"
    case multilineCompose = "multiline-compose"
    case singlelineCompose = "singleline-compose"

    public var expectation: GenericAppSafetyExpectation {
        switch self {
        case .multilineCompose, .singlelineCompose:
            return .present
        case .secureField, .password, .payment, .search, .urlAddress,
             .login, .formField, .commandPrompt, .unknownField:
            return .silent
        }
    }
}

/// A single arbitrary/unknown app + focused-field scenario. Bundle identifiers are
/// intentionally not present in either compatibility registry so every fixture
/// resolves to the generic fallback.
public struct GenericAppSafetyFixture: Equatable, Sendable {
    public let name: String
    public let category: GenericAppSafetyFieldCategory
    public let bundleIdentifier: String
    public let role: String?
    public let subrole: String?
    public let isSecureTextEntry: Bool
    public let fingerprint: FocusedElementFingerprint
    public let fieldClassifierInput: AXFieldClassifierInput
    public let textBeforeCursor: String
    public let textAfterCursor: String
    public let hasCaretRect: Bool

    public init(
        name: String,
        category: GenericAppSafetyFieldCategory,
        bundleIdentifier: String,
        role: String?,
        subrole: String?,
        isSecureTextEntry: Bool = false,
        fingerprint: FocusedElementFingerprint,
        fieldClassifierInput: AXFieldClassifierInput,
        textBeforeCursor: String,
        textAfterCursor: String = "",
        hasCaretRect: Bool = true
    ) {
        self.name = name
        self.category = category
        self.bundleIdentifier = bundleIdentifier
        self.role = role
        self.subrole = subrole
        self.isSecureTextEntry = isSecureTextEntry
        self.fingerprint = fingerprint
        self.fieldClassifierInput = fieldClassifierInput
        self.textBeforeCursor = textBeforeCursor
        self.textAfterCursor = textAfterCursor
        self.hasCaretRect = hasCaretRect
    }

    public var expectation: GenericAppSafetyExpectation { category.expectation }

    /// A neutral block of compose-grade context so suppression of a silent fixture is
    /// attributable to the field, not to a lack of typing context. This stays out of
    /// every emitted trace; the leak check asserts it never appears.
    public static let neutralContext = "the quick brown fox jumps "

    public static let genericFixtures: [GenericAppSafetyFixture] = [
        GenericAppSafetyFixture(
            name: "generic-secure-field",
            category: .secureField,
            bundleIdentifier: "com.example.unknownwriter",
            role: "AXTextField",
            subrole: "AXSecureTextField",
            isSecureTextEntry: true,
            fingerprint: FocusedElementFingerprint(placeholder: "Password", windowTitle: "Sign in"),
            fieldClassifierInput: AXFieldClassifierInput(
                role: "AXTextField",
                subrole: "AXSecureTextField",
                placeholder: "Password",
                windowTitle: "Sign in",
                isSecure: true
            ),
            textBeforeCursor: ""
        ),
        GenericAppSafetyFixture(
            name: "generic-password-hint-field",
            category: .password,
            bundleIdentifier: "net.thirdparty.notesclone",
            role: "AXTextField",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(
                identifier: "login-password",
                placeholder: "Password",
                windowTitle: "Sign in"
            ),
            fieldClassifierInput: AXFieldClassifierInput(
                role: "AXTextField",
                identifier: "login-password",
                placeholder: "Password",
                windowTitle: "Sign in"
            ),
            textBeforeCursor: neutralContext
        ),
        GenericAppSafetyFixture(
            name: "generic-payment-field",
            category: .payment,
            bundleIdentifier: "com.example.shopfront",
            role: "AXTextField",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(
                identifier: "card-number",
                placeholder: "Card number",
                windowTitle: "Checkout"
            ),
            fieldClassifierInput: AXFieldClassifierInput(
                role: "AXTextField",
                identifier: "card-number",
                placeholder: "Card number",
                windowTitle: "Checkout"
            ),
            textBeforeCursor: neutralContext
        ),
        GenericAppSafetyFixture(
            name: "generic-search-field",
            category: .search,
            bundleIdentifier: "org.indie.mysteryeditor",
            role: "AXSearchField",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(placeholder: "Search", windowTitle: "Library"),
            fieldClassifierInput: AXFieldClassifierInput(role: "AXSearchField", placeholder: "Search"),
            textBeforeCursor: neutralContext
        ),
        GenericAppSafetyFixture(
            name: "generic-url-address-field",
            category: .urlAddress,
            bundleIdentifier: "com.example.tabby",
            role: "AXTextField",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(
                identifier: "omnibox",
                placeholder: "Search or enter address",
                windowTitle: "New tab"
            ),
            fieldClassifierInput: AXFieldClassifierInput(
                role: "AXTextField",
                identifier: "omnibox",
                placeholder: "Search or enter address"
            ),
            textBeforeCursor: neutralContext
        ),
        GenericAppSafetyFixture(
            name: "generic-login-field",
            category: .login,
            bundleIdentifier: "net.thirdparty.portal",
            role: "AXTextField",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(
                identifier: "username",
                placeholder: "Username",
                windowTitle: "Sign in"
            ),
            fieldClassifierInput: AXFieldClassifierInput(
                role: "AXTextField",
                identifier: "username",
                placeholder: "Username",
                windowTitle: "Sign in"
            ),
            textBeforeCursor: neutralContext
        ),
        GenericAppSafetyFixture(
            name: "generic-short-form-field",
            category: .formField,
            bundleIdentifier: "com.example.formapp",
            role: "AXTextField",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(title: "Field", windowTitle: "Untitled form"),
            fieldClassifierInput: AXFieldClassifierInput(
                role: "AXTextField",
                identifier: "generic-input",
                title: "Field",
                windowTitle: "Untitled form"
            ),
            textBeforeCursor: neutralContext
        ),
        GenericAppSafetyFixture(
            name: "generic-command-prompt-field",
            category: .commandPrompt,
            bundleIdentifier: "com.example.webconsole",
            role: "AXTextField",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(
                placeholder: "Command line",
                windowTitle: "Web terminal"
            ),
            fieldClassifierInput: AXFieldClassifierInput(
                role: "AXTextField",
                placeholder: "Command line",
                windowTitle: "Web terminal"
            ),
            textBeforeCursor: neutralContext
        ),
        GenericAppSafetyFixture(
            name: "generic-unknown-role-field",
            category: .unknownField,
            bundleIdentifier: "com.example.canvasapp",
            role: "AXGroup",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(windowTitle: "Untitled canvas"),
            fieldClassifierInput: AXFieldClassifierInput(role: "AXGroup", windowTitle: "Untitled canvas"),
            textBeforeCursor: neutralContext
        ),
        GenericAppSafetyFixture(
            name: "generic-multiline-compose",
            category: .multilineCompose,
            bundleIdentifier: "com.example.scratchpad",
            role: "AXTextArea",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(
                identifier: "journal-body",
                placeholder: "Journal entry",
                windowTitle: "Journal"
            ),
            fieldClassifierInput: AXFieldClassifierInput(
                role: "AXTextArea",
                identifier: "journal-body",
                placeholder: "Journal entry",
                windowTitle: "Journal"
            ),
            textBeforeCursor: "Let me jot down a quick "
        ),
        GenericAppSafetyFixture(
            name: "generic-singleline-compose",
            category: .singlelineCompose,
            bundleIdentifier: "net.thirdparty.chatlite",
            role: "AXTextField",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(
                identifier: "composer",
                placeholder: "Message",
                windowTitle: "Chat"
            ),
            fieldClassifierInput: AXFieldClassifierInput(
                role: "AXTextField",
                identifier: "composer",
                placeholder: "Message",
                windowTitle: "Chat"
            ),
            textBeforeCursor: "thanks so much for the "
        )
    ]
}

/// The combined decision for a single fixture across both the named compatibility
/// surface (`CompatibilityRouter`) and the live decision stack the app ships
/// (`CompatibilityProfileStore` + classifier + sensitive policy + activation).
public struct GenericAppSafetyResult: Equatable, Sendable {
    public let fixture: GenericAppSafetyFixture
    public let routerDecision: CompatibilityDecision
    public let supportStatus: CompatibilitySupportStatus
    public let assessment: SensitiveTextFieldAssessment
    public let classification: AXFieldClassification
    public let activationDecision: CompletionActivationDecision

    public init(
        fixture: GenericAppSafetyFixture,
        routerDecision: CompatibilityDecision,
        supportStatus: CompatibilitySupportStatus,
        assessment: SensitiveTextFieldAssessment,
        classification: AXFieldClassification,
        activationDecision: CompletionActivationDecision
    ) {
        self.fixture = fixture
        self.routerDecision = routerDecision
        self.supportStatus = supportStatus
        self.assessment = assessment
        self.classification = classification
        self.activationDecision = activationDecision
    }

    /// The named compatibility surface refuses to request or accept a suggestion.
    public var routerSuppressed: Bool { !routerDecision.shouldRequestSuggestion }

    /// The live stack stays silent (no request reaches the model or the screen).
    public var liveSilent: Bool {
        assessment.isSensitive
            || classification.suppressesSuggestionsByDefault
            || !activationDecision.canSuggest
            || !supportStatus.canToggleSuggestions
    }

    /// Proof that this fixture is genuinely exercising the generic fallback in both
    /// layers, not a known per-app profile.
    public var resolvedToGenericFallback: Bool {
        routerDecision.profile.id == AppCompatibilityProfile.fallback.id
            && isLiveGenericFallback
    }

    private var isLiveGenericFallback: Bool {
        guard case let .supported(profile) = supportStatus else { return false }
        return profile.displayName == "Generic App" && profile.appFamily == .unknown
    }

    /// The whole-result verdict: did both layers agree with the fixture's expectation,
    /// while confirming we are on the generic fallback?
    public var matchesExpectation: Bool {
        guard resolvedToGenericFallback else { return false }
        switch fixture.expectation {
        case .silent:
            return routerSuppressed && liveSilent
        case .present:
            return !routerSuppressed && !liveSilent
        }
    }

    public var traceEventType: String {
        switch fixture.expectation {
        case .silent:
            return "suggestionSuppressed"
        case .present:
            return "suggestionPresented"
        }
    }

    /// Redacted metadata mirrored by `script/check_generic_app_safety_proof.sh`.
    /// Carries only enum-derived decisions and classification reasons — never the
    /// fixture's typed text or any raw value.
    public var traceMetadata: [String: String] {
        var metadata: [String: String] = [
            "genericAppSurface": fixture.name,
            "genericAppFieldCategory": fixture.category.rawValue,
            "genericAppExpectation": fixture.expectation.rawValue,
            "genericAppRouterDecision": routerSuppressed ? "suppressed" : "allowed",
            "genericAppLiveDecision": liveSilent ? "blocked" : "presented",
            "genericAppFallbackResolved": resolvedToGenericFallback ? "true" : "false",
            "fieldKind": classification.kind.rawValue,
            "fieldKindReason": classification.reason,
            "rawTextIncluded": "false"
        ]

        if fixture.expectation == .silent {
            metadata["genericAppSuppressionReason"] =
                routerDecision.suppressionReason?.debugLabel ?? "blocked"
        }

        return metadata
    }
}

/// Deterministic proof that the default-on generic fallback keeps wrong-field and
/// sensitive surfaces silent across arbitrary/unknown apps while still presenting in
/// positively classified compose fields. Pairs with
/// `script/check_generic_app_safety_proof.sh`.
public struct GenericAppSafetyProofHarness: Equatable, Sendable {
    private let router: CompatibilityRouter
    private let routingSettings: CompatibilityRoutingSettings
    private let profileStore: CompatibilityProfileStore
    private let sensitivePolicy: SensitiveTextFieldPolicy
    private let fieldClassifier: AXFieldClassifier
    private let activationPolicy: CompletionActivationPolicy

    public init(
        router: CompatibilityRouter = CompatibilityRouter(),
        routingSettings: CompatibilityRoutingSettings = .mvp,
        profileStore: CompatibilityProfileStore = .mvp,
        sensitivePolicy: SensitiveTextFieldPolicy = SensitiveTextFieldPolicy(),
        fieldClassifier: AXFieldClassifier = AXFieldClassifier(),
        activationPolicy: CompletionActivationPolicy = CompletionActivationPolicy(pace: .normal)
    ) {
        self.router = router
        self.routingSettings = routingSettings
        self.profileStore = profileStore
        self.sensitivePolicy = sensitivePolicy
        self.fieldClassifier = fieldClassifier
        self.activationPolicy = activationPolicy
    }

    public func run(
        fixtures: [GenericAppSafetyFixture] = GenericAppSafetyFixture.genericFixtures
    ) -> [GenericAppSafetyResult] {
        fixtures.map(result)
    }

    private func result(for fixture: GenericAppSafetyFixture) -> GenericAppSafetyResult {
        let routerDecision = router.decision(
            for: CompatibilityEvaluationContext(
                bundleIdentifier: fixture.bundleIdentifier,
                elementRole: fixture.role,
                elementSubrole: fixture.subrole,
                fieldClassifierInput: fixture.fieldClassifierInput,
                isSecureTextEntry: fixture.isSecureTextEntry,
                textBeforeCursor: fixture.textBeforeCursor,
                hasCaretRect: fixture.hasCaretRect
            ),
            settings: routingSettings
        )

        let supportStatus = profileStore.supportStatus(for: fixture.bundleIdentifier)
        let assessment = sensitivePolicy.assessment(
            role: fixture.role,
            subrole: fixture.subrole,
            fingerprint: fixture.fingerprint
        )
        let classification = fieldClassifier.classification(for: fixture.fieldClassifierInput)
        let activationDecision = activationPolicy.decision(
            textBeforeCursor: fixture.textBeforeCursor,
            textAfterCursor: fixture.textAfterCursor,
            isSecure: fixture.isSecureTextEntry || assessment.isSensitive || classification.kind == .secure,
            isFieldSuppressed: assessment.isSensitive || classification.suppressesSuggestionsByDefault,
            fieldKind: classification.kind,
            allowsUnknownFieldKind: allowsUnknownFieldKind(supportStatus)
        )

        return GenericAppSafetyResult(
            fixture: fixture,
            routerDecision: routerDecision,
            supportStatus: supportStatus,
            assessment: assessment,
            classification: classification,
            activationDecision: activationDecision
        )
    }

    private func allowsUnknownFieldKind(_ status: CompatibilitySupportStatus) -> Bool {
        guard case let .supported(profile) = status else { return false }
        return profile.allowsUnknownFieldKind
    }
}
