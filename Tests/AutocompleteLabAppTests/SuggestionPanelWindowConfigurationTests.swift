import AppKit
import CoreGraphics
import Testing
@testable import AutocompleteLabApp

@Suite("Suggestion panel window configuration")
struct SuggestionPanelWindowConfigurationTests {
    @Test("Suggesting mode stays click-through")
    func suggestingModeStaysClickThrough() {
        let configuration = SuggestionPanelWindowConfiguration.suggestingMode

        #expect(configuration.level == .statusBar)
        #expect(configuration.ignoresMouseEvents)
        #expect(configuration.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(configuration.collectionBehavior.contains(.fullScreenAuxiliary))
    }

    @Test("Panel presentation trace includes display and AppKit geometry")
    func panelPresentationTraceIncludesDisplayAndAppKitGeometry() {
        let presentation = SuggestionPanelPresentation(
            accessibilityFrame: CGRect(x: -1200, y: 180, width: 120, height: 20),
            appKitFrame: CGRect(x: -1200, y: 700, width: 120, height: 20),
            accessibilityAnchorRect: CGRect(x: -1200, y: 180, width: 0, height: 20),
            appKitAnchorRect: CGRect(x: -1200, y: 700, width: 0, height: 20),
            appKitTextLineRect: CGRect(x: -1220, y: 700, width: 20, height: 20),
            appKitClippingRect: CGRect(x: -1280, y: 640, width: 500, height: 180),
            screenIdentifier: "left",
            screenFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
            panelLevel: NSWindow.Level.statusBar.rawValue,
            ignoresMouseEvents: true
        )

        let metadata = presentation.traceMetadata

        #expect(metadata["panelLevel"] == String(NSWindow.Level.statusBar.rawValue))
        #expect(metadata["panelIgnoresMouseEvents"] == "true")
        #expect(metadata["hasPanelClickThrough"] == "true")
        #expect(metadata["screenID"] == "left")
        #expect(metadata["screenFrame"] == "x=-1920,y=0,w=1920,h=1080")
        #expect(metadata["convertedAnchorRect"] == "x=-1200,y=700,w=0,h=20")
        #expect(metadata["finalAppKitFrame"] == "x=-1200,y=700,w=120,h=20")
        #expect(metadata["suggestionPanelFrame"] == "x=-1200,y=700,w=120,h=20")
    }
}
