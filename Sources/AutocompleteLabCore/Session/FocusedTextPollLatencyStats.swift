import Foundation

public struct FocusedTextPollLatencyStats: Equatable, Sendable {
    private let sampleWindow: Int
    private var samples: [Int]

    public init(sampleWindow: Int = 60) {
        self.sampleWindow = max(1, sampleWindow)
        self.samples = []
        self.samples.reserveCapacity(self.sampleWindow)
    }

    public mutating func record(
        _ durationMilliseconds: Int,
        includeInSummary: Bool = true
    ) -> FocusedTextPollLatencySummary? {
        guard includeInSummary else {
            return nil
        }

        samples.append(max(0, durationMilliseconds))

        guard samples.count >= sampleWindow else {
            return nil
        }

        return drain()
    }

    public mutating func drain() -> FocusedTextPollLatencySummary? {
        guard !samples.isEmpty else {
            return nil
        }

        let ordered = samples.sorted()
        let summary = FocusedTextPollLatencySummary(
            count: samples.count,
            p50Milliseconds: percentile(0.50, in: ordered),
            p90Milliseconds: percentile(0.90, in: ordered),
            p95Milliseconds: percentile(0.95, in: ordered),
            p99Milliseconds: percentile(0.99, in: ordered),
            maxMilliseconds: ordered.last ?? 0
        )
        samples.removeAll(keepingCapacity: true)
        return summary
    }

    private func percentile(_ fraction: Double, in orderedSamples: [Int]) -> Int {
        guard !orderedSamples.isEmpty else {
            return 0
        }

        let maxIndex = orderedSamples.count - 1
        let rawIndex = (Double(maxIndex) * fraction).rounded()
        let index = min(maxIndex, Int(rawIndex))
        return orderedSamples[index]
    }
}

public struct FocusedTextPollLatencySummary: Equatable, Sendable {
    public let count: Int
    public let p50Milliseconds: Int
    public let p90Milliseconds: Int
    public let p95Milliseconds: Int
    public let p99Milliseconds: Int
    public let maxMilliseconds: Int

    public init(
        count: Int,
        p50Milliseconds: Int,
        p90Milliseconds: Int? = nil,
        p95Milliseconds: Int,
        p99Milliseconds: Int? = nil,
        maxMilliseconds: Int
    ) {
        self.count = count
        self.p50Milliseconds = p50Milliseconds
        self.p90Milliseconds = p90Milliseconds ?? p95Milliseconds
        self.p95Milliseconds = p95Milliseconds
        self.p99Milliseconds = p99Milliseconds ?? maxMilliseconds
        self.maxMilliseconds = maxMilliseconds
    }
}

public struct FocusedTextPollDiagnosticsPolicy: Equatable, Sendable {
    public static let typingDiagnostics = FocusedTextPollDiagnosticsPolicy()

    public let slowPollMarkerMilliseconds: Int
    public let slowAXReadMarkerMilliseconds: Int

    public init(
        slowPollMarkerMilliseconds: Int = 120,
        slowAXReadMarkerMilliseconds: Int = 120
    ) {
        self.slowPollMarkerMilliseconds = max(0, slowPollMarkerMilliseconds)
        self.slowAXReadMarkerMilliseconds = max(0, slowAXReadMarkerMilliseconds)
    }

    public func shouldRecordSlowPollMarker(durationMilliseconds: Int) -> Bool {
        durationMilliseconds >= slowPollMarkerMilliseconds
    }

    public func shouldRecordSlowAXReadMarker(
        queueDelayMilliseconds: Int,
        readDurationMilliseconds: Int
    ) -> Bool {
        max(queueDelayMilliseconds, readDurationMilliseconds) >= slowAXReadMarkerMilliseconds
    }
}
