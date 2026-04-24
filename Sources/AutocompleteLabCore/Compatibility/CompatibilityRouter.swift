import Foundation

public enum CompatibilityRung: Int, CaseIterable, Comparable, Sendable {
    case blocked = 0
    case detect = 1
    case suggest = 2
    case accept = 3
    case stableBeta = 4
    case supportedCandidate = 5

    public static func < (lhs: CompatibilityRung, rhs: CompatibilityRung) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var allowsSuggestions: Bool {
        self >= .suggest
    }

    public var allowsAcceptance: Bool {
        self >= .accept
    }
}

public enum TextIntegrationPath: String, Equatable, Sendable {
    case nativeAccessibility
    case webExtension
    case editorPlugin
    case overlayOnly
    case blocked
}

public enum SuggestionAcceptMode: String, Equatable, Sendable {
    case none
    case directAccessibility
    case clipboardFallback
    case domExtension
}

public struct CompatibilityRoutingSettings: Equatable, Sendable {
    public let enforceKnownApps: Bool
    public let suppressSecureFields: Bool
    public let minimumCharactersBeforeSuggestion: Int
    public let suppressEmptyText: Bool
    public let suppressImmediatelyAfterNewline: Bool

    public init(
        enforceKnownApps: Bool,
        suppressSecureFields: Bool,
        minimumCharactersBeforeSuggestion: Int,
        suppressEmptyText: Bool,
        suppressImmediatelyAfterNewline: Bool
    ) {
        self.enforceKnownApps = enforceKnownApps
        self.suppressSecureFields = suppressSecureFields
        self.minimumCharactersBeforeSuggestion = max(1, minimumCharactersBeforeSuggestion)
        self.suppressEmptyText = suppressEmptyText
        self.suppressImmediatelyAfterNewline = suppressImmediatelyAfterNewline
    }

    public static let mvp = CompatibilityRoutingSettings(
        enforceKnownApps: true,
        suppressSecureFields: true,
        minimumCharactersBeforeSuggestion: 3,
        suppressEmptyText: true,
        suppressImmediatelyAfterNewline: true
    )
}

public struct CompatibilityEvaluationContext: Equatable, Sendable {
    public let bundleIdentifier: String?
    public let elementRole: String?
    public let elementSubrole: String?
    public let isSecureTextEntry: Bool
    public let textBeforeCursor: String
    public let hasCaretRect: Bool

    public init(
        bundleIdentifier: String?,
        elementRole: String?,
        elementSubrole: String?,
        isSecureTextEntry: Bool,
        textBeforeCursor: String,
        hasCaretRect: Bool
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.elementRole = elementRole
        self.elementSubrole = elementSubrole
        self.isSecureTextEntry = isSecureTextEntry
        self.textBeforeCursor = textBeforeCursor
        self.hasCaretRect = hasCaretRect
    }
}

public enum CompatibilitySuppressionReason: Equatable, Sendable {
    case missingBundleIdentifier
    case unsupportedApp(String)
    case blockedProfile(String)
    case secureTextEntry
    case emptyText
    case afterNewline
    case belowMinimumCharacters(required: Int, actual: Int)
    case missingCaretRect
    case detectOnly(String)
}

public struct CompatibilityDecision: Equatable, Sendable {
    public let profile: AppCompatibilityProfile
    public let rung: CompatibilityRung
    public let textPath: TextIntegrationPath
    public let acceptMode: SuggestionAcceptMode
    public let suppressionReason: CompatibilitySuppressionReason?

    public var shouldRequestSuggestion: Bool {
        suppressionReason == nil && rung.allowsSuggestions
    }

    public var canShowSuggestion: Bool {
        shouldRequestSuggestion
    }

    public var canAcceptSuggestion: Bool {
        shouldRequestSuggestion && rung.allowsAcceptance && acceptMode != .none
    }

    public var allowsClipboardFallback: Bool {
        acceptMode == .clipboardFallback
    }
}

public struct CompatibilityRouter: Equatable, Sendable {
    public let registry: AppCompatibilityRegistry

    public init(registry: AppCompatibilityRegistry = .default) {
        self.registry = registry
    }

    public func decision(
        for context: CompatibilityEvaluationContext,
        settings: CompatibilityRoutingSettings = .mvp
    ) -> CompatibilityDecision {
        guard let bundleIdentifier = context.bundleIdentifier, !bundleIdentifier.isEmpty else {
            return blockedDecision(reason: .missingBundleIdentifier)
        }

        let profile = registry.profile(for: bundleIdentifier)

        if settings.enforceKnownApps, profile.id == AppCompatibilityProfile.fallback.id {
            return CompatibilityDecision(
                profile: profile,
                rung: .blocked,
                textPath: .blocked,
                acceptMode: .none,
                suppressionReason: .unsupportedApp(bundleIdentifier)
            )
        }

        if profile.defaultRung == .blocked || profile.textPath == .blocked {
            return CompatibilityDecision(
                profile: profile,
                rung: .blocked,
                textPath: profile.textPath,
                acceptMode: .none,
                suppressionReason: .blockedProfile(profile.id)
            )
        }

        if settings.suppressSecureFields, context.isSecureTextEntry {
            return CompatibilityDecision(
                profile: profile,
                rung: .blocked,
                textPath: profile.textPath,
                acceptMode: .none,
                suppressionReason: .secureTextEntry
            )
        }

        if settings.suppressEmptyText, context.textBeforeCursor.isEmpty {
            return suppressedDecision(profile: profile, reason: .emptyText)
        }

        if settings.suppressImmediatelyAfterNewline,
           context.textBeforeCursor.last?.isNewline == true {
            return suppressedDecision(profile: profile, reason: .afterNewline)
        }

        let characterCount = context.textBeforeCursor.count
        if characterCount < settings.minimumCharactersBeforeSuggestion {
            return suppressedDecision(
                profile: profile,
                reason: .belowMinimumCharacters(
                    required: settings.minimumCharactersBeforeSuggestion,
                    actual: characterCount
                )
            )
        }

        if !context.hasCaretRect {
            return CompatibilityDecision(
                profile: profile,
                rung: min(profile.defaultRung, .detect),
                textPath: profile.textPath,
                acceptMode: .none,
                suppressionReason: .missingCaretRect
            )
        }

        guard profile.defaultRung.allowsSuggestions else {
            return CompatibilityDecision(
                profile: profile,
                rung: profile.defaultRung,
                textPath: profile.textPath,
                acceptMode: .none,
                suppressionReason: .detectOnly(profile.id)
            )
        }

        return CompatibilityDecision(
            profile: profile,
            rung: profile.defaultRung,
            textPath: profile.textPath,
            acceptMode: profile.acceptMode,
            suppressionReason: nil
        )
    }

    private func blockedDecision(reason: CompatibilitySuppressionReason) -> CompatibilityDecision {
        CompatibilityDecision(
            profile: .fallback,
            rung: .blocked,
            textPath: .blocked,
            acceptMode: .none,
            suppressionReason: reason
        )
    }

    private func suppressedDecision(
        profile: AppCompatibilityProfile,
        reason: CompatibilitySuppressionReason
    ) -> CompatibilityDecision {
        CompatibilityDecision(
            profile: profile,
            rung: min(profile.defaultRung, .detect),
            textPath: profile.textPath,
            acceptMode: .none,
            suppressionReason: reason
        )
    }
}

public extension CompatibilityDecision {
    var debugLabel: String {
        [
            "profile=\(profile.id)",
            "rung=\(rung)",
            "path=\(textPath.rawValue)",
            "accept=\(acceptMode.rawValue)",
            "reason=\(suppressionReason?.debugLabel ?? "allowed")"
        ].joined(separator: " ")
    }
}

public extension CompatibilitySuppressionReason {
    var debugLabel: String {
        switch self {
        case .missingBundleIdentifier:
            return "missing bundle identifier"
        case .unsupportedApp(let bundleIdentifier):
            return "unsupported app \(bundleIdentifier)"
        case .blockedProfile(let profileID):
            return "blocked profile \(profileID)"
        case .secureTextEntry:
            return "secure text entry"
        case .emptyText:
            return "empty text"
        case .afterNewline:
            return "after newline"
        case .belowMinimumCharacters(let required, let actual):
            return "below minimum characters \(actual)/\(required)"
        case .missingCaretRect:
            return "missing caret rect"
        case .detectOnly(let profileID):
            return "detect only \(profileID)"
        }
    }
}
