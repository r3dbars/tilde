import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Menu bar icon state")
struct MenuBarIconTests {
    @Test("Ready state uses text cursor symbol")
    func readyStateUsesTextCursorSymbol() {
        let presentation = MenuBarIconPresentation(
            isTrusted: true,
            suggestionsPaused: false,
            runtimeReport: readyRuntime
        )

        #expect(presentation.state == .ready)
        #expect(presentation.symbolName == "text.cursor")
        #expect(presentation.accessibilityDescription == "SteadyType ready")
    }

    @Test("Paused state uses pause symbol")
    func pausedStateUsesPauseSymbol() {
        let presentation = MenuBarIconPresentation(
            isTrusted: true,
            suggestionsPaused: true,
            runtimeReport: readyRuntime
        )

        #expect(presentation.state == .paused)
        #expect(presentation.symbolName == "pause.circle")
        #expect(presentation.accessibilityDescription == "SteadyType paused")
    }

    @Test("Missing permission or model uses attention symbol")
    func missingPermissionOrModelUsesAttentionSymbol() {
        let missingPermission = MenuBarIconPresentation(
            isTrusted: false,
            suggestionsPaused: false,
            runtimeReport: readyRuntime
        )
        let missingModel = MenuBarIconPresentation(
            isTrusted: true,
            suggestionsPaused: false,
            runtimeReport: RuntimeReadinessReport(
                stage: .downloadNeeded,
                summary: "download needed",
                action: .installModel
            )
        )

        #expect(missingPermission.state == .needsAttention)
        #expect(missingModel.state == .needsAttention)
        #expect(missingModel.symbolName == "exclamationmark.triangle")
        #expect(missingModel.accessibilityDescription == "SteadyType needs attention")
    }
}

private let readyRuntime = RuntimeReadinessReport(
    stage: .ready,
    summary: "ready",
    action: .none,
    isReady: true
)
