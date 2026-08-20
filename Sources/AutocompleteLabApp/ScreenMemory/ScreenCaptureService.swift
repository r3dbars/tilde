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
/// the user's own master toggle (on by default, always visible and
/// switchable), Secure Event Input, screen lock, per-app exclusion against
/// every visible window, an active text field, and the 1/2s cadence cap —
/// are enforced by tested logic, not re-derived here.
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
    private var pendingTextFieldCaptureTask: Task<Void, Never>?
    private var activeTextFieldSessionIdentifier: String?
    private var textFieldRequiresFullRefresh = false

    /// Counts every capture that reaches `performCapture` (cadence/exclusion
    /// already cleared it). Referencing needs OTHER windows' text, which a
    /// single-window capture can never see by construction — the filter
    /// physically excludes every other window's pixels — so this forces a
    /// full-display pass on every Nth capture to keep referencing fed. `3` is
    /// a simple, documented choice: frequent enough that referenceSnippets
    /// stay usable within the 20s staleness window (`ScreenScene`'s
    /// `defaultStalenessCapSeconds`), infrequent enough that most captures
    /// still get the window-only path's ~2x OCR speedup and exact
    /// attribution.
    private var captureCounter = 0
    private static let fullDisplayCaptureInterval = 3

    /// What a full or region OCR pass leaves behind for the NEXT capture on
    /// the same path to diff against: the luminance grid it was computed
    /// from, the geometry it was captured under, and the resulting snapshot
    /// (its blocks are what `.unchanged` reuses and what `.region` merges
    /// into). Window and display captures keep entirely separate baselines
    /// — they alternate every `fullDisplayCaptureInterval` captures, and a
    /// display frame must never be diffed against a window frame or vice
    /// versa. There is nothing else to "reset" on a kind switch: each path
    /// only ever reads and writes its own baseline, and `CaptureChangeDetector`'s
    /// `GeometryKey` equality check already forces `.full` on a window
    /// identity or pixel-dimension change within a path.
    private struct CaptureBaseline {
        let geometry: CaptureChangeDetector.GeometryKey
        let grid: CaptureChangeDetector.LuminanceGrid
        let snapshot: ScreenSnapshot
    }
    private var windowBaseline: CaptureBaseline?
    private var displayBaseline: CaptureBaseline?

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
    /// "OCR only the changed screen region" experiment arm
    /// (`TildeSettings.incrementalOCREnabled`, default true). Read fresh on
    /// every capture, same live-provider pattern as `enabled`/`excludedApps`
    /// — a menu-level kill switch takes effect on the very next capture with
    /// nothing to keep in sync. `false` restores today's always-full-OCR
    /// behavior exactly: the luminance-grid sampling and
    /// `CaptureChangeDetector` call are skipped entirely, not just ignored.
    private let incrementalOCREnabled: @Sendable () -> Bool
    /// Explicit dev-build-only paired evaluator. When enabled, region/skip
    /// decisions run one additional full OCR pass over the same in-memory
    /// image and persist both outputs to the bounded owner-only corpus.
    private let localOCREvaluationEnabled: @Sendable () -> Bool
    private let localOCREvaluationGeneration: @Sendable () -> UInt64
    private let recordOCREvaluation: @Sendable (LocalOCREvaluationSample, UInt64) -> Void

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
        },
        incrementalOCREnabled: @escaping @Sendable () -> Bool = { TildeSettings().incrementalOCREnabled },
        localOCREvaluationEnabled: @escaping @Sendable () -> Bool = {
            LocalOCREvaluationStore.isAvailableInCurrentBuild
                && TildeSettings().localOCREvaluationEnabled
        },
        localOCREvaluationGeneration: @escaping @Sendable () -> UInt64 = {
            LocalOCREvaluationStore.shared.generationToken()
        },
        recordOCREvaluation: @escaping @Sendable (LocalOCREvaluationSample, UInt64) -> Void = {
            LocalOCREvaluationStore.shared.record($0, generation: $1)
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
        self.incrementalOCREnabled = incrementalOCREnabled
        self.localOCREvaluationEnabled = localOCREvaluationEnabled
        self.localOCREvaluationGeneration = localOCREvaluationGeneration
        self.recordOCREvaluation = recordOCREvaluation
    }

    /// The focused-window trigger. It may refresh context while an IMKit
    /// text session is active, but an ordinary app switch with no active
    /// text field is rejected by the shared capture policy.
    @discardableResult
    func noteWindowChanged() async -> CaptureOutcome {
        await attemptCapture(trigger: .windowChanged)
    }

    /// A real IMKit input session became active. The first refresh uses the
    /// full display and bypasses the incremental baseline so Vision's
    /// `.accurate` recognizer rebuilds a complete scene. The safety gates
    /// and two-second heavy-capture ceiling still apply.
    @discardableResult
    func noteTextFieldFocused(sessionIdentifier: String) async -> CaptureOutcome {
        activeTextFieldSessionIdentifier = sessionIdentifier
        lastActivityAt = now()
        textFieldRequiresFullRefresh = true
        pendingTextFieldCaptureTask?.cancel()
        pendingTextFieldCaptureTask = nil
        let outcome = await attemptTextFieldCapture(trigger: .textFieldFocused)
        scheduleRetryAfterCadenceIfNeeded(outcome, trigger: .textFieldFocused)
        return outcome
    }

    /// The IME has observed 250ms without another printable keystroke. Only
    /// the active session may refresh; a late pulse from an old field is
    /// ignored. Incremental OCR then recognizes only the changed region.
    @discardableResult
    func noteTypingPaused(sessionIdentifier: String) async -> CaptureOutcome? {
        guard activeTextFieldSessionIdentifier == sessionIdentifier else { return nil }
        lastActivityAt = now()
        pendingTextFieldCaptureTask?.cancel()
        pendingTextFieldCaptureTask = nil
        let trigger = CaptureTriggerPolicy.Trigger.typingPause(
            elapsedSeconds: CaptureTriggerPolicy.typingPauseThresholdSeconds
        )
        let outcome = await attemptTextFieldCapture(trigger: trigger)
        scheduleRetryAfterCadenceIfNeeded(outcome, trigger: trigger)
        return outcome
    }

    /// Stops delayed refreshes for the field that actually lost focus. A
    /// stale blur from an older IMKit controller cannot cancel a newer one.
    func noteTextFieldBlurred(sessionIdentifier: String) {
        guard activeTextFieldSessionIdentifier == sessionIdentifier else { return }
        activeTextFieldSessionIdentifier = nil
        pendingTextFieldCaptureTask?.cancel()
        pendingTextFieldCaptureTask = nil
    }

    /// A completion request reached the socket: the IME is actively
    /// serving the user, which is the "session" the typing-pause trigger
    /// requires. This does not read or forward the request's content — it
    /// is purely a timestamp pulse.
    /// Screen Memory plan Phase 2 PR 2b: the completion path's read of the
    /// capture pipeline. Purely reads `latestSnapshot` and hands it to
    /// `ScreenScene.freshScene`'s staleness gate — never triggers
    /// `attemptCapture`, so a completion request can call this and get an
    /// answer immediately, whether or not a capture happens to be in
    /// flight.
    ///
    /// Exclusion is re-checked here against `excludedApps()`'s CURRENT
    /// value, not just at capture time: a snapshot can be up to
    /// `ScreenScene.defaultStalenessCapSeconds` (20s) old, and the
    /// exclusion list can change at any moment in between (the user adding
    /// an app to it right after a capture must not leave that app's text
    /// readable from the cached snapshot for the rest of the staleness
    /// window). Blocks owned by a now-excluded app are dropped before
    /// classification ever sees them.
    func freshScene(
        frontmostBundleID: String?,
        fieldText: String,
        now: Date = Date()
    ) -> ScreenScene.Scene? {
        guard let snapshot = latestSnapshot else { return nil }
        let currentlyExcluded = excludedApps()
        let filteredSnapshot: ScreenSnapshot
        if currentlyExcluded.isEmpty {
            filteredSnapshot = snapshot
        } else {
            let keptBlocks = snapshot.blocks.filter {
                guard let owner = $0.windowOwnerBundleIdentifier else { return true }
                return !currentlyExcluded.contains(owner)
            }
            filteredSnapshot = ScreenSnapshot(
                capturedAt: snapshot.capturedAt,
                displayID: snapshot.displayID,
                blocks: keptBlocks
            )
        }
        let classificationStart = self.now()
        let scene = ScreenScene.freshScene(
            from: filteredSnapshot,
            now: now,
            frontmostBundleID: frontmostBundleID,
            fieldText: fieldText
        )
        // Count-only diagnostics (2026-08-16 dogfood fix): mode plus two
        // integers, never the OCR'd text itself, so a classification going
        // wrong live is never opaque again — this was the exact gap that
        // made tonight's bug take a live dogfood session plus a manual
        // "hand the model the block directly" test to even confirm.
        // `DiagnosticsMetadataRedactor`'s allowlist enforces the fixed
        // vocabulary/integers-only shape at the log-writing layer, but the
        // event is only fired here, after a real classification ran (a
        // `nil` scene -- no snapshot yet, or too stale -- logs nothing,
        // matching every other "no signal" path in this file).
        // "P99 at every section" (2026-08-18): `milliseconds` times only the
        // `ScreenScene.freshScene` call itself, using the same injectable
        // `now()` clock as the rest of this actor — the block-filtering work
        // above is O(blocks) and cheap; classification (turn/reference
        // bucketing) is the part worth a percentile.
        if let scene {
            let classificationMilliseconds = Self.milliseconds(from: classificationStart, to: self.now())
            diagnostics("scene-classified", [
                "mode": scene.mode.rawValue,
                "turns": String(scene.conversationTurns.count),
                "refs": String(scene.referenceSnippets.count),
                "milliseconds": String(classificationMilliseconds),
            ])
        }
        return scene
    }

    /// Test seam: injects a snapshot directly, bypassing the entire
    /// ScreenCaptureKit/Vision pipeline that a unit test cannot drive.
    /// Production code always reaches `latestSnapshot` through a real
    /// `attemptCapture`; nothing outside tests calls this.
    func setLatestSnapshotForTesting(_ snapshot: ScreenSnapshot?) {
        latestSnapshot = snapshot
    }

    func noteCompletionActivity() {
        let stamp = now()
        lastActivityAt = stamp
        pendingTypingPauseTask?.cancel()
        pendingTypingPauseTask = Task { [weak self] in
            let nanoseconds = UInt64(CaptureTriggerPolicy.typingPauseThresholdSeconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            _ = await self?.attemptCapture(
                trigger: .typingPause(elapsedSeconds: CaptureTriggerPolicy.typingPauseThresholdSeconds)
            )
        }
    }

    @discardableResult
    private func attemptTextFieldCapture(
        trigger: CaptureTriggerPolicy.Trigger
    ) async -> CaptureOutcome {
        let outcome = await attemptCapture(
            trigger: trigger,
            forceFullDisplay: textFieldRequiresFullRefresh,
            forceFullOCR: textFieldRequiresFullRefresh
        )
        if case .captured = outcome {
            textFieldRequiresFullRefresh = false
        }
        return outcome
    }

    private func scheduleRetryAfterCadenceIfNeeded(
        _ outcome: CaptureOutcome,
        trigger: CaptureTriggerPolicy.Trigger
    ) {
        guard activeTextFieldSessionIdentifier != nil,
              case let .skipped(.cadence(secondsRemaining)) = outcome else { return }
        pendingTextFieldCaptureTask?.cancel()
        pendingTextFieldCaptureTask = Task { [weak self] in
            let nanoseconds = UInt64(max(0, secondsRemaining) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled, let self else { return }
            let retry = await self.attemptTextFieldCapture(trigger: trigger)
            await self.scheduleRetryAfterCadenceIfNeeded(retry, trigger: trigger)
        }
    }

    private func attemptCapture(
        trigger: CaptureTriggerPolicy.Trigger,
        forceFullDisplay: Bool = false,
        forceFullOCR: Bool = false
    ) async -> CaptureOutcome {
        let moment = now()
        let isEnabled = enabled()

        guard isEnabled else {
            record(.skip(.disabled))
            return .skipped(.disabled)
        }
        guard permissionGranted() else {
            diagnostics("screen-capture-skipped", ["reason": "no-permission"])
            return .permissionNotGranted
        }
        guard activeTextFieldSessionIdentifier != nil else {
            record(.skip(.noActiveTextField))
            return .skipped(.noActiveTextField)
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

        // Re-read `enabled()` here rather than reusing the `isEnabled`
        // captured above: `shareableContent()` just suspended this call,
        // and the user can flip the Screen Memory toggle off during that
        // window. Deciding off a value read before the only await point in
        // this method would let a capture that started while enabled land
        // — and get stored into `latestSnapshot` — after the toggle reads
        // off everywhere else in the app.
        let stillEnabled = enabled()
        let decision = CaptureTriggerPolicy.decision(
            for: trigger,
            enabled: stillEnabled,
            screenLocked: screenLocked(),
            secureInputActive: secureInputActive(),
            textFieldActive: activeTextFieldSessionIdentifier != nil,
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
            return await performCapture(
                content: content,
                moment: moment,
                forceFullDisplay: forceFullDisplay,
                forceFullOCR: forceFullOCR
            )
        }
        lastCaptureAt = priorCaptureAt
        record(.skip(reason))
        return .skipped(reason)
    }

    /// Chooses window-only vs full-display capture and dispatches to the
    /// matching path. `captureCounter` decides the periodic full-display
    /// pass (see its doc comment); on any capture that isn't forced full,
    /// `frontmostWindow` still has to actually find a layer-0 window or this
    /// falls back to full-display anyway — a window-only capture is never
    /// attempted blind.
    private func performCapture(
        content: SCShareableContent,
        moment: Date,
        forceFullDisplay: Bool,
        forceFullOCR: Bool
    ) async -> CaptureOutcome {
        guard let display = Self.activeDisplay(in: content) else {
            diagnostics("screen-capture-skipped", ["reason": "no-display"])
            return .captureFailed
        }

        captureCounter += 1
        let forceFullDisplay = forceFullDisplay
            || captureCounter % Self.fullDisplayCaptureInterval == 0
        let zRanks = Self.onScreenZOrderRanks()

        if !forceFullDisplay, let window = Self.frontmostWindow(among: content.windows, zRanks: zRanks) {
            return await performWindowCapture(
                window: window,
                display: display,
                moment: moment,
                forceFullOCR: forceFullOCR
            )
        }
        return await performFullDisplayCapture(
            content: content,
            display: display,
            zRanks: zRanks,
            moment: moment,
            forceFullOCR: forceFullOCR
        )
    }

    /// Captures ONLY the frontmost app's frontmost layer-0 window
    /// (`SCContentFilter(desktopIndependentWindow:)`) — the captured image
    /// physically contains that one window's pixels, so every OCR block is
    /// stamped with that window's bundle id and frame directly, with no
    /// per-block attribution guessing (contrast `performFullDisplayCapture`,
    /// which still needs `WindowAttribution` because it can see several
    /// windows at once). Roughly halves OCR latency too: Vision has one
    /// window's worth of pixels to walk instead of the whole display.
    private func performWindowCapture(
        window: SCWindow,
        display: SCDisplay,
        moment: Date,
        forceFullOCR: Bool
    ) async -> CaptureOutcome {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(window.frame.width.rounded()))
        configuration.height = max(1, Int(window.frame.height.rounded()))
        configuration.showsCursor = false
        configuration.capturesAudio = false

        let dutyCycleStart = now()
        do {
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            // Vision's boxes are normalized against the captured WINDOW
            // image here, not the display — map each one through the
            // window's own display-normalized frame before it becomes a
            // `TextBlock`, or every downstream consumer (bubble-width gates,
            // speaker bucketing in `ScreenScene`) silently misreads
            // window-relative widths as display-relative ones.
            let windowFrame = Self.normalize(window.frame, in: display.frame)
            let ownerBundleIdentifier = window.owningApplication?.bundleIdentifier

            // Incremental OCR (docs: "OCR only the changed screen region"),
            // gated behind `TildeSettings.incrementalOCREnabled` (default
            // true — the experiment's "on" arm): when the flag reads false,
            // sampling and diffing are skipped outright, not merely ignored,
            // so the "off" arm costs nothing beyond today's behavior and
            // `windowBaseline` clears rather than going stale, so a later
            // re-enable starts from a fresh baseline instead of diffing
            // against a possibly very old frame.
            let incrementalEnabled = incrementalOCREnabled()
            let priorBaseline = incrementalEnabled && !forceFullOCR ? windowBaseline : nil
            let currentGrid = incrementalEnabled ? LuminanceGridSampler.sample(image) : nil
            let geometry = CaptureChangeDetector.GeometryKey(
                kind: .window,
                identity: window.windowID.description,
                pixelWidth: image.width,
                pixelHeight: image.height
            )
            let decision: CaptureChangeDetector.Decision
            if let currentGrid {
                decision = CaptureChangeDetector.decision(
                    previousGrid: priorBaseline?.grid,
                    previousGeometry: priorBaseline?.geometry,
                    currentGrid: currentGrid,
                    currentGeometry: geometry
                )
            } else {
                decision = .full
            }

            // "P99 at every section" (2026-08-18): the duty cycle above
            // covers screenshot+OCR together, which is what the power probe
            // budget cares about, but tells capture and OCR apart is exactly
            // what a percentile table needs to point at which half of the
            // duty cycle regressed. Every branch below times only its own
            // `recognizeText` call (or, for `.unchanged`, spends none) using
            // the same injectable clock as `dutyCycleMilliseconds`.
            func fullWindowOCR() async throws -> ([ScreenSnapshot.TextBlock], Int) {
                let ocrStart = now()
                let recognized = try await recognizeText(image)
                let ocrMilliseconds = Self.milliseconds(from: ocrStart, to: now())
                let mapped = recognized.map { block -> ScreenSnapshot.TextBlock in
                    ScreenSnapshot.TextBlock(
                        text: block.text,
                        boundingBox: WindowAttribution.mapWindowRelativeBox(block.boundingBox, windowFrame: windowFrame),
                        windowOwnerBundleIdentifier: ownerBundleIdentifier,
                        windowTitle: window.title,
                        windowFrame: windowFrame
                    )
                }
                return (mapped, ocrMilliseconds)
            }

            let blocks: [ScreenSnapshot.TextBlock]
            let ocrMilliseconds: Int
            let ocrScope: String
            switch decision {
            case .unchanged:
                if let priorBaseline {
                    // The screen IS current -- only the OCR pass was
                    // skipped -- so the reused blocks keep their original
                    // text and `capturedAt` moves forward to `moment`,
                    // matching `freshScene`'s staleness math exactly as if
                    // a real OCR had just confirmed the same content.
                    blocks = priorBaseline.snapshot.blocks
                    ocrMilliseconds = 0
                    ocrScope = "skipped"
                } else {
                    // `CaptureChangeDetector` only returns `.unchanged` when
                    // it was given a previous baseline, so this is a safety
                    // net for a future invariant break, not a reachable
                    // path today: fail open to a full OCR rather than
                    // inventing blocks out of nothing.
                    (blocks, ocrMilliseconds) = try await fullWindowOCR()
                    ocrScope = "full"
                }

            case let .region(rect):
                if let priorBaseline, let croppedImage = Self.cropped(image, to: rect) {
                    let ocrStart = now()
                    let recognized = try await recognizeText(croppedImage)
                    ocrMilliseconds = Self.milliseconds(from: ocrStart, to: now())
                    // Two affine hops through the same tested transform:
                    // Vision's box is normalized to the CROP, so it maps
                    // first into the crop's own place within the window
                    // image (`rect` standing in for "the window the crop
                    // was taken from"), then that window-relative box maps
                    // into display space exactly like the full-window path
                    // above.
                    let newBlocks = recognized.map { block -> ScreenSnapshot.TextBlock in
                        let windowRelative = WindowAttribution.mapWindowRelativeBox(block.boundingBox, windowFrame: rect)
                        return ScreenSnapshot.TextBlock(
                            text: block.text,
                            boundingBox: WindowAttribution.mapWindowRelativeBox(windowRelative, windowFrame: windowFrame),
                            windowOwnerBundleIdentifier: ownerBundleIdentifier,
                            windowTitle: window.title,
                            windowFrame: windowFrame
                        )
                    }
                    // The merge intersects against PREVIOUS blocks, whose
                    // boxes are display-normalized — so the region must make
                    // the same window→display hop the new blocks just did.
                    // Passing the window-space `rect` here would mis-place
                    // the region for any non-fullscreen window: stale blocks
                    // inside the changed area would survive the merge and
                    // duplicate the freshly-read text.
                    blocks = CaptureChangeDetector.mergeBlocks(
                        previousBlocks: priorBaseline.snapshot.blocks,
                        newBlocks: newBlocks,
                        region: WindowAttribution.mapWindowRelativeBox(rect, windowFrame: windowFrame)
                    )
                    ocrScope = "region"
                } else {
                    (blocks, ocrMilliseconds) = try await fullWindowOCR()
                    ocrScope = "full"
                }

            case .full:
                (blocks, ocrMilliseconds) = try await fullWindowOCR()
                ocrScope = "full"
            }

            let dutyCycleMilliseconds = Self.milliseconds(from: dutyCycleStart, to: now())
            let snapshot = ScreenSnapshot(capturedAt: moment, displayID: display.displayID, blocks: blocks)
            latestSnapshot = snapshot
            lastCaptureAt = moment
            windowBaseline = currentGrid.map { CaptureBaseline(geometry: geometry, grid: $0, snapshot: snapshot) }
            diagnostics(
                "screen-capture-completed",
                [
                    "blocks": String(blocks.count),
                    "duration_ms": String(dutyCycleMilliseconds),
                    "ocrMilliseconds": String(ocrMilliseconds),
                    "kind": "window",
                    "ocrScope": ocrScope,
                ]
            )
            await recordLocalOCREvaluationIfEnabled(
                capturedAt: moment,
                captureKind: "window",
                incrementalScope: ocrScope,
                incrementalMilliseconds: ocrMilliseconds,
                incrementalBlocks: blocks,
                referenceOCR: fullWindowOCR
            )
            return .captured(blockCount: blocks.count)
        } catch {
            let dutyCycleMilliseconds = Self.milliseconds(from: dutyCycleStart, to: now())
            diagnostics(
                "screen-capture-failed",
                ["duration_ms": String(dutyCycleMilliseconds), "kind": "window"]
            )
            return .captureFailed
        }
    }

    /// The original full-display path, unchanged in behavior: captures the
    /// active display, OCRs everything visible on it, and attributes each
    /// block to a window via `WindowAttribution`'s z-order-aware geometry
    /// match. This is what keeps "referencing" fed — it is the only path
    /// that can ever see a window other than the frontmost one.
    private func performFullDisplayCapture(
        content: SCShareableContent,
        display: SCDisplay,
        zRanks: [CGWindowID: Int],
        moment: Date,
        forceFullOCR: Bool
    ) async -> CaptureOutcome {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height
        configuration.showsCursor = false
        configuration.capturesAudio = false

        // Duty-cycle instrumentation (Phase 1b, docs/plans/screen-memory.md):
        // wall-clock time for capture+OCR only, in whole milliseconds, no
        // screen text. This is the number the power probe harness
        // (script/capture_power_probe.sh) reads back out of the diagnostics
        // log to check the <250ms OCR p95 budget — reuses the same
        // injectable `now` clock tests already control, rather than adding a
        // second time source.
        let dutyCycleStart = now()

        do {
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            // `SCShareableContent.windows` documents no ordering guarantee,
            // and `windowLayer` alone cannot recover z-order: every normal
            // app window is layer 0, so sorting by layer is a no-op there
            // and the list order decides attribution. That misattributes
            // whole regions when several windows occupy the same frame (a
            // user who stacks half-screen windows — live bug 2026-08-18:
            // the visible chat's blocks attributed to a same-position
            // window BEHIND it, so the own-window filter discarded the
            // whole conversation). `CGWindowListCopyWindowInfo` with
            // `.optionOnScreenOnly` IS documented front-to-back; rank by
            // it, keeping `windowLayer` only as the fallback for windows
            // missing from that list. `zRanks` is a parameter here (computed
            // once in `performCapture`, the same ranks used to pick the
            // frontmost window for the window-only path) rather than
            // recomputed. Building this list is pure/cheap geometry, needed
            // regardless of OCR scope, so it happens unconditionally before
            // the incremental-OCR decision below.
            let frontToBackWindows = content.windows.sorted {
                Self.frontToBackPrecedes($0, $1, zRanks: zRanks)
            }
            let windows = frontToBackWindows.map { window in
                WindowAttribution.WindowInfo(
                    bundleIdentifier: window.owningApplication?.bundleIdentifier,
                    title: window.title,
                    frame: Self.normalize(window.frame, in: display.frame)
                )
            }

            // Incremental OCR (docs: "OCR only the changed screen region"):
            // same mechanism and same `incrementalOCREnabled` gate as
            // `performWindowCapture`, diffed against this path's own
            // `displayBaseline` — never the window path's, since a display
            // frame and a window frame are never comparable.
            let incrementalEnabled = incrementalOCREnabled()
            let priorBaseline = incrementalEnabled && !forceFullOCR ? displayBaseline : nil
            let currentGrid = incrementalEnabled ? LuminanceGridSampler.sample(image) : nil
            let geometry = CaptureChangeDetector.GeometryKey(
                kind: .display,
                identity: display.displayID.description,
                pixelWidth: image.width,
                pixelHeight: image.height
            )
            let decision: CaptureChangeDetector.Decision = currentGrid.map {
                CaptureChangeDetector.decision(
                    previousGrid: priorBaseline?.grid,
                    previousGeometry: priorBaseline?.geometry,
                    currentGrid: $0,
                    currentGeometry: geometry
                )
            } ?? .full

            // "P99 at every section" (2026-08-18): `ocrStart` marks the
            // moment the screenshot finished, so `ocrMilliseconds` isolates
            // `recognizeText` from the screenshot half of the duty cycle —
            // same purpose and same injectable clock as `performWindowCapture`'s
            // split. Every branch below attributes each new block to a
            // window the same way the original full-display path always
            // did — `boundingBox` here is already display-relative, unlike
            // the window path, so no window-frame remap is needed for the
            // full-frame case.
            func fullDisplayOCR() async throws -> ([ScreenSnapshot.TextBlock], Int) {
                let ocrStart = now()
                let recognized = try await recognizeText(image)
                let ocrMilliseconds = Self.milliseconds(from: ocrStart, to: now())
                let mapped = recognized.map { block -> ScreenSnapshot.TextBlock in
                    let owner = WindowAttribution.attribute(boundingBox: block.boundingBox, frontToBackWindows: windows)
                    return ScreenSnapshot.TextBlock(
                        text: block.text,
                        boundingBox: block.boundingBox,
                        windowOwnerBundleIdentifier: owner?.bundleIdentifier,
                        windowTitle: owner?.title,
                        windowFrame: owner?.frame
                    )
                }
                return (mapped, ocrMilliseconds)
            }

            let blocks: [ScreenSnapshot.TextBlock]
            let ocrMilliseconds: Int
            let ocrScope: String
            switch decision {
            case .unchanged:
                if let priorBaseline {
                    // The screen IS current -- only the OCR pass was
                    // skipped -- so the reused blocks keep their original
                    // text and `capturedAt` moves forward to `moment`, same
                    // staleness semantics as a real re-OCR would have
                    // produced.
                    blocks = priorBaseline.snapshot.blocks
                    ocrMilliseconds = 0
                    ocrScope = "skipped"
                } else {
                    // Safety net for a future invariant break in
                    // `CaptureChangeDetector` (see `performWindowCapture`'s
                    // identical comment) — not reachable today.
                    (blocks, ocrMilliseconds) = try await fullDisplayOCR()
                    ocrScope = "full"
                }

            case let .region(rect):
                if let priorBaseline, let croppedImage = Self.cropped(image, to: rect) {
                    let ocrStart = now()
                    let recognized = try await recognizeText(croppedImage)
                    ocrMilliseconds = Self.milliseconds(from: ocrStart, to: now())
                    // Vision's box is normalized to the CROP; `rect` is
                    // already display-relative (this path's boxes never go
                    // through a window-frame remap), so one hop through the
                    // same tested affine transform lands it in display
                    // space directly.
                    let newBlocks = recognized.map { block -> ScreenSnapshot.TextBlock in
                        let displayRelative = WindowAttribution.mapWindowRelativeBox(block.boundingBox, windowFrame: rect)
                        let owner = WindowAttribution.attribute(boundingBox: displayRelative, frontToBackWindows: windows)
                        return ScreenSnapshot.TextBlock(
                            text: block.text,
                            boundingBox: displayRelative,
                            windowOwnerBundleIdentifier: owner?.bundleIdentifier,
                            windowTitle: owner?.title,
                            windowFrame: owner?.frame
                        )
                    }
                    blocks = CaptureChangeDetector.mergeBlocks(
                        previousBlocks: priorBaseline.snapshot.blocks,
                        newBlocks: newBlocks,
                        region: rect
                    )
                    ocrScope = "region"
                } else {
                    (blocks, ocrMilliseconds) = try await fullDisplayOCR()
                    ocrScope = "full"
                }

            case .full:
                (blocks, ocrMilliseconds) = try await fullDisplayOCR()
                ocrScope = "full"
            }

            // Stop the clock the instant the switch above finishes — window
            // attribution and block mapping are pure/deterministic and not
            // part of the "capture+OCR" duty cycle the plan's power budget
            // assertions (script/capture_power_probe.sh) measure.
            let dutyCycleMilliseconds = Self.milliseconds(from: dutyCycleStart, to: now())
            let snapshot = ScreenSnapshot(
                capturedAt: moment,
                displayID: display.displayID,
                blocks: blocks
            )
            latestSnapshot = snapshot
            lastCaptureAt = moment
            displayBaseline = currentGrid.map { CaptureBaseline(geometry: geometry, grid: $0, snapshot: snapshot) }
            diagnostics(
                "screen-capture-completed",
                [
                    "blocks": String(blocks.count),
                    "duration_ms": String(dutyCycleMilliseconds),
                    "ocrMilliseconds": String(ocrMilliseconds),
                    "kind": "display",
                    "ocrScope": ocrScope,
                ]
            )
            await recordLocalOCREvaluationIfEnabled(
                capturedAt: moment,
                captureKind: "display",
                incrementalScope: ocrScope,
                incrementalMilliseconds: ocrMilliseconds,
                incrementalBlocks: blocks,
                referenceOCR: fullDisplayOCR
            )
            return .captured(blockCount: blocks.count)
        } catch {
            // Failed attempts still spent wall-clock time in
            // ScreenCaptureKit/Vision (e.g. a slow timeout) and count toward
            // the duty cycle the power probe measures, so the same
            // duration_ms field is attached here too.
            let dutyCycleMilliseconds = Self.milliseconds(from: dutyCycleStart, to: now())
            diagnostics("screen-capture-failed", ["duration_ms": String(dutyCycleMilliseconds), "kind": "display"])
            return .captureFailed
        }
    }

    /// Whole milliseconds between two instants, floored at zero so a clock
    /// that does not advance (the common case in tests, which hold `now`
    /// fixed) reports `0` rather than a negative number. Internal, not
    /// private, so `ScreenCaptureServiceTests` can prove the rounding/floor
    /// behavior directly — `performCapture` itself stays untestable at unit
    /// level like the rest of ScreenCaptureKit-shaped code in this type (see
    /// the type doc comment), so this is the one piece of the duty-cycle
    /// math that CAN be proven without a live display.
    static func milliseconds(from start: Date, to end: Date) -> Int {
        max(0, Int((end.timeIntervalSince(start) * 1000).rounded()))
    }

    func recordLocalOCREvaluationIfEnabled(
        capturedAt: Date,
        captureKind: String,
        incrementalScope: String,
        incrementalMilliseconds: Int,
        incrementalBlocks: [ScreenSnapshot.TextBlock],
        referenceOCR: () async throws -> ([ScreenSnapshot.TextBlock], Int)
    ) async {
        let generation = localOCREvaluationGeneration()
        guard incrementalScope != "full", localOCREvaluationEnabled() else { return }
        do {
            let (referenceBlocks, referenceMilliseconds) = try await referenceOCR()
            // Consent and safety settings can change while Vision is working.
            // Re-check them at the persistence boundary, then strip any app
            // the user excluded during the in-flight pass.
            guard enabled(),
                  permissionGranted(),
                  localOCREvaluationEnabled(),
                  !screenLocked(),
                  !secureInputActive() else { return }
            let exclusions = excludedApps()
            let allowed: (ScreenSnapshot.TextBlock) -> Bool = { block in
                guard let owner = block.windowOwnerBundleIdentifier else { return false }
                return !exclusions.contains(owner)
            }
            recordOCREvaluation(
                LocalOCREvaluationSample(
                    capturedAt: capturedAt,
                    captureKind: captureKind,
                    incrementalScope: incrementalScope,
                    incrementalMilliseconds: incrementalMilliseconds,
                    fullReferenceMilliseconds: referenceMilliseconds,
                    incrementalBlocks: incrementalBlocks.filter(allowed),
                    fullReferenceBlocks: referenceBlocks.filter(allowed)
                ),
                generation
            )
            diagnostics(
                "ocr-evaluation-reference-completed",
                [
                    "kind": captureKind,
                    "scope": incrementalScope,
                    "referenceMilliseconds": String(referenceMilliseconds),
                ]
            )
        } catch {
            diagnostics(
                "ocr-evaluation-reference-failed",
                ["kind": captureKind, "scope": incrementalScope]
            )
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
        case .noActiveTextField: return "no-active-text-field"
        case .noActiveCompletionSession: return "no-active-session"
        case .belowTypingPauseThreshold: return "below-threshold"
        case .excludedWindow: return "excluded-app"
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
        let zRanks = onScreenZOrderRanks()
        let frontToBack = content.windows.sorted { frontToBackPrecedes($0, $1, zRanks: zRanks) }
        for window in frontToBack {
            let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
            if let match = content.displays.first(where: { $0.frame.contains(center) }) {
                return match
            }
        }
        return content.displays.first
    }

    /// True front-to-back ranks for on-screen windows, from
    /// `CGWindowListCopyWindowInfo` — the one window API whose ordering IS
    /// documented ("returned in order from front to back"). Keyed by
    /// `CGWindowID` for lookup against `SCWindow.windowID`.
    private static func onScreenZOrderRanks() -> [CGWindowID: Int] {
        guard let info = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return [:] }
        var ranks: [CGWindowID: Int] = [:]
        for (rank, entry) in info.enumerated() {
            if let number = entry[kCGWindowNumber as String] as? NSNumber {
                ranks[CGWindowID(truncating: number)] = rank
            }
        }
        return ranks
    }

    /// Documented z-order rank first. A window missing from the on-screen
    /// list sorts behind every ranked one — "not on screen" must never win
    /// an attribution over a visible window — with the old layer proxy only
    /// breaking ties between two unranked windows.
    private static func frontToBackPrecedes(
        _ a: SCWindow,
        _ b: SCWindow,
        zRanks: [CGWindowID: Int]
    ) -> Bool {
        switch (zRanks[a.windowID], zRanks[b.windowID]) {
        case let (rankA?, rankB?): return rankA < rankB
        case (.some, nil): return true
        case (nil, .some): return false
        case (nil, nil): return a.windowLayer < b.windowLayer
        }
    }

    /// The window the window-only capture path targets: the top-ranked
    /// normal-layer (`0`) window, front-to-back. This does not scope to a
    /// caller-supplied frontmost bundle id — `attemptCapture`'s trigger flow
    /// (`noteWindowChanged`/`noteCompletionActivity`) does not carry one
    /// through to `performCapture`, unlike `freshScene`, which only learns it
    /// from the completion request at read time — so this uses the same
    /// "top-ranked layer-0 window overall" proxy `AppDelegate.currentFrontWindowIdentity()`
    /// already relies on elsewhere for the same purpose. Layer-0 excludes
    /// menu bar extras, the dock, and other chrome that would otherwise win
    /// on raw z-order alone.
    private static func frontmostWindow(among windows: [SCWindow], zRanks: [CGWindowID: Int]) -> SCWindow? {
        windows
            .sorted { frontToBackPrecedes($0, $1, zRanks: zRanks) }
            .first { $0.windowLayer == 0 }
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

    /// Crops `image` to the pixel rect equivalent to `normalizedRegion`
    /// (top-left origin, 0...1, same convention `LuminanceGridSampler` and
    /// `CaptureChangeDetector` already share) so only that part of the frame
    /// gets OCR'd. `CaptureChangeDetector.decision` already clamps and pads
    /// its region into 0...1, but this clamps again against the image's
    /// actual pixel bounds — belt-and-suspenders against float rounding
    /// ever handing `CGImage.cropping(to:)` an out-of-bounds rect, which
    /// returns `nil` and would otherwise silently drop the region's text.
    /// Returns `nil` if the resulting rect is degenerate (zero width or
    /// height) or the crop itself fails.
    private static func cropped(_ image: CGImage, to normalizedRegion: NormalizedDisplayRect) -> CGImage? {
        let width = Double(image.width)
        let height = Double(image.height)
        guard width > 0, height > 0 else { return nil }

        let minX = max(0, min(normalizedRegion.minX * width, width))
        let minY = max(0, min(normalizedRegion.minY * height, height))
        let maxX = max(0, min(normalizedRegion.maxX * width, width))
        let maxY = max(0, min(normalizedRegion.maxY * height, height))
        let pixelRect = CGRect(x: minX, y: minY, width: max(0, maxX - minX), height: max(0, maxY - minY)).integral
        guard pixelRect.width >= 1, pixelRect.height >= 1 else { return nil }
        return image.cropping(to: pixelRect)
    }
}
