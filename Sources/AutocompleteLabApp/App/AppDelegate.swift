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
    private let llamaServerHost: LlamaServerProcessHost
    private lazy var personalHistoryController = PersonalHistoryController()
    private lazy var statusMenuHost = StatusMenuHost(
        appDelegate: self,
        personalHistory: personalHistoryController
    )
    private let ghostKeyboardInstallerHost = GhostKeyboardInstallerHost()

    // Screen Memory: capture engine, memory-only (nothing persisted yet —
    // Phase 3 of docs/plans/screen-memory.md), on by default per the
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
        suggestionsGate: Self.suggestionsGate
    )

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
        self.llamaServerHost = LlamaServerProcessHost(port: launchMode.llamaServerPort)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        llamaServerHost.start()
        if launchMode.allowsDailyDriverMutation {
            registerAsLoginItemIfNeeded()
            ghostKeyboardInstallerHost.installOrUpdateIfNeeded()
            // Any production launch means the brain is wanted again: lift the
            // keyboard watchdog's stay-quiet flag from a deliberate quit.
            UserDefaults(suiteName: TildeSettings.keyboardSuiteName)?
                .removeObject(forKey: "GhostBrainQuietQuit")
        }
        DiagnosticsLog.shared.record(
            launchMode == .production ? "launch" : "release-proof-launch",
            metadata: [:]
        )
        if launchMode == .production {
            // Runs last: everything the daily driver actually needs (socket,
            // login item, keyboard install) is already underway, so a modal
            // the user might sit on for a while never delays those. See the
            // method doc for why this shows on every launch rather than only
            // the very first one.
            presentScreenPermissionPromptIfNeeded()
        }
    }

    /// The discoverability fix for the bug that motivated requiring this
    /// permission: Screen Memory used to be reachable only behind a dev flag
    /// that a menu-bar (`LSUIElement`) app cannot pick up from a Terminal
    /// shell's environment, so the owner had no UI to find at all and 44
    /// consecutive captures logged as silently skipped. Now Screen Memory is
    /// shipped, on by default, and required (2026-08-16 owner directive:
    /// Tilde withholds suggestions entirely without this permission — see
    /// `AppDelegate.suggestionsGate` and `GhostBrainServerHost`), so the
    /// equivalent failure mode is a user who never sees a system permission
    /// dialog because nothing ever asked, and experiences a silently
    /// suggestion-less app with no idea why — this makes the ask itself
    /// impossible to miss.
    ///
    /// Shown on every production launch while the toggle is on and the
    /// permission is still missing, not merely once: the point of this
    /// screen is maximum discoverability, and a one-time flag risks the same
    /// invisibility bug in a new shape (dismissed once during a confused
    /// first run, then never surfaced with equal prominence again). A user
    /// who wants it to stop asking has a one-click, equally discoverable
    /// off-ramp: turn the "Screen Memory (local only)" menu toggle off,
    /// which also stops this prompt (see the `screenMemoryEnabled` guard
    /// below) — that is a deliberate, plainly-labeled choice to run without
    /// suggestions, not a way to keep suggestions while dodging the ask.
    private func presentScreenPermissionPromptIfNeeded() {
        guard TildeSettings().screenMemoryEnabled else { return }
        guard !ScreenRecordingPermission.isGranted() else { return }

        let alert = NSAlert()
        alert.messageText = "Tilde needs Screen Recording access to suggest"
        alert.informativeText = """
        Tilde predicts from what's on your screen, using on-device OCR — not just what you type — so it can understand what you're replying to or referencing. That's the whole idea behind Tilde, so without this permission Tilde will not suggest anything at all.

        Screen text never leaves this Mac. It is redacted for secrets before it is used, and you can turn Screen Memory off, exclude specific apps, or delete everything at any time from the Tilde menu.

        You can grant access now, or open System Settings directly. Either way, this is not something Tilde did wrong — macOS just needs you to say yes once.
        """
        alert.addButton(withTitle: "Grant Screen Recording Access")
        alert.addButton(withTitle: "Open System Settings…")
        alert.addButton(withTitle: "Not Now")

        let choice: String
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            ScreenRecordingPermission.request()
            choice = "requested"
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(ScreenRecordingPermission.systemSettingsURL)
            choice = "settings-opened"
        default:
            choice = "dismissed"
        }
        DiagnosticsLog.shared.record("screen-permission-prompt", metadata: ["status": choice])
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
    /// apps — only `presentScreenPermissionPromptIfNeeded` (launch) and the
    /// user's own menu click do that.
    func applicationDidBecomeActive(_ notification: Notification) {
        guard launchMode == .production else { return }
        statusMenuHost.refreshScreenMemoryStatus()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Deaths must leave a trace: an unexplained brainless morning
        // (2026-08-04) had no shutdown line to tell crash from quit. Flush,
        // or the exit races the log queue and the line never lands.
        DiagnosticsLog.shared.record("shutdown", metadata: [:])
        DiagnosticsLog.shared.flush()
        if launchMode == .production { ghostBrainServerHost.stop() }
        llamaServerHost.stop()
        if let frontmostAppObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(frontmostAppObserver)
        }
        windowIdentityPollTimer?.invalidate()
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
            self?.pollFrontWindowIdentityForScreenMemory()
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
        guard FileManager.default.fileExists(atPath: GhostBrainServerHost.socketPath) else {
            return "⚠️ Brain socket missing — quit and reopen"
        }
        return llamaServerHost.snapshot.menuLine
    }

    /// The keyboard is only as smart as this app is alive: register as a login
    /// item once. The user keeps control in System Settings › Login Items.
    /// Status is logged every launch and failures are logged, never swallowed —
    /// a silently-failed registration is how mornings start brainless.
    private func registerAsLoginItemIfNeeded() {
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
