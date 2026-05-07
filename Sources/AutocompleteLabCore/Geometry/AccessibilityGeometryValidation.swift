import CoreGraphics
import Foundation

public struct AccessibilityCharacterRange: Codable, Equatable, Sendable {
    public let location: Int
    public let length: Int

    public init(location: Int, length: Int) {
        self.location = max(0, location)
        self.length = max(0, length)
    }

    public var upperBound: Int {
        location + length
    }

    public var insertionLocation: Int {
        upperBound
    }

    public func containsInsertionPoint(_ utf16Offset: Int) -> Bool {
        utf16Offset >= location && utf16Offset <= upperBound
    }

    public func intersects(_ other: AccessibilityCharacterRange) -> Bool {
        guard length > 0, other.length > 0 else {
            return containsInsertionPoint(other.location) || other.containsInsertionPoint(location)
        }

        return location < other.upperBound && other.location < upperBound
    }
}

public enum AccessibilityAXErrorBucket: String, Codable, Equatable, Sendable, CaseIterable {
    case timeout
    case cannotComplete
    case unsupported
    case noValue
    case invalidElement
    case illegalArgument
    case decodeFailure
    case other
}

public struct AccessibilityAttributeErrorRecord: Codable, Equatable, Sendable {
    public let attribute: String
    public let bucket: AccessibilityAXErrorBucket
    public let errorCode: String
    public let elapsedMilliseconds: Int?

    public init(
        attribute: String,
        bucket: AccessibilityAXErrorBucket,
        errorCode: String,
        elapsedMilliseconds: Int? = nil
    ) {
        self.attribute = Self.safeAttributeName(attribute)
        self.bucket = bucket
        self.errorCode = Self.safeErrorCode(errorCode)
        self.elapsedMilliseconds = elapsedMilliseconds.map { max(0, $0) }
    }

    public static func bucket(
        for errorCode: String,
        elapsedMilliseconds: Int? = nil,
        timeoutThresholdMilliseconds: Int = 120
    ) -> AccessibilityAXErrorBucket {
        let normalized = errorCode
            .lowercased()
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()

        if normalized.contains("timeout") {
            return .timeout
        }

        if normalized.contains("cannotcomplete") {
            if let elapsedMilliseconds,
               elapsedMilliseconds >= max(0, timeoutThresholdMilliseconds) {
                return .timeout
            }

            return .cannotComplete
        }

        if normalized.contains("attributeunsupported")
            || normalized.contains("parameterizedattributeunsupported") {
            return .unsupported
        }

        if normalized.contains("novalue") {
            return .noValue
        }

        if normalized.contains("invaliduielement") {
            return .invalidElement
        }

        if normalized.contains("illegalargument") {
            return .illegalArgument
        }

        if normalized.contains("decodefailed") {
            return .decodeFailure
        }

        return .other
    }

    static func safeAttributeName(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("AX") || trimmed.hasPrefix("kAX") else {
            return "unknownAttribute"
        }

        let token = trimmed.prefix { character in
            character.isLetter
                || character.isNumber
                || character == "_"
                || character == "-"
        }

        return token.isEmpty ? "unknownAttribute" : String(token.prefix(80))
    }

    static func safeErrorCode(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "unknown"
        }

        let token = trimmed.prefix { character in
            character.isLetter
                || character.isNumber
                || character == "_"
                || character == "-"
                || character == ":"
        }

        let candidate = String(token.prefix(80))
        let knownCodes: Set<String> = [
            "success",
            "failure",
            "illegalArgument",
            "invalidUIElement",
            "invalidUIElementObserver",
            "cannotComplete",
            "timeout",
            "attributeUnsupported",
            "parameterizedAttributeUnsupported",
            "actionUnsupported",
            "notificationUnsupported",
            "notImplemented",
            "notificationAlreadyRegistered",
            "notificationNotRegistered",
            "apiDisabled",
            "noValue",
            "notEnoughPrecision",
            "decodeFailed",
            "unknown"
        ]

        if knownCodes.contains(candidate) {
            return candidate
        }

        if candidate.hasPrefix("axError:") || Int(candidate) != nil {
            return candidate
        }

        return "unknown"
    }
}

public struct AccessibilityAttributeErrorLog: Codable, Equatable, Sendable {
    public private(set) var errors: [AccessibilityAttributeErrorRecord]

    public init(errors: [AccessibilityAttributeErrorRecord] = []) {
        self.errors = errors
    }

    public var isEmpty: Bool {
        errors.isEmpty
    }

    public mutating func record(
        attribute: String,
        errorCode: String,
        elapsedMilliseconds: Int? = nil,
        timeoutThresholdMilliseconds: Int = 120
    ) {
        record(
            attribute: attribute,
            bucket: AccessibilityAttributeErrorRecord.bucket(
                for: errorCode,
                elapsedMilliseconds: elapsedMilliseconds,
                timeoutThresholdMilliseconds: timeoutThresholdMilliseconds
            ),
            errorCode: errorCode,
            elapsedMilliseconds: elapsedMilliseconds
        )
    }

    public mutating func record(
        attribute: String,
        bucket: AccessibilityAXErrorBucket,
        errorCode: String,
        elapsedMilliseconds: Int? = nil
    ) {
        errors.append(AccessibilityAttributeErrorRecord(
            attribute: attribute,
            bucket: bucket,
            errorCode: errorCode,
            elapsedMilliseconds: elapsedMilliseconds
        ))
    }

    public func countsByBucket() -> [AccessibilityAXErrorBucket: Int] {
        errors.reduce(into: [:]) { counts, error in
            counts[error.bucket, default: 0] += 1
        }
    }

    public func countsByAttributeAndBucket() -> [String: [AccessibilityAXErrorBucket: Int]] {
        errors.reduce(into: [:]) { counts, error in
            counts[error.attribute, default: [:]][error.bucket, default: 0] += 1
        }
    }

    public func metadata(prefix: String = "ax") -> [String: String] {
        var metadata: [String: String] = [:]

        for (bucket, count) in countsByBucket() {
            metadata["\(prefix)ErrorBucket.\(bucket.rawValue)"] = String(count)
        }

        for attribute in countsByAttributeAndBucket().keys.sorted() {
            guard let bucketCounts = countsByAttributeAndBucket()[attribute] else {
                continue
            }

            for bucket in bucketCounts.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
                metadata["\(prefix)ErrorAttribute.\(attribute).\(bucket.rawValue)"] = String(bucketCounts[bucket] ?? 0)
            }
        }

        return metadata
    }
}

public struct AccessibilityGeometryTextState: Equatable, Sendable {
    public let textBeforeCursorUTF16Length: Int
    public let textAfterCursorUTF16Length: Int
    public let selectedRange: AccessibilityCharacterRange?
    public let visibleCharacterRange: AccessibilityCharacterRange?

    public init(
        textBeforeCursorUTF16Length: Int,
        textAfterCursorUTF16Length: Int,
        selectedRange: AccessibilityCharacterRange? = nil,
        visibleCharacterRange: AccessibilityCharacterRange? = nil
    ) {
        self.textBeforeCursorUTF16Length = max(0, textBeforeCursorUTF16Length)
        self.textAfterCursorUTF16Length = max(0, textAfterCursorUTF16Length)
        self.selectedRange = selectedRange
        self.visibleCharacterRange = visibleCharacterRange
    }

    public func textAndSelectionMatch(_ other: AccessibilityGeometryTextState) -> Bool {
        textBeforeCursorUTF16Length == other.textBeforeCursorUTF16Length
            && textAfterCursorUTF16Length == other.textAfterCursorUTF16Length
            && selectedRange == other.selectedRange
    }
}

public struct AccessibilityGeometrySample: Equatable, Sendable {
    public let fieldIdentity: FocusedFieldIdentity
    public let textState: AccessibilityGeometryTextState
    public let caretRect: CGRect?
    public let textLineRect: CGRect?
    public let elementRect: CGRect?
    public let windowRect: CGRect?
    public let insertionPointLineNumber: Int?
    public let observedAt: Date

    public init(
        fieldIdentity: FocusedFieldIdentity,
        textState: AccessibilityGeometryTextState,
        caretRect: CGRect? = nil,
        textLineRect: CGRect? = nil,
        elementRect: CGRect? = nil,
        windowRect: CGRect? = nil,
        insertionPointLineNumber: Int? = nil,
        observedAt: Date = Date()
    ) {
        self.fieldIdentity = fieldIdentity
        self.textState = textState
        self.caretRect = caretRect
        self.textLineRect = textLineRect
        self.elementRect = elementRect
        self.windowRect = windowRect
        self.insertionPointLineNumber = insertionPointLineNumber.map { max(0, $0) }
        self.observedAt = observedAt
    }

    public init(
        fieldIdentity: FocusedFieldIdentity,
        textState: AccessibilityGeometryTextState,
        insertionPointLineNumber: Int?,
        caretRect: CGRect? = nil,
        textLineRect: CGRect? = nil,
        elementRect: CGRect? = nil,
        windowRect: CGRect? = nil,
        observedAt: Date = Date()
    ) {
        self.init(
            fieldIdentity: fieldIdentity,
            textState: textState,
            caretRect: caretRect,
            textLineRect: textLineRect,
            elementRect: elementRect,
            windowRect: windowRect,
            insertionPointLineNumber: insertionPointLineNumber,
            observedAt: observedAt
        )
    }
}

public struct AccessibilityGeometryValidationPolicy: Equatable, Sendable {
    public let maxStableTextJumpDistance: CGFloat
    public let staleRectTolerance: CGFloat
    public let boundsTolerance: CGFloat

    public init(
        maxStableTextJumpDistance: CGFloat = 220,
        staleRectTolerance: CGFloat = 2,
        boundsTolerance: CGFloat = 24
    ) {
        self.maxStableTextJumpDistance = max(1, maxStableTextJumpDistance)
        self.staleRectTolerance = max(0, staleRectTolerance)
        self.boundsTolerance = max(0, boundsTolerance)
    }

    public static let standard = AccessibilityGeometryValidationPolicy()
}

public struct AccessibilityGeometryValidation: Equatable {
    public let sample: AccessibilityGeometrySample
    public let previousSample: AccessibilityGeometrySample?
    public let caretEvaluation: AccessibilityTextBoundsPolicy.Evaluation
    public let textLineEvaluation: AccessibilityTextBoundsPolicy.Evaluation

    public var caretRect: CGRect? {
        caretEvaluation.bounds
    }

    public var textLineRect: CGRect? {
        textLineEvaluation.bounds
    }

    public var shouldRecordInHistory: Bool {
        !caretEvaluation.hasTransientGeometryRejection
            && !textLineEvaluation.hasTransientGeometryRejection
    }

    public var metadata: [String: String] {
        var metadata: [String: String] = [
            "hasVisibleCharacterRange": String(sample.textState.visibleCharacterRange != nil),
            "hasInsertionPointLineNumber": String(sample.insertionPointLineNumber != nil),
            "caretGeometryUsable": String(caretEvaluation.isUsable),
            "lineGeometryUsable": String(textLineEvaluation.isUsable)
        ]

        if let visibleRange = sample.textState.visibleCharacterRange {
            metadata["visibleCharacterRangeLocation"] = String(visibleRange.location)
            metadata["visibleCharacterRangeLength"] = String(visibleRange.length)
        }

        if let lineNumber = sample.insertionPointLineNumber {
            metadata["insertionPointLineNumber"] = String(lineNumber)
        }

        if let reason = caretEvaluation.rejectionReason {
            metadata["caretGeometryReason"] = reason.rawValue
        }

        if let reason = textLineEvaluation.rejectionReason {
            metadata["lineGeometryReason"] = reason.rawValue
        }

        return metadata
    }
}

public struct AccessibilityGeometryHistory: Equatable, Sendable {
    public let maxSamplesPerField: Int
    public let maxTrackedFields: Int
    public let policy: AccessibilityGeometryValidationPolicy
    public private(set) var samplesByField: [FocusedFieldIdentity: [AccessibilityGeometrySample]]

    public init(
        maxSamplesPerField: Int = 4,
        maxTrackedFields: Int = 24,
        policy: AccessibilityGeometryValidationPolicy = .standard,
        samplesByField: [FocusedFieldIdentity: [AccessibilityGeometrySample]] = [:]
    ) {
        self.maxSamplesPerField = max(1, maxSamplesPerField)
        self.maxTrackedFields = max(1, maxTrackedFields)
        self.policy = policy
        self.samplesByField = samplesByField
    }

    public func recentSamples(for fieldIdentity: FocusedFieldIdentity) -> [AccessibilityGeometrySample] {
        samplesByField[fieldIdentity] ?? []
    }

    public mutating func record(_ sample: AccessibilityGeometrySample) {
        var samples = samplesByField[sample.fieldIdentity] ?? []
        samples.append(sample)
        if samples.count > maxSamplesPerField {
            samples.removeFirst(samples.count - maxSamplesPerField)
        }
        samplesByField[sample.fieldIdentity] = samples
        trimTrackedFields()
    }

    public mutating func validateAndRecord(
        _ sample: AccessibilityGeometrySample
    ) -> AccessibilityGeometryValidation {
        let validation = AccessibilityGeometryValidator.validate(
            sample,
            previousSample: samplesByField[sample.fieldIdentity]?.last,
            policy: policy
        )

        if validation.shouldRecordInHistory {
            record(sample)
        }

        return validation
    }

    private mutating func trimTrackedFields() {
        guard samplesByField.count > maxTrackedFields else {
            return
        }

        let fieldsByOldestSample = samplesByField
            .compactMap { field, samples -> (FocusedFieldIdentity, Date)? in
                guard let newest = samples.last?.observedAt else {
                    return nil
                }

                return (field, newest)
            }
            .sorted { lhs, rhs in lhs.1 < rhs.1 }

        for (field, _) in fieldsByOldestSample.prefix(samplesByField.count - maxTrackedFields) {
            samplesByField.removeValue(forKey: field)
        }
    }
}

public enum AccessibilityGeometryValidator {
    public static func validate(
        _ sample: AccessibilityGeometrySample,
        previousSample: AccessibilityGeometrySample? = nil,
        policy: AccessibilityGeometryValidationPolicy = .standard
    ) -> AccessibilityGeometryValidation {
        var caretEvaluation = AccessibilityTextBoundsPolicy.evaluateTextBounds(
            sample.caretRect,
            elementRect: sample.elementRect,
            windowRect: sample.windowRect,
            selectedRange: sample.textState.selectedRange,
            visibleCharacterRange: sample.textState.visibleCharacterRange,
            tolerance: policy.boundsTolerance
        )
        var lineEvaluation = AccessibilityTextBoundsPolicy.evaluateTextLineBounds(
            sample.textLineRect,
            caretRect: caretEvaluation.bounds,
            elementRect: sample.elementRect,
            windowRect: sample.windowRect,
            selectedRange: sample.textState.selectedRange,
            visibleCharacterRange: sample.textState.visibleCharacterRange,
            tolerance: policy.boundsTolerance
        )

        if let previousSample,
           sample.textState.textAndSelectionMatch(previousSample.textState) {
            caretEvaluation = rejectStaleOrJumpedCaretIfNeeded(
                caretEvaluation,
                sample: sample,
                previousSample: previousSample,
                policy: policy
            )
            lineEvaluation = rejectStaleLineIfNeeded(
                lineEvaluation,
                sample: sample,
                previousSample: previousSample,
                policy: policy
            )
        }

        return AccessibilityGeometryValidation(
            sample: sample,
            previousSample: previousSample,
            caretEvaluation: caretEvaluation,
            textLineEvaluation: lineEvaluation
        )
    }

    private static func rejectStaleOrJumpedCaretIfNeeded(
        _ evaluation: AccessibilityTextBoundsPolicy.Evaluation,
        sample: AccessibilityGeometrySample,
        previousSample: AccessibilityGeometrySample,
        policy: AccessibilityGeometryValidationPolicy
    ) -> AccessibilityTextBoundsPolicy.Evaluation {
        guard evaluation.isUsable,
              let currentRect = evaluation.bounds,
              let previousRect = previousSample.caretRect else {
            return evaluation
        }

        if staleScrollOrLineSignal(
            currentRect: currentRect,
            previousRect: previousRect,
            sample: sample,
            previousSample: previousSample,
            policy: policy
        ) {
            return .rejected(.stale)
        }

        if distance(from: previousRect, to: currentRect) > policy.maxStableTextJumpDistance {
            return .rejected(.jumpedTooFar)
        }

        return evaluation
    }

    private static func rejectStaleLineIfNeeded(
        _ evaluation: AccessibilityTextBoundsPolicy.Evaluation,
        sample: AccessibilityGeometrySample,
        previousSample: AccessibilityGeometrySample,
        policy: AccessibilityGeometryValidationPolicy
    ) -> AccessibilityTextBoundsPolicy.Evaluation {
        guard evaluation.isUsable,
              let currentRect = evaluation.bounds,
              let previousRect = previousSample.textLineRect else {
            return evaluation
        }

        if staleScrollOrLineSignal(
            currentRect: currentRect,
            previousRect: previousRect,
            sample: sample,
            previousSample: previousSample,
            policy: policy
        ) {
            return .rejected(.stale)
        }

        return evaluation
    }

    private static func staleScrollOrLineSignal(
        currentRect: CGRect,
        previousRect: CGRect,
        sample: AccessibilityGeometrySample,
        previousSample: AccessibilityGeometrySample,
        policy: AccessibilityGeometryValidationPolicy
    ) -> Bool {
        guard rect(currentRect, isWithin: policy.staleRectTolerance, of: previousRect) else {
            return false
        }

        return sample.textState.visibleCharacterRange != previousSample.textState.visibleCharacterRange
            || sample.insertionPointLineNumber != previousSample.insertionPointLineNumber
    }

    private static func distance(from lhs: CGRect, to rhs: CGRect) -> CGFloat {
        let dx = lhs.midX - rhs.midX
        let dy = lhs.midY - rhs.midY
        return sqrt((dx * dx) + (dy * dy))
    }

    private static func rect(_ lhs: CGRect, isWithin tolerance: CGFloat, of rhs: CGRect) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) <= tolerance
            && abs(lhs.origin.y - rhs.origin.y) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }
}

private extension AccessibilityTextBoundsPolicy.Evaluation {
    var hasTransientGeometryRejection: Bool {
        rejectionReason == .stale
            || rejectionReason == .jumpedTooFar
            || rejectionReason == .visibleRangeMismatch
    }
}
