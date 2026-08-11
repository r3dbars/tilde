import AppKit
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

/// Tilde's brain-caretaker. The product is the InlineGhostIME input
/// method; this app exists to run its engines and utilities:
///   - GhostBrainServerHost: the unix socket the keyboard talks to
///   - LlamaServerProcessHost + LlamaCompletionEngine: the Gemma engine
///   - GhostKeyboardInstallerHost: installs/updates the keyboard itself
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let launchMode: TildeLaunchMode
    private let llamaServerHost: LlamaServerProcessHost
    private lazy var statusMenuHost = StatusMenuHost(appDelegate: self)
    private let ghostKeyboardInstallerHost = GhostKeyboardInstallerHost()

    // Phrase continuations go to the llama/Gemma engine. Mid-word completion
    // belongs only to the keyboard's system spell-checker path.
    private lazy var ghostBrainServerHost = GhostBrainServerHost(runtime: llamaServerHost)

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

        if launchMode == .production { statusMenuHost.start() }
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
