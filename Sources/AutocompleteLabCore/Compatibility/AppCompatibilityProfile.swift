import CoreGraphics
import Foundation

public enum LineRectPolicy: String, Equatable, Sendable {
    case trustAfterValidation
    case caretOnly
}

public enum BoundaryClipPolicy: String, Equatable, Sendable {
    case clipToFocusedTextElementWhenCaretInside
    case clipToFocusedTextElement
    case ignoreFocusedTextElement
}

/// Placement-tuning-only catalog: which line-rect/boundary trust policy and
/// which geometry tolerances to use for `InlineGhostPlacementResolver`. This
/// is *not* a suggestion/insertion gate — that authority is
/// `CompatibilityProfileStore` (exact bundle-id match, keyed off the live
/// runtime `CompatibilityProfile`). This type used to also carry a
/// `defaultRung`/`textPath`/`acceptMode` that looked like a second gate but
/// were never read by anything outside this type and its own tests; they were
/// removed so there is exactly one decision authority for "can this app get
/// suggestions" and exactly one (this one) for "where should the ghost text
/// go," with prefix-matching kept here because placement tuning is often
/// shared across a family of related bundle identifiers (browsers, chat
/// apps) that the live gate tracks individually.
public struct AppCompatibilityProfile: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let bundleIdentifierPrefixes: [String]
    public let lineRectPolicy: LineRectPolicy
    public let boundaryClipPolicy: BoundaryClipPolicy
    public let maximumLineHeightMultiplier: CGFloat
    public let minimumLineHeightAllowance: CGFloat
    public let verticalToleranceMultiplier: CGFloat
    public let minimumVerticalTolerance: CGFloat
    public let edgePadding: CGFloat
    public let minimumVisibleWidth: CGFloat

    public init(
        id: String,
        displayName: String,
        bundleIdentifierPrefixes: [String],
        lineRectPolicy: LineRectPolicy = .caretOnly,
        boundaryClipPolicy: BoundaryClipPolicy = .clipToFocusedTextElementWhenCaretInside,
        maximumLineHeightMultiplier: CGFloat = 1.8,
        minimumLineHeightAllowance: CGFloat = 8,
        verticalToleranceMultiplier: CGFloat = 0.75,
        minimumVerticalTolerance: CGFloat = 6,
        edgePadding: CGFloat = 4,
        minimumVisibleWidth: CGFloat = 8
    ) {
        self.id = id
        self.displayName = displayName
        self.bundleIdentifierPrefixes = bundleIdentifierPrefixes
        self.lineRectPolicy = lineRectPolicy
        self.boundaryClipPolicy = boundaryClipPolicy
        self.maximumLineHeightMultiplier = maximumLineHeightMultiplier
        self.minimumLineHeightAllowance = minimumLineHeightAllowance
        self.verticalToleranceMultiplier = verticalToleranceMultiplier
        self.minimumVerticalTolerance = minimumVerticalTolerance
        self.edgePadding = edgePadding
        self.minimumVisibleWidth = minimumVisibleWidth
    }

    public func matches(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else {
            return false
        }

        return bundleIdentifierPrefixes.contains { prefix in
            bundleIdentifier == prefix || bundleIdentifier.hasPrefix(prefix + ".")
        }
    }

    public static let fallback = AppCompatibilityProfile(
        id: "fallback",
        displayName: "Generic App",
        bundleIdentifierPrefixes: [],
        lineRectPolicy: .caretOnly,
        boundaryClipPolicy: .clipToFocusedTextElementWhenCaretInside
    )
}

public struct AppCompatibilityRegistry: Equatable, Sendable {
    public let profiles: [AppCompatibilityProfile]
    public let fallbackProfile: AppCompatibilityProfile

    public init(
        profiles: [AppCompatibilityProfile] = Self.defaultProfiles,
        fallbackProfile: AppCompatibilityProfile = .fallback
    ) {
        self.profiles = profiles
        self.fallbackProfile = fallbackProfile
    }

    public func profile(for bundleIdentifier: String?) -> AppCompatibilityProfile {
        profiles.first { $0.matches(bundleIdentifier: bundleIdentifier) } ?? fallbackProfile
    }

    public static let `default` = AppCompatibilityRegistry()

    public static let defaultProfiles: [AppCompatibilityProfile] = [
        AppCompatibilityProfile(
            id: "textedit",
            displayName: "TextEdit",
            bundleIdentifierPrefixes: ["com.apple.TextEdit"],
            lineRectPolicy: .caretOnly,
            boundaryClipPolicy: .clipToFocusedTextElementWhenCaretInside
        ),
        AppCompatibilityProfile(
            id: "notes",
            displayName: "Apple Notes",
            bundleIdentifierPrefixes: ["com.apple.Notes"],
            lineRectPolicy: .trustAfterValidation,
            boundaryClipPolicy: .clipToFocusedTextElementWhenCaretInside,
            verticalToleranceMultiplier: 1.2
        ),
        AppCompatibilityProfile(
            id: "mail",
            displayName: "Apple Mail",
            bundleIdentifierPrefixes: ["com.apple.mail"],
            lineRectPolicy: .trustAfterValidation,
            boundaryClipPolicy: .clipToFocusedTextElementWhenCaretInside
        ),
        AppCompatibilityProfile(
            id: "obsidian",
            displayName: "Obsidian",
            bundleIdentifierPrefixes: ["md.obsidian"],
            lineRectPolicy: .caretOnly,
            boundaryClipPolicy: .clipToFocusedTextElementWhenCaretInside,
            maximumLineHeightMultiplier: 1.45,
            verticalToleranceMultiplier: 0.65
        ),
        AppCompatibilityProfile(
            id: "notion-blocked",
            displayName: "Notion",
            bundleIdentifierPrefixes: ["notion.id"],
            lineRectPolicy: .caretOnly,
            boundaryClipPolicy: .ignoreFocusedTextElement
        ),
        AppCompatibilityProfile(
            id: "openai-composer",
            displayName: "OpenAI Composer",
            bundleIdentifierPrefixes: [
                "com.openai",
                "com.openai.chat",
                "com.openai.codex"
            ],
            lineRectPolicy: .caretOnly,
            boundaryClipPolicy: .clipToFocusedTextElementWhenCaretInside
        ),
        AppCompatibilityProfile(
            id: "claude-desktop",
            displayName: "Claude Desktop",
            bundleIdentifierPrefixes: ["com.anthropic.claudefordesktop"],
            lineRectPolicy: .caretOnly,
            boundaryClipPolicy: .clipToFocusedTextElementWhenCaretInside,
            maximumLineHeightMultiplier: 1.45,
            verticalToleranceMultiplier: 0.65
        ),
        AppCompatibilityProfile(
            id: "browser-composer",
            displayName: "Browser Composer",
            bundleIdentifierPrefixes: [
                "com.apple.Safari",
                "com.google.Chrome",
                "com.brave.Browser",
                "company.thebrowser.Browser",
                "org.mozilla.firefox"
            ],
            lineRectPolicy: .caretOnly,
            boundaryClipPolicy: .clipToFocusedTextElementWhenCaretInside,
            maximumLineHeightMultiplier: 1.45,
            verticalToleranceMultiplier: 0.65
        ),
        AppCompatibilityProfile(
            id: "apple-search-fields",
            displayName: "Apple Search Fields",
            bundleIdentifierPrefixes: [
                "com.apple.finder",
                "com.apple.systempreferences",
                "com.apple.ActivityMonitor"
            ],
            lineRectPolicy: .caretOnly,
            boundaryClipPolicy: .clipToFocusedTextElementWhenCaretInside
        ),
        AppCompatibilityProfile(
            id: "apple-messaging",
            displayName: "Apple Messaging",
            bundleIdentifierPrefixes: ["com.apple.MobileSMS"],
            lineRectPolicy: .caretOnly,
            boundaryClipPolicy: .clipToFocusedTextElementWhenCaretInside
        ),
        AppCompatibilityProfile(
            id: "chat-app",
            displayName: "Chat App",
            bundleIdentifierPrefixes: [
                "ru.keepcoder.Telegram"
            ],
            lineRectPolicy: .caretOnly,
            boundaryClipPolicy: .clipToFocusedTextElementWhenCaretInside,
            maximumLineHeightMultiplier: 1.45,
            verticalToleranceMultiplier: 0.65
        ),
        AppCompatibilityProfile(
            id: "slack-blocked",
            displayName: "Slack",
            bundleIdentifierPrefixes: ["com.tinyspeck.slackmacgap"],
            lineRectPolicy: .caretOnly,
            boundaryClipPolicy: .ignoreFocusedTextElement
        ),
        AppCompatibilityProfile(
            id: "discord-blocked",
            displayName: "Discord",
            bundleIdentifierPrefixes: [
                "com.hnc.Discord",
                "com.hnc.DiscordPTB",
                "com.hnc.DiscordCanary"
            ],
            lineRectPolicy: .caretOnly,
            boundaryClipPolicy: .ignoreFocusedTextElement
        ),
        AppCompatibilityProfile(
            id: "electron-editor",
            displayName: "Electron Editor",
            bundleIdentifierPrefixes: [
                "com.microsoft.VSCode",
                "com.todesktop"
            ],
            lineRectPolicy: .caretOnly,
            boundaryClipPolicy: .clipToFocusedTextElementWhenCaretInside,
            maximumLineHeightMultiplier: 1.45,
            verticalToleranceMultiplier: 0.65
        ),
        AppCompatibilityProfile(
            id: "terminal",
            displayName: "Terminal",
            bundleIdentifierPrefixes: [
                "com.apple.Terminal",
                "com.googlecode.iterm2"
            ],
            lineRectPolicy: .caretOnly,
            boundaryClipPolicy: .ignoreFocusedTextElement
        )
    ]
}
