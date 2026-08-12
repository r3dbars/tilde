import CryptoKit
import Foundation
import Testing
@testable import AutocompleteLabApp
@testable import AutocompleteLabCore

@Suite("Personal brain aggregate status", .serialized)
struct PersonalBrainStatusTests {
    @Test("Ready output has an exact aggregate-only schema and does not mutate settings")
    func readySchemaAndPrivacy() async throws {
        let fixture = try Fixture(enabled: true)
        defer { fixture.remove() }
        try await fixture.appendCheckpoint()
        let before = fixture.defaults.persistentDomain(forName: fixture.suiteName) ?? [:]

        let output = try #require(fixture.output())

        #expect(output == Self.readyJSON(captureEnabled: true))
        let after = fixture.defaults.persistentDomain(forName: fixture.suiteName) ?? [:]
        #expect(NSDictionary(dictionary: before).isEqual(to: after))
        for sentinel in fixture.privateSentinels {
            #expect(!output.contains(sentinel))
        }
    }

    @Test("Off capture can read a retained aggregate checkpoint")
    func offRetainsReadout() async throws {
        let fixture = try Fixture(enabled: false)
        defer { fixture.remove() }
        try await fixture.appendCheckpoint()

        #expect(fixture.output() == Self.readyJSON(captureEnabled: false))
    }

    @Test("Missing and incompatible checkpoints are stable empty reports")
    func emptyReports() async throws {
        let missing = try Fixture(enabled: false)
        defer { missing.remove() }
        #expect(missing.output() == Self.emptyJSON)

        let checkpointless = try Fixture(enabled: true)
        defer { checkpointless.remove() }
        try await checkpointless.store.append([checkpointless.event], checkpoint: nil)
        #expect(checkpointless.output() == Self.emptyJSON.replacingOccurrences(
            of: "\"captureEnabled\":false", with: "\"captureEnabled\":true"
        ))

        let incompatible = try Fixture(enabled: true)
        defer { incompatible.remove() }
        try incompatible.writeAuthenticatedCheckpoint { $0[2] = "old-recipe-v1" }
        #expect(incompatible.output() == Self.emptyJSON.replacingOccurrences(
            of: "\"captureEnabled\":false", with: "\"captureEnabled\":true"
        ))
    }

    @Test("Current history, experiment, and exclusions must all match")
    func envelopeMustMatchSettings() async throws {
        let fixture = try Fixture(enabled: true)
        defer { fixture.remove() }
        try await fixture.appendCheckpoint()
        let empty = Self.emptyJSON.replacingOccurrences(
            of: "\"captureEnabled\":false", with: "\"captureEnabled\":true"
        )

        fixture.settings.personalHistoryIdentifier = "different-history"
        #expect(fixture.output() == empty)
        fixture.settings.personalHistoryIdentifier = fixture.historyID
        fixture.settings.personalNextWordExperimentIdentifier = "different-experiment"
        #expect(fixture.output() == empty)
        fixture.settings.personalNextWordExperimentIdentifier = fixture.experimentID
        fixture.settings.personalHistoryExcludedApps = ["com.example.Different"]
        #expect(fixture.output() == empty)
    }

    @Test("Only the newest encrypted record is authenticated and decoded")
    func latestRecordOnly() async throws {
        let fixture = try Fixture(enabled: true)
        defer { fixture.remove() }
        try await fixture.appendCheckpoint()
        var bytes = try Data(contentsOf: fixture.file)
        let headerCount = Data("TILDE-PERSONAL-HISTORY\t2\n".utf8).count
        bytes.insert(contentsOf: Data("CORRUPT-OLDER-RECORD\n".utf8), at: headerCount)
        try bytes.write(to: fixture.file)
        chmod(fixture.file.path, 0o600)

        #expect(fixture.output() == Self.readyJSON(captureEnabled: true))
    }

    @Test("Malformed authenticated checkpoints fail with complete safe JSON")
    func malformedCheckpoint() throws {
        let fixture = try Fixture(enabled: true)
        defer { fixture.remove() }
        try fixture.writeAuthenticatedCheckpoint { $0.removeLast() }

        let failure = try #require(fixture.failure())
        #expect(failure == Self.unavailableJSON)
        for sentinel in fixture.privateSentinels { #expect(!failure.contains(sentinel)) }
    }

    @Test("Missing keys fail safely while legacy records need no key")
    func keyFailureAndLegacy() async throws {
        let fixture = try Fixture(enabled: true)
        defer { fixture.remove() }
        try await fixture.appendCheckpoint()
        let noKeyStore = EncryptedPersonalHistoryStore(
            location: fixture.file, keyProvider: MissingKeys()
        )
        let result = PersonalBrainStatusCommand(
            settings: fixture.settings, store: noKeyStore
        ).execute()
        #expect(result == .failure(Self.unavailableJSON.replacingOccurrences(
            of: "store-corrupt", with: "key-unavailable"
        )))

        try Data("TILDE-PERSONAL-HISTORY\t1\nNOT-DECRYPTED\n".utf8).write(to: fixture.file)
        #expect(try noKeyStore.loadLatestCheckpoint() == nil)
    }

    @Test("Status reads never tighten or touch private storage metadata")
    func statusReadDoesNotMutateStorage() async throws {
        let fixture = try Fixture(enabled: true)
        defer { fixture.remove() }
        try await fixture.appendCheckpoint()
        let directory = fixture.file.deletingLastPathComponent()
        let fileBefore = try Metadata(fixture.file)
        let directoryBefore = try Metadata(directory)

        #expect(fixture.output() == Self.readyJSON(captureEnabled: true))
        #expect(try Metadata(fixture.file) == fileBefore)
        #expect(try Metadata(directory) == directoryBefore)
    }

    @Test("Status rejects unsafe permissions without repairing them")
    func statusRejectsUnsafeModesWithoutMutation() async throws {
        let fixture = try Fixture(enabled: true)
        defer { fixture.remove() }
        try await fixture.appendCheckpoint()
        let directory = fixture.file.deletingLastPathComponent()
        #expect(chmod(fixture.file.path, 0o644) == 0)
        let looseFile = try Metadata(fixture.file)
        #expect(fixture.failure() == Self.unavailableJSON)
        #expect(try Metadata(fixture.file) == looseFile)

        #expect(chmod(fixture.file.path, 0o600) == 0)
        #expect(chmod(directory.path, 0o755) == 0)
        let looseDirectory = try Metadata(directory)
        #expect(fixture.failure() == Self.unavailableJSON)
        #expect(try Metadata(directory) == looseDirectory)

        try? FileManager.default.removeItem(at: fixture.file)
        let emptyLooseDirectory = try Metadata(directory)
        #expect(fixture.failure() == Self.unavailableJSON)
        #expect(try Metadata(directory) == emptyLooseDirectory)
    }

    @Test("A status read waits for an exclusive history-file update")
    func statusWaitsForCompleteRecord() async throws {
        let fixture = try Fixture(enabled: true)
        defer { fixture.remove() }
        try await fixture.appendCheckpoint()
        try assertStatusWaitsForCompleteRecord(fixture)
    }

    @Test("An owner-only FIFO produces complete unavailable JSON promptly")
    func statusRejectsFIFO() throws {
        let fixture = try Fixture(enabled: true)
        defer { fixture.remove() }
        try fixture.makeFIFO()
        let start = ContinuousClock.now

        #expect(fixture.failure() == Self.unavailableJSON)
        #expect(start.duration(to: .now) < .seconds(1))
    }

    @Test("A status read cannot observe an empty newly-created store")
    func statusWaitsForNewStoreCreation() async throws {
        let fixture = try Fixture(enabled: true)
        defer { fixture.remove() }
        try await fixture.appendCheckpoint()
        try assertStatusWaitsForNewStoreCreation(fixture)
    }

    private func assertStatusWaitsForCompleteRecord(_ fixture: Fixture) throws {
        let original = try Data(contentsOf: fixture.file)
        let descriptor = open(fixture.file.path, O_RDWR | O_EXLOCK | O_CLOEXEC)
        try #require(descriptor >= 0)
        defer { close(descriptor) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: Data("TILDE-PERSONAL-HISTORY\t2\nPARTIAL".utf8))

        let command = CommandBox(.init(settings: fixture.settings, store: fixture.store))
        let started = DispatchSemaphore(value: 0)
        let finished = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            started.signal()
            command.run()
            finished.signal()
        }
        started.wait()
        #expect(finished.wait(timeout: .now() + 0.05) == .timedOut)

        try handle.truncate(atOffset: 0)
        try handle.seek(toOffset: 0)
        try handle.write(contentsOf: original)
        #expect(fsync(descriptor) == 0)
        #expect(flock(descriptor, LOCK_UN) == 0)
        #expect(finished.wait(timeout: .now() + 1) == .success)
        #expect(command.result == .output(Self.readyJSON(captureEnabled: true)))
    }

    private func assertStatusWaitsForNewStoreCreation(_ fixture: Fixture) throws {
        let original = try Data(contentsOf: fixture.file)
        let directory = fixture.file.deletingLastPathComponent()
        let directoryDescriptor = open(
            directory.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC
        )
        try #require(directoryDescriptor >= 0)
        defer { close(directoryDescriptor) }
        #expect(flock(directoryDescriptor, LOCK_EX) == 0)
        try FileManager.default.removeItem(at: fixture.file)
        #expect(FileManager.default.createFile(
            atPath: fixture.file.path,
            contents: Data(),
            attributes: [.posixPermissions: NSNumber(value: Int16(0o600))]
        ))

        let command = CommandBox(.init(settings: fixture.settings, store: fixture.store))
        let finished = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            command.run()
            finished.signal()
        }
        #expect(finished.wait(timeout: .now() + 0.05) == .timedOut)

        try original.write(to: fixture.file)
        #expect(chmod(fixture.file.path, 0o600) == 0)
        #expect(flock(directoryDescriptor, LOCK_UN) == 0)
        #expect(finished.wait(timeout: .now() + 1) == .success)
        #expect(command.result == .output(Self.readyJSON(captureEnabled: true)))
    }

    private static func readyJSON(captureEnabled: Bool) -> String {
        """
        {"baselineRecipeID":"r1435-live-v1","candidateRecipeID":"r1945-live-v1","captureEnabled":\(captureEnabled),"cutoverMilliseconds":1786556700000,"daily":{"buckets":[{"cells":[1,2,3,4,5,6,7,8,9],"predictionDisagreements":30,"utcDayStartMilliseconds":1786492800000}],"coversLifetime":true},"gates":{"activeDays":{"count":1,"minimum":14},"candidatePredictions":{"count":33,"minimum":200},"opportunities":{"count":45,"minimum":2000},"predictionDisagreements":{"count":30,"minimum":100}},"lifetime":{"capacityLimited":true,"cells":[1,2,3,4,5,6,7,8,9],"predictionDisagreements":30},"privacy":{"aggregateOnly":true,"containsCandidates":false,"containsPaths":false,"containsPerCaseData":false,"containsRawText":false,"containsRecordIdentifiers":false,"containsTargets":false,"localOnly":true},"reason":"ready","schema":"tilde.personal-brain-status.v1","state":"ready"}
        """
    }

    private static let emptyJSON = """
    {"baselineRecipeID":"r1435-live-v1","candidateRecipeID":"r1945-live-v1","captureEnabled":false,"cutoverMilliseconds":1786556700000,"daily":null,"gates":null,"lifetime":null,"privacy":{"aggregateOnly":true,"containsCandidates":false,"containsPaths":false,"containsPerCaseData":false,"containsRawText":false,"containsRecordIdentifiers":false,"containsTargets":false,"localOnly":true},"reason":"no-compatible-checkpoint","schema":"tilde.personal-brain-status.v1","state":"empty"}
    """

    private static let unavailableJSON = """
    {"baselineRecipeID":"r1435-live-v1","candidateRecipeID":"r1945-live-v1","captureEnabled":true,"cutoverMilliseconds":1786556700000,"daily":null,"gates":null,"lifetime":null,"privacy":{"aggregateOnly":true,"containsCandidates":false,"containsPaths":false,"containsPerCaseData":false,"containsRawText":false,"containsRecordIdentifiers":false,"containsTargets":false,"localOnly":true},"reason":"store-corrupt","schema":"tilde.personal-brain-status.v1","state":"unavailable"}
    """

    private final class Keys: PersonalHistoryKeyProviding, @unchecked Sendable {
        let data = Data(repeating: 0xA5, count: 32)
        func loadExistingKey() throws -> Data { data }
        func loadOrCreateKey() throws -> Data { data }
        func deleteKey() throws {}
    }

    private final class MissingKeys: PersonalHistoryKeyProviding, @unchecked Sendable {
        func loadExistingKey() throws -> Data { throw PersonalHistoryStorageError.missingKey }
        func loadOrCreateKey() throws -> Data { throw PersonalHistoryStorageError.missingKey }
        func deleteKey() throws {}
    }

    private struct Metadata: Equatable {
        let mode: mode_t
        let modifiedSeconds: Int
        let modifiedNanoseconds: Int

        init(_ url: URL) throws {
            var info = stat()
            try #require(lstat(url.path, &info) == 0)
            mode = info.st_mode
            modifiedSeconds = info.st_mtimespec.tv_sec
            modifiedNanoseconds = info.st_mtimespec.tv_nsec
        }
    }

    private final class CommandBox: @unchecked Sendable {
        let command: PersonalBrainStatusCommand
        private let lock = NSLock()
        private var stored: PersonalBrainStatusCommandResult?

        init(_ command: PersonalBrainStatusCommand) { self.command = command }
        func run() { lock.withLock { stored = command.execute() } }
        var result: PersonalBrainStatusCommandResult? { lock.withLock { stored } }
    }

    private struct EncodedBatch: Encodable {
        let v = 1
        let events: [PersonalHistoryEvent]
        let checkpoint: PersonalNextWordStoredCheckpoint
    }

    private struct Fixture {
        let root: URL
        let file: URL
        let suiteName: String
        let defaults: UserDefaults
        let settings: TildeSettings
        let keys = Keys()
        let store: EncryptedPersonalHistoryStore
        let historyID = "STATUS-HISTORY-SENTINEL"
        let experimentID = "STATUS-EXPERIMENT-SENTINEL"
        let excludedApp = "com.example.StatusExclusionSentinel"

        init(enabled: Bool) throws {
            root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
                .appendingPathComponent("tilde-status-tests-\(UUID().uuidString)")
            file = root.appendingPathComponent("Personal History/history.v1.enc")
            suiteName = "status-tests-\(UUID().uuidString)"
            defaults = try #require(UserDefaults(suiteName: suiteName))
            settings = TildeSettings(keyboard: defaults)
            store = EncryptedPersonalHistoryStore(location: file, keyProvider: keys)
            settings.personalHistoryEnabled = enabled
            settings.personalHistoryIdentifier = historyID
            settings.personalNextWordExperimentIdentifier = experimentID
            settings.personalHistoryExcludedApps = [excludedApp]
        }

        var privateSentinels: [String] {
            [historyID, experimentID, excludedApp, "STATUS-TEXT-SENTINEL",
             "STATUS-EVENT-SENTINEL", "STATUS-SESSION-SENTINEL"]
        }

        func appendCheckpoint() async throws {
            try await store.append([event], checkpoint: storedCheckpoint)
        }

        func output() -> String? {
            guard case let .output(json) = PersonalBrainStatusCommand(
                settings: settings, store: store
            ).execute() else { return nil }
            return json
        }

        func failure() -> String? {
            guard case let .failure(json) = PersonalBrainStatusCommand(
                settings: settings, store: store
            ).execute() else { return nil }
            return json
        }

        func writeAuthenticatedCheckpoint(mutate: (inout [Any]) -> Void) throws {
            let encoded = try JSONEncoder().encode(
                EncodedBatch(events: [event], checkpoint: storedCheckpoint)
            )
            var batch = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
            var stored = try #require(batch["checkpoint"] as? [String: Any])
            var checkpoint = try #require(stored["checkpoint"] as? [Any])
            mutate(&checkpoint)
            stored["checkpoint"] = checkpoint
            batch["checkpoint"] = stored
            let plaintext = try JSONSerialization.data(withJSONObject: batch, options: [.sortedKeys])
            let sealed = try AES.GCM.seal(
                plaintext, using: SymmetricKey(data: keys.data),
                authenticating: Data("bar.r3d.tilde.personal-history.v1".utf8)
            )
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            chmod(file.deletingLastPathComponent().path, 0o700)
            var raw = Data("TILDE-PERSONAL-HISTORY\t2\n".utf8)
            raw.append(try #require(sealed.combined).base64EncodedData())
            raw.append(0x0A)
            try raw.write(to: file)
            chmod(file.path, 0o600)
        }

        func makeFIFO() throws {
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            #expect(chmod(file.deletingLastPathComponent().path, 0o700) == 0)
            #expect(mkfifo(file.path, 0o600) == 0)
        }

        var storedCheckpoint: PersonalNextWordStoredCheckpoint {
            PersonalNextWordStoredCheckpoint(
                historyIdentifier: historyID,
                experimentIdentifier: experimentID,
                excludedApps: [excludedApp],
                checkpoint: checkpoint
            )
        }

        var checkpoint: PersonalNextWordShadowCheckpoint {
            PersonalNextWordShadowCheckpoint(
                evaluationStartMilliseconds: PersonalNextWordShadow.evaluationStartMilliseconds,
                totals: aggregate,
                activeDays: [.init(
                    utcDayStartMilliseconds: 1_786_492_800_000, aggregate: aggregate
                )],
                everCapacityLimited: true
            )!
        }

        var aggregate: PersonalNextWordPairedAggregate {
            .init(
                outcomeCells: .init(
                    baselineSilentCandidateSilent: 1,
                    baselineSilentCandidateCorrect: 2,
                    baselineSilentCandidateWrong: 3,
                    baselineCorrectCandidateSilent: 4,
                    baselineCorrectCandidateCorrect: 5,
                    baselineCorrectCandidateWrong: 6,
                    baselineWrongCandidateSilent: 7,
                    baselineWrongCandidateCorrect: 8,
                    baselineWrongCandidateWrong: 9
                ),
                predictionDisagreements: 30
            )
        }

        var event: PersonalHistoryEvent {
            PersonalHistoryEvent(
                id: "STATUS-EVENT-SENTINEL",
                timestampMilliseconds: 1_786_556_800_000,
                historyIdentifier: historyID,
                sessionIdentifier: "STATUS-SESSION-SENTINEL",
                appBundleIdentifier: "com.example.StatusSourceSentinel",
                source: .typed,
                text: "STATUS-TEXT-SENTINEL"
            )!
        }

        func remove() {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: root)
        }
    }
}
