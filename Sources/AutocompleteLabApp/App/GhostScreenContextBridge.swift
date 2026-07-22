import AppKit
import AutocompleteLabCore
import CoreGraphics

/// Bridges IME socket requests to the screen-context (OCR) provider — designed
/// latency-first around capture EVENTS rather than timers:
///
/// - Capture happens when the user switches apps (observed via NSWorkspace, so
///   OCR runs while the human is still reaching for the keyboard), when a new
///   field session starts (the field identity on the socket changes), or when
///   typing resumes after an idle gap.
/// - While a typing burst is active, the attached context is FROZEN: the prompt
///   prefix stays stable, so the model's prompt KV cache keeps hitting (~70ms
///   first ghost word) instead of resetting on every OCR refresh. If a burst
///   starts before its capture finishes, the context may attach once mid-burst
///   (a single warm-up beat), then freezes.
///
/// The input method has no accessibility view of the world, so capture geometry
/// is derived from the requesting app's frontmost window. Screen text is used
/// in-memory only.
final class GhostScreenContextBridge: @unchecked Sendable {

    /// A keystroke gap longer than this ends the typing burst; the next request
    /// starts a new session and may adopt a fresh capture.
    private let burstIdleSeconds: TimeInterval = 8

    private let provider: VisiblePageContextProvider
    private let lock = NSLock()
    private var requestedPermissionThisLaunch = false
    private var frozenContextByField: [String: VisiblePageContext] = [:]
    private var lastFieldKey: String?
    private var lastRequestAt: Date?
    private var activationObserver: NSObjectProtocol?

    init(provider: VisiblePageContextProvider) {
        self.provider = provider
        // App switches are the highest-value capture moment: the OCR completes
        // while the user is still settling into the new window.
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleIdentifier = app.bundleIdentifier else { return }
            // Give the activated app a beat to bring its window frontmost.
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3) {
                self?.kickCapture(appBundleIdentifier: bundleIdentifier, textBeforeCursor: "")
            }
        }
    }

    deinit {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
    }

    /// Returns the context to attach for this request, applying the freeze rule.
    func context(
        appBundleIdentifier: String?,
        fieldIdentity: String?,
        textBeforeCursor: String,
        enabled: Bool
    ) -> VisiblePageContext? {
        guard enabled, let appBundleIdentifier else { return nil }
        promptForPermissionIfNeeded()

        let fieldKey = "\(appBundleIdentifier)#\(fieldIdentity ?? "-")"
        let now = Date()

        lock.lock()
        let burstActive = lastFieldKey == fieldKey
            && lastRequestAt.map { now.timeIntervalSince($0) < burstIdleSeconds } ?? false
        lastFieldKey = fieldKey
        lastRequestAt = now
        if frozenContextByField.count > 16 { frozenContextByField.removeAll() }
        var frozen = frozenContextByField[fieldKey]
        lock.unlock()

        if !burstActive {
            // New session/burst: capture now, and adopt the freshest completed
            // capture as this burst's frozen context.
            kickCapture(appBundleIdentifier: appBundleIdentifier, textBeforeCursor: textBeforeCursor)
            if let fresh = cachedContext(appBundleIdentifier: appBundleIdentifier) {
                frozen = fresh
            }
        } else if frozen == nil {
            // Burst started before its capture finished: adopt once, then freeze.
            frozen = cachedContext(appBundleIdentifier: appBundleIdentifier)
        }

        if let frozen {
            lock.lock()
            frozenContextByField[fieldKey] = frozen
            lock.unlock()
        }
        return frozen
    }

    // MARK: - Capture plumbing

    private func kickCapture(appBundleIdentifier: String, textBeforeCursor: String) {
        guard let focused = focusedContext(appBundleIdentifier: appBundleIdentifier, textBeforeCursor: textBeforeCursor),
              let app = runningApplication(appBundleIdentifier) else { return }
        provider.refreshIfNeeded(
            for: focused,
            app: RunningApplicationInfo(
                bundleIdentifier: appBundleIdentifier,
                localizedName: app.localizedName ?? appBundleIdentifier,
                processIdentifier: app.processIdentifier
            ),
            enabled: true,
            allowsFreshCacheRefresh: true
        )
    }

    private func cachedContext(appBundleIdentifier: String) -> VisiblePageContext? {
        guard let focused = focusedContext(appBundleIdentifier: appBundleIdentifier, textBeforeCursor: "") else {
            return nil
        }
        return provider.cachedContext(for: focused, appBundleIdentifier: appBundleIdentifier)
    }

    /// Minimal focused-context stand-in: window-scoped geometry, constant field
    /// identifier so captures are shared per window regardless of which field
    /// session asked.
    private func focusedContext(appBundleIdentifier: String, textBeforeCursor: String) -> FocusedTextContext? {
        guard let app = runningApplication(appBundleIdentifier),
              let window = frontmostWindow(pid: app.processIdentifier) else { return nil }
        return FocusedTextContext(
            elementIdentifier: 0,
            textBeforeCursor: textBeforeCursor,
            selectedTextLength: 0,
            caretRect: nil,
            elementRect: nil,
            windowRect: window.rect,
            windowIdentifier: window.number,
            textLineRect: nil,
            isSecure: false
        )
    }

    private func runningApplication(_ bundleIdentifier: String) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
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
}
