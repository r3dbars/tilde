import Testing
@testable import AutocompleteLabCore

@Suite("Ghost width calibration")
struct GhostWidthCalibrationTests {
    @Test("Neutral calibration leaves estimates unchanged")
    func neutralCalibrationLeavesEstimatesUnchanged() {
        #expect(GhostWidthCalibration.neutral.scale == 1)
        #expect(GhostWidthCalibration.neutral.applied(to: 250) == 250)
    }

    @Test("An observed line width pulls the scale toward the true ratio")
    func observedLineWidthPullsScaleTowardTrueRatio() {
        let updated = GhostWidthCalibration.neutral.updated(
            measuredWidth: 110,
            estimatedWidth: 100
        )

        #expect(updated.scale == 1.05)
        #expect(updated.applied(to: 200) == 210)
    }

    @Test("Repeated observations converge on the true ratio")
    func repeatedObservationsConvergeOnTrueRatio() {
        var calibration = GhostWidthCalibration.neutral
        for _ in 0..<6 {
            calibration = calibration.updated(measuredWidth: 130, estimatedWidth: 100)
        }

        #expect(calibration.scale > 1.25)
        #expect(calibration.scale <= 1.3)
    }

    @Test("The scale never leaves the plausible band")
    func scaleNeverLeavesPlausibleBand() {
        #expect(GhostWidthCalibration(scale: 10).scale == 1.4)
        #expect(GhostWidthCalibration(scale: 0.1).scale == 0.75)

        let extreme = GhostWidthCalibration.neutral.updated(
            measuredWidth: 5_000,
            estimatedWidth: 10
        )

        #expect(extreme.scale == 1.4)
    }

    @Test("Tiny or degenerate widths are ignored")
    func tinyOrDegenerateWidthsAreIgnored() {
        let calibration = GhostWidthCalibration(scale: 1.2)

        #expect(calibration.updated(measuredWidth: 5, estimatedWidth: 100) == calibration)
        #expect(calibration.updated(measuredWidth: 100, estimatedWidth: 0) == calibration)
        #expect(calibration.updated(
            measuredWidth: .infinity,
            estimatedWidth: 100
        ) == calibration)
    }
}
