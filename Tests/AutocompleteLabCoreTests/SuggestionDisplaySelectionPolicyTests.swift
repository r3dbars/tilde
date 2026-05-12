import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion display selection policy")
struct SuggestionDisplaySelectionPolicyTests {
    private let screenFrames = [
        CGRect(x: -1920, y: 0, width: 1920, height: 1080),
        CGRect(x: 0, y: 0, width: 1512, height: 982)
    ]
    private let screenHeight: CGFloat = 982

    @Test("Selects the screen containing the anchor centroid")
    func selectsScreenContainingAnchorCentroid() {
        let appKitAnchor = CGRect(x: -800, y: 420, width: 0, height: 24)
        let accessibilityAnchor = AccessibilityCoordinateConverter.accessibilityRect(
            fromAppKitRect: appKitAnchor,
            screenHeight: screenHeight
        )

        let index = SuggestionDisplaySelectionPolicy.selectedScreenIndex(
            containingAccessibilityRect: accessibilityAnchor,
            screenFrames: screenFrames,
            accessibilityScreenHeight: screenHeight
        )

        #expect(index == 0)
    }

    @Test("Uses centroid instead of largest overlap for spanning anchors")
    func usesCentroidInsteadOfLargestOverlapForSpanningAnchors() {
        let appKitAnchor = CGRect(x: -1900, y: 420, width: 4000, height: 24)
        let accessibilityAnchor = AccessibilityCoordinateConverter.accessibilityRect(
            fromAppKitRect: appKitAnchor,
            screenHeight: screenHeight
        )

        let index = SuggestionDisplaySelectionPolicy.selectedScreenIndex(
            containingAccessibilityRect: accessibilityAnchor,
            screenFrames: screenFrames,
            accessibilityScreenHeight: screenHeight
        )

        #expect(index == 1)
    }

    @Test("Suppresses anchors that do not map to any screen")
    func suppressesAnchorsThatDoNotMapToAnyScreen() {
        let appKitAnchor = CGRect(x: 5000, y: 420, width: 0, height: 24)
        let accessibilityAnchor = AccessibilityCoordinateConverter.accessibilityRect(
            fromAppKitRect: appKitAnchor,
            screenHeight: screenHeight
        )

        let index = SuggestionDisplaySelectionPolicy.selectedScreenIndex(
            containingAccessibilityRect: accessibilityAnchor,
            screenFrames: screenFrames,
            accessibilityScreenHeight: screenHeight
        )

        #expect(index == nil)
    }

    @Test("Suppresses invalid anchor geometry")
    func suppressesInvalidAnchorGeometry() {
        let index = SuggestionDisplaySelectionPolicy.selectedScreenIndex(
            containingAccessibilityRect: CGRect(x: 100, y: 100, width: 0, height: 0),
            screenFrames: screenFrames,
            accessibilityScreenHeight: screenHeight
        )

        #expect(index == nil)
    }

    @Test("Selects vertical displays above and below the main screen")
    func selectsVerticalDisplaysAboveAndBelowMainScreen() {
        let verticalScreens = [
            CGRect(x: 0, y: -1080, width: 1920, height: 1080),
            CGRect(x: 0, y: 0, width: 1512, height: 982),
            CGRect(x: 0, y: 982, width: 1920, height: 1080)
        ]
        let lowerAnchor = AccessibilityCoordinateConverter.accessibilityRect(
            fromAppKitRect: CGRect(x: 500, y: -600, width: 4, height: 22),
            screenHeight: screenHeight
        )
        let upperAnchor = AccessibilityCoordinateConverter.accessibilityRect(
            fromAppKitRect: CGRect(x: 500, y: 1_200, width: 4, height: 22),
            screenHeight: screenHeight
        )

        #expect(SuggestionDisplaySelectionPolicy.selectedScreenIndex(
            containingAccessibilityRect: lowerAnchor,
            screenFrames: verticalScreens,
            accessibilityScreenHeight: screenHeight
        ) == 0)
        #expect(SuggestionDisplaySelectionPolicy.selectedScreenIndex(
            containingAccessibilityRect: upperAnchor,
            screenFrames: verticalScreens,
            accessibilityScreenHeight: screenHeight
        ) == 2)
    }

    @Test("Suppresses ambiguous mirrored display frames instead of guessing")
    func suppressesAmbiguousMirroredDisplayFrames() {
        let mirroredFrames = [
            CGRect(x: 0, y: 0, width: 1512, height: 982),
            CGRect(x: 0, y: 0, width: 1512, height: 982)
        ]
        let appKitAnchor = CGRect(x: 420, y: 500, width: 4, height: 22)
        let accessibilityAnchor = AccessibilityCoordinateConverter.accessibilityRect(
            fromAppKitRect: appKitAnchor,
            screenHeight: screenHeight
        )

        let index = SuggestionDisplaySelectionPolicy.selectedScreenIndex(
            containingAccessibilityRect: accessibilityAnchor,
            screenFrames: mirroredFrames,
            accessibilityScreenHeight: screenHeight
        )

        #expect(index == nil)
    }
}
