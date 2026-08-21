import Foundation
import Testing
@testable import AutocompleteLabApp

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
