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
    private let suggestionPanel = SuggestionPanelController()
    private let diagnosticsWindow = DiagnosticsWindowController()
    private lazy var settingsWindow = SettingsWindowController { [weak self] in
        self?.requestAccessibilityPermission()
    }

    private var statusItem: NSStatusItem?
    private var statusMenuItem: NSMenuItem?
    private var runtimeMenuItem: NSMenuItem?
    private var toggleAppMenuItem: NSMenuItem?
    private var pollTimer: Timer?
    private var keyboardEventTap: KeyboardEventTap?
    private var suggestionSession = SuggestionSession()
    private var lastCaretRect: CGRect?
    private var lastTextLineRect: CGRect?
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
    private var currentCompletionRequest: CompletionRequest?
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
            return
        }

        lastTextSnapshot = snapshot
        invalidatePendingSuggestionRequest()

        guard profile.canPresentSuggestions else {
            recordSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                metadata: [
                    "reason": "profile-diagnostics-only"
                ]
            )
            hideSuggestion()
            return
        }

        let runtimeReport = runtimeReadinessReport
        guard runtimeReport.allowsSuggestions else {
            recordSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
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
            recordSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                metadata: [
                    "reason": activationDecision.blockReasonDescription
                ]
            )
            hideSuggestion()
            return
        }

        guard context.capabilities.supportsInlineSuggestions || profile.renderMode == .floatingMirror else {
            recordSuggestionEvent(
                "suggestion-blocked",
                context: context,
                profile: profile,
                metadata: [
                    "reason": "missing-inline-capabilities"
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
            return
        }

        scheduleSuggestion(
            context: context,
            profile: profile,
            appBundleIdentifier: frontmostApp.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            delayMilliseconds: delayMilliseconds
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
            return true
        }

        let action = keyboardRouter.action(
            for: key,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion
        )

        switch action {
        case .acceptNextWord:
            guard currentProfile?.supportsOneWordAcceptance == true else {
                return false
            }

            let verificationBaseline = insertionVerificationBaseline()
            guard let acceptedText = suggestionSession.nextWordAcceptance(),
                  insertAcceptedText(acceptedText) else {
                return false
            }

            suggestionSession.commitNextWordAcceptance(acceptedText)
            recordAcceptedText(acceptedText)
            refreshVisibleSuggestion()
            scheduleInsertionVerification(acceptedText: acceptedText, baseline: verificationBaseline)
            suppressKey(key)
            return true

        case .acceptAllVisible:
            guard currentProfile?.supportsFullAcceptance == true else {
                return false
            }

            let verificationBaseline = insertionVerificationBaseline()
            guard let acceptedText = suggestionSession.allVisibleAcceptance(),
                  insertAcceptedText(acceptedText) else {
                return false
            }

            suggestionSession.commitAllVisibleAcceptance(acceptedText)
            recordAcceptedText(acceptedText)
            hideSuggestion()
            scheduleInsertionVerification(acceptedText: acceptedText, baseline: verificationBaseline)
            suppressKey(key)
            return true

        case .dismiss:
            suppressCurrentField(reason: "escape")
            hideSuggestion()
            suppressKey(key)
            return true

        case .passThrough:
            return false
        }
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
            profile: profile
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
                suppressCurrentField(reason: "insert-verification-failed")
                hideSuggestion()
                return
            }
        }
    }

    private func scheduleSuggestion(
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity,
        delayMilliseconds: Int
    ) {
        lastRequestedTextBeforeCursor = context.textBeforeCursor

        let request = CompletionRequest(
            textBeforeCursor: context.textBeforeCursor,
            textAfterCursor: context.textAfterCursor,
            appBundleIdentifier: appBundleIdentifier
        )
        currentCompletionRequest = request
        let requestTicket = suggestionRequestGate.issue(request: request)

        debounceTask = Task { [engine, requestTicket, fieldIdentity] in
            let renderDelay = profile.renderMode == .inlineAdjacent ? delayMilliseconds : max(delayMilliseconds, 120)
            try? await Task.sleep(for: .milliseconds(renderDelay))
            guard !Task.isCancelled else {
                return
            }

            do {
                let suggestion = try await engine.suggestion(for: request)
                await MainActor.run {
                    guard self.suggestionRequestGate.allows(
                        requestTicket,
                        currentRequest: self.currentCompletionRequest
                    ), self.currentFieldIdentity == fieldIdentity else {
                        return
                    }

                    let anchorRect = context.caretRect ?? (profile.renderMode == .floatingMirror ? context.elementRect ?? context.windowRect : nil)
                    guard let suggestion, !suggestion.isEmpty else {
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

                    guard let anchorRect else {
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

                    self.suggestionSession.present(suggestion)
                    self.lastCaretRect = anchorRect
                    self.lastTextLineRect = context.textLineRect
                    self.lastTextStyle = context.textStyle
                    self.lastRenderMode = profile.renderMode
                    self.suggestionPanel.show(
                        text: suggestion.visibleText,
                        near: anchorRect,
                        alignedTo: profile.renderMode == .inlineAdjacent ? context.textLineRect : nil,
                        style: context.textStyle,
                        renderMode: profile.renderMode
                    )
                    self.recordSuggestionEvent(
                        "suggestion-presented",
                        context: context,
                        profile: profile,
                        metadata: [
                            "visibleChars": String(suggestion.visibleText.count)
                        ]
                    )
                    self.startKeyboardEventTapIfPossible()
                }
            } catch {
                await MainActor.run {
                    self.hideSuggestion()
                }
            }
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

    private func refreshVisibleSuggestion() {
        guard let suggestion = suggestionSession.visibleSuggestion,
              let caretRect = lastCaretRect else {
            hideSuggestion()
            return
        }

        suggestionPanel.show(
            text: suggestion.visibleText,
            near: caretRect,
            alignedTo: lastTextLineRect,
            style: lastTextStyle,
            renderMode: lastRenderMode ?? .inlineAdjacent
        )
    }

    private func recordAcceptedText(_ acceptedText: String) {
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

    private func hideSuggestion() {
        suggestionSession.dismiss()
        lastCaretRect = nil
        lastTextLineRect = nil
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
    }

    private func clearFocusedFieldState() {
        invalidatePendingSuggestionRequest()

        if let currentFieldIdentity {
            suppressedFieldIdentities.remove(currentFieldIdentity)
        }

        currentFieldIdentity = nil
        lastTextSnapshot = nil
        lastRequestedTextBeforeCursor = nil
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
            recentEvents: DiagnosticsLog.shared.recentLines(limit: 24)
        )
    }

    @objc
    private func toggleCurrentApp() {
        guard let app = accessibilityClient.frontmostApplication(),
              profileStore.allows(bundleIdentifier: app.bundleIdentifier) else {
            return
        }

        if disabledBundleIdentifiers.contains(app.bundleIdentifier) {
            disabledBundleIdentifiers.remove(app.bundleIdentifier)
        } else {
            disabledBundleIdentifiers.insert(app.bundleIdentifier)
            hideSuggestion()
        }

        persistDisabledApps()
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
