import Testing
@testable import AutocompleteLabCore
@testable import AutocompleteLabResearch

@Suite("Placement uncertainty suppressor")
struct PlacementUncertaintySuppressorTests {
    @Test("Suppresses a field after repeated placement uncertainty")
    func suppressesFieldAfterRepeatedPlacementUncertainty() {
        var suppressor = PlacementUncertaintySuppressor(threshold: 2)

        let first = suppressor.record(
            reason: "missing-caret",
            fieldIdentifier: "com.example.Editor|field:1"
        )
        let second = suppressor.record(
            reason: "invalid-caret",
            fieldIdentifier: "com.example.Editor|field:1"
        )

        #expect(!first.shouldSuppressField)
        #expect(first.metadata["placementUncertaintyCount"] == "1")
        #expect(first.metadata["placementUncertaintyFieldSuppressed"] == "false")
        #expect(second.shouldSuppressField)
        #expect(second.metadata["placementUncertaintyReason"] == "invalid-caret")
        #expect(second.metadata["placementUncertaintyCount"] == "2")
        #expect(second.metadata["placementUncertaintyThreshold"] == "2")
        #expect(second.metadata["placementUncertaintyFieldSuppressed"] == "true")
    }

    @Test("Counts placement uncertainty per field")
    func countsPlacementUncertaintyPerField() {
        var suppressor = PlacementUncertaintySuppressor(threshold: 2)

        _ = suppressor.record(reason: "missing-caret", fieldIdentifier: "field-a")
        let otherField = suppressor.record(reason: "missing-caret", fieldIdentifier: "field-b")

        #expect(otherField.count == 1)
        #expect(!otherField.shouldSuppressField)
    }

    @Test("Reset clears placement uncertainty for a field")
    func resetClearsPlacementUncertaintyForField() {
        var suppressor = PlacementUncertaintySuppressor(threshold: 2)

        _ = suppressor.record(reason: "missing-caret", fieldIdentifier: "field-a")
        suppressor.reset(fieldIdentifier: "field-a")
        let afterReset = suppressor.record(reason: "missing-caret", fieldIdentifier: "field-a")

        #expect(afterReset.count == 1)
        #expect(!afterReset.shouldSuppressField)
    }
}
