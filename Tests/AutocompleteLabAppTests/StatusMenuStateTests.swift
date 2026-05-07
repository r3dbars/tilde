import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Status menu state")
struct StatusMenuStateTests {
    @Test("Status title fails closed before Accessibility permission")
    func statusTitleFailsClosedBeforeAccessibilityPermission() {
        let state = StatusMenuStateBuilder.make(
            isTrustedForAccessibility: false,
            controlState: .running,
            appDisplayName: "TextEdit",
            appBundleIdentifier: "com.apple.TextEdit",
            supportStatus: CompatibilityProfileStore.mvp.supportStatus(for: "com.apple.TextEdit"),
            appEnabled: true,
            disabledAppCount: 0,
            lastSuggestionDecision: "Ready"
        )

        #expect(state.title == "Needs Accessibility")
        #expect(state.pauseTitle == "Pause Suggestions")
        #expect(state.toggleTitle == "Disable TextEdit")
        #expect(state.toggleEnabled)
        #expect(state.diagnosticsMetadata["accessibility"] == "AX missing")
        #expect(state.diagnosticsMetadata["profile"] == "green: TextEdit")
    }

    @Test("Status title reports paused and unsupported app states")
    func statusTitleReportsPausedAndUnsupportedAppStates() {
        let paused = StatusMenuStateBuilder.make(
            isTrustedForAccessibility: true,
            controlState: .paused,
            appDisplayName: "TextEdit",
            appBundleIdentifier: "com.apple.TextEdit",
            supportStatus: CompatibilityProfileStore.mvp.supportStatus(for: "com.apple.TextEdit"),
            appEnabled: true,
            disabledAppCount: 0,
            lastSuggestionDecision: "Paused"
        )
        #expect(paused.title == "Paused")
        #expect(paused.pauseTitle == "Resume Suggestions")
        #expect(paused.diagnosticsMetadata["paused"] == "true")

        let diagnosticsOnly = StatusMenuStateBuilder.make(
            isTrustedForAccessibility: true,
            controlState: .running,
            appDisplayName: "Atlas",
            appBundleIdentifier: "com.openai.atlas",
            supportStatus: CompatibilityProfileStore.mvp.supportStatus(for: "com.openai.atlas"),
            appEnabled: true,
            disabledAppCount: 0,
            lastSuggestionDecision: "Blocked: diagnostics only"
        )
        #expect(diagnosticsOnly.title == "Diagnostics only in Atlas")
        #expect(diagnosticsOnly.toggleTitle == "Suggestions unavailable in Atlas")
        #expect(!diagnosticsOnly.toggleEnabled)

        let unsupported = StatusMenuStateBuilder.make(
            isTrustedForAccessibility: true,
            controlState: .running,
            appDisplayName: "Unknown",
            appBundleIdentifier: "com.example.Unknown",
            supportStatus: .unsupported,
            appEnabled: false,
            disabledAppCount: 0,
            lastSuggestionDecision: "Blocked: unsupported app"
        )
        #expect(unsupported.title == "Unsupported in Unknown")
        #expect(unsupported.toggleTitle == "Suggestions unavailable in Unknown")
        #expect(!unsupported.toggleEnabled)
    }

    @Test("Status title follows visible suggestion lifecycle")
    func statusTitleFollowsVisibleSuggestionLifecycle() {
        let store = CompatibilityProfileStore.mvp

        #expect(
            makeTextEditState(lastSuggestionDecision: "Shown: phrase", appEnabled: true, store: store).title
                == "Showing in TextEdit"
        )
        #expect(
            makeTextEditState(lastSuggestionDecision: "Queued: phrase", appEnabled: true, store: store).title
                == "Thinking in TextEdit"
        )
        #expect(
            makeTextEditState(lastSuggestionDecision: "Waiting: typing", appEnabled: true, store: store).title
                == "Waiting in TextEdit"
        )
        #expect(
            makeTextEditState(lastSuggestionDecision: "Ready", appEnabled: true, store: store).title
                == "Ready in TextEdit"
        )
        #expect(
            makeTextEditState(lastSuggestionDecision: "Ready", appEnabled: false, store: store).title
                == "Blocked in TextEdit"
        )
    }

    @Test("Missing app uses neutral menu state")
    func missingAppUsesNeutralMenuState() {
        let state = StatusMenuStateBuilder.make(
            isTrustedForAccessibility: true,
            controlState: .running,
            appDisplayName: nil,
            appBundleIdentifier: nil,
            supportStatus: .unsupported,
            appEnabled: false,
            disabledAppCount: 0,
            lastSuggestionDecision: "Ready"
        )

        #expect(state.title == "Ready")
        #expect(state.toggleTitle == "Toggle Current App")
        #expect(!state.toggleEnabled)
        #expect(state.diagnosticsMetadata["app"] == "No app")
        #expect(state.diagnosticsMetadata["profile"] == "none")
    }

    private func makeTextEditState(
        lastSuggestionDecision: String,
        appEnabled: Bool,
        store: CompatibilityProfileStore
    ) -> StatusMenuState {
        StatusMenuStateBuilder.make(
            isTrustedForAccessibility: true,
            controlState: .running,
            appDisplayName: "TextEdit",
            appBundleIdentifier: "com.apple.TextEdit",
            supportStatus: store.supportStatus(for: "com.apple.TextEdit"),
            appEnabled: appEnabled,
            disabledAppCount: appEnabled ? 0 : 1,
            lastSuggestionDecision: lastSuggestionDecision
        )
    }
}
