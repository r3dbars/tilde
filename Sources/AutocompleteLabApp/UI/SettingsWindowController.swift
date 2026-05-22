import AppKit
import AutocompleteLabCore

struct SettingsLayoutStyle {
    let usesFramedCards: Bool
    let usesSystemFonts: Bool
    let usesDynamicSystemColors: Bool
    let appearanceCoverage: NativeAppearanceCoverage
    let sectionSpacing: CGFloat
    let sectionItemSpacing: CGFloat
    let contentInsets: NSEdgeInsets
    let preferredContentSize: NSSize
    let minimumContentSize: NSSize
    let visibleScreenInset: CGFloat
    let secondaryLabelMaxWidth: CGFloat

    static let nativeUtility = SettingsLayoutStyle(
        usesFramedCards: false,
        usesSystemFonts: true,
        usesDynamicSystemColors: true,
        appearanceCoverage: .lightDarkAndHighContrast,
        sectionSpacing: 14,
        sectionItemSpacing: 5,
        contentInsets: NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24),
        preferredContentSize: NSSize(width: 560, height: 680),
        minimumContentSize: NSSize(width: 540, height: 420),
        visibleScreenInset: 32,
        secondaryLabelMaxWidth: 470
    )
}

private final class FlippedSettingsDocumentView: NSView {
    override var isFlipped: Bool {
        true
    }
}

struct SettingsCurrentAppState: Equatable {
    let displayName: String
    let bundleIdentifier: String?
    let supportStatus: CompatibilitySupportStatus
    let isEnabled: Bool
    let disabledAppCount: Int
    let renderModeOverride: SuggestionRenderMode?

    init(
        displayName: String,
        bundleIdentifier: String?,
        supportStatus: CompatibilitySupportStatus,
        isEnabled: Bool,
        disabledAppCount: Int,
        renderModeOverride: SuggestionRenderMode? = nil
    ) {
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.supportStatus = supportStatus
        self.isEnabled = isEnabled
        self.disabledAppCount = disabledAppCount
        self.renderModeOverride = renderModeOverride
    }

    var canToggle: Bool {
        bundleIdentifier != nil && supportStatus.canToggleSuggestions
    }

    var canOverrideMode: Bool {
        guard bundleIdentifier != nil,
              case let .supported(profile) = supportStatus,
              profile.canPresentSuggestions,
              !profile.isSensitive else {
            return false
        }

        return profile.renderMode != .disabled
    }

    var canStartProof: Bool {
        guard bundleIdentifier != nil,
              case let .supported(profile) = supportStatus,
              !profile.isSensitive,
              isEnabled else {
            return false
        }

        return supportStatus.supportLevel != .unsupported
    }

    var shouldShowCheckControls: Bool {
        guard bundleIdentifier != nil,
              case let .supported(profile) = supportStatus,
              profile.canPresentSuggestions,
              !profile.isSensitive else {
            return false
        }

        return true
    }

    var statusText: String {
        guard bundleIdentifier != nil else {
            return "Current app: no app selected"
        }

        guard supportStatus.canToggleSuggestions else {
            return "Current app: \(displayName) is \(supportStatus.supportLevel.menuName)"
        }

        return "Current app: \(displayName) is \(supportStatus.supportLevel.menuName) and \(isEnabled ? "on" : "off")"
    }

    var detailText: String {
        guard bundleIdentifier != nil else {
            return "Open a writing app to see whether suggestions are supported."
        }

        guard supportStatus.canToggleSuggestions else {
            return "\(supportStatus.userFacingReason) Suggestions stay off here."
        }

        if isEnabled {
            return "\(supportStatus.userFacingReason) Suggestions are on for this app."
        }

        return "\(supportStatus.userFacingReason) Suggestions are paused in this app. Resume only where you want suggestions."
    }

    var supportMatrixText: String {
        guard bundleIdentifier != nil else {
            return "Support: choose a writing app to see its lane."
        }

        switch supportStatus {
        case let .supported(profile):
            if profile.isSensitive || !profile.canPresentSuggestions || profile.supportLevel == .diagnosticsOnly {
                return "Support: diagnostics only. Inline suggestions stay off; use check and copy flows only."
            }

            switch profile.supportLevel {
            case .green:
                return "Support: green target. Inline suggestions and one-word Tab are proven here."
            case .yellow:
                return "Support: yellow target. Suggestions are available, but checks and fallback matter."
            case .diagnosticsOnly:
                return "Support: diagnostics only. Inline suggestions stay off; use check and copy flows only."
            case .unsupported:
                return "Support: unsupported. Select text for Command Context copy fallback."
            }
        case .denylisted:
            return "Support: blocked. SteadyType stays out of this app."
        case .unsupported:
            return "Support: unsupported. Select text for Command Context copy fallback."
        }
    }

    var modeText: String {
        guard bundleIdentifier != nil else {
            return "Mode: choose a writing app"
        }

        guard case let .supported(profile) = supportStatus else {
            return "Mode: not set up here"
        }

        let primary = Self.renderModeName(profile.renderMode)
        if let renderModeOverride {
            return "Mode: \(Self.renderModeName(renderModeOverride)) forced (profile \(primary))"
        }

        guard let fallback = profile.fallbackRenderMode,
              fallback != profile.renderMode,
              fallback != .disabled else {
            return "Mode: \(primary)"
        }

        return "Mode: \(primary), \(Self.renderModeName(fallback)) fallback"
    }

    var acceptanceText: String {
        guard bundleIdentifier != nil else {
            return "Acceptance: off until an app is selected"
        }

        guard case let .supported(profile) = supportStatus,
              profile.canPresentSuggestions,
              !profile.isSensitive else {
            return "Acceptance: off here"
        }

        switch (profile.supportsOneWordAcceptance, profile.supportsFullAcceptance) {
        case (true, true):
            return "Keys: Tab accepts one word. The whole-suggestion shortcut works here."
        case (true, false):
            return "Keys: Tab accepts one word. Whole-suggestion accept is off for safety."
        case (false, true):
            return "Keys: whole-suggestion accept only"
        case (false, false):
            return "Acceptance: off here"
        }
    }

    var fallbackText: String {
        CommandFallbackPolicy().decision(
            supportStatus: supportStatus,
            isEnabled: isEnabled,
            hasCurrentApp: bundleIdentifier != nil
        ).statusText
    }

    var toggleTitle: String {
        canToggle ? "Suggestions in this app" : "Suggestions unavailable in this app"
    }

    var menuToggleTitle: String {
        guard bundleIdentifier != nil else {
            return "Pause Current App"
        }

        guard canToggle else {
            return "Suggestions unavailable in \(displayName)"
        }

        return isEnabled ? "Pause in \(displayName)" : "Resume in \(displayName)"
    }

    var modeButtonTitle: String {
        renderModeOverride == .floatingMirror ? "Use Default Placement" : "Use Floating Backup"
    }

    var proofButtonTitle: String {
        if bundleIdentifier == "com.apple.TextEdit", isEnabled {
            return "Check TextEdit"
        }

        if bundleIdentifier == "com.google.Chrome", isEnabled {
            return "Check Chrome"
        }

        return isEnabled ? "Check This App" : "Enable Suggestions First"
    }

    var copyProofCommandButtonTitle: String {
        canCopyProofCommand ? "Copy Check Command" : "No Check Command"
    }

    var canCopyProofCommand: Bool {
        proofCommandClipboardText != nil
    }

    var proofText: String {
        guard bundleIdentifier != nil else {
            return "Check: choose a writing app first."
        }

        guard case let .supported(profile) = supportStatus,
              profile.canPresentSuggestions,
              !profile.isSensitive else {
            return "Check: unavailable here."
        }

        guard isEnabled else {
            return "Check: turn on suggestions for this app first."
        }

        if bundleIdentifier == "com.openai.codex" {
            return "Check: use the guided prompt-app check, press Tab once, and do not press Enter."
        }

        if profile.supportsOneWordAcceptance && !profile.supportsFullAcceptance {
            return "Check: use disposable prompt text, press Tab once, and do not press Enter."
        }

        if profile.supportsOneWordAcceptance && profile.supportsFullAcceptance {
            return "Check: use disposable text, press Tab once, then the whole-suggestion shortcut."
        }

        return "Check: use disposable text and confirm accepted text stays in the field."
    }

    var proofCommandText: String? {
        guard let command = proofCommandClipboardText else {
            return nil
        }

        if bundleIdentifier == "com.apple.Notes" {
            return "Manual checks: \(command.replacingOccurrences(of: "\n", with: "; "))"
        }

        if supportStatus.supportLevel == .yellow {
            return "Manual check: \(command)"
        }

        return "Check command: \(command)"
    }

    var proofCommandClipboardText: String? {
        guard let bundleIdentifier,
              isEnabled,
              case let .supported(profile) = supportStatus,
              profile.canPresentSuggestions,
              !profile.isSensitive else {
            return nil
        }

        switch bundleIdentifier {
        case "com.apple.TextEdit":
            return "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh textedit"
        case "com.google.Chrome":
            return "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture all"
        case "md.obsidian":
            return "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian --manual-gate"
        case "com.apple.Notes":
            return """
            AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate
            AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate
            AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist --manual-gate
            """
        case "com.openai.codex":
            return "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate"
        case "com.anthropic.claudefordesktop":
            return "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude --manual-gate"
        default:
            return nil
        }
    }

    var blockedAppsText: String {
        if disabledAppCount == 0 {
            return "Paused apps: none"
        }

        return "Paused apps: \(disabledAppCount)"
    }

    private static func renderModeName(_ mode: SuggestionRenderMode) -> String {
        switch mode {
        case .inlineAdjacent:
            return "next to the cursor"
        case .floatingMirror:
            return "floating backup"
        case .disabled:
            return "disabled"
        }
    }
}

struct SettingsPermissionState: Equatable {
    let isTrusted: Bool

    var statusText: String {
        isTrusted ? "Accessibility permission: allowed" : "Accessibility permission: needed"
    }

    var detailText: String {
        if isTrusted {
            return "SteadyType can read the focused text field and insert only after you accept. Text stays on this Mac. Screen Recording is not needed for normal use."
        }

        return "Click Allow Accessibility when you are ready. macOS asks so SteadyType can read the focused text field and insert only after you accept. Text stays on this Mac. Screen Recording is not needed for normal use."
    }
}

struct SettingsFirstRunTrustState: Equatable {
    var statusText: String {
        "First run: practice in TextEdit"
    }

    var detailText: String {
        "Suggestions appear near the cursor. Tab accepts one word. Esc dismisses. Pause Suggestions stops suggestions everywhere; Pause in Current App stops only that app."
    }

    var quickStartText: String {
        "60-second path: Allow Accessibility, confirm Local Model is ready, Start TextEdit Practice, press Tab once, press Esc once, then Delete Local Logs."
    }

    var appsText: String {
        "Text stays on this Mac. Start with TextEdit. Use Notes, Obsidian, and Chrome practice pages only when needed. Avoid random websites, search, login, payment, and private fields."
    }
}

struct SettingsPrivacyState: Equatable {
    let tracingPaused: Bool
    let rawContentTracingEnabled: Bool
    let rawContentTracingExpiresAt: Date?
    let screenshotTracingEnabled: Bool
    let screenshotTracingExpiresAt: Date?
    let visiblePageContextEnabled: Bool
    let screenCaptureAccessGranted: Bool
    let diagnosticsPath: String
    let tracePath: String

    var statusText: String {
        "Privacy: stays on this Mac"
    }

    var diagnosticsStatusText: String {
        let traceState = tracingPaused ? "paused" : "recording"
        let screenshotState = screenshotTracingEnabled
            ? (screenshotTracingExpiresAt == nil ? "screenshots on" : "screenshots on temporarily")
            : "screenshots off"
        return "Local check data: \(traceState), \(screenshotState)"
    }

    var contentStatusText: String {
        let state = rawContentTracingEnabled
            ? (rawContentTracingExpiresAt == nil ? "on" : "on temporarily")
            : "off"
        return "Raw text in local logs: \(state)"
    }

    var visiblePageContextStatusText: String {
        if visiblePageContextEnabled && !screenCaptureAccessGranted {
            return "Screen context: on, waiting for Screen Recording permission."
        }

        return "Screen context: \(visiblePageContextEnabled ? "on" : "off"). OCR is local and only helps suggestions."
    }

    var sharingStatusText: String {
        if rawContentTracingEnabled || screenshotTracingEnabled || visiblePageContextEnabled {
            return "Nothing leaves automatically. Share Privacy Bundles, not raw logs or screenshots."
        }

        return "Nothing leaves automatically. Privacy Bundles exclude raw text and screenshots."
    }

    var learningStatusText: String {
        "Learning: local usefulness scores only"
    }

    var screenRecordingPermissionText: String? {
        guard screenshotTracingEnabled || visiblePageContextEnabled else {
            return nil
        }

        if visiblePageContextEnabled && !screenCaptureAccessGranted {
            return "Screen Recording: required for screen context."
        }

        if screenshotTracingEnabled && screenshotTracingExpiresAt == nil {
            return "Screen Recording: used only for local placement screenshots while enabled."
        }

        if screenshotTracingEnabled && !visiblePageContextEnabled {
            return "Screen Recording: used only for temporary local placement screenshots."
        }

        return "Screen Recording: used only for local screenshots and screen context while enabled."
    }

    var pathText: String {
        "Diagnostics log: \(diagnosticsPath) | Check data: \(tracePath)"
    }
}

struct SettingsKeyboardShortcutState: Equatable {
    let acceptAllShortcut: AcceptAllShortcut
    let conflict: KeyboardShortcutConflictEvaluation

    init(
        acceptAllShortcut: AcceptAllShortcut,
        currentApp: SettingsCurrentAppState? = nil
    ) {
        self.acceptAllShortcut = acceptAllShortcut
        let context = currentApp.map { app -> KeyboardShortcutConflictContext in
            let canPresentSuggestions: Bool
            let supportsFullAcceptance: Bool
            if case let .supported(profile) = app.supportStatus {
                canPresentSuggestions = profile.canPresentSuggestions && !profile.isSensitive
                supportsFullAcceptance = profile.supportsFullAcceptance
            } else {
                canPresentSuggestions = false
                supportsFullAcceptance = false
            }

            return KeyboardShortcutConflictContext(
                appDisplayName: app.displayName,
                isAppEnabled: app.isEnabled,
                canPresentSuggestions: canPresentSuggestions,
                supportsFullAcceptance: supportsFullAcceptance
            )
        }
        conflict = KeyboardShortcutConflictPolicy().evaluation(
            acceptAllShortcut: acceptAllShortcut,
            context: context
        )
    }

    var statusText: String {
        "Shortcuts: Tab accepts one word | \(acceptAllShortcut.displayName) accepts whole suggestion"
    }

    var cycleButtonTitle: String {
        switch acceptAllShortcut {
        case .backtick:
            return "Use Option-Tab"
        case .optionTab, .disabled:
            return "Use Backtick"
        }
    }

    var acceptAllPickerLabel: String {
        "Whole suggestion:"
    }

    var conflictText: String {
        conflict.statusText
    }

    var conflictDetailText: String {
        conflict.detailText
    }

    var perAppProfileText: String {
        conflict.perAppProfileText
    }
}

struct SettingsFeedbackState: Equatable {
    var statusText: String {
        "Feedback: redacted Privacy Bundle only"
    }

    var detailText: String {
        "Use this for beta feedback. It excludes raw text, prompts, accepted text, and screenshots."
    }

    var buttonTitle: String {
        "Export Privacy Bundle"
    }
}

enum SettingsPracticePrimaryAction: Equatable {
    case requestAccessibility
    case performRuntimeAction(RuntimeReadinessAction)
    case openTextEditPractice
    case none
}

struct SettingsPracticeState: Equatable {
    let isTrusted: Bool
    let suggestionsPaused: Bool
    let runtimeReport: RuntimeReadinessReport
    let isModelInstallInProgress: Bool
    let isTextEditEnabled: Bool

    static let preview = SettingsPracticeState(
        isTrusted: true,
        suggestionsPaused: false,
        runtimeReport: RuntimeReadinessReport(
            stage: .ready,
            summary: "ready",
            action: .none,
            isReady: true
        ),
        isModelInstallInProgress: false,
        isTextEditEnabled: true
    )

    var statusText: String {
        if !isTrusted {
            return "Practice: allow Accessibility first"
        }

        if !runtimeReport.allowsSuggestions {
            return "Practice: local model not ready"
        }

        if suggestionsPaused {
            return "Practice: ready, suggestions paused"
        }

        return "Practice: ready in TextEdit"
    }

    var detailText: String {
        "Safe target: TextEdit. Start Practice opens a disposable local file and lets you try suggestions near the cursor. No Screen Recording needed."
    }

    var modelText: String {
        RuntimeReadinessPresentation(report: runtimeReport).modelText
    }

    var textEditText: String {
        isTextEditEnabled
            ? "TextEdit: enabled for suggestions"
            : "TextEdit: will be enabled for this practice"
    }

    var stepsText: String {
        "Try: press Tab once for one word, type again and press Esc to dismiss, then pause suggestions or delete local logs before leaving."
    }

    var primaryAction: SettingsPracticePrimaryAction {
        if !isTrusted {
            return .requestAccessibility
        }

        if isModelInstallInProgress {
            return .none
        }

        guard runtimeReport.allowsSuggestions else {
            switch runtimeReport.action {
            case .installModel, .repairModel, .revealModelFolder, .retry:
                return .performRuntimeAction(runtimeReport.action)
            default:
                return .none
            }
        }

        return .openTextEditPractice
    }

    var primaryButtonTitle: String {
        switch primaryAction {
        case .requestAccessibility:
            return "Allow Accessibility"
        case let .performRuntimeAction(action):
            return action == .retry ? "Retry Model" : action.displayName
        case .openTextEditPractice:
            return "Start TextEdit Practice"
        case .none:
            return isModelInstallInProgress ? "Installing Model..." : "Practice Not Ready"
        }
    }

    var isPrimaryButtonEnabled: Bool {
        primaryAction != .none
    }

    var pauseButtonTitle: String {
        suggestionsPaused ? "Resume Suggestions" : "Pause Suggestions"
    }

    var deleteTracesButtonTitle: String {
        "Delete Local Logs"
    }
}

struct SettingsSuggestionAggressivenessState: Equatable {
    let tuning: SuggestionTuning

    init(tuning: SuggestionTuning) {
        self.tuning = tuning
    }

    init(aggressiveness: SuggestionAggressiveness) {
        self.tuning = SuggestionTuning(aggressiveness: aggressiveness)
    }

    var statusText: String {
        "Aggressiveness: \(tuning.aggressivenessLevel)/\(SuggestionTuning.maximumAggressivenessLevel) - \(tuning.displayName)"
    }

    var detailText: String {
        tuning.detailText
    }

    var boringGuardrailText: String {
        "Guardrail: short, boring next words first. Raise sliders only after accepted-and-kept data supports it."
    }

    var maxWordsText: String {
        "Words shown: \(tuning.maxVisibleWords)"
    }

    var maxWordsDetailText: String {
        "Caps visible phrase suggestions at \(tuning.maxVisibleWords) \(tuning.maxVisibleWords == 1 ? "word" : "words")."
    }

    var aggressivenessSliderValue: Double {
        Double(tuning.aggressivenessLevel)
    }

    var maxWordsSliderValue: Double {
        Double(tuning.maxVisibleWords)
    }
}

struct SettingsSuggestionDecisionState: Equatable {
    let rawDecision: String

    init(_ rawDecision: String) {
        self.rawDecision = rawDecision.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var statusText: String {
        switch normalizedPrefix {
        case "blocked":
            return "Suggestion status: quiet"
        case "waiting":
            return "Suggestion status: waiting"
        case "queued", "running":
            return "Suggestion status: thinking locally"
        case "shown", "kept current suggestion":
            return "Suggestion status: visible"
        case "accepted":
            return "Suggestion status: accepted"
        case "hidden":
            return "Suggestion status: hidden"
        case "paused":
            return "Suggestion status: paused"
        case "ready", "starting":
            return "Suggestion status: ready"
        default:
            guard !displayPrefix.isEmpty else {
                return "Suggestion status: ready"
            }

            return "Suggestion status: \(displayPrefix)"
        }
    }

    var detailText: String {
        switch normalizedPrefix {
        case "blocked":
            let reason = reasonText ?? "a safety or timing check paused suggestions"
            return "Why quiet: \(reason). Keep typing, or use Command Context for copy-only fallback."
        case "waiting":
            let reason = reasonText ?? "the app needs a moment to settle"
            return "Waiting: \(reason). This prevents jumpy suggestions."
        case "queued", "running":
            return "Thinking locally. Text stays on this Mac."
        case "shown", "kept current suggestion":
            return "Visible near the cursor. Tab accepts one word; Esc dismisses."
        case "accepted":
            return "Accepted. SteadyType will recompute after the field settles."
        case "hidden":
            return "Hidden. Keep typing to restart suggestions."
        case "paused":
            return "Paused. Resume suggestions when you want them again."
        case "ready", "starting":
            return "Ready when you type in a supported writing field."
        default:
            return "Latest local decision: \(rawDecision.isEmpty ? "ready" : rawDecision)"
        }
    }

    private var displayPrefix: String {
        guard let separatorIndex = rawDecision.firstIndex(of: ":") else {
            return rawDecision
        }

        return String(rawDecision[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedPrefix: String {
        let prefix = displayPrefix.lowercased()
        if prefix.isEmpty {
            return "ready"
        }

        if prefix.hasPrefix("kept current suggestion") {
            return "kept current suggestion"
        }

        for knownPrefix in ["blocked", "waiting", "queued", "running", "shown", "accepted", "hidden", "paused", "ready", "starting"] {
            if prefix == knownPrefix || prefix.hasPrefix("\(knownPrefix) ") {
                return knownPrefix
            }
        }

        return prefix
    }

    private var reasonText: String? {
        guard let separatorIndex = rawDecision.firstIndex(of: ":") else {
            return nil
        }

        let nextIndex = rawDecision.index(after: separatorIndex)
        let reason = rawDecision[nextIndex...].trimmingCharacters(in: .whitespacesAndNewlines)
        return reason.isEmpty ? nil : reason
    }
}

struct SettingsOnboardingState: Equatable {
    let isTrusted: Bool
    let suggestionsPaused: Bool
    let runtimeGuidance: RuntimeReadinessGuidance

    var text: String {
        if !isTrusted {
            return "Allow Accessibility so suggestions can appear near the cursor and insert only when you accept. Text stays on this Mac."
        }

        if suggestionsPaused {
            return "Paused. Resume when you want suggestions."
        }

        return runtimeGuidance.message.replacingOccurrences(of: "delete traces", with: "delete local logs")
    }
}

struct SettingsFieldControlState: Equatable {
    let appDisplayName: String?
    let hasFieldTarget: Bool
    let isCurrentField: Bool
    let isSilenced: Bool

    var statusText: String {
        guard hasFieldTarget else {
            return "Current field: no writing field selected"
        }

        let scope = isCurrentField ? "Current field" : "Last field"
        if isSilenced {
            return "\(scope): silenced for this session"
        }

        if let appDisplayName {
            return "\(scope): active in \(appDisplayName)"
        }

        return "\(scope): active"
    }

    var detailText: String {
        guard hasFieldTarget else {
            return "Click into a writing field to silence only that field."
        }

        if isSilenced {
            return "Suggestions stay off here until you leave this field."
        }

        return "Silence only this field for the current session; other fields and apps stay available."
    }

    var buttonTitle: String {
        isSilenced ? "Field Silenced" : "Silence This Field"
    }

    var canSilence: Bool {
        hasFieldTarget && !isSilenced
    }
}

@MainActor
final class SettingsWindowController: NSObject {
    private let window: NSWindow
    private let contentScrollView = NSScrollView()
    private let scrollDocumentView = FlippedSettingsDocumentView()
    private let firstRunTrustLabel = NSTextField(labelWithString: "")
    private let firstRunTrustDetailLabel = NSTextField(labelWithString: "")
    private let firstRunTrustQuickStartLabel = NSTextField(labelWithString: "")
    private let firstRunTrustAppsLabel = NSTextField(labelWithString: "")
    private let permissionLabel = NSTextField(labelWithString: "")
    private let permissionDetailLabel = NSTextField(labelWithString: "")
    private let runtimeLabel = NSTextField(labelWithString: "")
    private let runtimeDetailLabel = NSTextField(labelWithString: "")
    private let runtimeActionLabel = NSTextField(labelWithString: "")
    private let runtimeTargetLabel = NSTextField(labelWithString: "")
    private let modelDirectoryLabel = NSTextField(labelWithString: "")
    private let modelInstallStatusLabel = NSTextField(labelWithString: "")
    private let practiceLabel = NSTextField(labelWithString: "")
    private let practiceDetailLabel = NSTextField(labelWithString: "")
    private let practiceModelLabel = NSTextField(labelWithString: "")
    private let practiceTextEditLabel = NSTextField(labelWithString: "")
    private let practiceStepsLabel = NSTextField(labelWithString: "")
    private let practicePrimaryButton = NSButton(title: "Start TextEdit Practice", target: nil, action: nil)
    private let practicePauseButton = NSButton(title: "Pause Suggestions", target: nil, action: nil)
    private let practiceDeleteTracesButton = NSButton(title: "Delete Local Logs", target: nil, action: nil)
    private let controlLabel = NSTextField(labelWithString: "")
    private let controlDetailLabel = NSTextField(labelWithString: "")
    private let togglePauseButton = NSButton(checkboxWithTitle: "Suggestions everywhere", target: nil, action: nil)
    private let pause15MinutesButton = NSButton(title: "15 Minutes", target: nil, action: nil)
    private let pause1HourButton = NSButton(title: "1 Hour", target: nil, action: nil)
    private let pauseUntilTomorrowButton = NSButton(title: "Until Tomorrow", target: nil, action: nil)
    private let fieldControlLabel = NSTextField(labelWithString: "")
    private let fieldControlDetailLabel = NSTextField(labelWithString: "")
    private let silenceFieldButton = NSButton(title: "Silence This Field", target: nil, action: nil)
    private let runtimeActionButton = NSButton(title: "Open Model Folder", target: nil, action: nil)
    private let currentAppLabel = NSTextField(labelWithString: "")
    private let currentAppDetailLabel = NSTextField(labelWithString: "")
    private let currentAppSupportLabel = NSTextField(labelWithString: "")
    private let currentAppModeLabel = NSTextField(labelWithString: "")
    private let currentAppAcceptanceLabel = NSTextField(labelWithString: "")
    private let currentAppFallbackLabel = NSTextField(labelWithString: "")
    private let currentAppProofLabel = NSTextField(labelWithString: "")
    private let currentAppProofCommandLabel = NSTextField(labelWithString: "")
    private let disabledAppsLabel = NSTextField(labelWithString: "")
    private let suggestionDecisionLabel = NSTextField(labelWithString: "")
    private let suggestionDecisionDetailLabel = NSTextField(labelWithString: "")
    private let toggleCurrentAppButton = NSButton(
        checkboxWithTitle: "Suggestions in this app",
        target: nil,
        action: nil
    )
    private let forceMirrorModeButton = NSButton(title: "Use Floating Backup", target: nil, action: nil)
    private let startAppProofButton = NSButton(title: "Check This App", target: nil, action: nil)
    private let copyProofCommandButton = NSButton(title: "Copy Check Command", target: nil, action: nil)
    private let enableAllAppsButton = NSButton(title: "Resume Every Paused App", target: nil, action: nil)
    private let privacyLabel = NSTextField(labelWithString: "")
    private let diagnosticsStatusLabel = NSTextField(labelWithString: "")
    private let rawContentStatusLabel = NSTextField(labelWithString: "")
    private let visiblePageContextStatusLabel = NSTextField(labelWithString: "")
    private let privacySharingStatusLabel = NSTextField(labelWithString: "")
    private let learningStatusLabel = NSTextField(labelWithString: "")
    private let screenRecordingPermissionLabel = NSTextField(labelWithString: "")
    private let privacyPathLabel = NSTextField(labelWithString: "")
    private let feedbackLabel = NSTextField(labelWithString: "")
    private let feedbackDetailLabel = NSTextField(labelWithString: "")
    private let exportPrivacyBundleButton = NSButton(title: "Export Privacy Bundle", target: nil, action: nil)
    private let toggleTracingButton = NSButton(
        checkboxWithTitle: "Record local check data",
        target: nil,
        action: nil
    )
    private let toggleRawTraceButton = NSButton(
        checkboxWithTitle: "Include raw text in local logs",
        target: nil,
        action: nil
    )
    private let toggleScreenshotTraceButton = NSButton(
        checkboxWithTitle: "Save placement screenshots",
        target: nil,
        action: nil
    )
    private let toggleVisiblePageContextButton = NSButton(
        checkboxWithTitle: "Use screen context",
        target: nil,
        action: nil
    )
    private let deleteLocalLogsButton = NSButton(title: "Delete Local Logs", target: nil, action: nil)
    private let clearLearningDataButton = NSButton(title: "Clear Learned Suggestions", target: nil, action: nil)
    private let shortcutLabel = NSTextField(labelWithString: "")
    private let shortcutConflictLabel = NSTextField(labelWithString: "")
    private let shortcutConflictDetailLabel = NSTextField(labelWithString: "")
    private let shortcutPerAppProfileLabel = NSTextField(labelWithString: "")
    private let acceptAllShortcutLabel = NSTextField(labelWithString: "Whole suggestion:")
    private let acceptAllShortcutPopup = NSPopUpButton()
    private let cycleAcceptAllShortcutButton = NSButton(title: "Use Option-Tab", target: nil, action: nil)
    private let aggressivenessLabel = NSTextField(labelWithString: "")
    private let aggressivenessDetailLabel = NSTextField(labelWithString: "")
    private let boringGuardrailLabel = NSTextField(labelWithString: "")
    private let aggressivenessSlider = NSSlider()
    private let maxWordsLabel = NSTextField(labelWithString: "")
    private let maxWordsDetailLabel = NSTextField(labelWithString: "")
    private let maxWordsSlider = NSSlider()
    private let firstRunLabel = NSTextField(wrappingLabelWithString: "")
    private let requestPermission: () -> Void
    private let openAccessibilitySettings: () -> Void
    private let toggleSuggestionsPaused: () -> Void
    private let pauseSuggestionsFor15Minutes: () -> Void
    private let pauseSuggestionsFor1Hour: () -> Void
    private let pauseSuggestionsUntilTomorrow: () -> Void
    private let silenceCurrentField: () -> Void
    private let performRuntimeAction: (RuntimeReadinessAction) -> Void
    private let toggleCurrentApp: () -> Void
    private let toggleCurrentAppMirrorMode: () -> Void
    private let startCurrentAppProof: () -> Void
    private let startTextEditPractice: () -> Void
    private let enableAllApps: () -> Void
    private let toggleTracingPaused: () -> Void
    private let toggleRawContentTracing: () -> Void
    private let toggleScreenshotTracing: () -> Void
    private let toggleVisiblePageContext: () -> Void
    private let deleteLocalLogs: () -> Void
    private let clearLearningData: () -> Void
    private let exportPrivacyBundle: () -> Void
    private let cycleAcceptAllShortcut: () -> Void
    private let setAcceptAllShortcut: (AcceptAllShortcut) -> Void
    private let setSuggestionAggressivenessLevel: (Int) -> Void
    private let setSuggestionMaxVisibleWords: (Int) -> Void
    private let layoutStyle = SettingsLayoutStyle.nativeUtility
    private var currentRuntimeAction: RuntimeReadinessAction = .none
    private var currentPracticePrimaryAction: SettingsPracticePrimaryAction = .none
    private var currentProofCommandClipboardText: String?

    init(
        requestPermission: @escaping () -> Void,
        openAccessibilitySettings: @escaping () -> Void,
        toggleSuggestionsPaused: @escaping () -> Void,
        pauseSuggestionsFor15Minutes: @escaping () -> Void = {},
        pauseSuggestionsFor1Hour: @escaping () -> Void = {},
        pauseSuggestionsUntilTomorrow: @escaping () -> Void = {},
        silenceCurrentField: @escaping () -> Void,
        performRuntimeAction: @escaping (RuntimeReadinessAction) -> Void,
        toggleCurrentApp: @escaping () -> Void,
        toggleCurrentAppMirrorMode: @escaping () -> Void,
        startCurrentAppProof: @escaping () -> Void,
        startTextEditPractice: @escaping () -> Void = {},
        enableAllApps: @escaping () -> Void,
        toggleTracingPaused: @escaping () -> Void,
        toggleRawContentTracing: @escaping () -> Void,
        toggleScreenshotTracing: @escaping () -> Void,
        toggleVisiblePageContext: @escaping () -> Void,
        deleteLocalLogs: @escaping () -> Void,
        clearLearningData: @escaping () -> Void,
        exportPrivacyBundle: @escaping () -> Void = {},
        cycleAcceptAllShortcut: @escaping () -> Void,
        setAcceptAllShortcut: @escaping (AcceptAllShortcut) -> Void,
        setSuggestionAggressivenessLevel: @escaping (Int) -> Void,
        setSuggestionMaxVisibleWords: @escaping (Int) -> Void
    ) {
        self.requestPermission = requestPermission
        self.openAccessibilitySettings = openAccessibilitySettings
        self.toggleSuggestionsPaused = toggleSuggestionsPaused
        self.pauseSuggestionsFor15Minutes = pauseSuggestionsFor15Minutes
        self.pauseSuggestionsFor1Hour = pauseSuggestionsFor1Hour
        self.pauseSuggestionsUntilTomorrow = pauseSuggestionsUntilTomorrow
        self.silenceCurrentField = silenceCurrentField
        self.performRuntimeAction = performRuntimeAction
        self.toggleCurrentApp = toggleCurrentApp
        self.toggleCurrentAppMirrorMode = toggleCurrentAppMirrorMode
        self.startCurrentAppProof = startCurrentAppProof
        self.startTextEditPractice = startTextEditPractice
        self.enableAllApps = enableAllApps
        self.toggleTracingPaused = toggleTracingPaused
        self.toggleRawContentTracing = toggleRawContentTracing
        self.toggleScreenshotTracing = toggleScreenshotTracing
        self.toggleVisiblePageContext = toggleVisiblePageContext
        self.deleteLocalLogs = deleteLocalLogs
        self.clearLearningData = clearLearningData
        self.exportPrivacyBundle = exportPrivacyBundle
        self.cycleAcceptAllShortcut = cycleAcceptAllShortcut
        self.setAcceptAllShortcut = setAcceptAllShortcut
        self.setSuggestionAggressivenessLevel = setSuggestionAggressivenessLevel
        self.setSuggestionMaxVisibleWords = setSuggestionMaxVisibleWords

        let contentView = NSVisualEffectView(
            frame: NSRect(origin: .zero, size: SettingsLayoutStyle.nativeUtility.preferredContentSize)
        )
        contentView.material = .contentBackground
        contentView.blendingMode = .behindWindow
        contentView.state = .active
        window = NSWindow(
            contentRect: contentView.frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "SteadyType"
        window.contentView = contentView
        window.isReleasedWhenClosed = false
        window.contentMinSize = SettingsLayoutStyle.nativeUtility.minimumContentSize
        window.isMovableByWindowBackground = true

        super.init()

        buildContent(in: contentView)
    }

    func show(
        isTrusted: Bool,
        suggestionsPaused: Bool,
        suggestionsPausedUntil: Date? = nil,
        runtimeReport: RuntimeReadinessReport,
        runtimeTargetSummary: String,
        modelDirectoryPath: String,
        modelInstallStatusText: String?,
        isModelInstallInProgress: Bool,
        currentApp: SettingsCurrentAppState,
        fieldControl: SettingsFieldControlState,
        practice: SettingsPracticeState = .preview,
        privacy: SettingsPrivacyState,
        keyboardShortcuts: SettingsKeyboardShortcutState,
        suggestionAggressiveness: SettingsSuggestionAggressivenessState,
        lastSuggestionDecision: String
    ) {
        refresh(
            isTrusted: isTrusted,
            suggestionsPaused: suggestionsPaused,
            suggestionsPausedUntil: suggestionsPausedUntil,
            runtimeReport: runtimeReport,
            runtimeTargetSummary: runtimeTargetSummary,
            modelDirectoryPath: modelDirectoryPath,
            modelInstallStatusText: modelInstallStatusText,
            isModelInstallInProgress: isModelInstallInProgress,
            currentApp: currentApp,
            fieldControl: fieldControl,
            practice: practice,
            privacy: privacy,
            keyboardShortcuts: keyboardShortcuts,
            suggestionAggressiveness: suggestionAggressiveness,
            lastSuggestionDecision: lastSuggestionDecision
        )
        fitWindowInsideVisibleScreen()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    var isShowing: Bool {
        window.isVisible
    }

    var usesScrollableSettingsContent: Bool {
        guard let documentView = contentScrollView.documentView else {
            return false
        }

        return contentScrollView.hasVerticalScroller
            && !contentScrollView.hasHorizontalScroller
            && documentView === scrollDocumentView
    }

    var minimumSettingsContentSize: NSSize {
        window.contentMinSize
    }

    var preferredSettingsContentSize: NSSize {
        layoutStyle.preferredContentSize
    }

    var runtimeDetailTextForTesting: String {
        runtimeDetailLabel.stringValue
    }

    func refresh(
        isTrusted: Bool,
        suggestionsPaused: Bool,
        suggestionsPausedUntil: Date? = nil,
        now: Date = Date(),
        runtimeReport: RuntimeReadinessReport,
        runtimeTargetSummary: String,
        modelDirectoryPath: String,
        modelInstallStatusText: String?,
        isModelInstallInProgress: Bool,
        currentApp: SettingsCurrentAppState,
        fieldControl: SettingsFieldControlState,
        practice: SettingsPracticeState = .preview,
        privacy: SettingsPrivacyState,
        keyboardShortcuts: SettingsKeyboardShortcutState,
        suggestionAggressiveness: SettingsSuggestionAggressivenessState,
        lastSuggestionDecision: String
    ) {
        let guidance = RuntimeReadinessGuidance(report: runtimeReport)
        let permission = SettingsPermissionState(isTrusted: isTrusted)
        let firstRunTrust = SettingsFirstRunTrustState()
        let pauseControl = ControlPauseState(
            isPaused: suggestionsPaused,
            pausedUntil: suggestionsPausedUntil,
            now: now
        )
        firstRunTrustLabel.stringValue = firstRunTrust.statusText
        firstRunTrustDetailLabel.stringValue = firstRunTrust.detailText
        firstRunTrustQuickStartLabel.stringValue = firstRunTrust.quickStartText
        firstRunTrustAppsLabel.stringValue = firstRunTrust.appsText
        permissionLabel.stringValue = permission.statusText
        permissionDetailLabel.stringValue = permission.detailText
        controlLabel.stringValue = pauseControl.settingsSummaryText
        controlDetailLabel.stringValue = pauseControl.settingsDetailText
        let suggestionDecision = SettingsSuggestionDecisionState(lastSuggestionDecision)
        suggestionDecisionLabel.stringValue = suggestionDecision.statusText
        suggestionDecisionDetailLabel.stringValue = suggestionDecision.detailText
        togglePauseButton.state = suggestionsPaused ? .off : .on
        togglePauseButton.title = pauseControl.toggleTitle
        pause15MinutesButton.isEnabled = pauseControl.shouldEnableTimedPauseButtons
        pause1HourButton.isEnabled = pauseControl.shouldEnableTimedPauseButtons
        pauseUntilTomorrowButton.isEnabled = pauseControl.shouldEnableTimedPauseButtons
        fieldControlLabel.stringValue = fieldControl.statusText
        fieldControlDetailLabel.stringValue = fieldControl.detailText
        silenceFieldButton.title = fieldControl.buttonTitle
        silenceFieldButton.isEnabled = fieldControl.canSilence
        runtimeLabel.stringValue = "Local model: \(runtimeReport.summary)"
        let runtimePresentation = RuntimeReadinessPresentation(report: runtimeReport)
        runtimeDetailLabel.stringValue = runtimePresentation.settingsDetailText
        runtimeDetailLabel.isHidden = runtimePresentation.settingsDetailText.isEmpty
        if isModelInstallInProgress {
            runtimeActionLabel.stringValue = "Next step: Wait for the model install or cancel it."
            runtimeActionButton.title = "Cancel Install"
            runtimeActionButton.isEnabled = true
            currentRuntimeAction = .cancelModelInstall
        } else {
            runtimeActionLabel.stringValue = runtimeReport.action == .none
                ? "Next step: Model ready."
                : "Next step: \(runtimeReport.action.displayName)"
            runtimeActionButton.title = guidance.actionTitle
            runtimeActionButton.isEnabled = guidance.isActionEnabled
            currentRuntimeAction = runtimeReport.action
        }
        runtimeTargetLabel.stringValue = "Runtime target: \(runtimeTargetSummary)"
        modelDirectoryLabel.stringValue = "Model folder: \(modelDirectoryPath)"
        modelInstallStatusLabel.stringValue = modelInstallStatusText ?? ""
        modelInstallStatusLabel.isHidden = modelInstallStatusText == nil
        practiceLabel.stringValue = practice.statusText
        practiceDetailLabel.stringValue = practice.detailText
        practiceModelLabel.stringValue = practice.modelText
        practiceTextEditLabel.stringValue = practice.textEditText
        practiceStepsLabel.stringValue = practice.stepsText
        currentPracticePrimaryAction = practice.primaryAction
        practicePrimaryButton.title = practice.primaryButtonTitle
        practicePrimaryButton.isEnabled = practice.isPrimaryButtonEnabled
        practicePauseButton.title = practice.pauseButtonTitle
        practiceDeleteTracesButton.title = practice.deleteTracesButtonTitle
        currentAppLabel.stringValue = currentApp.statusText
        currentAppDetailLabel.stringValue = currentApp.detailText
        currentAppSupportLabel.stringValue = currentApp.supportMatrixText
        currentAppModeLabel.stringValue = currentApp.modeText
        currentAppAcceptanceLabel.stringValue = currentApp.acceptanceText
        currentAppFallbackLabel.stringValue = currentApp.fallbackText
        currentAppProofLabel.stringValue = currentApp.proofText
        currentAppProofLabel.isHidden = !currentApp.shouldShowCheckControls
        currentAppProofCommandLabel.stringValue = currentApp.proofCommandText ?? ""
        currentAppProofCommandLabel.isHidden = currentApp.proofCommandText == nil
        currentProofCommandClipboardText = currentApp.proofCommandClipboardText
        copyProofCommandButton.title = currentApp.copyProofCommandButtonTitle
        copyProofCommandButton.isEnabled = currentApp.canCopyProofCommand
        copyProofCommandButton.isHidden = !currentApp.canCopyProofCommand
        toggleCurrentAppButton.title = currentApp.toggleTitle
        toggleCurrentAppButton.state = currentApp.isEnabled ? .on : .off
        toggleCurrentAppButton.isEnabled = currentApp.canToggle
        forceMirrorModeButton.title = currentApp.modeButtonTitle
        forceMirrorModeButton.isEnabled = currentApp.canOverrideMode
        forceMirrorModeButton.isHidden = !currentApp.canOverrideMode
        startAppProofButton.title = currentApp.proofButtonTitle
        startAppProofButton.isEnabled = currentApp.canStartProof
        startAppProofButton.isHidden = !currentApp.shouldShowCheckControls
        disabledAppsLabel.stringValue = currentApp.blockedAppsText
        enableAllAppsButton.isEnabled = currentApp.disabledAppCount > 0
        privacyLabel.stringValue = privacy.statusText
        diagnosticsStatusLabel.stringValue = privacy.diagnosticsStatusText
        rawContentStatusLabel.stringValue = privacy.contentStatusText
        visiblePageContextStatusLabel.stringValue = privacy.visiblePageContextStatusText
        privacySharingStatusLabel.stringValue = privacy.sharingStatusText
        learningStatusLabel.stringValue = privacy.learningStatusText
        let screenRecordingText = privacy.screenRecordingPermissionText
        screenRecordingPermissionLabel.stringValue = screenRecordingText ?? ""
        screenRecordingPermissionLabel.isHidden = screenRecordingText == nil
        privacyPathLabel.stringValue = privacy.pathText
        let feedback = SettingsFeedbackState()
        feedbackLabel.stringValue = feedback.statusText
        feedbackDetailLabel.stringValue = feedback.detailText
        exportPrivacyBundleButton.title = feedback.buttonTitle
        toggleTracingButton.state = privacy.tracingPaused ? .off : .on
        toggleRawTraceButton.state = privacy.rawContentTracingEnabled ? .on : .off
        toggleScreenshotTraceButton.state = privacy.screenshotTracingEnabled ? .on : .off
        toggleVisiblePageContextButton.state = privacy.visiblePageContextEnabled ? .on : .off
        shortcutLabel.stringValue = keyboardShortcuts.statusText
        shortcutConflictLabel.stringValue = keyboardShortcuts.conflictText
        shortcutConflictDetailLabel.stringValue = keyboardShortcuts.conflictDetailText
        shortcutPerAppProfileLabel.stringValue = keyboardShortcuts.perAppProfileText
        acceptAllShortcutLabel.stringValue = keyboardShortcuts.acceptAllPickerLabel
        refreshAcceptAllShortcutPopup(selected: keyboardShortcuts.acceptAllShortcut)
        cycleAcceptAllShortcutButton.title = keyboardShortcuts.cycleButtonTitle
        aggressivenessLabel.stringValue = suggestionAggressiveness.statusText
        aggressivenessDetailLabel.stringValue = suggestionAggressiveness.detailText
        boringGuardrailLabel.stringValue = suggestionAggressiveness.boringGuardrailText
        aggressivenessSlider.doubleValue = suggestionAggressiveness.aggressivenessSliderValue
        maxWordsLabel.stringValue = suggestionAggressiveness.maxWordsText
        maxWordsDetailLabel.stringValue = suggestionAggressiveness.maxWordsDetailText
        maxWordsSlider.doubleValue = suggestionAggressiveness.maxWordsSliderValue
        firstRunLabel.stringValue = SettingsOnboardingState(
            isTrusted: isTrusted,
            suggestionsPaused: suggestionsPaused,
            runtimeGuidance: guidance
        ).text
    }

    func nativeAppearanceSnapshotPNGData(appearanceName: NSAppearance.Name) -> Data? {
        guard let contentView = window.contentView,
              let appearance = NSAppearance(named: appearanceName) else {
            return nil
        }

        let previousAppearance = window.appearance
        window.appearance = appearance
        defer {
            window.appearance = previousAppearance
        }

        contentView.needsLayout = true
        contentView.layoutSubtreeIfNeeded()
        let bounds = contentView.bounds
        guard !bounds.isEmpty,
              let bitmap = contentView.bitmapImageRepForCachingDisplay(in: bounds) else {
            return nil
        }

        contentView.cacheDisplay(in: bounds, to: bitmap)
        return bitmap.representation(using: .png, properties: [:])
    }

    private func buildContent(in contentView: NSView) {
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.drawsBackground = false
        contentScrollView.borderType = .noBorder
        contentScrollView.hasVerticalScroller = true
        contentScrollView.hasHorizontalScroller = false
        contentScrollView.autohidesScrollers = true
        contentScrollView.verticalScrollElasticity = .allowed
        contentScrollView.horizontalScrollElasticity = .none

        scrollDocumentView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.documentView = scrollDocumentView

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = layoutStyle.sectionSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "SteadyType")
        title.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        firstRunTrustLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(firstRunTrustDetailLabel)
        configureSecondaryLabel(firstRunTrustQuickStartLabel)
        configureSecondaryLabel(firstRunTrustAppsLabel)
        permissionLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(permissionDetailLabel)
        runtimeLabel.lineBreakMode = .byWordWrapping
        runtimeLabel.maximumNumberOfLines = 0
        runtimeLabel.preferredMaxLayoutWidth = 470
        runtimeDetailLabel.font = NSFont.systemFont(ofSize: 12)
        configureSecondaryLabel(runtimeDetailLabel)
        runtimeActionLabel.font = NSFont.systemFont(ofSize: 12)
        runtimeActionLabel.textColor = .secondaryLabelColor
        configureSecondaryLabel(runtimeTargetLabel)
        modelDirectoryLabel.lineBreakMode = .byTruncatingMiddle
        modelDirectoryLabel.maximumNumberOfLines = 1
        modelDirectoryLabel.preferredMaxLayoutWidth = 470
        configureSecondaryLabel(modelInstallStatusLabel)
        practiceLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(practiceDetailLabel)
        configureSecondaryLabel(practiceModelLabel)
        configureSecondaryLabel(practiceTextEditLabel)
        configureSecondaryLabel(practiceStepsLabel)
        controlLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        fieldControlLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(fieldControlDetailLabel)
        firstRunLabel.font = NSFont.systemFont(ofSize: 12)
        configureSecondaryLabel(firstRunLabel)
        currentAppLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(currentAppDetailLabel)
        configureSecondaryLabel(currentAppSupportLabel)
        configureSecondaryLabel(currentAppModeLabel)
        configureSecondaryLabel(currentAppAcceptanceLabel)
        configureSecondaryLabel(currentAppFallbackLabel)
        configureSecondaryLabel(currentAppProofLabel)
        configureSecondaryLabel(currentAppProofCommandLabel)
        configureSecondaryLabel(disabledAppsLabel)
        configureSecondaryLabel(suggestionDecisionLabel)
        configureSecondaryLabel(suggestionDecisionDetailLabel)
        privacyLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(controlDetailLabel)
        configureSecondaryLabel(diagnosticsStatusLabel)
        configureSecondaryLabel(rawContentStatusLabel)
        configureSecondaryLabel(visiblePageContextStatusLabel)
        configureSecondaryLabel(privacySharingStatusLabel)
        configureSecondaryLabel(learningStatusLabel)
        configureSecondaryLabel(screenRecordingPermissionLabel)
        privacyPathLabel.font = NSFont.systemFont(ofSize: 11)
        privacyPathLabel.textColor = .secondaryLabelColor
        privacyPathLabel.lineBreakMode = .byTruncatingMiddle
        privacyPathLabel.maximumNumberOfLines = 1
        privacyPathLabel.preferredMaxLayoutWidth = 470
        feedbackLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(feedbackDetailLabel)
        shortcutLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(shortcutConflictLabel)
        configureSecondaryLabel(shortcutConflictDetailLabel)
        configureSecondaryLabel(shortcutPerAppProfileLabel)
        acceptAllShortcutLabel.font = NSFont.systemFont(ofSize: 12)
        acceptAllShortcutLabel.textColor = .secondaryLabelColor
        aggressivenessLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(aggressivenessDetailLabel)
        configureSecondaryLabel(boringGuardrailLabel)
        maxWordsLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(maxWordsDetailLabel)

        let requestButton = NSButton(title: "Allow Accessibility", target: self, action: #selector(requestAccessibility))
        requestButton.bezelStyle = .rounded
        let openSettingsButton = NSButton(
            title: "Open Privacy Settings",
            target: self,
            action: #selector(openAccessibilitySettingsPane)
        )
        openSettingsButton.bezelStyle = .rounded
        togglePauseButton.target = self
        togglePauseButton.action = #selector(togglePause)
        togglePauseButton.toolTip = "Turns suggestions on or off immediately."
        pause15MinutesButton.target = self
        pause15MinutesButton.action = #selector(pauseFor15MinutesControl)
        pause15MinutesButton.bezelStyle = .rounded
        pause1HourButton.target = self
        pause1HourButton.action = #selector(pauseFor1HourControl)
        pause1HourButton.bezelStyle = .rounded
        pauseUntilTomorrowButton.target = self
        pauseUntilTomorrowButton.action = #selector(pauseUntilTomorrowControl)
        pauseUntilTomorrowButton.bezelStyle = .rounded
        pauseUntilTomorrowButton.toolTip = "Pauses suggestions everywhere until tomorrow."
        silenceFieldButton.target = self
        silenceFieldButton.action = #selector(silenceFieldControl)
        silenceFieldButton.bezelStyle = .rounded
        silenceFieldButton.toolTip = "Stops suggestions only in the current field until focus changes."
        runtimeActionButton.target = self
        runtimeActionButton.action = #selector(runRuntimeAction)
        runtimeActionButton.bezelStyle = .rounded
        practicePrimaryButton.target = self
        practicePrimaryButton.action = #selector(runPracticePrimaryAction)
        practicePrimaryButton.bezelStyle = .rounded
        practicePauseButton.target = self
        practicePauseButton.action = #selector(runPracticePauseAction)
        practicePauseButton.bezelStyle = .rounded
        practiceDeleteTracesButton.target = self
        practiceDeleteTracesButton.action = #selector(runPracticeDeleteTracesAction)
        practiceDeleteTracesButton.bezelStyle = .rounded
        toggleCurrentAppButton.target = self
        toggleCurrentAppButton.action = #selector(toggleCurrentAppControl)
        toggleCurrentAppButton.toolTip = "Adds or removes the current app from your blocked-app list."
        forceMirrorModeButton.target = self
        forceMirrorModeButton.action = #selector(toggleCurrentAppMirrorModeControl)
        forceMirrorModeButton.bezelStyle = .rounded
        forceMirrorModeButton.toolTip = "Uses the floating backup for this app, or returns to its default placement."
        startAppProofButton.target = self
        startAppProofButton.action = #selector(startAppProofControl)
        startAppProofButton.bezelStyle = .rounded
        startAppProofButton.toolTip = "Starts a local app check and opens Diagnostics."
        copyProofCommandButton.target = self
        copyProofCommandButton.action = #selector(copyProofCommandControl)
        copyProofCommandButton.bezelStyle = .rounded
        copyProofCommandButton.toolTip = "Copies the local check command for the current app."
        enableAllAppsButton.target = self
        enableAllAppsButton.action = #selector(enableAllAppsControl)
        enableAllAppsButton.bezelStyle = .rounded
        enableAllAppsButton.toolTip = "Resumes every app you paused in SteadyType."
        toggleTracingButton.target = self
        toggleTracingButton.action = #selector(toggleTracingControl)
        toggleTracingButton.toolTip = "Pauses diagnostics recording only. Suggestions use the Suggestion controls."
        toggleRawTraceButton.target = self
        toggleRawTraceButton.action = #selector(toggleRawTraceControl)
        toggleRawTraceButton.toolTip = "Off by default. Turn on only when support asks for local raw-text logs."
        toggleScreenshotTraceButton.target = self
        toggleScreenshotTraceButton.action = #selector(toggleScreenshotTraceControl)
        toggleScreenshotTraceButton.toolTip = "Saves local screenshots for placement checks."
        toggleVisiblePageContextButton.target = self
        toggleVisiblePageContextButton.action = #selector(toggleVisiblePageContextControl)
        toggleVisiblePageContextButton.toolTip = "Uses local OCR around the active editor as extra suggestion context."
        deleteLocalLogsButton.target = self
        deleteLocalLogsButton.action = #selector(deleteLocalLogsControl)
        deleteLocalLogsButton.bezelStyle = .rounded
        clearLearningDataButton.target = self
        clearLearningDataButton.action = #selector(clearLearningDataControl)
        clearLearningDataButton.bezelStyle = .rounded
        exportPrivacyBundleButton.target = self
        exportPrivacyBundleButton.action = #selector(exportPrivacyBundleControl)
        exportPrivacyBundleButton.bezelStyle = .rounded
        cycleAcceptAllShortcutButton.target = self
        cycleAcceptAllShortcutButton.action = #selector(cycleAcceptAllShortcutControl)
        cycleAcceptAllShortcutButton.bezelStyle = .rounded
        acceptAllShortcutPopup.target = self
        acceptAllShortcutPopup.action = #selector(selectAcceptAllShortcutControl)
        configureSlider(
            aggressivenessSlider,
            minimumValue: SuggestionTuning.minimumAggressivenessLevel,
            maximumValue: SuggestionTuning.maximumAggressivenessLevel,
            action: #selector(changeAggressivenessSlider)
        )
        aggressivenessSlider.toolTip = "Adjusts how quickly and how often suggestions appear."
        configureSlider(
            maxWordsSlider,
            minimumValue: CompletionModelPolicy.minimumVisibleWords,
            maximumValue: CompletionModelPolicy.maximumVisibleWords,
            action: #selector(changeMaxWordsSlider)
        )
        maxWordsSlider.toolTip = "Adjusts the maximum number of visible predicted words."

        [
            title,
            makeSection(
                title: "First Run",
                views: [
                    firstRunTrustLabel,
                    firstRunTrustDetailLabel,
                    firstRunTrustQuickStartLabel,
                    firstRunTrustAppsLabel
                ]
            ),
            makeSection(
                title: "Access",
                views: [
                    permissionLabel,
                    permissionDetailLabel,
                    makeButtonRow([requestButton, openSettingsButton])
                ]
            ),
            makeSection(
                title: "Local Model",
                views: [
                    runtimeLabel,
                    runtimeDetailLabel,
                    runtimeActionLabel,
                    makeButtonRow([runtimeActionButton]),
                    modelInstallStatusLabel,
                    runtimeTargetLabel,
                    modelDirectoryLabel
                ]
            ),
            makeSection(
                title: "Practice",
                views: [
                    practiceLabel,
                    practiceDetailLabel,
                    practiceModelLabel,
                    practiceTextEditLabel,
                    practiceStepsLabel,
                    makeButtonRow([practicePrimaryButton, practicePauseButton, practiceDeleteTracesButton])
                ]
            ),
            makeSection(
                title: "Suggestions",
                views: [
                    controlLabel,
                    controlDetailLabel,
                    togglePauseButton,
                    makeButtonRow([pause15MinutesButton, pause1HourButton, pauseUntilTomorrowButton]),
                    fieldControlLabel,
                    fieldControlDetailLabel,
                    makeButtonRow([silenceFieldButton]),
                    suggestionDecisionLabel,
                    suggestionDecisionDetailLabel,
                    firstRunLabel
                ]
            ),
            makeSection(
                title: "Apps",
                views: [
                    currentAppLabel,
                    currentAppDetailLabel,
                    currentAppSupportLabel,
                    currentAppModeLabel,
                    currentAppAcceptanceLabel,
                    currentAppFallbackLabel,
                    currentAppProofLabel,
                    currentAppProofCommandLabel,
                    makeButtonRow([forceMirrorModeButton, startAppProofButton, copyProofCommandButton]),
                    toggleCurrentAppButton,
                    makeButtonRow([disabledAppsLabel, enableAllAppsButton])
                ]
            ),
            makeSection(
                title: "Privacy and Diagnostics",
                views: [
                    privacyLabel,
                    diagnosticsStatusLabel,
                    rawContentStatusLabel,
                    visiblePageContextStatusLabel,
                    privacySharingStatusLabel,
                    screenRecordingPermissionLabel,
                    toggleTracingButton,
                    toggleRawTraceButton,
                    toggleScreenshotTraceButton,
                    toggleVisiblePageContextButton,
                    learningStatusLabel,
                    privacyPathLabel,
                    feedbackLabel,
                    feedbackDetailLabel,
                    makeButtonRow([exportPrivacyBundleButton, deleteLocalLogsButton, clearLearningDataButton])
                ]
            ),
            makeSection(
                title: "Keyboard",
                views: [
                    shortcutLabel,
                    shortcutConflictLabel,
                    shortcutConflictDetailLabel,
                    shortcutPerAppProfileLabel,
                    makeButtonRow([acceptAllShortcutLabel, acceptAllShortcutPopup, cycleAcceptAllShortcutButton])
                ]
            ),
            makeSection(
                title: "Tuning",
                views: [
                    aggressivenessLabel,
                    aggressivenessDetailLabel,
                    boringGuardrailLabel,
                    aggressivenessSlider,
                    maxWordsLabel,
                    maxWordsDetailLabel,
                    maxWordsSlider
                ]
            )
        ].forEach {
            stack.addArrangedSubview($0)
        }

        contentView.addSubview(contentScrollView)
        scrollDocumentView.addSubview(stack)

        NSLayoutConstraint.activate([
            contentScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentScrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            contentScrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            scrollDocumentView.leadingAnchor.constraint(equalTo: contentScrollView.contentView.leadingAnchor),
            scrollDocumentView.trailingAnchor.constraint(equalTo: contentScrollView.contentView.trailingAnchor),
            scrollDocumentView.topAnchor.constraint(equalTo: contentScrollView.contentView.topAnchor),
            scrollDocumentView.widthAnchor.constraint(equalTo: contentScrollView.contentView.widthAnchor),
            scrollDocumentView.heightAnchor.constraint(greaterThanOrEqualTo: contentScrollView.contentView.heightAnchor),

            stack.leadingAnchor.constraint(equalTo: scrollDocumentView.leadingAnchor, constant: layoutStyle.contentInsets.left),
            stack.trailingAnchor.constraint(equalTo: scrollDocumentView.trailingAnchor, constant: -layoutStyle.contentInsets.right),
            stack.topAnchor.constraint(equalTo: scrollDocumentView.topAnchor, constant: layoutStyle.contentInsets.top),
            stack.bottomAnchor.constraint(equalTo: scrollDocumentView.bottomAnchor, constant: -layoutStyle.contentInsets.bottom)
        ])
    }

    private func fitWindowInsideVisibleScreen() {
        guard let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame else {
            window.center()
            return
        }

        let desiredFrame = window.frameRect(forContentRect: NSRect(
            origin: .zero,
            size: layoutStyle.preferredContentSize
        ))
        let maxFrameWidth = max(window.minSize.width, visibleFrame.width - layoutStyle.visibleScreenInset)
        let maxFrameHeight = max(window.minSize.height, visibleFrame.height - layoutStyle.visibleScreenInset)
        let targetSize = NSSize(
            width: min(desiredFrame.width, maxFrameWidth),
            height: min(desiredFrame.height, maxFrameHeight)
        )
        let targetOrigin = NSPoint(
            x: visibleFrame.midX - (targetSize.width / 2),
            y: visibleFrame.midY - (targetSize.height / 2)
        )

        window.setFrame(NSRect(origin: targetOrigin, size: targetSize), display: false)
    }

    private func configureSecondaryLabel(
        _ label: NSTextField,
        maxWidth: CGFloat = SettingsLayoutStyle.nativeUtility.secondaryLabelMaxWidth
    ) {
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.preferredMaxLayoutWidth = maxWidth
    }

    private func makeSection(title: String, views: [NSView]) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor

        var arrangedSubviews: [NSView] = [titleLabel]
        arrangedSubviews.append(contentsOf: views)

        let section = NSStackView(views: arrangedSubviews)
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = layoutStyle.sectionItemSpacing
        return section
    }

    private func makeButtonRow(_ views: [NSView]) -> NSStackView {
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    private func configureSlider(
        _ slider: NSSlider,
        minimumValue: Int,
        maximumValue: Int,
        action: Selector
    ) {
        slider.minValue = Double(minimumValue)
        slider.maxValue = Double(maximumValue)
        slider.numberOfTickMarks = maximumValue - minimumValue + 1
        slider.allowsTickMarkValuesOnly = true
        slider.isContinuous = true
        slider.target = self
        slider.action = action
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 260).isActive = true
    }

    private func refreshAcceptAllShortcutPopup(selected: AcceptAllShortcut) {
        acceptAllShortcutPopup.removeAllItems()
        for shortcut in AcceptAllShortcut.allCases {
            acceptAllShortcutPopup.addItem(withTitle: shortcut.displayName)
            acceptAllShortcutPopup.lastItem?.representedObject = shortcut.rawValue
        }
        acceptAllShortcutPopup.selectItem(withTitle: selected.displayName)
    }

    @objc
    private func requestAccessibility() {
        requestPermission()
    }

    @objc
    private func openAccessibilitySettingsPane() {
        openAccessibilitySettings()
    }

    @objc
    private func togglePause() {
        toggleSuggestionsPaused()
    }

    @objc
    private func pauseFor15MinutesControl() {
        pauseSuggestionsFor15Minutes()
    }

    @objc
    private func pauseFor1HourControl() {
        pauseSuggestionsFor1Hour()
    }

    @objc
    private func pauseUntilTomorrowControl() {
        pauseSuggestionsUntilTomorrow()
    }

    @objc
    private func silenceFieldControl() {
        silenceCurrentField()
    }

    @objc
    private func runRuntimeAction() {
        performRuntimeAction(currentRuntimeAction)
    }

    @objc
    private func runPracticePrimaryAction() {
        performPracticePrimaryAction()
    }

    func performPracticePrimaryAction() {
        switch currentPracticePrimaryAction {
        case .requestAccessibility:
            requestPermission()
        case let .performRuntimeAction(action):
            performRuntimeAction(action)
        case .openTextEditPractice:
            startTextEditPractice()
        case .none:
            break
        }
    }

    @objc
    private func runPracticePauseAction() {
        performPracticePauseAction()
    }

    func performPracticePauseAction() {
        toggleSuggestionsPaused()
    }

    @objc
    private func runPracticeDeleteTracesAction() {
        performPracticeDeleteTracesAction()
    }

    func performPracticeDeleteTracesAction() {
        deleteLocalLogs()
    }

    @objc
    private func toggleCurrentAppControl() {
        toggleCurrentApp()
    }

    @objc
    private func toggleCurrentAppMirrorModeControl() {
        toggleCurrentAppMirrorMode()
    }

    @objc
    private func startAppProofControl() {
        performStartAppProofAction()
    }

    func performStartAppProofAction() {
        startCurrentAppProof()
    }

    func copyCurrentProofCommand(to pasteboard: NSPasteboard = .general) {
        guard let currentProofCommandClipboardText else {
            return
        }

        pasteboard.clearContents()
        pasteboard.setString(currentProofCommandClipboardText, forType: .string)
    }

    @objc
    private func copyProofCommandControl() {
        copyCurrentProofCommand()
    }

    @objc
    private func enableAllAppsControl() {
        enableAllApps()
    }

    @objc
    private func toggleTracingControl() {
        toggleTracingPaused()
    }

    @objc
    private func toggleRawTraceControl() {
        toggleRawContentTracing()
    }

    @objc
    private func toggleScreenshotTraceControl() {
        toggleScreenshotTracing()
    }

    @objc
    private func toggleVisiblePageContextControl() {
        toggleVisiblePageContext()
    }

    @objc
    private func deleteLocalLogsControl() {
        deleteLocalLogs()
    }

    @objc
    private func clearLearningDataControl() {
        clearLearningData()
    }

    @objc
    private func exportPrivacyBundleControl() {
        exportPrivacyBundle()
    }

    @objc
    private func cycleAcceptAllShortcutControl() {
        cycleAcceptAllShortcut()
    }

    @objc
    private func selectAcceptAllShortcutControl() {
        guard let rawValue = acceptAllShortcutPopup.selectedItem?.representedObject as? String,
              let shortcut = AcceptAllShortcut(rawValue: rawValue) else {
            return
        }

        setAcceptAllShortcut(shortcut)
    }

    @objc
    private func changeAggressivenessSlider() {
        setSuggestionAggressivenessLevel(aggressivenessSlider.integerValue)
    }

    @objc
    private func changeMaxWordsSlider() {
        setSuggestionMaxVisibleWords(maxWordsSlider.integerValue)
    }
}
