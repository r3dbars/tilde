import AppKit
import Carbon
import Foundation

/// Installs the bundled InlineGhostIME input method on launch: copies it from
/// Contents/Library into ~/Library/Input Methods when missing or outdated,
/// registers it with Text Input Services, and (first install only) tells the
/// user the one step macOS reserves for them — adding the keyboard in System
/// Settings. Encodes the deployment facts from Sources/InlineGhostIME/README.md.
final class GhostKeyboardInstallerHost {

    private static let bundledPathInApp = "Contents/Library/InlineGhostIME.app"
    private static let installedPath = NSString(
        string: "~/Library/Input Methods/InlineGhostIME.app"
    ).expandingTildeInPath

    func installOrUpdateIfNeeded() {
        let bundled = URL(fileURLWithPath: Bundle.main.bundlePath).appendingPathComponent(Self.bundledPathInApp)
        guard FileManager.default.fileExists(atPath: bundled.path) else {
            return // dev builds without the packaged keyboard
        }
        let installed = URL(fileURLWithPath: Self.installedPath)
        let firstInstall = !FileManager.default.fileExists(atPath: installed.path)

        if firstInstall || Self.bundledIsNewer(bundled: bundled, installed: installed) {
            do {
                try? FileManager.default.removeItem(at: installed)
                try FileManager.default.createDirectory(
                    at: installed.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try FileManager.default.copyItem(at: bundled, to: installed)
                DiagnosticsLog.shared.record("ime-installed", metadata: ["firstInstall": String(firstInstall)])
            } catch {
                DiagnosticsLog.shared.record("ime-install-failed", metadata: [:])
                return
            }
            // Live IME picks up the new binary on its next relaunch.
            let running = NSWorkspace.shared.runningApplications
            running.filter { $0.bundleIdentifier == "bar.r3d.inputmethod.InlineGhost" }
                .forEach { $0.terminate() }
        }

        // Registration is wiped whenever TextInputMenuAgent restarts — re-run
        // every launch; it is idempotent.
        TISRegisterInputSource(installed as CFURL)

        if firstInstall {
            promptToEnableKeyboard()
        }
    }

    private static func bundledIsNewer(bundled: URL, installed: URL) -> Bool {
        func binaryDate(_ app: URL) -> Date {
            let binary = app.appendingPathComponent("Contents/MacOS/InlineGhostIME")
            return (try? FileManager.default.attributesOfItem(atPath: binary.path)[.modificationDate] as? Date)
                .flatMap { $0 } ?? .distantPast
        }
        return binaryDate(bundled) > binaryDate(installed)
    }

    /// The one step macOS reserves for the user (TISEnableInputSource does not
    /// persist without consent): add the keyboard in System Settings.
    private func promptToEnableKeyboard() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "One step to turn on SteadyType's keyboard"
            alert.informativeText = """
            SteadyType types its suggestions through a macOS keyboard called \
            InlineGhostIME. macOS asks that you add it yourself:

            1. System Settings → Keyboard → Input Sources → Edit… → +
            2. Search "inline", select InlineGhostIME, click Add
            3. Pick InlineGhostIME from the keyboard menu in the menu bar

            If it does not appear in the list yet, log out and back in once — \
            macOS scans for new keyboards at login.
            """
            alert.addButton(withTitle: "Open Keyboard Settings")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!
                )
            }
        }
    }
}
