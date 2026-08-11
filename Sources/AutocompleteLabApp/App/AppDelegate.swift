import AppKit
import AutocompleteLabCore
import ServiceManagement

/// Tilde's brain-caretaker. The product is the InlineGhostIME input
/// method; this app exists to run its engines and utilities:
///   - GhostBrainServerHost: the unix socket the keyboard talks to
///   - LlamaServerProcessHost + LlamaCompletionEngine: the Gemma engine
///   - GhostKeyboardInstallerHost: installs/updates the keyboard itself
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let llamaServerHost = LlamaServerProcessHost()
    private lazy var statusMenuHost = StatusMenuHost(appDelegate: self)
    private let ghostKeyboardInstallerHost = GhostKeyboardInstallerHost()

    // Phrase continuations go to the llama/Gemma engine. Mid-word completion
    // belongs only to the keyboard's system spell-checker path.
    private lazy var ghostBrainServerHost = GhostBrainServerHost(
        engineProvider: { [weak self] in
            guard let self else { return UnavailableCompletionEngine(reason: "app shutting down") }
            let llama = self.llamaServerHost
            guard llama.isHealthy else {
                return UnavailableCompletionEngine(reason: "llama engine unavailable")
            }
            return LlamaCompletionEngine(baseURL: llama.baseURL)
        }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Two instances fight over the ghost socket and double the engine's
        // memory — the older instance wins, this one bows out.
        let me = NSRunningApplication.current
        let twins = NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? ""
        ).filter { $0.processIdentifier != me.processIdentifier }
        if !twins.isEmpty {
            DiagnosticsLog.shared.record("duplicate-instance-exit", metadata: [:])
            NSApp.terminate(nil)
            return
        }

        // Menu-bar agents get auto-terminated unless they say otherwise; the
        // keyboard is only as smart as this process is alive.
        ProcessInfo.processInfo.disableAutomaticTermination("Tilde serves the keyboard")

        statusMenuHost.start()
        ghostBrainServerHost.start()
        llamaServerHost.start()
        registerAsLoginItemIfNeeded()
        ghostKeyboardInstallerHost.installOrUpdateIfNeeded()
        // Any launch means the brain is wanted again: lift the keyboard
        // watchdog's stay-quiet flag from a previous deliberate quit.
        UserDefaults(suiteName: Self.keyboardDefaultsSuite)?
            .removeObject(forKey: "GhostBrainQuietQuit")
        DiagnosticsLog.shared.record("launch", metadata: [:])
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Deaths must leave a trace: an unexplained brainless morning
        // (2026-08-04) had no shutdown line to tell crash from quit. Flush,
        // or the exit races the log queue and the line never lands.
        DiagnosticsLog.shared.record("shutdown", metadata: [:])
        DiagnosticsLog.shared.flush()
        llamaServerHost.stop()
        ghostBrainServerHost.stop()
    }

    /// The keyboard's own defaults domain — the one channel the app and the
    /// IME process share.
    static let keyboardDefaultsSuite = "bar.r3d.inputmethod.InlineGhost"

    /// One line for the status menu: which engine is answering. Honest by
    /// rule — the app may fail, but never silently. The personal/generic
    /// distinction surfaces the worst silent failure (identity loss).
    func engineStatusLine() -> String {
        guard FileManager.default.fileExists(atPath: GhostBrainServerHost.socketPath) else {
            return "⚠️ Brain socket missing — quit and reopen"
        }
        guard llamaServerHost.isHealthy else {
            return "Engine: starting…"
        }
        let personal = RuntimeSetting.string("MODEL_PATH") != nil
        return personal ? "Engine: Personal Gemma (ready)" : "Engine: Generic Gemma (ready)"
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
