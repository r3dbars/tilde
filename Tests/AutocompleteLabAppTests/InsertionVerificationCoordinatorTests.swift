import AutocompleteLabCore
import Testing
@testable import AutocompleteLabApp

@MainActor
@Suite("Insertion verification coordinator")
struct InsertionVerificationCoordinatorTests {
    @Test("Verified insertion does not retry or hide")
    func verifiedInsertionDoesNotRetryOrHide() async throws {
        let coordinator = InsertionVerificationCoordinator(
            scheduler: InsertionVerificationScheduler(delay: .milliseconds(0))
        )
        let baseline = insertionBaseline()
        var insertCalls: [(String, Set<InsertionMode>)] = []
        var hideCount = 0
        var suppressReasons: [String] = []

        coordinator.schedule(
            acceptedText: " world",
            baseline: baseline,
            readFocusedContext: { _ in
                InsertionVerificationFocusedContext(
                    fieldIdentity: baseline.fieldIdentity,
                    textBeforeCursor: "hello world"
                )
            },
            insertAcceptedText: { text, skippedModes in
                insertCalls.append((text, skippedModes))
                return true
            },
            suppressCurrentField: { reason in
                suppressReasons.append(reason)
            },
            hideSuggestion: {
                hideCount += 1
            }
        )

        try await Task.sleep(for: .milliseconds(20))

        #expect(insertCalls.isEmpty)
        #expect(hideCount == 0)
        #expect(suppressReasons.isEmpty)
    }

    @Test("Unchanged insertion retries once while skipping primary mode")
    func unchangedInsertionRetriesOnceSkippingPrimaryMode() async throws {
        let coordinator = InsertionVerificationCoordinator(
            scheduler: InsertionVerificationScheduler(delay: .milliseconds(0))
        )
        let baseline = insertionBaseline(
            profile: compatibilityProfile(
                insertionMode: .axValueReplacement,
                fallbackInsertionMode: .keyEvents
            )
        )
        var contexts = [
            InsertionVerificationFocusedContext(
                fieldIdentity: baseline.fieldIdentity,
                textBeforeCursor: "hello"
            ),
            InsertionVerificationFocusedContext(
                fieldIdentity: baseline.fieldIdentity,
                textBeforeCursor: "hello world"
            )
        ]
        var insertCalls: [(String, Set<InsertionMode>)] = []
        var hideCount = 0

        coordinator.schedule(
            acceptedText: " world",
            baseline: baseline,
            readFocusedContext: { _ in
                contexts.removeFirst()
            },
            insertAcceptedText: { text, skippedModes in
                insertCalls.append((text, skippedModes))
                return true
            },
            suppressCurrentField: { _ in },
            hideSuggestion: {
                hideCount += 1
            }
        )

        try await Task.sleep(for: .milliseconds(40))

        #expect(insertCalls.count == 1)
        #expect(insertCalls[0].0 == " world")
        #expect(insertCalls[0].1 == [.axValueReplacement])
        #expect(hideCount == 0)
    }

    @Test("Final failure suppresses field and hides suggestion")
    func finalFailureSuppressesFieldAndHidesSuggestion() async throws {
        let coordinator = InsertionVerificationCoordinator(
            scheduler: InsertionVerificationScheduler(delay: .milliseconds(0))
        )
        let baseline = insertionBaseline(
            profile: compatibilityProfile(
                insertionMode: .keyEvents,
                fallbackInsertionMode: nil,
                suppressesAfterInsertionFailure: true
            )
        )
        var suppressReasons: [String] = []
        var hideCount = 0

        coordinator.schedule(
            acceptedText: " world",
            baseline: baseline,
            readFocusedContext: { _ in
                InsertionVerificationFocusedContext(
                    fieldIdentity: baseline.fieldIdentity,
                    textBeforeCursor: "hello"
                )
            },
            insertAcceptedText: { _, _ in true },
            suppressCurrentField: { reason in
                suppressReasons.append(reason)
            },
            hideSuggestion: {
                hideCount += 1
            }
        )

        try await Task.sleep(for: .milliseconds(20))

        #expect(suppressReasons == ["insert-verification-failed"])
        #expect(hideCount == 1)
    }

    private func insertionBaseline(
        profile: CompatibilityProfile? = nil
    ) -> InsertionVerificationBaseline {
        InsertionVerificationBaseline(
            fieldIdentity: fieldIdentity(),
            previousTextBeforeCursor: "hello",
            profile: profile ?? compatibilityProfile(),
            suggestionID: "suggestion-1",
            requestMode: .phraseContinuation,
            retryCount: 0
        )
    }

    private func fieldIdentity() -> FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: "com.example.Editor",
            processIdentifier: 42,
            elementIdentifier: 7
        )
    }

    private func compatibilityProfile(
        insertionMode: InsertionMode = .axSelectedText,
        fallbackInsertionMode: InsertionMode? = .keyEvents,
        suppressesAfterInsertionFailure: Bool = true
    ) -> CompatibilityProfile {
        CompatibilityProfile(
            bundleIdentifier: "com.example.Editor",
            displayName: "Example Editor",
            supportLevel: .green,
            supportReason: "test",
            renderMode: .inlineAdjacent,
            insertionMode: insertionMode,
            fallbackInsertionMode: fallbackInsertionMode,
            suppressesAfterInsertionFailure: suppressesAfterInsertionFailure,
            notes: "test"
        )
    }
}
