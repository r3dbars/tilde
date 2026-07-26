import AppKit
import AutocompleteLabCore
import CoreGraphics
import ServiceManagement

/// SteadyType's brain-caretaker. The product is the InlineGhostIME input
/// method; this app exists to run its engines and utilities:
///   - GhostBrainServerHost: the unix socket the keyboard talks to
///   - LlamaServerProcessHost + LlamaCompletionEngine: the Gemma engine
///   - GhostScreenContextBridge + VisiblePageContextProvider: screen context
///   - GhostKeyboardInstallerHost: installs/updates the keyboard itself
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let visiblePageContextProvider = VisiblePageContextProvider()
    private let llamaServerHost = LlamaServerProcessHost()
    private lazy var ghostScreenContextBridge = GhostScreenContextBridge(provider: visiblePageContextProvider)
    private lazy var statusMenuHost = StatusMenuHost(appDelegate: self)
    private let ghostKeyboardInstallerHost = GhostKeyboardInstallerHost()

    // Phrase continuations go to the llama/Gemma engine when its server is
    // healthy; word completion belongs to the keyboard's dictionary layer, so
    // the server answers it with silence. No second model engine — llama-only
    // (owner decision, 2026-07-22).
    private lazy var ghostBrainServerHost = GhostBrainServerHost(
        engineProvider: { [weak self] in
            guard let self else { return UnavailableCompletionEngine(reason: "app shutting down") }
            let llama = self.llamaServerHost
            return ModeRoutedCompletionEngine(
                phraseEngine: LlamaCompletionEngine(baseURL: llama.baseURL),
                fallbackEngine: UnavailableCompletionEngine(reason: "llama engine unavailable"),
                phraseEngineIsHealthy: { llama.isHealthy },
                // Live-flippable: defaults write bar.r3d.steadytype ModelHandlesWordCompletions -bool true|false
                routeWordCompletions: { UserDefaults.standard.bool(forKey: "ModelHandlesWordCompletions") }
            )
        },
        screenContextResolver: { [bridge = ghostScreenContextBridge] app, field, text in
            bridge.context(
                appBundleIdentifier: app,
                fieldIdentity: field,
                textBeforeCursor: text,
                enabled: UserDefaults.standard.bool(forKey: "VisiblePageContextEnabled")
            )
        }
    )

    /// True only once this instance won the single-instance race and started
    /// its hosts. `NSApp.terminate` still fires `applicationWillTerminate` for
    /// the losing duplicate — whose teardown must not touch the primary's live
    /// socket or engine.
    private var startedServing = false

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
        startedServing = true

        // Menu-bar agents get auto-terminated unless they say otherwise; the
        // keyboard is only as smart as this process is alive.
        ProcessInfo.processInfo.disableAutomaticTermination("SteadyType serves the keyboard")

        statusMenuHost.start()
        ghostBrainServerHost.start()
        llamaServerHost.start()
        registerAsLoginItemIfNeeded()
        ghostKeyboardInstallerHost.installOrUpdateIfNeeded()
        DiagnosticsLog.shared.record("launch", metadata: [:])
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard startedServing else { return }
        llamaServerHost.stop()
        ghostBrainServerHost.stop()
    }

    /// One line for the status menu: which engine is answering. Honest by
    /// rule — the app may fail, but never silently. The personal/generic
    /// distinction surfaces the worst silent failure (identity loss).
    func engineStatusLine() -> String {
        guard ghostBrainServerHost.isServingKeyboard else {
            return "⚠️ Brain socket down — quit and reopen"
        }
        guard llamaServerHost.isHealthy else {
            return "Engine: starting…"
        }
        let personal = RuntimeSetting.string("MODEL_PATH") != nil
        return personal ? "Engine: Personal Gemma (ready)" : "Engine: Generic Gemma (ready)"
    }

    /// The keyboard is only as smart as this app is alive: register as a login
    /// item once. The user keeps control in System Settings › Login Items.
    private func registerAsLoginItemIfNeeded() {
        guard SMAppService.mainApp.status == .notRegistered else { return }
        try? SMAppService.mainApp.register()
    }
}
