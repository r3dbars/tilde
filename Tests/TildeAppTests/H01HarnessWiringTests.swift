import TildeCore
import Foundation
import Testing
@testable import TildeApp

/// In-memory stand-in for the settings suite the app and input method share.
private final class MemoryDefaults: H01ExperimentDefaults, @unchecked Sendable {
    private var storage: [String: Any] = [:]

    init(enabled: Bool? = nil) {
        if let enabled { storage[H01BlockRandomization.enabledKey] = enabled }
    }

    func object(forKey key: String) -> Any? { storage[key] }
    func set(_ value: Any?, forKey key: String) { storage[key] = value }
}

private struct EightWordTransport: LlamaCompletionStreamingTransport {
    func open(request: URLRequest) async throws -> LlamaCompletionHTTPStream {
        LlamaCompletionHTTPStream(
            statusCode: 200,
            lines: AsyncThrowingStream { continuation in
                continuation.yield(
                    #"data: {"content":" one two three four five six seven eight nine "}"#
                )
                continuation.yield(
                    #"data: {"stop":true,"tokens_predicted":9,"stopped_limit":true}"#
                )
                continuation.finish()
            },
            cancel: {}
        )
    }
}

@Suite("H01 harness wiring (disabled by default)")
struct H01HarnessWiringTests {
    private func engine(
        profile: TildeProductProfile,
        defaults: H01ExperimentDefaults
    ) -> LlamaCompletionEngine {
        LlamaCompletionEngine(
            baseURL: URL(string: "http://127.0.0.1:17876")!,
            diagnostics: .disabled,
            transport: EightWordTransport(),
            productProfile: profile,
            experimentDefaults: defaults
        )
    }

    @Test("An arm-tagged request changes nothing while the harness is off")
    func disabledHarnessKeepsTheProfileCap() async throws {
        let engine = engine(profile: .modelPreview, defaults: MemoryDefaults())
        let suggestion = try await engine.suggestion(
            textBeforeCursor: "Counting ",
            appBundleIdentifier: "com.apple.TextEdit",
            scene: nil,
            experimentArm: H01Arm.b.rawValue,
            onPartialSuggestion: { _, _ in }
        )
        let words = suggestion?.visibleText.split(whereSeparator: \Character.isWhitespace) ?? []
        #expect(words.count > 3)
        let untagged = try await engine.suggestion(
            textBeforeCursor: "Counting ",
            appBundleIdentifier: "com.apple.TextEdit",
            scene: nil
        )
        #expect(untagged?.visibleText == suggestion?.visibleText)
    }

    @Test("Production ignores the harness even when the toggle is on")
    func productionIsNeverInTheExperiment() async throws {
        let defaults = MemoryDefaults(enabled: true)
        let engine = engine(profile: .production, defaults: defaults)
        #expect(H01BlockRandomization.visibleWordCap(
            requestedArm: H01Arm.b.rawValue,
            profile: .production,
            defaults: defaults
        ) == nil)
        let suggestion = try await engine.suggestion(
            textBeforeCursor: "Counting ",
            appBundleIdentifier: "com.apple.TextEdit",
            scene: nil,
            experimentArm: H01Arm.b.rawValue,
            onPartialSuggestion: { _, _ in }
        )
        let words = suggestion?.visibleText.split(whereSeparator: \Character.isWhitespace) ?? []
        #expect(words.count > 3)
    }

    @Test("Enabled Model Preview applies arm B's three-word cap and arm A's eight")
    func enabledModelPreviewAppliesTheArmCap() async throws {
        let defaults = MemoryDefaults(enabled: true)
        let engine = engine(profile: .modelPreview, defaults: defaults)

        let treatment = try await engine.suggestion(
            textBeforeCursor: "Counting ",
            appBundleIdentifier: "com.apple.TextEdit",
            scene: nil,
            experimentArm: H01Arm.b.rawValue,
            onPartialSuggestion: { _, _ in }
        )
        #expect(treatment?.visibleText == "one two three")

        let control = try await engine.suggestion(
            textBeforeCursor: "Counting ",
            appBundleIdentifier: "com.apple.TextEdit",
            scene: nil,
            experimentArm: H01Arm.a.rawValue,
            onPartialSuggestion: { _, _ in }
        )
        let controlWords = control?.visibleText
            .split(whereSeparator: \Character.isWhitespace) ?? []
        #expect(controlWords.count > 3)
        #expect(controlWords.count <= TildeProductProfile.modelPreview.maximumVisibleWords)
    }

    @Test("The keyboard settings suite is the toggle's single home")
    func toggleLivesInTheSharedSuite() {
        let defaults = MemoryDefaults()
        let settings = TildeSettings(keyboard: nil, app: UserDefaults.standard)
        _ = settings
        #expect(H01BlockRandomization.enabledKey
            == TildeSettings.KeyboardKey.h01BlockRandomization.rawValue)
        #expect(H01BlockRandomization.isEnabled(defaults) == false)
    }
}
