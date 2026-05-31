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

public enum PromptAppSafetyMode: String, Equatable, Sendable {
    case notPrompt
    case disabled
    case clickOnly
    case wordOnly

    public var isPromptSurface: Bool {
        self != .notPrompt
    }
}

public enum CompatibilityGraduationDecision: String, Equatable, Sendable {
    case supported
    case wordOnly = "word-only"
    case diagnosticsOnly = "diagnostics-only"
    case blocked
}

public struct CompatibilityProfile: Equatable, Sendable {
    public let bundleIdentifier: String
    public let displayName: String
    public let appFamily: CompatibilityAppFamily
    public let supportLevel: CompatibilitySupportLevel
    public let graduationDecision: CompatibilityGraduationDecision
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
    public let allowsUnknownFieldKind: Bool
    public let requiresNoSubmitAcceptanceProof: Bool
    public let suppressesUntilBlurAfterEscape: Bool
    public let suppressesAfterInsertionFailure: Bool
    public let allowsDescendantTextFallback: Bool
    public let allowsDetachedSuggestions: Bool
    public let allowsSyntheticCaretPlacement: Bool
    public let isSensitive: Bool
    public let promptAppSafetyMode: PromptAppSafetyMode
    public let notes: String

    public init(
        bundleIdentifier: String,
        displayName: String,
        appFamily: CompatibilityAppFamily = .unknown,
        supportLevel: CompatibilitySupportLevel,
        graduationDecision: CompatibilityGraduationDecision? = nil,
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
        allowsUnknownFieldKind: Bool = false,
        requiresNoSubmitAcceptanceProof: Bool = false,
        suppressesUntilBlurAfterEscape: Bool = true,
        suppressesAfterInsertionFailure: Bool = true,
        allowsDescendantTextFallback: Bool = false,
        allowsDetachedSuggestions: Bool = true,
        allowsSyntheticCaretPlacement: Bool = false,
        isSensitive: Bool = false,
        promptAppSafetyMode: PromptAppSafetyMode = .notPrompt,
        notes: String
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.appFamily = appFamily
        self.supportLevel = supportLevel
        self.graduationDecision = graduationDecision ?? Self.defaultGraduationDecision(
            supportLevel: supportLevel,
            renderMode: renderMode,
            insertionMode: insertionMode,
            supportsOneWordAcceptance: supportsOneWordAcceptance,
            supportsFullAcceptance: supportsFullAcceptance,
            requiresNoSubmitAcceptanceProof: requiresNoSubmitAcceptanceProof,
            isSensitive: isSensitive
        )
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
        self.allowsUnknownFieldKind = allowsUnknownFieldKind
        self.requiresNoSubmitAcceptanceProof = requiresNoSubmitAcceptanceProof
        self.suppressesUntilBlurAfterEscape = suppressesUntilBlurAfterEscape
        self.suppressesAfterInsertionFailure = suppressesAfterInsertionFailure
        self.allowsDescendantTextFallback = allowsDescendantTextFallback
        self.allowsDetachedSuggestions = allowsDetachedSuggestions
        self.allowsSyntheticCaretPlacement = allowsSyntheticCaretPlacement
        self.isSensitive = isSensitive
        self.promptAppSafetyMode = promptAppSafetyMode
        self.notes = notes
    }

    private static func defaultGraduationDecision(
        supportLevel: CompatibilitySupportLevel,
        renderMode: SuggestionRenderMode,
        insertionMode: InsertionMode,
        supportsOneWordAcceptance: Bool,
        supportsFullAcceptance: Bool,
        requiresNoSubmitAcceptanceProof: Bool,
        isSensitive: Bool
    ) -> CompatibilityGraduationDecision {
        let canPresent = renderMode != .disabled
            && insertionMode != .disabled
            && (supportsOneWordAcceptance || supportsFullAcceptance)

        if canPresent,
           supportsOneWordAcceptance,
           !supportsFullAcceptance,
           requiresNoSubmitAcceptanceProof {
            return .wordOnly
        }

        if canPresent, !isSensitive {
            return .supported
        }

        if supportLevel == .diagnosticsOnly {
            return .diagnosticsOnly
        }

        return .blocked
    }

    public var canPresentSuggestions: Bool {
        renderMode != .disabled
            && insertionMode != .disabled
            && (supportsOneWordAcceptance || supportsFullAcceptance)
    }

    public var allowsMaxAggressiveTuningBypass: Bool {
        guard canPresentSuggestions, !isSensitive else {
            return false
        }

        if promptAppSafetyMode == .notPrompt {
            return true
        }

        return promptAppSafetyMode == .wordOnly
            && graduationDecision == .wordOnly
            && supportsOneWordAcceptance
            && !supportsFullAcceptance
            && !requiresNoSubmitAcceptanceProof
    }

    public var allowsCopyOnlyCommandFallback: Bool {
        !isSensitive && supportLevel != .unsupported
    }

    public func replacingAcceptanceProofMode(
        supportsFullAcceptance: Bool,
        requiresNoSubmitAcceptanceProof: Bool,
        notes: String? = nil
    ) -> CompatibilityProfile {
        CompatibilityProfile(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            appFamily: appFamily,
            supportLevel: supportLevel,
            graduationDecision: graduationDecision,
            supportReason: supportReason,
            renderMode: renderMode,
            insertionMode: insertionMode,
            fallbackRenderMode: fallbackRenderMode,
            fallbackInsertionMode: fallbackInsertionMode,
            fieldIdentityMode: fieldIdentityMode,
            anchorLadder: anchorLadder,
            knownFailureModes: knownFailureModes,
            allowsFieldAnchor: allowsFieldAnchor,
            allowsWindowAnchor: allowsWindowAnchor,
            requiresValidatedCaret: requiresValidatedCaret,
            supportsObserverUpdates: supportsObserverUpdates,
            supportsOneWordAcceptance: supportsOneWordAcceptance,
            supportsFullAcceptance: supportsFullAcceptance,
            allowsUnknownFieldKind: allowsUnknownFieldKind,
            requiresNoSubmitAcceptanceProof: requiresNoSubmitAcceptanceProof,
            suppressesUntilBlurAfterEscape: suppressesUntilBlurAfterEscape,
            suppressesAfterInsertionFailure: suppressesAfterInsertionFailure,
            allowsDescendantTextFallback: allowsDescendantTextFallback,
            allowsDetachedSuggestions: allowsDetachedSuggestions,
            allowsSyntheticCaretPlacement: allowsSyntheticCaretPlacement,
            isSensitive: isSensitive,
            promptAppSafetyMode: promptAppSafetyMode,
            notes: notes ?? self.notes
        )
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

        if promptAppSafetyMode == .wordOnly {
            sentences.append("Prompt safety mode is word-only.")
        } else if promptAppSafetyMode == .clickOnly {
            sentences.append("Prompt safety mode is click-only.")
        }

        if fallbackInsertionMode == .disabled || (supportLevel == .yellow && suppressesAfterInsertionFailure) {
            sentences.append("Insertion fails closed if the primary method is not verified.")
        }

        return sentences.joined(separator: " ")
    }

    public var allowsStrictVisualProofSyntheticCaretPlacement: Bool {
        supportsOneWordAcceptance
            && (!supportsFullAcceptance || !requiresNoSubmitAcceptanceProof)
            && !allowsDetachedSuggestions
            && !allowsSyntheticCaretPlacement
            && !isSensitive
            && promptAppSafetyMode == .wordOnly
            && anchorLadder == [.caret]
            && notes.contains("one-word no-submit proof")
    }

    public var debugSummary: String {
        let fallbackRender = fallbackRenderMode?.rawValue ?? "none"
        let fallbackInsertion = fallbackInsertionMode?.rawValue ?? "none"
        let anchors = anchorLadder.map(\.rawValue).joined(separator: ">")

        return "support=\(supportLevel.rawValue); family=\(appFamily.rawValue); primary render=\(renderMode.rawValue), insert=\(insertionMode.rawValue); fallback render=\(fallbackRender), insert=\(fallbackInsertion); field=\(fieldIdentityMode.rawValue); anchors=\(anchors)"
    }

    public func placementTrustPolicy(
        input: CompatibilityPlacementTrustInput = CompatibilityPlacementTrustInput()
    ) -> PlacementTrustPolicy {
        let hasTrustedVisualAdjustment = input.hasTrustedVisualAdjustment
        let isGreenProfile = supportLevel == .green
        let strictVisualProofSyntheticCaretEnabled =
            (input.screenshotTracingEnabled || input.shouldCaptureScreenshot)
            && allowsStrictVisualProofSyntheticCaretPlacement

        return PlacementTrustPolicy(
            allowsLowConfidencePlacement: isGreenProfile || hasTrustedVisualAdjustment,
            allowsSyntheticCaretPlacement: isGreenProfile
                || hasTrustedVisualAdjustment
                || allowsSyntheticCaretPlacement
                || input.hasProofedSyntheticCaret
                || strictVisualProofSyntheticCaretEnabled
        )
    }
}

public struct CompatibilityPlacementTrustInput: Equatable, Sendable {
    public let hasTrustedVisualAdjustment: Bool
    public let hasProofedSyntheticCaret: Bool
    public let screenshotTracingEnabled: Bool
    public let shouldCaptureScreenshot: Bool

    public init(
        hasTrustedVisualAdjustment: Bool = false,
        hasProofedSyntheticCaret: Bool = false,
        screenshotTracingEnabled: Bool = false,
        shouldCaptureScreenshot: Bool = false
    ) {
        self.hasTrustedVisualAdjustment = hasTrustedVisualAdjustment
        self.hasProofedSyntheticCaret = hasProofedSyntheticCaret
        self.screenshotTracingEnabled = screenshotTracingEnabled
        self.shouldCaptureScreenshot = shouldCaptureScreenshot
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
        guard let profile = profile(for: bundleIdentifier) else {
            return false
        }

        return profile.canPresentSuggestions && !profile.isSensitive
    }

    public func supportStatus(for bundleIdentifier: String) -> CompatibilitySupportStatus {
        guard !bundleIdentifier.isEmpty else {
            return .unsupported
        }

        if denylistedBundleIdentifiers.contains(bundleIdentifier) {
            return .denylisted
        }

        if let profile = profiles[bundleIdentifier] {
            return .supported(Self.bestEffortProfileIfUseful(profile) ?? profile)
        }

        return .supported(Self.universalFallbackProfile(for: bundleIdentifier))
    }

    public static func universalFallbackProfile(for bundleIdentifier: String) -> CompatibilityProfile {
        CompatibilityProfile(
            bundleIdentifier: bundleIdentifier,
            displayName: "Universal App",
            appFamily: .unknown,
            supportLevel: .yellow,
            graduationDecision: .wordOnly,
            supportReason: "Best-effort mode for normal text fields. Secure, search, URL, form, and sensitive fields stay blocked.",
            renderMode: .floatingMirror,
            insertionMode: .axValueReplacement,
            fallbackRenderMode: .floatingMirror,
            fallbackInsertionMode: .disabled,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.caret, .line, .field, .window],
            knownFailureModes: ["caret placement may be approximate", "acceptance may fail closed in custom editors"],
            allowsFieldAnchor: true,
            allowsWindowAnchor: true,
            requiresValidatedCaret: false,
            supportsOneWordAcceptance: true,
            supportsFullAcceptance: false,
            allowsUnknownFieldKind: false,
            suppressesAfterInsertionFailure: true,
            allowsDescendantTextFallback: true,
            allowsDetachedSuggestions: true,
            allowsSyntheticCaretPlacement: true,
            promptAppSafetyMode: .wordOnly,
            notes: "Universal fallback profile. Show a floating suggestion for normal editable fields even without app-specific caret proof; keep sensitive field classification and one-word-only acceptance guardrails."
        )
    }

    private static func bestEffortProfileIfUseful(_ profile: CompatibilityProfile) -> CompatibilityProfile? {
        guard !profile.canPresentSuggestions,
              !profile.isSensitive,
              profile.promptAppSafetyMode == .notPrompt else {
            return nil
        }

        return CompatibilityProfile(
            bundleIdentifier: profile.bundleIdentifier,
            displayName: profile.displayName,
            appFamily: profile.appFamily,
            supportLevel: .yellow,
            graduationDecision: .wordOnly,
            supportReason: "\(profile.supportReason) Using best-effort suggestions for normal text fields.",
            renderMode: .floatingMirror,
            insertionMode: .axValueReplacement,
            fallbackRenderMode: .floatingMirror,
            fallbackInsertionMode: .disabled,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.caret, .line, .field, .window],
            knownFailureModes: profile.knownFailureModes + ["best-effort placement may be approximate"],
            allowsFieldAnchor: true,
            allowsWindowAnchor: true,
            requiresValidatedCaret: false,
            supportsOneWordAcceptance: true,
            supportsFullAcceptance: false,
            allowsUnknownFieldKind: false,
            suppressesAfterInsertionFailure: true,
            allowsDescendantTextFallback: true,
            allowsDetachedSuggestions: true,
            allowsSyntheticCaretPlacement: true,
            promptAppSafetyMode: .wordOnly,
            notes: "\(profile.notes) Best-effort fallback is enabled for normal text fields; sensitive field classification still blocks display and acceptance."
        )
    }

    public static let mvp = CompatibilityProfileStore(profiles: [
        CompatibilityProfile(
            bundleIdentifier: "com.apple.TextEdit",
            displayName: "TextEdit",
            appFamily: .nativeAppKit,
            supportLevel: .green,
            supportReason: "Verified suggestions near the cursor and native text insertion.",
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
            supportReason: "Rich text can drift; display can use a floating backup, and insertion fails closed.",
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
            insertionMode: .keyEvents,
            fallbackRenderMode: .floatingMirror,
            fallbackInsertionMode: .keyEvents,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.caret],
            knownFailureModes: ["CodeMirror may hide caret bounds", "whole-editor anchors look detached", "AX value can expose only the visible viewport in long notes"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            requiresValidatedCaret: true,
            suppressesAfterInsertionFailure: false,
            allowsDescendantTextFallback: true,
            allowsDetachedSuggestions: false,
            allowsSyntheticCaretPlacement: true,
            notes: "Yellow Electron target. Prefer capability probing, descendant text fallback for empty CodeMirror web areas, synthetic text-area caret placement, and key-event insertion because CodeMirror AX values can represent only the visible viewport in long virtualized notes. Do not show detached suggestions when CodeMirror hides usable caret bounds."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.apple.mail",
            displayName: "Mail",
            appFamily: .nativeAppKit,
            supportLevel: .diagnosticsOnly,
            graduationDecision: .diagnosticsOnly,
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
            bundleIdentifier: "com.apple.MobileSMS",
            displayName: "Messages",
            appFamily: .nativeAppKit,
            supportLevel: .yellow,
            graduationDecision: .wordOnly,
            supportReason: "Messages compose exposes a normal AX text field, but acceptance stays one-word-only because this is a sendable chat surface.",
            renderMode: .floatingMirror,
            insertionMode: .axValueReplacement,
            fallbackRenderMode: .floatingMirror,
            fallbackInsertionMode: .disabled,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.caret, .field],
            knownFailureModes: ["single-line chat compose can move quickly after send", "whole-suggestion accept is off for chat safety"],
            allowsFieldAnchor: true,
            allowsWindowAnchor: false,
            requiresValidatedCaret: false,
            supportsOneWordAcceptance: true,
            supportsFullAcceptance: false,
            suppressesAfterInsertionFailure: true,
            allowsDescendantTextFallback: true,
            allowsDetachedSuggestions: false,
            allowsSyntheticCaretPlacement: true,
            notes: "Yellow Messages target. Use floating mirror placement from the AXTextField/caret, allow aggressive phrase display, and keep Tab acceptance to one word so suggestions cannot submit a whole chat."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.openai.atlas",
            displayName: "ChatGPT Atlas",
            appFamily: .chromium,
            supportLevel: .diagnosticsOnly,
            graduationDecision: .blocked,
            supportReason: "Atlas can contain private browser text and prompt chats; no no-submit proof exists.",
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
            promptAppSafetyMode: .disabled,
            notes: "Diagnostics-only prompt/browser target until disposable prompt proof verifies placement and Tab accept cannot submit."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.openai.chat",
            displayName: "ChatGPT",
            appFamily: .chromium,
            supportLevel: .diagnosticsOnly,
            graduationDecision: .blocked,
            supportReason: "ChatGPT prompt composers can submit, attach context, and expose tools; no exact-version no-submit proof exists.",
            renderMode: .disabled,
            insertionMode: .disabled,
            fallbackRenderMode: .disabled,
            fallbackInsertionMode: .disabled,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.none],
            knownFailureModes: ["Return can submit", "slash commands and app mentions need proof", "browser/app context can be attached"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsOneWordAcceptance: false,
            supportsFullAcceptance: false,
            isSensitive: true,
            promptAppSafetyMode: .disabled,
            notes: "Diagnostics-only ChatGPT target until a disposable prompt proof verifies placement, one-word accept, no submit, and no tool/context side effects."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.openai.ChatGPT",
            displayName: "ChatGPT",
            appFamily: .chromium,
            supportLevel: .diagnosticsOnly,
            graduationDecision: .blocked,
            supportReason: "ChatGPT prompt composers can submit, attach context, and expose tools; no exact-version no-submit proof exists.",
            renderMode: .disabled,
            insertionMode: .disabled,
            fallbackRenderMode: .disabled,
            fallbackInsertionMode: .disabled,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.none],
            knownFailureModes: ["Return can submit", "slash commands and app mentions need proof", "browser/app context can be attached"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsOneWordAcceptance: false,
            supportsFullAcceptance: false,
            isSensitive: true,
            promptAppSafetyMode: .disabled,
            notes: "Diagnostics-only ChatGPT target until a disposable prompt proof verifies placement, one-word accept, no submit, and no tool/context side effects."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.google.Chrome",
            displayName: "Chrome",
            appFamily: .chromium,
            supportLevel: .yellow,
            supportReason: "Only local textarea and contenteditable fixtures are beta-safe; other browser surfaces need proof.",
            renderMode: .inlineAdjacent,
            insertionMode: .axThenKeyEvents,
            fallbackRenderMode: .floatingMirror,
            fallbackInsertionMode: .axValueReplacement,
            anchorLadder: [.caret, .field],
            knownFailureModes: ["textarea support differs from rich editors", "zero-height caret bounds can occur"],
            allowsDescendantTextFallback: true,
            notes: "Yellow browser target for local textarea and contenteditable fixtures only. Prefer proof-gated synthetic caret inline placement when Chrome hides usable caret bounds, with mirror fallback for unreadable or detached local fixture surfaces. Production browser apps, public pages, chat, hosted docs, Monaco, CodeMirror, and ProseMirror stay blocked until current exact proof exists."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.openai.codex",
            displayName: "Codex",
            appFamily: .customCanvas,
            supportLevel: .yellow,
            supportReason: "Codex prompt support is on for this installed app: Tab and whole-suggestion accept are available, and prompt safety gates stay on.",
            renderMode: .inlineAdjacent,
            insertionMode: .axValueReplacement,
            fallbackRenderMode: .floatingMirror,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.caret],
            knownFailureModes: ["prompt editor may need synthetic caret", "detached whole-box suggestions are disallowed", "key-event insertion can land at the start of the prompt"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsOneWordAcceptance: true,
            supportsFullAcceptance: true,
            requiresNoSubmitAcceptanceProof: false,
            suppressesAfterInsertionFailure: true,
            allowsDetachedSuggestions: false,
            promptAppSafetyMode: .wordOnly,
            notes: "Enabled for this local Codex build with one-word no-submit proof, full-accept no-submit proof, and prompt-safe accepted-text filtering. Detached suggestions, generic key-event insertion, and clipboard fallback stay off."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.anthropic.claude-code",
            displayName: "Claude Code",
            appFamily: .customCanvas,
            supportLevel: .diagnosticsOnly,
            graduationDecision: .diagnosticsOnly,
            supportReason: "The installed Claude Code bundle is a background-only CLI helper; interactive Claude Code typing usually happens inside a terminal host, which is blocked until a separate safe adapter exists.",
            renderMode: .disabled,
            insertionMode: .disabled,
            fallbackRenderMode: .disabled,
            fallbackInsertionMode: .disabled,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.none],
            knownFailureModes: ["foreground prompt surface is not the Claude Code bundle", "terminal-hosted CLI input can submit shell commands"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsOneWordAcceptance: false,
            supportsFullAcceptance: false,
            suppressesAfterInsertionFailure: true,
            allowsDetachedSuggestions: false,
            isSensitive: true,
            promptAppSafetyMode: .disabled,
            notes: "Diagnostics-only Claude Code CLI target. Do not present suggestions for the background-only bundle or terminal-hosted Claude Code sessions until a terminal-host adapter proves one-word Tab accept without submitting shell input or agent prompts."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            displayName: "Claude",
            appFamily: .electron,
            supportLevel: .yellow,
            supportReason: "Claude desktop is proof-only; composer placement still needs more layout proof before any normal beta use.",
            renderMode: .inlineAdjacent,
            insertionMode: .axValueReplacement,
            fallbackRenderMode: .floatingMirror,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.caret],
            knownFailureModes: ["composer may hide caret bounds", "detached whole-window suggestions are disallowed"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsOneWordAcceptance: true,
            supportsFullAcceptance: false,
            requiresNoSubmitAcceptanceProof: true,
            suppressesAfterInsertionFailure: true,
            allowsDetachedSuggestions: false,
            promptAppSafetyMode: .wordOnly,
            notes: "Proof-only target for Claude desktop. Prefer prompt-bound inline suggestions when the composer exposes bounds; otherwise use mirror placement without showing detached whole-window suggestions. Same-slice one-word no-submit proof exists; normal beta use and full accept stay disabled until separate current proof exists."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            appFamily: .webKit,
            supportLevel: .diagnosticsOnly,
            graduationDecision: .blocked,
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
            promptAppSafetyMode: .disabled,
            notes: "Diagnostics-only WebKit browser profile until textarea and rich-editor behavior are proven separately."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.tinyspeck.slackmacgap",
            displayName: "Slack",
            appFamily: .electron,
            supportLevel: .diagnosticsOnly,
            graduationDecision: .blocked,
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
            promptAppSafetyMode: .disabled,
            notes: "Diagnostics-only Electron target until message composer geometry, Enter-preference variants, and one-word no-submit insertion are proven."
        ),
        CompatibilityProfile(
            bundleIdentifier: "ru.keepcoder.Telegram",
            displayName: "Telegram",
            appFamily: .electron,
            supportLevel: .diagnosticsOnly,
            graduationDecision: .blocked,
            supportReason: "Telegram send-by-enter behavior and attachment/caption flows need app-specific no-submit proof.",
            renderMode: .disabled,
            insertionMode: .disabled,
            fallbackRenderMode: .disabled,
            fallbackInsertionMode: .disabled,
            anchorLadder: [.none],
            knownFailureModes: ["send-by-enter preference can submit", "attachment caption flows need no-submit proof"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsOneWordAcceptance: false,
            supportsFullAcceptance: false,
            promptAppSafetyMode: .disabled,
            notes: "Diagnostics-only chat target until Telegram desktop proves one-word accept cannot submit under send-by-enter variants."
        ),
        CompatibilityProfile(
            bundleIdentifier: "notion.id",
            displayName: "Notion",
            appFamily: .electron,
            supportLevel: .diagnosticsOnly,
            graduationDecision: .blocked,
            supportReason: "Notion pages need app-specific ProseMirror placement and insertion proof.",
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
            graduationDecision: .blocked,
            supportReason: "Discord message composers need explicit no-submit proof before suggestions can run.",
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
            promptAppSafetyMode: .disabled,
            notes: "Diagnostics-only chat target until a disposable server/channel proves placement and Tab accept cannot submit."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.hnc.DiscordPTB",
            displayName: "Discord PTB",
            appFamily: .electron,
            supportLevel: .diagnosticsOnly,
            graduationDecision: .blocked,
            supportReason: "Discord message composers need explicit no-submit proof before suggestions can run.",
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
            promptAppSafetyMode: .disabled,
            notes: "Diagnostics-only chat target until a disposable server/channel proves placement and Tab accept cannot submit."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.hnc.DiscordCanary",
            displayName: "Discord Canary",
            appFamily: .electron,
            supportLevel: .diagnosticsOnly,
            graduationDecision: .blocked,
            supportReason: "Discord message composers need explicit no-submit proof before suggestions can run.",
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
            promptAppSafetyMode: .disabled,
            notes: "Diagnostics-only chat target until a disposable server/channel proves placement and Tab accept cannot submit."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.microsoft.VSCode",
            displayName: "VS Code",
            appFamily: .electron,
            supportLevel: .diagnosticsOnly,
            graduationDecision: .blocked,
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
            graduationDecision: .blocked,
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
        "com.github.wez.wezterm",
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
            return "unsupported: no compatibility profile"
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

    public var userFacingSafetySummary: String {
        switch self {
        case let .supported(profile):
            return profile.userFacingSafetySummary
        case .denylisted:
            return "Suggestions stay off here."
        case .unsupported:
            return "Suggestions use best-effort mode only after SteadyType can identify a normal text field."
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
