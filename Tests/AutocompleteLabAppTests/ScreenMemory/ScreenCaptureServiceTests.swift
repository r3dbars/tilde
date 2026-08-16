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
            devModeEnabled: { true },
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
            devModeEnabled: { true },
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

    @Test("Dev mode disabled skips before ever checking the master toggle, and logs the exact reason")
    func devModeDisabledSkipsEarly() async {
        let (sink, events) = recordingDiagnostics()
        let service = ScreenCaptureService(
            devModeEnabled: { false },
            enabled: { Issue.record("enabled should not be checked before devModeEnabled"); return false },
            excludedApps: { [] },
            permissionGranted: { false },
            screenLocked: { false },
            secureInputActive: { false },
            recognizeText: { _ in [] },
            now: { Date() },
            diagnostics: sink
        )
        let outcome = await service.noteWindowChanged()
        #expect(outcome == .devModeDisabled)
        #expect(events.values.contains { $0.0 == "screen-capture-skipped" && $0.1["reason"] == "dev-flag-off" })
        // Distinguishable from the master toggle being off: same event,
        // different literal reason — that distinction is the whole point.
        #expect(!events.values.contains { $0.1["reason"] == "disabled" })
    }

    @Test("noteCompletionActivity does not disturb the enabled/permission gates")
    func completionActivityDoesNotBypassGates() async {
        let service = ScreenCaptureService(
            devModeEnabled: { true },
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

    @Test("enabled is read fresh on every trigger, not cached at init")
    func enabledProviderIsReadLive() async {
        let flag = LockedFlag(true)
        let service = ScreenCaptureService(
            devModeEnabled: { true },
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

    @Test("devModeEnabled is read fresh on every trigger, not cached at init")
    func devModeEnabledProviderIsReadLive() async {
        let flag = LockedFlag(true)
        let service = ScreenCaptureService(
            devModeEnabled: { flag.value },
            enabled: { true },
            excludedApps: { [] },
            permissionGranted: { false },
            screenLocked: { false },
            secureInputActive: { false },
            recognizeText: { _ in [] },
            now: { Date() },
            diagnostics: { _, _ in }
        )
        // Still true: gets past `devModeEnabled`, stops at permission.
        #expect(await service.noteWindowChanged() == .permissionNotGranted)
        flag.value = false
        // Flipped without recreating the service: now stops at `devModeEnabled`.
        #expect(await service.noteWindowChanged() == .devModeDisabled)
    }

    @Test("latestSnapshot starts nil and is never populated without a successful capture")
    func latestSnapshotStartsNil() async {
        let service = ScreenCaptureService(
            devModeEnabled: { true },
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
            devModeEnabled: { true },
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
            devModeEnabled: { true },
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
