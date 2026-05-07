import AppKit
import AutocompleteLabCore

struct SettingsCurrentAppState: Equatable {
    let displayName: String
    let bundleIdentifier: String?
    let supportStatus: CompatibilitySupportStatus
    let isEnabled: Bool
    let disabledAppCount: Int
    let renderModeOverride: SuggestionRenderMode?
    let canQuietCurrentField: Bool

    init(
        displayName: String,
        bundleIdentifier: String?,
        supportStatus: CompatibilitySupportStatus,
        isEnabled: Bool,
        disabledAppCount: Int,
        renderModeOverride: SuggestionRenderMode? = nil,
        canQuietCurrentField: Bool = false
    ) {
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.supportStatus = supportStatus
        self.isEnabled = isEnabled
        self.disabledAppCount = disabledAppCount
        self.renderModeOverride = renderModeOverride
        self.canQuietCurrentField = canQuietCurrentField
    }

    var canToggle: Bool {
        bundleIdentifier != nil && supportStatus.canToggleSuggestions
    }

    var canToggleMirrorMode: Bool {
        guard case let .supported(profile) = supportStatus,
              profile.canPresentSuggestions,
              !profile.isSensitive else {
            return false
        }

        return isMirrorForced
            || (profile.renderMode == .inlineAdjacent && profile.fallbackRenderMode == .floatingMirror)
    }

    var isMirrorForced: Bool {
        renderModeOverride == .floatingMirror
    }

    var statusText: String {
        guard bundleIdentifier != nil else {
            return "Current app: no app selected"
        }

        guard supportStatus.canToggleSuggestions else {
            return "Current app: \(displayName) is \(supportStatus.supportLevel.menuName)"
        }

        return "Current app: \(displayName) is \(supportStatus.supportLevel.menuName) and \(isEnabled ? "allowed" : "blocked")"
    }

    var detailText: String {
        guard bundleIdentifier != nil else {
            return "Open a writing app to see whether suggestions are supported."
        }

        guard supportStatus.canToggleSuggestions else {
            return "\(supportStatus.userFacingReason) \(supportStatus.userFacingUnavailableText)"
        }

        if isEnabled {
            return "\(supportStatus.userFacingReason) Suggestions are on for this app."
        }

        return "\(supportStatus.userFacingReason) Suggestions are blocked by your app list."
    }

    var modeText: String {
        guard bundleIdentifier != nil else {
            return "Mode: choose a writing app"
        }

        guard case let .supported(profile) = supportStatus else {
            return "Mode: \(supportStatus.interactionMode.displayName)"
        }

        if isMirrorForced {
            return "Mode: mirror forced"
        }

        let primary = profile.interactionMode.displayName
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

    var safetyText: String {
        guard bundleIdentifier != nil else {
            return "Safety: choose a writing app first"
        }

        if isMirrorForced {
            return "Safety: Mirror forced by you; inline placement stays off for this app."
        }

        return "Safety: \(supportStatus.userFacingSafetySummary)"
    }

    var proofGuideText: String {
        guard let bundleIdentifier else {
            return "Proof: choose a writing app first."
        }

        switch bundleIdentifier {
        case "com.apple.TextEdit":
            return "Proof: copies the disposable TextEdit smoke command."
        case "com.apple.Notes":
            return "Proof: use only a disposable note; title, body, and checklist need separate passes."
        case "md.obsidian":
            return "Proof: use a disposable vault note."
        case "com.google.Chrome":
            return "Proof: copies the local Chrome fixture smoke command."
        case "com.openai.codex", "com.anthropic.claude-code", "com.anthropic.claudefordesktop":
            return "Proof: use a harmless prompt fragment; press Tab only, never Enter."
        default:
            return "Proof: no proof flow for this app yet."
        }
    }

    var proofCommandText: String? {
        guard let bundleIdentifier else {
            return nil
        }

        switch bundleIdentifier {
        case "com.apple.TextEdit":
            return "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh textedit"
        case "com.apple.Notes":
            return [
                "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-title --manual-gate",
                "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-body --manual-gate",
                "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh notes-checklist --manual-gate"
            ].joined(separator: "\n")
        case "md.obsidian":
            return "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh obsidian --manual-gate"
        case "com.google.Chrome":
            return "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh chrome --fixture all"
        case "com.openai.codex":
            return "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh codex --manual-gate"
        case "com.anthropic.claude-code":
            return "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-code --manual-gate"
        case "com.anthropic.claudefordesktop":
            return "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude --manual-gate"
        default:
            return nil
        }
    }

    var canCopyProofCommand: Bool {
        proofCommandText != nil
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

    var mirrorModeTitle: String {
        "Force mirror mode"
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
            return "Autocomplete Lab can read the active field text around the cursor, read cursor and field bounds, and insert only text you accept. Text stays on this Mac."
        }

        return "Allow Accessibility so Autocomplete Lab can read the active field text around the cursor, read cursor and field bounds, and insert only text you accept. Text stays on this Mac."
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

    var screenRecordingPermissionText: String? {
        guard screenshotTracingEnabled else {
            return nil
        }

        if screenshotTracingExpiresAt == nil {
            return "Screen Recording: only captures placement screenshots while this debug switch is on. Normal suggestions do not need it."
        }

        return "Screen Recording: only captures temporary placement screenshots. Normal suggestions do not need it."
    }

    var pathText: String {
        "Logs: \(diagnosticsPath) | Traces: \(tracePath)"
    }

    var statusPanelText: String {
        [
            "Autocomplete Lab keeps suggestions and diagnostics on this Mac.",
            diagnosticsStatusText,
            contentStatusText,
            screenRecordingPermissionText ?? "Screen Recording: off; normal suggestions do not need it.",
            "No raw text is included unless raw text capture is on.",
            "Logs: \(diagnosticsPath)",
            "Traces: \(tracePath)"
        ].joined(separator: "\n")
    }
}

struct SettingsKeyboardShortcutState: Equatable {
    let acceptAllShortcut: AcceptAllShortcut

    var statusText: String {
        "Shortcuts: Tab next word | \(acceptAllShortcut.displayName) all"
    }

    var pickerTitles: [String] {
        AcceptAllShortcut.allCases.map(\.displayName)
    }

    var selectedShortcutTitle: String {
        acceptAllShortcut.displayName
    }
}

struct SettingsSuggestionControlState: Equatable {
    let suggestionsPaused: Bool
    let pace: SuggestionPace

    var statusText: String {
        "Suggestions: \(suggestionsPaused ? "paused" : "ready") | Pace: \(pace.displayName)"
    }

    var detailText: String {
        pace.detailText
    }

    var pickerTitles: [String] {
        SuggestionPace.allCases.map(\.displayName)
    }

    var selectedPaceTitle: String {
        pace.displayName
    }
}

struct SettingsFirstRunState: Equatable {
    let isTrusted: Bool
    let suggestionsPaused: Bool
    let runtimeReport: RuntimeReadinessReport
    let currentApp: SettingsCurrentAppState

    var message: String {
        if !isTrusted {
            return "Start here: allow Accessibility so Autocomplete Lab can read cursor text and bounds, then insert only what you accept. Text stays on this Mac."
        }

        guard runtimeReport.stage == .ready else {
            return RuntimeReadinessGuidance(report: runtimeReport).message
        }

        if suggestionsPaused {
            return "Start paused: open TextEdit with a disposable document, then turn on Suggestions when you are ready to test."
        }

        if currentApp.bundleIdentifier == "com.apple.TextEdit" {
            return "Ready: TextEdit is the first test app. Use a disposable document; Tab accepts one word and Esc dismisses."
        }

        return "Ready: start in TextEdit with a disposable document before testing Notes, Obsidian, or prompt apps."
    }

    var textEditTestButtonTitle: String {
        "Open TextEdit Test"
    }

    var canOpenTextEditTest: Bool {
        isTrusted && runtimeReport.stage == .ready
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
    private let controlLabel = NSTextField(labelWithString: "")
    private let suggestionPaceDetailLabel = NSTextField(labelWithString: "")
    private let suggestionPacePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let togglePauseButton = NSButton(checkboxWithTitle: "Suggestions", target: nil, action: nil)
    private let runtimeActionButton = NSButton(title: "Open Model Folder", target: nil, action: nil)
    private let currentAppLabel = NSTextField(labelWithString: "")
    private let currentAppDetailLabel = NSTextField(labelWithString: "")
    private let currentAppModeLabel = NSTextField(labelWithString: "")
    private let currentAppAcceptanceLabel = NSTextField(labelWithString: "")
    private let currentAppSafetyLabel = NSTextField(labelWithString: "")
    private let currentAppProofLabel = NSTextField(labelWithString: "")
    private let disabledAppsLabel = NSTextField(labelWithString: "")
    private let suggestionDecisionLabel = NSTextField(labelWithString: "")
    private let toggleMirrorModeButton = NSButton(
        checkboxWithTitle: "Force mirror mode",
        target: nil,
        action: nil
    )
    private let quietCurrentFieldButton = NSButton(
        title: "Quiet Current Field",
        target: nil,
        action: nil
    )
    private let copyProofCommandButton = NSButton(
        title: "Copy Proof Command",
        target: nil,
        action: nil
    )
    private let openCommandContextButton = NSButton(
        title: "Command Context...",
        target: nil,
        action: nil
    )
    private let toggleCurrentAppButton = NSButton(
        checkboxWithTitle: "Allow suggestions in this app",
        target: nil,
        action: nil
    )
    private let enableAllAppsButton = NSButton(title: "Clear Blocked Apps", target: nil, action: nil)
    private let privacyLabel = NSTextField(labelWithString: "")
    private let diagnosticsStatusLabel = NSTextField(labelWithString: "")
    private let rawContentStatusLabel = NSTextField(labelWithString: "")
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
    private let privacyStatusButton = NSButton(title: "Privacy Status...", target: nil, action: nil)
    private let deleteLocalLogsButton = NSButton(title: "Delete Local Logs", target: nil, action: nil)
    private let shortcutLabel = NSTextField(labelWithString: "")
    private let acceptAllShortcutPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let firstRunLabel = NSTextField(wrappingLabelWithString: "")
    private let openTextEditTestButton = NSButton(title: "Open TextEdit Test", target: nil, action: nil)
    private let requestPermission: () -> Void
    private let openAccessibilitySettings: () -> Void
    private let toggleSuggestionsPaused: () -> Void
    private let openTextEditTest: () -> Void
    private let performRuntimeAction: (RuntimeReadinessAction) -> Void
    private let toggleCurrentApp: () -> Void
    private let toggleMirrorMode: () -> Void
    private let quietCurrentField: () -> Void
    private let copyProofCommand: (String) -> Void
    private let openCommandContext: () -> Void
    private let enableAllApps: () -> Void
    private let toggleTracingPaused: () -> Void
    private let toggleRawContentTracing: () -> Void
    private let toggleScreenshotTracing: () -> Void
    private let deleteLocalLogs: () -> Void
    private let showPrivacyStatus: (String) -> Void
    private let setAcceptAllShortcut: (AcceptAllShortcut) -> Void
    private let setSuggestionPace: (SuggestionPace) -> Void
    private var currentRuntimeAction: RuntimeReadinessAction = .none
    private var currentProofCommand: String?
    private var currentPrivacyStatusText = ""

    init(
        requestPermission: @escaping () -> Void,
        openAccessibilitySettings: @escaping () -> Void,
        toggleSuggestionsPaused: @escaping () -> Void,
        openTextEditTest: @escaping () -> Void,
        performRuntimeAction: @escaping (RuntimeReadinessAction) -> Void,
        toggleCurrentApp: @escaping () -> Void,
        toggleMirrorMode: @escaping () -> Void,
        quietCurrentField: @escaping () -> Void,
        copyProofCommand: @escaping (String) -> Void,
        openCommandContext: @escaping () -> Void,
        enableAllApps: @escaping () -> Void,
        toggleTracingPaused: @escaping () -> Void,
        toggleRawContentTracing: @escaping () -> Void,
        toggleScreenshotTracing: @escaping () -> Void,
        deleteLocalLogs: @escaping () -> Void,
        showPrivacyStatus: @escaping (String) -> Void,
        setAcceptAllShortcut: @escaping (AcceptAllShortcut) -> Void,
        setSuggestionPace: @escaping (SuggestionPace) -> Void
    ) {
        self.requestPermission = requestPermission
        self.openAccessibilitySettings = openAccessibilitySettings
        self.toggleSuggestionsPaused = toggleSuggestionsPaused
        self.openTextEditTest = openTextEditTest
        self.performRuntimeAction = performRuntimeAction
        self.toggleCurrentApp = toggleCurrentApp
        self.toggleMirrorMode = toggleMirrorMode
        self.quietCurrentField = quietCurrentField
        self.copyProofCommand = copyProofCommand
        self.openCommandContext = openCommandContext
        self.enableAllApps = enableAllApps
        self.toggleTracingPaused = toggleTracingPaused
        self.toggleRawContentTracing = toggleRawContentTracing
        self.toggleScreenshotTracing = toggleScreenshotTracing
        self.deleteLocalLogs = deleteLocalLogs
        self.showPrivacyStatus = showPrivacyStatus
        self.setAcceptAllShortcut = setAcceptAllShortcut
        self.setSuggestionPace = setSuggestionPace

        let contentView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 560, height: 760))
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
        window.contentMinSize = NSSize(width: 540, height: 700)
        window.isMovableByWindowBackground = true

        super.init()

        buildContent(in: contentView)
    }

    func show(
        isTrusted: Bool,
        suggestionsPaused: Bool,
        suggestionPace: SuggestionPace,
        runtimeReport: RuntimeReadinessReport,
        runtimeTargetSummary: String,
        modelDirectoryPath: String,
        currentApp: SettingsCurrentAppState,
        privacy: SettingsPrivacyState,
        keyboardShortcuts: SettingsKeyboardShortcutState,
        lastSuggestionDecision: String
    ) {
        refresh(
            isTrusted: isTrusted,
            suggestionsPaused: suggestionsPaused,
            suggestionPace: suggestionPace,
            runtimeReport: runtimeReport,
            runtimeTargetSummary: runtimeTargetSummary,
            modelDirectoryPath: modelDirectoryPath,
            currentApp: currentApp,
            privacy: privacy,
            keyboardShortcuts: keyboardShortcuts,
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
        suggestionPace: SuggestionPace,
        runtimeReport: RuntimeReadinessReport,
        runtimeTargetSummary: String,
        modelDirectoryPath: String,
        currentApp: SettingsCurrentAppState,
        privacy: SettingsPrivacyState,
        keyboardShortcuts: SettingsKeyboardShortcutState,
        lastSuggestionDecision: String
    ) {
        let suggestionControl = SettingsSuggestionControlState(
            suggestionsPaused: suggestionsPaused,
            pace: suggestionPace
        )
        let guidance = RuntimeReadinessGuidance(report: runtimeReport)
        let permission = SettingsPermissionState(isTrusted: isTrusted)
        permissionLabel.stringValue = permission.statusText
        permissionDetailLabel.stringValue = permission.detailText
        controlLabel.stringValue = suggestionControl.statusText
        suggestionPaceDetailLabel.stringValue = suggestionControl.detailText
        suggestionPacePopup.selectItem(withTitle: suggestionControl.selectedPaceTitle)
        suggestionDecisionLabel.stringValue = "Why: \(lastSuggestionDecision)"
        togglePauseButton.state = suggestionsPaused ? .off : .on
        runtimeLabel.stringValue = "Local model: \(runtimeReport.summary)"
        runtimeDetailLabel.stringValue = runtimeReport.detail ?? ""
        runtimeDetailLabel.isHidden = runtimeReport.detail == nil
        runtimeActionLabel.stringValue = "Next step: \(runtimeReport.action.displayName)"
        runtimeActionButton.title = guidance.actionTitle
        runtimeActionButton.isEnabled = guidance.isActionEnabled
        currentRuntimeAction = runtimeReport.action
        runtimeTargetLabel.stringValue = "Runtime target: \(runtimeTargetSummary)"
        modelDirectoryLabel.stringValue = "Model folder: \(modelDirectoryPath)"
        currentAppLabel.stringValue = currentApp.statusText
        currentAppDetailLabel.stringValue = currentApp.detailText
        currentAppModeLabel.stringValue = currentApp.modeText
        currentAppAcceptanceLabel.stringValue = currentApp.acceptanceText
        currentAppSafetyLabel.stringValue = currentApp.safetyText
        currentAppProofLabel.stringValue = currentApp.proofGuideText
        currentProofCommand = currentApp.proofCommandText
        copyProofCommandButton.isEnabled = currentApp.canCopyProofCommand
        toggleMirrorModeButton.title = currentApp.mirrorModeTitle
        toggleMirrorModeButton.state = currentApp.isMirrorForced ? .on : .off
        toggleMirrorModeButton.isEnabled = currentApp.canToggleMirrorMode
        quietCurrentFieldButton.isEnabled = currentApp.canQuietCurrentField
        toggleCurrentAppButton.title = currentApp.toggleTitle
        toggleCurrentAppButton.state = currentApp.isEnabled ? .on : .off
        toggleCurrentAppButton.isEnabled = currentApp.canToggle
        disabledAppsLabel.stringValue = currentApp.blockedAppsText
        enableAllAppsButton.isEnabled = currentApp.disabledAppCount > 0
        privacyLabel.stringValue = privacy.statusText
        diagnosticsStatusLabel.stringValue = privacy.diagnosticsStatusText
        rawContentStatusLabel.stringValue = privacy.contentStatusText
        let screenRecordingText = privacy.screenRecordingPermissionText
        screenRecordingPermissionLabel.stringValue = screenRecordingText ?? ""
        screenRecordingPermissionLabel.isHidden = screenRecordingText == nil
        privacyPathLabel.stringValue = privacy.pathText
        currentPrivacyStatusText = privacy.statusPanelText
        toggleTracingButton.state = privacy.tracingPaused ? .off : .on
        toggleRawTraceButton.state = privacy.rawContentTracingEnabled ? .on : .off
        toggleScreenshotTraceButton.state = privacy.screenshotTracingEnabled ? .on : .off
        shortcutLabel.stringValue = keyboardShortcuts.statusText
        acceptAllShortcutPopup.selectItem(withTitle: keyboardShortcuts.selectedShortcutTitle)
        let firstRun = SettingsFirstRunState(
            isTrusted: isTrusted,
            suggestionsPaused: suggestionsPaused,
            runtimeReport: runtimeReport,
            currentApp: currentApp
        )
        firstRunLabel.stringValue = firstRun.message
        openTextEditTestButton.title = firstRun.textEditTestButtonTitle
        openTextEditTestButton.isEnabled = firstRun.canOpenTextEditTest
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
        controlLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(suggestionPaceDetailLabel)
        firstRunLabel.font = NSFont.systemFont(ofSize: 12)
        configureSecondaryLabel(firstRunLabel)
        currentAppLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(currentAppDetailLabel)
        configureSecondaryLabel(currentAppModeLabel)
        configureSecondaryLabel(currentAppAcceptanceLabel)
        configureSecondaryLabel(currentAppSafetyLabel)
        configureSecondaryLabel(currentAppProofLabel)
        configureSecondaryLabel(disabledAppsLabel)
        configureSecondaryLabel(suggestionDecisionLabel)
        privacyLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(diagnosticsStatusLabel)
        configureSecondaryLabel(rawContentStatusLabel)
        configureSecondaryLabel(screenRecordingPermissionLabel)
        privacyPathLabel.font = NSFont.systemFont(ofSize: 11)
        privacyPathLabel.textColor = .secondaryLabelColor
        privacyPathLabel.lineBreakMode = .byTruncatingMiddle
        privacyPathLabel.maximumNumberOfLines = 1
        privacyPathLabel.preferredMaxLayoutWidth = 470
        shortcutLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)

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
        openTextEditTestButton.target = self
        openTextEditTestButton.action = #selector(openTextEditTestControl)
        openTextEditTestButton.bezelStyle = .rounded
        openTextEditTestButton.toolTip = "Opens a disposable TextEdit document for the first test."
        suggestionPacePopup.removeAllItems()
        suggestionPacePopupItems().forEach { item in
            suggestionPacePopup.menu?.addItem(item)
        }
        suggestionPacePopup.target = self
        suggestionPacePopup.action = #selector(selectSuggestionPaceControl)
        suggestionPacePopup.toolTip = "Chooses how soon suggestions appear in allowed apps."
        runtimeActionButton.target = self
        runtimeActionButton.action = #selector(runRuntimeAction)
        runtimeActionButton.bezelStyle = .rounded
        toggleCurrentAppButton.target = self
        toggleCurrentAppButton.action = #selector(toggleCurrentAppControl)
        toggleCurrentAppButton.toolTip = "Adds or removes the current app from your blocked-app list."
        toggleMirrorModeButton.target = self
        toggleMirrorModeButton.action = #selector(toggleMirrorModeControl)
        toggleMirrorModeButton.toolTip = "Forces this app to use the safer mirror surface instead of inline placement."
        quietCurrentFieldButton.target = self
        quietCurrentFieldButton.action = #selector(quietCurrentFieldControl)
        quietCurrentFieldButton.bezelStyle = .rounded
        quietCurrentFieldButton.toolTip = "Hides suggestions for this field until focus changes."
        copyProofCommandButton.target = self
        copyProofCommandButton.action = #selector(copyProofCommandControl)
        copyProofCommandButton.bezelStyle = .rounded
        copyProofCommandButton.toolTip = "Copies the exact local smoke command for this app."
        openCommandContextButton.target = self
        openCommandContextButton.action = #selector(openCommandContextControl)
        openCommandContextButton.bezelStyle = .rounded
        openCommandContextButton.toolTip = "Opens a separate copy-only suggestion panel for uncertain apps."
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
        privacyStatusButton.target = self
        privacyStatusButton.action = #selector(showPrivacyStatusControl)
        privacyStatusButton.bezelStyle = .rounded
        privacyStatusButton.toolTip = "Shows what privacy-sensitive diagnostics are enabled right now."
        deleteLocalLogsButton.target = self
        deleteLocalLogsButton.action = #selector(deleteLocalLogsControl)
        deleteLocalLogsButton.bezelStyle = .rounded
        acceptAllShortcutPopup.removeAllItems()
        keyboardShortcutPopupItems().forEach { item in
            acceptAllShortcutPopup.menu?.addItem(item)
        }
        acceptAllShortcutPopup.target = self
        acceptAllShortcutPopup.action = #selector(selectAcceptAllShortcutControl)
        acceptAllShortcutPopup.toolTip = "Chooses the shortcut for accepting all visible suggestion text."

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
                    runtimeTargetLabel,
                    modelDirectoryLabel
                ]
            ),
            makeSection(
                title: "Suggestions",
                views: [
                    controlLabel,
                    makeButtonRow([togglePauseButton, suggestionPacePopup]),
                    suggestionPaceDetailLabel,
                    suggestionDecisionLabel,
                    firstRunLabel,
                    makeButtonRow([openTextEditTestButton])
                ]
            ),
            makeSection(
                title: "Apps",
                views: [
                    currentAppLabel,
                    currentAppDetailLabel,
                    currentAppModeLabel,
                    currentAppAcceptanceLabel,
                    currentAppSafetyLabel,
                    currentAppProofLabel,
                    toggleMirrorModeButton,
                    toggleCurrentAppButton,
                    makeButtonRow([openCommandContextButton, copyProofCommandButton, quietCurrentFieldButton]),
                    makeButtonRow([disabledAppsLabel, enableAllAppsButton])
                ]
            ),
            makeSection(
                title: "Privacy and Diagnostics",
                views: [
                    privacyLabel,
                    diagnosticsStatusLabel,
                    rawContentStatusLabel,
                    screenRecordingPermissionLabel,
                    toggleTracingButton,
                    toggleRawTraceButton,
                    toggleScreenshotTraceButton,
                    privacyPathLabel,
                    makeButtonRow([privacyStatusButton, deleteLocalLogsButton])
                ]
            ),
            makeSection(
                title: "Keyboard",
                views: [
                    shortcutLabel,
                    makeButtonRow([acceptAllShortcutPopup])
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

    private func keyboardShortcutPopupItems() -> [NSMenuItem] {
        AcceptAllShortcut.allCases.map { shortcut in
            let item = NSMenuItem(title: shortcut.displayName, action: nil, keyEquivalent: "")
            item.representedObject = shortcut.rawValue
            return item
        }
    }

    private func suggestionPacePopupItems() -> [NSMenuItem] {
        SuggestionPace.allCases.map { pace in
            let item = NSMenuItem(title: pace.displayName, action: nil, keyEquivalent: "")
            item.representedObject = pace.rawValue
            return item
        }
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
    private func openTextEditTestControl() {
        openTextEditTest()
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
    private func toggleMirrorModeControl() {
        toggleMirrorMode()
    }

    @objc
    private func quietCurrentFieldControl() {
        quietCurrentField()
    }

    @objc
    private func copyProofCommandControl() {
        guard let currentProofCommand else {
            return
        }

        copyProofCommand(currentProofCommand)
    }

    @objc
    private func openCommandContextControl() {
        openCommandContext()
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
    private func showPrivacyStatusControl() {
        showPrivacyStatus(currentPrivacyStatusText)
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
    private func selectSuggestionPaceControl() {
        guard let rawValue = suggestionPacePopup.selectedItem?.representedObject as? String,
              let pace = SuggestionPace(rawValue: rawValue) else {
            return
        }

        setSuggestionPace(pace)
    }
}
