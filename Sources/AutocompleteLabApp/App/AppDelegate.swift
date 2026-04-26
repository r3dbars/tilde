import AppKit
import AutocompleteLabCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let accessibilityClient = AccessibilityClient()
    private let profileStore = CompatibilityProfileStore.mvp
    private let activationPolicy = CompletionActivationPolicy()
    private let triggerPolicy = SuggestionTriggerPolicy()
    private let modelRuntimeBundle = AppModelRuntimeFactory.makeRuntime()
    private var modelRuntime: any ModelRuntime {
        modelRuntimeBundle.runtime
    }
    private lazy var engine: any CompletionEngine = RuntimeBackedCompletionEngine(runtime: modelRuntime)
    private lazy var insertionEngine = InsertionEngine(accessibilityClient: accessibilityClient)
    private let keyboardRouter = KeyboardActionRouter()
    private let keyboardCapturePolicy = KeyboardCapturePolicy()
    private let insertionVerification = InsertionVerification()
    private let wordCompletionRanker = WordCompletionCandidateRanker()
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
    private var runtimeWarmTask: Task<Void, Never>?
    private var suggestionRequestGate = SuggestionRequestGate()
    private var suggestionBlockLogGate = SuggestionBlockLogGate()
    private var currentCompletionRequest: CompletionRequest?
    private var currentSuggestionID: String?
    private var currentSuggestionRequestMode: CompletionRequestMode?
    private var currentSuggestionTextBeforeCursor: String?
    private var currentSuggestionDisplayedText: String?
    private var recentAcceptedWords: [String] = []
    private var suppressKeyUntil: [AutocompleteKey: Date] = [:]
    private var lastStatusLine: String?
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
                modelDirectoryPath: modelDirectoryPath
            )
        }
        startPolling()
    }

    func applicationWillTerminate(_ notification: Notification) {
        DiagnosticsLog.shared.record("terminate")
        debounceTask?.cancel()
        insertionVerificationTask?.cancel()
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
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
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
                "readinessStage": report.stage.rawValue,
                "readinessAction": report.action.rawValue
            ]
        )
    }

    private func refreshRuntimeChrome() {
        runtimeMenuItem?.title = "Model: \(modelRuntimeBundle.bootstrapPlan.preferredAsset.model.rawValue) • \(runtimeReadinessReport.summary)"
        settingsWindow.refresh(
            isTrusted: accessibilityClient.isTrusted,
            runtimeReport: runtimeReadinessReport,
            modelDirectoryPath: modelDirectoryPath
        )
    }

    private var runtimeReadinessReport: RuntimeReadinessReport {
        modelRuntimeBundle.bootstrapPlan.readinessReport(for: currentRuntimeState)
    }

    private var modelDirectoryPath: String {
        modelRuntimeBundle.modelDirectoryURL.path
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

        guard let context = accessibilityClient.focusedTextContext(
            allowDescendantTextFallback: profile.allowsDescendantTextFallback
        ), !context.isSecure else {
            clearFocusedFieldState()
            currentProfile = profile
            hideSuggestion()
            return
        }

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

        let renderMode = RenderModePlan.effectiveMode(
            for: profile,
            supportsInlineSuggestions: context.capabilities.supportsInlineSuggestions,
            hasMirrorAnchor: context.elementRect != nil || context.windowRect != nil
        )

        guard let renderMode else {
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

        if shouldSuppressDetachedSuggestion(
            profile: profile,
            context: context,
            renderMode: renderMode
        ) {
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
            recordRawAcceptance(action: action, acceptedText: acceptedText)
            if suggestionSession.hasVisibleSuggestion {
                refreshVisibleSuggestion()
            } else {
                hideSuggestion(reason: "accepted-next-word-final")
            }
            scheduleInsertionVerification(acceptedText: acceptedText, baseline: verificationBaseline)
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
            recordRawAcceptance(action: action, acceptedText: acceptedText)
            hideSuggestion(reason: "accepted-all")
            scheduleInsertionVerification(acceptedText: acceptedText, baseline: verificationBaseline)
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
            requestMode: currentSuggestionRequestMode
        )
    }

    private func scheduleInsertionVerification(
        acceptedText: String,
        baseline: InsertionVerificationBaseline?
    ) {
        guard let baseline else {
            return
        }

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
                outcome: "verified"
            )
        }
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

        if requestMode == .wordCompletion,
           let fastSuggestion = wordCompletionRanker.suggestion(
               for: context.textBeforeCursor,
               recentWords: recentAcceptedWords
           ) {
            let screenshotPath = captureTraceScreenshot(
                near: context.elementRect ?? context.windowRect ?? context.caretRect,
                suggestionID: suggestionID
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

        debounceTask = Task { [engine, requestTicket, fieldIdentity] in
            let renderDelay = renderMode == .inlineAdjacent ? delayMilliseconds : max(delayMilliseconds, 120)
            try? await Task.sleep(for: .milliseconds(renderDelay))
            guard !Task.isCancelled else {
                return
            }

            do {
                let suggestion = try await engine.suggestion(for: request)
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
                    let screenshotPath = self.captureTraceScreenshot(
                        near: context.elementRect ?? context.windowRect ?? context.caretRect,
                        suggestionID: suggestionID
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
        let anchorRect = RenderModePlan.anchorRect(
            for: renderMode,
            caretRect: context.caretRect,
            elementRect: context.elementRect,
            windowRect: context.windowRect
        )

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
        lastTextLineRect = context.textLineRect
        lastClippingRect = context.elementRect ?? context.windowRect
        lastTextStyle = context.textStyle
        lastRenderMode = renderMode
        suggestionPanel.show(
            text: suggestion.visibleText,
            near: anchorRect,
            alignedTo: renderMode == .inlineAdjacent ? context.textLineRect : nil,
            boundedBy: context.elementRect ?? context.windowRect,
            style: context.textStyle,
            renderMode: renderMode
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
                "effectiveRenderMode": renderMode.rawValue,
                "visibleChars": String(suggestion.visibleText.count)
            ]
        )
        recordSuggestionEvent(
            "suggestion-presented",
            context: context,
            profile: profile,
            metadata: [
                "effectiveRenderMode": renderMode.rawValue,
                "requestMode": request.mode.rawValue,
                "visibleChars": String(suggestion.visibleText.count),
                "suggestionID": suggestionID,
                "latencyMilliseconds": String(latencyMilliseconds)
            ]
        )
        startKeyboardEventTapIfPossible()
    }

    private func captureTraceScreenshot(near rect: CGRect?, suggestionID: String) -> String {
        guard RawAutocompleteTraceLog.shared.screenshotTracingEnabled,
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
            return screenshotURL.path
        } catch {
            return ""
        }
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

    private func recordRawAcceptance(action: KeyboardAction, acceptedText: String) {
        guard let profile = currentProfile else {
            return
        }

        RawAutocompleteTraceLog.shared.recordAcceptance(
            action: action.diagnosticName,
            appBundleIdentifier: profile.bundleIdentifier,
            acceptedText: acceptedText,
            remainingVisibleText: suggestionSession.visibleSuggestion?.visibleText,
            suggestionID: currentSuggestionID ?? "",
            fieldIdentity: currentFieldIdentity?.traceDescription ?? "",
            requestMode: currentSuggestionRequestMode?.rawValue ?? ""
        )
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

        let anchorRect = RenderModePlan.anchorRect(
            for: renderMode,
            caretRect: context.caretRect,
            elementRect: context.elementRect,
            windowRect: context.windowRect
        )

        guard let anchorRect else {
            return
        }

        lastCaretRect = anchorRect
        lastTextLineRect = context.textLineRect
        lastClippingRect = context.elementRect ?? context.windowRect
        lastTextStyle = context.textStyle
        lastRenderMode = renderMode
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
        let words = text
            .split(whereSeparator: { !$0.isLetter })
            .map { String($0).lowercased() }
            .filter { $0.count >= 3 }

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
            hideSuggestion(reason: "stale-text-changed")
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

        diagnosticsWindow.show(
            diagnostics: accessibilityClient.focusedTextDiagnostics(
                allowDescendantTextFallback: profile?.allowsDescendantTextFallback == true
            ),
            profile: profile,
            compatibilityStatus: compatibilityStatus,
            appEnabled: appEnabled,
            appTrusted: accessibilityClient.isTrusted,
            runtimeReport: runtimeReadinessReport,
            modelDirectoryPath: modelDirectoryPath,
            recentEvents: DiagnosticsLog.shared.recentLines(limit: 24),
            traceSummary: RawAutocompleteTraceLog.shared.summary(),
            recentTraceEvents: RawAutocompleteTraceLog.shared.recentEvents(limit: 48),
            tracePath: RawAutocompleteTraceLog.shared.path,
            tracingPaused: RawAutocompleteTraceLog.shared.isPaused,
            refreshAction: { [weak self] in
                self?.showDiagnostics()
            },
            toggleTracingAction: { [weak self] in
                self?.toggleTracing()
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
        RawAutocompleteTraceLog.shared.setPaused(nextPaused)
        DiagnosticsLog.shared.record(
            "trace-control",
            metadata: ["paused": String(nextPaused)]
        )
        showDiagnostics()
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
    let requestMode: CompletionRequestMode?
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
