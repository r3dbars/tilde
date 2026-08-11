import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Tilde settings")
struct TildeSettingsTests {
    private func makeSettings() -> (TildeSettings, UserDefaults) {
        let keyboardName = "tilde.tests.keyboard.\(UUID().uuidString)"
        let keyboard = UserDefaults(suiteName: keyboardName)!
        keyboard.removePersistentDomain(forName: keyboardName)
        return (TildeSettings(keyboard: keyboard), keyboard)
    }

    @Test("Fresh keyboard settings enable suggestions")
    func absentKeysUseProductDefaults() {
        let (settings, _) = makeSettings()
        #expect(settings.suggestionsEnabled)
        #expect(settings.pausedUntil == nil)
    }

    @Test("Keyboard settings stay in the keyboard defaults domain")
    func keyboardSettingsLandInKeyboardDomain() {
        let (settings, keyboard) = makeSettings()
        settings.suggestionsEnabled = false

        #expect(keyboard.object(forKey: "GhostSuggestionsEnabled") as? Bool == false)
    }

    @Test("Pause expires and resume clears it")
    func pauseLifecycle() {
        let (settings, keyboard) = makeSettings()
        settings.pause(for: 3600)
        #expect(settings.pausedUntil != nil)
        settings.resume()
        #expect(settings.pausedUntil == nil)

        keyboard.set(
            Date().addingTimeInterval(-60).timeIntervalSince1970,
            forKey: "GhostPausedUntil"
        )
        #expect(settings.pausedUntil == nil)
    }

    @Test("Every menu keyboard key has a reader in the keyboard sources")
    func keyboardKeysExistInKeyboardSources() throws {
        let sources = try Self.keyboardSourceText()
        for key in TildeSettings.KeyboardKey.allCases {
            #expect(
                sources.contains(key.rawValue),
                "\(key.rawValue) is written by the menu but never read by the keyboard"
            )
        }
    }

    @Test("Tab inserts before aggregate stats work")
    func tabInsertionStaysFirst() throws {
        let source = try Self.keyboardSourceText()
        let function = try Self.functionBody(named: "acceptSuggestion", in: source)
        let insertion = try #require(function.range(of: "apply(effects"))
        let stats = try #require(function.range(of: "GhostStats.recordAccepted"))
        #expect(insertion.lowerBound < stats.lowerBound)
    }

    @Test("Tab defers fresh prediction instead of running it inline")
    func tabDefersFreshPrediction() throws {
        let source = try Self.keyboardSourceText()
        let function = try Self.functionBody(named: "acceptSuggestion", in: source)
        #expect(function.contains("apply(effects"))
        #expect(!function.contains("updateSuggestion(for: client)"))
    }

    private static func keyboardSourceText() throws -> String {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.pathComponents.count > 1 {
            let candidate = directory.appendingPathComponent("Sources/InlineGhostIME")
            if FileManager.default.fileExists(atPath: candidate.path) {
                let files = try FileManager.default
                    .contentsOfDirectory(at: candidate, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "swift" }
                return try files
                    .map { try String(contentsOf: $0, encoding: .utf8) }
                    .joined(separator: "\n")
            }
            directory = directory.deletingLastPathComponent()
        }
        throw TestFailure.keyboardSourcesNotFound
    }

    private static func functionBody(named name: String, in source: String) throws -> Substring {
        guard let start = source.range(of: "private func \(name)")?.lowerBound else {
            throw TestFailure.keyboardFunctionNotFound(name)
        }
        let tail = source[start...]
        guard let nextFunction = tail.dropFirst().range(of: "\n    private func ")?.lowerBound else {
            return tail
        }
        return tail[..<nextFunction]
    }

    enum TestFailure: Error {
        case keyboardSourcesNotFound
        case keyboardFunctionNotFound(String)
    }
}
