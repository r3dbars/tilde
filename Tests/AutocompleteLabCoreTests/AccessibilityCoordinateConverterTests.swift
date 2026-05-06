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

    @Test("Converts accessibility rects on negative-origin screens")
    func convertsNegativeOriginScreenRects() {
        let screenFrame = CGRect(x: -1920, y: 300, width: 1920, height: 1080)
        let accessibilityRect = CGRect(x: -1380, y: 165, width: 0, height: 20)
        let appKitRect = AccessibilityCoordinateConverter.appKitRect(
            fromAccessibilityRect: accessibilityRect,
            in: screenFrame
        )
        let roundTripRect = AccessibilityCoordinateConverter.accessibilityRect(
            fromAppKitRect: appKitRect,
            in: screenFrame
        )

        #expect(appKitRect.minX == -1380)
        #expect(appKitRect.minY == 1195)
        #expect(screenFrame.contains(CGPoint(x: appKitRect.midX, y: appKitRect.midY)))
        #expect(roundTripRect == accessibilityRect)
    }

    @Test("Builds non-empty probe rects for zero-width carets")
    func buildsProbeRectForZeroWidthCarets() {
        let screenFrame = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let caretRect = CGRect(x: -1380, y: 165, width: 0, height: 20)
        let probeRect = AccessibilityCoordinateConverter.appKitProbeRect(
            fromAccessibilityRect: caretRect,
            in: screenFrame
        )

        #expect(probeRect.width == 1)
        #expect(probeRect.height == 20)
        #expect(screenFrame.intersects(probeRect))
    }
}
