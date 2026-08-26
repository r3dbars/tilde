import Foundation
import Testing
@testable import TildeLabKit

@Suite("Tilde Lab asset verification")
struct LabAssetVerifierTests {
    @Test("An explicitly experimental GGUF is hashed and labeled without weakening the production pin")
    func experimentalGGUF() async throws {
        let fixture = try makeFixture(modelBytes: Data("GGUFexperimental-model".utf8))
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let configuration = LabExecutionConfiguration(
            serverExecutable: fixture.server,
            modelFile: fixture.model,
            modelProfile: .experimental(
                identifier: "google/gemma-4-26B-A4B",
                revision: "q8-local"
            )
        )

        let assets = try await LabAssetVerifier().verify(configuration)

        #expect(assets.verificationMode == .experimentalLocal)
        #expect(assets.modelIdentifier == "google/gemma-4-26B-A4B")
        #expect(assets.modelRevision == "q8-local")
        #expect(assets.modelSHA256.count == 64)
        #expect(assets.helperSHA256.count == 64)
    }

    @Test("Production mode still rejects non-production bytes")
    func productionPinRemainsStrict() async throws {
        let fixture = try makeFixture(modelBytes: Data("GGUFnot-production".utf8))
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let configuration = LabExecutionConfiguration(
            serverExecutable: fixture.server,
            modelFile: fixture.model
        )

        do {
            _ = try await LabAssetVerifier().verify(configuration)
            Issue.record("Non-production bytes unexpectedly passed production verification.")
        } catch LabAssetError.invalidModelSize {
            // Expected: the immutable production size gate runs before hashing.
        } catch {
            Issue.record("Unexpected verification error: \(error)")
        }
    }

    @Test("Experimental mode rejects a local file that is not GGUF")
    func experimentalFormatGate() async throws {
        let fixture = try makeFixture(modelBytes: Data("not-a-gguf".utf8))
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let configuration = LabExecutionConfiguration(
            serverExecutable: fixture.server,
            modelFile: fixture.model,
            modelProfile: .experimental(identifier: "example/model")
        )

        do {
            _ = try await LabAssetVerifier().verify(configuration)
            Issue.record("A non-GGUF file unexpectedly passed experimental verification.")
        } catch LabAssetError.invalidModelFormat {
            // Expected.
        } catch {
            Issue.record("Unexpected verification error: \(error)")
        }
    }

    @Test("Older aggregate reports decode as production-pinned")
    func legacyAssetSnapshot() throws {
        let json = """
        {
          "modelIdentifier": "legacy-model",
          "modelRevision": "legacy-revision",
          "modelSHA256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          "helperSHA256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        }
        """

        let snapshot = try JSONDecoder().decode(LabAssetSnapshot.self, from: Data(json.utf8))

        #expect(snapshot.verificationMode == .productionPinned)
    }

    private func makeFixture(
        modelBytes: Data
    ) throws -> (directory: URL, server: URL, model: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tilde-lab-assets-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let server = directory.appendingPathComponent("llama-server")
        let model = directory.appendingPathComponent("model.gguf")
        try Data("helper".utf8).write(to: server, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: server.path)
        try modelBytes.write(to: model, options: .atomic)
        return (directory, server, model)
    }
}
