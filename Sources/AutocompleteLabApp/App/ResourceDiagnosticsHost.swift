import AppKit

private final class ProcessResourceDiagnosticsSampler {
    private var previousCPUSeconds: Double?
    private var previousWallTime: Date?

    func sample() -> [String: String] {
        let now = Date()
        let cpuSeconds = Self.currentCPUSeconds()
        var metadata: [String: String] = [
            "lowPowerMode": String(ProcessInfo.processInfo.isLowPowerModeEnabled),
            "processorCount": String(ProcessInfo.processInfo.activeProcessorCount),
            "thermalState": ProcessInfo.processInfo.thermalState.diagnosticsValue
        ]

        if let rssMB = Self.currentResidentMemoryMegabytes() {
            metadata["rssMB"] = String(rssMB)
        }

        if let cpuSeconds {
            if let previousCPUSeconds, let previousWallTime {
                let elapsed = max(0.001, now.timeIntervalSince(previousWallTime))
                let cpuPercent = max(0, ((cpuSeconds - previousCPUSeconds) / elapsed) * 100)
                metadata["cpuPercent"] = String(format: "%.1f", cpuPercent)
            } else {
                metadata["cpuPercent"] = "0.0"
            }
            previousCPUSeconds = cpuSeconds
            previousWallTime = now
        }

        return metadata
    }

    private static func currentCPUSeconds() -> Double? {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else {
            return nil
        }

        return seconds(from: usage.ru_utime) + seconds(from: usage.ru_stime)
    }

    private static func seconds(from timeValue: timeval) -> Double {
        Double(timeValue.tv_sec) + (Double(timeValue.tv_usec) / 1_000_000)
    }

    private static func currentResidentMemoryMegabytes() -> Int? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.stride / MemoryLayout<natural_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    reboundPointer,
                    &count
                )
            }
        }
        guard result == KERN_SUCCESS else {
            return nil
        }

        let megabyte = UInt64(1_048_576)
        return Int((UInt64(info.resident_size) + megabyte - 1) / megabyte)
    }
}

private extension ProcessInfo.ThermalState {
    var diagnosticsValue: String {
        switch self {
        case .nominal:
            "nominal"
        case .fair:
            "fair"
        case .serious:
            "serious"
        case .critical:
            "critical"
        @unknown default:
            "unknown"
        }
    }
}

@MainActor
final class ResourceDiagnosticsHost {
    private var timer: Timer?
    private let sampler = ProcessResourceDiagnosticsSampler()

    func start() {
        guard timer == nil else {
            return
        }

        record(reason: "launch")
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.record(reason: "periodic")
            }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func record(reason: String) {
        var metadata = sampler.sample()
        metadata["reason"] = reason
        DiagnosticsLog.shared.record("runtime-resource-sample", metadata: metadata)
    }
}
