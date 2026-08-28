import Foundation
import Testing
@testable import TildeLabKit

@Suite("Interleaved arm order")
struct LabInterleavedArmOrderTests {
    @Test("Cache policy is explicit in each HTTP request")
    func cacheRequestFlag() throws {
        let client = try LabHTTPCompletionClient(
            baseURL: URL(string: "http://127.0.0.1:12345")!, workerIndex: 0
        )
        for enabled in [false, true] {
            var generation = LabGenerationConfiguration()
            generation.cachePrompt = enabled
            let request = LabModelRequest(
                prompt: "synthetic test", generation: generation, timeoutSeconds: 1
            )
            #expect(client.requestBody(request)["cache_prompt"] as? Bool == enabled)
        }
    }

    @Test("Two-arm blocks alternate AB and BA without cancelling rotation")
    func pairedBalance() {
        let orders = (0..<20).map {
            LabExperimentRunner.interleavedArmOrder(armCount: 2, blockIndex: $0)
        }
        #expect(orders[0] == [0, 1])
        #expect(orders[1] == [1, 0])
        #expect(orders.filter { $0.first == 0 }.count == 10)
        #expect(orders.filter { $0.first == 1 }.count == 10)
        #expect(Array(orders.prefix(4)) == [[0, 1], [1, 0], [0, 1], [1, 0]])
    }

    @Test("Each order contains every arm exactly once")
    func permutations() {
        for count in 0...8 {
            for block in 0..<20 {
                let order = LabExperimentRunner.interleavedArmOrder(
                    armCount: count, blockIndex: block
                )
                #expect(order.sorted() == Array(0..<count))
            }
        }
    }
}
