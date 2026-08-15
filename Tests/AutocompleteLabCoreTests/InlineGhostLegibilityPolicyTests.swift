import Testing
@testable import AutocompleteLabCore

@Suite("Inline ghost legibility policy")
struct InlineGhostLegibilityPolicyTests {
    private let allSpecs: [InlineGhostColorSpec] = [
        .darkEditor,
        .lightEditor,
        .universal
    ]

    @Test("Every spec clears the contrast floor on pure black and pure white")
    func everySpecClearsContrastFloorOnBlackAndWhite() {
        for spec in allSpecs {
            for background in [0.0, 1.0] {
                let backgroundLuminance = InlineGhostLegibilityPolicy.relativeLuminance(ofWhite: background)
                let fillLuminance = InlineGhostLegibilityPolicy.relativeLuminance(ofWhite: spec.fillWhite)
                let haloLuminance = InlineGhostLegibilityPolicy.relativeLuminance(ofWhite: spec.haloWhite)
                let best = max(
                    InlineGhostLegibilityPolicy.contrastRatio(fillLuminance, backgroundLuminance),
                    InlineGhostLegibilityPolicy.contrastRatio(haloLuminance, backgroundLuminance)
                )

                #expect(best >= InlineGhostLegibilityPolicy.minimumContrastRatio)
            }
        }
    }

    @Test("Untrusted specs are dual-legible on fill alone")
    func untrustedSpecsAreDualLegibleOnFillAlone() {
        for spec in [InlineGhostColorSpec.universal, .lightEditor] {
            let fillLuminance = InlineGhostLegibilityPolicy.relativeLuminance(ofWhite: spec.fillWhite)

            for background in [0.0, 1.0] {
                let backgroundLuminance = InlineGhostLegibilityPolicy.relativeLuminance(ofWhite: background)

                #expect(
                    InlineGhostLegibilityPolicy.contrastRatio(fillLuminance, backgroundLuminance)
                        >= InlineGhostLegibilityPolicy.minimumContrastRatio
                )
            }
        }
    }

    @Test("Every spec keeps a visible halo on the opposite side of the fill")
    func everySpecKeepsVisibleHaloOppositeFill() {
        for spec in allSpecs {
            #expect(spec.haloAlpha > 0.2)
            #expect(spec.haloBlurRadius > 0)
            #expect(abs(spec.fillWhite - spec.haloWhite) >= 0.4)
        }
    }

    @Test("Reported luminance picks the matching spec")
    func reportedLuminancePicksMatchingSpec() {
        #expect(InlineGhostLegibilityPolicy.spec(reportedTextLuminance: nil) == .universal)
        #expect(InlineGhostLegibilityPolicy.spec(reportedTextLuminance: 0.9) == .darkEditor)
        #expect(InlineGhostLegibilityPolicy.spec(reportedTextLuminance: 0.62) == .darkEditor)
        #expect(InlineGhostLegibilityPolicy.spec(reportedTextLuminance: 0.1) == .lightEditor)
        #expect(InlineGhostLegibilityPolicy.spec(reportedTextLuminance: 0.25) == .lightEditor)
        #expect(InlineGhostLegibilityPolicy.spec(reportedTextLuminance: 0.4) == .universal)
    }

    @Test("A misreported color can never pick an unsafe paint")
    func misreportedColorCanNeverPickUnsafePaint() {
        for reported in stride(from: 0.0, through: 1.0, by: 0.05) {
            let spec = InlineGhostLegibilityPolicy.spec(reportedTextLuminance: reported)

            #expect(allSpecs.contains(spec))
        }
    }

    @Test("Marked-text paint clears the floor AFTER alpha compositing")
    func markedTextPaintClearsFloorAfterCompositing() {
        // No halo exists on this surface, so the honest test composites the
        // semi-transparent fill into each background before judging contrast.
        for background in [0.0, 1.0] {
            let composited = InlineGhostLegibilityPolicy.compositedWhite(
                of: .markedText,
                overBackgroundWhite: background
            )
            let compositedLuminance = InlineGhostLegibilityPolicy.relativeLuminance(ofWhite: composited)
            let backgroundLuminance = InlineGhostLegibilityPolicy.relativeLuminance(ofWhite: background)

            #expect(
                InlineGhostLegibilityPolicy.contrastRatio(compositedLuminance, backgroundLuminance)
                    >= InlineGhostLegibilityPolicy.minimumContrastRatio
            )
        }
    }
}
