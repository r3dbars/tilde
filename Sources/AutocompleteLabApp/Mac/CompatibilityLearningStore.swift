import Foundation
import AutocompleteLabCore

final class CompatibilityLearningStore: @unchecked Sendable {
    static let shared = CompatibilityLearningStore(
        fileURL: FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AutocompleteLab/compatibility-learning.json")
    )

    private let queue = DispatchQueue(label: "app.transcripted.autocomplete.compatibility-learning")
    private let fileURL: URL
    private let screenshotTracingDuration: TimeInterval
    private let now: () -> Date
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        fileURL: URL,
        screenshotTracingDuration: TimeInterval = 60 * 60,
        now: @escaping () -> Date = Date.init
    ) {
        self.fileURL = fileURL
        self.screenshotTracingDuration = screenshotTracingDuration
        self.now = now
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    var path: String {
        fileURL.path
    }

    func engine() -> CompatibilityLearningEngine {
        CompatibilityLearningEngine(profiles: profiles())
    }

    func profile(for bundleIdentifier: String) -> CompatibilityLearningProfile? {
        profiles()[bundleIdentifier]
    }

    func setScreenshotTracing(_ enabled: Bool, for bundleIdentifier: String) {
        update(bundleIdentifier: bundleIdentifier, reason: enabled ? "screenshot-tracing-enabled" : "screenshot-tracing-disabled") { profile in
            profile.screenshotTracingEnabled = enabled
            profile.screenshotTracingExpiresAt = enabled
                ? ISO8601DateFormatter().string(from: now().addingTimeInterval(screenshotTracingDuration))
                : nil
        }
    }

    func recordObservation(for bundleIdentifier: String, reason: String) {
        update(bundleIdentifier: bundleIdentifier, reason: reason) { profile in
            profile.observations += 1
            profile.confidence = min(1, profile.confidence + 0.05)
        }
    }

    func updateOffset(x: Double, y: Double, for bundleIdentifier: String, reason: String) {
        update(bundleIdentifier: bundleIdentifier, reason: reason) { profile in
            profile.xOffset = x
            profile.yOffset = y
            profile.observations += 1
            profile.confidence = min(1, max(profile.confidence, 0.25))
        }
    }

    func nudgeOffset(dx: Double, dy: Double, for bundleIdentifier: String) {
        update(bundleIdentifier: bundleIdentifier, reason: "manual-visual-nudge") { profile in
            profile.xOffset += dx
            profile.yOffset += dy
            profile.observations += 1
            profile.confidence = min(1, max(profile.confidence, 0.35))
        }
    }

    func reset(bundleIdentifier: String) {
        queue.sync { [fileURL, encoder, decoder] in
            guard let data = try? Data(contentsOf: fileURL),
                  var profiles = try? decoder.decode([String: CompatibilityLearningProfile].self, from: data) else {
                return
            }

            profiles.removeValue(forKey: bundleIdentifier)

            do {
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try encoder.encode(profiles).write(to: fileURL, options: .atomic)
            } catch {
                DiagnosticsLog.shared.record(
                    "compatibility-learning-reset-failed",
                    metadata: ["reason": error.localizedDescription]
                )
            }
        }
    }

    func deleteAll() {
        queue.sync { [fileURL] in
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    func disableScreenshotTracing() {
        queue.sync { [fileURL, encoder, decoder, now] in
            guard let data = try? Data(contentsOf: fileURL),
                  var profiles = try? decoder.decode([String: CompatibilityLearningProfile].self, from: data) else {
                return
            }

            let timestamp = ISO8601DateFormatter().string(from: now())
            var changed = false
            for bundleIdentifier in profiles.keys {
                guard var profile = profiles[bundleIdentifier],
                      profile.screenshotTracingEnabled || profile.screenshotTracingExpiresAt != nil else {
                    continue
                }

                profile.screenshotTracingEnabled = false
                profile.screenshotTracingExpiresAt = nil
                profile.lastReason = "screenshot-tracing-disabled"
                profile.updatedAt = timestamp
                profiles[bundleIdentifier] = profile
                changed = true
            }

            guard changed else {
                return
            }

            do {
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try encoder.encode(profiles).write(to: fileURL, options: .atomic)
            } catch {
                DiagnosticsLog.shared.record(
                    "compatibility-learning-disable-screenshot-tracing-failed",
                    metadata: ["reason": error.localizedDescription]
                )
            }
        }
    }

    private func profiles() -> [String: CompatibilityLearningProfile] {
        queue.sync { [fileURL, encoder, decoder] in
            guard let data = try? Data(contentsOf: fileURL),
                  let profiles = try? decoder.decode([String: CompatibilityLearningProfile].self, from: data) else {
                return [:]
            }

            let sanitized = sanitizeScreenshotTracing(in: profiles)
            if sanitized != profiles {
                do {
                    try encoder.encode(sanitized).write(to: fileURL, options: .atomic)
                } catch {
                    DiagnosticsLog.shared.record(
                        "compatibility-learning-expiry-write-failed",
                        metadata: ["reason": error.localizedDescription]
                    )
                }
            }

            return sanitized
        }
    }

    private func update(
        bundleIdentifier: String,
        reason: String,
        mutate: (inout CompatibilityLearningProfile) -> Void
    ) {
        queue.sync { [fileURL, encoder, decoder] in
            var profiles: [String: CompatibilityLearningProfile]
            if let data = try? Data(contentsOf: fileURL),
               let decoded = try? decoder.decode([String: CompatibilityLearningProfile].self, from: data) {
                profiles = decoded
            } else {
                profiles = [:]
            }

            var profile = profiles[bundleIdentifier] ?? CompatibilityLearningProfile(bundleIdentifier: bundleIdentifier)
            mutate(&profile)
            profile.lastReason = reason
            profile.updatedAt = ISO8601DateFormatter().string(from: now())
            profiles[bundleIdentifier] = profile

            do {
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try encoder.encode(profiles).write(to: fileURL, options: .atomic)
            } catch {
                DiagnosticsLog.shared.record(
                    "compatibility-learning-write-failed",
                    metadata: ["reason": error.localizedDescription]
                )
            }
        }
    }

    private func sanitizeScreenshotTracing(
        in profiles: [String: CompatibilityLearningProfile]
    ) -> [String: CompatibilityLearningProfile] {
        var sanitized = profiles
        for bundleIdentifier in sanitized.keys {
            guard var profile = sanitized[bundleIdentifier] else {
                continue
            }

            if screenshotTracingIsActive(profile) {
                continue
            }

            guard profile.screenshotTracingEnabled || profile.screenshotTracingExpiresAt != nil else {
                continue
            }

            profile.screenshotTracingEnabled = false
            profile.screenshotTracingExpiresAt = nil
            sanitized[bundleIdentifier] = profile
        }

        return sanitized
    }

    private func screenshotTracingIsActive(_ profile: CompatibilityLearningProfile) -> Bool {
        guard profile.screenshotTracingEnabled,
              let expiresAtValue = profile.screenshotTracingExpiresAt,
              let expiresAt = ISO8601DateFormatter().date(from: expiresAtValue) else {
            return false
        }

        return expiresAt > now()
    }
}
