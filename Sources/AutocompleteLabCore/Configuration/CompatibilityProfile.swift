import Foundation

public enum SuggestionRenderMode: String, Equatable, Sendable {
    case inlineAdjacent
    case floatingMirror
    case disabled
}

public enum InsertionMode: String, Equatable, Sendable {
    case axSelectedText
    case axValueReplacement
    case axThenKeyEvents
    case keyEvents
    case clipboardFallbackOptIn
    case disabled
}

public enum FocusedFieldIdentityMode: String, Equatable, Sendable {
    case accessibilityElement
    case stableBounds
}

public struct CompatibilityProfile: Equatable, Sendable {
    public let bundleIdentifier: String
    public let displayName: String
    public let renderMode: SuggestionRenderMode
    public let insertionMode: InsertionMode
    public let fieldIdentityMode: FocusedFieldIdentityMode
    public let supportsOneWordAcceptance: Bool
    public let supportsFullAcceptance: Bool
    public let suppressesUntilBlurAfterEscape: Bool
    public let allowsDescendantTextFallback: Bool
    public let isSensitive: Bool
    public let notes: String

    public init(
        bundleIdentifier: String,
        displayName: String,
        renderMode: SuggestionRenderMode,
        insertionMode: InsertionMode,
        fieldIdentityMode: FocusedFieldIdentityMode = .accessibilityElement,
        supportsOneWordAcceptance: Bool = true,
        supportsFullAcceptance: Bool = true,
        suppressesUntilBlurAfterEscape: Bool = true,
        allowsDescendantTextFallback: Bool = false,
        isSensitive: Bool = false,
        notes: String
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.renderMode = renderMode
        self.insertionMode = insertionMode
        self.fieldIdentityMode = fieldIdentityMode
        self.supportsOneWordAcceptance = supportsOneWordAcceptance
        self.supportsFullAcceptance = supportsFullAcceptance
        self.suppressesUntilBlurAfterEscape = suppressesUntilBlurAfterEscape
        self.allowsDescendantTextFallback = allowsDescendantTextFallback
        self.isSensitive = isSensitive
        self.notes = notes
    }
}

public struct CompatibilityProfileStore: Equatable, Sendable {
    public let profiles: [String: CompatibilityProfile]
    public let denylistedBundleIdentifiers: Set<String>

    public init(
        profiles: [CompatibilityProfile],
        denylistedBundleIdentifiers: Set<String> = Self.defaultDenylist
    ) {
        self.profiles = Dictionary(uniqueKeysWithValues: profiles.map { ($0.bundleIdentifier, $0) })
        self.denylistedBundleIdentifiers = denylistedBundleIdentifiers
    }

    public func profile(for bundleIdentifier: String) -> CompatibilityProfile? {
        guard !denylistedBundleIdentifiers.contains(bundleIdentifier) else {
            return nil
        }

        return profiles[bundleIdentifier]
    }

    public func allows(bundleIdentifier: String) -> Bool {
        profile(for: bundleIdentifier) != nil
    }

    public static let mvp = CompatibilityProfileStore(profiles: [
        CompatibilityProfile(
            bundleIdentifier: "com.apple.TextEdit",
            displayName: "TextEdit",
            renderMode: .inlineAdjacent,
            insertionMode: .axSelectedText,
            notes: "Green reference target. Use for caret geometry, one-word acceptance, and full-accept regression tests."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.apple.Notes",
            displayName: "Notes",
            renderMode: .inlineAdjacent,
            insertionMode: .axSelectedText,
            notes: "Green/yellow rich-text target. Re-probe each focused field because title, note body, and lists can differ."
        ),
        CompatibilityProfile(
            bundleIdentifier: "md.obsidian",
            displayName: "Obsidian",
            renderMode: .floatingMirror,
            insertionMode: .axThenKeyEvents,
            fieldIdentityMode: .stableBounds,
            notes: "Yellow Electron target. Prefer capability probing, mirror-style placement, and verified AX before synthetic key insertion."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.apple.mail",
            displayName: "Mail",
            renderMode: .floatingMirror,
            insertionMode: .axThenKeyEvents,
            fieldIdentityMode: .stableBounds,
            allowsDescendantTextFallback: true,
            notes: "Yellow rich-text compose target. Keep insertion conservative, verify AX writes, and avoid full value replacement."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.google.Chrome",
            displayName: "Chrome",
            renderMode: .floatingMirror,
            insertionMode: .axValueReplacement,
            notes: "Yellow browser target. Verified on a local textarea with AXTextArea, selected range, and settable selected text. Chrome can report zero-height caret bounds, so use mirror anchoring."
        )
    ])

    public static let defaultDenylist: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.apple.keychainaccess",
        "com.1password.1password",
        "com.agilebits.onepassword7"
    ]
}
