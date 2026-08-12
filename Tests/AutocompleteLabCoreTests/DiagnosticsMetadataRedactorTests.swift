import Testing
@testable import AutocompleteLabCore

@Suite("Diagnostics metadata redactor")
struct DiagnosticsMetadataRedactorTests {
    @Test("Known scalar fields survive unchanged")
    func keepsKnownScalars() {
        #expect(field("totalMilliseconds", "42") == "totalMilliseconds=42")
        #expect(field("cleanedChars", "8") == "cleanedChars=8")
        #expect(field("willRestart", "true") == "willRestart=true")
        #expect(field("reason", "launch-failed") == "reason=launch-failed")
        #expect(field("reason", "assets-missing") == "reason=assets-missing")
        #expect(field("reason", "port-in-use") == "reason=port-in-use")
        #expect(field("reason", "health-timeout") == "reason=health-timeout")
        #expect(field("reason", "directory") == "reason=directory")
        #expect(field("reason", "already-running") == "reason=already-running")
        #expect(field("reason", "store-corrupt") == "reason=store-corrupt")
        #expect(field("reason", "key-unavailable") == "reason=key-unavailable")
        #expect(field("reason", "storage-unavailable") == "reason=storage-unavailable")
        #expect(field("reason", "internal-error") == "reason=internal-error")
        #expect(field("app", "com.apple.TextEdit") == "app=com.apple.TextEdit")
    }

    @Test("Unknown and text-like fields expose shape only")
    func redactsUnknownFields() {
        #expect(field("selectedText", "private draft") == "metadata=String(13 chars)")
        #expect(field("newMetric", "42") == "metadata=String(2 chars)")
    }

    @Test("Free text, paths, URLs, and newlines never survive")
    func redactsUnsafeValues() {
        #expect(field("reason", "private draft") == "reason=String(13 chars)")
        #expect(field("app", "/Users/me/draft") == "app=String(15 chars)")
        #expect(field("app", "https://private.example") == "app=String(23 chars)")
        #expect(field("app", "private") == "app=String(7 chars)")
        #expect(field("app", "com.apple.TextEdit\n") == "app=String(19 chars)")
        #expect(field("status", "enabled\nprivate") == "status=String(15 chars)")
        #expect(field("reason", "-50") == "reason=String(3 chars)")
    }

    @Test("Event names are single fixed tokens")
    func sanitizesEvents() {
        #expect(DiagnosticsMetadataRedactor.logSafeEvent("llama-server-start") == "llama-server-start")
        #expect(DiagnosticsMetadataRedactor.logSafeEvent("launch\n") == "event-redacted")
        #expect(DiagnosticsMetadataRedactor.logSafeEvent("private event\ntext") == "event-redacted")
    }

    private func field(_ key: String, _ value: String) -> String {
        DiagnosticsMetadataRedactor.logSafeField(forKey: key, value: value)
    }
}
