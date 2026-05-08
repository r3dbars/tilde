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

public enum CompatibilityInteractionMode: String, Equatable, Sendable {
    case inline
    case mirror
    case commandOnly
    case disabled

    public var displayName: String {
        switch self {
        case .inline:
            return "inline"
        case .mirror:
            return "mirror"
        case .commandOnly:
            return "command-only"
        case .disabled:
            return "disabled"
        }
    }
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
    public let safetyOwnerNote: String
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
    public let allowsUnknownFieldKind: Bool
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
        safetyOwnerNote: String,
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
        allowsUnknownFieldKind: Bool = false,
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
        self.safetyOwnerNote = safetyOwnerNote
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
        self.allowsUnknownFieldKind = allowsUnknownFieldKind
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

    public var interactionMode: CompatibilityInteractionMode {
        let canAcceptText = insertionMode != .disabled
            && (supportsOneWordAcceptance || supportsFullAcceptance)

        guard canAcceptText else {
            return .disabled
        }

        switch renderMode {
        case .inlineAdjacent:
            return .inline
        case .floatingMirror:
            return .mirror
        case .disabled:
            return .commandOnly
        }
    }

    public var userFacingSafetySummary: String {
        guard canPresentSuggestions, !isSensitive else {
            return "Suggestions stay off here."
        }

        var sentences: [String] = []
        switch renderMode {
        case .inlineAdjacent:
            if fallbackRenderMode == .floatingMirror {
                sentences.append("Inline when caret proof is trusted; mirror fallback if inline is unsafe.")
            } else {
                sentences.append("Inline only when caret proof is trusted.")
            }
        case .floatingMirror:
            sentences.append("Mirror only until caret placement proof is current.")
        case .disabled:
            sentences.append("Suggestions stay off here.")
        }

        if !allowsDetachedSuggestions {
            sentences.append("Detached field/window suggestions are disabled.")
        }

        if supportsOneWordAcceptance && !supportsFullAcceptance {
            sentences.append("Full accept stays off until no-submit proof exists.")
        }

        if fallbackInsertionMode == .disabled || (supportLevel == .yellow && suppressesAfterInsertionFailure) {
            sentences.append("Insertion fails closed if the primary method is not verified.")
        }

        return sentences.joined(separator: " ")
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
            safetyOwnerNote: "Owner: TextEdit allows inline because caret geometry, observer updates, and native AX selected-text insertion are verified; mirror fallback remains available.",
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
            supportReason: "Rich text can drift; display stays mirror-first and insertion fails closed until each Notes surface is proven.",
            safetyOwnerNote: "Owner: Notes stays yellow because rich text can drift; mirror-only display, no detached anchors, and key-event fallback fail closed until title, body, and checklist proof is current.",
            renderMode: .floatingMirror,
            insertionMode: .axThenKeyEvents,
            fallbackInsertionMode: .keyEvents,
            knownFailureModes: ["AX selected-text insertion can report success without moving the caret"],
            supportsObserverUpdates: true,
            allowsDetachedSuggestions: false,
            notes: "Yellow rich-text target. Try AX selected-text insertion before key-event fallback, fail closed on unchanged verification, and use caret-bound mirror placement until fresh title/body/checklist proof exists. Suppress detached mirror placement because Notes can report AX selected-text insertion success without moving the caret."
        ),
        CompatibilityProfile(
            bundleIdentifier: "md.obsidian",
            displayName: "Obsidian",
            appFamily: .electron,
            supportLevel: .yellow,
            supportReason: "Electron editors can hide caret bounds, so this uses floating or synthetic placement.",
            safetyOwnerNote: "Owner: Obsidian stays yellow because CodeMirror can hide caret bounds; caret-only mirror placement and no detached suggestions prevent whole-editor ghosts.",
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
            safetyOwnerNote: "Owner: Mail remains diagnostics-only because compose fields can contain sensitive text and no safe insertion adapter exists.",
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
            bundleIdentifier: "com.openai.atlas",
            displayName: "ChatGPT Atlas",
            appFamily: .chromium,
            supportLevel: .diagnosticsOnly,
            supportReason: "Atlas can contain private browser text and prompt chats; no no-submit proof exists.",
            safetyOwnerNote: "Owner: Atlas remains diagnostics-only because browser fields and ChatGPT prompts can contain private text and no one-word no-submit proof exists.",
            renderMode: .disabled,
            insertionMode: .disabled,
            fallbackRenderMode: .disabled,
            fallbackInsertionMode: .disabled,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.none],
            knownFailureModes: ["browser fields can contain private content", "prompt composer needs no-submit proof"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsOneWordAcceptance: false,
            supportsFullAcceptance: false,
            isSensitive: true,
            notes: "Diagnostics-only prompt/browser target until disposable prompt proof verifies placement and Tab accept cannot submit."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.google.Chrome",
            displayName: "Chrome",
            appFamily: .chromium,
            supportLevel: .yellow,
            supportReason: "Browser editors vary; display can fall back to floating and insertion can fall back to AX.",
            safetyOwnerNote: "Owner: Chrome stays yellow because browser fields vary; inline requires caret proof and mirror/AX fallback covers proven local fixture paths.",
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
            supportReason: "Dogfood prompt support stays mirror-first until one-word no-submit proof is current.",
            safetyOwnerNote: "Owner: Codex is prompt-gated because accidental submit is high risk; mirror next-word accept is allowed, full accept stays off until no-submit proof exists.",
            renderMode: .floatingMirror,
            insertionMode: .axValueReplacement,
            fallbackInsertionMode: .keyEvents,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.caret],
            knownFailureModes: ["prompt editor may need synthetic caret", "detached whole-box suggestions are disallowed"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsFullAcceptance: false,
            suppressesAfterInsertionFailure: false,
            allowsDetachedSuggestions: false,
            notes: "Dogfood target. Prefer caret-bound mirror suggestions and AX value replacement in the prompt editor until same-slice screenshot and one-word no-submit proof is current. The app may synthesize a caret from the prompt text, but should not show detached whole-box suggestions. Requires one-word no-submit proof; full accept stays disabled until separate full-accept no-submit proof is current."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.anthropic.claude-code",
            displayName: "Claude Code",
            appFamily: .customCanvas,
            supportLevel: .yellow,
            supportReason: "Prompt insertion requires one-word no-submit proof and stays limited to next-word accept until full accept is separately proven safe.",
            safetyOwnerNote: "Owner: Claude Code is prompt-gated because Enter must never be implied; key-event next-word accept is allowed, full accept stays off until no-submit proof exists.",
            renderMode: .floatingMirror,
            insertionMode: .keyEvents,
            fallbackInsertionMode: .axThenKeyEvents,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.caret],
            knownFailureModes: ["prompt editor may need synthetic caret", "detached whole-box suggestions are disallowed"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsFullAcceptance: false,
            suppressesAfterInsertionFailure: false,
            allowsDetachedSuggestions: false,
            notes: "Dogfood target. Prefer caret-bound mirror suggestions when the prompt editor exposes bounds until live no-submit proof is current. The app may synthesize a caret from the prompt text, but should not show detached whole-box suggestions. Requires one-word no-submit proof; full accept stays disabled until separate full-accept no-submit proof is current."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            displayName: "Claude",
            appFamily: .electron,
            supportLevel: .yellow,
            supportReason: "Composer placement stays mirror-first until one-word no-submit proof is current.",
            safetyOwnerNote: "Owner: Claude desktop is prompt-gated because composer submit is high risk; mirror next-word accept is allowed, full accept stays off until no-submit proof exists.",
            renderMode: .floatingMirror,
            insertionMode: .axValueReplacement,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.caret],
            knownFailureModes: ["composer may hide caret bounds", "detached whole-window suggestions are disallowed"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsFullAcceptance: false,
            suppressesAfterInsertionFailure: false,
            allowsDetachedSuggestions: false,
            notes: "Dogfood target for Claude desktop. Prefer prompt-bound mirror suggestions when the composer exposes bounds and suppress detached whole-window suggestions. Requires one-word no-submit proof; full accept stays disabled until separate full-accept no-submit proof is current."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            appFamily: .webKit,
            supportLevel: .diagnosticsOnly,
            supportReason: "Browser rich editors need separate proof from textareas.",
            safetyOwnerNote: "Owner: Safari remains diagnostics-only because textarea, contenteditable, and rich-editor placement and insertion proof need separate capture.",
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
            safetyOwnerNote: "Owner: Slack remains diagnostics-only because message composer geometry and one-word no-submit insertion proof are not captured yet.",
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
            bundleIdentifier: "notion.id",
            displayName: "Notion",
            appFamily: .electron,
            supportLevel: .diagnosticsOnly,
            supportReason: "Notion pages need app-specific ProseMirror placement and insertion proof.",
            safetyOwnerNote: "Owner: Notion remains diagnostics-only because page editors can contain private workspace content and ProseMirror placement, Tab behavior, and insertion proof are not captured yet.",
            renderMode: .disabled,
            insertionMode: .disabled,
            fallbackRenderMode: .disabled,
            fallbackInsertionMode: .disabled,
            anchorLadder: [.none],
            knownFailureModes: ["ProseMirror editor needs app-specific proof", "workspace pages can contain private content"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsOneWordAcceptance: false,
            supportsFullAcceptance: false,
            notes: "Diagnostics-only Notion target until disposable page placement, insertion, and no-submit proof are captured."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.hnc.Discord",
            displayName: "Discord",
            appFamily: .electron,
            supportLevel: .diagnosticsOnly,
            supportReason: "Discord message composers need explicit no-submit proof before suggestions can run.",
            safetyOwnerNote: "Owner: Discord remains diagnostics-only because message composers can send chat text and one-word no-submit proof is not captured yet.",
            renderMode: .disabled,
            insertionMode: .disabled,
            fallbackRenderMode: .disabled,
            fallbackInsertionMode: .disabled,
            anchorLadder: [.none],
            knownFailureModes: ["message composer needs no-submit proof"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsOneWordAcceptance: false,
            supportsFullAcceptance: false,
            notes: "Diagnostics-only chat target until a disposable server/channel proves placement and Tab accept cannot submit."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.hnc.DiscordPTB",
            displayName: "Discord PTB",
            appFamily: .electron,
            supportLevel: .diagnosticsOnly,
            supportReason: "Discord message composers need explicit no-submit proof before suggestions can run.",
            safetyOwnerNote: "Owner: Discord PTB remains diagnostics-only because message composers can send chat text and one-word no-submit proof is not captured yet.",
            renderMode: .disabled,
            insertionMode: .disabled,
            fallbackRenderMode: .disabled,
            fallbackInsertionMode: .disabled,
            anchorLadder: [.none],
            knownFailureModes: ["message composer needs no-submit proof"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsOneWordAcceptance: false,
            supportsFullAcceptance: false,
            notes: "Diagnostics-only chat target until a disposable server/channel proves placement and Tab accept cannot submit."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.hnc.DiscordCanary",
            displayName: "Discord Canary",
            appFamily: .electron,
            supportLevel: .diagnosticsOnly,
            supportReason: "Discord message composers need explicit no-submit proof before suggestions can run.",
            safetyOwnerNote: "Owner: Discord Canary remains diagnostics-only because message composers can send chat text and one-word no-submit proof is not captured yet.",
            renderMode: .disabled,
            insertionMode: .disabled,
            fallbackRenderMode: .disabled,
            fallbackInsertionMode: .disabled,
            anchorLadder: [.none],
            knownFailureModes: ["message composer needs no-submit proof"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsOneWordAcceptance: false,
            supportsFullAcceptance: false,
            notes: "Diagnostics-only chat target until a disposable server/channel proves placement and Tab accept cannot submit."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.microsoft.VSCode",
            displayName: "VS Code",
            appFamily: .electron,
            supportLevel: .diagnosticsOnly,
            supportReason: "Monaco editor exposes custom text geometry.",
            safetyOwnerNote: "Owner: VS Code remains diagnostics-only because Monaco geometry and developer input surfaces are not proven safe.",
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
            safetyOwnerNote: "Owner: Cursor remains diagnostics-only because Monaco geometry and developer input surfaces are not proven safe.",
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
            return "No compatibility profile yet; broad unknown-app support stays off until proven apps feel safe."
        }
    }

    public var userFacingUnavailableText: String {
        switch self {
        case .supported:
            return "Suggestions stay off here."
        case .denylisted:
            return "Suggestions are intentionally off here."
        case .unsupported:
            return "Suggestions are intentionally off until this app is tested."
        }
    }

    public var userFacingSafetySummary: String {
        switch self {
        case let .supported(profile):
            return profile.userFacingSafetySummary
        case .denylisted:
            return "Suggestions stay off because this kind of app can expose secrets or shell input."
        case .unsupported:
            return "Suggestions are intentionally off until this app has a compatibility profile."
        }
    }

    public var canToggleSuggestions: Bool {
        guard case let .supported(profile) = self else {
            return false
        }

        return profile.canPresentSuggestions && !profile.isSensitive
    }

    public var interactionMode: CompatibilityInteractionMode {
        switch self {
        case let .supported(profile):
            return profile.isSensitive ? .disabled : profile.interactionMode
        case .denylisted, .unsupported:
            return .disabled
        }
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
