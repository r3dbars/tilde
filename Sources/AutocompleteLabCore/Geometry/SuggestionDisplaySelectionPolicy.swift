import CoreGraphics
import Foundation

public enum SuggestionDisplaySelectionPolicy {
    public static func selectedScreenIndex(
        containingAccessibilityRect accessibilityRect: CGRect,
        screenFrames: [CGRect],
        accessibilityScreenHeight: CGFloat
    ) -> Int? {
        guard accessibilityRect.hasFiniteDisplayGeometry,
              accessibilityRect.height > 0,
              accessibilityScreenHeight.isFinite,
              accessibilityScreenHeight > 0 else {
            return nil
        }

        let probeRect = AccessibilityCoordinateConverter.appKitProbeRect(
            fromAccessibilityRect: accessibilityRect,
            screenHeight: accessibilityScreenHeight
        )
        guard probeRect.hasFiniteDisplayGeometry else {
            return nil
        }

        let centroid = CGPoint(x: probeRect.midX, y: probeRect.midY)
        if let centroidIndex = screenFrames.firstIndex(where: { screen in
            screen.hasFiniteDisplayGeometry
                && screen.width > 0
                && screen.height > 0
                && screen.contains(centroid)
        }) {
            return centroidIndex
        }

        return nil
    }
}

private extension CGRect {
    var hasFiniteDisplayGeometry: Bool {
        minX.isFinite
            && minY.isFinite
            && maxX.isFinite
            && maxY.isFinite
            && width.isFinite
            && height.isFinite
    }
}
