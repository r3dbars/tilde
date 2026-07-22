import AppKit
import AutocompleteLabCore
import CoreGraphics

/// Bridges IME socket requests to the screen-context (OCR) provider.
///
/// The input method has no accessibility view of the world, so capture geometry
/// is derived here from the requesting app's frontmost window. The provider's
/// own cache/refresh policy governs freshness; capture + OCR run on the
/// provider's queue and results are used in-memory only.
final class GhostScreenContextBridge: @unchecked Sendable {

    private let provider: VisiblePageContextProvider
    private var requestedPermissionThisLaunch = false
    private let lock = NSLock()

    init(provider: VisiblePageContextProvider) {
        self.provider = provider
    }

    /// Returns the cached OCR context for the requesting app/field (kicking off a
    /// background refresh when stale). Nil until a capture has completed or when
    /// screen-context is disabled/unpermitted.
    func context(
        appBundleIdentifier: String?,
        fieldIdentity: String?,
        textBeforeCursor: String,
        enabled: Bool
    ) -> VisiblePageContext? {
        guard enabled, let appBundleIdentifier else { return nil }
        promptForPermissionIfNeeded()
        guard let app = NSRunningApplication
            .runningApplications(withBundleIdentifier: appBundleIdentifier).first else { return nil }
        guard let window = frontmostWindow(pid: app.processIdentifier) else { return nil }

        let focused = FocusedTextContext(
            elementIdentifier: Self.stableHash(fieldIdentity ?? appBundleIdentifier),
            role: nil,
            subrole: nil,
            fingerprint: FocusedElementFingerprint(),
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: "",
            selectedTextLength: 0,
            caretRect: nil,
            elementRect: nil,
            windowRect: window.rect,
            windowIdentifier: window.number,
            textLineRect: nil,
            textStyle: nil,
            isSecure: false,
            caretIsSynthetic: true,
            capabilities: FocusedTextCapabilities(
                canReadValue: false,
                canReadSelectedTextRange: false,
                canReadBoundsForRange: false,
                canReadAttributedText: false,
                canSetSelectedText: false
            )
        )
        let info = RunningApplicationInfo(
            bundleIdentifier: appBundleIdentifier,
            localizedName: app.localizedName ?? appBundleIdentifier,
            processIdentifier: app.processIdentifier
        )
        provider.refreshIfNeeded(for: focused, app: info, enabled: enabled)
        return provider.cachedContext(for: focused, appBundleIdentifier: appBundleIdentifier)
    }

    /// One prompt per launch: without Screen Recording access the provider only
    /// records a redacted notice and stays silent forever.
    private func promptForPermissionIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !requestedPermissionThisLaunch else { return }
        requestedPermissionThisLaunch = true
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }
    }

    private func frontmostWindow(pid: pid_t) -> (rect: CGRect, number: Int)? {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return nil }

        for entry in list {
            guard let owner = entry[kCGWindowOwnerPID as String] as? pid_t,
                  owner == pid,
                  (entry[kCGWindowLayer as String] as? Int) == 0,
                  let bounds = entry[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let rect = CGRect(
                x: bounds["X"] ?? 0,
                y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )
            // Skip menu-bar droppings and tiny panels; we want the document window.
            guard rect.width > 200, rect.height > 150 else { continue }
            return (rect, entry[kCGWindowNumber as String] as? Int ?? 0)
        }
        return nil
    }

    /// Launch-stable hash (String.hashValue is seeded per process).
    private static func stableHash(_ string: String) -> Int {
        var hash = 5381
        for byte in string.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(byte)
        }
        return hash
    }
}
