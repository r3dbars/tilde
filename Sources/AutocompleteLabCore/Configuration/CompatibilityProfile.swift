import Foundation

public enum SuggestionRenderMode: String, Codable, Equatable, Sendable {
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

public enum CompatibilityAppFamily: String, Equatable, Sendable {
    case nativeAppKit
    case swiftUIAppKit
    case webKit
    case chromium
    case electron
    case customCanvas
    case unknown
}

public struct CompatibilityProfile: Equatable, Sendable {
    public let bundleIdentifier: String
    public let displayName: String
    public let appFamily: CompatibilityAppFamily
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
    public let isSensitive: Bool
    public let notes: String

    public init(
        bundleIdentifier: String,
        displayName: String,
        appFamily: CompatibilityAppFamily = .unknown,
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
        isSensitive: Bool = false,
        notes: String
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.appFamily = appFamily
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

        return "family=\(appFamily.rawValue); primary render=\(renderMode.rawValue), insert=\(insertionMode.rawValue); fallback render=\(fallbackRender), insert=\(fallbackInsertion); field=\(fieldIdentityMode.rawValue); anchors=\(anchors)"
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
            renderMode: .inlineAdjacent,
            insertionMode: .keyEvents,
            fallbackRenderMode: .floatingMirror,
            fallbackInsertionMode: .axSelectedText,
            knownFailureModes: ["AX selected-text insertion can report success without moving the caret"],
            supportsObserverUpdates: true,
            notes: "Green/yellow rich-text target. Notes can report AX selected-text insertion success without moving the caret, so prefer verified key-event insertion."
        ),
        CompatibilityProfile(
            bundleIdentifier: "md.obsidian",
            displayName: "Obsidian",
            appFamily: .electron,
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
            notes: "Yellow Electron target. Prefer capability probing, mirror-style placement, and verified AX before synthetic key insertion. Do not show detached suggestions when CodeMirror hides caret bounds."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.apple.mail",
            displayName: "Mail",
            appFamily: .nativeAppKit,
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
            renderMode: .floatingMirror,
            insertionMode: .axValueReplacement,
            fallbackRenderMode: .floatingMirror,
            fallbackInsertionMode: .keyEvents,
            anchorLadder: [.caret, .field],
            knownFailureModes: ["textarea support differs from rich editors", "zero-height caret bounds can occur"],
            notes: "Yellow browser target. Verified on a local textarea with AXTextArea, selected range, and settable selected text. Chrome can report zero-height caret bounds, so use mirror anchoring."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.openai.codex",
            displayName: "Codex",
            appFamily: .customCanvas,
            renderMode: .inlineAdjacent,
            insertionMode: .keyEvents,
            fallbackRenderMode: .floatingMirror,
            fallbackInsertionMode: .axThenKeyEvents,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.caret],
            knownFailureModes: ["prompt editor may need synthetic caret", "detached whole-box suggestions are disallowed"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            suppressesAfterInsertionFailure: false,
            allowsDetachedSuggestions: false,
            notes: "Dogfood target. Prefer caret-bound inline suggestions when the prompt editor exposes bounds. The app may synthesize a caret from the prompt text, but should not show detached whole-box suggestions."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            appFamily: .webKit,
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

    public var summary: String {
        switch self {
        case let .supported(profile):
            if profile.canPresentSuggestions {
                return "supported: \(profile.displayName)"
            }

            return "diagnostics only: \(profile.displayName)"
        case .denylisted:
            return "blocked: denylisted app"
        case .unsupported:
            return "blocked: no MVP compatibility profile"
        }
    }
}
