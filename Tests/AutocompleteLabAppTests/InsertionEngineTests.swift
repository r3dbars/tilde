import AutocompleteLabCore
import Testing
@testable import AutocompleteLabApp

@MainActor
@Suite("Insertion engine")
struct InsertionEngineTests {
    @Test("Chrome AX selected-text insertion uses descendant fallback")
    func chromeAXInsertionUsesDescendantFallback() throws {
        let client = TextInsertionClientSpy(insertResults: [true])
        let engine = InsertionEngine(accessibilityClient: client)
        let chrome = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))

        let result = engine.insert("ant", profile: chrome)

        #expect(result.succeeded)
        #expect(result.mode == .axSelectedText)
        #expect(client.calls == [
            .insertText(text: "ant", allowDescendantTextFallback: true)
        ])
    }

    @Test("Chrome AX value-replacement fallback uses descendant fallback")
    func chromeAXValueReplacementUsesDescendantFallback() throws {
        let client = TextInsertionClientSpy(replaceResults: [true])
        let engine = InsertionEngine(accessibilityClient: client)
        let chrome = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))

        let result = engine.insert("ant", profile: chrome, skipping: [.axThenKeyEvents])

        #expect(result.succeeded)
        #expect(result.mode == .axValueReplacement)
        #expect(client.calls == [
            .replaceSelectedTextBySettingValue(text: "ant", allowDescendantTextFallback: true)
        ])
    }

    @Test("Native TextEdit AX insertion stays on the focused element")
    func textEditAXInsertionDoesNotUseDescendantFallback() throws {
        let client = TextInsertionClientSpy(insertResults: [true])
        let engine = InsertionEngine(accessibilityClient: client)
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))

        let result = engine.insert("ant", profile: textEdit)

        #expect(result.succeeded)
        #expect(client.calls == [
            .insertText(text: "ant", allowDescendantTextFallback: false)
        ])
    }
}

private final class TextInsertionClientSpy: TextInsertionClient {
    enum Call: Equatable {
        case insertText(text: String, allowDescendantTextFallback: Bool)
        case replaceSelectedTextBySettingValue(text: String, allowDescendantTextFallback: Bool)
    }

    private var insertResults: [Bool]
    private var replaceResults: [Bool]
    private(set) var calls: [Call] = []

    init(insertResults: [Bool] = [], replaceResults: [Bool] = []) {
        self.insertResults = insertResults
        self.replaceResults = replaceResults
    }

    func insertText(_ text: String, allowDescendantTextFallback: Bool) -> Bool {
        calls.append(.insertText(text: text, allowDescendantTextFallback: allowDescendantTextFallback))
        return insertResults.isEmpty ? false : insertResults.removeFirst()
    }

    func replaceSelectedTextBySettingValue(_ text: String, allowDescendantTextFallback: Bool) -> Bool {
        calls.append(.replaceSelectedTextBySettingValue(text: text, allowDescendantTextFallback: allowDescendantTextFallback))
        return replaceResults.isEmpty ? false : replaceResults.removeFirst()
    }
}
