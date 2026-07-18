import Foundation
import AutocompleteLabCore

@MainActor
protocol InsertionVerificationHandling: AnyObject {
    func insertionVerificationContext(
        for baseline: InsertionVerificationBaseline,
        acceptedText: String
    ) -> FocusedInsertionVerificationContext
    func insertionRetrySkippedModes(
        result: InsertionVerificationResult,
        profile: CompatibilityProfile,
        retryCount: Int
    ) -> Set<InsertionMode>
    func retryAcceptedInsertion(
        _ acceptedText: String,
        skippingInsertionModes: Set<InsertionMode>,
        action: KeyboardAction?
    ) -> Bool
    func handleInsertionVerificationContextFailure(
        _ contextRead: FocusedInsertionVerificationContext,
        acceptedText: String,
        baseline: InsertionVerificationBaseline
    )
    func handleInsertionVerificationFailure(
        acceptedText: String,
        baseline: InsertionVerificationBaseline,
        context: FocusedTextContext,
        result: InsertionVerificationResult
    )
    func handleInsertionVerificationSuccess(
        acceptedText: String,
        baseline: InsertionVerificationBaseline
    )
}

/// Owns delayed insertion verification and retry scheduling. AppDelegate keeps
/// field reads, insertion actions, and acceptance side effects behind the typed
/// handler surface.
@MainActor
final class InsertionVerificationHost {
    private let scheduler: InsertionVerificationScheduler
    private let verification: InsertionVerification
    private let timingPolicy: InsertionVerificationTimingPolicy
    private let fastPathPolicy: ObsidianInsertionVerificationFastPathPolicy
    private let retryPolicy: InsertionRetryPolicy
    private weak var handler: (any InsertionVerificationHandling)?

    init(
        handler: any InsertionVerificationHandling,
        scheduler: InsertionVerificationScheduler = InsertionVerificationScheduler(),
        verification: InsertionVerification = InsertionVerification(),
        timingPolicy: InsertionVerificationTimingPolicy = InsertionVerificationTimingPolicy(),
        fastPathPolicy: ObsidianInsertionVerificationFastPathPolicy = ObsidianInsertionVerificationFastPathPolicy(),
        retryPolicy: InsertionRetryPolicy = InsertionRetryPolicy()
    ) {
        self.handler = handler
        self.scheduler = scheduler
        self.verification = verification
        self.timingPolicy = timingPolicy
        self.fastPathPolicy = fastPathPolicy
        self.retryPolicy = retryPolicy
    }

    func schedule(
        acceptedText: String,
        baseline: InsertionVerificationBaseline
    ) {
        scheduler.scheduleAsync(
            after: .milliseconds(
                timingPolicy.delayMilliseconds(
                    for: baseline.profile,
                    retryCount: baseline.retryCount
                )
            )
        ) { [weak self] in
            guard let self, let handler = self.handler else {
                return
            }

            let contextRead = handler.insertionVerificationContext(
                for: baseline,
                acceptedText: acceptedText
            )
            guard case let .ready(context: initialContext) = contextRead else {
                handler.handleInsertionVerificationContextFailure(
                    contextRead,
                    acceptedText: acceptedText,
                    baseline: baseline
                )
                return
            }

            var context = initialContext
            var result = self.verification.verify(
                previousTextBeforeCursor: baseline.previousTextBeforeCursor,
                acceptedText: acceptedText,
                currentTextBeforeCursor: context.textBeforeCursor,
                previousTextAfterCursor: baseline.previousTextAfterCursor,
                currentTextAfterCursor: context.textAfterCursor
            )
            self.recordVerification(
                result: result,
                baseline: baseline,
                acceptedText: acceptedText,
                context: context
            )

            if self.fastPathPolicy.canVerifyLengthMatchedSuffix(
                   appBundleIdentifier: baseline.profile.bundleIdentifier,
                   previousTextBeforeCursor: baseline.previousTextBeforeCursor,
                   acceptedText: acceptedText,
                   currentTextBeforeCursor: context.textBeforeCursor,
                   previousTextAfterCursor: baseline.previousTextAfterCursor,
                   currentTextAfterCursor: context.textAfterCursor,
                   verificationResult: result
               ) {
                result = .verified
                DiagnosticsLog.shared.record(
                    "obsidian-length-matched-insert-verification-fast-path",
                    metadata: [
                        "app": baseline.profile.bundleIdentifier,
                        "acceptedChars": String(acceptedText.count),
                        "previousBeforeChars": String(baseline.previousTextBeforeCursor.count),
                        "currentBeforeChars": String(context.textBeforeCursor.count),
                        "reason": "length-matched-suffix"
                    ]
                )
                self.recordVerification(
                    result: result,
                    baseline: baseline,
                    acceptedText: acceptedText,
                    context: context,
                    source: "obsidian-length-matched-suffix"
                )
            }

            if !result.isVerified,
               let recheckDelayMilliseconds = self.timingPolicy.readOnlyRecheckDelayMilliseconds(
                   for: baseline.profile,
                   result: result,
                   retryCount: baseline.retryCount
               ) {
                try? await Task.sleep(for: .milliseconds(recheckDelayMilliseconds))
                guard !Task.isCancelled else {
                    return
                }

                if case let .ready(context: recheckContext) = handler.insertionVerificationContext(
                    for: baseline,
                    acceptedText: acceptedText
                ) {
                    context = recheckContext
                    result = self.verification.verify(
                        previousTextBeforeCursor: baseline.previousTextBeforeCursor,
                        acceptedText: acceptedText,
                        currentTextBeforeCursor: context.textBeforeCursor,
                        previousTextAfterCursor: baseline.previousTextAfterCursor,
                        currentTextAfterCursor: context.textAfterCursor
                    )
                    self.recordVerification(
                        result: result,
                        baseline: baseline,
                        acceptedText: acceptedText,
                        context: context,
                        source: "read-only-recheck",
                        recheckDelayMilliseconds: recheckDelayMilliseconds
                    )
                }
            }

            guard result.isVerified else {
                if self.retryPolicy.shouldRetry(
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

                    let skippedModes = handler.insertionRetrySkippedModes(
                        result: result,
                        profile: baseline.profile,
                        retryCount: baseline.retryCount
                    )
                    if handler.retryAcceptedInsertion(
                        acceptedText,
                        skippingInsertionModes: skippedModes,
                        action: baseline.action
                    ) {
                        var retryBaseline = baseline
                        retryBaseline.retryCount += 1
                        self.schedule(acceptedText: acceptedText, baseline: retryBaseline)
                        return
                    }
                }

                handler.handleInsertionVerificationFailure(
                    acceptedText: acceptedText,
                    baseline: baseline,
                    context: context,
                    result: result
                )
                return
            }

            handler.handleInsertionVerificationSuccess(
                acceptedText: acceptedText,
                baseline: baseline
            )
        }
    }

    func cancel() {
        scheduler.cancel()
    }

    private func recordVerification(
        result: InsertionVerificationResult,
        baseline: InsertionVerificationBaseline,
        acceptedText: String,
        context: FocusedTextContext,
        source: String? = nil,
        recheckDelayMilliseconds: Int? = nil
    ) {
        var metadata: [String: String] = [
            "app": baseline.profile.bundleIdentifier,
            "result": String(describing: result),
            "acceptedChars": String(acceptedText.count),
            "previousBeforeChars": String(baseline.previousTextBeforeCursor.count),
            "currentBeforeChars": String(context.textBeforeCursor.count),
            "previousAfterChars": String(baseline.previousTextAfterCursor.count),
            "currentAfterChars": String(context.textAfterCursor.count)
        ]
        if let source {
            metadata["source"] = source
        }
        if let recheckDelayMilliseconds {
            metadata["recheckDelayMilliseconds"] = String(recheckDelayMilliseconds)
        }
        DiagnosticsLog.shared.record("insert-verification", metadata: metadata)
    }
}
