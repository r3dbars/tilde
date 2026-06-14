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

    @Test("Electron key-event profiles prefer hardware events")
    func electronKeyEventProfilesPreferHardwareEvents() throws {
        let obsidian = try #require(CompatibilityProfileStore.mvp.profile(for: "md.obsidian"))
        let chrome = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))

        #expect(InsertionEngine.prefersHardwareKeyEvents(for: obsidian))
        #expect(InsertionEngine.prefersHardwareKeyEvents(for: chrome))
        #expect(!InsertionEngine.prefersHardwareKeyEvents(for: textEdit))
    }

    @Test("Accepted-text insertion forwards the validated field identity to the AX write (F1)")
    func insertForwardsExpectedFieldIdentityToClient() throws {
        let client = TextInsertionClientSpy(insertResults: [true])
        let engine = InsertionEngine(accessibilityClient: client)
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let identity = FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 4321,
            elementIdentifier: 99
        )

        let result = engine.insert("ant", profile: textEdit, expectedFieldIdentity: identity)

        #expect(result.succeeded)
        // The identity-bound write must receive the same identity the acceptance pipeline
        // validated; otherwise AccessibilityClient cannot refuse a drifted target.
        #expect(client.recordedExpectedIdentities == [identity])
    }

    @Test("Value-replacement insertion forwards the validated field identity (F1)")
    func valueReplacementForwardsExpectedFieldIdentityToClient() throws {
        let client = TextInsertionClientSpy(replaceResults: [true])
        let engine = InsertionEngine(accessibilityClient: client)
        let chrome = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))
        let identity = FocusedFieldIdentity(
            bundleIdentifier: "com.google.Chrome",
            processIdentifier: 777,
            elementIdentifier: 12
        )

        let result = engine.insert(
            "ant",
            profile: chrome,
            expectedFieldIdentity: identity,
            skipping: [.axThenKeyEvents]
        )

        #expect(result.succeeded)
        #expect(client.recordedExpectedIdentities == [identity])
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
    private(set) var recordedExpectedIdentities: [FocusedFieldIdentity?] = []

    init(insertResults: [Bool] = [], replaceResults: [Bool] = []) {
        self.insertResults = insertResults
        self.replaceResults = replaceResults
    }

    func insertText(
        _ text: String,
        expectedFieldIdentity: FocusedFieldIdentity?,
        allowDescendantTextFallback: Bool
    ) -> Bool {
        calls.append(.insertText(text: text, allowDescendantTextFallback: allowDescendantTextFallback))
        recordedExpectedIdentities.append(expectedFieldIdentity)
        return insertResults.isEmpty ? false : insertResults.removeFirst()
    }

    func replaceSelectedTextBySettingValue(
        _ text: String,
        expectedFieldIdentity: FocusedFieldIdentity?,
        allowDescendantTextFallback: Bool
    ) -> Bool {
        calls.append(.replaceSelectedTextBySettingValue(text: text, allowDescendantTextFallback: allowDescendantTextFallback))
        recordedExpectedIdentities.append(expectedFieldIdentity)
        return replaceResults.isEmpty ? false : replaceResults.removeFirst()
    }
}
