import Testing
@testable import AutocompleteLabCore

@Suite("Insertion undo recoverability")
struct InsertionUndoRecoverabilityTests {
    private let model = InsertionUndoRecoverabilityModel()

    @Test("TextEdit and Chrome require native single-edit proof")
    func nativeUndoCandidatesRequireNativeProof() throws {
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let chrome = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))

        #expect(model.expectedGuarantee(for: textEdit, acceptMode: "acceptNextWord") == .nativeSingleEdit)
        #expect(model.expectedGuarantee(for: textEdit, acceptMode: "acceptAllVisible") == .nativeSingleEdit)
        #expect(model.expectedGuarantee(for: chrome, acceptMode: "acceptNextWord") == .nativeSingleEdit)

        let decision = model.evaluate(
            profile: textEdit,
            proof: InsertionUndoRecoverabilityProof(
                appBundleIdentifier: "com.apple.TextEdit",
                acceptMode: "acceptNextWord",
                insertionVerified: true,
                undoMechanism: .nativeSingleEdit,
                sameSliceUndoProof: true,
                restoredOriginalTarget: true
            )
        )

        #expect(decision.status == .proven)
        #expect(decision.guarantee == .nativeSingleEdit)
    }

    @Test("App rollback is honest degraded proof for native candidates")
    func appRollbackIsDegradedForNativeCandidates() throws {
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))

        let decision = model.evaluate(
            profile: textEdit,
            proof: InsertionUndoRecoverabilityProof(
                appBundleIdentifier: "com.apple.TextEdit",
                acceptMode: "acceptNextWord",
                insertionVerified: true,
                undoMechanism: .appRollback,
                sameSliceUndoProof: true,
                restoredOriginalTarget: true
            )
        )

        #expect(decision.status == .degraded)
        #expect(decision.guarantee == .appRollback)
        #expect(decision.reason.contains("native single-edit undo is not proven"))
    }

    @Test("Notes and Obsidian stay degraded until surface proof graduates")
    func richSurfacesStayDegraded() throws {
        let notes = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.Notes"))
        let obsidian = try #require(CompatibilityProfileStore.mvp.profile(for: "md.obsidian"))

        #expect(model.expectedGuarantee(for: notes, acceptMode: "acceptNextWord") == .degraded)
        #expect(model.expectedGuarantee(for: obsidian, acceptMode: "acceptNextWord") == .degraded)

        let notesDecision = model.evaluate(
            profile: notes,
            proof: InsertionUndoRecoverabilityProof(
                appBundleIdentifier: "com.apple.Notes",
                acceptMode: "acceptNextWord",
                insertionVerified: true,
                undoMechanism: .appRollback,
                sameSliceUndoProof: true,
                restoredOriginalTarget: true
            )
        )

        #expect(notesDecision.status == .proven)
        #expect(notesDecision.guarantee == .appRollback)
    }

    @Test("Failure metadata exposes rollback state")
    func failureMetadataExposesRollbackState() throws {
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))

        let metadata = model.failureMetadata(
            profile: textEdit,
            acceptMode: "acceptNextWord",
            rollbackAvailable: true,
            rollbackMechanism: .appRollback
        )

        #expect(metadata["undoExpectedGuarantee"] == "nativeSingleEdit")
        #expect(metadata["rollbackAvailable"] == "true")
        #expect(metadata["rollbackMechanism"] == "appRollback")
        #expect(metadata["failureRecoverability"] == "recoverable")
    }
}
