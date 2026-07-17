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

    public func replacingBundleIdentifier(_ bundleIdentifier: String) -> CompatibilityProfile {
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
            notes: notes
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
    public let fallbackProfile: CompatibilityProfile

    public init(
        profiles: [CompatibilityProfile],
        denylistedBundleIdentifiers: Set<String> = Self.defaultDenylist,
        fallbackProfile: CompatibilityProfile = Self.defaultOnFallbackProfile
    ) {
        self.profiles = Dictionary(uniqueKeysWithValues: profiles.map { ($0.bundleIdentifier, $0) })
        self.denylistedBundleIdentifiers = denylistedBundleIdentifiers
        self.fallbackProfile = fallbackProfile
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
        if denylistedBundleIdentifiers.contains(bundleIdentifier) {
            return .denylisted
        }

        if let profile = profiles[bundleIdentifier] {
            return .supported(profile)
        }

        return .supported(fallbackProfile.replacingBundleIdentifier(bundleIdentifier))
    }

    public static let defaultOnFallbackProfile = CompatibilityProfile(
        bundleIdentifier: "*",
        displayName: "Generic App",
        appFamily: .unknown,
        supportLevel: .yellow,
        supportReason: "Default-on generic Accessibility path for apps without a custom profile.",
        renderMode: .inlineAdjacent,
        insertionMode: .axThenKeyEvents,
        fallbackRenderMode: .floatingMirror,
        fallbackInsertionMode: .axValueReplacement,
        knownFailureModes: ["generic AX support may have bad caret placement or insertion in untested apps"],
        allowsDescendantTextFallback: true,
        notes: "Default-on fallback. Use native Accessibility first, fall back to mirror placement and AX value replacement, and let per-app pause disable bad targets until a custom adapter is added."
    )

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
            supportReason: "Electron editors can hide caret bounds, so this uses caret-locked inline placement or stays hidden.",
            renderMode: .inlineAdjacent,
            insertionMode: .keyEvents,
            fallbackRenderMode: nil,
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
            notes: "Yellow Electron target. Prefer capability probing, descendant text fallback for empty CodeMirror web areas, synthetic text-area caret placement, and key-event insertion because CodeMirror AX values can represent only the visible viewport in long virtualized notes. Obsidian is inline-or-hidden: do not fall back to a mirror or detached whole-editor suggestion when CodeMirror hides usable caret bounds."
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
            supportReason: "Messages compose is a sendable chat surface; suggestions require explicit proof mode and remain one-word-only.",
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
            requiresNoSubmitAcceptanceProof: true,
            suppressesAfterInsertionFailure: true,
            allowsDescendantTextFallback: true,
            allowsDetachedSuggestions: false,
            allowsSyntheticCaretPlacement: true,
            promptAppSafetyMode: .wordOnly,
            notes: "Proof-only Messages target. Use floating mirror placement from the AXTextField/caret only during explicit proof mode, keep Tab acceptance to one word, and keep whole-suggestion accept off until no-submit proof is broader."
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
            insertionMode: .axThenKeyEvents,
            fallbackRenderMode: .floatingMirror,
            fallbackInsertionMode: .axValueReplacement,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.caret],
            knownFailureModes: ["prompt editor may need synthetic caret", "detached whole-box suggestions are disallowed"],
            allowsFieldAnchor: false,
            allowsWindowAnchor: false,
            supportsOneWordAcceptance: true,
            supportsFullAcceptance: true,
            requiresNoSubmitAcceptanceProof: false,
            suppressesAfterInsertionFailure: false,
            allowsDetachedSuggestions: false,
            promptAppSafetyMode: .wordOnly,
            notes: "Enabled for this local Codex build with one-word no-submit proof, full-accept no-submit proof, prompt-safe accepted-text filtering, and a guarded AX-then-key-event insertion ladder. Detached suggestions and clipboard fallback stay off."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.anthropic.claude-code",
            displayName: "Claude Code",
            appFamily: .customCanvas,
            supportLevel: .yellow,
            graduationDecision: .wordOnly,
            supportReason: "Claude Code is enabled for dogfood through the direct app profile and terminal-host adapter.",
            renderMode: .floatingMirror,
            insertionMode: .clipboardFallbackOptIn,
            fallbackRenderMode: .floatingMirror,
            fallbackInsertionMode: .keyEvents,
            fieldIdentityMode: .stableBounds,
            anchorLadder: [.caret],
            knownFailureModes: ["foreground prompt surface is often a terminal host", "terminal-hosted CLI input can submit shell commands"],
            allowsFieldAnchor: true,
            allowsWindowAnchor: false,
            requiresValidatedCaret: false,
            supportsOneWordAcceptance: true,
            supportsFullAcceptance: false,
            requiresNoSubmitAcceptanceProof: true,
            suppressesAfterInsertionFailure: true,
            allowsDetachedSuggestions: false,
            allowsSyntheticCaretPlacement: true,
            promptAppSafetyMode: .wordOnly,
            notes: "Default-on Claude Code dogfood target. Direct app profile uses floating placement and one-word acceptance only. Terminal-hosted sessions use the Claude Code terminal adapter without requiring proof mode, and should be fixed app-by-app when screenshots show bad placement or insertion."
        ),
        CompatibilityProfile(
            bundleIdentifier: "com.anthropic.claudefordesktop",
            displayName: "Claude",
            appFamily: .electron,
            supportLevel: .yellow,
            supportReason: "Claude desktop is enabled for dogfood; composer placement will be fixed from app screenshots.",
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
            notes: "Default-on Claude desktop target. Prefer prompt-bound inline suggestions when the composer exposes bounds; otherwise use mirror placement without showing detached whole-window suggestions. Same-slice one-word no-submit proof exists; broaden layout fixes from dogfood screenshots."
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
        "com.apple.dt.Xcode",
        "com.microsoft.VSCodeInsiders",
        "com.visualstudio.code.oss",
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
            return "Blocked: high-risk app"
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
            return "Suggestions are intentionally off until this app has a compatibility profile."
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
