import Foundation

public enum SuggestionRenderMode: String, Codable, Equatable, Sendable {
    case inlineAdjacent
    case floatingMirror
    case disabled
}

public enum InsertionMode: String, Equatable, Hashable, Sendable {
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

public enum CompatibilityAppFamily: String, Equatable, Sendable {
    case nativeAppKit
    case swiftUIAppKit
    case webKit
    case chromium
    case electron
    case customCanvas
    case unknown
}

public enum CompatibilitySupportLevel: String, Equatable, Sendable {
    case green
    case yellow
    case diagnosticsOnly
    case unsupported

    public var displayName: String {
        switch self {
        case .green:
            return "Green"
        case .yellow:
            return "Yellow"
        case .diagnosticsOnly:
            return "Diagnostics-only"
        case .unsupported:
            return "Unsupported"
        }
    }

    public var menuName: String {
        switch self {
        case .green:
            return "green"
        case .yellow:
            return "yellow"
        case .diagnosticsOnly:
            return "diagnostics-only"
        case .unsupported:
            return "unsupported"
        }
    }
}

public struct CompatibilityProfile: Equatable, Sendable {
    public let bundleIdentifier: String
    public let displayName: String
    public let appFamily: CompatibilityAppFamily
    public let supportLevel: CompatibilitySupportLevel
    public let supportReason: String
    public let renderMode: SuggestionRenderMode
    public let insertionMode: InsertionMode
    public let fallbackRenderMode: SuggestionRenderMode?
    public let fallbackInsertionMode: InsertionMode?
    public let fieldIdentityMode: FocusedFieldIdentityMode
    public let anchorLadder: [SuggestionAnchorSource]
    public let knownFailureModes: [String]
    public let allowsFieldAnchor: Bool
    public let allowsWindowAnchor: Bool
    public let requiresValidatedCaret: Bool
    public let supportsObserverUpdates: Bool
    public let supportsOneWordAcceptance: Bool
    public let supportsFullAcceptance: Bool
    public let suppressesUntilBlurAfterEscape: Bool
    public let suppressesAfterInsertionFailure: Bool
    public let allowsDescendantTextFallback: Bool
    public let allowsDetachedSuggestions: Bool
    public let allowsSyntheticCaretPlacement: Bool
    public let isSensitive: Bool
    public let notes: String

    public init(
        bundleIdentifier: String,
        displayName: String,
        appFamily: CompatibilityAppFamily = .unknown,
        supportLevel: CompatibilitySupportLevel,
        supportReason: String,
        renderMode: SuggestionRenderMode,
        insertionMode: InsertionMode,
        fallbackRenderMode: SuggestionRenderMode? = nil,
        fallbackInsertionMode: InsertionMode? = nil,
        fieldIdentityMode: FocusedFieldIdentityMode = .accessibilityElement,
        anchorLadder: [SuggestionAnchorSource] = [.caret, .line, .field],
        knownFailureModes: [String] = [],
        allowsFieldAnchor: Bool = true,
        allowsWindowAnchor: Bool = false,
        requiresValidatedCaret: Bool = true,
        supportsObserverUpdates: Bool = false,
        supportsOneWordAcceptance: Bool = true,
        supportsFullAcceptance: Bool = true,
        suppressesUntilBlurAfterEscape: Bool = true,
        suppressesAfterInsertionFailure: Bool = true,
        allowsDescendantTextFallback: Bool = false,
        allowsDetachedSuggestions: Bool = true,
        allowsSyntheticCaretPlacement: Bool = false,
        isSensitive: Bool = false,
        notes: String
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.appFamily = appFamily
        self.supportLevel = supportLevel
        self.supportReason = supportReason
        self.renderMode = renderMode
        self.insertionMode = insertionMode
        self.fallbackRenderMode = fallbackRenderMode
        self.fallbackInsertionMode = fallbackInsertionMode
        self.fieldIdentityMode = fieldIdentityMode
        self.anchorLadder = anchorLadder
        self.knownFailureModes = knownFailureModes
        self.allowsFieldAnchor = allowsFieldAnchor
        self.allowsWindowAnchor = allowsWindowAnchor
        self.requiresValidatedCaret = requiresValidatedCaret
        self.supportsObserverUpdates = supportsObserverUpdates
        self.supportsOneWordAcceptance = supportsOneWordAcceptance
        self.supportsFullAcceptance = supportsFullAcceptance
        self.suppressesUntilBlurAfterEscape = suppressesUntilBlurAfterEscape
        self.suppressesAfterInsertionFailure = suppressesAfterInsertionFailure
        self.allowsDescendantTextFallback = allowsDescendantTextFallback
        self.allowsDetachedSuggestions = allowsDetachedSuggestions
        self.allowsSyntheticCaretPlacement = allowsSyntheticCaretPlacement
        self.isSensitive = isSensitive
        self.notes = notes
    }

    public var canPresentSuggestions: Bool {
        renderMode != .disabled
            && insertionMode != .disabled
            && (supportsOneWordAcceptance || supportsFullAcceptance)
    }

    public var debugSummary: String {
        let fallbackRender = fallbackRenderMode?.rawValue ?? "none"
        let fallbackInsertion = fallbackInsertionMode?.rawValue ?? "none"
        let anchors = anchorLadder.map(\.rawValue).joined(separator: ">")

        return "support=\(supportLevel.rawValue); family=\(appFamily.rawValue); primary render=\(renderMode.rawValue), insert=\(insertionMode.rawValue); fallback render=\(fallbackRender), insert=\(fallbackInsertion); field=\(fieldIdentityMode.rawValue); anchors=\(anchors)"
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
        guard case let .supported(profile) = supportStatus(for: bundleIdentifier) else {
            return nil
        }

        return profile
    }

    public func allows(bundleIdentifier: String) -> Bool {
        profile(for: bundleIdentifier) != nil
    }

    public func supportStatus(for bundleIdentifier: String) -> CompatibilitySupportStatus {
        if denylistedBundleIdentifiers.contains(bundleIdentifier) {
            return .denylisted
        }

        if let profile = profiles[bundleIdentifier] {
            return .supported(profile)
        }

        return .unsupported
    }

    public static let mvp = CompatibilityProfileStore(profiles: [
        CompatibilityProfile(
            bundleIdentifier: "com.apple.TextEdit",
            displayName: "TextEdit",
            appFamily: .nativeAppKit,
            supportLevel: .green,
            supportReason: "Verified inline suggestions and native text insertion.",
            renderMode: .inlineAdjacent,
            insertionMode: .axSelectedText,
            fallbackRenderMode: .floatingMirror,
            fallbackInsertionMode: .axValueReplacement,
            knownFailureModes: ["rich text selection changes can stale geometry"],
            supportsObserverUpdates: true,
            notes: "Green reference target. Use for caret geometry, one-word acceptance, and full-accept regression tests."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.apple.Notes",
            displayName: "Notes",
            appFamily: .swiftUIAppKit,
            supportLevel: .yellow,
            supportReason: "Rich text can drift; display can fall back to floating, and insertion fails closed.",
            renderMode: .inlineAdjacent,
            insertionMode: .axThenKeyEvents,
            fallbackRenderMode: .floatingMirror,
            fallbackInsertionMode: .keyEvents,
            knownFailureModes: ["AX selected-text insertion can report success without moving the caret unless post-insert verification passes"],
            supportsObserverUpdates: true,
            allowsDetachedSuggestions: false,
            notes: "Yellow rich-text target. Try verified AX selected-text insertion before synthetic keys, fail closed on unchanged verification, and suppress detached mirror placement until fresh title/body/checklist proof exists because Notes can report AX selected-text insertion success without moving the caret."
        ),
        CompatibilityProfile(
            bundleIdentifier: "md.obsidian",
            displayName: "Obsidian",
            appFamily: .electron,
            supportLevel: .yellow,
            supportReason: "Electron editors can hide caret bounds, so this uses floating or synthetic placement.",
            renderMode: .floatingMirror,
            insertionMode: .axThenKeyEvents,
            fallbackRenderMode: .floatingMirror,
            fallbackInsertionMode: .keyEvents,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.caret],
            knownFailureModes: ["CodeMirror may hide caret bounds", "whole-editor anchors look detached"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            requiresValidatedCaret: true,
            suppressesAfterInsertionFailure: false,
            allowsDetachedSuggestions: false,
            allowsSyntheticCaretPlacement: true,
            notes: "Yellow Electron target. Prefer capability probing, synthetic text-area caret placement, and verified AX before synthetic key insertion. Do not show detached suggestions when CodeMirror hides usable caret bounds."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.apple.mail",
            displayName: "Mail",
            appFamily: .nativeAppKit,
            supportLevel: .diagnosticsOnly,
            supportReason: "Mail compose is sensitive and insertion is not proven.",
            renderMode: .disabled,
            insertionMode: .disabled,
            fallbackRenderMode: .disabled,
            fallbackInsertionMode: .disabled,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.none],
            knownFailureModes: ["compose is sensitive until a safe adapter exists"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsOneWordAcceptance: false,
            supportsFullAcceptance: false,
            allowsDescendantTextFallback: true,
            isSensitive: true,
            notes: "Diagnostics-only rich-text compose target until Mail insertion has a verified safe adapter."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.google.Chrome",
            displayName: "Chrome",
            appFamily: .chromium,
            supportLevel: .yellow,
            supportReason: "Browser editors vary; display can fall back to floating and insertion can fall back to AX.",
            renderMode: .inlineAdjacent,
            insertionMode: .keyEvents,
            fallbackRenderMode: .floatingMirror,
            fallbackInsertionMode: .axValueReplacement,
            anchorLadder: [.caret, .field],
            knownFailureModes: ["textarea support differs from rich editors", "zero-height caret bounds can occur"],
            notes: "Yellow browser target. Prefer synthetic caret inline placement when Chrome hides usable caret bounds, with mirror fallback. Prefer key-event insertion across textarea and contenteditable surfaces because rich browser editors can report AX replacement success without keeping cursor verification stable."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.openai.codex",
            displayName: "Codex",
            appFamily: .customCanvas,
            supportLevel: .yellow,
            supportReason: "Dogfood prompt support still needs one-word no-submit proof before it is green.",
            renderMode: .inlineAdjacent,
            insertionMode: .axValueReplacement,
            fallbackRenderMode: .floatingMirror,
            fallbackInsertionMode: .keyEvents,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.caret],
            knownFailureModes: ["prompt editor may need synthetic caret", "detached whole-box suggestions are disallowed"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsFullAcceptance: false,
            suppressesAfterInsertionFailure: false,
            allowsDetachedSuggestions: false,
            notes: "Dogfood target. Prefer caret-bound inline suggestions and AX value replacement in the prompt editor. The app may synthesize a caret from the prompt text, but should not show detached whole-box suggestions. Requires one-word no-submit proof; full accept stays disabled until separate full-accept no-submit proof is current."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.anthropic.claude-code",
            displayName: "Claude Code",
            appFamily: .customCanvas,
            supportLevel: .yellow,
            supportReason: "Prompt insertion requires one-word no-submit proof and stays limited to next-word accept until full accept is separately proven safe.",
            renderMode: .inlineAdjacent,
            insertionMode: .keyEvents,
            fallbackRenderMode: .floatingMirror,
            fallbackInsertionMode: .axThenKeyEvents,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.caret],
            knownFailureModes: ["prompt editor may need synthetic caret", "detached whole-box suggestions are disallowed"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsFullAcceptance: false,
            suppressesAfterInsertionFailure: false,
            allowsDetachedSuggestions: false,
            notes: "Dogfood target. Prefer caret-bound inline suggestions when the prompt editor exposes bounds. The app may synthesize a caret from the prompt text, but should not show detached whole-box suggestions. Requires one-word no-submit proof; full accept stays disabled until separate full-accept no-submit proof is current."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            displayName: "Claude",
            appFamily: .electron,
            supportLevel: .yellow,
            supportReason: "Composer placement still needs one-word no-submit proof before it is green.",
            renderMode: .inlineAdjacent,
            insertionMode: .axValueReplacement,
            fallbackRenderMode: .floatingMirror,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.caret],
            knownFailureModes: ["composer may hide caret bounds", "detached whole-window suggestions are disallowed"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsFullAcceptance: false,
            suppressesAfterInsertionFailure: false,
            allowsDetachedSuggestions: false,
            notes: "Dogfood target for Claude desktop. Prefer prompt-bound inline suggestions when the composer exposes bounds; otherwise use mirror placement without showing detached whole-window suggestions. Requires one-word no-submit proof; full accept stays disabled until separate full-accept no-submit proof is current."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            appFamily: .webKit,
            supportLevel: .diagnosticsOnly,
            supportReason: "Browser rich editors need separate proof from textareas.",
            renderMode: .disabled,
            insertionMode: .disabled,
            fallbackRenderMode: .disabled,
            fallbackInsertionMode: .disabled,
            anchorLadder: [.none],
            knownFailureModes: ["browser rich editors need separate proof from textareas"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsOneWordAcceptance: false,
            supportsFullAcceptance: false,
            notes: "Diagnostics-only WebKit browser profile until textarea and rich-editor behavior are proven separately."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.tinyspeck.slackmacgap",
            displayName: "Slack",
            appFamily: .electron,
            supportLevel: .diagnosticsOnly,
            supportReason: "Electron rich editor needs app-specific proof.",
            renderMode: .disabled,
            insertionMode: .disabled,
            fallbackRenderMode: .disabled,
            fallbackInsertionMode: .disabled,
            anchorLadder: [.none],
            knownFailureModes: ["Electron rich editor needs app-specific proof"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsOneWordAcceptance: false,
            supportsFullAcceptance: false,
            notes: "Diagnostics-only Electron target until message composer geometry and insertion are proven."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.microsoft.VSCode",
            displayName: "VS Code",
            appFamily: .electron,
            supportLevel: .diagnosticsOnly,
            supportReason: "Monaco editor exposes custom text geometry.",
            renderMode: .disabled,
            insertionMode: .disabled,
            fallbackRenderMode: .disabled,
            fallbackInsertionMode: .disabled,
            anchorLadder: [.none],
            knownFailureModes: ["Monaco editor exposes custom text geometry"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsOneWordAcceptance: false,
            supportsFullAcceptance: false,
            notes: "Diagnostics-only Monaco target until editor-specific caret and Tab behavior are proven."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.todesktop.230313mzl4w4u92",
            displayName: "Cursor",
            appFamily: .electron,
            supportLevel: .diagnosticsOnly,
            supportReason: "Monaco editor exposes custom text geometry.",
            renderMode: .disabled,
            insertionMode: .disabled,
            fallbackRenderMode: .disabled,
            fallbackInsertionMode: .disabled,
            anchorLadder: [.none],
            knownFailureModes: ["Monaco editor exposes custom text geometry"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsOneWordAcceptance: false,
            supportsFullAcceptance: false,
            notes: "Diagnostics-only Monaco target until editor-specific caret and Tab behavior are proven."
        )
    ])

    public static let defaultDenylist: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.apple.dt.Xcode",
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.visualstudio.code.oss",
        "com.todesktop.230313mzl4w4u92",
        "com.exafunction.windsurf",
        "com.jetbrains.intellij",
        "com.jetbrains.AppCode",
        "com.jetbrains.CLion",
        "com.jetbrains.PyCharm",
        "com.jetbrains.WebStorm",
        "com.jetbrains.RubyMine",
        "com.jetbrains.goland",
        "com.jetbrains.datagrip",
        "com.jetbrains.phpstorm",
        "com.jetbrains.rider",
        "com.jetbrains.DataSpell",
        "com.jetbrains.aqua",
        "com.jetbrains.gateway",
        "dev.warp.Warp",
        "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty",
        "org.alacritty",
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "com.dashlane.dashlanephonefinal",
        "com.lastpass.LastPass",
        "com.apple.systempreferences",
        "com.apple.systemsettings"
    ]
}

public enum CompatibilitySupportStatus: Equatable, Sendable {
    case supported(CompatibilityProfile)
    case denylisted
    case unsupported

    public var supportLevel: CompatibilitySupportLevel {
        switch self {
        case let .supported(profile):
            return profile.supportLevel
        case .denylisted, .unsupported:
            return .unsupported
        }
    }

    public var summary: String {
        switch self {
        case let .supported(profile):
            if profile.canPresentSuggestions {
                return "\(profile.supportLevel.menuName): \(profile.displayName)"
            }

            return "diagnostics only: \(profile.displayName)"
        case .denylisted:
            return "blocked: denylisted app"
        case .unsupported:
            return "blocked: no MVP compatibility profile"
        }
    }

    public var userFacingSummary: String {
        switch self {
        case let .supported(profile):
            return "\(profile.supportLevel.displayName): \(profile.displayName)"
        case .denylisted:
            return "Unsupported: blocked app"
        case .unsupported:
            return "Unsupported: not tested yet"
        }
    }

    public var userFacingReason: String {
        switch self {
        case let .supported(profile):
            return profile.supportReason
        case .denylisted:
            return "Blocked because this kind of app can expose secrets or shell input."
        case .unsupported:
            return "No compatibility profile yet."
        }
    }

    public var canToggleSuggestions: Bool {
        guard case let .supported(profile) = self else {
            return false
        }

        return profile.canPresentSuggestions && !profile.isSensitive
    }

    public func menuText(appDisplayName: String, isEnabled: Bool) -> String {
        switch self {
        case let .supported(profile):
            guard profile.canPresentSuggestions, !profile.isSensitive else {
                return "\(appDisplayName) \(profile.supportLevel.menuName)"
            }

            return "\(appDisplayName) \(profile.supportLevel.menuName) \(isEnabled ? "on" : "off")"
        case .denylisted, .unsupported:
            return "\(appDisplayName) unsupported"
        }
    }
}
