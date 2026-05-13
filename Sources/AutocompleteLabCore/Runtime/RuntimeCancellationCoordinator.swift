import Foundation

public final class RuntimeCancellationCoordinator: @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.transcripted.autocomplete.runtime-cancellation")
    private var epoch = 0
    private var nextOperationID = 0
    private var activeOperationCancellations: [Int: @Sendable () -> Void] = [:]

    public init() {}

    public var activeOperationCount: Int {
        queue.sync {
            activeOperationCancellations.count
        }
    }

    public func snapshot() -> Int {
        queue.sync {
            epoch
        }
    }

    @discardableResult
    public func cancelAll() -> Int {
        let snapshot = queue.sync {
            epoch += 1
            let cancellations = Array(activeOperationCancellations.values)
            activeOperationCancellations.removeAll()
            return (epoch, cancellations)
        }

        for cancel in snapshot.1 {
            cancel()
        }

        return snapshot.0
    }

    public func check(epoch operationEpoch: Int) throws {
        try Task.checkCancellation()

        let isCurrent = queue.sync {
            epoch == operationEpoch
        }

        guard isCurrent else {
            throw CancellationError()
        }
    }

    public func withRegisteredTask<Value: Sendable>(
        _ operation: @escaping @Sendable (_ epoch: Int) async throws -> Value
    ) async throws -> Value {
        try Task.checkCancellation()

        let registration = queue.sync {
            let operationEpoch = epoch
            nextOperationID += 1
            let operationID = nextOperationID
            let task = Task {
                try await operation(operationEpoch)
            }
            activeOperationCancellations[operationID] = {
                task.cancel()
            }
            return RuntimeCancellationRegistration(id: operationID, task: task)
        }
        defer {
            unregisterOperation(id: registration.id)
        }

        return try await withTaskCancellationHandler {
            try await registration.task.value
        } onCancel: {
            registration.task.cancel()
        }
    }

    private func unregisterOperation(id: Int) {
        queue.sync {
            activeOperationCancellations[id] = nil
        }
    }
}

private struct RuntimeCancellationRegistration<Value: Sendable>: Sendable {
    let id: Int
    let task: Task<Value, Error>
}
