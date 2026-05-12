import Testing
@testable import AutocompleteLabCore

@Suite("Browser hosted surface policy")
struct BrowserHostedSurfacePolicyTests {
    private let policy = BrowserHostedSurfacePolicy()

    @Test("Chrome Google Docs is blocked until real production proof exists")
    func blocksChromeGoogleDocs() throws {
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                title: "Editing project plan",
                windowTitle: "Project plan - Google Docs"
            )
        )

        let block = try #require(blockedSurface(from: decision))
        #expect(block.surface == .googleDocs)
        #expect(block.traceReason == "unsupported-browser-surface")
        #expect(block.userFacingReason == "Google Docs needs proof first")
    }

    @Test("Chrome Notion is blocked until real production proof exists")
    func blocksChromeNotion() throws {
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                windowTitle: "Roadmap - Notion"
            )
        )

        let block = try #require(blockedSurface(from: decision))
        #expect(block.surface == .notion)
    }

    @Test("Browser ChatGPT, Slack, and Discord are blocked until no-submit proof exists")
    func blocksBrowserChatSurfaces() throws {
        let chatGPTDecision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                windowTitle: "ChatGPT"
            )
        )
        let slackDecision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                windowTitle: "Transcripted | Slack"
            )
        )
        let discordDecision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                windowTitle: "Discord"
            )
        )

        #expect(try #require(blockedSurface(from: chatGPTDecision)).surface == .chatGPT)
        #expect(try #require(blockedSurface(from: slackDecision)).surface == .slack)
        #expect(try #require(blockedSurface(from: discordDecision)).surface == .discord)
    }

    @Test("Chrome local editor fixtures stay eligible")
    func allowsChromeLocalEditorFixtures() {
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                title: "Local ProseMirror-like smoke fixture",
                description: "Real ProseMirror smoke editor",
                windowTitle: "SteadyType Chrome Real ProseMirror Smoke [ready=1]"
            )
        )

        #expect(decision.canSuggest)
    }

    @Test("Chrome unknown browser pages fail closed until proofed")
    func blocksUnknownChromePages() throws {
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                title: "Draft",
                windowTitle: "Private writing app"
            )
        )

        let block = try #require(blockedSurface(from: decision))
        #expect(block.surface == .unproven)
        #expect(block.userFacingReason == "This browser page needs proof first")
        #expect(block.traceMetadata["browserSurfaceSafetyClass"] == "browser-unknown")
    }

    @Test("Non-browser apps are not filtered by hosted surface fingerprints")
    func allowsNonBrowserApps() {
        let decision = policy.decision(
            bundleIdentifier: "md.obsidian",
            fingerprint: FocusedElementFingerprint(
                windowTitle: "Project - Notion"
            )
        )

        #expect(decision.canSuggest)
    }

    @Test("Trace metadata is safe and does not include raw fingerprints")
    func traceMetadataIsSafe() throws {
        let secretTitle = "Private roadmap - Google Docs"
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(
                title: secretTitle,
                windowTitle: "https://docs.google.com/document/d/private-id/edit"
            )
        )

        let block = try #require(blockedSurface(from: decision))
        let metadata = block.traceMetadata

        #expect(metadata["browserSurface"] == "google-docs")
        #expect(metadata["browserSurfaceDecision"] == "blocked")
        #expect(metadata["browserSurfaceReason"] == "unsupported-surface-needs-proof")
        #expect(metadata["browserSurfaceSafetyClass"] == "browser-editor")
        #expect(!metadata.values.contains(secretTitle))
        #expect(!metadata.values.contains("https://docs.google.com/document/d/private-id/edit"))
    }

    @Test("Browser chat blocks are tagged for no-submit metrics")
    func browserChatBlocksAreTaggedForNoSubmitMetrics() throws {
        let decision = policy.decision(
            bundleIdentifier: "com.google.Chrome",
            fingerprint: FocusedElementFingerprint(windowTitle: "Transcripted - Slack")
        )

        let block = try #require(blockedSurface(from: decision))
        let metadata = block.traceMetadata

        #expect(metadata["browserSurface"] == "slack")
        #expect(metadata["browserSurfaceSafetyClass"] == "browser-chat")
        #expect(metadata["promptSafetyMetricSurface"] == "browser-chat")
    }

    private func blockedSurface(
        from decision: BrowserHostedSurfaceDecision
    ) -> BrowserHostedSurfaceBlock? {
        guard case let .blocked(block) = decision else {
            return nil
        }

        return block
    }
}
