import AppKit
import Testing
@testable import AutocompleteLabApp

@Suite("Overlay desktop behavior")
struct OverlayDesktopBehaviorTests {
    @Test("Suggestion overlays can join Spaces and fullscreen apps")
    func suggestionOverlaysCanJoinSpacesAndFullscreenApps() {
        let behavior = OverlayDesktopBehavior.collectionBehavior

        #expect(behavior.contains(.canJoinAllSpaces))
        #expect(behavior.contains(.fullScreenAuxiliary))
        #expect(OverlayDesktopBehavior.traceDescription == "can-join-all-spaces+fullscreen-auxiliary")
    }
}
