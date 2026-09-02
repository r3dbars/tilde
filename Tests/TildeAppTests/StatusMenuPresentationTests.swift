import Foundation
import Testing
@testable import TildeApp

struct StatusMenuPresentationTests {
    private let modelURL = URL(fileURLWithPath: "/tmp/model.gguf")

    @Test("Ready menu is concise and useful")
    func ready() {
        let menu = StatusMenuHost.Presentation.make(
            state: .ready,
            model: .ready(modelURL),
            wordsToday: 13
        )

        #expect(menu.status == "Tilde is Ready")
        #expect(menu.detail == "13 words with Tilde today")
        #expect(menu.primaryAction == "Pause for 1 Hour")
    }

    @Test("Paused menu offers one resume action")
    func paused() {
        let menu = StatusMenuHost.Presentation.make(
            state: .paused(until: Date().addingTimeInterval(3_600)),
            model: .ready(modelURL),
            wordsToday: 13
        )

        #expect(menu.status == "Tilde is Paused")
        #expect(menu.detail == "13 words with Tilde today")
        #expect(menu.primaryAction == "Resume Tilde")
    }

    /// `.disabled` covers two different user choices. When the Screen Memory
    /// master toggle is the reason, the resume action turns a privacy
    /// control back on, so the menu has to say which switch it is flipping
    /// instead of hiding it behind "Resume Tilde".
    @Test("Screen Memory off is named, not disguised as a pause")
    func screenMemoryOff() {
        let menu = StatusMenuHost.Presentation.make(
            state: .disabled,
            model: .ready(modelURL),
            wordsToday: 13,
            screenMemoryEnabled: false
        )

        #expect(menu.status == "Screen Memory is Off")
        #expect(menu.detail == "Tilde suggests nothing until it can read the screen")
        #expect(menu.primaryAction == "Turn Screen Memory Back On")
    }

    @Test("Suggestions off with Screen Memory on is still an ordinary pause")
    func suggestionsOffIsStillAPause() {
        let menu = StatusMenuHost.Presentation.make(
            state: .disabled,
            model: .ready(modelURL),
            wordsToday: 13,
            screenMemoryEnabled: true
        )

        #expect(menu.status == "Tilde is Paused")
        #expect(menu.primaryAction == "Resume Tilde")
    }

    @Test("Attention menu points to setup")
    func attention() {
        let menu = StatusMenuHost.Presentation.make(
            state: .needsPermission,
            model: .downloading(receivedBytes: 1_400_000_000, totalBytes: 3_400_000_000),
            wordsToday: 13
        )

        #expect(menu.status == "Tilde Needs Attention")
        #expect(menu.detail == "Finish setup to start suggesting")
        #expect(menu.primaryAction == "Finish Setup")
    }

    @Test("Download menu reports bounded model progress")
    func downloading() {
        let menu = StatusMenuHost.Presentation.make(
            state: .preparingModel,
            model: .downloading(receivedBytes: 1_400_000_000, totalBytes: 3_400_000_000),
            wordsToday: 13
        )

        #expect(menu.status == "Downloading Local Model · 41%")
        #expect(menu.detail == "1.4 GB of 3.4 GB")
        #expect(menu.primaryAction == nil)
    }
}
