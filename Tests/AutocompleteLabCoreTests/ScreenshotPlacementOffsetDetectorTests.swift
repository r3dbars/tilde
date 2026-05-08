import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Screenshot placement offset detector")
struct ScreenshotPlacementOffsetDetectorTests {
    @Test("Detects ghost text offset from synthetic pixels")
    func detectsGhostTextOffsetFromSyntheticPixels() {
        let expected = CGRect(x: 120, y: 220, width: 12, height: 6)
        let bitmap = bitmapWithSignal(
            captureRect: captureRect,
            signalRect: expected.offsetBy(dx: 6, dy: -3),
            foreground: .darkGray
        )

        let detection = ScreenshotPlacementOffsetDetector()
            .detection(in: bitmap, captureRect: captureRect, expectedSignalRect: expected)

        #expect(detection.isDetected)
        #expect(abs(detection.dx - 6) < 0.001)
        #expect(abs(detection.dy + 3) < 0.001)
        #expect(detection.confidence >= 0.8)
        #expect(detection.signalPixelCount == 72)
    }

    @Test("Rejects low contrast pixels")
    func rejectsLowContrastPixels() {
        let expected = CGRect(x: 120, y: 220, width: 12, height: 6)
        let bitmap = bitmapWithSignal(
            captureRect: captureRect,
            signalRect: expected.offsetBy(dx: 4, dy: 0),
            foreground: ScreenshotPlacementPixel(red: 242, green: 242, blue: 242)
        )

        let detection = ScreenshotPlacementOffsetDetector()
            .detection(in: bitmap, captureRect: captureRect, expectedSignalRect: expected)

        #expect(!detection.isDetected)
        #expect(detection.reason == .lowContrast)
    }

    @Test("Rejects blank screenshots")
    func rejectsBlankScreenshots() {
        let expected = CGRect(x: 120, y: 220, width: 12, height: 6)
        let bitmap = solidBitmap(width: 96, height: 64, color: .white)

        let detection = ScreenshotPlacementOffsetDetector()
            .detection(in: bitmap, captureRect: captureRect, expectedSignalRect: expected)

        #expect(!detection.isDetected)
        #expect(detection.reason == .lowContrast)
    }

    @Test("Rejects excessive outlier offsets")
    func rejectsExcessiveOutlierOffsets() {
        let expected = CGRect(x: 112, y: 212, width: 10, height: 6)
        let bitmap = bitmapWithSignal(
            captureRect: captureRect,
            signalRect: CGRect(x: 180, y: 252, width: 10, height: 6),
            foreground: .darkGray
        )
        let detector = ScreenshotPlacementOffsetDetector(
            searchPadding: 96,
            minimumSignalPixels: 8,
            maximumOutlierDistance: 24
        )

        let detection = detector.detection(
            in: bitmap,
            captureRect: captureRect,
            expectedSignalRect: expected
        )

        #expect(!detection.isDetected)
        #expect(detection.reason == .excessiveOutlier)
        #expect(detection.signalPixelCount == 60)
    }

    private var captureRect: CGRect {
        CGRect(x: 100, y: 200, width: 96, height: 64)
    }

    private func bitmapWithSignal(
        captureRect: CGRect,
        signalRect: CGRect,
        foreground: ScreenshotPlacementPixel
    ) -> ScreenshotPlacementPixelBuffer {
        var bitmap = solidBitmap(
            width: Int(captureRect.width),
            height: Int(captureRect.height),
            color: .white
        )
        draw(
            globalRect: signalRect,
            captureRect: captureRect,
            color: foreground,
            into: &bitmap
        )
        return bitmap
    }

    private func solidBitmap(
        width: Int,
        height: Int,
        color: ScreenshotPlacementPixel
    ) -> ScreenshotPlacementPixelBuffer {
        ScreenshotPlacementPixelBuffer(
            width: width,
            height: height,
            pixels: Array(repeating: color, count: width * height)
        )
    }

    private func draw(
        globalRect: CGRect,
        captureRect: CGRect,
        color: ScreenshotPlacementPixel,
        into bitmap: inout ScreenshotPlacementPixelBuffer
    ) {
        var pixels = bitmap.pixels
        let local = globalRect.offsetBy(dx: -captureRect.minX, dy: -captureRect.minY).integral
        let xRange = Int(max(0, local.minX))..<Int(min(CGFloat(bitmap.width), local.maxX))
        let yRange = Int(max(0, local.minY))..<Int(min(CGFloat(bitmap.height), local.maxY))

        for y in yRange {
            for x in xRange {
                pixels[y * bitmap.width + x] = color
            }
        }

        bitmap = ScreenshotPlacementPixelBuffer(width: bitmap.width, height: bitmap.height, pixels: pixels)
    }
}

private extension ScreenshotPlacementPixel {
    static let white = ScreenshotPlacementPixel(red: 245, green: 245, blue: 245)
    static let darkGray = ScreenshotPlacementPixel(red: 96, green: 96, blue: 96)
}
