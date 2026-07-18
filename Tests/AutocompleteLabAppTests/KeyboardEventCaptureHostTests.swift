import AutocompleteLabCore
import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Keyboard event capture host")
@MainActor
struct KeyboardEventCaptureHostTests {
    @Test("Fails closed unless Accessibility, a visible suggestion, and running state all agree")
    func captureGateFailsClosed() {
        let host = makeHost()
        let snapshot = KeyboardEventTapSnapshot(hasVisibleSuggestion: true)

        #expect(!host.startIfPossible(
            isTrustedForAccessibility: false,
            hasVisibleSuggestion: true,
            controlState: .running,
            snapshot: snapshot
        ))
        #expect(!host.startIfPossible(
            isTrustedForAccessibility: true,
            hasVisibleSuggestion: false,
            controlState: .running,
            snapshot: snapshot
        ))
        #expect(!host.startIfPossible(
            isTrustedForAccessibility: true,
            hasVisibleSuggestion: true,
            controlState: .paused,
            snapshot: snapshot
        ))
    }

    @Test("Presentation activation keeps the capture gate fail-closed")
    func presentationActivationFailsClosedThroughCaptureGate() {
        let host = makeHost()

        #expect(!host.activateForSuggestionPresentation(
            isTrustedForAccessibility: false,
            hasVisibleSuggestion: true,
            controlState: .running,
            snapshot: KeyboardEventTapSnapshot(hasVisibleSuggestion: true)
        ))
    }

    @Test("AppDelegate delegates native tap lifecycle to the host")
    func appDelegateDelegatesNativeTapLifecycle() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )

        #expect(appDelegate.contains("KeyboardEventCaptureHost("))
        #expect(appDelegate.contains("keyboardEventCaptureHost.startIfPossible("))
        #expect(appDelegate.contains("keyboardEventCaptureHost.activateForSuggestionPresentation("))
        #expect(appDelegate.contains("keyboardEventCaptureHost.scheduleStopIfIdle("))
        #expect(appDelegate.contains("keyboardEventCaptureHost.stopNow(reason: reason)"))
        #expect(!appDelegate.contains("let eventTap = KeyboardEventTap("))
        #expect(!appDelegate.contains("keyboardEventTapStopTask = Task"))
    }

    private func makeHost() -> KeyboardEventCaptureHost {
        KeyboardEventCaptureHost(
            handler: { _, _, _ in .replayOriginalKey(.noVisibleSuggestion) },
            passthroughKeyDownObserver: {},
            passthroughTypingMatchObserver: { _ in },
            disabledObserver: { _ in },
            idleStateProvider: {
                KeyboardEventCaptureIdleState(
                    hasVisibleSuggestion: false,
                    isSuggestionPanelVisible: false,
                    hasPendingAcceptedInsertionUndo: false
                )
            }
        )
    }
}
