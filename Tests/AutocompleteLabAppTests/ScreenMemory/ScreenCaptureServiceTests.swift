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

    @Test("Permission not granted skips before enumerating windows")
    func permissionNotGrantedSkipsEarly() async {
        let service = ScreenCaptureService(
            enabled: { true },
            excludedApps: { [] },
            permissionGranted: { false },
            screenLocked: { Issue.record("screenLocked should not be checked before permission"); return false },
            secureInputActive: { false },
            recognizeText: { _ in [] },
            now: { Date() },
            diagnostics: { _, _ in }
        )
        let outcome = await service.noteWindowChanged()
        #expect(outcome == .permissionNotGranted)
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
