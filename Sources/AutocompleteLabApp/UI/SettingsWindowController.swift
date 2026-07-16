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

/// A small, calm status dot that reads at a glance the same way a traffic-light
/// dot reads in the menu bar: green for active, gray for paused, etc.
private final class SettingsStatusDotView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = frameRect.height / 2
        widthAnchor.constraint(equalToConstant: frameRect.width).isActive = true
        heightAnchor.constraint(equalToConstant: frameRect.height).isActive = true
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(color: NSColor) {
        layer?.backgroundColor = color.cgColor
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

    var canChangePlacement: Bool {
        guard bundleIdentifier != nil,
              case let .supported(profile) = supportStatus,
              profile.canPresentSuggestions,
              !profile.isSensitive,
              profile.renderMode != .disabled else {
            return false
        }

        return true
    }

    var statusText: String {
        guard bundleIdentifier != nil else {
            return "No writing app in front"
        }

        guard canToggle else {
            return "\(displayName): suggestions aren’t available here"
        }

        return isEnabled
            ? "\(displayName): suggestions on"
            : "\(displayName): suggestions paused"
    }

    var detailText: String {
        guard bundleIdentifier != nil else {
            return "Open a writing app to see whether SteadyType can help there."
        }

        guard canToggle else {
            return "\(supportStatus.userFacingReason) Suggestions stay off here."
        }

        if isEnabled {
            return "\(supportStatus.userFacingReason) Suggestions are on for this app."
        }

        return "\(supportStatus.userFacingReason) Suggestions are paused here — resume them whenever you like."
    }

    /// Short, plain tooltip used by the menu-bar “Pause in …” item.
    var fallbackText: String {
        guard bundleIdentifier != nil else {
            return "Choose a writing app first."
        }

        guard canToggle else {
            return "Suggestions aren’t available in this app."
        }

        return isEnabled
            ? "Suggestions are on in this app."
            : "Suggestions are paused in this app."
    }

    var toggleTitle: String {
        guard canToggle else {
            return "Suggestions unavailable in this app"
        }

        return "Suggest while I type here"
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

    var placementButtonTitle: String {
        renderModeOverride == .floatingMirror ? "Show Inline Text" : "Show in a Floating Box"
    }

    var blockedAppsText: String {
        if disabledAppCount == 0 {
            return "No apps are paused."
        }

        return disabledAppCount == 1
            ? "1 app is paused."
            : "\(disabledAppCount) apps are paused."
    }
}

struct SettingsPermissionState: Equatable {
    let isTrusted: Bool

    var statusText: String {
        isTrusted ? "Accessibility: allowed" : "Accessibility: needed"
    }

    var detailText: String {
        if isTrusted {
            return "SteadyType can read the text field you’re typing in and only inserts text after you accept a suggestion. Nothing leaves your Mac. Screen Recording is not needed for everyday use."
        }

        return "SteadyType needs Accessibility so it can see the text field you’re typing in and insert a suggestion only after you accept it. Nothing leaves your Mac. Screen Recording is not needed for everyday use."
    }
}

struct SettingsFirstRunTrustState: Equatable {
    var statusText: String {
        "New here? Start in TextEdit"
    }

    var detailText: String {
        "Suggestions appear in light gray next to your cursor. Press Tab to accept one word, Shift-Tab for the whole visible suggestion, and Esc to dismiss. Pause Suggestions stops them everywhere; Pause in Current App stops only that app."
    }

    var quickStartText: String {
        "60-second path: Allow Accessibility, wait for the on-device model, Start TextEdit Practice, press Tab once, Shift-Tab once, Esc once, then Delete Local Logs."
    }

    var appsText: String {
        "Everything stays on this Mac. Start with TextEdit. Try Notes, Obsidian, and Chrome practice pages when you’re ready. Avoid random websites, search, login, payment, and private fields for now."
    }
}

struct SettingsPrivacyState: Equatable {
    let tracingPaused: Bool
    let rawContentTracingEnabled: Bool
    let rawContentTracingExpiresAt: Date?
    let screenshotTracingEnabled: Bool
    let screenshotTracingExpiresAt: Date?
    let visiblePageContextEnabled: Bool
    let personalCaptureEnabled: Bool
    let screenCaptureAccessGranted: Bool
    let diagnosticsPath: String
    let tracePath: String
    let personalCapturePath: String

    init(
        tracingPaused: Bool,
        rawContentTracingEnabled: Bool,
        rawContentTracingExpiresAt: Date?,
        screenshotTracingEnabled: Bool,
        screenshotTracingExpiresAt: Date?,
        visiblePageContextEnabled: Bool,
        personalCaptureEnabled: Bool = false,
        screenCaptureAccessGranted: Bool,
        diagnosticsPath: String,
        tracePath: String,
        personalCapturePath: String = ""
    ) {
        self.tracingPaused = tracingPaused
        self.rawContentTracingEnabled = rawContentTracingEnabled
        self.rawContentTracingExpiresAt = rawContentTracingExpiresAt
        self.screenshotTracingEnabled = screenshotTracingEnabled
        self.screenshotTracingExpiresAt = screenshotTracingExpiresAt
        self.visiblePageContextEnabled = visiblePageContextEnabled
        self.personalCaptureEnabled = personalCaptureEnabled
        self.screenCaptureAccessGranted = screenCaptureAccessGranted
        self.diagnosticsPath = diagnosticsPath
        self.tracePath = tracePath
        self.personalCapturePath = personalCapturePath
    }

    var statusText: String {
        "Everything stays on your Mac"
    }

    var diagnosticsStatusText: String {
        "Activity log: \(tracingPaused ? "paused" : "on")"
    }

    var contentStatusText: String {
        let state = rawContentTracingEnabled
            ? (rawContentTracingExpiresAt == nil ? "on" : "on for a short time")
            : "off"
        return "Exact text in logs: \(state)"
    }

    var visiblePageContextStatusText: String {
        if visiblePageContextEnabled && !screenCaptureAccessGranted {
            return "Reads nearby on-screen text: on — waiting for Screen Recording permission."
        }

        return "Reads nearby on-screen text: \(visiblePageContextEnabled ? "on" : "off"). This happens on your Mac and only improves suggestions."
    }

    var personalCaptureStatusText: String {
        "Writing journal: \(personalCaptureEnabled ? "on" : "off")"
    }

    var personalCaptureDetailText: String {
        "Optional. Saves a daily Markdown file on this Mac so SteadyType can learn from your real writing. It stays out of any diagnostic report."
    }

    var sharingStatusText: String {
        "Nothing is ever sent automatically. A diagnostic report you choose to export never includes your text or screenshots."
    }

    var localOnlyProofText: String {
        "Suggestions come from a model that runs entirely on your Mac. There is no server, and exact text is off by default."
    }

    var learningStatusText: String {
        "SteadyType remembers which suggestions you keep — only on this Mac."
    }

    var screenRecordingPermissionText: String? {
        guard screenshotTracingEnabled || visiblePageContextEnabled else {
            return nil
        }

        if visiblePageContextEnabled && !screenCaptureAccessGranted {
            return "Screen Recording: needed to read nearby on-screen text."
        }

        if visiblePageContextEnabled {
            return "Screen Recording: used on your Mac to read nearby on-screen text."
        }

        return "Screen Recording: used on your Mac to check where suggestions appear."
    }

    var pathText: String {
        guard !personalCapturePath.isEmpty else {
            return "Activity log: \(diagnosticsPath) | Event log: \(tracePath)"
        }

        return "Activity log: \(diagnosticsPath) | Event log: \(tracePath) | Writing journal: \(personalCapturePath)"
    }
}

struct SettingsKeyboardShortcutState: Equatable {
    let acceptAllShortcut: AcceptAllShortcut
    let conflict: KeyboardShortcutConflictEvaluation
    let summonShortcut: SuggestionSummonHotKeyDescriptor

    init(
        acceptAllShortcut: AcceptAllShortcut,
        currentApp: SettingsCurrentAppState? = nil,
        summonShortcut: SuggestionSummonHotKeyDescriptor = .controlBacktick
    ) {
        self.acceptAllShortcut = acceptAllShortcut
        self.summonShortcut = summonShortcut
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
        "Tab accepts one word. Esc dismisses. \(summonShortcut.displayName) asks for a suggestion."
    }

    var acceptAllStatusText: String {
        if acceptAllShortcut == .disabled {
            return "Accepting the whole suggestion is off."
        }

        return "\(acceptAllShortcut.displayName) accepts the whole suggestion."
    }

    var cycleButtonTitle: String {
        switch acceptAllShortcut {
        case .shiftTab:
            return "Use Option-Tab"
        case .optionTab:
            return "Turn Off"
        case .disabled:
            return "Use Shift-Tab"
        }
    }

    var acceptAllPickerLabel: String {
        "Accept the whole suggestion with:"
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

struct SettingsTrustState: Equatable {
    let isTrusted: Bool
    let suggestionsPaused: Bool
    let runtimeReport: RuntimeReadinessReport
    let currentApp: SettingsCurrentAppState
    let privacy: SettingsPrivacyState
    let lastSuggestionDecision: String

    var statusText: String {
        if !isTrusted {
            return "Waiting for Accessibility"
        }

        if suggestionsPaused {
            return "Suggestions are paused"
        }

        return "SteadyType is on"
    }

    var localModeText: String {
        "On-device model: \(runtimeReport.summary)."
    }

    var typedTextText: String {
        if privacy.rawContentTracingEnabled || privacy.personalCaptureEnabled {
            return "Your text: a local journal or detailed log is on."
        }

        return "Your text: never stored unless you turn it on."
    }

    var currentSurfaceText: String {
        currentApp.statusText
    }

    var whyText: String {
        "Why now: \(lastSuggestionDecision)"
    }
}

struct SettingsFeedbackState: Equatable {
    var statusText: String {
        "Feedback shares a redacted report only"
    }

    var detailText: String {
        "Use this to send beta feedback. The report leaves out your text, prompts, accepted suggestions, and screenshots."
    }

    var buttonTitle: String {
        "Export Diagnostic Report…"
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
            return "Practice: on-device model not ready"
        }

        if suggestionsPaused {
            return "Practice: ready, suggestions paused"
        }

        return "Practice: ready in TextEdit"
    }

    var detailText: String {
        "TextEdit is the safest place to start. Practice opens a throwaway local file so you can try suggestions near the cursor. No Screen Recording needed."
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
        "Try it: press Tab once for one word, Shift-Tab once for the whole visible suggestion, type more and press Esc to dismiss, then pause suggestions or delete local logs before you leave."
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
            return isModelInstallInProgress ? "Setting Up Model…" : "Practice Not Ready"
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
        "How eager: \(tuning.displayName)"
    }

    var detailText: String {
        tuning.detailText
    }

    var boringGuardrailText: String {
        "These fine-tune the basics above. The defaults favor short, unsurprising suggestions; nudge them only if SteadyType feels too quiet or too busy."
    }

    var maxWordsText: String {
        "Longest suggestion: \(tuning.maxVisibleWords) \(tuning.maxVisibleWords == 1 ? "word" : "words")"
    }

    var maxWordsDetailText: String {
        let minimum = CompletionModelPolicy.preferredMinimumVisibleWords(forVisibleWords: tuning.maxVisibleWords)
        if minimum > 1 {
            return "Aims for \(minimum)–\(tuning.maxVisibleWords) words when there’s enough context."
        }

        return "Allows suggestions up to \(tuning.maxVisibleWords) \(tuning.maxVisibleWords == 1 ? "word" : "words") long."
    }

    var aggressivenessSliderValue: Double {
        Double(tuning.aggressivenessLevel)
    }

    var maxWordsSliderValue: Double {
        Double(tuning.maxVisibleWords)
    }

    var wordStartText: String {
        "Show word hints after: \(tuning.wordStartCharacters) \(tuning.wordStartCharacters == 1 ? "letter" : "letters")"
    }

    var wordStartDetailText: String {
        "Lower shows word suggestions sooner."
    }

    var phraseStartText: String {
        "Show phrase hints after: \(tuning.phraseStartWords) \(tuning.phraseStartWords == 1 ? "word" : "words")"
    }

    var phraseStartDetailText: String {
        "Lower offers longer phrase suggestions with less context."
    }

    var responseSpeedText: String {
        "Suggestion delay: \(responseSpeedName)"
    }

    var responseSpeedDetailText: String {
        "Higher shows suggestions sooner; lower waits for a clearer pause."
    }

    var confidenceText: String {
        "How sure before showing: \(confidenceName)"
    }

    var confidenceDetailText: String {
        "Looser shows more guesses; stricter shows fewer."
    }

    var learningRestraintText: String {
        "Influence of your history: \(learningRestraintName)"
    }

    var learningRestraintDetailText: String {
        "Higher means suggestions you’ve ignored before are more likely to stay hidden."
    }

    var wordStartSliderValue: Double {
        Double(tuning.wordStartCharacters)
    }

    var phraseStartSliderValue: Double {
        Double(tuning.phraseStartWords)
    }

    var responseSpeedSliderValue: Double {
        Double(tuning.responseSpeedLevel)
    }

    var confidenceSliderValue: Double {
        Double(tuning.confidenceLevel)
    }

    var learningRestraintSliderValue: Double {
        Double(tuning.learningRestraintLevel)
    }

    private var responseSpeedName: String {
        switch tuning.responseSpeedLevel {
        case 1:
            "Slow"
        case 2:
            "Calm"
        case 4:
            "Fast"
        case 5:
            "Instant"
        default:
            "Normal"
        }
    }

    private var confidenceName: String {
        switch tuning.confidenceLevel {
        case 1:
            "Strict"
        case 2:
            "Careful"
        case 4:
            "Loose"
        case 5:
            "Very Loose"
        default:
            "Normal"
        }
    }

    private var learningRestraintName: String {
        switch tuning.learningRestraintLevel {
        case 0:
            "Off"
        case 1:
            "Low"
        case 3:
            "High"
        default:
            "Normal"
        }
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
            return "Right now: quiet"
        case "waiting":
            return "Right now: getting ready"
        case "queued", "running":
            return "Right now: thinking on your Mac"
        case "shown", "kept current suggestion":
            return "Right now: showing a suggestion"
        case "accepted":
            return "Right now: accepted"
        case "hidden":
            return "Right now: hidden"
        case "paused":
            return "Right now: paused"
        case "ready", "starting":
            return "Right now: ready"
        default:
            guard !displayPrefix.isEmpty else {
                return "Right now: ready"
            }

            return "Right now: \(displayPrefix)"
        }
    }

    var detailText: String {
        switch normalizedPrefix {
        case "blocked":
            let reason = reasonText ?? "a safety or timing check is holding suggestions"
            return "Quiet because \(reason). Keep typing and it’ll pick back up."
        case "waiting":
            let reason = reasonText ?? "the field needs a moment to settle"
            return "Getting ready: \(reason). This keeps suggestions from jumping around."
        case "queued", "running":
            return "Thinking on your Mac. Your text never leaves it."
        case "shown", "kept current suggestion":
            return "A suggestion is next to your cursor. Tab accepts one word; Shift-Tab accepts the whole visible suggestion; Esc dismisses."
        case "accepted":
            return "Accepted. SteadyType will look for the next suggestion once the field settles."
        case "hidden":
            return "Hidden. Keep typing to bring suggestions back."
        case "paused":
            return "Paused. Resume whenever you want suggestions again."
        case "ready", "starting":
            return "Ready as soon as you type in a supported field."
        default:
            return "Latest: \(rawDecision.isEmpty ? "ready" : rawDecision)"
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
            return "Current field: nothing selected yet"
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
            return "Click into a writing field to silence just that field."
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
    private let tabView = NSTabView()
    private let tabSelector = NSSegmentedControl(
        labels: ["General", "Privacy", "Advanced"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let contentScrollView = NSScrollView()
    private let scrollDocumentView = FlippedSettingsDocumentView()

    // Status header
    private let statusDot = SettingsStatusDotView(frame: NSRect(x: 0, y: 0, width: 9, height: 9))
    private let statusHeadlineLabel = NSTextField(labelWithString: "")
    private let statusDetailLabel = NSTextField(labelWithString: "")

    // Setup / onboarding
    private let firstRunTrustLabel = NSTextField(labelWithString: "")
    private let firstRunTrustDetailLabel = NSTextField(labelWithString: "")
    private let firstRunTrustQuickStartLabel = NSTextField(labelWithString: "")
    private let firstRunTrustAppsLabel = NSTextField(labelWithString: "")
    private let permissionLabel = NSTextField(labelWithString: "")
    private let permissionDetailLabel = NSTextField(labelWithString: "")
    private let practiceLabel = NSTextField(labelWithString: "")
    private let practiceDetailLabel = NSTextField(labelWithString: "")
    private let practiceStepsLabel = NSTextField(labelWithString: "")
    private let practicePrimaryButton = NSButton(title: "Start TextEdit Practice", target: nil, action: nil)
    private let practicePauseButton = NSButton(title: "Pause Suggestions", target: nil, action: nil)
    private let practiceDeleteTracesButton = NSButton(title: "Delete Local Logs", target: nil, action: nil)
    private let setupCardStack = NSStackView()
    private var setupSection: NSStackView?

    // Suggestions (General)
    private let controlDetailLabel = NSTextField(labelWithString: "")
    private let togglePauseButton = NSButton(checkboxWithTitle: "Show suggestions while I type", target: nil, action: nil)
    private let pause15MinutesButton = NSButton(title: "15 Minutes", target: nil, action: nil)
    private let pause1HourButton = NSButton(title: "1 Hour", target: nil, action: nil)
    private let pauseUntilTomorrowButton = NSButton(title: "Until Tomorrow", target: nil, action: nil)
    private let aggressivenessLabel = NSTextField(labelWithString: "")
    private let aggressivenessDetailLabel = NSTextField(labelWithString: "")
    private let aggressivenessSlider = NSSlider()

    // This app (General)
    private let currentAppLabel = NSTextField(labelWithString: "")
    private let currentAppDetailLabel = NSTextField(labelWithString: "")
    private let toggleCurrentAppButton = NSButton(
        checkboxWithTitle: "Suggest while I type here",
        target: nil,
        action: nil
    )
    private let silenceFieldButton = NSButton(title: "Silence This Field", target: nil, action: nil)
    private let fieldControlDetailLabel = NSTextField(labelWithString: "")
    private let disabledAppsLabel = NSTextField(labelWithString: "")
    private let enableAllAppsButton = NSButton(title: "Resume Paused Apps", target: nil, action: nil)

    // Keyboard (General)
    private let shortcutLabel = NSTextField(labelWithString: "")
    private let acceptAllShortcutLabel = NSTextField(labelWithString: "Accept the whole suggestion with:")
    private let acceptAllShortcutPopup = NSPopUpButton()
    private let shortcutAcceptAllLabel = NSTextField(labelWithString: "")

    // Live status detail (General)
    private let suggestionDecisionDetailLabel = NSTextField(labelWithString: "")

    // Privacy
    private let privacyLabel = NSTextField(labelWithString: "")
    private let localOnlyProofLabel = NSTextField(labelWithString: "")
    private let visiblePageContextStatusLabel = NSTextField(labelWithString: "")
    private let toggleVisiblePageContextButton = NSButton(
        checkboxWithTitle: "Use nearby on-screen text to improve suggestions",
        target: nil,
        action: nil
    )
    private let screenRecordingPermissionLabel = NSTextField(labelWithString: "")
    private let learningStatusLabel = NSTextField(labelWithString: "")
    private let clearLearningDataButton = NSButton(title: "Forget What I’ve Taught It", target: nil, action: nil)
    private let privacySharingStatusLabel = NSTextField(labelWithString: "")
    private let feedbackLabel = NSTextField(labelWithString: "")
    private let feedbackDetailLabel = NSTextField(labelWithString: "")
    private let diagnosticsStatusLabel = NSTextField(labelWithString: "")
    private let toggleTracingButton = NSButton(
        checkboxWithTitle: "Keep a local activity log to help with bug reports",
        target: nil,
        action: nil
    )
    private let exportPrivacyBundleButton = NSButton(title: "Export Diagnostic Report…", target: nil, action: nil)
    private let deleteLocalLogsButton = NSButton(title: "Delete Local Logs", target: nil, action: nil)

    // Advanced
    private let runtimeLabel = NSTextField(labelWithString: "")
    private let runtimeDetailLabel = NSTextField(labelWithString: "")
    private let runtimeActionLabel = NSTextField(labelWithString: "")
    private let runtimeActionButton = NSButton(title: "Open Model Folder", target: nil, action: nil)
    private let runtimeTargetLabel = NSTextField(labelWithString: "")
    private let modelDirectoryLabel = NSTextField(labelWithString: "")
    private let modelInstallStatusLabel = NSTextField(labelWithString: "")
    private let boringGuardrailLabel = NSTextField(labelWithString: "")
    private let resetTuningButton = NSButton(title: "Reset Fine-Tuning", target: nil, action: nil)
    private let maxWordsLabel = NSTextField(labelWithString: "")
    private let maxWordsDetailLabel = NSTextField(labelWithString: "")
    private let maxWordsSlider = NSSlider()
    private let wordStartLabel = NSTextField(labelWithString: "")
    private let wordStartDetailLabel = NSTextField(labelWithString: "")
    private let wordStartSlider = NSSlider()
    private let phraseStartLabel = NSTextField(labelWithString: "")
    private let phraseStartDetailLabel = NSTextField(labelWithString: "")
    private let phraseStartSlider = NSSlider()
    private let responseSpeedLabel = NSTextField(labelWithString: "")
    private let responseSpeedDetailLabel = NSTextField(labelWithString: "")
    private let responseSpeedSlider = NSSlider()
    private let confidenceLabel = NSTextField(labelWithString: "")
    private let confidenceDetailLabel = NSTextField(labelWithString: "")
    private let confidenceSlider = NSSlider()
    private let learningRestraintLabel = NSTextField(labelWithString: "")
    private let learningRestraintDetailLabel = NSTextField(labelWithString: "")
    private let learningRestraintSlider = NSSlider()
    private let placementDetailLabel = NSTextField(labelWithString: "")
    private let placementButton = NSButton(title: "Show in a Floating Box", target: nil, action: nil)
    private let advancedAccessibilityLabel = NSTextField(labelWithString: "")
    private let requestPermissionButton = NSButton(title: "Allow Accessibility", target: nil, action: nil)
    private let openAccessibilitySettingsButton = NSButton(title: "Open Privacy Settings", target: nil, action: nil)
    private let advancedDiagnosticsLabel = NSTextField(labelWithString: "")
    private let toggleRawTraceButton = NSButton(
        checkboxWithTitle: "Include exact text in logs (only if support asks)",
        target: nil,
        action: nil
    )
    private let toggleScreenshotTraceButton = NSButton(
        checkboxWithTitle: "Save placement screenshots",
        target: nil,
        action: nil
    )
    private let privacyPathLabel = NSTextField(labelWithString: "")

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
    private let startTextEditPractice: () -> Void
    private let enableAllApps: () -> Void
    private let toggleTracingPaused: () -> Void
    private let toggleRawContentTracing: () -> Void
    private let toggleScreenshotTracing: () -> Void
    private let toggleVisiblePageContext: () -> Void
    private let togglePersonalCapture: () -> Void
    private let revealPersonalCaptureFolder: () -> Void
    private let deletePersonalCapture: () -> Void
    private let deleteLocalLogs: () -> Void
    private let clearLearningData: () -> Void
    private let exportPrivacyBundle: () -> Void
    private let cycleAcceptAllShortcut: () -> Void
    private let setAcceptAllShortcut: (AcceptAllShortcut) -> Void
    private let setSuggestionAggressivenessLevel: (Int) -> Void
    private let setSuggestionMaxVisibleWords: (Int) -> Void
    private let setSuggestionWordStartCharacters: (Int) -> Void
    private let setSuggestionPhraseStartWords: (Int) -> Void
    private let setSuggestionResponseSpeedLevel: (Int) -> Void
    private let setSuggestionConfidenceLevel: (Int) -> Void
    private let setSuggestionLearningRestraintLevel: (Int) -> Void
    private let resetSuggestionTuning: () -> Void
    private let layoutStyle = SettingsLayoutStyle.nativeUtility
    private var currentRuntimeAction: RuntimeReadinessAction = .none
    private var currentPracticePrimaryAction: SettingsPracticePrimaryAction = .none

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
        startTextEditPractice: @escaping () -> Void = {},
        enableAllApps: @escaping () -> Void,
        toggleTracingPaused: @escaping () -> Void,
        toggleRawContentTracing: @escaping () -> Void,
        toggleScreenshotTracing: @escaping () -> Void,
        toggleVisiblePageContext: @escaping () -> Void,
        togglePersonalCapture: @escaping () -> Void = {},
        revealPersonalCaptureFolder: @escaping () -> Void = {},
        deletePersonalCapture: @escaping () -> Void = {},
        deleteLocalLogs: @escaping () -> Void,
        clearLearningData: @escaping () -> Void,
        exportPrivacyBundle: @escaping () -> Void = {},
        cycleAcceptAllShortcut: @escaping () -> Void,
        setAcceptAllShortcut: @escaping (AcceptAllShortcut) -> Void,
        setSuggestionAggressivenessLevel: @escaping (Int) -> Void,
        setSuggestionMaxVisibleWords: @escaping (Int) -> Void,
        setSuggestionWordStartCharacters: @escaping (Int) -> Void = { _ in },
        setSuggestionPhraseStartWords: @escaping (Int) -> Void = { _ in },
        setSuggestionResponseSpeedLevel: @escaping (Int) -> Void = { _ in },
        setSuggestionConfidenceLevel: @escaping (Int) -> Void = { _ in },
        setSuggestionLearningRestraintLevel: @escaping (Int) -> Void = { _ in },
        resetSuggestionTuning: @escaping () -> Void = {}
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
        self.startTextEditPractice = startTextEditPractice
        self.enableAllApps = enableAllApps
        self.toggleTracingPaused = toggleTracingPaused
        self.toggleRawContentTracing = toggleRawContentTracing
        self.toggleScreenshotTracing = toggleScreenshotTracing
        self.toggleVisiblePageContext = toggleVisiblePageContext
        self.togglePersonalCapture = togglePersonalCapture
        self.revealPersonalCaptureFolder = revealPersonalCaptureFolder
        self.deletePersonalCapture = deletePersonalCapture
        self.deleteLocalLogs = deleteLocalLogs
        self.clearLearningData = clearLearningData
        self.exportPrivacyBundle = exportPrivacyBundle
        self.cycleAcceptAllShortcut = cycleAcceptAllShortcut
        self.setAcceptAllShortcut = setAcceptAllShortcut
        self.setSuggestionAggressivenessLevel = setSuggestionAggressivenessLevel
        self.setSuggestionMaxVisibleWords = setSuggestionMaxVisibleWords
        self.setSuggestionWordStartCharacters = setSuggestionWordStartCharacters
        self.setSuggestionPhraseStartWords = setSuggestionPhraseStartWords
        self.setSuggestionResponseSpeedLevel = setSuggestionResponseSpeedLevel
        self.setSuggestionConfidenceLevel = setSuggestionConfidenceLevel
        self.setSuggestionLearningRestraintLevel = setSuggestionLearningRestraintLevel
        self.resetSuggestionTuning = resetSuggestionTuning

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
        window.title = "SteadyType Settings"
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

    /// Switches the visible tab. Exposed for visual QA snapshots of non-default tabs.
    func selectTab(at index: Int) {
        guard index >= 0, index < tabView.numberOfTabViewItems else {
            return
        }

        tabSelector.selectedSegment = index
        tabView.selectTabViewItem(at: index)
        if let view = tabView.selectedTabViewItem?.view {
            view.needsLayout = true
            view.layoutSubtreeIfNeeded()
        }
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
        let trust = SettingsTrustState(
            isTrusted: isTrusted,
            suggestionsPaused: suggestionsPaused,
            runtimeReport: runtimeReport,
            currentApp: currentApp,
            privacy: privacy,
            lastSuggestionDecision: lastSuggestionDecision
        )
        let pauseControl = ControlPauseState(
            isPaused: suggestionsPaused,
            pausedUntil: suggestionsPausedUntil,
            now: now
        )
        let suggestionDecision = SettingsSuggestionDecisionState(lastSuggestionDecision)
        let needsSetup = !isTrusted || !runtimeReport.allowsSuggestions

        // Status header.
        statusHeadlineLabel.stringValue = trust.statusText
        statusDetailLabel.stringValue = needsSetup
            ? SettingsOnboardingState(isTrusted: isTrusted, suggestionsPaused: suggestionsPaused, runtimeGuidance: guidance).text
            : suggestionDecision.detailText
        statusDot.update(color: statusDotColor(isTrusted: isTrusted, suggestionsPaused: suggestionsPaused, runtimeReport: runtimeReport))

        // Setup card (only while there is something to finish).
        firstRunTrustLabel.stringValue = firstRunTrust.statusText
        firstRunTrustDetailLabel.stringValue = firstRunTrust.detailText
        firstRunTrustQuickStartLabel.stringValue = firstRunTrust.quickStartText
        firstRunTrustAppsLabel.stringValue = firstRunTrust.appsText
        permissionLabel.stringValue = permission.statusText
        permissionDetailLabel.stringValue = permission.detailText
        practiceLabel.stringValue = practice.statusText
        practiceDetailLabel.stringValue = practice.detailText
        practiceStepsLabel.stringValue = practice.stepsText
        currentPracticePrimaryAction = practice.primaryAction
        practicePrimaryButton.title = practice.primaryButtonTitle
        practicePrimaryButton.isEnabled = practice.isPrimaryButtonEnabled
        practicePauseButton.title = practice.pauseButtonTitle
        practiceDeleteTracesButton.title = practice.deleteTracesButtonTitle
        setupSection?.isHidden = !needsSetup

        // Suggestions.
        controlDetailLabel.stringValue = pauseControl.settingsDetailText
        togglePauseButton.state = suggestionsPaused ? .off : .on
        pause15MinutesButton.isEnabled = pauseControl.shouldEnableTimedPauseButtons
        pause1HourButton.isEnabled = pauseControl.shouldEnableTimedPauseButtons
        pauseUntilTomorrowButton.isEnabled = pauseControl.shouldEnableTimedPauseButtons
        aggressivenessLabel.stringValue = suggestionAggressiveness.statusText
        aggressivenessDetailLabel.stringValue = suggestionAggressiveness.detailText
        aggressivenessSlider.doubleValue = suggestionAggressiveness.aggressivenessSliderValue
        suggestionDecisionDetailLabel.stringValue = suggestionDecision.detailText

        // This app.
        currentAppLabel.stringValue = currentApp.statusText
        currentAppDetailLabel.stringValue = currentApp.detailText
        toggleCurrentAppButton.title = currentApp.toggleTitle
        toggleCurrentAppButton.state = currentApp.isEnabled ? .on : .off
        toggleCurrentAppButton.isEnabled = currentApp.canToggle
        silenceFieldButton.title = fieldControl.buttonTitle
        silenceFieldButton.isEnabled = fieldControl.canSilence
        fieldControlDetailLabel.stringValue = fieldControl.detailText
        disabledAppsLabel.stringValue = currentApp.blockedAppsText
        enableAllAppsButton.isEnabled = currentApp.disabledAppCount > 0

        // Keyboard.
        shortcutLabel.stringValue = keyboardShortcuts.statusText
        acceptAllShortcutLabel.stringValue = keyboardShortcuts.acceptAllPickerLabel
        shortcutAcceptAllLabel.stringValue = keyboardShortcuts.acceptAllStatusText
        refreshAcceptAllShortcutPopup(selected: keyboardShortcuts.acceptAllShortcut)

        // Privacy.
        privacyLabel.stringValue = privacy.statusText
        localOnlyProofLabel.stringValue = privacy.localOnlyProofText
        visiblePageContextStatusLabel.stringValue = privacy.visiblePageContextStatusText
        toggleVisiblePageContextButton.state = privacy.visiblePageContextEnabled ? .on : .off
        let screenRecordingText = privacy.screenRecordingPermissionText
        screenRecordingPermissionLabel.stringValue = screenRecordingText ?? ""
        screenRecordingPermissionLabel.isHidden = screenRecordingText == nil
        learningStatusLabel.stringValue = privacy.learningStatusText
        privacySharingStatusLabel.stringValue = privacy.sharingStatusText
        let feedback = SettingsFeedbackState()
        feedbackLabel.stringValue = feedback.statusText
        feedbackDetailLabel.stringValue = feedback.detailText
        exportPrivacyBundleButton.title = feedback.buttonTitle
        diagnosticsStatusLabel.stringValue = privacy.diagnosticsStatusText
        toggleTracingButton.state = privacy.tracingPaused ? .off : .on

        // Advanced — model.
        runtimeLabel.stringValue = "On-device model: \(runtimeReport.summary)"
        let runtimePresentation = RuntimeReadinessPresentation(report: runtimeReport)
        runtimeDetailLabel.stringValue = runtimePresentation.settingsDetailText
        runtimeDetailLabel.isHidden = runtimePresentation.settingsDetailText.isEmpty
        if isModelInstallInProgress {
            runtimeActionLabel.stringValue = "Next step: wait for the model to finish, or cancel."
            runtimeActionButton.title = "Cancel Setup"
            runtimeActionButton.isEnabled = true
            currentRuntimeAction = .cancelModelInstall
        } else {
            runtimeActionLabel.stringValue = runtimeReport.action == .none
                ? "The model is ready."
                : "Next step: \(runtimeReport.action.displayName)"
            runtimeActionButton.title = guidance.actionTitle
            runtimeActionButton.isEnabled = guidance.isActionEnabled
            currentRuntimeAction = runtimeReport.action
        }
        runtimeTargetLabel.stringValue = "Runs locally: \(runtimeTargetSummary)"
        modelDirectoryLabel.stringValue = "Model folder: \(modelDirectoryPath)"
        modelInstallStatusLabel.stringValue = modelInstallStatusText ?? ""
        modelInstallStatusLabel.isHidden = modelInstallStatusText == nil

        // Advanced — fine-tuning.
        boringGuardrailLabel.stringValue = suggestionAggressiveness.boringGuardrailText
        maxWordsLabel.stringValue = suggestionAggressiveness.maxWordsText
        maxWordsDetailLabel.stringValue = suggestionAggressiveness.maxWordsDetailText
        maxWordsSlider.doubleValue = suggestionAggressiveness.maxWordsSliderValue
        wordStartLabel.stringValue = suggestionAggressiveness.wordStartText
        wordStartDetailLabel.stringValue = suggestionAggressiveness.wordStartDetailText
        wordStartSlider.doubleValue = suggestionAggressiveness.wordStartSliderValue
        phraseStartLabel.stringValue = suggestionAggressiveness.phraseStartText
        phraseStartDetailLabel.stringValue = suggestionAggressiveness.phraseStartDetailText
        phraseStartSlider.doubleValue = suggestionAggressiveness.phraseStartSliderValue
        responseSpeedLabel.stringValue = suggestionAggressiveness.responseSpeedText
        responseSpeedDetailLabel.stringValue = suggestionAggressiveness.responseSpeedDetailText
        responseSpeedSlider.doubleValue = suggestionAggressiveness.responseSpeedSliderValue
        confidenceLabel.stringValue = suggestionAggressiveness.confidenceText
        confidenceDetailLabel.stringValue = suggestionAggressiveness.confidenceDetailText
        confidenceSlider.doubleValue = suggestionAggressiveness.confidenceSliderValue
        learningRestraintLabel.stringValue = suggestionAggressiveness.learningRestraintText
        learningRestraintDetailLabel.stringValue = suggestionAggressiveness.learningRestraintDetailText
        learningRestraintSlider.doubleValue = suggestionAggressiveness.learningRestraintSliderValue

        // Advanced — placement.
        placementDetailLabel.stringValue = currentApp.canChangePlacement
            ? "Choose how suggestions appear in \(currentApp.displayName)."
            : "Open a supported writing app to choose how suggestions appear there."
        placementButton.title = currentApp.placementButtonTitle
        placementButton.isEnabled = currentApp.canChangePlacement

        // Advanced — setup + detailed diagnostics.
        advancedAccessibilityLabel.stringValue = permission.statusText
        requestPermissionButton.isEnabled = !isTrusted
        toggleRawTraceButton.state = privacy.rawContentTracingEnabled ? .on : .off
        toggleScreenshotTraceButton.state = privacy.screenshotTracingEnabled ? .on : .off
        privacyPathLabel.stringValue = privacy.pathText
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
        configureControls()

        let title = NSTextField(labelWithString: "SteadyType")
        title.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        tabSelector.target = self
        tabSelector.action = #selector(changeTab)
        tabSelector.translatesAutoresizingMaskIntoConstraints = false
        tabSelector.selectedSegment = 0

        let statusHeader = makeStatusHeader()

        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.tabViewType = .noTabsNoBorder
        tabView.drawsBackground = false
        tabView.addTabViewItem(makeTabItem(label: "General", view: makeGeneralTab()))
        tabView.addTabViewItem(makeTabItem(label: "Privacy", view: makePrivacyTab()))
        tabView.addTabViewItem(makeTabItem(label: "Advanced", view: makeAdvancedTab()))

        let headerStack = NSStackView(views: [title, tabSelector, statusHeader])
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 12
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.setHuggingPriority(.required, for: .vertical)

        contentView.addSubview(headerStack)
        contentView.addSubview(tabView)

        let insets = layoutStyle.contentInsets
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: insets.top),
            headerStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: insets.left),
            headerStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -insets.right),
            tabSelector.centerXAnchor.constraint(equalTo: headerStack.centerXAnchor),

            tabView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 14),
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func makeStatusHeader() -> NSView {
        statusHeadlineLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        statusDetailLabel.font = NSFont.systemFont(ofSize: 12)
        statusDetailLabel.textColor = .secondaryLabelColor
        statusDetailLabel.lineBreakMode = .byWordWrapping
        statusDetailLabel.maximumNumberOfLines = 2
        statusDetailLabel.preferredMaxLayoutWidth = layoutStyle.secondaryLabelMaxWidth

        let textStack = NSStackView(views: [statusHeadlineLabel, statusDetailLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        let row = NSStackView(views: [statusDot, textStack])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func statusDotColor(
        isTrusted: Bool,
        suggestionsPaused: Bool,
        runtimeReport: RuntimeReadinessReport
    ) -> NSColor {
        if !isTrusted || !runtimeReport.allowsSuggestions {
            return .systemOrange
        }

        if suggestionsPaused {
            return .systemGray
        }

        return .systemGreen
    }

    private func makeGeneralTab() -> NSView {
        setupCardStack.orientation = .vertical
        setupCardStack.alignment = .leading
        setupCardStack.spacing = layoutStyle.sectionItemSpacing
        [
            firstRunTrustLabel,
            firstRunTrustDetailLabel,
            permissionLabel,
            permissionDetailLabel,
            practiceLabel,
            practiceDetailLabel,
            practiceStepsLabel,
            makeButtonRow([practicePrimaryButton, practicePauseButton, practiceDeleteTracesButton]),
            firstRunTrustQuickStartLabel,
            firstRunTrustAppsLabel
        ].forEach { setupCardStack.addArrangedSubview($0) }

        let setup = makeSection(title: "Set Up", views: [setupCardStack])
        setupSection = setup

        let sections: [NSView] = [
            setup,
            makeSection(
                title: "Suggestions",
                views: [
                    togglePauseButton,
                    controlDetailLabel,
                    makeButtonRow([pause15MinutesButton, pause1HourButton, pauseUntilTomorrowButton]),
                    aggressivenessLabel,
                    aggressivenessSlider,
                    aggressivenessDetailLabel
                ]
            ),
            makeSection(
                title: "This App",
                views: [
                    currentAppLabel,
                    currentAppDetailLabel,
                    toggleCurrentAppButton,
                    makeButtonRow([silenceFieldButton]),
                    fieldControlDetailLabel,
                    makeButtonRow([disabledAppsLabel, enableAllAppsButton])
                ]
            ),
            makeSection(
                title: "Keyboard",
                views: [
                    shortcutLabel,
                    makeButtonRow([acceptAllShortcutLabel, acceptAllShortcutPopup]),
                    shortcutAcceptAllLabel
                ]
            )
        ]

        return makeScrollingStack(sections, primaryScroll: true)
    }

    private func makePrivacyTab() -> NSView {
        let sections: [NSView] = [
            makeSection(
                title: "On Your Mac",
                views: [
                    privacyLabel,
                    localOnlyProofLabel
                ]
            ),
            makeSection(
                title: "On-Screen Context",
                views: [
                    toggleVisiblePageContextButton,
                    visiblePageContextStatusLabel,
                    screenRecordingPermissionLabel
                ]
            ),
            makeSection(
                title: "Learning",
                views: [
                    learningStatusLabel,
                    makeButtonRow([clearLearningDataButton])
                ]
            ),
            makeSection(
                title: "Help Improve SteadyType",
                views: [
                    feedbackLabel,
                    feedbackDetailLabel,
                    privacySharingStatusLabel,
                    toggleTracingButton,
                    diagnosticsStatusLabel,
                    makeButtonRow([exportPrivacyBundleButton, deleteLocalLogsButton])
                ]
            )
        ]

        return makeScrollingStack(sections)
    }

    private func makeAdvancedTab() -> NSView {
        let sections: [NSView] = [
            makeSection(
                title: "Fine-Tuning",
                views: [
                    boringGuardrailLabel,
                    maxWordsLabel,
                    maxWordsSlider,
                    maxWordsDetailLabel,
                    responseSpeedLabel,
                    responseSpeedSlider,
                    responseSpeedDetailLabel,
                    confidenceLabel,
                    confidenceSlider,
                    confidenceDetailLabel,
                    wordStartLabel,
                    wordStartSlider,
                    wordStartDetailLabel,
                    phraseStartLabel,
                    phraseStartSlider,
                    phraseStartDetailLabel,
                    learningRestraintLabel,
                    learningRestraintSlider,
                    learningRestraintDetailLabel,
                    makeButtonRow([resetTuningButton])
                ]
            ),
            makeSection(
                title: "Placement",
                views: [
                    placementDetailLabel,
                    makeButtonRow([placementButton])
                ]
            ),
            makeSection(
                title: "On-Device Model",
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
                title: "Permissions",
                views: [
                    advancedAccessibilityLabel,
                    makeButtonRow([requestPermissionButton, openAccessibilitySettingsButton])
                ]
            ),
            makeSection(
                title: "Detailed Diagnostics",
                views: [
                    advancedDiagnosticsLabel,
                    toggleRawTraceButton,
                    toggleScreenshotTraceButton,
                    privacyPathLabel
                ]
            )
        ]

        advancedDiagnosticsLabel.stringValue = "Only turn these on if support asks. They stay on this Mac and are off by default."

        return makeScrollingStack(sections)
    }

    private func configureControls() {
        statusHeadlineLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)

        configureSecondaryLabel(firstRunTrustDetailLabel)
        firstRunTrustLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(firstRunTrustQuickStartLabel)
        configureSecondaryLabel(firstRunTrustAppsLabel)
        permissionLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(permissionDetailLabel)
        practiceLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(practiceDetailLabel)
        configureSecondaryLabel(practiceStepsLabel)

        configureSecondaryLabel(controlDetailLabel)
        aggressivenessLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(aggressivenessDetailLabel)
        configureSecondaryLabel(suggestionDecisionDetailLabel)

        currentAppLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(currentAppDetailLabel)
        configureSecondaryLabel(fieldControlDetailLabel)
        configureSecondaryLabel(disabledAppsLabel)

        shortcutLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        acceptAllShortcutLabel.font = NSFont.systemFont(ofSize: 12)
        acceptAllShortcutLabel.textColor = .secondaryLabelColor
        configureSecondaryLabel(shortcutAcceptAllLabel)

        privacyLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(localOnlyProofLabel)
        configureSecondaryLabel(visiblePageContextStatusLabel)
        configureSecondaryLabel(screenRecordingPermissionLabel)
        configureSecondaryLabel(learningStatusLabel)
        configureSecondaryLabel(privacySharingStatusLabel)
        feedbackLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(feedbackDetailLabel)
        configureSecondaryLabel(diagnosticsStatusLabel)

        runtimeLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        runtimeLabel.lineBreakMode = .byWordWrapping
        runtimeLabel.maximumNumberOfLines = 0
        runtimeLabel.preferredMaxLayoutWidth = layoutStyle.secondaryLabelMaxWidth
        configureSecondaryLabel(runtimeDetailLabel)
        runtimeActionLabel.font = NSFont.systemFont(ofSize: 12)
        runtimeActionLabel.textColor = .secondaryLabelColor
        configureSecondaryLabel(runtimeTargetLabel)
        modelDirectoryLabel.lineBreakMode = .byTruncatingMiddle
        modelDirectoryLabel.maximumNumberOfLines = 1
        modelDirectoryLabel.font = NSFont.systemFont(ofSize: 11)
        modelDirectoryLabel.textColor = .secondaryLabelColor
        modelDirectoryLabel.preferredMaxLayoutWidth = layoutStyle.secondaryLabelMaxWidth
        configureSecondaryLabel(modelInstallStatusLabel)

        configureSecondaryLabel(boringGuardrailLabel)
        maxWordsLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(maxWordsDetailLabel)
        wordStartLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(wordStartDetailLabel)
        phraseStartLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(phraseStartDetailLabel)
        responseSpeedLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(responseSpeedDetailLabel)
        confidenceLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(confidenceDetailLabel)
        learningRestraintLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        configureSecondaryLabel(learningRestraintDetailLabel)
        configureSecondaryLabel(placementDetailLabel)
        configureSecondaryLabel(advancedAccessibilityLabel)
        configureSecondaryLabel(advancedDiagnosticsLabel)
        privacyPathLabel.font = NSFont.systemFont(ofSize: 11)
        privacyPathLabel.textColor = .secondaryLabelColor
        privacyPathLabel.lineBreakMode = .byTruncatingMiddle
        privacyPathLabel.maximumNumberOfLines = 1
        privacyPathLabel.preferredMaxLayoutWidth = layoutStyle.secondaryLabelMaxWidth

        configureButton(practicePrimaryButton, #selector(runPracticePrimaryAction))
        configureButton(practicePauseButton, #selector(runPracticePauseAction))
        configureButton(practiceDeleteTracesButton, #selector(runPracticeDeleteTracesAction))

        togglePauseButton.target = self
        togglePauseButton.action = #selector(togglePause)
        togglePauseButton.toolTip = "Turns suggestions on or off right away."
        configureButton(pause15MinutesButton, #selector(pauseFor15MinutesControl))
        configureButton(pause1HourButton, #selector(pauseFor1HourControl))
        configureButton(pauseUntilTomorrowButton, #selector(pauseUntilTomorrowControl))
        pauseUntilTomorrowButton.toolTip = "Pauses suggestions everywhere until tomorrow."

        toggleCurrentAppButton.target = self
        toggleCurrentAppButton.action = #selector(toggleCurrentAppControl)
        toggleCurrentAppButton.toolTip = "Pauses or resumes suggestions in the app you’re using now."
        configureButton(silenceFieldButton, #selector(silenceFieldControl))
        silenceFieldButton.toolTip = "Stops suggestions only in this field until you move on."
        configureButton(enableAllAppsButton, #selector(enableAllAppsControl))
        enableAllAppsButton.toolTip = "Resumes every app you paused in SteadyType."

        acceptAllShortcutPopup.target = self
        acceptAllShortcutPopup.action = #selector(selectAcceptAllShortcutControl)

        toggleVisiblePageContextButton.target = self
        toggleVisiblePageContextButton.action = #selector(toggleVisiblePageContextControl)
        toggleVisiblePageContextButton.toolTip = "Reads nearby on-screen text on your Mac to make suggestions fit better."
        configureButton(clearLearningDataButton, #selector(clearLearningDataControl))
        toggleTracingButton.target = self
        toggleTracingButton.action = #selector(toggleTracingControl)
        toggleTracingButton.toolTip = "Keeps a local activity log. It never includes your text."
        configureButton(exportPrivacyBundleButton, #selector(exportPrivacyBundleControl))
        configureButton(deleteLocalLogsButton, #selector(deleteLocalLogsControl))

        configureButton(runtimeActionButton, #selector(runRuntimeAction))
        configureButton(resetTuningButton, #selector(resetTuningControl))
        configureButton(placementButton, #selector(toggleCurrentAppMirrorModeControl))
        placementButton.toolTip = "Switch between inline ghost text and a small floating box for this app."
        configureButton(requestPermissionButton, #selector(requestAccessibility))
        configureButton(openAccessibilitySettingsButton, #selector(openAccessibilitySettingsPane))
        toggleRawTraceButton.target = self
        toggleRawTraceButton.action = #selector(toggleRawTraceControl)
        toggleRawTraceButton.toolTip = "Off by default. Turn on only when support asks for a log that includes your exact text."
        toggleScreenshotTraceButton.target = self
        toggleScreenshotTraceButton.action = #selector(toggleScreenshotTraceControl)
        toggleScreenshotTraceButton.toolTip = "Saves local screenshots to check where suggestions appear."

        configureSlider(
            aggressivenessSlider,
            minimumValue: SuggestionTuning.minimumAggressivenessLevel,
            maximumValue: SuggestionTuning.maximumAggressivenessLevel,
            action: #selector(changeAggressivenessSlider)
        )
        aggressivenessSlider.toolTip = "How quickly and how often suggestions appear."
        configureSlider(
            maxWordsSlider,
            minimumValue: CompletionModelPolicy.minimumVisibleWords,
            maximumValue: CompletionModelPolicy.maximumVisibleWords,
            action: #selector(changeMaxWordsSlider)
        )
        maxWordsSlider.toolTip = "The longest suggestion SteadyType will show."
        configureSlider(
            wordStartSlider,
            minimumValue: SuggestionTuning.minimumWordStartCharacters,
            maximumValue: SuggestionTuning.maximumWordStartCharacters,
            action: #selector(changeWordStartSlider)
        )
        wordStartSlider.toolTip = "How many letters you type before word hints appear."
        configureSlider(
            phraseStartSlider,
            minimumValue: SuggestionTuning.minimumPhraseStartWords,
            maximumValue: SuggestionTuning.maximumPhraseStartWords,
            action: #selector(changePhraseStartSlider)
        )
        phraseStartSlider.toolTip = "How many words you type before phrase hints appear."
        configureSlider(
            responseSpeedSlider,
            minimumValue: SuggestionTuning.minimumResponseSpeedLevel,
            maximumValue: SuggestionTuning.maximumResponseSpeedLevel,
            action: #selector(changeResponseSpeedSlider)
        )
        responseSpeedSlider.toolTip = "How long SteadyType waits after you stop typing."
        configureSlider(
            confidenceSlider,
            minimumValue: SuggestionTuning.minimumConfidenceLevel,
            maximumValue: SuggestionTuning.maximumConfidenceLevel,
            action: #selector(changeConfidenceSlider)
        )
        confidenceSlider.toolTip = "How sure a guess must be before it appears."
        configureSlider(
            learningRestraintSlider,
            minimumValue: SuggestionTuning.minimumLearningRestraintLevel,
            maximumValue: SuggestionTuning.maximumLearningRestraintLevel,
            action: #selector(changeLearningRestraintSlider)
        )
        learningRestraintSlider.toolTip = "How much your past choices hide future suggestions."
    }

    private func makeScrollingStack(_ sections: [NSView], primaryScroll: Bool = false) -> NSView {
        let stack = NSStackView(views: sections)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = layoutStyle.sectionSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView: NSScrollView
        let documentView: NSView
        if primaryScroll {
            scrollView = contentScrollView
            documentView = scrollDocumentView
        } else {
            scrollView = NSScrollView()
            documentView = FlippedSettingsDocumentView()
        }
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.verticalScrollElasticity = .allowed
        scrollView.horizontalScrollElasticity = .none

        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView
        documentView.addSubview(stack)

        let insets = layoutStyle.contentInsets
        NSLayoutConstraint.activate([
            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            documentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.heightAnchor),

            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: insets.left),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -insets.right),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -insets.bottom)
        ])

        return scrollView
    }

    private func makeTabItem(label: String, view: NSView) -> NSTabViewItem {
        let item = NSTabViewItem(identifier: label)
        item.label = label
        // NSTabView sizes its item views with the autoresizing mask, so the container must
        // be frame-driven; the scroll view inside it then resolves with Auto Layout.
        let container = NSView(frame: NSRect(origin: .zero, size: layoutStyle.preferredContentSize))
        container.autoresizingMask = [.width, .height]
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        item.view = container
        return item
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

    private func configureButton(_ button: NSButton, _ action: Selector) {
        button.target = self
        button.action = action
        button.bezelStyle = .rounded
    }

    private func makeSection(title: String, views: [NSView]) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title.uppercased())
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
    private func changeTab() {
        let index = max(0, min(tabSelector.selectedSegment, tabView.numberOfTabViewItems - 1))
        tabView.selectTabViewItem(at: index)
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
    private func resetTuningControl() {
        resetSuggestionTuning()
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

    @objc
    private func changeWordStartSlider() {
        setSuggestionWordStartCharacters(wordStartSlider.integerValue)
    }

    @objc
    private func changePhraseStartSlider() {
        setSuggestionPhraseStartWords(phraseStartSlider.integerValue)
    }

    @objc
    private func changeResponseSpeedSlider() {
        setSuggestionResponseSpeedLevel(responseSpeedSlider.integerValue)
    }

    @objc
    private func changeConfidenceSlider() {
        setSuggestionConfidenceLevel(confidenceSlider.integerValue)
    }

    @objc
    private func changeLearningRestraintSlider() {
        setSuggestionLearningRestraintLevel(learningRestraintSlider.integerValue)
    }
}
