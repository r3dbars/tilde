import AutocompleteLabCore
import Foundation
import Testing
@testable import AutocompleteLabApp

/// Exercises `ScreenCaptureService`'s own wiring — the parts that sit in
/// front of ScreenCaptureKit itself. Everything ScreenCaptureKit-shaped
/// (SCShareableContent, SCContentFilter) is not constructible outside a
/// granted, live display, so the deeper trigger-policy branches (screen
/// lock, secure input, exclusion, cadence) are proven once, purely, in
/// CaptureTriggerPolicyTests — this file only proves the actor stops before
/// ever reaching ScreenCaptureKit when it should, and that it reads
/// `enabled`/`excludedApps` fresh rather than caching them at init.
@Suite("Screen capture service")
struct ScreenCaptureServiceTests {
    private func recordingDiagnostics() -> (
        sink: @Sendable (String, [String: String]) -> Void,
        events: EventBox
    ) {
        let box = EventBox()
        let sink: @Sendable (String, [String: String]) -> Void = { event, metadata in
            box.append((event, metadata))
        }
        return (sink, box)
    }

    @Test("Disabled service skips before ever touching ScreenCaptureKit")
    func disabledSkipsEarly() async {
        let (sink, events) = recordingDiagnostics()
        let service = ScreenCaptureService(
            enabled: { false },
            excludedApps: { [] },
            permissionGranted: { Issue.record("permissionGranted should not be checked before enabled"); return false },
            screenLocked: { false },
            secureInputActive: { false },
            recognizeText: { _ in [] },
            now: { Date() },
            diagnostics: sink
        )
        let outcome = await service.noteWindowChanged()
        #expect(outcome == .skipped(.disabled))
        #expect(events.values.contains { $0.0 == "screen-capture-skipped" && $0.1["reason"] == "disabled" })
    }

    @Test("Permission not granted skips before enumerating windows, and logs the exact reason")
    func permissionNotGrantedSkipsEarly() async {
        let (sink, events) = recordingDiagnostics()
        let service = ScreenCaptureService(
            enabled: { true },
            excludedApps: { [] },
            permissionGranted: { false },
            screenLocked: { Issue.record("screenLocked should not be checked before permission"); return false },
            secureInputActive: { false },
            recognizeText: { _ in [] },
            now: { Date() },
            diagnostics: sink
        )
        let outcome = await service.noteWindowChanged()
        #expect(outcome == .permissionNotGranted)
        #expect(events.values.contains { $0.0 == "screen-capture-skipped" && $0.1["reason"] == "no-permission" })
    }

    @Test("No text field means no ScreenCaptureKit enumeration")
    func textFieldRequiredBeforeCapture() async {
        let service = ScreenCaptureService(
            enabled: { true },
            excludedApps: { [] },
            permissionGranted: { true },
            screenLocked: { false },
            secureInputActive: { false },
            shareableContent: {
                Issue.record("shareableContent should not run without an active text field")
                throw CocoaError(.fileReadUnknown)
            },
            recognizeText: { _ in [] },
            now: { Date() },
            diagnostics: { _, _ in }
        )
        #expect(await service.noteWindowChanged() == .skipped(.noActiveTextField))
    }

    @Test("noteCompletionActivity does not disturb the enabled/permission gates")
    func completionActivityDoesNotBypassGates() async {
        let service = ScreenCaptureService(
            enabled: { true },
            excludedApps: { [] },
            permissionGranted: { false },
            screenLocked: { false },
            secureInputActive: { false },
            recognizeText: { _ in [] },
            now: { Date() },
            diagnostics: { _, _ in }
        )
        await service.noteCompletionActivity()
        let outcome = await service.noteWindowChanged()
        #expect(outcome == .permissionNotGranted)
    }

    @Test("Only the focused IMKit session can schedule typing refreshes")
    func textFieldSessionOwnership() async {
        let service = ScreenCaptureService(
            enabled: { false },
            excludedApps: { [] },
            permissionGranted: { false },
            screenLocked: { false },
            secureInputActive: { false },
            recognizeText: { _ in [] },
            now: { Date() },
            diagnostics: { _, _ in }
        )
        let focused = UUID().uuidString
        let stale = UUID().uuidString

        #expect(await service.noteTextFieldFocused(sessionIdentifier: focused) == .skipped(.disabled))
        #expect(await service.noteTypingPaused(sessionIdentifier: stale) == nil)
        #expect(await service.noteTypingPaused(sessionIdentifier: focused) == .skipped(.disabled))

        await service.noteTextFieldBlurred(sessionIdentifier: stale)
        #expect(await service.noteTypingPaused(sessionIdentifier: focused) == .skipped(.disabled))

        await service.noteTextFieldBlurred(sessionIdentifier: focused)
        #expect(await service.noteTypingPaused(sessionIdentifier: focused) == nil)
    }

    @Test("enabled is read fresh on every trigger, not cached at init")
    func enabledProviderIsReadLive() async {
        let flag = LockedFlag(true)
        let service = ScreenCaptureService(
            enabled: { flag.value },
            excludedApps: { [] },
            permissionGranted: { false },
            screenLocked: { false },
            secureInputActive: { false },
            recognizeText: { _ in [] },
            now: { Date() },
            diagnostics: { _, _ in }
        )
        // Still true: gets past `enabled`, stops at permission.
        #expect(await service.noteWindowChanged() == .permissionNotGranted)
        flag.value = false
        // Flipped without recreating the service: now stops at `enabled`.
        #expect(await service.noteWindowChanged() == .skipped(.disabled))
    }

    @Test("latestSnapshot starts nil and is never populated without a successful capture")
    func latestSnapshotStartsNil() async {
        let service = ScreenCaptureService(
            enabled: { false },
            excludedApps: { [] },
            permissionGranted: { false },
            screenLocked: { false },
            secureInputActive: { false },
            recognizeText: { _ in [] },
            now: { Date() },
            diagnostics: { _, _ in }
        )
        #expect(await service.latestSnapshot == nil)
        _ = await service.noteWindowChanged()
        #expect(await service.latestSnapshot == nil)
    }

    // MARK: - freshScene (Screen Memory plan Phase 2 PR 2b)

    private func makeService() -> ScreenCaptureService {
        ScreenCaptureService(
            enabled: { false },
            excludedApps: { [] },
            permissionGranted: { false },
            screenLocked: { false },
            secureInputActive: { false },
            recognizeText: { _ in [] },
            now: { Date() },
            diagnostics: { _, _ in }
        )
    }

    @Test("freshScene reads whatever the last successful capture stored, without triggering a new one")
    func freshSceneReadsLatestSnapshotOnly() async {
        let service = makeService()
        let referenceMoment = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = ScreenSnapshot(
            capturedAt: referenceMoment,
            displayID: 1,
            blocks: [
                ScreenSnapshot.TextBlock(
                    text: "hey are you around today",
                    boundingBox: NormalizedDisplayRect(x: 0.05, y: 0.30, width: 0.35, height: 0.05),
                    windowOwnerBundleIdentifier: "com.tinyspeck.slackmacgap",
                    windowFrame: NormalizedDisplayRect(x: 0, y: 0, width: 1, height: 1)
                ),
                ScreenSnapshot.TextBlock(
                    text: "yeah free after 3pm works",
                    boundingBox: NormalizedDisplayRect(x: 0.55, y: 0.60, width: 0.35, height: 0.05),
                    windowOwnerBundleIdentifier: "com.tinyspeck.slackmacgap",
                    windowFrame: NormalizedDisplayRect(x: 0, y: 0, width: 1, height: 1)
                ),
            ]
        )
        await service.setLatestSnapshotForTesting(snapshot)

        let fresh = await service.freshScene(
            frontmostBundleID: "com.tinyspeck.slackmacgap",
            fieldText: "",
            now: referenceMoment.addingTimeInterval(5)
        )
        #expect(fresh?.mode == .replying)

        let stale = await service.freshScene(
            frontmostBundleID: "com.tinyspeck.slackmacgap",
            fieldText: "",
            now: referenceMoment.addingTimeInterval(25)
        )
        #expect(stale == nil)
    }

    @Test("freshScene prefers a fresh window read with a conversation over a later display read without one")
    func freshScenePrefersWindowConversation() async {
        let service = makeService()
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let slack = "com.tinyspeck.slackmacgap"
        let frame = NormalizedDisplayRect(x: 0.3, y: 0.2, width: 0.4, height: 0.5)
        let windowRead = ScreenSnapshot(capturedAt: t0, displayID: 1, blocks: [
            ScreenSnapshot.TextBlock(text: "want me to grab it for you?",
                boundingBox: NormalizedDisplayRect(x: 0.31, y: 0.30, width: 0.20, height: 0.03),
                windowOwnerBundleIdentifier: slack, windowFrame: frame),
            ScreenSnapshot.TextBlock(text: "yes please",
                boundingBox: NormalizedDisplayRect(x: 0.48, y: 0.50, width: 0.20, height: 0.03),
                windowOwnerBundleIdentifier: slack, windowFrame: frame),
        ])
        // A later full-display read whose attribution missed the window.
        let displayRead = ScreenSnapshot(capturedAt: t0.addingTimeInterval(2), displayID: 1, blocks: [
            ScreenSnapshot.TextBlock(text: "want me to grab it for you?",
                boundingBox: NormalizedDisplayRect(x: 0.31, y: 0.30, width: 0.20, height: 0.03),
                windowOwnerBundleIdentifier: nil, windowFrame: nil),
        ])
        await service.setLatestWindowSnapshotForTesting(windowRead)
        await service.setLatestSnapshotForTesting(displayRead)

        let scene = await service.freshScene(frontmostBundleID: slack, fieldText: "", now: t0.addingTimeInterval(3))
        #expect(scene?.mode == .replying)
        #expect(scene?.conversationTurns.count == 2)

        // Once the window read is stale, the latest read is all there is.
        let later = await service.freshScene(frontmostBundleID: slack, fieldText: "", now: t0.addingTimeInterval(21))
        #expect(later?.mode != .replying)
    }

    @Test("AX reader thresholds fall back to OCR rather than trusting thin trees")
    func axReaderThresholds() {
        // The walk itself needs a live AX tree; what unit tests can pin is
        // the contract that keeps Electron/Chromium windows on the OCR
        // path: too few text nodes or too little text means nil, and the
        // walk is bounded so it can never stall a capture.
        #expect(AXWindowTextReader.minimumBlocks == 2)
        #expect(AXWindowTextReader.minimumCharacters == 40)
        #expect(AXWindowTextReader.timeoutSeconds <= 0.2)
        #expect(AXWindowTextReader.nodeBudget <= 5_000)
    }

    @Test("A snapshot captured before a content reset is never served")
    func contentResetInvalidatesOlderSnapshots() async {
        let service = makeService()
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let slack = "com.tinyspeck.slackmacgap"
        let frame = NormalizedDisplayRect(x: 0, y: 0, width: 1, height: 1)
        let snapshot = ScreenSnapshot(capturedAt: t0, displayID: 1, blocks: [
            ScreenSnapshot.TextBlock(text: "want me to grab it for you today?",
                boundingBox: NormalizedDisplayRect(x: 0.05, y: 0.30, width: 0.35, height: 0.05),
                windowOwnerBundleIdentifier: slack, windowFrame: frame),
            ScreenSnapshot.TextBlock(text: "yes please, that would be great",
                boundingBox: NormalizedDisplayRect(x: 0.55, y: 0.60, width: 0.35, height: 0.05),
                windowOwnerBundleIdentifier: slack, windowFrame: frame),
        ])
        await service.setLatestSnapshotForTesting(snapshot)
        await service.setLatestWindowSnapshotForTesting(snapshot)

        // Fresh and valid before the reset...
        let before = await service.freshScene(frontmostBundleID: slack, fieldText: "", now: t0.addingTimeInterval(2))
        #expect(before?.mode == .replying)

        // ...gone the moment the content reset lands, even though the
        // snapshot is still inside the staleness window.
        await service.setLastContentResetAtForTesting(t0.addingTimeInterval(3))
        let after = await service.freshScene(frontmostBundleID: slack, fieldText: "", now: t0.addingTimeInterval(4))
        #expect(after == nil)
    }

    /// Fix item 4 of "Classify scenes by geometry, not host app": a
    /// classification must never be opaque again. Count-only -- mode plus
    /// two integers, never any of the OCR'd text.
    @Test("freshScene logs a count-only scene-classified diagnostic after a real classification")
    func freshSceneLogsCountOnlyDiagnostic() async {
        let (sink, events) = recordingDiagnostics()
        let service = ScreenCaptureService(
            enabled: { false },
            excludedApps: { [] },
            permissionGranted: { false },
            screenLocked: { false },
            secureInputActive: { false },
            recognizeText: { _ in [] },
            now: { Date() },
            diagnostics: sink
        )
        let referenceMoment = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = ScreenSnapshot(
            capturedAt: referenceMoment,
            displayID: 1,
            blocks: [
                ScreenSnapshot.TextBlock(
                    text: "hey are you around today",
                    boundingBox: NormalizedDisplayRect(x: 0.05, y: 0.30, width: 0.35, height: 0.05),
                    windowOwnerBundleIdentifier: "com.tinyspeck.slackmacgap",
                    windowFrame: NormalizedDisplayRect(x: 0, y: 0, width: 1, height: 1)
                ),
                ScreenSnapshot.TextBlock(
                    text: "yeah free after 3pm works",
                    boundingBox: NormalizedDisplayRect(x: 0.55, y: 0.60, width: 0.35, height: 0.05),
                    windowOwnerBundleIdentifier: "com.tinyspeck.slackmacgap",
                    windowFrame: NormalizedDisplayRect(x: 0, y: 0, width: 1, height: 1)
                ),
            ]
        )
        await service.setLatestSnapshotForTesting(snapshot)

        let scene = await service.freshScene(
            frontmostBundleID: "com.tinyspeck.slackmacgap",
            fieldText: "",
            now: referenceMoment.addingTimeInterval(5)
        )
        #expect(scene?.mode == .replying)

        let logged = events.values.first { $0.0 == "scene-classified" }
        #expect(logged?.1["mode"] == "replying")
        #expect(logged?.1["turns"] == "2")
        #expect(logged?.1["refs"] == "0")
        // "P99 at every section" (2026-08-18): the classification call is
        // timed too, as a non-negative whole-millisecond integer.
        #expect(logged?.1["milliseconds"].flatMap { Int($0) }.map { $0 >= 0 } == true)
        // Never the OCR'd text itself.
        #expect(logged?.1.values.contains { $0.contains("hey are you around") } != true)
    }

    @Test("freshScene logs nothing when there is no snapshot to classify")
    func freshSceneLogsNothingWithoutASnapshot() async {
        let (sink, events) = recordingDiagnostics()
        let service = ScreenCaptureService(
            enabled: { false },
            excludedApps: { [] },
            permissionGranted: { false },
            screenLocked: { false },
            secureInputActive: { false },
            recognizeText: { _ in [] },
            now: { Date() },
            diagnostics: sink
        )
        let scene = await service.freshScene(frontmostBundleID: "com.apple.TextEdit", fieldText: "hello")
        #expect(scene == nil)
        #expect(!events.values.contains { $0.0 == "scene-classified" })
    }

    @Test("freshScene with no captured snapshot yet returns nil — today's behavior")
    func freshSceneWithNoSnapshotReturnsNil() async {
        let service = makeService()
        let fresh = await service.freshScene(frontmostBundleID: "com.apple.TextEdit", fieldText: "hello")
        #expect(fresh == nil)
    }

    /// Covenant regression: a capture taken BEFORE an app was added to the
    /// exclusion list must not keep serving that app's text for the rest of
    /// the 20s staleness window once the exclusion list changes.
    /// `excludedApps` is a live provider, so `freshScene` must consult its
    /// CURRENT value on every read, not whatever was true at capture time.
    @Test("freshScene drops blocks from an app that became excluded after the snapshot was captured")
    func freshSceneFiltersNewlyExcludedAppBlocks() async {
        let excluded = LockedSet<String>([])
        let service = ScreenCaptureService(
            enabled: { false },
            excludedApps: { excluded.value },
            permissionGranted: { false },
            screenLocked: { false },
            secureInputActive: { false },
            recognizeText: { _ in [] },
            now: { Date() },
            diagnostics: { _, _ in }
        )
        let referenceMoment = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = ScreenSnapshot(
            capturedAt: referenceMoment,
            displayID: 1,
            blocks: [
                ScreenSnapshot.TextBlock(
                    text: "hey are you around today",
                    boundingBox: NormalizedDisplayRect(x: 0.05, y: 0.30, width: 0.35, height: 0.05),
                    windowOwnerBundleIdentifier: "com.tinyspeck.slackmacgap",
                    windowFrame: NormalizedDisplayRect(x: 0, y: 0, width: 1, height: 1)
                ),
                ScreenSnapshot.TextBlock(
                    text: "yeah free after 3pm works",
                    boundingBox: NormalizedDisplayRect(x: 0.55, y: 0.60, width: 0.35, height: 0.05),
                    windowOwnerBundleIdentifier: "com.tinyspeck.slackmacgap",
                    windowFrame: NormalizedDisplayRect(x: 0, y: 0, width: 1, height: 1)
                ),
            ]
        )
        await service.setLatestSnapshotForTesting(snapshot)

        // Not yet excluded: the snapshot classifies normally.
        let beforeExclusion = await service.freshScene(
            frontmostBundleID: "com.tinyspeck.slackmacgap",
            fieldText: "",
            now: referenceMoment.addingTimeInterval(2)
        )
        #expect(beforeExclusion?.mode == .replying)

        // The user excludes the app; the SAME cached (still-fresh) snapshot
        // must no longer surface its text, even though nothing re-captured.
        excluded.value = ["com.tinyspeck.slackmacgap"]
        let afterExclusion = await service.freshScene(
            frontmostBundleID: "com.tinyspeck.slackmacgap",
            fieldText: "",
            now: referenceMoment.addingTimeInterval(4)
        )
        #expect(afterExclusion?.mode == .composing)
        #expect(afterExclusion?.conversationTurns.isEmpty == true)
    }

    // MARK: - Duty-cycle instrumentation (Phase 1b)
    //
    // `performCapture` itself cannot be unit-tested (see the type doc
    // comment: SCShareableContent/SCContentFilter need a live, permissioned
    // display). This proves the one piece of the duration math that lives
    // outside ScreenCaptureKit — script/capture_power_probe.sh and
    // script/screen_capture_probe.swift are the real, live callers that
    // exercise the full instrumented path per docs/plans/screen-memory.md.

    @Test("Capture requests backing pixels, not points, on Retina displays")
    func pixelScaleUsesBackingSize() {
        #expect(ScreenCaptureService.pixelScale(pixelWidth: 3024, pointWidth: 1512) == 2)
        #expect(ScreenCaptureService.pixelScale(pixelWidth: 3840, pointWidth: 1920) == 2)
        #expect(ScreenCaptureService.pixelScale(pixelWidth: 1920, pointWidth: 1920) == 1)
        // Unknown backing size must never shrink the capture.
        #expect(ScreenCaptureService.pixelScale(pixelWidth: 0, pointWidth: 1512) == 1)
    }

    @Test("duration milliseconds rounds to the nearest whole millisecond")
    func durationRoundsToNearestMillisecond() {
        let start = Date(timeIntervalSince1970: 0)
        #expect(ScreenCaptureService.milliseconds(from: start, to: start.addingTimeInterval(0.1874)) == 187)
        #expect(ScreenCaptureService.milliseconds(from: start, to: start.addingTimeInterval(0.1876)) == 188)
    }

    @Test("duration milliseconds floors at zero for a clock that does not advance")
    func durationFloorsAtZero() {
        let instant = Date(timeIntervalSince1970: 1_000)
        #expect(ScreenCaptureService.milliseconds(from: instant, to: instant) == 0)
        // A clock that appears to run backward (e.g. an injected test clock
        // reset between calls) must never report a negative duration.
        #expect(ScreenCaptureService.milliseconds(from: instant, to: instant.addingTimeInterval(-1)) == 0)
    }

    // MARK: - Local paired OCR evaluation

    private func evaluationBlock(_ text: String, owner: String? = "com.example.Editor") -> ScreenSnapshot.TextBlock {
        ScreenSnapshot.TextBlock(
            text: text,
            boundingBox: NormalizedDisplayRect(x: 0.1, y: 0.2, width: 0.3, height: 0.04),
            windowOwnerBundleIdentifier: owner,
            windowTitle: "Draft"
        )
    }

    @Test("Paired evaluation records only incremental scopes and filters newly excluded apps")
    func pairedEvaluationGatesAndFilters() async {
        let captureEnabled = LockedFlag(true)
        let enabled = LockedFlag(false)
        let exclusions = LockedSet<String>(["com.example.Secret"])
        let records = EvaluationRecordBox()
        let service = ScreenCaptureService(
            enabled: { captureEnabled.value },
            excludedApps: { exclusions.value },
            permissionGranted: { true },
            screenLocked: { false },
            secureInputActive: { false },
            recognizeText: { _ in [] },
            now: Date.init,
            diagnostics: { _, _ in },
            localOCREvaluationEnabled: { enabled.value },
            localOCREvaluationGeneration: { 7 },
            recordOCREvaluation: { records.append($0, generation: $1) }
        )
        let candidate = [
            evaluationBlock("allowed"),
            evaluationBlock("excluded", owner: "com.example.Secret"),
            evaluationBlock("password", owner: "com.1password.1password"),
        ]

        await service.recordLocalOCREvaluationIfEnabled(
            capturedAt: Date(timeIntervalSince1970: 1),
            captureKind: "display",
            incrementalScope: "region",
            incrementalMilliseconds: 10,
            incrementalBlocks: candidate,
            referenceOCR: { Issue.record("disabled evaluation must not OCR"); return ([], 0) }
        )
        enabled.value = true
        await service.recordLocalOCREvaluationIfEnabled(
            capturedAt: Date(timeIntervalSince1970: 1),
            captureKind: "display",
            incrementalScope: "full",
            incrementalMilliseconds: 200,
            incrementalBlocks: candidate,
            referenceOCR: { Issue.record("full scope must not run a second OCR"); return ([], 0) }
        )
        await service.recordLocalOCREvaluationIfEnabled(
            capturedAt: Date(timeIntervalSince1970: 1),
            captureKind: "display",
            incrementalScope: "region",
            incrementalMilliseconds: 10,
            incrementalBlocks: candidate,
            referenceOCR: { (candidate, 200) }
        )

        #expect(records.values.count == 1)
        #expect(records.values.first?.generation == 7)
        #expect(records.values.first?.sample.incrementalBlocks.map(\.text) == ["allowed"])
        #expect(records.values.first?.sample.fullReferenceBlocks.map(\.text) == ["allowed"])
    }

    @Test("Paired evaluation rechecks consent and safety after reference OCR")
    func pairedEvaluationRechecksSafety() async {
        let captureEnabled = LockedFlag(true)
        let permissionGranted = LockedFlag(true)
        let enabled = LockedFlag(true)
        let secureInput = LockedFlag(false)
        let records = EvaluationRecordBox()
        let service = ScreenCaptureService(
            enabled: { captureEnabled.value },
            excludedApps: { [] },
            permissionGranted: { permissionGranted.value },
            screenLocked: { false },
            secureInputActive: { secureInput.value },
            recognizeText: { _ in [] },
            now: Date.init,
            diagnostics: { _, _ in },
            localOCREvaluationEnabled: { enabled.value },
            localOCREvaluationGeneration: { 9 },
            recordOCREvaluation: { records.append($0, generation: $1) }
        )
        let block = evaluationBlock("sensitive")

        await service.recordLocalOCREvaluationIfEnabled(
            capturedAt: Date(),
            captureKind: "window",
            incrementalScope: "region",
            incrementalMilliseconds: 10,
            incrementalBlocks: [block],
            referenceOCR: {
                secureInput.value = true
                return ([block], 200)
            }
        )
        #expect(records.values.isEmpty)

        secureInput.value = false
        captureEnabled.value = false
        await service.recordLocalOCREvaluationIfEnabled(
            capturedAt: Date(),
            captureKind: "window",
            incrementalScope: "region",
            incrementalMilliseconds: 10,
            incrementalBlocks: [block],
            referenceOCR: {
                return ([block], 200)
            }
        )
        #expect(records.values.isEmpty)

        captureEnabled.value = true
        permissionGranted.value = false
        await service.recordLocalOCREvaluationIfEnabled(
            capturedAt: Date(),
            captureKind: "window",
            incrementalScope: "region",
            incrementalMilliseconds: 10,
            incrementalBlocks: [block],
            referenceOCR: { ([block], 200) }
        )
        #expect(records.values.isEmpty)
    }

    @Test("Paired evaluation is single-flight while reference OCR is running")
    func pairedEvaluationSuppressesConcurrentReferencePasses() async {
        let gate = AsyncTestGate()
        let records = EvaluationRecordBox()
        let service = ScreenCaptureService(
            enabled: { true },
            excludedApps: { [] },
            permissionGranted: { true },
            screenLocked: { false },
            secureInputActive: { false },
            recognizeText: { _ in [] },
            now: Date.init,
            diagnostics: { _, _ in },
            localOCREvaluationEnabled: { true },
            localOCREvaluationGeneration: { 12 },
            recordOCREvaluation: { records.append($0, generation: $1) }
        )
        let block = evaluationBlock("candidate")

        let first = Task {
            await service.recordLocalOCREvaluationIfEnabled(
                capturedAt: Date(),
                captureKind: "display",
                incrementalScope: "region",
                incrementalMilliseconds: 10,
                incrementalBlocks: [block],
                referenceOCR: {
                    await gate.block()
                    return ([block], 200)
                }
            )
        }
        await gate.waitUntilBlocked()

        await service.recordLocalOCREvaluationIfEnabled(
            capturedAt: Date(),
            captureKind: "display",
            incrementalScope: "region",
            incrementalMilliseconds: 10,
            incrementalBlocks: [block],
            referenceOCR: {
                Issue.record("a concurrent evaluation must not start reference OCR")
                return ([block], 200)
            }
        )
        await gate.release()
        await first.value

        #expect(records.values.count == 1)
    }

    @Test("Reference OCR failure is metadata-only and never changes capture state")
    func pairedEvaluationReferenceFailure() async {
        let (sink, events) = recordingDiagnostics()
        let records = EvaluationRecordBox()
        let service = ScreenCaptureService(
            enabled: { true },
            excludedApps: { [] },
            permissionGranted: { true },
            screenLocked: { false },
            secureInputActive: { false },
            recognizeText: { _ in [] },
            now: Date.init,
            diagnostics: sink,
            localOCREvaluationEnabled: { true },
            localOCREvaluationGeneration: { 11 },
            recordOCREvaluation: { records.append($0, generation: $1) }
        )

        await service.recordLocalOCREvaluationIfEnabled(
            capturedAt: Date(),
            captureKind: "display",
            incrementalScope: "skipped",
            incrementalMilliseconds: 0,
            incrementalBlocks: [evaluationBlock("candidate")],
            referenceOCR: { throw CocoaError(.fileReadUnknown) }
        )

        #expect(records.values.isEmpty)
        #expect(events.values.count == 1)
        #expect(events.values.first?.0 == "ocr-evaluation-reference-failed")
        #expect(events.values.first?.1 == ["kind": "display", "ocrScope": "skipped"])
    }
}

/// Thread-safe box for capturing diagnostics calls made from actor-isolated code.
final class EventBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [(String, [String: String])] = []

    func append(_ value: (String, [String: String])) {
        lock.lock()
        storage.append(value)
        lock.unlock()
    }

    var values: [(String, [String: String])] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

/// Thread-safe mutable Bool for proving a provider closure is re-invoked
/// rather than snapshotted once.
final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Bool

    init(_ initial: Bool) { storage = initial }

    var value: Bool {
        get { lock.lock(); defer { lock.unlock() }; return storage }
        set { lock.lock(); storage = newValue; lock.unlock() }
    }
}

/// Thread-safe mutable Set, same purpose as `LockedFlag` but for
/// `excludedApps`-shaped providers.
final class LockedSet<Element: Hashable>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Set<Element>

    init(_ initial: Set<Element>) { storage = initial }

    var value: Set<Element> {
        get { lock.lock(); defer { lock.unlock() }; return storage }
        set { lock.lock(); storage = newValue; lock.unlock() }
    }
}

final class EvaluationRecordBox: @unchecked Sendable {
    struct Value: Sendable {
        let sample: LocalOCREvaluationSample
        let generation: UInt64
    }

    private let lock = NSLock()
    private var storage: [Value] = []

    func append(_ sample: LocalOCREvaluationSample, generation: UInt64) {
        lock.lock()
        storage.append(Value(sample: sample, generation: generation))
        lock.unlock()
    }

    var values: [Value] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

actor AsyncTestGate {
    private var blocked = false
    private var continuation: CheckedContinuation<Void, Never>?

    func block() async {
        blocked = true
        await withCheckedContinuation { continuation = $0 }
    }

    func waitUntilBlocked() async {
        while !blocked { await Task.yield() }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}
