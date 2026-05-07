import CoreGraphics
import Foundation

public struct ScreenshotPlacementPixel: Equatable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8
    public let alpha: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    var luminance: Double {
        (
            0.2126 * Double(red)
                + 0.7152 * Double(green)
                + 0.0722 * Double(blue)
        ) / 255
    }

    var opacity: Double {
        Double(alpha) / 255
    }
}

public struct ScreenshotPlacementPixelBuffer: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let pixels: [ScreenshotPlacementPixel]

    public init(width: Int, height: Int, pixels: [ScreenshotPlacementPixel]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    public func pixel(x: Int, y: Int) -> ScreenshotPlacementPixel? {
        guard x >= 0,
              y >= 0,
              x < width,
              y < height else {
            return nil
        }

        let index = y * width + x
        guard pixels.indices.contains(index) else {
            return nil
        }

        return pixels[index]
    }
}

public enum ScreenshotPlacementOffsetDetectionReason: String, Equatable, Sendable {
    case detected
    case invalidInput = "invalid-input"
    case expectedRectOutsideCapture = "expected-rect-outside-capture"
    case insufficientSearchArea = "insufficient-search-area"
    case insufficientSignal = "insufficient-signal"
    case lowContrast = "low-contrast"
    case excessiveOutlier = "excessive-outlier"
}

public struct ScreenshotPlacementOffsetDetection: Equatable, Sendable {
    public let dx: CGFloat
    public let dy: CGFloat
    public let confidence: Double
    public let signalPixelCount: Int
    public let signalBounds: CGRect?
    public let reason: ScreenshotPlacementOffsetDetectionReason

    public init(
        dx: CGFloat,
        dy: CGFloat,
        confidence: Double,
        signalPixelCount: Int,
        signalBounds: CGRect?,
        reason: ScreenshotPlacementOffsetDetectionReason
    ) {
        self.dx = dx
        self.dy = dy
        self.confidence = confidence
        self.signalPixelCount = signalPixelCount
        self.signalBounds = signalBounds
        self.reason = reason
    }

    public var isDetected: Bool {
        reason == .detected
    }
}

public struct ScreenshotPlacementOffsetDetector: Equatable, Sendable {
    public let searchPadding: CGFloat
    public let minimumSignalPixels: Int
    public let minimumContrast: Double
    public let maximumOutlierDistance: CGFloat

    public init(
        searchPadding: CGFloat = 24,
        minimumSignalPixels: Int = 8,
        minimumContrast: Double = 0.12,
        maximumOutlierDistance: CGFloat = 96
    ) {
        self.searchPadding = searchPadding
        self.minimumSignalPixels = minimumSignalPixels
        self.minimumContrast = minimumContrast
        self.maximumOutlierDistance = maximumOutlierDistance
    }

    public func detection(
        in bitmap: ScreenshotPlacementPixelBuffer,
        captureRect: CGRect,
        expectedSignalRect: CGRect
    ) -> ScreenshotPlacementOffsetDetection {
        guard bitmap.width > 0,
              bitmap.height > 0,
              bitmap.pixels.count == bitmap.width * bitmap.height,
              isUsable(captureRect),
              isUsable(expectedSignalRect),
              searchPadding.isFinite,
              minimumContrast.isFinite,
              maximumOutlierDistance.isFinite else {
            return rejected(.invalidInput)
        }

        let scaleX = CGFloat(bitmap.width) / captureRect.width
        let scaleY = CGFloat(bitmap.height) / captureRect.height
        guard scaleX.isFinite,
              scaleY.isFinite,
              scaleX > 0,
              scaleY > 0 else {
            return rejected(.invalidInput)
        }

        let expected = pixelRect(
            for: expectedSignalRect,
            captureRect: captureRect,
            scaleX: scaleX,
            scaleY: scaleY
        )
        let imageBounds = CGRect(x: 0, y: 0, width: bitmap.width, height: bitmap.height)
        guard expected.intersects(imageBounds) else {
            return rejected(.expectedRectOutsideCapture)
        }

        let search = expected
            .insetBy(dx: -abs(searchPadding * scaleX), dy: -abs(searchPadding * scaleY))
            .intersection(imageBounds)
            .integral
        guard !search.isNull,
              search.width >= 1,
              search.height >= 1 else {
            return rejected(.insufficientSearchArea)
        }

        let xRange = Int(max(0, search.minX))..<Int(min(CGFloat(bitmap.width), search.maxX))
        let yRange = Int(max(0, search.minY))..<Int(min(CGFloat(bitmap.height), search.maxY))
        var samples: [(x: Int, y: Int, luminance: Double)] = []
        samples.reserveCapacity(max(0, xRange.count * yRange.count))

        for y in yRange {
            for x in xRange {
                guard let pixel = bitmap.pixel(x: x, y: y),
                      pixel.opacity > 0.05 else {
                    continue
                }
                samples.append((x, y, pixel.luminance))
            }
        }

        guard !samples.isEmpty else {
            return rejected(.insufficientSignal)
        }

        let background = median(samples.map(\.luminance))
        let contrastSamples = samples.map { abs($0.luminance - background) }
        let maximumContrast = contrastSamples.max() ?? 0
        guard maximumContrast >= minimumContrast else {
            return rejected(.lowContrast)
        }

        var signalPixels: [(x: Int, y: Int, contrast: Double)] = []
        signalPixels.reserveCapacity(samples.count)
        for sample in samples {
            let contrast = abs(sample.luminance - background)
            if contrast >= minimumContrast {
                signalPixels.append((sample.x, sample.y, contrast))
            }
        }

        guard signalPixels.count >= max(1, minimumSignalPixels) else {
            return rejected(.insufficientSignal, maximumContrast: maximumContrast)
        }

        let minX = signalPixels.map(\.x).min() ?? 0
        let maxX = signalPixels.map(\.x).max() ?? minX
        let minY = signalPixels.map(\.y).min() ?? 0
        let maxY = signalPixels.map(\.y).max() ?? minY
        let signalBounds = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )
        let dx = (signalBounds.midX - expected.midX) / scaleX
        let dy = (signalBounds.midY - expected.midY) / scaleY
        let distance = CGFloat(Foundation.hypot(Double(dx), Double(dy)))

        guard distance <= maximumOutlierDistance else {
            return rejected(
                .excessiveOutlier,
                dx: dx,
                dy: dy,
                signalPixelCount: signalPixels.count,
                signalBounds: signalBounds
            )
        }

        let averageContrast = signalPixels.map(\.contrast).reduce(0, +) / Double(signalPixels.count)
        let densityConfidence = min(1, Double(signalPixels.count) / Double(max(minimumSignalPixels * 3, 1)))
        let contrastConfidence = min(1, averageContrast / max(minimumContrast, 0.001))
        let confidence = min(1, 0.2 + 0.5 * densityConfidence + 0.3 * contrastConfidence)

        return ScreenshotPlacementOffsetDetection(
            dx: dx,
            dy: dy,
            confidence: confidence,
            signalPixelCount: signalPixels.count,
            signalBounds: signalBounds,
            reason: .detected
        )
    }

    private func pixelRect(
        for rect: CGRect,
        captureRect: CGRect,
        scaleX: CGFloat,
        scaleY: CGFloat
    ) -> CGRect {
        CGRect(
            x: (rect.minX - captureRect.minX) * scaleX,
            y: (rect.minY - captureRect.minY) * scaleY,
            width: max(1, rect.width * scaleX),
            height: max(1, rect.height * scaleY)
        )
    }

    private func isUsable(_ rect: CGRect) -> Bool {
        rect.minX.isFinite
            && rect.minY.isFinite
            && rect.width.isFinite
            && rect.height.isFinite
            && !rect.isNull
            && !rect.isInfinite
            && rect.width > 0
            && rect.height > 0
    }

    private func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else {
            return 0
        }

        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }

        return sorted[middle]
    }

    private func rejected(
        _ reason: ScreenshotPlacementOffsetDetectionReason,
        dx: CGFloat = 0,
        dy: CGFloat = 0,
        signalPixelCount: Int = 0,
        signalBounds: CGRect? = nil,
        maximumContrast: Double = 0
    ) -> ScreenshotPlacementOffsetDetection {
        ScreenshotPlacementOffsetDetection(
            dx: dx,
            dy: dy,
            confidence: min(0.2, max(0, maximumContrast)),
            signalPixelCount: signalPixelCount,
            signalBounds: signalBounds,
            reason: reason
        )
    }
}
