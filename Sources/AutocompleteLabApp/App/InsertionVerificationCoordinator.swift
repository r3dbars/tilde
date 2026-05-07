import AutocompleteLabCore
import Foundation

struct InsertionVerificationBaseline: Equatable {
    let fieldIdentity: FocusedFieldIdentity
    let previousTextBeforeCursor: String
    let profile: CompatibilityProfile
    let suggestionID: String?
    let requestMode: CompletionRequestMode?
    let retryCount: Int
}

struct InsertionVerificationFocusedContext: Equatable {
    let fieldIdentity: FocusedFieldIdentity
    let textBeforeCursor: String
}

@MainActor
final class InsertionVerificationCoordinator {
    private let scheduler: InsertionVerificationScheduler
    private let insertionVerification: InsertionVerification
    private let insertionRetryPolicy: InsertionRetryPolicy

    init(
        scheduler: InsertionVerificationScheduler = InsertionVerificationScheduler(),
        insertionVerification: InsertionVerification = InsertionVerification(),
        insertionRetryPolicy: InsertionRetryPolicy = InsertionRetryPolicy()
    ) {
        self.scheduler = scheduler
        self.insertionVerification = insertionVerification
        self.insertionRetryPolicy = insertionRetryPolicy
    }

    func schedule(
        acceptedText: String,
        baseline: InsertionVerificationBaseline?,
        readFocusedContext: @escaping @MainActor (CompatibilityProfile) -> InsertionVerificationFocusedContext?,
        insertAcceptedText: @escaping @MainActor (String, Set<InsertionMode>) -> Bool,
        suppressCurrentField: @escaping @MainActor (String) -> Void,
        hideSuggestion: @escaping @MainActor () -> Void
    ) {
        guard let baseline else {
            return
        }

        scheduler.schedule { [weak self] in
            self?.verify(
                acceptedText: acceptedText,
                baseline: baseline,
                readFocusedContext: readFocusedContext,
                insertAcceptedText: insertAcceptedText,
                suppressCurrentField: suppressCurrentField,
                hideSuggestion: hideSuggestion
            )
        }
    }

    func cancel() {
        scheduler.cancel()
    }

    private func verify(
        acceptedText: String,
        baseline: InsertionVerificationBaseline,
        readFocusedContext: @escaping @MainActor (CompatibilityProfile) -> InsertionVerificationFocusedContext?,
        insertAcceptedText: @escaping @MainActor (String, Set<InsertionMode>) -> Bool,
        suppressCurrentField: @escaping @MainActor (String) -> Void,
        hideSuggestion: @escaping @MainActor () -> Void
    ) {
        guard let context = readFocusedContext(baseline.profile) else {
            DiagnosticsLog.shared.record(
                "insert-verification",
                metadata: [
                    "app": baseline.profile.bundleIdentifier,
                    "result": "missing-context"
                ]
            )
            hideSuggestion()
            return
        }

        guard context.fieldIdentity == baseline.fieldIdentity else {
            return
        }

        let result = insertionVerification.verify(
            previousTextBeforeCursor: baseline.previousTextBeforeCursor,
            acceptedText: acceptedText,
            currentTextBeforeCursor: context.textBeforeCursor
        )

        DiagnosticsLog.shared.record(
            "insert-verification",
            metadata: [
                "app": baseline.profile.bundleIdentifier,
                "result": String(describing: result),
                "acceptedChars": String(acceptedText.count),
                "previousBeforeChars": String(baseline.previousTextBeforeCursor.count),
                "currentBeforeChars": String(context.textBeforeCursor.count)
            ]
        )

        guard result.isVerified else {
            handleFailedVerification(
                result: result,
                acceptedText: acceptedText,
                baseline: baseline,
                context: context,
                readFocusedContext: readFocusedContext,
                insertAcceptedText: insertAcceptedText,
                suppressCurrentField: suppressCurrentField,
                hideSuggestion: hideSuggestion
            )
            return
        }

        if baseline.retryCount > 0 {
            DiagnosticsLog.shared.record(
                "insert-verification-recovered",
                metadata: [
                    "app": baseline.profile.bundleIdentifier,
                    "acceptedChars": String(acceptedText.count),
                    "retryCount": String(baseline.retryCount)
                ]
            )
        }
        RawAutocompleteTraceLog.shared.record(
            type: .insertionVerified,
            suggestionID: baseline.suggestionID ?? "",
            appBundleIdentifier: baseline.profile.bundleIdentifier,
            fieldIdentity: baseline.fieldIdentity.traceDescription,
            requestMode: baseline.requestMode?.rawValue ?? "",
            acceptedText: acceptedText,
            outcome: "verified"
        )
    }

    private func handleFailedVerification(
        result: InsertionVerificationResult,
        acceptedText: String,
        baseline: InsertionVerificationBaseline,
        context: InsertionVerificationFocusedContext,
        readFocusedContext: @escaping @MainActor (CompatibilityProfile) -> InsertionVerificationFocusedContext?,
        insertAcceptedText: @escaping @MainActor (String, Set<InsertionMode>) -> Bool,
        suppressCurrentField: @escaping @MainActor (String) -> Void,
        hideSuggestion: @escaping @MainActor () -> Void
    ) {
        if insertionRetryPolicy.shouldRetry(
            result: result,
            insertionMode: baseline.profile.insertionMode,
            retryCount: baseline.retryCount
        ) {
            DiagnosticsLog.shared.record(
                "insert-verification-retry",
                metadata: [
                    "app": baseline.profile.bundleIdentifier,
                    "acceptedChars": String(acceptedText.count),
                    "retryCount": String(baseline.retryCount + 1),
                    "result": String(describing: result)
                ]
            )

            let skippedModes = insertionRetrySkippedModes(
                result: result,
                profile: baseline.profile,
                retryCount: baseline.retryCount
            )
            if insertAcceptedText(acceptedText, skippedModes) {
                let retryBaseline = InsertionVerificationBaseline(
                    fieldIdentity: baseline.fieldIdentity,
                    previousTextBeforeCursor: baseline.previousTextBeforeCursor,
                    profile: baseline.profile,
                    suggestionID: baseline.suggestionID,
                    requestMode: baseline.requestMode,
                    retryCount: baseline.retryCount + 1
                )
                schedule(
                    acceptedText: acceptedText,
                    baseline: retryBaseline,
                    readFocusedContext: readFocusedContext,
                    insertAcceptedText: insertAcceptedText,
                    suppressCurrentField: suppressCurrentField,
                    hideSuggestion: hideSuggestion
                )
                return
            }
        }

        DiagnosticsLog.shared.record(
            "insert-verification-final-failure",
            metadata: [
                "app": baseline.profile.bundleIdentifier,
                "result": String(describing: result),
                "acceptedChars": String(acceptedText.count),
                "retryCount": String(baseline.retryCount)
            ]
        )
        RawAutocompleteTraceLog.shared.record(
            type: .insertionFailed,
            suggestionID: baseline.suggestionID ?? "",
            appBundleIdentifier: baseline.profile.bundleIdentifier,
            fieldIdentity: baseline.fieldIdentity.traceDescription,
            requestMode: baseline.requestMode?.rawValue ?? "",
            acceptedText: acceptedText,
            outcome: String(describing: result),
            reason: "insert-verification-failed",
            metadata: [
                "previousBeforeChars": String(baseline.previousTextBeforeCursor.count),
                "currentBeforeChars": String(context.textBeforeCursor.count)
            ]
        )
        if baseline.profile.suppressesAfterInsertionFailure {
            suppressCurrentField("insert-verification-failed")
        }
        hideSuggestion()
    }

    private func insertionRetrySkippedModes(
        result: InsertionVerificationResult,
        profile: CompatibilityProfile,
        retryCount: Int
    ) -> Set<InsertionMode> {
        guard result == .unchanged,
              retryCount == 0,
              profile.fallbackInsertionMode != nil else {
            return []
        }

        return [profile.insertionMode]
    }
}
