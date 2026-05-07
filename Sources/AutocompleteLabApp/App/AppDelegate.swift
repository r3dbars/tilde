import AppKit
import AutocompleteLabCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let accessibilityClient = AccessibilityClient()
    private let profileStore = CompatibilityProfileStore.mvp
    private let activationPolicy = CompletionActivationPolicy()
    private let triggerPolicy = SuggestionTriggerPolicy(
        charactersBeforePauseRequest: 1,
        wordCompletionDelayMilliseconds: 0,
        wordBoundaryDelayMilliseconds: 0,
        pauseDelayMilliseconds: 15
    )
    private let modelRuntimeBundle = AppModelRuntimeFactory.makeRuntime()
    private var completionLengthConfiguration: CompletionLengthConfiguration {
        modelRuntimeBundle.lengthConfiguration
    }
    private var modelRuntime: any ModelRuntime {
        modelRuntimeBundle.runtime
    }
    private lazy var engine: any CompletionEngine = RuntimeBackedCompletionEngine(runtime: modelRuntime)
    private lazy var insertionEngine = InsertionEngine(accessibilityClient: accessibilityClient)
    private let keyboardRouter = KeyboardActionRouter()
    private let keyboardCapturePolicy = KeyboardCapturePolicy()
    private let insertionVerification = InsertionVerification()
    private let insertionRetryPolicy = InsertionRetryPolicy()
    private let acceptanceSurvivalClassifier = AcceptanceSurvivalClassifier()
    private let wordCompletionRanker = WordCompletionCandidateRanker()
    private let recentWordExtractor = RecentWordExtractor()
    private let compatibilityLearningStore = CompatibilityLearningStore.shared
    private let suggestionPanel = SuggestionPanelController()
    private let diagnosticsWindow = DiagnosticsWindowController()
    private lazy var settingsWindow = SettingsWindowController(
        requestPermission: { [weak self] in
            self?.requestAccessibilityPermission()
        },
        openAccessibilitySettings: { [weak self] in
            self?.openAccessibilitySettings()
        }
    )

    private var statusItem: NSStatusItem?
    private var statusMenuItem: NSMenuItem?
    private var runtimeMenuItem: NSMenuItem?
    private var toggleAppMenuItem: NSMenuItem?
    private var pollTimer: Timer?
    private var keyboardEventTap: KeyboardEventTap?
    private var suggestionSession = SuggestionSession()
    private var lastCaretRect: CGRect?
    private var lastTextLineRect: CGRect?
    private var lastClippingRect: CGRect?
    private var lastTextStyle: FocusedTextStyle?
    private var lastRenderMode: SuggestionRenderMode?
    private var currentFieldIdentity: FocusedFieldIdentity?
    private var currentProfile: CompatibilityProfile?
    private var lastTextSnapshot: FocusedTextSnapshot?
    private var lastRequestedTextBeforeCursor: String?
    private var suppressedFieldIdentities: Set<FocusedFieldIdentity> = []
    private var disabledBundleIdentifiers: Set<String> = []
    private var debounceTask: Task<Void, Never>?
    private var insertionVerificationTask: Task<Void, Never>?
    private var acceptanceSurvivalTasks: [String: Task<Void, Never>] = [:]
    private var acceptanceSurvivalTrackers: [String: AcceptanceSurvivalTracker] = [:]
    private var runtimeWarmTask: Task<Void, Never>?
    private var suggestionRequestGate = SuggestionRequestGate()
    private var suggestionBlockLogGate = SuggestionBlockLogGate()
    private var suggestionRepetitionSuppressor = SuggestionRepetitionSuppressor()
    private var currentCompletionRequest: CompletionRequest?
    private var currentSuggestionID: String?
    private var currentSuggestionRequestMode: CompletionRequestMode?
    private var currentSuggestionTextBeforeCursor: String?
    private var currentSuggestionDisplayedText: String?
    private var recentAcceptedWords: [String] = []
    private var suppressKeyUntil: [AutocompleteKey: Date] = [:]
    private var lastStatusLine: String?
    private var lastSyntheticCaretDiagnosticSignature: String?
    private var currentRuntimeState: LocalRuntimeState = .unavailable(reason: "starting")

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("AutocompleteLab runs as a persistent menu bar agent.")
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        loadDisabledApps()
        DiagnosticsLog.shared.record("launch", metadata: ["accessibility": String(accessibilityClient.isTrusted)])
        DiagnosticsLog.shared.record("runtime-bootstrap", metadata: modelRuntimeBundle.diagnosticsMetadata)
        accessibilityClient.requestPermissionIfNeeded()
        warmModelRuntime()
        if !accessibilityClient.isTrusted {
            settingsWindow.show(
                isTrusted: false,
                runtimeReport: runtimeReadinessReport,
                runtimeTargetSummary: runtimeTargetSummary,
                modelDirectoryPath: modelDirectoryPath
            )
        }
        startPolling()
    }

    func applicationWillTerminate(_ notification: Notification) {
        DiagnosticsLog.shared.record("terminate")
        debounceTask?.cancel()
        insertionVerificationTask?.cancel()
        cancelAcceptanceSurvivalTracking()
        runtimeWarmTask?.cancel()
        invalidatePendingSuggestionRequest()
        modelRuntime.cancel()
        pollTimer?.invalidate()
        stopKeyboardEventTapIfActive()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Autocomplete"

        let menu = NSMenu()
        let statusMenu = NSMenuItem(title: "Status: starting", action: nil, keyEquivalent: "")
        let runtimeMenu = NSMenuItem(title: "Model: starting", action: nil, keyEquivalent: "")
        let toggleItem = NSMenuItem(title: "Toggle Current App", action: #selector(toggleCurrentApp), keyEquivalent: "t")

        menu.addItem(NSMenuItem(title: "Transcripted Autocomplete Lab", action: nil, keyEquivalent: ""))
        menu.addItem(statusMenu)
        menu.addItem(runtimeMenu)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Show Diagnostics", action: #selector(showDiagnostics), keyEquivalent: "d"))
        menu.addItem(NSMenuItem(title: "Reveal Model Folder", action: #selector(revealModelFolder), keyEquivalent: "m"))
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Nudge Suggestion Up", action: #selector(nudgeCurrentAppSuggestionUp), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Nudge Suggestion Down", action: #selector(nudgeCurrentAppSuggestionDown), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Nudge Suggestion Left", action: #selector(nudgeCurrentAppSuggestionLeft), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Nudge Suggestion Right", action: #selector(nudgeCurrentAppSuggestionRight), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Reset Current App Learning", action: #selector(resetCurrentAppLearning), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Request Accessibility Permission", action: #selector(requestAccessibilityPermission), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
        statusMenuItem = statusMenu
        runtimeMenuItem = runtimeMenu
        toggleAppMenuItem = toggleItem
        refreshRuntimeChrome()
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollFocusedText()
            }
        }
    }

    private func warmModelRuntime() {
        let candidate = modelRuntimeBundle.activeCandidate
        let runtime = modelRuntime

        applyRuntimeState(.warming(candidate: candidate))
        DiagnosticsLog.shared.record(
            "runtime-warm-start",
            metadata: [
                "candidate": candidate.rawValue,
                "modelDirectory": modelRuntimeBundle.modelDirectoryURL.path
            ]
        )

        runtimeWarmTask?.cancel()
        runtimeWarmTask = Task { [weak self, runtime, candidate] in
            do {
                try await runtime.warm()
            } catch {
                await MainActor.run {
                    DiagnosticsLog.shared.record(
                        "runtime-warm-failed",
                        metadata: [
                            "candidate": candidate.rawValue,
                            "reason": error.localizedDescription
                        ]
                    )
                    self?.applyRuntimeState(.failed(candidate: candidate, reason: error.localizedDescription))
                }
                return
            }

            let state = await runtime.state
            await MainActor.run {
                DiagnosticsLog.shared.record(
                    "runtime-warm-succeeded",
                    metadata: [
                        "candidate": candidate.rawValue,
                        "state": state.statusSummary
                    ]
                )
                self?.applyRuntimeState(state)
            }
        }
    }

    private func applyRuntimeState(_ state: LocalRuntimeState) {
        currentRuntimeState = state
        refreshRuntimeChrome()
        let report = runtimeReadinessReport
        DiagnosticsLog.shared.record(
            "runtime",
            metadata: [
                "state": state.statusSummary,
                "completionLength": completionLengthConfiguration.displaySummary,
                "readinessStage": report.stage.rawValue,
                "readinessAction": report.action.rawValue
            ]
        )
    }

    private func refreshRuntimeChrome() {
        runtimeMenuItem?.title = "Model: \(modelRuntimeBundle.bootstrapPlan.preferredAsset.model.rawValue) • \(runtimeReadinessReport.summary) • \(completionLengthConfiguration.displaySummary)"
        settingsWindow.refresh(
            isTrusted: accessibilityClient.isTrusted,
            runtimeReport: runtimeReadinessReport,
            runtimeTargetSummary: runtimeTargetSummary,
            modelDirectoryPath: modelDirectoryPath
        )
    }

    private var runtimeReadinessReport: RuntimeReadinessReport {
        modelRuntimeBundle.bootstrapPlan.readinessReport(for: currentRuntimeState)
    }

    private var modelDirectoryPath: String {
        modelRuntimeBundle.modelDirectoryURL.path
    }

    private var runtimeTargetSummary: String {
        "\(modelRuntimeBundle.bootstrapPlan.preferredAsset.model.rawValue) • \(completionLengthConfiguration.displaySummary)"
    }

    private func pollFocusedText() {
        guard accessibilityClient.isTrusted else {
            updateStatusMenu(app: nil, profile: nil, appEnabled: false)
            hideSuggestion()
            return
        }

        guard let frontmostApp = accessibilityClient.frontmostApplication(),
              let profile = profileStore.profile(for: frontmostApp.bundleIdentifier) else {
            clearFocusedFieldState()
            currentProfile = nil
            updateStatusMenu(app: accessibilityClient.frontmostApplication(), profile: nil, appEnabled: false)
            hideSuggestion()
            return
        }

        let appEnabled = !disabledBundleIdentifiers.contains(frontmostApp.bundleIdentifier)
        currentProfile = profile
        updateStatusMenu(app: frontmostApp, profile: profile, appEnabled: appEnabled)

        guard appEnabled else {
            clearFocusedFieldState()
            hideSuggestion()
            return
        }

        guard let rawContext = accessibilityClient.focusedTextContext(
            allowDescendantTextFallback: profile.allowsDescendantTextFallback
        ), !rawContext.isSecure else {
            clearFocusedFieldState()
            currentProfile = profile
            hideSuggestion()
            return
        }
        let context = presentationAdjustedContext(rawContext, app: frontmostApp, profile: profile)

        let fieldIdentity = fieldIdentity(
            app: frontmostApp,
            context: context,
            profile: profile
        )
        transitionToField(fieldIdentity)

        let snapshot = FocusedTextSnapshot(
            fieldIdentity: fieldIdentity,
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor
        )

        guard snapshot != lastTextSnapshot else {
            repositionVisibleSuggestion(context: context, profile: profile)
            return
        }

        recordTypedOverSuggestionIfNeeded(
            newTextBeforeCursor: context.textBeforeCursor,
            fieldIdentity: fieldIdentity,
            profile: profile
        )
        rememberTypedWordsIfNeeded(
            previousSnapshot: lastTextSnapshot,
            currentSnapshot: snapshot
        )
        hideStaleSuggestionIfNeeded(
            newTextBeforeCursor: context.textBeforeCursor,
            fieldIdentity: fieldIdentity
        )

        lastTextSnapshot = snapshot
        invalidatePendingSuggestionRequest()

        guard profile.canPresentSuggestions else {
            recordBlockedSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                metadata: [
                    "reason": "profile-diagnostics-only"
                ]
            )
            hideSuggestion()
            return
        }

        let runtimeReport = runtimeReadinessReport
        guard runtimeReport.allowsSuggestions else {
            recordBlockedSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                metadata: [
                    "reason": "runtime-not-ready",
                    "readinessStage": runtimeReport.stage.rawValue
                ]
            )
            hideSuggestion()
            return
        }

        let activationDecision = activationPolicy.decision(
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            isSecure: context.isSecure,
            isFieldSuppressed: suppressedFieldIdentities.contains(fieldIdentity)
        )

        guard activationDecision.canSuggest else {
            recordBlockedSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                metadata: [
                    "reason": activationDecision.blockReasonDescription
                ]
            )
            hideSuggestion()
            return
        }

        let baseRenderMode = RenderModePlan.effectiveMode(
            for: profile,
            supportsInlineSuggestions: context.capabilities.supportsInlineSuggestions,
            hasMirrorAnchor: context.elementRect != nil || context.windowRect != nil
        )

        guard let baseRenderMode else {
            recordBlockedSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                metadata: [
                    "reason": "missing-inline-capabilities"
                ]
            )
            hideSuggestion()
            return
        }
        let renderMode = compatibilityLearningStore.engine()
            .adjustment(for: profile.bundleIdentifier, profileRenderMode: baseRenderMode)
            .effectiveRenderMode

        if shouldSuppressDetachedSuggestion(
            profile: profile,
            context: context,
            renderMode: renderMode
        ) {
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: UUID().uuidString,
                appBundleIdentifier: profile.bundleIdentifier,
                fieldIdentity: fieldIdentity.traceDescription,
                requestMode: (activationDecision.requestMode ?? .phraseContinuation).rawValue,
                triggerReason: "policy",
                textBeforeCursor: context.textBeforeCursor,
                textAfterCursor: context.textAfterCursor,
                reason: "detached-suggestion-disabled",
                metadata: traceGeometryMetadata(context: context, renderMode: renderMode)
            )
            recordBlockedSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                fieldIdentity: fieldIdentity,
                metadata: [
                    "reason": "detached-suggestion-disabled"
                ]
            )
            hideSuggestion()
            return
        }

        let triggerDecision = triggerPolicy.decision(
            previousTextBeforeCursor: lastRequestedTextBeforeCursor,
            currentTextBeforeCursor: context.textBeforeCursor
        )

        guard case let .request(delayMilliseconds) = triggerDecision else {
            recordSuggestionEvent(
                "suggestion-trigger-skipped",
                context: context,
                profile: profile,
                metadata: [
                    "reason": "cadence-policy"
                ]
            )
            hideSuggestion()
            return
        }

        scheduleSuggestion(
            context: context,
            profile: profile,
            appBundleIdentifier: frontmostApp.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            renderMode: renderMode,
            delayMilliseconds: delayMilliseconds,
            requestMode: activationDecision.requestMode ?? .phraseContinuation
        )
    }

    private func shouldSuppressDetachedSuggestion(
        profile: CompatibilityProfile,
        context: FocusedTextContext,
        renderMode: SuggestionRenderMode
    ) -> Bool {
        renderMode == .floatingMirror
            && context.caretRect == nil
            && !profile.allowsDetachedSuggestions
    }

    private func presentationAdjustedContext(
        _ context: FocusedTextContext,
        app: RunningApplicationInfo,
        profile: CompatibilityProfile
    ) -> FocusedTextContext {
        guard app.bundleIdentifier == "com.openai.codex",
              context.caretRect == nil,
              let syntheticCaret = codexSyntheticCaretRect(for: context) else {
            return context
        }

        let capabilities = FocusedTextCapabilities(
            canReadValue: context.capabilities.canReadValue,
            canReadSelectedTextRange: context.capabilities.canReadSelectedTextRange,
            canReadBoundsForRange: true,
            canReadAttributedText: context.capabilities.canReadAttributedText,
            canSetSelectedText: context.capabilities.canSetSelectedText
        )

        recordSyntheticCaretIfNeeded(syntheticCaret, context: context, profile: profile)

        return FocusedTextContext(
            elementIdentifier: context.elementIdentifier,
            role: context.role,
            subrole: context.subrole,
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            caretRect: syntheticCaret,
            elementRect: context.elementRect,
            windowRect: context.windowRect,
            textLineRect: syntheticCaret,
            textStyle: context.textStyle,
            isSecure: context.isSecure,
            capabilities: capabilities
        )
    }

    private func codexSyntheticCaretRect(for context: FocusedTextContext) -> CGRect? {
        guard context.role == "AXTextArea",
              let elementRect = context.elementRect,
              elementRect.width > 80,
              elementRect.height > 20 else {
            return nil
        }

        let font = context.textStyle?.font ?? NSFont.systemFont(ofSize: 18)
        let lineHeight = max(font.ascender - font.descender + font.leading, 20)
        let horizontalPadding: CGFloat = 18
        let verticalPadding: CGFloat = 4
        let codexVisualBaselineLift = lineHeight * 0.85
        let maxLineWidth = max(40, elementRect.width - (horizontalPadding * 2))
        let visualLines = wrappedVisualLines(
            for: context.textBeforeCursor,
            font: font,
            maxLineWidth: maxLineWidth
        )
        let currentLine = visualLines.last ?? ""
        let lineIndex = max(0, visualLines.count - 1)
        let currentLineWidth = min(width(of: currentLine, font: font), maxLineWidth)
        let caretHeight = max(lineHeight, 16)
        let inlineGap: CGFloat = 8
        let inlineVerticalDrop = lineHeight * 0.85
        let preferredY = elementRect.minY
            + verticalPadding
            - codexVisualBaselineLift
            + inlineVerticalDrop
            + (CGFloat(lineIndex) * lineHeight)
        let y = clampedCodexCaretY(
            preferredY,
            caretHeight: caretHeight,
            elementRect: elementRect,
            windowRect: context.windowRect
        )

        return CGRect(
            x: min(
                elementRect.minX + horizontalPadding + currentLineWidth + inlineGap,
                elementRect.maxX - horizontalPadding
            ),
            y: y,
            width: 0,
            height: caretHeight
        )
    }

    private func clampedCodexCaretY(
        _ preferredY: CGFloat,
        caretHeight: CGFloat,
        elementRect: CGRect,
        windowRect: CGRect?
    ) -> CGFloat {
        let boundingRect = windowRect ?? elementRect
        let upperPadding: CGFloat = 8
        let lowerPadding: CGFloat = 8
        let minY = min(elementRect.minY - (caretHeight * 1.25), boundingRect.maxY - caretHeight - lowerPadding)
        let maxY = max(elementRect.maxY + (caretHeight * 6), minY)
        let boundedMinY = max(boundingRect.minY + upperPadding, minY)
        let boundedMaxY = min(boundingRect.maxY - caretHeight - lowerPadding, maxY)

        guard boundedMaxY >= boundedMinY else {
            return preferredY
        }

        return min(max(preferredY, boundedMinY), boundedMaxY)
    }

    private func wrappedVisualLines(for text: String, font: NSFont, maxLineWidth: CGFloat) -> [String] {
        var lines: [String] = []

        for paragraph in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            var current = ""

            for character in paragraph {
                let next = current + String(character)
                if !current.isEmpty, width(of: next, font: font) > maxLineWidth {
                    lines.append(current)
                    current = String(character)
                } else {
                    current = next
                }
            }

            lines.append(current)
        }

        return lines.isEmpty ? [""] : lines
    }

    private func width(of text: String, font: NSFont) -> CGFloat {
        text.size(withAttributes: [.font: font]).width
    }

    private func compactRectDescription(_ rect: CGRect) -> String {
        "x=\(Int(rect.origin.x.rounded())),y=\(Int(rect.origin.y.rounded())),w=\(Int(rect.width.rounded())),h=\(Int(rect.height.rounded()))"
    }

    private func recordSyntheticCaretIfNeeded(
        _ caret: CGRect,
        context: FocusedTextContext,
        profile: CompatibilityProfile
    ) {
        let signature = [
            profile.bundleIdentifier,
            String(context.textBeforeCursor.count),
            compactRectDescription(caret)
        ].joined(separator: "|")

        guard signature != lastSyntheticCaretDiagnosticSignature else {
            return
        }

        lastSyntheticCaretDiagnosticSignature = signature
        DiagnosticsLog.shared.record(
            "synthetic-caret",
            metadata: [
                "app": profile.bundleIdentifier,
                "source": "codex-textarea-estimate",
                "caret": compactRectDescription(caret),
                "beforeChars": String(context.textBeforeCursor.count)
            ]
        )
    }

    private func startKeyboardEventTapIfPossible() {
        guard keyboardCapturePolicy.shouldCaptureKeys(
            isTrustedForAccessibility: accessibilityClient.isTrusted,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion
        ), keyboardEventTap == nil else {
            return
        }

        let eventTap = KeyboardEventTap { [weak self] key in
            var handled = false

            if Thread.isMainThread {
                handled = MainActor.assumeIsolated {
                    self?.handleAutocompleteKey(key) ?? false
                }
            } else {
                DispatchQueue.main.sync {
                    handled = MainActor.assumeIsolated {
                        self?.handleAutocompleteKey(key) ?? false
                    }
                }
            }

            return handled
        }

        if eventTap.start() {
            keyboardEventTap = eventTap
            DiagnosticsLog.shared.record("keyboard-event-tap-started")
        }
    }

    private func stopKeyboardEventTapIfActive() {
        guard let keyboardEventTap else {
            return
        }

        keyboardEventTap.stop()
        self.keyboardEventTap = nil
        DiagnosticsLog.shared.record("keyboard-event-tap-stopped")
    }

    private func handleAutocompleteKey(_ key: AutocompleteKey) -> Bool {
        if shouldSuppressKey(key) {
            recordKeyboardAction(key: key, action: .passThrough, handled: true, reason: "suppressed-repeat")
            return true
        }

        let action = keyboardRouter.action(
            for: key,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion
        )

        switch action {
        case .acceptNextWord:
            guard currentProfile?.supportsOneWordAcceptance == true else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "unsupported-one-word")
                return false
            }

            let verificationBaseline = insertionVerificationBaseline()
            guard let acceptedText = suggestionSession.nextWordAcceptance(),
                  insertAcceptedText(acceptedText) else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "insert-failed")
                return false
            }

            suggestionSession.commitNextWordAcceptance(acceptedText)
            recordAcceptedText(acceptedText)
            suggestionRepetitionSuppressor.recordAcceptance(
                acceptedText,
                mode: currentSuggestionRequestMode,
                scope: currentProfile?.bundleIdentifier ?? ""
            )
            let acceptanceID = recordRawAcceptance(action: action, acceptedText: acceptedText)
            if suggestionSession.hasVisibleSuggestion {
                refreshVisibleSuggestion()
            } else {
                hideSuggestion(reason: "accepted-next-word-final")
            }
            scheduleInsertionVerification(
                acceptedText: acceptedText,
                acceptanceID: acceptanceID,
                baseline: verificationBaseline
            )
            suppressKey(key)
            recordKeyboardAction(key: key, action: action, handled: true, reason: "accepted")
            return true

        case .acceptAllVisible:
            guard currentProfile?.supportsFullAcceptance == true else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "unsupported-full")
                return false
            }

            let verificationBaseline = insertionVerificationBaseline()
            guard let acceptedText = suggestionSession.allVisibleAcceptance(),
                  insertAcceptedText(acceptedText) else {
                recordKeyboardAction(key: key, action: action, handled: false, reason: "insert-failed")
                return false
            }

            suggestionSession.commitAllVisibleAcceptance(acceptedText)
            recordAcceptedText(acceptedText)
            suggestionRepetitionSuppressor.recordAcceptance(
                acceptedText,
                mode: currentSuggestionRequestMode,
                scope: currentProfile?.bundleIdentifier ?? ""
            )
            let acceptanceID = recordRawAcceptance(action: action, acceptedText: acceptedText)
            hideSuggestion(reason: "accepted-all")
            scheduleInsertionVerification(
                acceptedText: acceptedText,
                acceptanceID: acceptanceID,
                baseline: verificationBaseline
            )
            suppressKey(key)
            recordKeyboardAction(key: key, action: action, handled: true, reason: "accepted")
            return true

        case .dismiss:
            suppressCurrentField(reason: "escape")
            hideSuggestion(reason: "escape")
            suppressKey(key)
            recordKeyboardAction(key: key, action: action, handled: true, reason: "dismissed")
            return true

        case .passThrough:
            recordKeyboardAction(key: key, action: action, handled: false, reason: "pass-through")
            return false
        }
    }

    private func recordKeyboardAction(
        key: AutocompleteKey,
        action: KeyboardAction,
        handled: Bool,
        reason: String
    ) {
        DiagnosticsLog.shared.record(
            "keyboard-action",
            metadata: [
                "app": currentProfile?.bundleIdentifier ?? "unknown",
                "key": key.diagnosticName,
                "action": action.diagnosticName,
                "handled": String(handled),
                "reason": reason
            ]
        )
    }

    private func shouldSuppressKey(_ key: AutocompleteKey) -> Bool {
        guard let until = suppressKeyUntil[key] else {
            return false
        }

        if until > Date() {
            return true
        }

        suppressKeyUntil[key] = nil
        return false
    }

    private func suppressKey(_ key: AutocompleteKey) {
        suppressKeyUntil[key] = Date().addingTimeInterval(0.25)
    }

    private func insertionVerificationBaseline() -> InsertionVerificationBaseline? {
        guard let currentFieldIdentity,
              let lastTextSnapshot,
              lastTextSnapshot.fieldIdentity == currentFieldIdentity,
              let profile = currentProfile else {
            return nil
        }

        return InsertionVerificationBaseline(
            fieldIdentity: currentFieldIdentity,
            previousTextBeforeCursor: lastTextSnapshot.textBeforeCursor,
            profile: profile,
            suggestionID: currentSuggestionID,
            acceptanceID: "",
            requestMode: currentSuggestionRequestMode,
            retryCount: 0
        )
    }

    private func scheduleInsertionVerification(
        acceptedText: String,
        acceptanceID: String,
        baseline: InsertionVerificationBaseline?
    ) {
        guard var baseline else {
            return
        }
        baseline.acceptanceID = acceptanceID

        insertionVerificationTask?.cancel()
        insertionVerificationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else {
                return
            }

            guard let frontmostApp = accessibilityClient.frontmostApplication(),
                  let context = accessibilityClient.focusedTextContext(
                      allowDescendantTextFallback: baseline.profile.allowsDescendantTextFallback
                  ) else {
                DiagnosticsLog.shared.record(
                    "insert-verification",
                    metadata: [
                        "app": baseline.profile.bundleIdentifier,
                        "result": "missing-context"
                    ]
                )
                hideSuggestion()
                return
            }

            let currentIdentity = fieldIdentity(
                app: frontmostApp,
                context: context,
                profile: baseline.profile
            )

            guard currentIdentity == baseline.fieldIdentity else {
                return
            }

            let result = insertionVerification.verify(
                previousTextBeforeCursor: baseline.previousTextBeforeCursor,
                acceptedText: acceptedText,
                currentTextBeforeCursor: context.textBeforeCursor
            )

            DiagnosticsLog.shared.record(
                "insert-verification",
                metadata: [
                    "app": baseline.profile.bundleIdentifier,
                    "result": String(describing: result),
                    "acceptedChars": String(acceptedText.count),
                    "previousBeforeChars": String(baseline.previousTextBeforeCursor.count),
                    "currentBeforeChars": String(context.textBeforeCursor.count)
                ]
            )

            guard result.isVerified else {
                if insertionRetryPolicy.shouldRetry(
                    result: result,
                    insertionMode: baseline.profile.insertionMode,
                    retryCount: baseline.retryCount
                ) {
                    DiagnosticsLog.shared.record(
                        "insert-verification-retry",
                        metadata: [
                            "app": baseline.profile.bundleIdentifier,
                            "acceptedChars": String(acceptedText.count),
                            "retryCount": String(baseline.retryCount + 1),
                            "result": String(describing: result)
                        ]
                    )

                    if insertAcceptedText(acceptedText) {
                        let retryBaseline = InsertionVerificationBaseline(
                            fieldIdentity: baseline.fieldIdentity,
                            previousTextBeforeCursor: baseline.previousTextBeforeCursor,
                            profile: baseline.profile,
                            suggestionID: baseline.suggestionID,
                            acceptanceID: baseline.acceptanceID,
                            requestMode: baseline.requestMode,
                            retryCount: baseline.retryCount + 1
                        )
                        scheduleInsertionVerification(
                            acceptedText: acceptedText,
                            acceptanceID: acceptanceID,
                            baseline: retryBaseline
                        )
                        return
                    }
                }

                RawAutocompleteTraceLog.shared.record(
                    type: .insertionFailed,
                    suggestionID: baseline.suggestionID ?? "",
                    appBundleIdentifier: baseline.profile.bundleIdentifier,
                    fieldIdentity: baseline.fieldIdentity.traceDescription,
                    requestMode: baseline.requestMode?.rawValue ?? "",
                    acceptedText: acceptedText,
                    outcome: String(describing: result),
                    reason: "insert-verification-failed",
                    metadata: [
                        "acceptanceID": baseline.acceptanceID,
                        "previousBeforeChars": String(baseline.previousTextBeforeCursor.count),
                        "currentBeforeChars": String(context.textBeforeCursor.count)
                    ]
                )
                if baseline.profile.suppressesAfterInsertionFailure {
                    suppressCurrentField(reason: "insert-verification-failed")
                }
                hideSuggestion()
                return
            }

            RawAutocompleteTraceLog.shared.record(
                type: .insertionVerified,
                suggestionID: baseline.suggestionID ?? "",
                appBundleIdentifier: baseline.profile.bundleIdentifier,
                fieldIdentity: baseline.fieldIdentity.traceDescription,
                requestMode: baseline.requestMode?.rawValue ?? "",
                acceptedText: acceptedText,
                outcome: "verified",
                metadata: [
                    "acceptanceID": baseline.acceptanceID
                ]
            )
            beginAcceptanceSurvivalTracking(
                acceptedText: acceptedText,
                baseline: baseline
            )
        }
    }

    private func beginAcceptanceSurvivalTracking(
        acceptedText: String,
        baseline: InsertionVerificationBaseline
    ) {
        guard let suggestionID = baseline.suggestionID,
              !baseline.acceptanceID.isEmpty else {
            return
        }

        let tracker = AcceptanceSurvivalTracker(
            acceptanceID: baseline.acceptanceID,
            suggestionID: suggestionID,
            appBundleIdentifier: baseline.profile.bundleIdentifier,
            fieldIdentity: baseline.fieldIdentity,
            requestMode: baseline.requestMode?.rawValue ?? "",
            acceptedText: acceptedText,
            acceptedAt: Date(),
            profile: baseline.profile
        )
        acceptanceSurvivalTrackers[baseline.acceptanceID] = tracker
        acceptanceSurvivalTasks[baseline.acceptanceID]?.cancel()
        acceptanceSurvivalTasks[baseline.acceptanceID] = Task { @MainActor in
            var previousDelaySeconds = 0
            for (delaySeconds, checkpoint) in [
                (2, AcceptanceSurvivalCheckpoint.twoSeconds),
                (10, AcceptanceSurvivalCheckpoint.tenSeconds),
                (30, AcceptanceSurvivalCheckpoint.thirtySeconds)
            ] {
                try? await Task.sleep(for: .seconds(delaySeconds - previousDelaySeconds))
                previousDelaySeconds = delaySeconds
                guard !Task.isCancelled else {
                    return
                }

                recordAcceptanceSurvivalCheckpoint(
                    acceptanceID: baseline.acceptanceID,
                    checkpoint: checkpoint
                )
            }
        }
    }

    private func recordAcceptanceSurvivalCheckpoint(
        acceptanceID: String,
        checkpoint: AcceptanceSurvivalCheckpoint
    ) {
        guard let tracker = acceptanceSurvivalTrackers[acceptanceID],
              let frontmostApp = accessibilityClient.frontmostApplication(),
              let context = accessibilityClient.focusedTextContext(
                  allowDescendantTextFallback: tracker.profile.allowsDescendantTextFallback
              ) else {
            return
        }

        let currentIdentity = fieldIdentity(
            app: frontmostApp,
            context: context,
            profile: tracker.profile
        )
        guard currentIdentity == tracker.fieldIdentity else {
            return
        }

        recordAcceptanceSurvival(
            tracker: tracker,
            checkpoint: checkpoint,
            currentTextWindow: context.textBeforeCursor + context.textAfterCursor
        )
    }

    private func recordAcceptanceSurvival(
        tracker: AcceptanceSurvivalTracker,
        checkpoint: AcceptanceSurvivalCheckpoint,
        currentTextWindow: String
    ) {
        let firstPass = acceptanceSurvivalClassifier.classify(
            acceptedText: tracker.acceptedText,
            currentTextWindow: currentTextWindow,
            checkpoint: checkpoint,
            deletedWithinTwoSeconds: tracker.deletedWithinTwoSeconds
        )
        var updatedTracker = tracker
        if checkpoint == .twoSeconds,
           firstPass.survivalClass == .rejectedAfterAccept {
            updatedTracker.deletedWithinTwoSeconds = true
            acceptanceSurvivalTrackers[tracker.acceptanceID] = updatedTracker
        }

        let measurement = acceptanceSurvivalClassifier.classify(
            acceptedText: tracker.acceptedText,
            currentTextWindow: currentTextWindow,
            checkpoint: checkpoint,
            firstEditDelayMilliseconds: firstPass.survivalClass == .exactKept
                ? nil
                : max(0, Int(Date().timeIntervalSince(tracker.acceptedAt) * 1_000)),
            deletedWithinTwoSeconds: updatedTracker.deletedWithinTwoSeconds
        )

        RawAutocompleteTraceLog.shared.record(
            type: .acceptedTextEdited,
            suggestionID: tracker.suggestionID,
            appBundleIdentifier: tracker.appBundleIdentifier,
            fieldIdentity: tracker.fieldIdentity.traceDescription,
            requestMode: tracker.requestMode,
            metadata: measurement.traceMetadata.merging([
                "acceptanceID": tracker.acceptanceID,
                "acceptedChars": String(tracker.acceptedText.count),
                "acceptedWords": String(tracker.acceptedText.split(whereSeparator: \.isWhitespace).count)
            ]) { current, _ in current }
        )

        if checkpoint.isFinalMetricCheckpoint {
            finishAcceptanceSurvivalTracking(acceptanceID: tracker.acceptanceID)
        }
    }

    private func flushAcceptanceSurvivalTrackers(for fieldIdentity: FocusedFieldIdentity?) {
        guard let fieldIdentity,
              let snapshot = lastTextSnapshot,
              snapshot.fieldIdentity == fieldIdentity else {
            return
        }

        let currentTextWindow = snapshot.textBeforeCursor + snapshot.textAfterCursor
        let trackers = Array(acceptanceSurvivalTrackers.values)
        for tracker in trackers where tracker.fieldIdentity == fieldIdentity {
            recordAcceptanceSurvival(
                tracker: tracker,
                checkpoint: .fieldBlur,
                currentTextWindow: currentTextWindow
            )
        }
    }

    private func finishAcceptanceSurvivalTracking(acceptanceID: String) {
        acceptanceSurvivalTasks[acceptanceID]?.cancel()
        acceptanceSurvivalTasks[acceptanceID] = nil
        acceptanceSurvivalTrackers[acceptanceID] = nil
    }

    private func cancelAcceptanceSurvivalTracking() {
        acceptanceSurvivalTasks.values.forEach { $0.cancel() }
        acceptanceSurvivalTasks.removeAll()
        acceptanceSurvivalTrackers.removeAll()
    }

    private func scheduleSuggestion(
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity,
        renderMode: SuggestionRenderMode,
        delayMilliseconds: Int,
        requestMode: CompletionRequestMode
    ) {
        lastRequestedTextBeforeCursor = context.textBeforeCursor

        let suggestionID = UUID().uuidString
        let request = CompletionRequest(
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            appBundleIdentifier: appBundleIdentifier,
            maxVisibleWords: completionLengthConfiguration.maxVisibleWords,
            mode: requestMode,
            suggestionID: suggestionID
        )
        currentCompletionRequest = request
        let requestTicket = suggestionRequestGate.issue(request: request)
        let requestStartedAt = Date()
        let fieldIdentityDescription = fieldIdentity.traceDescription

        RawAutocompleteTraceLog.shared.record(
            type: .suggestionRequested,
            suggestionID: suggestionID,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentityDescription,
            requestMode: request.mode.rawValue,
            triggerReason: "poll",
            textBeforeCursor: request.textBeforeCursor,
            textAfterCursor: request.textAfterCursor,
            metadata: [
                "renderMode": renderMode.rawValue,
                "delayMilliseconds": String(delayMilliseconds)
            ]
        )

        if requestMode == .wordCompletion {
            if let fastSuggestion = wordCompletionRanker.suggestion(
                for: context.textBeforeCursor,
                recentWords: recentAcceptedWords
            ) {
                let screenshotPath = captureTraceScreenshot(
                    near: context.elementRect ?? context.windowRect ?? context.caretRect,
                    suggestionID: suggestionID,
                    bundleIdentifier: appBundleIdentifier
                )
                presentSuggestion(
                    fastSuggestion,
                    suggestionID: suggestionID,
                    request: request,
                    context: context,
                    profile: profile,
                    fieldIdentity: fieldIdentity,
                    renderMode: renderMode,
                    latencyMilliseconds: 0,
                    triggerReason: "fast-word-completion",
                    screenshotPath: screenshotPath
                )
                return
            }

            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: suggestionID,
                appBundleIdentifier: appBundleIdentifier,
                fieldIdentity: fieldIdentityDescription,
                requestMode: request.mode.rawValue,
                triggerReason: "fast-word-completion",
                textBeforeCursor: request.textBeforeCursor,
                textAfterCursor: request.textAfterCursor,
                reason: "no-fast-word-candidate",
                metadata: [
                    "renderMode": renderMode.rawValue
                ]
            )
            hideSuggestion()
            return
        }

        debounceTask = Task { [engine, requestTicket, fieldIdentity] in
            let renderDelay = renderMode == .inlineAdjacent ? delayMilliseconds : max(delayMilliseconds, 60)
            try? await Task.sleep(for: .milliseconds(renderDelay))
            guard !Task.isCancelled else {
                return
            }

            do {
                let suggestion = try await engine.suggestion(
                    for: request,
                    onPartialSuggestion: { partialSuggestion in
                        Task { @MainActor in
                            let latencyMilliseconds = max(0, Int(Date().timeIntervalSince(requestStartedAt) * 1000))
                            guard self.suggestionRequestGate.allows(
                                requestTicket,
                                currentRequest: self.currentCompletionRequest
                            ), self.currentFieldIdentity == fieldIdentity else {
                                return
                            }

                            guard !partialSuggestion.isEmpty,
                                  !self.suggestionRepetitionSuppressor.shouldSuppress(
                                      partialSuggestion.visibleText,
                                      mode: request.mode,
                                      scope: appBundleIdentifier
                                  ) else {
                                return
                            }

                            self.presentSuggestion(
                                partialSuggestion,
                                suggestionID: suggestionID,
                                request: request,
                                context: context,
                                profile: profile,
                                fieldIdentity: fieldIdentity,
                                renderMode: renderMode,
                                latencyMilliseconds: latencyMilliseconds,
                                triggerReason: "model-stream",
                                screenshotPath: ""
                            )
                        }
                    }
                )
                await MainActor.run {
                    let latencyMilliseconds = max(0, Int(Date().timeIntervalSince(requestStartedAt) * 1000))
                    guard self.suggestionRequestGate.allows(
                        requestTicket,
                        currentRequest: self.currentCompletionRequest
                    ), self.currentFieldIdentity == fieldIdentity else {
                        return
                    }

                    let anchorRect = RenderModePlan.anchorRect(
                        for: renderMode,
                        caretRect: context.caretRect,
                        elementRect: context.elementRect,
                        windowRect: context.windowRect
                    )
                    guard let suggestion, !suggestion.isEmpty else {
                        RawAutocompleteTraceLog.shared.record(
                            type: .suggestionSuppressed,
                            suggestionID: suggestionID,
                            appBundleIdentifier: appBundleIdentifier,
                            fieldIdentity: fieldIdentityDescription,
                            requestMode: request.mode.rawValue,
                            triggerReason: "model-result",
                            textBeforeCursor: request.textBeforeCursor,
                            textAfterCursor: request.textAfterCursor,
                            latencyMilliseconds: latencyMilliseconds,
                            reason: "empty-suggestion"
                        )
                        self.recordSuggestionEvent(
                            "suggestion-blocked",
                            context: context,
                            profile: profile,
                            metadata: [
                                "reason": "empty-suggestion"
                            ]
                        )
                        self.hideSuggestion()
                        return
                    }

                    guard anchorRect != nil else {
                        RawAutocompleteTraceLog.shared.record(
                            type: .suggestionSuppressed,
                            suggestionID: suggestionID,
                            appBundleIdentifier: appBundleIdentifier,
                            fieldIdentity: fieldIdentityDescription,
                            requestMode: request.mode.rawValue,
                            triggerReason: "model-result",
                            textBeforeCursor: request.textBeforeCursor,
                            textAfterCursor: request.textAfterCursor,
                            cleanedVisibleText: suggestion.visibleText,
                            displayedText: suggestion.visibleText,
                            latencyMilliseconds: latencyMilliseconds,
                            reason: "missing-anchor"
                        )
                        self.recordSuggestionEvent(
                            "suggestion-blocked",
                            context: context,
                            profile: profile,
                            metadata: [
                                "reason": "missing-anchor"
                            ]
                        )
                        self.hideSuggestion()
                        return
                    }

                    RawAutocompleteTraceLog.shared.record(
                        type: .modelResult,
                        suggestionID: suggestionID,
                        appBundleIdentifier: appBundleIdentifier,
                        fieldIdentity: fieldIdentityDescription,
                        requestMode: request.mode.rawValue,
                        triggerReason: "model-result",
                        textBeforeCursor: request.textBeforeCursor,
                        textAfterCursor: request.textAfterCursor,
                        cleanedVisibleText: suggestion.visibleText,
                        displayedText: suggestion.visibleText,
                        latencyMilliseconds: latencyMilliseconds
                    )
                    guard !self.suggestionRepetitionSuppressor.shouldSuppress(
                        suggestion.visibleText,
                        mode: request.mode,
                        scope: appBundleIdentifier
                    ) else {
                        RawAutocompleteTraceLog.shared.record(
                            type: .suggestionSuppressed,
                            suggestionID: suggestionID,
                            appBundleIdentifier: appBundleIdentifier,
                            fieldIdentity: fieldIdentityDescription,
                            requestMode: request.mode.rawValue,
                            triggerReason: "model-result",
                            textBeforeCursor: request.textBeforeCursor,
                            textAfterCursor: request.textAfterCursor,
                            cleanedVisibleText: suggestion.visibleText,
                            displayedText: suggestion.visibleText,
                            latencyMilliseconds: latencyMilliseconds,
                            reason: "repeated-miss"
                        )
                        self.hideSuggestion()
                        return
                    }
                    let screenshotPath = self.captureTraceScreenshot(
                        near: context.elementRect ?? context.windowRect ?? context.caretRect,
                        suggestionID: suggestionID,
                        bundleIdentifier: appBundleIdentifier
                    )
                    self.presentSuggestion(
                        suggestion,
                        suggestionID: suggestionID,
                        request: request,
                        context: context,
                        profile: profile,
                        fieldIdentity: fieldIdentity,
                        renderMode: renderMode,
                        latencyMilliseconds: latencyMilliseconds,
                        triggerReason: "model-result",
                        screenshotPath: screenshotPath
                    )
                }
            } catch {
                await MainActor.run {
                    self.hideSuggestion(reason: "engine-error")
                }
            }
        }
    }

    private func presentSuggestion(
        _ suggestion: CompletionSuggestion,
        suggestionID: String,
        request: CompletionRequest,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        renderMode: SuggestionRenderMode,
        latencyMilliseconds: Int,
        triggerReason: String,
        screenshotPath: String
    ) {
        let storedLearningAdjustment = compatibilityLearningStore.engine().adjustment(
            for: profile.bundleIdentifier,
            profileRenderMode: renderMode
        )
        let learningAdjustment = profile.bundleIdentifier == "com.openai.codex"
            ? storedLearningAdjustment.withoutVisualOffset
            : storedLearningAdjustment
        let effectiveRenderMode = learningAdjustment.effectiveRenderMode
        let anchorRect = learningAdjustment.adjusted(RenderModePlan.anchorRect(
            for: effectiveRenderMode,
            caretRect: context.caretRect,
            elementRect: context.elementRect,
            windowRect: context.windowRect
        ))
        let adjustedTextLineRect = learningAdjustment.adjusted(context.textLineRect)
        let adjustedClippingRect = context.elementRect ?? context.windowRect

        guard let anchorRect else {
            RawAutocompleteTraceLog.shared.record(
                type: .suggestionSuppressed,
                suggestionID: suggestionID,
                appBundleIdentifier: request.appBundleIdentifier ?? profile.bundleIdentifier,
                fieldIdentity: fieldIdentity.traceDescription,
                requestMode: request.mode.rawValue,
                triggerReason: triggerReason,
                textBeforeCursor: request.textBeforeCursor,
                textAfterCursor: request.textAfterCursor,
                displayedText: suggestion.visibleText,
                latencyMilliseconds: latencyMilliseconds,
                reason: "missing-anchor"
            )
            return
        }

        suggestionSession.present(suggestion)
        currentSuggestionID = suggestionID
        currentSuggestionRequestMode = request.mode
        currentSuggestionTextBeforeCursor = request.textBeforeCursor
        currentSuggestionDisplayedText = suggestion.visibleText
        lastCaretRect = anchorRect
        lastTextLineRect = adjustedTextLineRect
        lastClippingRect = adjustedClippingRect
        lastTextStyle = context.textStyle
        lastRenderMode = effectiveRenderMode
        suggestionPanel.show(
            text: suggestion.visibleText,
            near: anchorRect,
            alignedTo: effectiveRenderMode == .inlineAdjacent ? adjustedTextLineRect : nil,
            boundedBy: adjustedClippingRect,
            style: context.textStyle,
            renderMode: effectiveRenderMode
        )
        compatibilityLearningStore.recordObservation(
            for: profile.bundleIdentifier,
            reason: "suggestion-presented"
        )
        RawAutocompleteTraceLog.shared.record(
            type: .suggestionPresented,
            suggestionID: suggestionID,
            appBundleIdentifier: request.appBundleIdentifier ?? profile.bundleIdentifier,
            fieldIdentity: fieldIdentity.traceDescription,
            requestMode: request.mode.rawValue,
            triggerReason: triggerReason,
            textBeforeCursor: request.textBeforeCursor,
            textAfterCursor: request.textAfterCursor,
            cleanedVisibleText: suggestion.visibleText,
            displayedText: suggestion.visibleText,
            latencyMilliseconds: latencyMilliseconds,
            screenshotPath: screenshotPath,
            metadata: [
                "effectiveRenderMode": effectiveRenderMode.rawValue,
                "visibleChars": String(suggestion.visibleText.count),
                "anchorRect": compactRectDescription(anchorRect),
                "textLineRect": adjustedTextLineRect.map(compactRectDescription) ?? "none",
                "clippingRect": adjustedClippingRect.map(compactRectDescription) ?? "none"
            ]
            .merging(traceGeometryMetadata(context: context, renderMode: effectiveRenderMode)) { current, _ in current }
            .merging(learningAdjustment.metadata) { current, _ in current }
        )
        recordSuggestionEvent(
            "suggestion-presented",
            context: context,
            profile: profile,
            metadata: [
                "effectiveRenderMode": effectiveRenderMode.rawValue,
                "requestMode": request.mode.rawValue,
                "traceID": String(suggestionID.prefix(8)),
                "visibleChars": String(suggestion.visibleText.count),
                "suggestionID": suggestionID,
                "latencyMilliseconds": String(latencyMilliseconds)
            ].merging(learningAdjustment.metadata) { current, _ in current }
        )
        startKeyboardEventTapIfPossible()
    }

    private func captureTraceScreenshot(
        near rect: CGRect?,
        suggestionID: String,
        bundleIdentifier: String
    ) -> String {
        let appScreenshotTracingEnabled = compatibilityLearningStore
            .profile(for: bundleIdentifier)?
            .screenshotTracingEnabled == true
        guard (RawAutocompleteTraceLog.shared.screenshotTracingEnabled || appScreenshotTracingEnabled),
              let rect else {
            return ""
        }

        let folderURL = RawAutocompleteTraceLog.shared.screenshotFolderURL
        let screenshotURL = folderURL.appendingPathComponent("\(suggestionID).png")

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            let paddedRect = rect.insetBy(dx: -24, dy: -24)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = [
                "-x",
                "-R\(Int(paddedRect.origin.x)),\(Int(paddedRect.origin.y)),\(Int(paddedRect.width)),\(Int(paddedRect.height))",
                screenshotURL.path
            ]
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  FileManager.default.fileExists(atPath: screenshotURL.path) else {
                return ""
            }
            compatibilityLearningStore.recordObservation(
                for: bundleIdentifier,
                reason: "screenshot-captured"
            )
            return screenshotURL.path
        } catch {
            return ""
        }
    }

    private func traceGeometryMetadata(
        context: FocusedTextContext,
        renderMode: SuggestionRenderMode
    ) -> [String: String] {
        [
            "effectiveRenderMode": renderMode.rawValue,
            "hasCaretRect": String(context.caretRect != nil),
            "hasElementRect": String(context.elementRect != nil),
            "hasWindowRect": String(context.windowRect != nil),
            "canReadBounds": String(context.capabilities.canReadBoundsForRange)
        ]
    }

    private func recordSuggestionEvent(
        _ event: String,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        metadata: [String: String] = [:]
    ) {
        var safeMetadata = metadata
        safeMetadata["app"] = profile.bundleIdentifier
        safeMetadata["renderMode"] = profile.renderMode.rawValue
        safeMetadata["insertionMode"] = profile.insertionMode.rawValue
        safeMetadata["fieldIdentityMode"] = profile.fieldIdentityMode.rawValue
        safeMetadata["role"] = context.role ?? "unknown"
        safeMetadata["subrole"] = context.subrole ?? "none"
        safeMetadata["beforeChars"] = String(context.textBeforeCursor.count)
        safeMetadata["afterChars"] = String(context.textAfterCursor.count)
        safeMetadata["hasCaretRect"] = String(context.caretRect != nil)
        safeMetadata["hasElementRect"] = String(context.elementRect != nil)
        safeMetadata["hasWindowRect"] = String(context.windowRect != nil)
        safeMetadata["canReadValue"] = String(context.capabilities.canReadValue)
        safeMetadata["canReadRange"] = String(context.capabilities.canReadSelectedTextRange)
        safeMetadata["canReadBounds"] = String(context.capabilities.canReadBoundsForRange)
        safeMetadata["canSetSelectedText"] = String(context.capabilities.canSetSelectedText)

        DiagnosticsLog.shared.record(event, metadata: safeMetadata)
    }

    private func recordBlockedSuggestionEvent(
        _ event: String,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        metadata: [String: String] = [:]
    ) {
        let signature = blockedSuggestionSignature(
            context: context,
            profile: profile,
            fieldIdentity: fieldIdentity,
            metadata: metadata
        )

        guard suggestionBlockLogGate.shouldRecord(signature: signature) else {
            return
        }

        recordSuggestionEvent(event, context: context, profile: profile, metadata: metadata)
    }

    private func blockedSuggestionSignature(
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        metadata: [String: String]
    ) -> String {
        [
            profile.bundleIdentifier,
            String(fieldIdentity.processIdentifier),
            String(fieldIdentity.elementIdentifier),
            metadata["reason"] ?? "unknown",
            metadata["readinessStage"] ?? "none",
            String(context.textBeforeCursor.count),
            String(context.textAfterCursor.count)
        ].joined(separator: "|")
    }

    private func fieldIdentity(
        app: RunningApplicationInfo,
        context: FocusedTextContext,
        profile: CompatibilityProfile
    ) -> FocusedFieldIdentity {
        let elementIdentifier: Int

        switch profile.fieldIdentityMode {
        case .accessibilityElement:
            elementIdentifier = context.elementIdentifier
        case .stableBounds:
            elementIdentifier = stableBoundsIdentifier(context: context)
        }

        return FocusedFieldIdentity(
            bundleIdentifier: app.bundleIdentifier,
            processIdentifier: app.processIdentifier,
            elementIdentifier: elementIdentifier
        )
    }

    private func stableBoundsIdentifier(context: FocusedTextContext) -> Int {
        var hasher = Hasher()
        hasher.combine(context.role ?? "unknown")
        hasher.combine(context.subrole ?? "none")
        combineRoundedRect(context.elementRect, into: &hasher)
        combineRoundedRect(context.windowRect, into: &hasher)
        return hasher.finalize()
    }

    private func combineRoundedRect(_ rect: CGRect?, into hasher: inout Hasher) {
        guard let rect else {
            hasher.combine("missing")
            return
        }

        hasher.combine(Int(rect.origin.x.rounded()))
        hasher.combine(Int(rect.origin.y.rounded()))
        hasher.combine(Int(rect.width.rounded()))
        hasher.combine(Int(rect.height.rounded()))
    }

    private func insertAcceptedText(_ acceptedText: String) -> Bool {
        guard let profile = currentProfile else {
            return accessibilityClient.insertText(acceptedText)
        }

        let result = insertionEngine.insert(acceptedText, profile: profile)
        DiagnosticsLog.shared.record(
            "insert",
            metadata: [
                "app": profile.bundleIdentifier,
                "mode": result.mode.rawValue,
                "success": String(result.succeeded)
            ]
        )

        return result.succeeded
    }

    private func recordRawAcceptance(action: KeyboardAction, acceptedText: String) -> String {
        let acceptanceID = UUID().uuidString
        guard let profile = currentProfile else {
            return acceptanceID
        }

        RawAutocompleteTraceLog.shared.recordAcceptance(
            action: action.diagnosticName,
            acceptanceID: acceptanceID,
            acceptMode: action == .acceptNextWord ? "tab" : "full",
            appBundleIdentifier: profile.bundleIdentifier,
            acceptedText: acceptedText,
            remainingVisibleText: suggestionSession.visibleSuggestion?.visibleText,
            suggestionID: currentSuggestionID ?? "",
            fieldIdentity: currentFieldIdentity?.traceDescription ?? "",
            requestMode: currentSuggestionRequestMode?.rawValue ?? ""
        )

        return acceptanceID
    }

    private func refreshVisibleSuggestion() {
        guard let suggestion = suggestionSession.visibleSuggestion,
              let caretRect = lastCaretRect else {
            hideSuggestion()
            return
        }

        currentSuggestionDisplayedText = suggestion.visibleText
        suggestionPanel.show(
            text: suggestion.visibleText,
            near: caretRect,
            alignedTo: lastTextLineRect,
            boundedBy: lastClippingRect,
            style: lastTextStyle,
            renderMode: lastRenderMode ?? .inlineAdjacent
        )
    }

    private func repositionVisibleSuggestion(
        context: FocusedTextContext,
        profile: CompatibilityProfile
    ) {
        guard suggestionSession.hasVisibleSuggestion,
              let renderMode = RenderModePlan.effectiveMode(
                  for: profile,
                  supportsInlineSuggestions: context.capabilities.supportsInlineSuggestions,
                  hasMirrorAnchor: context.elementRect != nil || context.windowRect != nil
              ) else {
            return
        }

        let storedLearningAdjustment = compatibilityLearningStore.engine().adjustment(
            for: profile.bundleIdentifier,
            profileRenderMode: renderMode
        )
        let learningAdjustment = profile.bundleIdentifier == "com.openai.codex"
            ? storedLearningAdjustment.withoutVisualOffset
            : storedLearningAdjustment
        let effectiveRenderMode = learningAdjustment.effectiveRenderMode
        let anchorRect = learningAdjustment.adjusted(RenderModePlan.anchorRect(
            for: effectiveRenderMode,
            caretRect: context.caretRect,
            elementRect: context.elementRect,
            windowRect: context.windowRect
        ))

        guard let anchorRect else {
            return
        }

        lastCaretRect = anchorRect
        lastTextLineRect = learningAdjustment.adjusted(context.textLineRect)
        lastClippingRect = context.elementRect ?? context.windowRect
        lastTextStyle = context.textStyle
        lastRenderMode = effectiveRenderMode
        refreshVisibleSuggestion()
    }

    private func recordAcceptedText(_ acceptedText: String) {
        rememberAcceptedWords(in: acceptedText)

        guard let currentFieldIdentity,
              let lastTextSnapshot,
              lastTextSnapshot.fieldIdentity == currentFieldIdentity else {
            return
        }

        self.lastTextSnapshot = FocusedTextSnapshot(
            fieldIdentity: currentFieldIdentity,
            textBeforeCursor: lastTextSnapshot.textBeforeCursor + acceptedText,
            textAfterCursor: lastTextSnapshot.textAfterCursor
        )
    }

    private func rememberAcceptedWords(in text: String) {
        rememberRecentWords(recentWordExtractor.words(in: text))
    }

    private func rememberTypedWordsIfNeeded(
        previousSnapshot: FocusedTextSnapshot?,
        currentSnapshot: FocusedTextSnapshot
    ) {
        guard let previousSnapshot,
              previousSnapshot.fieldIdentity == currentSnapshot.fieldIdentity else {
            return
        }

        rememberRecentWords(recentWordExtractor.completedWords(
            previousTextBeforeCursor: previousSnapshot.textBeforeCursor,
            currentTextBeforeCursor: currentSnapshot.textBeforeCursor
        ))
    }

    private func rememberRecentWords(_ words: [String]) {
        guard !words.isEmpty else {
            return
        }

        recentAcceptedWords.append(contentsOf: words)
        if recentAcceptedWords.count > 500 {
            recentAcceptedWords.removeFirst(recentAcceptedWords.count - 500)
        }
    }

    private func recordTypedOverSuggestionIfNeeded(
        newTextBeforeCursor: String,
        fieldIdentity: FocusedFieldIdentity,
        profile: CompatibilityProfile
    ) {
        guard suggestionSession.hasVisibleSuggestion,
              let suggestionID = currentSuggestionID,
              let originalTextBeforeCursor = currentSuggestionTextBeforeCursor,
              let displayedText = currentSuggestionDisplayedText,
              fieldIdentity == currentFieldIdentity,
              newTextBeforeCursor.hasPrefix(originalTextBeforeCursor),
              newTextBeforeCursor != originalTextBeforeCursor else {
            return
        }

        let typedSuffix = String(newTextBeforeCursor.dropFirst(originalTextBeforeCursor.count))
        guard !typedSuffix.isEmpty else {
            return
        }

        let normalizedDisplayed = displayedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedTyped = typedSuffix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedDisplayed.hasPrefix(normalizedTyped) else {
            return
        }

        RawAutocompleteTraceLog.shared.record(
            type: .suggestionTypedOver,
            suggestionID: suggestionID,
            appBundleIdentifier: profile.bundleIdentifier,
            fieldIdentity: fieldIdentity.traceDescription,
            requestMode: currentSuggestionRequestMode?.rawValue ?? "",
            textBeforeCursor: originalTextBeforeCursor,
            displayedText: displayedText,
            outcome: "typed-over",
            reason: "typed-against-visible-suggestion",
            metadata: [
                "typedSuffix": typedSuffix
            ]
        )
    }

    private func hideStaleSuggestionIfNeeded(
        newTextBeforeCursor: String,
        fieldIdentity: FocusedFieldIdentity
    ) {
        guard suggestionSession.hasVisibleSuggestion,
              fieldIdentity == currentFieldIdentity,
              let originalTextBeforeCursor = currentSuggestionTextBeforeCursor,
              let displayedText = currentSuggestionDisplayedText,
              newTextBeforeCursor.hasPrefix(originalTextBeforeCursor),
              newTextBeforeCursor != originalTextBeforeCursor else {
            return
        }

        let typedSuffix = String(newTextBeforeCursor.dropFirst(originalTextBeforeCursor.count))
        let normalizedDisplayed = displayedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedTyped = typedSuffix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalizedDisplayed.hasPrefix(normalizedTyped), !normalizedTyped.isEmpty {
            hideSuggestion(reason: "typed-through-visible-prefix")
        } else {
            suggestionRepetitionSuppressor.recordMiss(
                displayedText,
                mode: currentSuggestionRequestMode,
                scope: currentProfile?.bundleIdentifier ?? ""
            )
            hideSuggestion(reason: "typed-over")
        }
    }

    private func hideSuggestion(reason: String = "hidden") {
        if suggestionSession.hasVisibleSuggestion,
           let suggestionID = currentSuggestionID {
            let outcome: String
            if reason.hasPrefix("accepted") {
                outcome = "accepted"
            } else if reason == "typed-through-visible-prefix" {
                outcome = "typed-through"
            } else if reason == "typed-over" {
                outcome = "typed-over"
            } else {
                outcome = "ignored"
            }

            RawAutocompleteTraceLog.shared.record(
                type: .suggestionHidden,
                suggestionID: suggestionID,
                appBundleIdentifier: currentProfile?.bundleIdentifier ?? "",
                fieldIdentity: currentFieldIdentity?.traceDescription ?? "",
                requestMode: currentSuggestionRequestMode?.rawValue ?? "",
                displayedText: currentSuggestionDisplayedText ?? suggestionSession.visibleSuggestion?.visibleText ?? "",
                outcome: outcome,
                reason: reason
            )
        }

        suggestionSession.dismiss()
        currentSuggestionID = nil
        currentSuggestionRequestMode = nil
        currentSuggestionTextBeforeCursor = nil
        currentSuggestionDisplayedText = nil
        lastCaretRect = nil
        lastTextLineRect = nil
        lastClippingRect = nil
        lastTextStyle = nil
        lastRenderMode = nil
        suggestionPanel.hide()
        stopKeyboardEventTapIfActive()
    }

    private func updateStatusMenu(
        app: RunningApplicationInfo?,
        profile: CompatibilityProfile?,
        appEnabled: Bool
    ) {
        let permission = accessibilityClient.isTrusted ? "AX ok" : "AX missing"
        let appName = app?.localizedName ?? "No app"
        let profileName = profile?.displayName ?? "unsupported"
        let enabled = appEnabled ? "on" : "off"
        let statusLine = "Status: \(permission) | \(appName) | \(profileName) | \(enabled)"

        statusMenuItem?.title = statusLine
        toggleAppMenuItem?.title = app.map { appEnabled ? "Disable \($0.localizedName)" : "Enable \($0.localizedName)" } ?? "Toggle Current App"
        settingsWindow.refresh(
            isTrusted: accessibilityClient.isTrusted,
            runtimeReport: runtimeReadinessReport,
            runtimeTargetSummary: runtimeTargetSummary,
            modelDirectoryPath: modelDirectoryPath
        )

        guard lastStatusLine != statusLine else {
            return
        }

        lastStatusLine = statusLine
        DiagnosticsLog.shared.record(
            "status",
            metadata: [
                "accessibility": permission,
                "app": appName,
                "profile": profileName,
                "enabled": enabled
            ]
        )
    }

    private func suppressCurrentField(reason: String) {
        guard let currentProfile,
              currentProfile.suppressesUntilBlurAfterEscape,
              let currentFieldIdentity else {
            return
        }

        suppressedFieldIdentities.insert(currentFieldIdentity)
        DiagnosticsLog.shared.record(
            "field-suppressed",
            metadata: [
                "app": currentProfile.bundleIdentifier,
                "reason": reason
            ]
        )
    }

    private func transitionToField(_ fieldIdentity: FocusedFieldIdentity) {
        guard currentFieldIdentity != fieldIdentity else {
            return
        }

        invalidatePendingSuggestionRequest()
        flushAcceptanceSurvivalTrackers(for: currentFieldIdentity)

        if let currentFieldIdentity {
            suppressedFieldIdentities.remove(currentFieldIdentity)
        }

        currentFieldIdentity = fieldIdentity
        lastTextSnapshot = nil
        lastRequestedTextBeforeCursor = nil
        suggestionBlockLogGate.reset()
    }

    private func clearFocusedFieldState() {
        invalidatePendingSuggestionRequest()
        flushAcceptanceSurvivalTrackers(for: currentFieldIdentity)

        if let currentFieldIdentity {
            suppressedFieldIdentities.remove(currentFieldIdentity)
        }

        currentFieldIdentity = nil
        lastTextSnapshot = nil
        lastRequestedTextBeforeCursor = nil
        suggestionBlockLogGate.reset()
    }

    private func invalidatePendingSuggestionRequest() {
        debounceTask?.cancel()
        debounceTask = nil
        currentCompletionRequest = nil
        suggestionRequestGate.invalidate()
    }

    @objc
    private func requestAccessibilityPermission() {
        accessibilityClient.requestPermissionIfNeeded()
        settingsWindow.refresh(
            isTrusted: accessibilityClient.isTrusted,
            runtimeReport: runtimeReadinessReport,
            runtimeTargetSummary: runtimeTargetSummary,
            modelDirectoryPath: modelDirectoryPath
        )
        DiagnosticsLog.shared.record("request-accessibility")
    }

    @objc
    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        if let url, NSWorkspace.shared.open(url) {
            DiagnosticsLog.shared.record("open-accessibility-settings")
        } else {
            DiagnosticsLog.shared.record("open-accessibility-settings-failed")
        }
    }

    @objc
    private func showSettings() {
        settingsWindow.show(
            isTrusted: accessibilityClient.isTrusted,
            runtimeReport: runtimeReadinessReport,
            runtimeTargetSummary: runtimeTargetSummary,
            modelDirectoryPath: modelDirectoryPath
        )
    }

    @objc
    private func revealModelFolder() {
        do {
            try FileManager.default.createDirectory(
                at: modelRuntimeBundle.modelDirectoryURL,
                withIntermediateDirectories: true
            )
            NSWorkspace.shared.activateFileViewerSelecting([modelRuntimeBundle.modelDirectoryURL])
            DiagnosticsLog.shared.record(
                "reveal-model-folder",
                metadata: ["path": modelDirectoryPath]
            )
        } catch {
            DiagnosticsLog.shared.record(
                "reveal-model-folder-failed",
                metadata: ["reason": error.localizedDescription]
            )
        }
    }

    @objc
    private func showDiagnostics() {
        let app = accessibilityClient.frontmostApplication()
        let compatibilityStatus = app
            .map { profileStore.supportStatus(for: $0.bundleIdentifier) }
            ?? .unsupported
        let profile = app.flatMap { profileStore.profile(for: $0.bundleIdentifier) }
        let appEnabled = app.map { !disabledBundleIdentifiers.contains($0.bundleIdentifier) } ?? false
        let bundleIdentifier = app?.bundleIdentifier ?? ""

        diagnosticsWindow.show(
            diagnostics: accessibilityClient.focusedTextDiagnostics(
                allowDescendantTextFallback: profile?.allowsDescendantTextFallback == true
            ),
            profile: profile,
            compatibilityStatus: compatibilityStatus,
            appEnabled: appEnabled,
            appTrusted: accessibilityClient.isTrusted,
            runtimeReport: runtimeReadinessReport,
            runtimeTargetSummary: runtimeTargetSummary,
            modelDirectoryPath: modelDirectoryPath,
            recentEvents: DiagnosticsLog.shared.recentLines(limit: 24),
            traceSummary: RawAutocompleteTraceLog.shared.summary(),
            recentTraceEvents: RawAutocompleteTraceLog.shared.recentEvents(limit: 48),
            tracePath: RawAutocompleteTraceLog.shared.path,
            tracingPaused: RawAutocompleteTraceLog.shared.isPaused,
            screenshotTracingEnabled: RawAutocompleteTraceLog.shared.screenshotTracingEnabled
                || compatibilityLearningStore.profile(for: bundleIdentifier)?.screenshotTracingEnabled == true,
            compatibilityLearningPath: compatibilityLearningStore.path,
            compatibilityLearningProfile: compatibilityLearningStore.profile(for: bundleIdentifier),
            refreshAction: { [weak self] in
                self?.showDiagnostics()
            },
            toggleTracingAction: { [weak self] in
                self?.toggleTracing()
            },
            toggleScreenshotTracingAction: { [weak self] in
                self?.toggleScreenshotTracing(for: bundleIdentifier)
            },
            openTraceFolderAction: {
                self.openTraceFolder()
            },
            exportReportAction: {
                self.exportTraceReport()
            },
            deleteTracesAction: { [weak self] in
                RawAutocompleteTraceLog.shared.deleteAll()
                self?.showDiagnostics()
            }
        )
    }

    private func toggleTracing() {
        let nextPaused = !RawAutocompleteTraceLog.shared.isPaused
        if nextPaused {
            RawAutocompleteTraceLog.shared.record(
                type: .appPaused,
                suggestionID: "",
                appBundleIdentifier: currentProfile?.bundleIdentifier ?? "",
                fieldIdentity: currentFieldIdentity?.traceDescription ?? "",
                reason: "manual",
                metadata: [
                    "pauseReason": "manual",
                    "scope": "global"
                ]
            )
        }
        RawAutocompleteTraceLog.shared.setPaused(nextPaused)
        DiagnosticsLog.shared.record(
            "trace-control",
            metadata: ["paused": String(nextPaused)]
        )
        showDiagnostics()
    }

    private func toggleScreenshotTracing(for bundleIdentifier: String) {
        guard !bundleIdentifier.isEmpty else {
            RawAutocompleteTraceLog.shared.setScreenshotTracingEnabled(!RawAutocompleteTraceLog.shared.screenshotTracingEnabled)
            showDiagnostics()
            return
        }

        let current = compatibilityLearningStore.profile(for: bundleIdentifier)?.screenshotTracingEnabled == true
        compatibilityLearningStore.setScreenshotTracing(!current, for: bundleIdentifier)
        DiagnosticsLog.shared.record(
            "screenshot-trace-control",
            metadata: [
                "app": bundleIdentifier,
                "enabled": String(!current)
            ]
        )
        showDiagnostics()
    }

    @objc
    private func nudgeCurrentAppSuggestionUp() {
        nudgeCurrentAppSuggestion(dx: 0, dy: -2)
    }

    @objc
    private func nudgeCurrentAppSuggestionDown() {
        nudgeCurrentAppSuggestion(dx: 0, dy: 2)
    }

    @objc
    private func nudgeCurrentAppSuggestionLeft() {
        nudgeCurrentAppSuggestion(dx: -2, dy: 0)
    }

    @objc
    private func nudgeCurrentAppSuggestionRight() {
        nudgeCurrentAppSuggestion(dx: 2, dy: 0)
    }

    private func nudgeCurrentAppSuggestion(dx: Double, dy: Double) {
        guard let bundleIdentifier = accessibilityClient.frontmostApplication()?.bundleIdentifier,
              profileStore.allows(bundleIdentifier: bundleIdentifier) else {
            DiagnosticsLog.shared.record("compatibility-learning-nudge-skipped")
            return
        }

        compatibilityLearningStore.nudgeOffset(dx: dx, dy: dy, for: bundleIdentifier)
        DiagnosticsLog.shared.record(
            "compatibility-learning-nudge",
            metadata: [
                "app": bundleIdentifier,
                "dx": String(dx),
                "dy": String(dy)
            ]
        )
    }

    @objc
    private func resetCurrentAppLearning() {
        guard let bundleIdentifier = accessibilityClient.frontmostApplication()?.bundleIdentifier else {
            return
        }

        compatibilityLearningStore.reset(bundleIdentifier: bundleIdentifier)
        DiagnosticsLog.shared.record(
            "compatibility-learning-reset",
            metadata: ["app": bundleIdentifier]
        )
    }

    private func openTraceFolder() {
        do {
            try FileManager.default.createDirectory(
                at: RawAutocompleteTraceLog.shared.folderURL,
                withIntermediateDirectories: true
            )
            NSWorkspace.shared.activateFileViewerSelecting([RawAutocompleteTraceLog.shared.folderURL])
        } catch {
            DiagnosticsLog.shared.record(
                "trace-folder-open-failed",
                metadata: ["reason": error.localizedDescription]
            )
        }
    }

    private func exportTraceReport() {
        guard let reportURL = RawAutocompleteTraceLog.shared.exportHTMLReport() else {
            DiagnosticsLog.shared.record("trace-report-export-failed")
            showDiagnostics()
            return
        }

        NSWorkspace.shared.open(reportURL)
        DiagnosticsLog.shared.record(
            "trace-report-exported",
            metadata: ["path": reportURL.path]
        )
        showDiagnostics()
    }

    @objc
    private func toggleCurrentApp() {
        guard let app = accessibilityClient.frontmostApplication(),
              profileStore.allows(bundleIdentifier: app.bundleIdentifier) else {
            return
        }

        let shouldDisable = !disabledBundleIdentifiers.contains(app.bundleIdentifier)
        var selection = DisabledAppSelection(bundleIdentifiers: disabledBundleIdentifiers)
        selection.set(app.bundleIdentifier, disabled: shouldDisable)
        disabledBundleIdentifiers = selection.bundleIdentifiers

        if shouldDisable {
            RawAutocompleteTraceLog.shared.record(
                type: .appDisabled,
                suggestionID: "",
                appBundleIdentifier: app.bundleIdentifier,
                fieldIdentity: currentFieldIdentity?.traceDescription ?? "",
                reason: "manual",
                metadata: [
                    "disableReason": "manual",
                    "scope": "app"
                ]
            )
            clearFocusedFieldState()
            hideSuggestion()
        }

        persistDisabledApps()
        DiagnosticsLog.shared.record(
            "app-control",
            metadata: [
                "app": app.bundleIdentifier,
                "enabled": String(!shouldDisable),
                "disabledCount": String(disabledBundleIdentifiers.count)
            ]
        )
        updateStatusMenu(
            app: app,
            profile: profileStore.profile(for: app.bundleIdentifier),
            appEnabled: !disabledBundleIdentifiers.contains(app.bundleIdentifier)
        )
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }
}

private extension AppDelegate {
    static var disabledAppsDefaultsKey: String {
        "DisabledBundleIdentifiers"
    }

    func loadDisabledApps() {
        let persisted = UserDefaults.standard.stringArray(forKey: Self.disabledAppsDefaultsKey) ?? []
        disabledBundleIdentifiers = DisabledAppSelection(
            persistedBundleIdentifiers: persisted
        ).bundleIdentifiers
    }

    func persistDisabledApps() {
        let selection = DisabledAppSelection(bundleIdentifiers: disabledBundleIdentifiers)
        UserDefaults.standard.set(
            selection.persistedBundleIdentifiers,
            forKey: Self.disabledAppsDefaultsKey
        )
    }
}

private struct FocusedFieldIdentity: Equatable, Hashable {
    let bundleIdentifier: String
    let processIdentifier: pid_t
    let elementIdentifier: Int

    var traceDescription: String {
        "\(bundleIdentifier)|pid:\(processIdentifier)|element:\(elementIdentifier)"
    }
}

private struct FocusedTextSnapshot: Equatable {
    let fieldIdentity: FocusedFieldIdentity
    let textBeforeCursor: String
    let textAfterCursor: String
}

private struct InsertionVerificationBaseline: Equatable {
    let fieldIdentity: FocusedFieldIdentity
    let previousTextBeforeCursor: String
    let profile: CompatibilityProfile
    let suggestionID: String?
    var acceptanceID: String
    let requestMode: CompletionRequestMode?
    let retryCount: Int
}

private struct AcceptanceSurvivalTracker: Equatable {
    let acceptanceID: String
    let suggestionID: String
    let appBundleIdentifier: String
    let fieldIdentity: FocusedFieldIdentity
    let requestMode: String
    let acceptedText: String
    let acceptedAt: Date
    let profile: CompatibilityProfile
    var deletedWithinTwoSeconds: Bool = false
}

private extension CompletionActivationDecision {
    var blockReasonDescription: String {
        switch self {
        case .allow:
            return "allowed"
        case let .block(reason):
            return reason.rawValue
        }
    }
}
