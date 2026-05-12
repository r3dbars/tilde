import Foundation

public struct SuggestionPrivacySettings: Equatable, Sendable {
    public let isAppAllowlistEnabled: Bool
    public let allowedBundleIdentifiers: Set<String>
    public let suppressSecureFields: Bool
    public let minimumCharactersBeforeSuggestion: Int
    public let suppressEmptyText: Bool
    public let suppressImmediatelyAfterNewline: Bool
    public let debounceMilliseconds: Int
    public let targetLatencyMilliseconds: Int

    public init(
        isAppAllowlistEnabled: Bool,
        allowedBundleIdentifiers: Set<String>,
        suppressSecureFields: Bool,
        minimumCharactersBeforeSuggestion: Int,
        suppressEmptyText: Bool,
        suppressImmediatelyAfterNewline: Bool,
        debounceMilliseconds: Int,
        targetLatencyMilliseconds: Int
    ) {
        self.isAppAllowlistEnabled = isAppAllowlistEnabled
        self.allowedBundleIdentifiers = allowedBundleIdentifiers
        self.suppressSecureFields = suppressSecureFields
        self.minimumCharactersBeforeSuggestion = minimumCharactersBeforeSuggestion
        self.suppressEmptyText = suppressEmptyText
        self.suppressImmediatelyAfterNewline = suppressImmediatelyAfterNewline
        self.debounceMilliseconds = debounceMilliseconds
        self.targetLatencyMilliseconds = targetLatencyMilliseconds
    }

    public static let mvp = SuggestionPrivacySettings(
        isAppAllowlistEnabled: true,
        allowedBundleIdentifiers: [
            "com.apple.TextEdit",
            "com.apple.Notes",
            "md.obsidian"
        ],
        suppressSecureFields: true,
        minimumCharactersBeforeSuggestion: 3,
        suppressEmptyText: true,
        suppressImmediatelyAfterNewline: true,
        debounceMilliseconds: CompletionModelPolicy.mvp.debounceMilliseconds,
        targetLatencyMilliseconds: CompletionModelPolicy.mvp.targetLatencyMilliseconds
    )
}

public struct FocusedSuggestionPrivacyContext: Equatable, Sendable {
    public let bundleIdentifier: String?
    public let textBeforeCursor: String
    public let isSecureTextEntry: Bool

    public init(
        bundleIdentifier: String?,
        textBeforeCursor: String,
        isSecureTextEntry: Bool
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.textBeforeCursor = textBeforeCursor
        self.isSecureTextEntry = isSecureTextEntry
    }
}

public enum SuggestionSuppressionReason: Equatable, Sendable {
    case missingBundleIdentifier
    case bundleIdentifierNotAllowed(String)
    case secureTextEntry
    case emptyText
    case afterNewline
    case belowMinimumCharacters(required: Int, actual: Int)
}

public struct SuggestionPrivacyDecision: Equatable, Sendable {
    public let shouldRequestSuggestion: Bool
    public let suppressionReason: SuggestionSuppressionReason?

    public static let allowed = SuggestionPrivacyDecision(
        shouldRequestSuggestion: true,
        suppressionReason: nil
    )

    public static func suppressed(_ reason: SuggestionSuppressionReason) -> SuggestionPrivacyDecision {
        SuggestionPrivacyDecision(shouldRequestSuggestion: false, suppressionReason: reason)
    }
}

public struct SuggestionPrivacyPolicy: Equatable, Sendable {
    public let settings: SuggestionPrivacySettings

    public init(settings: SuggestionPrivacySettings = .mvp) {
        self.settings = settings
    }

    public func decision(for context: FocusedSuggestionPrivacyContext) -> SuggestionPrivacyDecision {
        if settings.isAppAllowlistEnabled {
            guard let bundleIdentifier = context.bundleIdentifier, !bundleIdentifier.isEmpty else {
                return .suppressed(.missingBundleIdentifier)
            }

            guard settings.allowedBundleIdentifiers.contains(bundleIdentifier) else {
                return .suppressed(.bundleIdentifierNotAllowed(bundleIdentifier))
            }
        }

        if settings.suppressSecureFields, context.isSecureTextEntry {
            return .suppressed(.secureTextEntry)
        }

        if settings.suppressEmptyText, context.textBeforeCursor.isEmpty {
            return .suppressed(.emptyText)
        }

        if settings.suppressImmediatelyAfterNewline,
           context.textBeforeCursor.last?.isNewline == true {
            return .suppressed(.afterNewline)
        }

        let characterCount = context.textBeforeCursor.count
        if characterCount < settings.minimumCharactersBeforeSuggestion {
            return .suppressed(
                .belowMinimumCharacters(
                    required: settings.minimumCharactersBeforeSuggestion,
                    actual: characterCount
                )
            )
        }

        return .allowed
    }

    public func shouldRequestSuggestion(for context: FocusedSuggestionPrivacyContext) -> Bool {
        decision(for: context).shouldRequestSuggestion
    }
}
