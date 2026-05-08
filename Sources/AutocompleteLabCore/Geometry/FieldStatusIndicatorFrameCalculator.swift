import CoreGraphics
import Foundation

public enum FieldStatusIndicatorFrameCalculator {
    public static let defaultBadgeSize = CGSize(width: 22, height: 22)

    public static func frame(
        anchorRect: CGRect,
        fieldRect: CGRect? = nil,
        badgeSize: CGSize = defaultBadgeSize,
        screenFrame: CGRect,
        gap: CGFloat = 6,
        margin: CGFloat = 8
    ) -> CGRect? {
        guard let anchor = normalized(anchorRect),
              let screen = normalized(screenFrame),
              screen.width > 0,
              screen.height > 0 else {
            return nil
        }

        let field = fieldRect.flatMap(normalized)
        let reference = field ?? anchor
        let size = CGSize(
            width: max(1, ceil(badgeSize.width)),
            height: max(1, ceil(badgeSize.height))
        )
        let horizontalBounds = bounds(
            lower: screen.minX,
            upper: screen.maxX,
            margin: margin
        )
        let verticalBounds = bounds(
            lower: screen.minY,
            upper: screen.maxY,
            margin: margin
        )

        let leftX = reference.minX - gap - size.width
        let rightX = reference.maxX + gap
        let insideX = reference.minX + gap
        let x: CGFloat
        if fits(origin: leftX, length: size.width, bounds: horizontalBounds) {
            x = leftX
        } else if fits(origin: rightX, length: size.width, bounds: horizontalBounds) {
            x = rightX
        } else {
            x = clampedOrigin(
                preferred: insideX,
                length: size.width,
                lowerBound: horizontalBounds.lower,
                upperBound: horizontalBounds.upper
            )
        }

        let preferredY: CGFloat
        if anchor.height > 80 {
            preferredY = anchor.maxY - gap - size.height
        } else {
            preferredY = anchor.midY - (size.height / 2)
        }

        let y = clampedOrigin(
            preferred: preferredY,
            length: size.height,
            lowerBound: verticalBounds.lower,
            upperBound: verticalBounds.upper
        )

        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    private static func normalized(_ rect: CGRect) -> CGRect? {
        guard rect.minX.isFinite,
              rect.minY.isFinite,
              rect.maxX.isFinite,
              rect.maxY.isFinite,
              rect.width.isFinite,
              rect.height.isFinite,
              !rect.isNull else {
            return nil
        }

        return rect.standardized
    }

    private static func bounds(
        lower: CGFloat,
        upper: CGFloat,
        margin: CGFloat
    ) -> (lower: CGFloat, upper: CGFloat) {
        let lowerBound = lower + margin
        let upperBound = upper - margin
        return (lowerBound, max(lowerBound + 1, upperBound))
    }

    private static func fits(
        origin: CGFloat,
        length: CGFloat,
        bounds: (lower: CGFloat, upper: CGFloat)
    ) -> Bool {
        origin >= bounds.lower && origin + length <= bounds.upper
    }

    private static func clampedOrigin(
        preferred: CGFloat,
        length: CGFloat,
        lowerBound: CGFloat,
        upperBound: CGFloat
    ) -> CGFloat {
        let maxOrigin = max(lowerBound, upperBound - length)
        return min(max(preferred, lowerBound), maxOrigin)
    }
}
