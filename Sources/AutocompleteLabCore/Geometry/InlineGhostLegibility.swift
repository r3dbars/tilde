import Foundation

/// Grayscale paint for inline ghost text: a fill plus a soft halo drawn
/// behind the glyphs. Between them the ghost must stay readable over any
/// editor background, because web/Electron composers routinely misreport
/// their text colors and the true background is unknowable from outside.
public struct InlineGhostColorSpec: Equatable, Sendable {
    public let fillWhite: Double
    public let fillAlpha: Double
    public let haloWhite: Double
    public let haloAlpha: Double
    public let haloBlurRadius: Double

    public init(
        fillWhite: Double,
        fillAlpha: Double,
        haloWhite: Double,
        haloAlpha: Double,
        haloBlurRadius: Double
    ) {
        self.fillWhite = fillWhite
        self.fillAlpha = fillAlpha
        self.haloWhite = haloWhite
        self.haloAlpha = haloAlpha
        self.haloBlurRadius = haloBlurRadius
    }

    /// Reported text is light, so the background is probably dark: a light
    /// fill carries legibility, and the dark halo covers a misreport.
    public static let darkEditor = InlineGhostColorSpec(
        fillWhite: 0.80,
        fillAlpha: 0.88,
        haloWhite: 0,
        haloAlpha: 0.50,
        haloBlurRadius: 2
    )

    /// Reported text is dark, so the background is probably light: this fill
    /// clears the contrast floor against both white and black on its own.
    public static let lightEditor = InlineGhostColorSpec(
        fillWhite: 0.42,
        fillAlpha: 0.78,
        haloWhite: 1,
        haloAlpha: 0.35,
        haloBlurRadius: 2
    )

    /// No trustworthy report: a mid gray that is dual-legible by itself,
    /// with a dark halo for tinted or translucent backgrounds.
    public static let universal = InlineGhostColorSpec(
        fillWhite: 0.52,
        fillAlpha: 0.82,
        haloWhite: 0,
        haloAlpha: 0.40,
        haloBlurRadius: 2
    )

    /// Marked-text surfaces have no halo — the host composites the fill
    /// straight into its own text — so this fill must clear the contrast
    /// floor AFTER alpha compositing over both pure black and pure white.
    /// One paint, no report consulted: the clients that honor marked-text
    /// styling are the same ones that misreport their colors.
    public static let markedText = InlineGhostColorSpec(
        fillWhite: 0.50,
        fillAlpha: 0.92,
        haloWhite: 0,
        haloAlpha: 0,
        haloBlurRadius: 0
    )
}

public enum InlineGhostLegibilityPolicy {
    /// Every spec must clear this WCAG contrast ratio against pure white and
    /// pure black — via the fill or the halo, whichever reads against that
    /// background.
    public static let minimumContrastRatio: Double = 3

    /// The reported luminance is a hint, never a commitment: a misreported
    /// color can only pick between specs that are all safe everywhere.
    public static func spec(reportedTextLuminance: Double?) -> InlineGhostColorSpec {
        guard let reportedTextLuminance else {
            return .universal
        }

        if reportedTextLuminance >= 0.62 {
            return .darkEditor
        }

        if reportedTextLuminance <= 0.25 {
            return .lightEditor
        }

        return .universal
    }

    /// The gray a semi-transparent fill actually becomes once the host
    /// composites it over a background — the only gray contrast can be
    /// honestly judged on for halo-less surfaces.
    public static func compositedWhite(
        of spec: InlineGhostColorSpec,
        overBackgroundWhite background: Double
    ) -> Double {
        (spec.fillAlpha * spec.fillWhite) + ((1 - spec.fillAlpha) * background)
    }

    public static func relativeLuminance(ofWhite white: Double) -> Double {
        let clamped = min(max(white, 0), 1)
        guard clamped > 0.03928 else {
            return clamped / 12.92
        }

        return pow((clamped + 0.055) / 1.055, 2.4)
    }

    public static func contrastRatio(_ first: Double, _ second: Double) -> Double {
        (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }
}
