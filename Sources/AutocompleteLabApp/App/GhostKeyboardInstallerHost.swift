import AppKit
import Carbon
import Foundation

/// Installs the bundled InlineGhostIME input method on launch: copies it from
/// Contents/Library into ~/Library/Input Methods when missing or outdated,
/// registers it with Text Input Services, and (first install only) tells the
/// user the one step macOS reserves for them — adding the keyboard in System
/// Settings. The bundled input method remains disabled until the user enables it.
final class GhostKeyboardInstallerHost {

    private static let bundledPathInApp = "Contents/Library/InlineGhostIME.app"
    private static let bundleIdentifier = "bar.r3d.inputmethod.InlineGhost"
    private static let executableName = "InlineGhostIME"
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

        do {
            if try Self.installIfNeeded(bundled: bundled, installed: installed) {
                DiagnosticsLog.shared.record("ime-installed", metadata: ["firstInstall": String(firstInstall)])
                // Live IME picks up the new binary on its next relaunch.
                NSWorkspace.shared.runningApplications
                    .filter { $0.bundleIdentifier == Self.bundleIdentifier }
                    .forEach { $0.terminate() }
            }
        } catch {
            DiagnosticsLog.shared.record("ime-install-failed", metadata: [:])
            return
        }

        // Registration is wiped whenever TextInputMenuAgent restarts — re-run
        // every launch; it is idempotent.
        TISRegisterInputSource(installed as CFURL)

        if firstInstall {
            promptToEnableKeyboard()
        }
    }

    /// Builds the replacement completely before swapping it into the live path.
    /// `replaceItemAt` keeps the old bundle in place if replacement fails.
    @discardableResult
    static func installIfNeeded(
        bundled: URL,
        installed: URL,
        fileManager: FileManager = .default
    ) throws -> Bool {
        try validateInputMethod(at: bundled, fileManager: fileManager)

        let installedExists = fileManager.fileExists(atPath: installed.path)
        if installedExists,
           (try? validateInputMethod(at: installed, fileManager: fileManager)) != nil,
           !bundledIsNewer(bundled: bundled, installed: installed, fileManager: fileManager) {
            return false
        }

        let parent = installed.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        let staging = parent.appendingPathComponent(".InlineGhostIME.install-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: staging) }

        try fileManager.copyItem(at: bundled, to: staging)
        try validateInputMethod(at: staging, fileManager: fileManager)

        if installedExists {
            _ = try fileManager.replaceItemAt(installed, withItemAt: staging)
        } else {
            try fileManager.moveItem(at: staging, to: installed)
        }
        return true
    }

    private static func validateInputMethod(at app: URL, fileManager: FileManager) throws {
        let infoURL = app.appendingPathComponent("Contents/Info.plist")
        let data = try Data(contentsOf: infoURL)
        guard let info = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              info["CFBundleIdentifier"] as? String == bundleIdentifier,
              info["CFBundleExecutable"] as? String == executableName else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let executable = app.appendingPathComponent("Contents/MacOS/\(executableName)")
        guard fileManager.isExecutableFile(atPath: executable.path) else {
            throw CocoaError(.fileReadNoSuchFile)
        }
    }

    private static func bundledIsNewer(
        bundled: URL,
        installed: URL,
        fileManager: FileManager
    ) -> Bool {
        func binaryDate(_ app: URL) -> Date {
            let binary = app.appendingPathComponent("Contents/MacOS/\(executableName)")
            return (try? fileManager.attributesOfItem(atPath: binary.path)[.modificationDate] as? Date)
                .flatMap { $0 } ?? .distantPast
        }
        return binaryDate(bundled) > binaryDate(installed)
    }

    /// The one step macOS reserves for the user (TISEnableInputSource does not
    /// persist without consent): add the keyboard in System Settings.
    private func promptToEnableKeyboard() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "One step to turn on Tilde's keyboard"
            alert.informativeText = """
            Tilde types its suggestions through a macOS keyboard called \
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
