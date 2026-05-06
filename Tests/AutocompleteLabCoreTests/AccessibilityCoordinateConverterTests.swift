import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Accessibility coordinate converter")
struct AccessibilityCoordinateConverterTests {
    @Test("Converts top-left accessibility rect to bottom-left AppKit rect")
    func convertsTopLeftToBottomLeft() {
        let accessibilityRect = CGRect(x: 158, y: 227, width: 0, height: 14)
        let appKitRect = AccessibilityCoordinateConverter.appKitRect(
            fromAccessibilityRect: accessibilityRect,
            screenHeight: 1080
        )

        #expect(appKitRect.minX == 158)
        #expect(appKitRect.minY == 839)
        #expect(appKitRect.height == 14)
    }

    @Test("Converts bottom-left AppKit rect back to top-left accessibility rect")
    func convertsBottomLeftBackToTopLeft() {
        let appKitRect = CGRect(x: 158, y: 839, width: 0, height: 14)
        let accessibilityRect = AccessibilityCoordinateConverter.accessibilityRect(
            fromAppKitRect: appKitRect,
            screenHeight: 1080
        )

        #expect(accessibilityRect.minX == 158)
        #expect(accessibilityRect.minY == 227)
        #expect(accessibilityRect.height == 14)
    }
}
