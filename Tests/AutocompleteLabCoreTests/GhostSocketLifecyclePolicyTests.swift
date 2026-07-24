import Testing
@testable import AutocompleteLabCore

@Suite("Ghost socket lifecycle policy")
struct GhostSocketLifecyclePolicyTests {

    // MARK: - Teardown: only the owner of the current file may unlink it

    @Test("A process that never bound the socket never unlinks it")
    func neverBoundNeverUnlinks() {
        #expect(!GhostSocketLifecyclePolicy.shouldUnlinkOnStop(
            didBindSocket: false, boundFileID: nil, currentFileID: 42
        ))
        // Even with a (stale) recorded file ID, "did not bind" wins.
        #expect(!GhostSocketLifecyclePolicy.shouldUnlinkOnStop(
            didBindSocket: false, boundFileID: 42, currentFileID: 42
        ))
    }

    @Test("The owner unlinks the exact file it bound")
    func ownerUnlinksOwnFile() {
        #expect(GhostSocketLifecyclePolicy.shouldUnlinkOnStop(
            didBindSocket: true, boundFileID: 42, currentFileID: 42
        ))
    }

    @Test("A replaced socket file belongs to someone else and stays")
    func replacedFileStays() {
        #expect(!GhostSocketLifecyclePolicy.shouldUnlinkOnStop(
            didBindSocket: true, boundFileID: 42, currentFileID: 99
        ))
    }

    @Test("An already-missing socket file needs no unlink")
    func missingFileNeedsNoUnlink() {
        #expect(!GhostSocketLifecyclePolicy.shouldUnlinkOnStop(
            didBindSocket: true, boundFileID: 42, currentFileID: nil
        ))
    }

    // MARK: - Bind: never steal a live socket

    @Test("A dead socket file is stale and gets replaced")
    func staleSocketIsReplaced() {
        #expect(
            GhostSocketLifecyclePolicy.bindAction(liveServerAnswersProbe: false)
                == .replaceStaleSocket
        )
    }

    @Test("A socket with a live server behind it is left alone")
    func liveSocketIsLeftAlone() {
        #expect(
            GhostSocketLifecyclePolicy.bindAction(liveServerAnswersProbe: true)
                == .leaveLiveSocketAlone
        )
    }
}
