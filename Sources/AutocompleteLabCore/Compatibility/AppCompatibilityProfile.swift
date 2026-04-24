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
        displayName: "Default Accessibility Editor",
        bundleIdentifierPrefixes: []
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
            id: "electron-editor",
            displayName: "Electron Editor",
            bundleIdentifierPrefixes: [
                "md.obsidian",
                "com.microsoft.VSCode",
                "com.todesktop"
            ],
            lineRectPolicy: .caretOnly,
            boundaryClipPolicy: .clipToFocusedTextElementWhenCaretInside,
            maximumLineHeightMultiplier: 1.45,
            verticalToleranceMultiplier: 0.65
        )
    ]
}
