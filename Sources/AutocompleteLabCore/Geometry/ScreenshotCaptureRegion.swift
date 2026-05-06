import CoreGraphics
import Foundation

public enum ScreenshotCaptureRegion {
    public static func enclosing(
        _ rects: [CGRect],
        padding: CGFloat = 24,
        minimumSize: CGSize = CGSize(width: 48, height: 48)
    ) -> CGRect? {
        let usableRects = rects.compactMap(normalizedRect)
        guard let first = usableRects.first else {
            return nil
        }

        let union = usableRects.dropFirst().reduce(first) { partialResult, rect in
            partialResult.union(rect)
        }
        let padded = union.insetBy(dx: -padding, dy: -padding)
        let minX = floor(padded.minX)
        let minY = floor(padded.minY)
        let maxX = ceil(padded.maxX)
        let maxY = ceil(padded.maxY)

        return CGRect(
            x: minX,
            y: minY,
            width: max(maxX - minX, minimumSize.width),
            height: max(maxY - minY, minimumSize.height)
        )
    }

    private static func normalizedRect(_ rect: CGRect) -> CGRect? {
        guard rect.minX.isFinite,
              rect.minY.isFinite,
              rect.width.isFinite,
              rect.height.isFinite,
              !rect.isNull,
              !rect.isInfinite else {
            return nil
        }

        if rect.width > 0, rect.height > 0 {
            return rect
        }

        let width = max(rect.width, 1)
        let height = max(rect.height, 1)
        return CGRect(
            x: rect.midX - width / 2,
            y: rect.midY - height / 2,
            width: width,
            height: height
        )
    }
}
