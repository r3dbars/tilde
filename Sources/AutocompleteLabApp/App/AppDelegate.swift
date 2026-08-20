import AppKit
import AutocompleteLabCore
import CoreGraphics
import ServiceManagement

enum TildeLaunchMode: Equatable {
    case production
    case releaseProof

    init?(arguments: [String]) {
        switch Array(arguments.dropFirst()) {
        case []: self = .production
        case ["--release-proof"]: self = .releaseProof
        default: return nil
        }
    }

    var allowsDailyDriverMutation: Bool { self == .production }

    var llamaServerPort: Int {
        switch self {
        case .production: 17_872
        case .releaseProof: 17_873
        }
    }
}

enum TildeInvocation: Equatable {
    case application(TildeLaunchMode)
    case personalBrainStatusJSON
    case replayEvalJSON(limit: Int)
    case redactionEvalJSON(corpusPath: String)

    init?(arguments: [String]) {
        let rest = Array(arguments.dropFirst())
        if rest.isEmpty { self = .application(.production); return }
        if rest == ["--release-proof"] { self = .application(.releaseProof); return }
        if rest == ["--personal-brain-status-json"] { self = .personalBrainStatusJSON; return }
        if rest == ["--replay-eval-json"] {
            self = .replayEvalJSON(limit: PersonalReplayEval.defaultLimit)
            return
        }
        if rest.count == 3, rest[0] == "--replay-eval-json", rest[1] == "--limit",
           let limit = Int(rest[2]), limit > 0 {
            self = .replayEvalJSON(limit: limit)
            return
        }
        if rest.count == 2, rest[0] == "--redaction-eval-json" {
            self = .redactionEvalJSON(corpusPath: rest[1])
            return
        }
        return nil
    }
}

/// Tilde's brain-caretaker. The product is the InlineGhostIME input
/// method; this app exists to run its engines and utilities:
///   - GhostBrainServerHost: the unix socket the keyboard talks to
///   - LlamaServerProcessHost + LlamaCompletionEngine: the Gemma engine
///   - GhostKeyboardInstallerHost: installs/updates the keyboard itself
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let launchMode: TildeLaunchMode
    private let modelManager: ModelManager
    private let llamaServerHost: LlamaServerProcessHost
    private lazy var personalHistoryController = PersonalHistoryController()
    private lazy var statusMenuHost = StatusMenuHost(
        appDelegate: self,
        personalHistory: personalHistoryController
    )
    private let ghostKeyboardInstallerHost = GhostKeyboardInstallerHost()
    private var keyboardInstallResult: GhostKeyboardInstallerHost.KeyboardInstallResult?
    private var setupWindow: TildeSetupWindowController?
    private var setupLaunchTimer: Timer?
    private var modelPreparationTask: Task<Void, Never>?

    // Screen Memory: normal capture state remains memory-only. Development
    // builds may persist an explicitly enabled, bounded raw OCR evaluation
    // corpus through LocalOCREvaluationStore. On by default per the
    // 2026-08-16 owner directive making Screen Memory a first-class,
    // required-permission feature rather than an opt-in. `enabled` reads
    // TildeSettings live on every trigger, so flipping the menu toggle off
    // takes effect on the very next trigger with nothing to keep in sync.
    // `excludedApps` is the SAME list Personal History uses, per the
    // covenant's "shared with Personal History" requirement.
    private lazy var screenCaptureService = ScreenCaptureService(
        enabled: { TildeSettings().screenMemoryEnabled },
        excludedApps: { TildeSettings().personalHistoryExcludedApps }
    )
    private var frontmostAppObserver: NSObjectProtocol?
    // Backstop for `frontmostAppObserver`: NSWorkspace only tells us when a
    // DIFFERENT app becomes frontmost, never when the focused window changes
    // within the SAME app (e.g. Cmd+`, clicking a different document window,
    // a new tab-window). This timer polls the true frontmost window's
    // identity — no new permission needed, `CGWindowListCopyWindowInfo`'s
    // layer/pid/window-number fields are unrestricted — and fires the same
    // window-changed trigger on any change, cross- or same-app alike.
    private var windowIdentityPollTimer: Timer?
    private var lastFrontWindowIdentity: FrontWindowIdentity?

    // Phrase continuations go to the llama/Gemma engine. Mid-word completion
    // belongs only to the keyboard's system spell-checker path.
    private lazy var ghostBrainServerHost = GhostBrainServerHost(
        runtime: llamaServerHost,
        personalHistory: personalHistoryController,
        sceneProvider: Self.sceneProvider(for: screenCaptureService),
        // A bare activity pulse only — see GhostBrainServerHost's doc comment.
        onCompletionActivity: Self.completionActivityHandler(for: screenCaptureService),
        onScreenMemoryEvent: Self.screenMemoryEventHandler(for: screenCaptureService),
        suggestionsGate: Self.suggestionsGate,
        personalSuggestionsGate: Self.personalSuggestionsGate,
        personalNextWordProvider: Self.personalNextWordProvider(for: personalHistoryController)
    )

    /// "Personal suggestions (experimental)" (`docs/plans/road-to-paid.md`
    /// Phase 3): both the feature toggle AND Personal History's own master
    /// toggle must be on — the menu only ever shows the experimental toggle
    /// while Personal History is enabled, but this gate re-checks both live
    /// on every completion request, the same discipline `suggestionsGate`
    /// applies to Screen Recording permission, so a toggle flipped mid-
    /// session takes effect on the very next request with nothing cached.
    private nonisolated static func personalSuggestionsGate() -> Bool {
        let settings = TildeSettings()
        return settings.personalHistoryEnabled && settings.personalSuggestionsServingEnabled
    }

    /// `nonisolated` for the same reason `sceneProvider`/
    /// `completionActivityHandler` are: the closure captures and calls an
    /// actor-isolated method (`PersonalHistoryController.
    /// personalNextWordPrediction`) from inside a `@MainActor` lazy-var
    /// initializer. Per-app exclusions are enforced on the other side of
    /// this closure, inside the controller — see its doc comment.
    private nonisolated static func personalNextWordProvider(
        for controller: PersonalHistoryController
    ) -> @Sendable ([String], String?) async -> PersonalNextWordPrediction? {
        { tailWords, appBundleIdentifier in
            await controller.personalNextWordPrediction(
                afterTailWords: tailWords,
                appBundleIdentifier: appBundleIdentifier
            )
        }
    }

    /// 2026-08-16 owner directive: Screen Recording permission is now
    /// required for Tilde to suggest at all — see `GhostBrainServerHost`'s
    /// `suggestionsGate` doc comment for why this returns `.silence`
    /// upstream rather than anything more drastic. `ScreenMemoryStatus`
    /// (Core, pure, tested) is the single source of truth this and
    /// `StatusMenuHost`'s status line both defer to, so the two can never
    /// disagree. Read fresh on every completion request (never cached), so
    /// this is deliberately a plain function, not a stored property
    /// capturing a snapshot at init time.
    private nonisolated static func suggestionsGate() -> Bool {
        ScreenMemoryStatus.evaluate(
            enabled: TildeSettings().screenMemoryEnabled,
            permissionGranted: ScreenRecordingPermission.isGranted()
        ).allowsSuggestions
    }

    /// `nonisolated` so the closure it returns has no ambiguous isolation of
    /// its own to infer — without this, a closure literal written inline
    /// inside a `@MainActor` class's lazy-var initializer that captures and
    /// calls an actor-isolated method fails to compile ("default argument
    /// cannot be both main actor-isolated and actor-isolated"), since the
    /// compiler cannot tell whether the closure belongs to `AppDelegate`'s
    /// MainActor or to `ScreenCaptureService`'s own actor.
    private nonisolated static func completionActivityHandler(
        for service: ScreenCaptureService
    ) -> @Sendable () -> Void {
        { Task { await service.noteCompletionActivity() } }
    }

    private nonisolated static func screenMemoryEventHandler(
        for service: ScreenCaptureService
    ) -> @Sendable (ScreenMemoryInputEvent) -> Void {
        { event in
            Task {
                switch event.kind {
                case .textFieldFocused:
                    _ = await service.noteTextFieldFocused(sessionIdentifier: event.sessionIdentifier)
                case .typingPaused:
                    _ = await service.noteTypingPaused(sessionIdentifier: event.sessionIdentifier)
                case .textFieldBlurred:
                    await service.noteTextFieldBlurred(sessionIdentifier: event.sessionIdentifier)
                }
            }
        }
    }

    /// Screen Memory plan Phase 2 PR 2b: the SAME settings gate
    /// `screenCaptureService`'s own `enabled` closure uses (see its doc
    /// comment) — a request must never surface screen context capture
    /// itself would refuse to have started. `GhostBrainServerHost` and
    /// `LlamaCompletionEngine` know nothing about `TildeSettings`; this is
    /// the one place that decision is made for the whole live-suggestion
    /// path. When the toggle is off, or Screen Recording permission was
    /// never granted (so `screenCaptureService` never produced a snapshot in
    /// the first place), `freshScene` naturally returns `nil` and the prompt
    /// falls back to plain autocomplete — degraded, not dead.
    private nonisolated static func sceneProvider(
        for service: ScreenCaptureService
    ) -> @Sendable (String?, String) async -> ScreenScene.Scene? {
        { appBundleIdentifier, fieldText in
            guard TildeSettings().screenMemoryEnabled else { return nil }
            return await service.freshScene(frontmostBundleID: appBundleIdentifier, fieldText: fieldText)
        }
    }

    init(launchMode: TildeLaunchMode = .production) {
        self.launchMode = launchMode
        let modelManager = ModelManager()
        self.modelManager = modelManager
        self.llamaServerHost = LlamaServerProcessHost(
            port: launchMode.llamaServerPort,
            modelFileProvider: { modelManager.verifiedInstalledModelFile() }
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if launchMode == .production, TildeInstallationLocation.requiresMove() {
            presentInstallLocationRepair()
            return
        }

        if launchMode == .production {
            // The process-held runtime lock makes this the only socket/model owner.
            guard ghostBrainServerHost.start() else {
                DiagnosticsLog.shared.record("duplicate-instance-exit", metadata: [:])
                NSApp.terminate(nil)
                return
            }
        }

        // Menu-bar agents get auto-terminated unless they say otherwise; the
        // keyboard is only as smart as this process is alive.
        ProcessInfo.processInfo.disableAutomaticTermination("Tilde serves the keyboard")

        if launchMode == .production {
            statusMenuHost.start()
            startObservingFrontmostAppForScreenMemory()
        } else if launchMode == .releaseProof
            && ProcessInfo.processInfo.environment["TILDE_SCREEN_MEMORY_DEV"] == "1"
        {
            // Screen Memory's power probe (script/capture_power_probe.sh,
            // Phase 1b) needs an isolated instance that actually fires
            // window-change captures. Production mode cannot be that
            // instance: launching a second production Tilde alongside the
            // owner's real daily driver hits the duplicate-instance guard
            // above and self-terminates before this line — by design, so a
            // probe run never touches the real app's socket. Release-proof
            // mode is already the isolated dev/proof lane (dedicated port,
            // no socket takeover attempt), so wiring the SAME window-change
            // observer production uses — gated behind an env var the probe
            // alone sets — lets the probe exercise the real trigger path. A
            // normal (non-probe) release-proof launch, which the release
            // network-egress gate depends on staying input-method-free, is
            // untouched: this env var is never set there.
            //
            // This checks the environment directly rather than through
            // TildeSettings: PR #357 (2026-08-16) deleted TildeSettings'
            // persisted `ScreenMemoryDevMode` / `TILDE_SCREEN_MEMORY_DEV`
            // gate entirely, since Screen Memory's capture engine itself is
            // now on-by-default in production and needs no dev flag to
            // enable it. The probe's need is narrower and unrelated to that
            // product gate — an ephemeral, session-only opt-in for wiring
            // observation into an otherwise-headless release-proof lane —
            // so it reads the environment variable directly instead of
            // resurrecting a persisted UserDefaults flag.
            startObservingFrontmostAppForScreenMemory()
            // The probe (script/capture_power_probe.sh) expects THIS launch
            // to trigger the system Screen Recording consent dialog on a
            // fresh, never-answered bundle. Production only asks via the
            // Settings toggle's confirmation flow
            // (StatusMenuHost.toggleScreenMemory), which this headless dev
            // lane never runs — without asking here, a fresh bundle could
            // sit at permission=false forever with nothing to prompt it.
            // request() is a no-op once the user has already answered for
            // this exact code signature, so this is safe to call every run.
            if !ScreenRecordingPermission.isGranted() {
                ScreenRecordingPermission.request()
            }
        }
        startModelPreparation()
        if launchMode.allowsDailyDriverMutation {
            registerAsLoginItemIfNeeded()
            keyboardInstallResult = ghostKeyboardInstallerHost.installOrUpdateIfNeeded()
            // Any production launch means the brain is wanted again: lift the
            // keyboard watchdog's stay-quiet flag from a deliberate quit.
            UserDefaults(suiteName: TildeSettings.keyboardSuiteName)?
                .removeObject(forKey: "GhostBrainQuietQuit")
        }
        DiagnosticsLog.shared.record(
            launchMode == .production ? "launch" : "release-proof-launch",
            metadata: [:]
        )
        if launchMode == .production { finishLaunchSetup() }
    }

    private func presentInstallLocationRepair() {
        let alert = NSAlert()
        alert.messageText = "Move Tilde to Applications"
        alert.informativeText = "Tilde needs to live in Applications so it can start with your Mac. Drag Tilde into Applications, then open it there."
        alert.addButton(withTitle: "Open Applications Folder")
        alert.runModal()
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications", isDirectory: true))
        NSApp.terminate(nil)
    }

    /// One of the three required Screen Recording permission checkpoints
    /// (2026-08-16 owner directive; the other two are launch and the menu's
    /// own `toggleScreenMemory`/`menuWillOpen`): macOS has no push
    /// notification for a Screen Recording TCC decision, so re-checking
    /// when Tilde becomes the frontmost app is the practical proxy — the
    /// common path back from granting access in System Settings is
    /// switching back to Tilde (or, for this `LSUIElement` menu-bar app,
    /// simply clicking its status item, which activates it before the menu
    /// opens). This only refreshes the already-built menu's status text; it
    /// never polls in a loop and never re-requests the system prompt on its
    /// own, so a user who denied access is not re-nagged just for switching
    /// apps. The setup window owns every user-facing permission action.
    func applicationDidBecomeActive(_ notification: Notification) {
        guard launchMode == .production else { return }
        statusMenuHost.refresh()
        setupWindow?.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Deaths must leave a trace: an unexplained brainless morning
        // (2026-08-04) had no shutdown line to tell crash from quit. Flush,
        // or the exit races the log queue and the line never lands.
        DiagnosticsLog.shared.record("shutdown", metadata: [:])
        DiagnosticsLog.shared.flush()
        LocalOCREvaluationStore.shared.flush()
        if launchMode == .production { ghostBrainServerHost.stop() }
        llamaServerHost.stop()
        if let frontmostAppObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(frontmostAppObserver)
        }
        windowIdentityPollTimer?.invalidate()
        setupLaunchTimer?.invalidate()
        modelPreparationTask?.cancel()
    }

    /// The window-change trigger: macOS already tells every app when a
    /// different app becomes frontmost, so Screen Memory needs no IME/socket
    /// changes to observe it — `NSWorkspace` gives it directly. This alone
    /// misses same-app window changes (see `windowIdentityPollTimer`'s doc
    /// comment), so a lightweight poll backs it up.
    private func startObservingFrontmostAppForScreenMemory() {
        frontmostAppObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [screenCaptureService] _ in
            Task { await screenCaptureService.noteWindowChanged() }
        }
        lastFrontWindowIdentity = Self.currentFrontWindowIdentity()
        windowIdentityPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollFrontWindowIdentityForScreenMemory() }
        }
    }

    /// Fires the window-changed trigger whenever the true frontmost window
    /// (by process + `CGWindowID`) differs from the last poll — this is what
    /// catches a same-app window switch that `NSWorkspace` cannot see.
    /// `ScreenCaptureService`'s own cadence cap (one capture per 5s) keeps a
    /// 1s poll interval cheap: most polls just update the identity and
    /// return without ever reaching ScreenCaptureKit.
    private func pollFrontWindowIdentityForScreenMemory() {
        let identity = Self.currentFrontWindowIdentity()
        guard identity != lastFrontWindowIdentity else { return }
        lastFrontWindowIdentity = identity
        Task { [screenCaptureService] in await screenCaptureService.noteWindowChanged() }
    }

    struct FrontWindowIdentity: Equatable {
        let ownerProcessIdentifier: pid_t
        let windowNumber: CGWindowID
    }

    /// The true frontmost on-screen window, system-wide, identified by owning
    /// process + window number — `CGWindowListCopyWindowInfo` documents its
    /// result as front-to-back ordered, so the first normal-layer (`0`)
    /// window found is frontmost. Deliberately does not request window
    /// names/titles: this only needs an identity to detect change, and
    /// nothing here reads or stores what the window is titled.
    private static func currentFrontWindowIdentity() -> FrontWindowIdentity? {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return nil }
        for info in list {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  let windowNumber = info[kCGWindowNumber as String] as? CGWindowID
            else { continue }
            return FrontWindowIdentity(ownerProcessIdentifier: pid, windowNumber: windowNumber)
        }
        return nil
    }

    /// One line for the status menu: which engine is answering. Honest by
    /// rule — the app may fail, but never silently. The personal/generic
    /// distinction surfaces the worst silent failure (identity loss).
    func engineStatusLine() -> String {
        switch modelManager.state {
        case .checking, .missing:
            return "Model: Gemma 4 E2B (checking…)"
        case let .downloading(receivedBytes, totalBytes):
            let percent = totalBytes > 0 ? Int((Double(receivedBytes) / Double(totalBytes)) * 100) : 0
            return "Model: Gemma 4 E2B (downloading \(min(100, max(0, percent)))%)"
        case .verifying:
            return "Model: Gemma 4 E2B (checking download…)"
        case let .failed(failure):
            return "⚠️ Model: \(Self.modelFailureMenuDescription(failure))"
        case .ready:
            break
        }
        guard FileManager.default.fileExists(atPath: GhostBrainServerHost.socketPath) else {
            return "⚠️ Brain socket missing — quit and reopen"
        }
        return llamaServerHost.snapshot.menuLine
    }

    func applicationState(now: Date = Date()) -> TildeApplicationState {
        let settings = TildeSettings()
        return TildeApplicationState.resolve(
            suggestionsEnabled: settings.suggestionsEnabled,
            pausedUntil: settings.pausedUntil,
            keyboardAvailable: ghostKeyboardInstallerHost.inputSourceStatus() != .missing,
            screenMemoryEnabled: settings.screenMemoryEnabled,
            screenRecordingGranted: ScreenRecordingPermission.isGranted(),
            model: modelManager.state,
            runtime: llamaServerHost.snapshot,
            socketAvailable: FileManager.default.fileExists(atPath: GhostBrainServerHost.socketPath),
            now: now
        )
    }

    func setupState() -> TildeSetupState {
        return TildeSetupState.resolve(
            keyboardInstallResult: keyboardInstallResult,
            inputSourceStatus: ghostKeyboardInstallerHost.inputSourceStatus(),
            screenRecordingGranted: ScreenRecordingPermission.isGranted(),
            runtime: llamaServerHost.snapshot,
            socketAvailable: FileManager.default.fileExists(atPath: GhostBrainServerHost.socketPath),
            model: modelManager.state,
            requireInitialInputSourceSelection: TildeSettings().setupVersion < TildeSettings.currentSetupVersion
        )
    }

    func setupRequired() -> Bool {
        let settings = TildeSettings()
        return settings.setupVersion < TildeSettings.currentSetupVersion
            || ghostKeyboardInstallerHost.inputSourceStatus() == .missing
            || !ScreenRecordingPermission.isGranted()
            || !modelManager.state.isReady
            || runtimeRequiresSetup
    }

    func showSetup() {
        if setupWindow == nil { setupWindow = TildeSetupWindowController(appDelegate: self) }
        setupWindow?.show()
    }

    func completeSetup() {
        guard case .ready = setupState() else { return }
        let settings = TildeSettings()
        settings.setupVersion = TildeSettings.currentSetupVersion
        statusMenuHost.refresh()
        setupWindow?.close()
    }

    func openKeyboardSettings() { ghostKeyboardInstallerHost.openKeyboardSettings() }

    @discardableResult
    func selectInputSourceIfAvailable() -> Bool {
        ghostKeyboardInstallerHost.selectInputSourceIfAvailable()
    }

    func inputSourceIsSelected() -> Bool {
        ghostKeyboardInstallerHost.inputSourceStatus() == .selected
    }

    func requestScreenRecordingAccess() {
        let settings = TildeSettings()
        settings.screenRecordingRequested = true
        ScreenRecordingPermission.request()
    }

    func openScreenRecordingSettings() {
        NSWorkspace.shared.open(ScreenRecordingPermission.systemSettingsURL)
    }

    func retrySetup() {
        switch setupState() {
        case .recoverableError(.keyboard), .needsKeyboard, .installingKeyboard:
            keyboardInstallResult = ghostKeyboardInstallerHost.installOrUpdateIfNeeded()
        case .recoverableError(.model), .downloadingModel, .verifyingModel:
            startModelPreparation()
        case .recoverableError(.runtime), .startingRuntime:
            llamaServerHost.start()
        case .needsInputSourceSelection:
            _ = selectInputSourceIfAvailable()
        case .needsScreenRecording, .ready:
            break
        }
        setupWindow?.refresh()
    }

    func modelState() -> ModelState { modelManager.state }

    func modelDescription() -> String { "Gemma 4 E2B · 3.43 GB" }

    func deleteModel() {
        modelPreparationTask?.cancel()
        llamaServerHost.stop()
        modelPreparationTask = Task { [weak self, modelManager] in
            await modelManager.deleteModelAndWait()
            guard let self, !Task.isCancelled else { return }
            TildeSettings().setupVersion = 0
            self.statusMenuHost.refresh()
            self.showSetup()
            self.startModelPreparation()
        }
    }

    @discardableResult
    func relaunchAfterScreenRecordingGrant() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            "while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.1; done; exec /usr/bin/open -n -F -- \"$1\"",
            "tilde-relaunch",
            Bundle.main.bundlePath,
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
            NSApp.terminate(nil)
            return true
        } catch {
            DiagnosticsLog.shared.record("setup-relaunch-failed", metadata: [:])
            return false
        }
    }

    private func finishLaunchSetup() {
        let settings = TildeSettings()
        guard settings.setupVersion < TildeSettings.currentSetupVersion || !modelManager.state.isReady else {
            setupLaunchTimer?.invalidate()
            setupLaunchTimer = nil
            return
        }
        let hasKeyboard = ghostKeyboardInstallerHost.inputSourceStatus() != .missing
        let hasPermission = ScreenRecordingPermission.isGranted()
        guard hasKeyboard, hasPermission, !settings.screenRecordingRequested else {
            setupLaunchTimer?.invalidate()
            setupLaunchTimer = nil
            showSetup()
            return
        }

        switch setupState() {
        case .ready:
            settings.setupVersion = TildeSettings.currentSetupVersion
            setupLaunchTimer?.invalidate()
            setupLaunchTimer = nil
            statusMenuHost.refresh()
        case .installingKeyboard, .downloadingModel, .verifyingModel, .startingRuntime:
            guard setupLaunchTimer == nil else { return }
            setupLaunchTimer = Timer.scheduledTimer(
                withTimeInterval: 0.5,
                repeats: true
            ) { [weak self] _ in
                Task { @MainActor in self?.finishLaunchSetup() }
            }
        case .needsKeyboard, .needsScreenRecording, .needsInputSourceSelection, .recoverableError:
            setupLaunchTimer?.invalidate()
            setupLaunchTimer = nil
            showSetup()
        }
    }

    private var runtimeRequiresSetup: Bool {
        switch llamaServerHost.snapshot {
        case .failed:
            return true
        case .ready:
            return !FileManager.default.fileExists(atPath: GhostBrainServerHost.socketPath)
        case .starting, .retrying:
            return false
        }
    }

    private func startModelPreparation() {
        modelManager.prepare()
        modelPreparationTask?.cancel()
        modelPreparationTask = Task { [weak self, modelManager] in
            await modelManager.waitUntilSettled()
            guard let self, !Task.isCancelled else { return }
            if modelManager.state.isReady { self.llamaServerHost.start() }
            self.statusMenuHost.refresh()
            self.setupWindow?.refresh()
            if self.launchMode == .production { self.finishLaunchSetup() }
        }
    }

    private static func modelFailureMenuDescription(_ failure: ModelFailure) -> String {
        switch failure {
        case .offline: "offline — try again"
        case .insufficientDiskSpace: "not enough disk space"
        case .serverRejectedRequest: "download unavailable"
        case .checksumMismatch: "download failed verification"
        case .invalidModel: "download is invalid"
        case .installationFailed: "couldn't install"
        }
    }

    /// The keyboard is only as smart as this app is alive: register as a login
    /// item once. The user keeps control in System Settings › Login Items.
    /// Status is logged every launch and failures are logged, never swallowed —
    /// a silently-failed registration is how mornings start brainless.
    private func registerAsLoginItemIfNeeded() {
        guard TildeSettings().launchAtLoginEnabled else {
            if SMAppService.mainApp.status != .notRegistered {
                do {
                    try SMAppService.mainApp.unregister()
                } catch {
                    DiagnosticsLog.shared.record(
                        "login-item-unregister-failed",
                        metadata: ["reason": error.localizedDescription]
                    )
                }
            }
            return
        }
        let service = SMAppService.mainApp
        if service.status == .notRegistered {
            do {
                try service.register()
            } catch {
                DiagnosticsLog.shared.record(
                    "login-item-register-failed",
                    metadata: ["reason": error.localizedDescription]
                )
            }
        }
        DiagnosticsLog.shared.record(
            "login-item-status",
            metadata: ["status": Self.describe(service.status)]
        )
    }

    private static func describe(_ status: SMAppService.Status) -> String {
        switch status {
        case .notRegistered: return "notRegistered"
        case .enabled: return "enabled"
        case .requiresApproval: return "requiresApproval"
        case .notFound: return "notFound"
        @unknown default: return "unknown"
        }
    }
}
