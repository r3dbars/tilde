import Foundation

struct FocusedTextPollBeginDecision: Equatable {
    let shouldStart: Bool
    let startedAt: UInt64?
    let coalescedSource: FocusedTextUpdateSource?

    static func start(startedAt: UInt64) -> FocusedTextPollBeginDecision {
        FocusedTextPollBeginDecision(
            shouldStart: true,
            startedAt: startedAt,
            coalescedSource: nil
        )
    }

    static func coalesced(_ source: FocusedTextUpdateSource) -> FocusedTextPollBeginDecision {
        FocusedTextPollBeginDecision(
            shouldStart: false,
            startedAt: nil,
            coalescedSource: source
        )
    }
}

struct FocusedTextPollFinish: Equatable {
    let durationMilliseconds: Int
    let pendingUpdateSource: FocusedTextUpdateSource?
}

struct FocusedTextPollLifecycle: Equatable {
    private var isInFlight = false
    private var latestReadRequestID: UInt64?
    private var pendingUpdateSource: FocusedTextUpdateSource?
    private var nextScheduledPollAt = Date.distantPast
    private let updateSourcePolicy: FocusedTextUpdateSourcePolicy

    init(updateSourcePolicy: FocusedTextUpdateSourcePolicy = FocusedTextUpdateSourcePolicy()) {
        self.updateSourcePolicy = updateSourcePolicy
    }

    mutating func shouldRunScheduledPoll(
        source: FocusedTextUpdateSource,
        now: Date,
        interval: TimeInterval
    ) -> Bool {
        guard now >= nextScheduledPollAt else {
            return false
        }

        nextScheduledPollAt = now.addingTimeInterval(interval)
        return true
    }

    mutating func requestImmediatePoll(now: Date = Date()) {
        nextScheduledPollAt = now
    }

    mutating func beginPoll(
        source: FocusedTextUpdateSource,
        startedAt: UInt64 = DispatchTime.now().uptimeNanoseconds
    ) -> FocusedTextPollBeginDecision {
        guard !isInFlight else {
            pendingUpdateSource = updateSourcePolicy.coalesced(
                pendingUpdateSource,
                with: source
            )
            return .coalesced(source)
        }

        isInFlight = true
        return .start(startedAt: startedAt)
    }

    mutating func finishPoll(
        startedAt: UInt64,
        endedAt: UInt64 = DispatchTime.now().uptimeNanoseconds
    ) -> FocusedTextPollFinish {
        let durationMilliseconds = Int((endedAt - startedAt) / 1_000_000)
        let pendingUpdateSource = pendingUpdateSource
        self.pendingUpdateSource = nil
        isInFlight = false
        latestReadRequestID = nil
        return FocusedTextPollFinish(
            durationMilliseconds: durationMilliseconds,
            pendingUpdateSource: pendingUpdateSource
        )
    }

    mutating func recordReadRequestID(_ requestID: UInt64) {
        latestReadRequestID = requestID
    }

    func isLatestReadRequest(_ requestID: UInt64) -> Bool {
        latestReadRequestID == requestID
    }
}
