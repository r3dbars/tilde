import Foundation
import Testing
@testable import AutocompleteLabApp

/// Guards for the bug that shipped twice on 2026-07-29: a menu switch bound to
/// a key nothing reads. Both instances were invisible at runtime — the
/// checkmark moved, the behaviour did not — and both survived a green test run,
/// because nothing asserted that a setting's key reaches its reader.
@Suite("Tilde settings")
struct TildeSettingsTests {

    /// Two throwaway suites standing in for the keyboard's domain and the app's.
    private func makeSettings() -> (TildeSettings, UserDefaults, UserDefaults) {
        let keyboardName = "tilde.tests.keyboard.\(UUID().uuidString)"
        let appName = "tilde.tests.app.\(UUID().uuidString)"
        let keyboard = UserDefaults(suiteName: keyboardName)!
        let app = UserDefaults(suiteName: appName)!
        keyboard.removePersistentDomain(forName: keyboardName)
        app.removePersistentDomain(forName: appName)
        return (TildeSettings(keyboard: keyboard, app: app), keyboard, app)
    }

    // MARK: - Defaults

    @Test("A fresh install reads as ON, not OFF")
    func absentKeysDefaultOn() {
        let (settings, _, _) = makeSettings()
        // The keyboard registers these true at launch, but register(defaults:)
        // is process-local — from the app the keys look unset. Reading with
        // bool(forKey:) would report a fresh install as fully switched off.
        #expect(settings.suggestionsEnabled)
        #expect(settings.soundsEnabled)
        #expect(settings.learningEnabled)
        #expect(settings.pausedUntil == nil)
    }

    // MARK: - Domain routing

    @Test("Keyboard settings are written to the keyboard's domain, never the app's")
    func keyboardSettingsLandInKeyboardDomain() {
        let (settings, keyboard, app) = makeSettings()

        settings.suggestionsEnabled = false
        settings.soundsEnabled = false
        settings.learningEnabled = false

        #expect(keyboard.object(forKey: "GhostSuggestionsEnabled") as? Bool == false)
        #expect(keyboard.object(forKey: "GhostSoundsEnabled") as? Bool == false)
        #expect(keyboard.object(forKey: "GhostUsageCaptureEnabled") as? Bool == false)

        // The app's domain must stay clean: a keyboard setting written here is
        // a silent no-op, which is exactly how three dead toggles survived.
        for key in TildeSettings.KeyboardKey.allCases {
            #expect(app.object(forKey: key.rawValue) == nil)
        }
    }

    @Test("App settings are written to the app's domain, never the keyboard's")
    func appSettingsLandInAppDomain() {
        let (settings, keyboard, app) = makeSettings()
        settings.screenAware = true
        #expect(app.bool(forKey: "VisiblePageContextEnabled"))
        #expect(keyboard.object(forKey: "VisiblePageContextEnabled") == nil)
    }

    // MARK: - Round trips

    @Test("Every switch round-trips")
    func togglesRoundTrip() {
        let (settings, _, _) = makeSettings()
        settings.suggestionsEnabled = false
        #expect(!settings.suggestionsEnabled)
        settings.suggestionsEnabled = true
        #expect(settings.suggestionsEnabled)

        settings.soundsEnabled = false
        #expect(!settings.soundsEnabled)

        settings.screenAware = true
        #expect(settings.screenAware)
        settings.screenAware = false
        #expect(!settings.screenAware)
    }

    @Test("Sound is gated by its own switch, not by the volume knob")
    func soundGateIsSeparateFromVolume() {
        let (settings, keyboard, _) = makeSettings()
        // Silencing must not touch the writer's tuned volume: the keyboard's
        // fallback sounds ignore GhostSoundVolume entirely, so muting by
        // volume would not have silenced them.
        keyboard.set(0.8, forKey: "GhostSoundVolume")
        settings.soundsEnabled = false
        #expect(!settings.soundsEnabled)
        #expect(keyboard.double(forKey: "GhostSoundVolume") == 0.8)
        settings.soundsEnabled = true
        #expect(keyboard.double(forKey: "GhostSoundVolume") == 0.8)
    }

    // MARK: - Pause

    @Test("Pause expires on its own and resume clears it")
    func pauseLifecycle() {
        let (settings, keyboard, _) = makeSettings()
        #expect(settings.pausedUntil == nil)

        settings.pause(for: 3600)
        #expect(settings.pausedUntil != nil)

        settings.resume()
        #expect(settings.pausedUntil == nil)

        // A deadline in the past is not a pause — the menu must not offer
        // "Resume" forever after an hour has quietly elapsed.
        keyboard.set(Date().addingTimeInterval(-60).timeIntervalSince1970,
                     forKey: "GhostPausedUntil")
        #expect(settings.pausedUntil == nil)
    }

    // MARK: - The contract that actually catches the recurring bug

    @Test("Every keyboard setting names a key the keyboard really reads")
    func keyboardKeysExistInKeyboardSources() throws {
        // Behavioural tests cannot catch a key the reader never looks at: a
        // toggle writing "GhostSoundVolume" round-trips perfectly while
        // silencing nothing. So assert the contract against the other
        // process's source.
        let sources = try Self.keyboardSourceText()
        for key in TildeSettings.KeyboardKey.allCases {
            #expect(
                sources.contains(key.rawValue),
                "\(key.rawValue) is written by the menu but never read by the keyboard — a silent no-op"
            )
        }
    }

    @Test("Keys are spelled exactly once, so a typo cannot drift")
    func keysAreUnique() {
        let keyboard = TildeSettings.KeyboardKey.allCases.map(\.rawValue)
        let app = TildeSettings.AppKey.allCases.map(\.rawValue)
        #expect(Set(keyboard).count == keyboard.count)
        #expect(Set(keyboard).isDisjoint(with: Set(app)))
    }

    /// Concatenated InlineGhostIME sources, found by walking up from this file
    /// to the package root.
    private static func keyboardSourceText() throws -> String {
        var directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        while directory.pathComponents.count > 1 {
            let candidate = directory.appendingPathComponent("Sources/InlineGhostIME")
            if FileManager.default.fileExists(atPath: candidate.path) {
                let files = try FileManager.default
                    .contentsOfDirectory(at: candidate, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "swift" }
                #expect(!files.isEmpty, "found the keyboard directory but no sources in it")
                return try files.map { try String(contentsOf: $0, encoding: .utf8) }
                    .joined(separator: "\n")
            }
            directory = directory.deletingLastPathComponent()
        }
        throw TestFailure.keyboardSourcesNotFound
    }

    enum TestFailure: Error { case keyboardSourcesNotFound }
}
