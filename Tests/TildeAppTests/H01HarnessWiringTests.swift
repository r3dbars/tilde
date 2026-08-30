import TildeCore
import Foundation
import Testing
@testable import TildeApp

private struct NineWordTransport: LlamaCompletionStreamingTransport {
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

@Suite("Fixed visible-cap wiring")
struct FixedVisibleCapWiringTests {
    private func suggestion(
        profile: TildeProductProfile
    ) async throws -> CompletionSuggestion? {
        let engine = LlamaCompletionEngine(
            baseURL: URL(string: "http://127.0.0.1:17876")!,
            diagnostics: .disabled,
            transport: NineWordTransport(),
            productProfile: profile
        )
        return try await engine.suggestion(
            textBeforeCursor: "Counting ",
            appBundleIdentifier: "com.apple.TextEdit",
            scene: nil
        )
    }

    @Test("Every profile uses only its declared fixed visible-word cap")
    func profilesUseDeclaredCaps() async throws {
        let cases: [(TildeProductProfile, Int)] = [
            (.production, 8),
            (.preview26B, 8),
            (.preview9B, 3),
            (.modelPreview, 8),
        ]
        for (profile, expectedWords) in cases {
            let words = try #require(await suggestion(profile: profile))
                .visibleText.split(whereSeparator: \Character.isWhitespace)
            #expect(words.count == expectedWords, "\(profile.rawValue) must keep its fixed cap")
            #expect(expectedWords == profile.maximumVisibleWords)
        }
    }

    @Test("Model Preview cannot silently inherit the locked three-word treatment")
    func modelPreviewStaysAtItsEightWordControl() async throws {
        let words = try #require(await suggestion(profile: .modelPreview))
            .visibleText.split(whereSeparator: \Character.isWhitespace)
        #expect(words.count == CompletionSuggestion.defaultMaxVisibleWords)
        #expect(words.count > 3)
    }
}
