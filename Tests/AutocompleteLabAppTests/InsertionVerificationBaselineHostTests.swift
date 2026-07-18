import Foundation
import AutocompleteLabCore
import Testing
@testable import AutocompleteLabApp

@MainActor
@Suite("Insertion verification baseline host")
struct InsertionVerificationBaselineHostTests {
    @Test("Fails closed when the current field does not match the snapshot")
    func mismatchedFieldReturnsNil() throws {
        let identity = FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let state = CurrentSuggestionStateHost()
        state.fieldIdentity = identity
        state.acceptanceSnapshot = acceptanceSnapshot(identity: identity)
        let host = makeHost(
            state: state,
            currentFieldIdentity: FocusedFieldIdentity(
                bundleIdentifier: "com.apple.Notes",
                processIdentifier: 42,
                elementIdentifier: 7
            )
        )

        #expect(host.baseline(
            acceptanceID: "acceptance",
            acceptedAt: Date(timeIntervalSince1970: 1),
            action: .acceptAllVisible,
            acceptMode: "acceptAllVisible"
        ) == nil)
    }

    @Test("Builds a field-bound baseline with the current request behavior profile")
    func buildsFieldBoundBaseline() throws {
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let identity = FocusedFieldIdentity(
            bundleIdentifier: profile.bundleIdentifier,
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let state = CurrentSuggestionStateHost()
        state.id = "suggestion"
        state.fieldIdentity = identity
        state.requestMode = .phraseContinuation
        state.acceptanceSnapshot = acceptanceSnapshot(identity: identity)
        state.textBeforeCursor = "This is "
        let snapshot = FocusedTextSnapshot(
            fieldIdentity: identity,
            textBeforeCursor: "This is ",
            textAfterCursor: ""
        )
        let host = makeHost(
            state: state,
            currentFieldIdentity: identity,
            lastTextSnapshot: snapshot,
            profile: profile,
            currentBehaviorProfileID: .docsProse
        )

        let acceptedAt = Date(timeIntervalSince1970: 10)
        let baseline = try #require(host.baseline(
            acceptanceID: "acceptance",
            acceptedAt: acceptedAt,
            action: .acceptAllVisible,
            acceptMode: "acceptAllVisible"
        ))

        #expect(baseline.acceptanceID == "acceptance")
        #expect(baseline.acceptedAt == acceptedAt)
        #expect(baseline.fieldIdentity == identity)
        #expect(baseline.previousTextBeforeCursor == "This is ")
        #expect(baseline.behaviorProfileID == AutocompleteBehaviorProfileID.docsProse)
        #expect(baseline.retryCount == 0)
    }

    private func makeHost(
        state: CurrentSuggestionStateHost,
        currentFieldIdentity: FocusedFieldIdentity?,
        lastTextSnapshot: FocusedTextSnapshot? = nil,
        profile: CompatibilityProfile? = nil,
        currentBehaviorProfileID: AutocompleteBehaviorProfileID? = nil
    ) -> InsertionVerificationBaselineHost {
        InsertionVerificationBaselineHost(
            dependencies: InsertionVerificationBaselineHostDependencies(
                currentFieldIdentity: { currentFieldIdentity },
                lastTextSnapshot: { lastTextSnapshot },
                currentSuggestionState: state,
                currentProfile: { profile },
                currentBehaviorProfileID: { currentBehaviorProfileID }
            )
        )
    }

    private func acceptanceSnapshot(identity: FocusedFieldIdentity) -> SuggestionAcceptanceSnapshot {
        SuggestionAcceptanceSnapshot(
            fieldIdentity: identity,
            targetFingerprint: FocusedTargetFingerprint(
                role: "AXTextArea",
                subrole: nil,
                elementFingerprint: FocusedElementFingerprint(identifier: "editor"),
                windowIdentifier: 1,
                elementBounds: nil,
                windowBounds: nil,
                caretBounds: nil,
                surroundingTextRevision: nil
            ),
            textBeforeCursor: "This is ",
            textAfterCursor: "",
            selectedTextLength: 0
        )
    }
}
