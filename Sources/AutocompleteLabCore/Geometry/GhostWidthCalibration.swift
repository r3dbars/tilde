import Foundation

/// Running correction between text widths estimated in a guessed font and
/// widths actually observed on screen. Any surface that must place a ghost
/// by measuring the typed line in a font the target app never confirmed
/// compounds its error with every character; one observed line width per
/// poll pulls the estimate back toward truth instead.
public struct GhostWidthCalibration: Equatable, Sendable {
    public static let neutral = GhostWidthCalibration(scale: 1)

    private static let minimumScale = 0.75
    private static let maximumScale = 1.4
    /// Widths below this carry too little signal to calibrate from.
    private static let minimumWidth = 8.0

    public let scale: Double

    public init(scale: Double) {
        self.scale = min(max(scale, Self.minimumScale), Self.maximumScale)
    }

    public func updated(measuredWidth: Double, estimatedWidth: Double) -> GhostWidthCalibration {
        guard measuredWidth >= Self.minimumWidth,
              estimatedWidth >= Self.minimumWidth,
              measuredWidth.isFinite,
              estimatedWidth.isFinite else {
            return self
        }

        let observed = measuredWidth / estimatedWidth
        return GhostWidthCalibration(scale: (scale + observed) / 2)
    }

    public func applied(to estimatedWidth: Double) -> Double {
        estimatedWidth * scale
    }
}
