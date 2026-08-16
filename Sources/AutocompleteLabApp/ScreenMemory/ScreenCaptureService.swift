import AutocompleteLabCore
import Carbon.HIToolbox.Events
import CoreGraphics
import Foundation
import ScreenCaptureKit

/// Owns Screen Memory's capture pipeline end to end: ScreenCaptureKit
/// full-display capture, Vision OCR, per-window attribution. Memory-only in
/// this phase — nothing here persists a `ScreenSnapshot` anywhere; the
/// latest one lives in `latestSnapshot` until the next capture replaces it
/// or the process exits.
///
/// Every capture attempt is routed through `CaptureTriggerPolicy` (Core,
/// pure) with freshly observed state, so the covenant's non-negotiables —
/// off by default, Secure Event Input, screen lock, per-app exclusion
/// against every visible window, the 1/5s cadence cap — are enforced by
/// tested logic, not re-derived here.
actor ScreenCaptureService {
    enum CaptureOutcome: Equatable, Sendable {
        case captured(blockCount: Int)
        case skipped(CaptureTriggerPolicy.BlockReason)
        case permissionNotGranted
        case captureFailed
    }

    private var lastCaptureAt: Date?
    private var lastActivityAt: Date?
    private(set) var latestSnapshot: ScreenSnapshot?
    private var pendingTypingPauseTask: Task<Void, Never>?

    /// Injectable for tests: the real system checks (TCC, lock screen,
    /// secure input, ScreenCaptureKit itself) are not something a unit test
    /// should have to actually perform on a display. `enabled` and
    /// `excludedApps` are providers, not stored state, so TildeSettings
    /// stays the single source of truth — flipping the menu toggle or
    /// editing the (Personal-History-shared) exclusion list takes effect on
    /// the very next trigger with nothing to keep in sync.
    private let enabled: @Sendable () -> Bool
    private let excludedApps: @Sendable () -> Set<String>
    private let permissionGranted: @Sendable () -> Bool
    private let screenLocked: @Sendable () -> Bool
    private let secureInputActive: @Sendable () -> Bool
    // Not @Sendable: closures without an isolation annotation are treated as
    // callable from any isolation domain, which is exactly what triggers a
    // "sending risks data races" error the moment an actor-isolated,
    // non-Sendable ScreenCaptureKit value (SCContentFilter,
    // SCStreamConfiguration) is passed into one. `captureImage` is not
    // injectable for that reason — see the direct SCScreenshotManager call
    // in `performCapture` — everything that IS a plain Sendable value stays
    // injectable for tests.
    private let shareableContent: () async throws -> SCShareableContent
    private let recognizeText: (CGImage) async throws -> [ScreenTextRecognizer.RecognizedBlock]
    private let now: @Sendable () -> Date
    private let diagnostics: @Sendable (String, [String: String]) -> Void

    init(
        enabled: @escaping @Sendable () -> Bool,
        excludedApps: @escaping @Sendable () -> Set<String>,
        permissionGranted: @escaping @Sendable () -> Bool = { ScreenRecordingPermission.isGranted() },
        screenLocked: @escaping @Sendable () -> Bool = { ScreenLockObserver.isLocked() },
        secureInputActive: @escaping @Sendable () -> Bool = { IsSecureEventInputEnabled() },
        shareableContent: @escaping () async throws -> SCShareableContent = {
            try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        },
        recognizeText: @escaping (CGImage) async throws -> [ScreenTextRecognizer.RecognizedBlock] = {
            try await ScreenTextRecognizer.recognize(image: $0)
        },
        now: @escaping @Sendable () -> Date = Date.init,
        diagnostics: @escaping @Sendable (String, [String: String]) -> Void = { event, metadata in
            DiagnosticsLog.shared.record(event, metadata: metadata)
        }
    ) {
        self.enabled = enabled
        self.excludedApps = excludedApps
        self.permissionGranted = permissionGranted
        self.screenLocked = screenLocked
        self.secureInputActive = secureInputActive
        self.shareableContent = shareableContent
        self.recognizeText = recognizeText
        self.now = now
        self.diagnostics = diagnostics
    }

    /// The focused-window trigger. Fires regardless of completion-session
    /// state — a plain app switch is worth capturing context for even if
    /// the user was not mid-suggestion.
    @discardableResult
    func noteWindowChanged() async -> CaptureOutcome {
        await attemptCapture(trigger: .windowChanged)
    }

    /// A completion request reached the socket: the IME is actively
    /// serving the user, which is the "session" the typing-pause trigger
    /// requires. This does not read or forward the request's content — it
    /// is purely a timestamp pulse.
    func noteCompletionActivity() {
        let stamp = now()
        lastActivityAt = stamp
        pendingTypingPauseTask?.cancel()
        pendingTypingPauseTask = Task { [weak self] in
            let nanoseconds = UInt64(CaptureTriggerPolicy.typingPauseThresholdSeconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            await self?.attemptCapture(
                trigger: .typingPause(elapsedSeconds: CaptureTriggerPolicy.typingPauseThresholdSeconds)
            )
        }
    }

    @discardableResult
    private func attemptCapture(trigger: CaptureTriggerPolicy.Trigger) async -> CaptureOutcome {
        let moment = now()
        let isEnabled = enabled()

        guard isEnabled else {
            record(.skip(.disabled))
            return .skipped(.disabled)
        }
        guard permissionGranted() else {
            diagnostics("screen-capture-skipped", ["reason": "permission"])
            return .permissionNotGranted
        }

        let sessionActive = CaptureTriggerPolicy.isCompletionSessionActive(
            lastActivityAt: lastActivityAt,
            now: moment
        )

        // Reserve the cadence slot BEFORE the first suspension point below.
        // Actor reentrancy means another trigger can run its own synchronous
        // prefix while this call is suspended on `await shareableContent()`;
        // without reserving here, both calls would read the same stale
        // `lastCaptureAt`, both pass the 1-per-5s cadence check, and both go
        // on to capture. Recording `moment` now closes that window; if this
        // attempt turns out not to actually capture (enumeration failure,
        // excluded window, etc.), the reservation is rolled back below.
        let priorCaptureAt = lastCaptureAt
        if let priorCaptureAt {
            let sinceLastCapture = moment.timeIntervalSince(priorCaptureAt)
            if sinceLastCapture < CaptureTriggerPolicy.cadenceCapSeconds {
                let reason = CaptureTriggerPolicy.BlockReason.cadence(
                    secondsRemaining: CaptureTriggerPolicy.cadenceCapSeconds - sinceLastCapture
                )
                record(.skip(reason))
                return .skipped(reason)
            }
        }
        lastCaptureAt = moment

        // Visible-window enumeration is required to honor "exclude if ANY
        // visible window belongs to an excluded app" — not just frontmost.
        // If we cannot enumerate, we cannot prove the exclusion list is
        // satisfied, so this fails closed rather than capturing blind.
        guard let content = try? await shareableContent() else {
            lastCaptureAt = priorCaptureAt
            diagnostics("screen-capture-skipped", ["reason": "enumeration-failed"])
            return .captureFailed
        }
        let visibleOwners = content.windows.compactMap(\.owningApplication?.bundleIdentifier)

        let decision = CaptureTriggerPolicy.decision(
            for: trigger,
            enabled: isEnabled,
            screenLocked: screenLocked(),
            secureInputActive: secureInputActive(),
            completionSessionActive: sessionActive,
            visibleWindowOwnerBundleIdentifiers: visibleOwners,
            excludedApps: excludedApps(),
            // Cadence was already enforced above (and its slot reserved);
            // passing `nil` here avoids re-checking it against the
            // now-reserved `lastCaptureAt`, which would always read as "too
            // soon" since it was just set to `moment`.
            lastCaptureAt: nil,
            now: moment
        )
        guard case let .skip(reason) = decision else {
            // decision is exhaustively .capture or .skip — reaching here means .capture.
            return await performCapture(content: content, moment: moment)
        }
        lastCaptureAt = priorCaptureAt
        record(.skip(reason))
        return .skipped(reason)
    }

    private func performCapture(content: SCShareableContent, moment: Date) async -> CaptureOutcome {
        guard let display = Self.activeDisplay(in: content) else {
            diagnostics("screen-capture-skipped", ["reason": "no-display"])
            return .captureFailed
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height
        configuration.showsCursor = false
        configuration.capturesAudio = false

        do {
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            let recognized = try await recognizeText(image)
            // `SCShareableContent.windows` documents no ordering guarantee.
            // `windowLayer` (mirrors CGWindowLevel) is the closest available
            // front-to-back proxy: lower layers sit in front for normal
            // windows. Verified empirically via script/screen_capture_probe;
            // treat as a caveat, not a hard guarantee, on unusual window
            // levels (panels, always-on-top utilities).
            let frontToBackWindows = content.windows.sorted { $0.windowLayer < $1.windowLayer }
            let windows = frontToBackWindows.map { window in
                WindowAttribution.WindowInfo(
                    bundleIdentifier: window.owningApplication?.bundleIdentifier,
                    title: window.title,
                    frame: Self.normalize(window.frame, in: display.frame)
                )
            }
            let blocks = recognized.map { block -> ScreenSnapshot.TextBlock in
                let owner = WindowAttribution.attribute(boundingBox: block.boundingBox, frontToBackWindows: windows)
                return ScreenSnapshot.TextBlock(
                    text: block.text,
                    boundingBox: block.boundingBox,
                    windowOwnerBundleIdentifier: owner?.bundleIdentifier,
                    windowTitle: owner?.title
                )
            }
            let snapshot = ScreenSnapshot(
                capturedAt: moment,
                displayID: display.displayID,
                blocks: blocks
            )
            latestSnapshot = snapshot
            lastCaptureAt = moment
            diagnostics("screen-capture-completed", ["blocks": String(blocks.count)])
            return .captured(blockCount: blocks.count)
        } catch {
            diagnostics("screen-capture-failed", [:])
            return .captureFailed
        }
    }

    private func record(_ decision: CaptureTriggerPolicy.Decision) {
        guard case let .skip(reason) = decision else { return }
        diagnostics("screen-capture-skipped", ["reason": Self.describe(reason)])
    }

    private static func describe(_ reason: CaptureTriggerPolicy.BlockReason) -> String {
        switch reason {
        case .disabled: return "disabled"
        case .screenLocked: return "screen-locked"
        case .secureInput: return "secure-input"
        case .noActiveCompletionSession: return "no-active-session"
        case .belowTypingPauseThreshold: return "below-threshold"
        case .excludedWindow: return "excluded-window"
        case .cadence: return "cadence"
        }
    }

    /// Picks the display holding the focused window, not just "whichever
    /// display SCShareableContent listed first" — on a multi-monitor setup
    /// that's frequently the wrong screen, so capture would OCR an idle
    /// display and miss the content the user is actually looking at. The
    /// frontmost window (lowest `windowLayer`, same front-to-back proxy used
    /// elsewhere in this type) locates the active display by which display's
    /// frame contains that window's center point. Falls back to the first
    /// display if there are no windows to locate, or none of their frames
    /// land inside a known display (e.g. a stale/off-screen window frame).
    private static func activeDisplay(in content: SCShareableContent) -> SCDisplay? {
        guard content.displays.count > 1 else { return content.displays.first }
        let frontToBack = content.windows.sorted { $0.windowLayer < $1.windowLayer }
        for window in frontToBack {
            let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
            if let match = content.displays.first(where: { $0.frame.contains(center) }) {
                return match
            }
        }
        return content.displays.first
    }

    /// `SCWindow.frame` is in global desktop points; `display.frame` is that
    /// same display's placement in that same global space. Normalizing by
    /// the display's own frame — not (0,0)-(screenWidth,screenHeight)) —
    /// keeps multi-monitor arrangements correct: a window's frame is
    /// expressed relative to the display it was captured from, matching the
    /// 0...1 space Vision's OCR boxes already use for that capture.
    private static func normalize(_ frame: CGRect, in displayFrame: CGRect) -> NormalizedDisplayRect {
        guard displayFrame.width > 0, displayFrame.height > 0 else {
            return NormalizedDisplayRect(x: 0, y: 0, width: 0, height: 0)
        }
        return NormalizedDisplayRect(
            x: (frame.origin.x - displayFrame.origin.x) / displayFrame.width,
            y: (frame.origin.y - displayFrame.origin.y) / displayFrame.height,
            width: frame.width / displayFrame.width,
            height: frame.height / displayFrame.height
        )
    }
}
