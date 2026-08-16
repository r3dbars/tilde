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

    // Screen Memory, Phase 1a: capture engine only, memory-only, off by
    // default. `enabled`/`excludedApps` read TildeSettings live on every
    // trigger — the covenant's exclusion list is the SAME one Personal
    // History uses, per its "shared with Personal History" requirement.
    // `enabled` also requires the SAME dev flag that gates the menu controls
    // (StatusMenuHost) — otherwise a persisted `ScreenMemoryEnabled=true`
    // from an earlier dev session would keep capturing on later launches
    // with no visible toggle or status line to turn it back off.
    private lazy var screenCaptureService = ScreenCaptureService(
        enabled: { TildeSettings.screenMemoryDevModeEnabled && TildeSettings().screenMemoryEnabled },
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
        // A bare activity pulse only — see GhostBrainServerHost's doc comment.
        onCompletionActivity: Self.completionActivityHandler(for: screenCaptureService)
    )

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
