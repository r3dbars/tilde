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

public struct AppCompatibilityProfile: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let bundleIdentifierPrefixes: [String]
    public let defaultRung: CompatibilityRung
    public let textPath: TextIntegrationPath
    public let acceptMode: SuggestionAcceptMode
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
        defaultRung: CompatibilityRung = .detect,
        textPath: TextIntegrationPath = .nativeAccessibility,
        acceptMode: SuggestionAcceptMode = .none,
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
        self.defaultRung = defaultRung
        self.textPath = textPath
        self.acceptMode = acceptMode
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
        displayName: "Universal App",
        bundleIdentifierPrefixes: [],
        defaultRung: .suggest,
        textPath: .nativeAccessibility,
        acceptMode: .none
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
            defaultRung: .stableBeta,
            textPath: .nativeAccessibility,
            acceptMode: .directAccessibility,
            lineRectPolicy: .caretOnly,
            boundaryClipPolicy: .clipToFocusedTextElementWhenCaretInside
        ),
        AppCompatibilityProfile(
            id: "notes",
            displayName: "Apple Notes",
            bundleIdentifierPrefixes: ["com.apple.Notes"],
            defaultRung: .accept,
            textPath: .nativeAccessibility,
            acceptMode: .directAccessibility,
            lineRectPolicy: .trustAfterValidation,
            boundaryClipPolicy: .clipToFocusedTextElementWhenCaretInside,
            verticalToleranceMultiplier: 1.2
        ),
        AppCompatibilityProfile(
            id: "mail",
            displayName: "Apple Mail",
            bundleIdentifierPrefixes: ["com.apple.mail"],
            defaultRung: .detect,
            textPath: .nativeAccessibility,
            acceptMode: .none,
            lineRectPolicy: .trustAfterValidation,
            boundaryClipPolicy: .clipToFocusedTextElementWhenCaretInside
        ),
        AppCompatibilityProfile(
            id: "obsidian",
            displayName: "Obsidian",
            bundleIdentifierPrefixes: ["md.obsidian"],
            defaultRung: .detect,
            textPath: .editorPlugin,
            acceptMode: .none,
            lineRectPolicy: .caretOnly,
            boundaryClipPolicy: .clipToFocusedTextElementWhenCaretInside,
            maximumLineHeightMultiplier: 1.45,
            verticalToleranceMultiplier: 0.65
        ),
        AppCompatibilityProfile(
            id: "notion-blocked",
            displayName: "Notion",
            bundleIdentifierPrefixes: ["notion.id"],
            defaultRung: .blocked,
            textPath: .blocked,
            acceptMode: .none,
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
            defaultRung: .detect,
            textPath: .nativeAccessibility,
            acceptMode: .none,
            lineRectPolicy: .caretOnly,
            boundaryClipPolicy: .clipToFocusedTextElementWhenCaretInside
        ),
        AppCompatibilityProfile(
            id: "claude-desktop",
            displayName: "Claude Desktop",
            bundleIdentifierPrefixes: ["com.anthropic.claudefordesktop"],
            defaultRung: .detect,
            textPath: .editorPlugin,
            acceptMode: .none,
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
            defaultRung: .detect,
            textPath: .webExtension,
            acceptMode: .none,
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
            defaultRung: .detect,
            textPath: .nativeAccessibility,
            acceptMode: .none,
            lineRectPolicy: .caretOnly,
            boundaryClipPolicy: .clipToFocusedTextElementWhenCaretInside
        ),
        AppCompatibilityProfile(
            id: "apple-messaging",
            displayName: "Apple Messaging",
            bundleIdentifierPrefixes: ["com.apple.MobileSMS"],
            defaultRung: .detect,
            textPath: .nativeAccessibility,
            acceptMode: .none,
            lineRectPolicy: .caretOnly,
            boundaryClipPolicy: .clipToFocusedTextElementWhenCaretInside
        ),
        AppCompatibilityProfile(
            id: "chat-app",
            displayName: "Chat App",
            bundleIdentifierPrefixes: [
                "ru.keepcoder.Telegram"
            ],
            defaultRung: .detect,
            textPath: .editorPlugin,
            acceptMode: .none,
            lineRectPolicy: .caretOnly,
            boundaryClipPolicy: .clipToFocusedTextElementWhenCaretInside,
            maximumLineHeightMultiplier: 1.45,
            verticalToleranceMultiplier: 0.65
        ),
        AppCompatibilityProfile(
            id: "slack-blocked",
            displayName: "Slack",
            bundleIdentifierPrefixes: ["com.tinyspeck.slackmacgap"],
            defaultRung: .blocked,
            textPath: .blocked,
            acceptMode: .none,
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
            defaultRung: .blocked,
            textPath: .blocked,
            acceptMode: .none,
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
            defaultRung: .detect,
            textPath: .editorPlugin,
            acceptMode: .none,
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
            defaultRung: .blocked,
            textPath: .blocked,
            acceptMode: .none,
            lineRectPolicy: .caretOnly,
            boundaryClipPolicy: .ignoreFocusedTextElement
        )
    ]
}
