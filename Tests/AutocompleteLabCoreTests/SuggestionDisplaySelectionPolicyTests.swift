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
}
