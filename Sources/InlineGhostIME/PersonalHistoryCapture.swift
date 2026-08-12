import AutocompleteLabCore
import Foundation

/// Bounded, memory-only batching on the keyboard side. The key callback only
/// enqueues small values; settings checks, event creation, and authenticated
/// socket I/O happen later on a utility queue. The Tilde app owns every disk
/// write.
final class PersonalHistoryCapture: @unchecked Sendable {
    static let shared = PersonalHistoryCapture()

    private static let maximumBufferedEvents = 192
    private static let flushDelay: TimeInterval = 0.75
    private static let retryDelay: TimeInterval = 5

    private let queue = DispatchQueue(label: "bar.r3d.inputmethod.personal-history", qos: .utility)
    private let defaults: UserDefaults
    private let policy = PersonalHistoryCapturePolicy()
    private var pending: [PersonalHistoryEvent] = []
    private var scheduledFlush: DispatchWorkItem?
    private var sending = false
    private var attemptedEventIDs: Set<String> = []

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func record(
        text: String,
        source: PersonalHistoryEventSource,
        sessionIdentifier: String,
        appBundleIdentifier: String?,
        secureInput: Bool
    ) {
        queue.async { [self] in
            recordOnQueue(
                text: text,
                source: source,
                sessionIdentifier: sessionIdentifier,
                appBundleIdentifier: appBundleIdentifier,
                secureInput: secureInput
            )
        }
    }

    private func recordOnQueue(
        text: String,
        source: PersonalHistoryEventSource,
        sessionIdentifier: String,
        appBundleIdentifier: String?,
        secureInput: Bool
    ) {
        let enabled = defaults.bool(forKey: PersonalHistorySettingsContract.enabledKey)
        let excluded = Set(defaults.stringArray(
            forKey: PersonalHistorySettingsContract.excludedAppsKey
        ) ?? [])
        let historyIdentifier = defaults.string(
            forKey: PersonalHistorySettingsContract.historyIdentifierKey
        )
        switch policy.decision(
            enabled: enabled,
            secureInput: secureInput,
            appBundleIdentifier: appBundleIdentifier,
            excludedApps: excluded
        ) {
        case let .allowed(app):
            guard let historyIdentifier,
                  let event = PersonalHistoryEvent(
                id: UUID().uuidString,
                timestampMilliseconds: Int64(Date().timeIntervalSince1970 * 1_000),
                historyIdentifier: historyIdentifier,
                sessionIdentifier: sessionIdentifier,
                appBundleIdentifier: app,
                source: source,
                text: text
            ) else { return }
            if source == .typed,
               let lastIndex = pending.indices.last,
               !attemptedEventIDs.contains(pending[lastIndex].id),
               let combined = pending[lastIndex].coalescing(with: event) {
                pending[lastIndex] = combined
            } else {
                pending.append(event)
            }
            if pending.count > Self.maximumBufferedEvents {
                pending.removeFirst(pending.count - Self.maximumBufferedEvents)
                retainAttemptedIDsStillPending()
            }
            scheduleFlush(after: Self.flushDelay)

        case let .blocked(reason):
            switch reason {
            case .disabled, .secureInput:
                pending.removeAll(keepingCapacity: true)
                attemptedEventIDs.removeAll(keepingCapacity: true)
            case .excludedApp:
                if let appBundleIdentifier {
                    pending.removeAll { $0.appBundleIdentifier == appBundleIdentifier }
                    retainAttemptedIDsStillPending()
                }
            case .missingOrInvalidApp:
                break
            }
        }
    }

    func flush() {
        queue.async { [self] in scheduleFlush(after: 0) }
    }

    func sensitiveInputBegan() {
        queue.async { [self] in
            scheduledFlush?.cancel()
            scheduledFlush = nil
            pending.removeAll(keepingCapacity: true)
            attemptedEventIDs.removeAll(keepingCapacity: true)
        }
    }

    private func scheduleFlush(after delay: TimeInterval) {
        guard !pending.isEmpty else { return }
        scheduledFlush?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.sendNextBatch() }
        scheduledFlush = work
        queue.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func sendNextBatch() {
        guard !sending, !pending.isEmpty else { return }
        guard defaults.bool(forKey: PersonalHistorySettingsContract.enabledKey),
              let historyIdentifier = defaults.string(
                forKey: PersonalHistorySettingsContract.historyIdentifierKey
              ) else {
            pending.removeAll(keepingCapacity: true)
            attemptedEventIDs.removeAll(keepingCapacity: true)
            return
        }
        let excluded = Set(defaults.stringArray(
            forKey: PersonalHistorySettingsContract.excludedAppsKey
        ) ?? [])
        pending.removeAll {
            $0.historyIdentifier != historyIdentifier
                || excluded.contains($0.appBundleIdentifier)
        }
        retainAttemptedIDsStillPending()
        guard !pending.isEmpty else { return }
        sending = true
        let batch = Array(pending.prefix(PersonalHistoryEvent.maximumBatchEvents))
        let sentIDs = Set(batch.map(\.id))
        attemptedEventIDs.formUnion(sentIDs)

        Task { [weak self] in
            let response = await GhostBrainClient.recordPersonalHistory(batch)
            self?.queue.async { [weak self] in
                guard let self else { return }
                sending = false
                if response == .recorded {
                    pending.removeAll { sentIDs.contains($0.id) }
                    attemptedEventIDs.subtract(sentIDs)
                    scheduleFlush(after: pending.isEmpty ? 0 : Self.flushDelay)
                } else {
                    scheduleFlush(after: Self.retryDelay)
                }
            }
        }
    }

    private func retainAttemptedIDsStillPending() {
        attemptedEventIDs.formIntersection(Set(pending.map(\.id)))
    }
}
