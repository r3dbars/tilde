import Testing
@testable import AutocompleteLabCore

@Suite("Accessibility attribute error log")
struct AccessibilityAttributeErrorLogTests {
    @Test("Buckets cannot-complete separately from timeout")
    func bucketsCannotCompleteSeparatelyFromTimeout() {
        #expect(AccessibilityAttributeErrorRecord.bucket(
            for: "cannotComplete",
            elapsedMilliseconds: 20,
            timeoutThresholdMilliseconds: 120
        ) == .cannotComplete)

        #expect(AccessibilityAttributeErrorRecord.bucket(
            for: "cannotComplete",
            elapsedMilliseconds: 140,
            timeoutThresholdMilliseconds: 120
        ) == .timeout)
    }

    @Test("Records errors by AX attribute and bucket")
    func recordsErrorsByAttributeAndBucket() {
        var log = AccessibilityAttributeErrorLog()

        log.record(attribute: "AXVisibleCharacterRange", errorCode: "cannotComplete", elapsedMilliseconds: 20)
        log.record(attribute: "AXVisibleCharacterRange", errorCode: "cannotComplete", elapsedMilliseconds: 140)
        log.record(attribute: "AXInsertionPointLineNumber", errorCode: "noValue")
        log.record(attribute: "AXBoundsForRange", errorCode: "parameterizedAttributeUnsupported")

        #expect(log.countsByBucket()[.cannotComplete] == 1)
        #expect(log.countsByBucket()[.timeout] == 1)
        #expect(log.countsByBucket()[.noValue] == 1)
        #expect(log.countsByBucket()[.unsupported] == 1)

        let byAttribute = log.countsByAttributeAndBucket()
        #expect(byAttribute["AXVisibleCharacterRange"]?[.cannotComplete] == 1)
        #expect(byAttribute["AXVisibleCharacterRange"]?[.timeout] == 1)
        #expect(byAttribute["AXInsertionPointLineNumber"]?[.noValue] == 1)
        #expect(byAttribute["AXBoundsForRange"]?[.unsupported] == 1)
    }

    @Test("Metadata is trace-safe and does not keep raw text")
    func metadataIsTraceSafeAndDoesNotKeepRawText() {
        var log = AccessibilityAttributeErrorLog()

        log.record(
            attribute: "AXVisibleCharacterRange private typed sentence",
            bucket: .cannotComplete,
            errorCode: "cannotComplete private typed sentence"
        )
        log.record(
            attribute: "private typed sentence",
            bucket: .other,
            errorCode: "private typed sentence"
        )

        let metadata = log.metadata()
        let combined = metadata.keys.joined(separator: " ") + metadata.values.joined(separator: " ")

        #expect(metadata["axErrorAttribute.AXVisibleCharacterRange.cannotComplete"] == "1")
        #expect(metadata["axErrorAttribute.unknownAttribute.other"] == "1")
        #expect(!combined.contains("private"))
        #expect(!combined.contains("typed"))
        #expect(!combined.contains("sentence"))
    }
}
