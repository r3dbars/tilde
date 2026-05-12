import Foundation

public enum SensitiveFieldProofLevel: String, Codable, Equatable, Sendable {
    case localFixture
    case boundedNative
    case boundedBrowser
}

public struct SensitiveFieldProofFixture: Equatable, Sendable {
    public let name: String
    public let category: SensitiveFieldProofCategory
    public let proofLevel: SensitiveFieldProofLevel
    public let bundleIdentifier: String
    public let role: String?
    public let subrole: String?
    public let fingerprint: FocusedElementFingerprint
    public let textBeforeCursor: String
    public let textAfterCursor: String
    public let fieldClassifierInput: AXFieldClassifierInput

    public init(
        name: String,
        category: SensitiveFieldProofCategory,
        proofLevel: SensitiveFieldProofLevel,
        bundleIdentifier: String,
        role: String?,
        subrole: String?,
        fingerprint: FocusedElementFingerprint,
        textBeforeCursor: String = "",
        textAfterCursor: String = "",
        fieldClassifierInput: AXFieldClassifierInput
    ) {
        self.name = name
        self.category = category
        self.proofLevel = proofLevel
        self.bundleIdentifier = bundleIdentifier
        self.role = role
        self.subrole = subrole
        self.fingerprint = fingerprint
        self.textBeforeCursor = textBeforeCursor
        self.textAfterCursor = textAfterCursor
        self.fieldClassifierInput = fieldClassifierInput
    }

    public static let betaSensitiveFixtures: [SensitiveFieldProofFixture] = [
        SensitiveFieldProofFixture(
            name: "native-password-field",
            category: .password,
            proofLevel: .boundedNative,
            bundleIdentifier: "com.apple.TextEdit",
            role: "AXTextField",
            subrole: "AXSecureTextField",
            fingerprint: FocusedElementFingerprint(placeholder: "Password", windowTitle: "Sign in"),
            fieldClassifierInput: AXFieldClassifierInput(role: "AXTextField", subrole: "AXSecureTextField", placeholder: "Password", isSecure: true)
        ),
        SensitiveFieldProofFixture(
            name: "browser-otp-field",
            category: .otp,
            proofLevel: .boundedBrowser,
            bundleIdentifier: "com.apple.Safari",
            role: "AXTextField",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(identifier: "one-time-code", placeholder: "Verification code", windowTitle: "Sign in"),
            textBeforeCursor: "Verification code: 123456",
            fieldClassifierInput: AXFieldClassifierInput(role: "AXTextField", identifier: "one-time-code", placeholder: "Verification code", windowTitle: "Sign in")
        ),
        SensitiveFieldProofFixture(
            name: "browser-payment-field",
            category: .payment,
            proofLevel: .boundedBrowser,
            bundleIdentifier: "com.google.Chrome",
            role: "AXTextField",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(identifier: "card-number", placeholder: "Card number", windowTitle: "Checkout"),
            textBeforeCursor: "4242 4242 4242 4242",
            fieldClassifierInput: AXFieldClassifierInput(role: "AXTextField", identifier: "card-number", placeholder: "Card number", windowTitle: "Checkout")
        ),
        SensitiveFieldProofFixture(
            name: "login-field",
            category: .login,
            proofLevel: .localFixture,
            bundleIdentifier: "com.apple.Safari",
            role: "AXTextField",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(identifier: "username", placeholder: "Username", windowTitle: "Sign in"),
            fieldClassifierInput: AXFieldClassifierInput(role: "AXTextField", identifier: "username", placeholder: "Username", windowTitle: "Sign in")
        ),
        SensitiveFieldProofFixture(
            name: "search-field",
            category: .search,
            proofLevel: .boundedNative,
            bundleIdentifier: "com.apple.Safari",
            role: "AXSearchField",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(placeholder: "Search", windowTitle: "Search"),
            fieldClassifierInput: AXFieldClassifierInput(role: "AXSearchField", placeholder: "Search")
        ),
        SensitiveFieldProofFixture(
            name: "browser-address-field",
            category: .urlAddress,
            proofLevel: .boundedBrowser,
            bundleIdentifier: "com.google.Chrome",
            role: "AXTextField",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(identifier: "omnibox", placeholder: "Search or enter address", windowTitle: "example.invalid"),
            textBeforeCursor: "example.invalid",
            fieldClassifierInput: AXFieldClassifierInput(role: "AXTextField", identifier: "omnibox", placeholder: "Search or enter address")
        ),
        SensitiveFieldProofFixture(
            name: "shipping-address-field",
            category: .address,
            proofLevel: .boundedBrowser,
            bundleIdentifier: "com.google.Chrome",
            role: "AXTextField",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(identifier: "shipping-address", placeholder: "Shipping address", windowTitle: "Checkout"),
            textBeforeCursor: "1600 Amphitheatre Parkway",
            fieldClassifierInput: AXFieldClassifierInput(role: "AXTextField", identifier: "shipping-address", placeholder: "Shipping address", windowTitle: "Checkout")
        ),
        SensitiveFieldProofFixture(
            name: "browser-command-line-field",
            category: .commandLine,
            proofLevel: .boundedBrowser,
            bundleIdentifier: "com.google.Chrome",
            role: "AXTextField",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(identifier: "terminal-command", placeholder: "Command line", windowTitle: "Web terminal"),
            textBeforeCursor: "rm -rf local-fixture",
            fieldClassifierInput: AXFieldClassifierInput(role: "AXTextField", identifier: "terminal-command", placeholder: "Command line", windowTitle: "Web terminal")
        ),
        SensitiveFieldProofFixture(
            name: "api-key-like-field",
            category: .apiKeyLikeText,
            proofLevel: .localFixture,
            bundleIdentifier: "com.apple.TextEdit",
            role: "AXTextArea",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(placeholder: "API key", windowTitle: "Developer settings"),
            textBeforeCursor: "sk-LOCALTEST000000000000",
            fieldClassifierInput: AXFieldClassifierInput(role: "AXTextArea", placeholder: "API key", windowTitle: "Developer settings")
        ),
        SensitiveFieldProofFixture(
            name: "password-manager-window",
            category: .passwordManager,
            proofLevel: .boundedNative,
            bundleIdentifier: "com.1password.1password",
            role: "AXTextField",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(title: "1Password", placeholder: "Search 1Password", windowTitle: "1Password"),
            fieldClassifierInput: AXFieldClassifierInput(role: "AXTextField", title: "1Password", placeholder: "Search 1Password", windowTitle: "1Password")
        ),
        SensitiveFieldProofFixture(
            name: "private-prompt-field",
            category: .privatePrompt,
            proofLevel: .localFixture,
            bundleIdentifier: "com.openai.chat",
            role: "AXTextArea",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(placeholder: "Private prompt", windowTitle: "Private chat"),
            fieldClassifierInput: AXFieldClassifierInput(role: "AXTextArea", placeholder: "Private prompt", windowTitle: "Private chat")
        ),
        SensitiveFieldProofFixture(
            name: "private-search-field",
            category: .privateSearch,
            proofLevel: .boundedBrowser,
            bundleIdentifier: "com.apple.Safari",
            role: "AXSearchField",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(placeholder: "Private Search", windowTitle: "Private Browsing"),
            fieldClassifierInput: AXFieldClassifierInput(role: "AXSearchField", placeholder: "Private Search", windowTitle: "Private Browsing")
        )
    ]
}

public struct SensitiveFieldProofResult: Equatable, Sendable {
    public let fixture: SensitiveFieldProofFixture
    public let assessment: SensitiveTextFieldAssessment
    public let fieldClassification: AXFieldClassification
    public let activationDecision: CompletionActivationDecision
    public let supportStatus: CompatibilitySupportStatus

    public var isSilent: Bool {
        assessment.isSensitive
            || fieldClassification.suppressesSuggestionsByDefault
            || !activationDecision.canSuggest
            || !supportStatus.canPresentSuggestions
    }

    public var traceMetadata: [String: String] {
        var metadata = assessment.traceMetadata
        metadata["sensitivePolicyCategory"] = assessment.category?.rawValue ?? "none"
        metadata["sensitiveSuppressionCategory"] = fixture.category.rawValue
        metadata["sensitiveSuppressionProof"] = fixture.proofLevel.rawValue
        metadata["sensitiveSuppressionDecision"] = isSilent ? "blocked" : "presented"
        metadata["fieldKind"] = fieldClassification.kind.rawValue
        metadata["fieldKindReason"] = fieldClassification.reason
        metadata["supportLevel"] = supportStatus.supportLevel.rawValue
        metadata["rawTextIncluded"] = "false"
        return metadata
    }
}

public struct SensitiveFieldProofHarness: Equatable, Sendable {
    private let sensitivePolicy: SensitiveTextFieldPolicy
    private let fieldClassifier: AXFieldClassifier
    private let activationPolicy: CompletionActivationPolicy
    private let compatibilityStore: CompatibilityProfileStore

    public init(
        sensitivePolicy: SensitiveTextFieldPolicy = SensitiveTextFieldPolicy(),
        fieldClassifier: AXFieldClassifier = AXFieldClassifier(),
        activationPolicy: CompletionActivationPolicy = CompletionActivationPolicy(pace: .normal),
        compatibilityStore: CompatibilityProfileStore = .mvp
    ) {
        self.sensitivePolicy = sensitivePolicy
        self.fieldClassifier = fieldClassifier
        self.activationPolicy = activationPolicy
        self.compatibilityStore = compatibilityStore
    }

    public func run(
        fixtures: [SensitiveFieldProofFixture] = SensitiveFieldProofFixture.betaSensitiveFixtures
    ) -> [SensitiveFieldProofResult] {
        fixtures.map(result)
    }

    private func result(for fixture: SensitiveFieldProofFixture) -> SensitiveFieldProofResult {
        let assessment = sensitivePolicy.assessment(
            role: fixture.role,
            subrole: fixture.subrole,
            fingerprint: fixture.fingerprint
        )
        let classification = fieldClassifier.classification(for: fixture.fieldClassifierInput)
        let supportStatus = compatibilityStore.supportStatus(for: fixture.bundleIdentifier)
        let activationDecision = activationPolicy.decision(
            textBeforeCursor: fixture.textBeforeCursor,
            textAfterCursor: fixture.textAfterCursor,
            isSecure: assessment.isSensitive || classification.kind == .secure,
            isFieldSuppressed: assessment.isSensitive || classification.suppressesSuggestionsByDefault,
            fieldKind: classification.kind,
            allowsUnknownFieldKind: supportStatus.allowsUnknownFieldKind
        )

        return SensitiveFieldProofResult(
            fixture: fixture,
            assessment: assessment,
            fieldClassification: classification,
            activationDecision: activationDecision,
            supportStatus: supportStatus
        )
    }
}

private extension CompatibilitySupportStatus {
    var canPresentSuggestions: Bool {
        switch self {
        case let .supported(profile):
            profile.canPresentSuggestions && !profile.isSensitive
        case .denylisted, .unsupported:
            false
        }
    }

    var allowsUnknownFieldKind: Bool {
        switch self {
        case let .supported(profile):
            profile.allowsUnknownFieldKind
        case .denylisted, .unsupported:
            false
        }
    }
}
