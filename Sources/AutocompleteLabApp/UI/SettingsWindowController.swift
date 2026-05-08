import AppKit
import AutocompleteLabCore

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

        return "\(supportStatus.userFacingReason) Suggestions are off for this app. Turn them on only where you want to test."
    }

    var modeText: String {
        guard bundleIdentifier != nil else {
            return "Mode: choose a writing app"
        }

        guard case let .supported(profile) = supportStatus else {
            return "Mode: not tested yet"
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
            return "Acceptance: Tab next word + full accept"
        case (true, false):
            return "Acceptance: Tab next word only; full accept is off for safety"
        case (false, true):
            return "Acceptance: full accept only"
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
        canToggle ? "Allow suggestions in this app" : "Suggestions unavailable in this app"
    }

    var menuToggleTitle: String {
        guard bundleIdentifier != nil else {
            return "Toggle Current App"
        }

        guard canToggle else {
            return "Suggestions unavailable in \(displayName)"
        }

        return isEnabled ? "Disable \(displayName)" : "Enable \(displayName)"
    }

    var modeButtonTitle: String {
        renderModeOverride == .floatingMirror ? "Use Profile Mode" : "Force Mirror Mode"
    }

    var proofButtonTitle: String {
        if bundleIdentifier == "com.apple.TextEdit", isEnabled {
            return "Run TextEdit Proof"
        }

        return isEnabled ? "Start App Proof" : "Enable App First"
    }

    var copyProofCommandButtonTitle: String {
        canCopyProofCommand ? "Copy Proof Command" : "No Proof Command"
    }

    var canCopyProofCommand: Bool {
        proofCommandClipboardText != nil
    }

    var proofText: String {
        guard bundleIdentifier != nil else {
            return "Proof: choose a writing app first."
        }

        guard case let .supported(profile) = supportStatus,
              profile.canPresentSuggestions,
              !profile.isSensitive else {
            return "Proof: unavailable here."
        }

        guard isEnabled else {
            return "Proof: turn on suggestions for this app first."
        }

        if bundleIdentifier == "com.openai.codex" {
            return "Proof: include AUTOCOMPLETE_LAB_CODEX_PROOF, press Tab once, and do not press Enter."
        }

        if profile.supportsOneWordAcceptance && !profile.supportsFullAcceptance {
            return "Proof: use disposable prompt text, press Tab once, and do not press Enter."
        }

        if profile.supportsOneWordAcceptance && profile.supportsFullAcceptance {
            return "Proof: use disposable text, press Tab once, then the full-accept shortcut."
        }

        return "Proof: use disposable text and verify accepted text stays in the field."
    }

    var proofCommandText: String? {
        guard let command = proofCommandClipboardText else {
            return nil
        }

        if bundleIdentifier == "com.apple.Notes" {
            return "Manual commands: \(command.replacingOccurrences(of: "\n", with: "; "))"
        }

        if supportStatus.supportLevel == .yellow {
            return "Manual command: \(command)"
        }

        return "Command: \(command)"
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
            return "Blocked apps: none"
        }

        return "Blocked apps: \(disabledAppCount)"
    }

    private static func renderModeName(_ mode: SuggestionRenderMode) -> String {
        switch mode {
        case .inlineAdjacent:
            return "inline"
        case .floatingMirror:
            return "mirror"
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
            return "Autocomplete Lab can read the active text field and insert accepted suggestions. Text stays on this Mac."
        }

        return "Allow Accessibility so Autocomplete Lab can read the active text field, find the cursor, and insert accepted suggestions. Text stays on this Mac."
    }
}

struct SettingsPrivacyState: Equatable {
    let tracingPaused: Bool
    let rawContentTracingEnabled: Bool
    let rawContentTracingExpiresAt: Date?
    let screenshotTracingEnabled: Bool
    let screenshotTracingExpiresAt: Date?
    let diagnosticsPath: String
    let tracePath: String

    var statusText: String {
        "Privacy: local diagnostics only"
    }

    var diagnosticsStatusText: String {
        let traceState = tracingPaused ? "paused" : "recording"
        let screenshotState = screenshotTracingEnabled
            ? (screenshotTracingExpiresAt == nil ? "screenshots on" : "screenshots on temporarily")
            : "screenshots off"
        return "Diagnostics: performance + placement traces \(traceState), \(screenshotState)"
    }

    var contentStatusText: String {
        let state = rawContentTracingEnabled
            ? (rawContentTracingExpiresAt == nil ? "on" : "on temporarily")
            : "off"
        return "Raw text capture: \(state)"
    }

    var sharingStatusText: String {
        if rawContentTracingEnabled || screenshotTracingEnabled {
            return "Sharing: use Export Privacy Bundle; do not share debug traces or screenshots."
        }

        return "Sharing: Export Privacy Bundle excludes raw text, prompts, accepted text, and screenshots."
    }

    var learningStatusText: String {
        "Learning: accepted-kept scores, style sketch, and recent words stay local"
    }

    var screenRecordingPermissionText: String? {
        guard screenshotTracingEnabled else {
            return nil
        }

        if screenshotTracingExpiresAt == nil {
            return "Screen Recording: only used for placement screenshots while this debug switch is on."
        }

        return "Screen Recording: only used for temporary placement screenshots."
    }

    var pathText: String {
        "Logs: \(diagnosticsPath) | Traces: \(tracePath)"
    }
}

struct SettingsKeyboardShortcutState: Equatable {
    let acceptAllShortcut: AcceptAllShortcut

    var statusText: String {
        "Shortcuts: Tab next word | \(acceptAllShortcut.displayName) all"
    }

    var cycleButtonTitle: String {
        "Use \(acceptAllShortcut.next.displayName)"
    }

    var acceptAllPickerLabel: String {
        "Accept all:"
    }
}

struct SettingsSuggestionAggressivenessState: Equatable {
    let aggressiveness: SuggestionAggressiveness

    var statusText: String {
        "Aggressiveness: \(aggressiveness.displayName)"
    }

    var detailText: String {
        switch aggressiveness {
        case .quiet:
            return "Waits longer and needs stronger scores before showing."
        case .normal:
            return "Uses the current balanced timing and score gates."
        case .eager:
            return "Shows sooner when safe, while keeping sensitive-field and high-risk blocks."
        }
    }

    var cycleButtonTitle: String {
        "Use \(aggressiveness.next.displayName)"
    }
}

struct SettingsOnboardingState: Equatable {
    let isTrusted: Bool
    let suggestionsPaused: Bool
    let runtimeGuidance: RuntimeReadinessGuidance

    var text: String {
        if !isTrusted {
            return "Allow Accessibility so the app can read the active text field, find the cursor, and insert only what you accept. Text stays on this Mac."
        }

        if suggestionsPaused {
            return "Paused. Resume when you want to test suggestions."
        }

        return runtimeGuidance.message
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
    private let permissionLabel = NSTextField(labelWithString: "")
    private let permissionDetailLabel = NSTextField(labelWithString: "")
    private let runtimeLabel = NSTextField(labelWithString: "")
    private let runtimeDetailLabel = NSTextField(labelWithString: "")
    private let runtimeActionLabel = NSTextField(labelWithString: "")
    private let runtimeTargetLabel = NSTextField(labelWithString: "")
    private let modelDirectoryLabel = NSTextField(labelWithString: "")
    private let modelInstallStatusLabel = NSTextField(labelWithString: "")
    private let controlLabel = NSTextField(labelWithString: "")
    private let togglePauseButton = NSButton(checkboxWithTitle: "Suggestions", target: nil, action: nil)
    private let fieldControlLabel = NSTextField(labelWithString: "")
    private let fieldControlDetailLabel = NSTextField(labelWithString: "")
    private let silenceFieldButton = NSButton(title: "Silence This Field", target: nil, action: nil)
    private let runtimeActionButton = NSButton(title: "Open Model Folder", target: nil, action: nil)
    private let currentAppLabel = NSTextField(labelWithString: "")
    private let currentAppDetailLabel = NSTextField(labelWithString: "")
    private let currentAppModeLabel = NSTextField(labelWithString: "")
    private let currentAppAcceptanceLabel = NSTextField(labelWithString: "")
    private let currentAppFallbackLabel = NSTextField(labelWithString: "")
    private let currentAppProofLabel = NSTextField(labelWithString: "")
    private let currentAppProofCommandLabel = NSTextField(labelWithString: "")
    private let disabledAppsLabel = NSTextField(labelWithString: "")
    private let suggestionDecisionLabel = NSTextField(labelWithString: "")
    private let toggleCurrentAppButton = NSButton(
        checkboxWithTitle: "Allow suggestions in this app",
        target: nil,
        action: nil
    )
    private let forceMirrorModeButton = NSButton(title: "Force Mirror Mode", target: nil, action: nil)
    private let startAppProofButton = NSButton(title: "Start App Proof", target: nil, action: nil)
    private let copyProofCommandButton = NSButton(title: "Copy Proof Command", target: nil, action: nil)
    private let enableAllAppsButton = NSButton(title: "Clear Blocked Apps", target: nil, action: nil)
    private let privacyLabel = NSTextField(labelWithString: "")
    private let diagnosticsStatusLabel = NSTextField(labelWithString: "")
    private let rawContentStatusLabel = NSTextField(labelWithString: "")
    private let privacySharingStatusLabel = NSTextField(labelWithString: "")
    private let learningStatusLabel = NSTextField(labelWithString: "")
    private let screenRecordingPermissionLabel = NSTextField(labelWithString: "")
    private let privacyPathLabel = NSTextField(labelWithString: "")
    private let toggleTracingButton = NSButton(
        checkboxWithTitle: "Performance and placement traces",
        target: nil,
        action: nil
    )
    private let toggleRawTraceButton = NSButton(
        checkboxWithTitle: "Include raw text in traces",
        target: nil,
        action: nil
    )
    private let toggleScreenshotTraceButton = NSButton(
        checkboxWithTitle: "Capture placement screenshots",
        target: nil,
        action: nil
    )
    private let deleteLocalLogsButton = NSButton(title: "Delete Local Logs", target: nil, action: nil)
    private let clearLearningDataButton = NSButton(title: "Clear Learned Suggestions", target: nil, action: nil)
    private let shortcutLabel = NSTextField(labelWithString: "")
    private let acceptAllShortcutLabel = NSTextField(labelWithString: "Accept all:")
    private let acceptAllShortcutPopup = NSPopUpButton()
    private let cycleAcceptAllShortcutButton = NSButton(title: "Use Option-Tab", target: nil, action: nil)
    private let aggressivenessLabel = NSTextField(labelWithString: "")
    private let aggressivenessDetailLabel = NSTextField(labelWithString: "")
    private let cycleAggressivenessButton = NSButton(title: "Use Eager", target: nil, action: nil)
    private let firstRunLabel = NSTextField(wrappingLabelWithString: "")
    private let requestPermission: () -> Void
    private let openAccessibilitySettings: () -> Void
    private let toggleSuggestionsPaused: () -> Void
    private let silenceCurrentField: () -> Void
    private let performRuntimeAction: (RuntimeReadinessAction) -> Void
    private let toggleCurrentApp: () -> Void
    private let toggleCurrentAppMirrorMode: () -> Void
    private let startCurrentAppProof: () -> Void
    private let enableAllApps: () -> Void
    private let toggleTracingPaused: () -> Void
    private let toggleRawContentTracing: () -> Void
    private let toggleScreenshotTracing: () -> Void
    private let deleteLocalLogs: () -> Void
    private let clearLearningData: () -> Void
    private let cycleAcceptAllShortcut: () -> Void
    private let setAcceptAllShortcut: (AcceptAllShortcut) -> Void
    private let cycleSuggestionAggressiveness: () -> Void
    private var currentRuntimeAction: RuntimeReadinessAction = .none
    private var currentProofCommandClipboardText: String?

    init(
        requestPermission: @escaping () -> Void,
        openAccessibilitySettings: @escaping () -> Void,
        toggleSuggestionsPaused: @escaping () -> Void,
        silenceCurrentField: @escaping () -> Void,
        performRuntimeAction: @escaping (RuntimeReadinessAction) -> Void,
        toggleCurrentApp: @escaping () -> Void,
        toggleCurrentAppMirrorMode: @escaping () -> Void,
        startCurrentAppProof: @escaping () -> Void,
        enableAllApps: @escaping () -> Void,
        toggleTracingPaused: @escaping () -> Void,
        toggleRawContentTracing: @escaping () -> Void,
        toggleScreenshotTracing: @escaping () -> Void,
        deleteLocalLogs: @escaping () -> Void,
        clearLearningData: @escaping () -> Void,
        cycleAcceptAllShortcut: @escaping () -> Void,
        setAcceptAllShortcut: @escaping (AcceptAllShortcut) -> Void,
        cycleSuggestionAggressiveness: @escaping () -> Void
    ) {
        self.requestPermission = requestPermission
        self.openAccessibilitySettings = openAccessibilitySettings
        self.toggleSuggestionsPaused = toggleSuggestionsPaused
        self.silenceCurrentField = silenceCurrentField
        self.performRuntimeAction = performRuntimeAction
        self.toggleCurrentApp = toggleCurrentApp
        self.toggleCurrentAppMirrorMode = toggleCurrentAppMirrorMode
        self.startCurrentAppProof = startCurrentAppProof
        self.enableAllApps = enableAllApps
        self.toggleTracingPaused = toggleTracingPaused
        self.toggleRawContentTracing = toggleRawContentTracing
        self.toggleScreenshotTracing = toggleScreenshotTracing
        self.deleteLocalLogs = deleteLocalLogs
        self.clearLearningData = clearLearningData
        self.cycleAcceptAllShortcut = cycleAcceptAllShortcut
        self.setAcceptAllShortcut = setAcceptAllShortcut
        self.cycleSuggestionAggressiveness = cycleSuggestionAggressiveness

        let contentView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 560, height: 780))
        contentView.material = .contentBackground
        contentView.blendingMode = .behindWindow
        contentView.state = .active
        window = NSWindow(
            contentRect: contentView.frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Autocomplete Lab"
        window.contentView = contentView
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 540, height: 720)
        window.isMovableByWindowBackground = true

        super.init()

        buildContent(in: contentView)
    }

    func show(
        isTrusted: Bool,
        suggestionsPaused: Bool,
        runtimeReport: RuntimeReadinessReport,
        runtimeTargetSummary: String,
        modelDirectoryPath: String,
        modelInstallStatusText: String?,
        isModelInstallInProgress: Bool,
        currentApp: SettingsCurrentAppState,
        fieldControl: SettingsFieldControlState,
        privacy: SettingsPrivacyState,
        keyboardShortcuts: SettingsKeyboardShortcutState,
        suggestionAggressiveness: SettingsSuggestionAggressivenessState,
        lastSuggestionDecision: String
    ) {
        refresh(
            isTrusted: isTrusted,
            suggestionsPaused: suggestionsPaused,
            runtimeReport: runtimeReport,
            runtimeTargetSummary: runtimeTargetSummary,
            modelDirectoryPath: modelDirectoryPath,
            modelInstallStatusText: modelInstallStatusText,
            isModelInstallInProgress: isModelInstallInProgress,
            currentApp: currentApp,
            fieldControl: fieldControl,
            privacy: privacy,
            keyboardShortcuts: keyboardShortcuts,
            suggestionAggressiveness: suggestionAggressiveness,
            lastSuggestionDecision: lastSuggestionDecision
        )
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    var isShowing: Bool {
        window.isVisible
    }

    func refresh(
        isTrusted: Bool,
        suggestionsPaused: Bool,
        runtimeReport: RuntimeReadinessReport,
        runtimeTargetSummary: String,
        modelDirectoryPath: String,
        modelInstallStatusText: String?,
        isModelInstallInProgress: Bool,
        currentApp: SettingsCurrentAppState,
        fieldControl: SettingsFieldControlState,
        privacy: SettingsPrivacyState,
        keyboardShortcuts: SettingsKeyboardShortcutState,
        suggestionAggressiveness: SettingsSuggestionAggressivenessState,
        lastSuggestionDecision: String
    ) {
        let guidance = RuntimeReadinessGuidance(report: runtimeReport)
        let permission = SettingsPermissionState(isTrusted: isTrusted)
        permissionLabel.stringValue = permission.statusText
        permissionDetailLabel.stringValue = permission.detailText
        controlLabel.stringValue = suggestionsPaused ? "Suggestions: paused" : "Suggestions: ready"
        suggestionDecisionLabel.stringValue = "Why: \(lastSuggestionDecision)"
        togglePauseButton.state = suggestionsPaused ? .off : .on
        fieldControlLabel.stringValue = fieldControl.statusText
        fieldControlDetailLabel.stringValue = fieldControl.detailText
        silenceFieldButton.title = fieldControl.buttonTitle
        silenceFieldButton.isEnabled = fieldControl.canSilence
        runtimeLabel.stringValue = "Local model: \(runtimeReport.summary)"
        runtimeDetailLabel.stringValue = runtimeReport.detail ?? ""
        runtimeDetailLabel.isHidden = runtimeReport.detail == nil
        if isModelInstallInProgress {
            runtimeActionLabel.stringValue = "Next step: Wait for the model install or cancel it."
            runtimeActionButton.title = "Cancel Install"
            runtimeActionButton.isEnabled = true
            currentRuntimeAction = .cancelModelInstall
        } else {
            runtimeActionLabel.stringValue = "Next step: \(runtimeReport.action.displayName)"
            runtimeActionButton.title = guidance.actionTitle
            runtimeActionButton.isEnabled = guidance.isActionEnabled
            currentRuntimeAction = runtimeReport.action
        }
        runtimeTargetLabel.stringValue = "Runtime target: \(runtimeTargetSummary)"
        modelDirectoryLabel.stringValue = "Model folder: \(modelDirectoryPath)"
        modelInstallStatusLabel.stringValue = modelInstallStatusText ?? ""
        modelInstallStatusLabel.isHidden = modelInstallStatusText == nil
        currentAppLabel.stringValue = currentApp.statusText
        currentAppDetailLabel.stringValue = currentApp.detailText
        currentAppModeLabel.stringValue = currentApp.modeText
        currentAppAcceptanceLabel.stringValue = currentApp.acceptanceText
        currentAppFallbackLabel.stringValue = currentApp.fallbackText
        currentAppProofLabel.stringValue = currentApp.proofText
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
        startAppProofButton.title = currentApp.proofButtonTitle
        startAppProofButton.isEnabled = currentApp.canStartProof
        disabledAppsLabel.stringValue = currentApp.blockedAppsText
        enableAllAppsButton.isEnabled = currentApp.disabledAppCount > 0
        privacyLabel.stringValue = privacy.statusText
        diagnosticsStatusLabel.stringValue = privacy.diagnosticsStatusText
        rawContentStatusLabel.stringValue = privacy.contentStatusText
        privacySharingStatusLabel.stringValue = privacy.sharingStatusText
        learningStatusLabel.stringValue = privacy.learningStatusText
        let screenRecordingText = privacy.screenRecordingPermissionText
        screenRecordingPermissionLabel.stringValue = screenRecordingText ?? ""
        screenRecordingPermissionLabel.isHidden = screenRecordingText == nil
        privacyPathLabel.stringValue = privacy.pathText
        toggleTracingButton.state = privacy.tracingPaused ? .off : .on
        toggleRawTraceButton.state = privacy.rawContentTracingEnabled ? .on : .off
        toggleScreenshotTraceButton.state = privacy.screenshotTracingEnabled ? .on : .off
        shortcutLabel.stringValue = keyboardShortcuts.statusText
        acceptAllShortcutLabel.stringValue = keyboardShortcuts.acceptAllPickerLabel
        refreshAcceptAllShortcutPopup(selected: keyboardShortcuts.acceptAllShortcut)
        cycleAcceptAllShortcutButton.title = keyboardShortcuts.cycleButtonTitle
        aggressivenessLabel.stringValue = suggestionAggressiveness.statusText
        aggressivenessDetailLabel.stringValue = suggestionAggressiveness.detailText
        cycleAggressivenessButton.title = suggestionAggressiveness.cycleButtonTitle
        firstRunLabel.stringValue = SettingsOnboardingState(
            isTrusted: isTrusted,
            suggestionsPaused: suggestionsPaused,
            runtimeGuidance: guidance
        ).text
    }

    private func buildContent(in contentView: NSView) {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Autocomplete Lab")
        title.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
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
        controlLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        fieldControlLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(fieldControlDetailLabel)
        firstRunLabel.font = NSFont.systemFont(ofSize: 12)
        configureSecondaryLabel(firstRunLabel)
        currentAppLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(currentAppDetailLabel)
        configureSecondaryLabel(currentAppModeLabel)
        configureSecondaryLabel(currentAppAcceptanceLabel)
        configureSecondaryLabel(currentAppFallbackLabel)
        configureSecondaryLabel(currentAppProofLabel)
        configureSecondaryLabel(currentAppProofCommandLabel)
        configureSecondaryLabel(disabledAppsLabel)
        configureSecondaryLabel(suggestionDecisionLabel)
        privacyLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(diagnosticsStatusLabel)
        configureSecondaryLabel(rawContentStatusLabel)
        configureSecondaryLabel(privacySharingStatusLabel)
        configureSecondaryLabel(learningStatusLabel)
        configureSecondaryLabel(screenRecordingPermissionLabel)
        privacyPathLabel.font = NSFont.systemFont(ofSize: 11)
        privacyPathLabel.textColor = .secondaryLabelColor
        privacyPathLabel.lineBreakMode = .byTruncatingMiddle
        privacyPathLabel.maximumNumberOfLines = 1
        privacyPathLabel.preferredMaxLayoutWidth = 470
        shortcutLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        acceptAllShortcutLabel.font = NSFont.systemFont(ofSize: 12)
        acceptAllShortcutLabel.textColor = .secondaryLabelColor
        aggressivenessLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(aggressivenessDetailLabel)

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
        silenceFieldButton.target = self
        silenceFieldButton.action = #selector(silenceFieldControl)
        silenceFieldButton.bezelStyle = .rounded
        silenceFieldButton.toolTip = "Stops suggestions only in the current field until focus changes."
        runtimeActionButton.target = self
        runtimeActionButton.action = #selector(runRuntimeAction)
        runtimeActionButton.bezelStyle = .rounded
        toggleCurrentAppButton.target = self
        toggleCurrentAppButton.action = #selector(toggleCurrentAppControl)
        toggleCurrentAppButton.toolTip = "Adds or removes the current app from your blocked-app list."
        forceMirrorModeButton.target = self
        forceMirrorModeButton.action = #selector(toggleCurrentAppMirrorModeControl)
        forceMirrorModeButton.bezelStyle = .rounded
        forceMirrorModeButton.toolTip = "Forces mirror placement for this app, or resets to its profile mode."
        startAppProofButton.target = self
        startAppProofButton.action = #selector(startAppProofControl)
        startAppProofButton.bezelStyle = .rounded
        startAppProofButton.toolTip = "Turns on temporary screenshot proof for the enabled current app and opens Diagnostics."
        copyProofCommandButton.target = self
        copyProofCommandButton.action = #selector(copyProofCommandControl)
        copyProofCommandButton.bezelStyle = .rounded
        copyProofCommandButton.toolTip = "Copies the exact smoke command for the current app."
        enableAllAppsButton.target = self
        enableAllAppsButton.action = #selector(enableAllAppsControl)
        enableAllAppsButton.bezelStyle = .rounded
        toggleTracingButton.target = self
        toggleTracingButton.action = #selector(toggleTracingControl)
        toggleTracingButton.toolTip = "Keeps local performance and placement events available for debugging."
        toggleRawTraceButton.target = self
        toggleRawTraceButton.action = #selector(toggleRawTraceControl)
        toggleRawTraceButton.toolTip = "Off by default. Turn on only when you need local raw-text debugging."
        toggleScreenshotTraceButton.target = self
        toggleScreenshotTraceButton.action = #selector(toggleScreenshotTraceControl)
        toggleScreenshotTraceButton.toolTip = "Captures local screenshots for placement debugging."
        deleteLocalLogsButton.target = self
        deleteLocalLogsButton.action = #selector(deleteLocalLogsControl)
        deleteLocalLogsButton.bezelStyle = .rounded
        clearLearningDataButton.target = self
        clearLearningDataButton.action = #selector(clearLearningDataControl)
        clearLearningDataButton.bezelStyle = .rounded
        cycleAcceptAllShortcutButton.target = self
        cycleAcceptAllShortcutButton.action = #selector(cycleAcceptAllShortcutControl)
        cycleAcceptAllShortcutButton.bezelStyle = .rounded
        cycleAggressivenessButton.target = self
        cycleAggressivenessButton.action = #selector(cycleAggressivenessControl)
        cycleAggressivenessButton.bezelStyle = .rounded
        cycleAggressivenessButton.toolTip = "Cycles between quiet, normal, and eager suggestions."
        acceptAllShortcutPopup.target = self
        acceptAllShortcutPopup.action = #selector(selectAcceptAllShortcutControl)

        [
            title,
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
                title: "Suggestions",
                views: [
                    controlLabel,
                    togglePauseButton,
                    fieldControlLabel,
                    fieldControlDetailLabel,
                    makeButtonRow([silenceFieldButton]),
                    suggestionDecisionLabel,
                    firstRunLabel
                ]
            ),
            makeSection(
                title: "Apps",
                views: [
                    currentAppLabel,
                    currentAppDetailLabel,
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
                    privacySharingStatusLabel,
                    screenRecordingPermissionLabel,
                    toggleTracingButton,
                    toggleRawTraceButton,
                    toggleScreenshotTraceButton,
                    learningStatusLabel,
                    privacyPathLabel,
                    makeButtonRow([deleteLocalLogsButton, clearLearningDataButton])
                ]
            ),
            makeSection(
                title: "Keyboard",
                views: [
                    shortcutLabel,
                    makeButtonRow([acceptAllShortcutLabel, acceptAllShortcutPopup, cycleAcceptAllShortcutButton]),
                    aggressivenessLabel,
                    aggressivenessDetailLabel,
                    makeButtonRow([cycleAggressivenessButton])
                ]
            )
        ].forEach {
            stack.addArrangedSubview($0)
        }

        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -24)
        ])
    }

    private func configureSecondaryLabel(_ label: NSTextField, maxWidth: CGFloat = 470) {
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
        section.spacing = 5
        return section
    }

    private func makeButtonRow(_ views: [NSView]) -> NSStackView {
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
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
    private func silenceFieldControl() {
        silenceCurrentField()
    }

    @objc
    private func runRuntimeAction() {
        performRuntimeAction(currentRuntimeAction)
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
        startCurrentAppProof()
    }

    @objc
    private func copyProofCommandControl() {
        guard let currentProofCommandClipboardText else {
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(currentProofCommandClipboardText, forType: .string)
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
    private func deleteLocalLogsControl() {
        deleteLocalLogs()
    }

    @objc
    private func clearLearningDataControl() {
        clearLearningData()
    }

    @objc
    private func cycleAcceptAllShortcutControl() {
        cycleAcceptAllShortcut()
    }

    @objc
    private func cycleAggressivenessControl() {
        cycleSuggestionAggressiveness()
    }

    @objc
    private func selectAcceptAllShortcutControl() {
        guard let rawValue = acceptAllShortcutPopup.selectedItem?.representedObject as? String,
              let shortcut = AcceptAllShortcut(rawValue: rawValue) else {
            return
        }

        setAcceptAllShortcut(shortcut)
    }
}
