import Testing
@testable import AutocompleteLabCore

@Suite("Descendant text fallback policy")
struct DescendantTextFallbackPolicyTests {
    private let policy = DescendantTextFallbackPolicy()

    @Test("Keeps Mail compose fallback scoped to New Message")
    func mailComposeFallbackIsScoped() {
        #expect(policy.allowsFallback(
            bundleIdentifier: "com.apple.mail",
            role: "AXWebArea",
            directText: "",
            windowTitle: "New Message"
        ))
        #expect(!policy.allowsFallback(
            bundleIdentifier: "com.apple.mail",
            role: "AXWebArea",
            directText: "",
            windowTitle: "Inbox"
        ))
    }

    @Test("Allows Chrome disposable smoke web areas")
    func chromeSmokeWebAreasCanUseDescendantText() {
        #expect(policy.allowsFallback(
            bundleIdentifier: "com.google.Chrome",
            role: "AXWebArea",
            directText: nil,
            windowTitle: "SteadyType Chrome Real Monaco Smoke [ready=1]"
        ))
        #expect(policy.allowsFallback(
            bundleIdentifier: "com.google.Chrome",
            role: "AXWebArea",
            directText: " ",
            windowTitle: "SteadyType Chrome Real ProseMirror Smoke [ready=1]"
        ))
    }

    @Test("Allows Obsidian empty CodeMirror web areas")
    func obsidianCodeMirrorWebAreasCanUseDescendantText() {
        #expect(policy.allowsFallback(
            bundleIdentifier: "md.obsidian",
            role: "AXWebArea",
            directText: "",
            windowTitle: "SteadyType Proof"
        ))
    }

    @Test("Allows Codex to recover its editor from an empty web area")
    func codexWebAreaCanRecoverEditorDescendant() {
        #expect(policy.allowsFallback(
            bundleIdentifier: "com.openai.codex",
            role: "AXWebArea",
            directText: nil,
            windowTitle: "Codex"
        ))
        #expect(!policy.allowsFallback(
            bundleIdentifier: "com.openai.codex",
            role: "AXTextArea",
            directText: nil,
            windowTitle: "Codex"
        ))
        #expect(!policy.allowsFallback(
            bundleIdentifier: "com.openai.codex",
            role: "AXWebArea",
            directText: "already readable",
            windowTitle: "Codex"
        ))
    }

    @Test("Blocks broad Chrome production pages")
    func broadChromePagesStayBlocked() {
        #expect(!policy.allowsFallback(
            bundleIdentifier: "com.google.Chrome",
            role: "AXWebArea",
            directText: "",
            windowTitle: "Project plan - Google Docs"
        ))
        #expect(!policy.allowsFallback(
            bundleIdentifier: "com.google.Chrome",
            role: "AXWebArea",
            directText: "",
            windowTitle: "Roadmap - Notion"
        ))
    }

    @Test("Requires empty direct AX text and a web area")
    func requiresEmptyDirectTextAndWebArea() {
        #expect(!policy.allowsFallback(
            bundleIdentifier: "com.google.Chrome",
            role: "AXTextArea",
            directText: "",
            windowTitle: "SteadyType Chrome Textarea Smoke"
        ))
        #expect(!policy.allowsFallback(
            bundleIdentifier: "com.google.Chrome",
            role: "AXWebArea",
            directText: "already readable",
            windowTitle: "SteadyType Chrome Textarea Smoke"
        ))
    }
}
